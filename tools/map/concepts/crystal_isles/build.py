"""Glass Clash map concept: "Crystal Isles".

A chain of small floating grassy islands joined by short wooden bridges. Island 0 is the
lobby (spawn, crate crystal, shop tent, leaderboards, index, daily chest, codes, champion),
islands 1-3 hold two Clash Stands each (6 arenas), and the largest island at the end holds
the Featured arena behind a crystal arch. Clouds drift below.

Self-contained: clears the scene, builds everything, renders three views (aerial, spawn,
arena) with Cycles to docs/art/concepts/crystal_isles/*.jpg.

Run:  <bpy python> build.py [--views aerial,spawn,arena] [--samples 24] [--pct 100]
      extra flags: --vt / --look / --exp (colour management), debug views: featured, hall.
      CI_SAVE=/path/file.blend also saves the built scene.
1 Blender unit = 1 stud, Z up. The arena row runs along +Y. Island heights step up 2-3 studs each.
"""

import bpy  # noqa: I001  (bpy must be imported before bmesh / mathutils)
import bmesh
import math
import os
import random
import subprocess
import sys
from mathutils import Matrix, Vector, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
STAND_BLEND = os.path.join(REPO, "assets", "blender", "map", "clash_stand.blend")
STAND_COLL = "GlassClash_ClashStand.001"
GLASSY_DIR = os.path.join(REPO, "assets", "blender", "glassies")
OUT_DIR = os.path.join(REPO, "docs", "art", "concepts", "crystal_isles")


def _arg(name, default):
    if name in sys.argv:
        return sys.argv[sys.argv.index(name) + 1]
    return default


VIEWS = _arg("--views", "aerial,spawn,arena").split(",")
SAMPLES = int(_arg("--samples", "24"))
RES_PCT = int(_arg("--pct", "100"))

rng = random.Random(7)

# ---------------------------------------------------------------------------
# Layout (studs). Row runs along +Y; every island top is at Z = 0.
# ---------------------------------------------------------------------------
# Each island steps up a little (z) so the row reads as a gentle climb toward the Featured arena.
LOBBY = dict(cx=0.0, cy=0.0, a=48.0, b=28.0, z=0.0)
SPAWN = Vector((0.0, -12.0, 0.0))
ARENA_ISLANDS = [dict(cx=0.0, cy=cy, a=46.0, b=23.0, z=z) for cy, z in ((56.0, 2.0), (107.0, 4.0), (158.0, 6.0))]
FEATURED = dict(cx=0.0, cy=210.0, a=36.0, b=24.0, z=9.0)
FEAT_PAD_LOCAL = Vector((19.5, -10.5, 0))  # featured pads sit on the front corners (short walk from the arch)
ARENA_X = 24.0  # arenas sit left/right of a 19-stud wide central viewing walkway
PAD_LOCAL = 18.5  # queue pad distance from the stand centre, along the swing axis
FEAT_SCALE = 1.15
STAND_Z = 0.1
BRIDGE_W = 8.0

# ---------------------------------------------------------------------------
# Colours / materials
# ---------------------------------------------------------------------------
PAL = {
    "grass": "#7CCB5B",
    "grass_side": "#5DA845",
    "dirt": "#9A6B43",
    "rock": "#9787A0",
    "rock_dark": "#6E6180",
    "path": "#F1DDAA",
    "plaza": "#EDE5D3",
    "plaza_dark": "#CFC3AA",
    "plank": "#C98A4B",
    "plank_dark": "#94603A",
    "rope": "#E8D2A0",
    "cyan": "#6FE7FF",
    "pink": "#FF7EC8",
    "violet": "#B58CFF",
    "gold": "#FFD166",
    "padA": "#4FB8FF",
    "padB": "#FF9F43",
    "pad_base": "#5B6A8C",
    "tent_red": "#FF6B6B",
    "cream": "#FFF4E0",
    "navy": "#2B3A67",
    "trim": "#FFC94D",
    "white": "#FFFFFF",
    "cloud": "#FFFFFF",
    "leaf": "#4FAF5A",
    "leaf2": "#3E9B4E",
    "trunk": "#8A5A3B",
    "skin": "#FFD34D",
    "red": "#E8453C",
    "teal": "#2EC4B6",
    "yellow": "#FFE066",
    "purple": "#8E6CEF",
    "blue": "#3A86FF",
    "green": "#38B000",
    "coral": "#FF8A65",
    "dark": "#3B3F55",
    "board": "#2F5D50",
    "marble": "#F4F1EA",
}


def srgb(hexstr, a=1.0):
    h = hexstr.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (out[0], out[1], out[2], a)


M = {}


def _bsdf(m):
    try:
        m.use_nodes = True
    except Exception:  # noqa: BLE001
        pass
    return m.node_tree.nodes.get("Principled BSDF")


def mat(name, hexcol, rough=0.85, emit=0.0, emit_hex=None):
    m = bpy.data.materials.new("CI_" + name)
    b = _bsdf(m)
    b.inputs["Base Color"].default_value = srgb(hexcol)
    b.inputs["Roughness"].default_value = rough
    try:
        b.inputs["Specular IOR Level"].default_value = 0.3
    except KeyError:
        pass
    if emit > 0:
        b.inputs["Emission Color"].default_value = srgb(emit_hex or hexcol)
        b.inputs["Emission Strength"].default_value = emit
    m.diffuse_color = srgb(hexcol)
    M[name] = m
    return m


def glass_mat(name, hexcol):
    """Glossy tinted glass preview for glassies (the only glossy things in the world)."""
    m = bpy.data.materials.new("CI_glass_" + name)
    b = _bsdf(m)
    b.inputs["Base Color"].default_value = srgb(hexcol)
    b.inputs["Roughness"].default_value = 0.04
    b.inputs["IOR"].default_value = 1.45
    for key, val in (("Transmission Weight", 0.82), ("Coat Weight", 0.6), ("Coat Roughness", 0.03)):
        try:
            b.inputs[key].default_value = val
        except KeyError:
            pass
    b.inputs["Emission Color"].default_value = srgb(hexcol)
    b.inputs["Emission Strength"].default_value = 0.35
    M["glass_" + name] = m
    return m


def build_materials():
    for k in ("grass", "grass_side", "dirt", "rock", "rock_dark", "path", "plaza", "plaza_dark",
              "plank", "plank_dark", "rope", "pad_base", "tent_red", "cream", "navy", "trim",
              "white", "leaf", "leaf2", "trunk", "skin", "red", "teal", "yellow", "purple", "blue",
              "green", "coral", "dark", "board", "marble"):
        mat(k, PAL[k])
    mat("cloud", PAL["cloud"], rough=1.0, emit=0.25)
    for k in ("cyan", "pink", "violet", "gold"):
        mat("cr_" + k, PAL[k], rough=0.45, emit=2.2)  # glowing, matte-ish crystals
        mat("crs_" + k, PAL[k], rough=0.5, emit=0.6)  # dimmer crystals (lots of them, under islands)
    mat("padA", PAL["padA"], rough=0.5, emit=1.0)
    mat("padB", PAL["padB"], rough=0.5, emit=1.0)
    mat("lamp", "#FFF1C9", rough=0.5, emit=4.0)
    mat("screen", "#E9F1FF", rough=0.6, emit=1.2)
    mat("screen_gold", PAL["gold"], rough=0.6, emit=1.5)
    mat("gold_metal", PAL["gold"], rough=0.35)
    mat("silhouette", "#2A2D3E", rough=0.6)
    mat("bubble", "#FFFFFF", rough=0.2)
    glass_mat("pop", "#8FE3FF")
    glass_mat("jam", "#FF6B8B")
    glass_mat("prism", "#C9A8FF")


# ---------------------------------------------------------------------------
# Mesh builder: one object per group, many primitives, per-face materials, flat shaded
# ---------------------------------------------------------------------------
class MB:
    def __init__(self, name):
        self.name = name
        self.v, self.f, self.fm = [], [], []
        self.mats = []

    def _mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def add(self, verts, faces, m, mx=None):
        base = len(self.v)
        mx = mx or Matrix.Identity(4)
        self.v.extend([tuple(mx @ Vector(p)) for p in verts])
        ms = m if isinstance(m, list) else [m] * len(faces)
        for face, mm in zip(faces, ms):
            self.f.append([base + i for i in face])
            self.fm.append(self._mi(mm))

    # primitives -----------------------------------------------------------
    def box(self, c, s, m, rz=0.0, rx=0.0, ry=0.0):
        hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        v = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
             (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]
        f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        mx = Matrix.Translation(c) @ Euler((rx, ry, rz)).to_matrix().to_4x4()
        self.add(v, f, m, mx)

    def prism(self, c, r, h, m, n=8, rt=None, rz=0.0, mx=None, side_mats=None, top_m=None, sx=1.0, sy=1.0):
        """Frustum from z=0 to z=h (local), placed at c. rt = top radius (0 -> cone)."""
        rt = r if rt is None else rt
        v, f = [], []
        for i in range(n):
            t = 2 * math.pi * i / n
            v.append((r * math.cos(t) * sx, r * math.sin(t) * sy, 0))
        for i in range(n):
            t = 2 * math.pi * i / n
            v.append((rt * math.cos(t) * sx, rt * math.sin(t) * sy, h))
        mats = []
        f.append(tuple(reversed(range(n))))
        mats.append(m)
        for i in range(n):
            j = (i + 1) % n
            f.append((i, j, n + j, n + i))
            mats.append(side_mats[i % len(side_mats)] if side_mats else m)
        if rt > 1e-4:
            f.append(tuple(range(n, 2 * n)))
            mats.append(top_m or m)
        else:
            v = v[:n] + [(0, 0, h)]
            f = [f[0]] + [(i, (i + 1) % n, n) for i in range(n)]
            mats = mats[:n + 1]
        M4 = Matrix.Translation(c) @ Matrix.Rotation(rz, 4, "Z")
        if mx is not None:
            M4 = mx @ M4
        self.add(v, f, mats, M4)

    def crystal(self, base, direction, r, h, m, n=6, tip=None, twist=0.0):
        """Hexagonal glowing crystal: prism body + pointed tip, growing along direction."""
        tip = tip if tip is not None else r * 1.6
        v, f = [], []
        for k, z in enumerate((0.0, h)):
            rr = r if k == 0 else r * 0.9
            for i in range(n):
                t = 2 * math.pi * i / n + twist
                v.append((rr * math.cos(t), rr * math.sin(t), z))
        v.append((0, 0, h + tip))
        f.append(tuple(reversed(range(n))))
        for i in range(n):
            j = (i + 1) % n
            f.append((i, j, n + j, n + i))
            f.append((n + i, n + j, 2 * n))
        d = Vector(direction).normalized()
        rot = Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()
        self.add(v, f, m, Matrix.Translation(base) @ rot)

    def ico(self, c, r, m, sub=1, scale=(1, 1, 1), rz=0.0):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
        v = [tuple(x.co) for x in bm.verts]
        f = [tuple(x.index for x in fa.verts) for fa in bm.faces]
        bm.free()
        mx = Matrix.Translation(c) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Diagonal((*scale, 1))
        self.add(v, f, m, mx)

    def beam(self, p0, p1, w, h, m):
        """Box spanning from p0 to p1 (centre line), cross-section w x h."""
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        L = d.length
        rot = Vector((1, 0, 0)).rotation_difference(d.normalized()).to_matrix().to_4x4()
        hx, hy, hz = L / 2, w / 2, h / 2
        v = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
             (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]
        f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        self.add(v, f, m, Matrix.Translation((p0 + p1) / 2) @ rot)

    def build(self, coll=None):
        me = bpy.data.meshes.new(self.name)
        me.from_pydata(self.v, [], self.f)
        for m in self.mats:
            me.materials.append(m)
        for poly, mi in zip(me.polygons, self.fm):
            poly.material_index = mi
            poly.use_smooth = False
        me.validate()
        ob = bpy.data.objects.new(self.name, me)
        (coll or bpy.context.scene.collection).objects.link(ob)
        return ob


def text(body, loc, size, m, rz=0.0, upright=True, extrude=0.12):
    cu = bpy.data.curves.new("T_" + body, "FONT")
    cu.body = body
    cu.size = size
    cu.extrude = extrude
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    ob = bpy.data.objects.new("T_" + body, cu)
    ob.data.materials.append(m)
    ob.location = loc
    ob.rotation_euler = (math.pi / 2 if upright else 0.0, 0.0, rz)
    bpy.context.scene.collection.objects.link(ob)
    return ob


class lifted:
    """Context manager: every object created inside is raised by dz (island height)."""

    def __init__(self, dz):
        self.dz = dz

    def __enter__(self):
        self.before = set(bpy.data.objects)
        return self

    def __exit__(self, *exc):
        for o in set(bpy.data.objects) - self.before:
            if o.parent is None and o.users_scene:
                o.location.z += self.dz
        return False


def yaw_to(src, dst):
    """rz so a +Y-facing thing at src faces dst (used for avatars, which face -Y by default)."""
    return math.atan2(dst[1] - src[1], dst[0] - src[0]) + math.pi / 2


# ---------------------------------------------------------------------------
# Islands
# ---------------------------------------------------------------------------
def se_points(a, b, count, exp=4.0, jitter=0.03, seed=0):
    r = random.Random(seed)
    pts = []
    for i in range(count):
        t = 2 * math.pi * i / count
        c, s = math.cos(t), math.sin(t)
        x = a * math.copysign(abs(c) ** (2 / exp), c)
        y = b * math.copysign(abs(s) ** (2 / exp), s)
        k = 1 + r.uniform(-jitter, jitter)
        pts.append(Vector((x * k, y * k, 0)))
    return pts


def island(name, isl, seed, crystals_under=26, exp=4.0):
    cx, cy, a, b = isl["cx"], isl["cy"], isl["a"], isl["b"]
    r = random.Random(seed)
    n = 36
    pts = se_points(a, b, n, exp=exp, jitter=0.025, seed=seed)
    mb = MB(name)
    # grass cap (top z=0, 1.4 thick)
    v, f, ms = [], [], []
    for p in pts:
        v.append((p.x, p.y, 0.0))
    for p in pts:
        v.append((p.x * 1.01, p.y * 1.01, -1.4))
    f.append(tuple(range(n)))
    ms.append(M["grass"])
    for i in range(n):
        j = (i + 1) % n
        f.append((i, n + i, n + j, j))
        ms.append(M["grass_side"])
    mb.add(v, f, ms, Matrix.Translation((cx, cy, 0)))
    # rock underside: shrinking jittered rings down to a tip
    depth = 0.95 * min(a, b) + 8
    levels = [(-1.4, 1.0, "dirt"), (-3.6, 0.95, "rock"), (-0.3 * depth, 0.8, "rock"),
              (-0.55 * depth, 0.55, "rock_dark"), (-0.78 * depth, 0.3, "rock_dark")]
    rings = []
    for li, (z, s, _) in enumerate(levels):
        off = Vector((r.uniform(-2, 2), r.uniform(-2, 2), 0)) * (li / 2)
        ring = []
        for p in pts:
            k = s * (1 + (r.uniform(-0.07, 0.07) if li > 0 else 0))
            ring.append(Vector((p.x * k * 1.01, p.y * k * 1.01, z + (r.uniform(-1.2, 1.2) if li > 1 else 0))) + off)
        rings.append(ring)
    tip = Vector((r.uniform(-3, 3), r.uniform(-3, 3), -depth))
    v = [tuple(p) for ring in rings for p in ring] + [tuple(tip)]
    f, ms = [], []
    for li in range(len(rings) - 1):
        for i in range(n):
            j = (i + 1) % n
            f.append((li * n + i, (li + 1) * n + i, (li + 1) * n + j, li * n + j))
            ms.append(M[levels[li][2]])
    last = (len(rings) - 1) * n
    for i in range(n):
        j = (i + 1) % n
        f.append((last + i, len(v) - 1, last + j))
        ms.append(M["rock_dark"])
    mb.add(v, f, ms, Matrix.Translation((cx, cy, 0)))
    mb.build()

    # glowing crystals growing out of the underside, pointing down/outward
    cb = MB(name + "_Crystals")
    cols = ["cyan", "pink", "violet", "gold"]
    for _ in range(crystals_under):
        li = r.choice((1, 2, 2, 3, 3))
        i = r.randrange(n)
        p = rings[li][i]
        out = Vector((p.x, p.y, 0)).normalized()
        d = (out * r.uniform(0.3, 0.9) + Vector((0, 0, -1))).normalized()
        base = Vector((cx, cy, 0)) + p - out * 0.8
        s = r.uniform(0.7, 1.8)
        cb.crystal(base, d, s, s * r.uniform(2.5, 4.5), M["crs_" + r.choice(cols)], twist=r.random())
    # big glowing cluster on the tip
    tipw = Vector((cx, cy, 0)) + tip
    col = cols[seed % 4]
    cb.crystal(tipw + Vector((0, 0, 2)), (0, 0, -1), 2.6, 7, M["cr_" + col])
    for k in range(5):
        ang = 2 * math.pi * k / 5 + r.random()
        d = Vector((math.cos(ang) * 0.7, math.sin(ang) * 0.7, -1))
        cb.crystal(tipw + Vector((math.cos(ang) * 1.8, math.sin(ang) * 1.8, 2.5)), d, 1.2, 4.5,
                   M["cr_" + cols[(seed + k) % 4]])
    cb.build()
    return pts


def fence(name, isl, pts, openings):
    """Low wooden fence on the island rim. openings: list of (x, y) points to keep clear (radius 6)."""
    cx, cy = isl["cx"], isl["cy"]
    mb = MB(name)
    n = len(pts)
    ring = [Vector((cx + p.x * 0.975, cy + p.y * 0.975, 0)) for p in pts]

    def blocked(p):
        return any((p - Vector((ox, oy, 0))).length < 6.5 for ox, oy in openings)

    for i in range(n):
        p, q = ring[i], ring[(i + 1) % n]
        if blocked(p) or blocked(q):
            continue
        mb.box((p.x, p.y, 1.3), (0.7, 0.7, 2.6), M["plank_dark"])
        for z in (1.0, 2.0):
            mb.beam((p.x, p.y, z), (q.x, q.y, z), 0.35, 0.35, M["plank"])
    mb.build()


def crystal_cluster(mb, base, scale, cols, r, n_small=4, lean=0.25, glow=True):
    pre = "cr_" if glow else "crs_"
    base = Vector(base)
    mb.crystal(base + Vector((0, 0, -0.5)), (r.uniform(-lean, lean), r.uniform(-lean, lean), 1),
               1.1 * scale, 4.0 * scale, M[pre + cols[0]], twist=r.random())
    for k in range(n_small):
        ang = 2 * math.pi * k / n_small + r.random()
        off = Vector((math.cos(ang), math.sin(ang), 0)) * 1.3 * scale
        d = (off.normalized() * r.uniform(0.4, 0.9) + Vector((0, 0, 1))).normalized()
        s = scale * r.uniform(0.45, 0.7)
        mb.crystal(base + off + Vector((0, 0, -0.4)), d, s, s * r.uniform(2.2, 3.4),
                   M[pre + cols[(k + 1) % len(cols)]], twist=r.random())


def rocks(mb, base, r, count=3, size=1.6):
    for _ in range(count):
        off = Vector((r.uniform(-1.5, 1.5), r.uniform(-1.5, 1.5), 0)) * size
        s = size * r.uniform(0.6, 1.2)
        mb.ico(Vector(base) + off + Vector((0, 0, s * 0.3)), s, M["rock"], sub=1,
               scale=(1, r.uniform(0.7, 1.1), 0.7), rz=r.random() * 6)


def tree(mb, base, r, s=1.0):
    x, y = base[0], base[1]
    mb.prism((x, y, 0), 0.7 * s, 4.5 * s, M["trunk"], n=6)
    mb.ico((x, y, 6.5 * s), 3.2 * s, M[r.choice(("leaf", "leaf2"))], sub=1, scale=(1, 1, 0.9), rz=r.random() * 6)
    mb.ico((x + 1.4 * s, y + 0.8 * s, 8.6 * s), 2.0 * s, M["leaf"], sub=1, rz=r.random() * 6)


def lamp(mb, x, y, col="gold"):
    mb.prism((x, y, 0), 0.5, 0.6, M["plank_dark"], n=6)
    mb.prism((x, y, 0.6), 0.22, 5.4, M["plank_dark"], n=6)
    mb.crystal((x, y, 5.6), (0, 0, 1), 0.55, 1.2, M["cr_" + col], tip=0.8)


# ---------------------------------------------------------------------------
# Bridges
# ---------------------------------------------------------------------------
def bridge(name, y0, y1, z0=0.0, z1=0.0, x=0.0):
    """Plank ramp-bridge from island edge y0 (top z0) to island edge y1 (top z1); overlaps 2 studs onto each."""
    mb = MB(name)
    a, b = y0 - 2.0, y1 + 2.0
    L = b - a
    n = int(L / 1.0)

    def zat(t):
        return z0 + (z1 - z0) * t + 0.08 + 0.35 * math.sin(math.pi * t)

    slope = math.atan2(z1 - z0, L)
    for i in range(n):
        t = (i + 0.5) / n
        y = a + t * L
        mb.box((x, y, zat(t) - 0.15), (BRIDGE_W, 0.86, 0.3), M["plank" if i % 3 else "plank_dark"], rx=slope)
    for sx in (-1, 1):
        bx = x + sx * (BRIDGE_W / 2 - 0.4)
        mb.beam((bx, a, zat(0) - 0.5), (bx, (a + b) / 2, zat(0.5) - 0.5), 0.6, 0.6, M["plank_dark"])
        mb.beam((bx, (a + b) / 2, zat(0.5) - 0.5), (bx, b, zat(1) - 0.5), 0.6, 0.6, M["plank_dark"])
        posts = [a + 0.5, (a + b) / 2, b - 0.5]
        tops = []
        for py in posts:
            t = (py - a) / L
            z0_ = zat(t)
            mb.box((bx, py, z0_ + 1.4), (0.6, 0.6, 2.8), M["plank_dark"])
            mb.box((bx, py, z0_ + 2.95), (0.8, 0.8, 0.3), M["plank"])
            tops.append(Vector((bx, py, z0_ + 2.6)))
        for p, q in zip(tops, tops[1:]):
            mid = (p + q) / 2 + Vector((0, 0, -0.5))
            mb.beam(p, mid, 0.22, 0.22, M["rope"])
            mb.beam(mid, q, 0.22, 0.22, M["rope"])
    mb.build()


# ---------------------------------------------------------------------------
# Avatars (blocky kid-friendly figures for scale)
# ---------------------------------------------------------------------------
SHIRTS = ["red", "teal", "yellow", "purple", "blue", "green", "coral", "tent_red", "white"]
PANTS = ["navy", "dark", "blue", "trunk"]


def avatar(mb, x, y, rz, shirt=None, z=0.0, s=1.0, mono=None):
    cam = CAMS["arena"][0]
    if math.hypot(x - cam[0], y - cam[1]) < 25:  # keep the arena close-up foreground clear
        return
    shirt = M[mono] if mono else M[shirt or rng.choice(SHIRTS)]
    pants = M[mono] if mono else M[rng.choice(PANTS)]
    skin = M[mono] if mono else M["skin"]
    mx = Matrix.Translation((x, y, z)) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Scale(s, 4)
    parts = [((-0.5, 0, 1.0), (0.95, 0.95, 2.0), pants), ((0.5, 0, 1.0), (0.95, 0.95, 2.0), pants),
             ((0, 0, 3.0), (2.0, 1.0, 2.0), shirt), ((-1.5, 0, 3.0), (0.95, 0.95, 2.0), skin),
             ((1.5, 0, 3.0), (0.95, 0.95, 2.0), skin)]
    for c, sz, m in parts:
        hx, hy, hz = sz[0] / 2, sz[1] / 2, sz[2] / 2
        v = [(c[0] + dx * hx, c[1] + dy * hy, c[2] + dz * hz) for dz in (-1, 1) for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        mb.add(v, f, m, mx)
    head = MB("tmp")
    head.prism((0, 0, 4.0), 0.68, 1.2, skin, n=10)
    mb.add(head.v, head.f, skin, mx)
    # face (two dark eyes) on the -Y side
    for ex in (-0.25, 0.25):
        hx = 0.09
        v = [(ex - hx, -0.69, 4.62 - hx), (ex + hx, -0.69, 4.62 - hx), (ex + hx, -0.69, 4.62 + hx), (ex - hx, -0.69, 4.62 + hx)]
        mb.add(v, [(0, 1, 2, 3)], M["dark"] if not mono else M[mono], mx)


def face_rz(src, dst):
    """Avatar faces -Y locally; rotation so it looks from src toward dst."""
    dx, dy = dst[0] - src[0], dst[1] - src[1]
    return math.atan2(dy, dx) + math.pi / 2


# ---------------------------------------------------------------------------
# Real assets: Clash Stand + glassies
# ---------------------------------------------------------------------------
STAND = None
GLASSY = {}


def load_assets():
    global STAND
    with bpy.data.libraries.load(STAND_BLEND, link=False) as (src, dst):
        dst.collections = [STAND_COLL]
    STAND = bpy.data.collections[STAND_COLL]
    # report its measured size (world bbox of the collection at identity)
    mn, mx = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in STAND.all_objects:
        mw = Matrix.LocRotScale(o.location, o.rotation_euler, o.scale)
        for c in o.bound_box:
            w = mw @ Vector(c)
            mn = Vector(map(min, mn, w))
            mx = Vector(map(max, mx, w))
    print("CLASH STAND bbox min", tuple(round(x, 2) for x in mn), "max", tuple(round(x, 2) for x in mx),
          "size", tuple(round(x, 2) for x in (mx - mn)))
    for gid, names in (("pop", ["Body", "Cap", "Bubble_01", "Bubble_02", "Bubble_03", "Bubble_04", "Bubble_05"]),
                       ("jam", ["Body", "Lid"]), ("prism", ["Body"])):
        with bpy.data.libraries.load(os.path.join(GLASSY_DIR, gid, gid + ".blend"), link=False) as (src, dst):
            dst.objects = [n for n in names if n in src.objects]
        parts = []
        for o in dst.objects:
            base = o.name.split(".")[0]
            o.matrix_world = Matrix.Identity(4)
            if base == "Body":
                m = M["glass_" + gid]
            elif base == "Cap":
                m = M["red"]
            elif base == "Lid":
                m = M["gold_metal"]
            else:
                m = M["bubble"]
            o.data.materials.clear()
            o.data.materials.append(m)
            for p in o.data.polygons:
                p.material_index = 0
            parts.append((base, o.data))
        GLASSY[gid] = parts


def place_glassy(gid, mx, mono=None):
    for base, me in GLASSY[gid]:
        if mono and base.startswith("Bubble"):
            continue
        o = bpy.data.objects.new(gid + "_" + base, me)
        o.matrix_world = mx
        if mono:
            o.material_slots[0].link = "OBJECT"
            o.material_slots[0].material = M[mono]
        bpy.context.scene.collection.objects.link(o)


def stand_instance(name, mx):
    e = bpy.data.objects.new(name, None)
    e.instance_type = "COLLECTION"
    e.instance_collection = STAND
    e.matrix_world = mx
    bpy.context.scene.collection.objects.link(e)


HOOK_LOCAL = {"A": Vector((-1.5, 0.0, 15.02)), "B": Vector((1.5, 0.0, 15.02))}
STRING_LEN = 5.0


def hang(mb_str, stand_mx, side, gid, swing_deg):
    """Hang glassy `gid` under hook `side`. swing_deg > 0 pulls it outward (away from the other)."""
    th = math.radians(swing_deg if side == "A" else -swing_deg)
    hook_w = stand_mx @ HOOK_LOCAL[side]
    loc, rot, _ = stand_mx.decompose()
    R = rot.to_matrix().to_4x4() @ Matrix.Rotation(th, 4, "Y")
    pivot = Matrix.Translation(hook_w) @ R
    place_glassy(gid, pivot @ Matrix.Translation((0, 0, -STRING_LEN)))
    mb_str.add(*_string_mesh(), M["white"], pivot)


def _string_mesh():
    r, n = 0.06, 4
    v = [(r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n), z) for z in (0.0, -STRING_LEN) for i in range(n)]
    f = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    return v, f


def queue_pad(mb, p, side, label_rz=None):
    col = "padA" if side == "A" else "padB"
    mb.prism((p.x, p.y, -0.05), 3.3, 0.3, M["pad_base"], n=12)
    mb.prism((p.x, p.y, 0.25), 2.7, 0.18, M[col], n=12)
    # floating marker crystal so pads read from far away
    mb.crystal((p.x, p.y, 8.2), (0, 0, -1), 0.7, 1.0, M[col], tip=1.0)
    mb.crystal((p.x, p.y, 8.2), (0, 0, 1), 0.7, 0.1, M[col], tip=1.0)


# ---------------------------------------------------------------------------
# Content builders
# ---------------------------------------------------------------------------
ACTIVE = []  # (stand_mx, pad positions) for avatars


def build_lobby():
    pts = island("Isle_Lobby", LOBBY, seed=1, crystals_under=30)
    fence("Fence_Lobby", LOBBY, pts, [(0, LOBBY["b"])])
    r = random.Random(11)
    mb = MB("Lobby_Props")
    # plaza + path to the first bridge
    mb.prism((0, -6, -0.05), 19, 0.13, M["plaza"], n=20)
    mb.prism((0, -6, -0.04), 13, 0.13, M["plaza_dark"], n=20)
    mb.prism((0, -6, -0.03), 12, 0.13, M["plaza"], n=20)
    mb.box((0, 19.5, 0.0), (9, 18, 0.12), M["path"])
    # spawn pad
    mb.prism((SPAWN.x, SPAWN.y, 0), 5.2, 0.5, M["marble"], n=12)
    mb.prism((SPAWN.x, SPAWN.y, 0.5), 4.2, 0.12, M["cr_cyan"], n=12)
    mb.prism((SPAWN.x, SPAWN.y, 0.55), 3.6, 0.12, M["marble"], n=12)
    for k in range(8):
        ang = 2 * math.pi * k / 8
        if math.sin(ang) > 0.5:  # keep the view from spawn toward the arenas clear
            continue
        mb.crystal((SPAWN.x + math.cos(ang) * 5.6, SPAWN.y + math.sin(ang) * 5.6, 0), (math.cos(ang) * 0.3, math.sin(ang) * 0.3, 1),
                   0.45, 1.4, M["cr_cyan"])

    # Crate crystal: giant glowing crystal with 3 crate machines at its base, facing spawn
    cc = Vector((-22.0, 11.0, 0))
    cb = MB("CrateCrystal")
    mb.prism((cc.x, cc.y, -0.05), 9.5, 0.6, M["rock"], n=9)
    cb.crystal(cc + Vector((0, 0, 0.2)), (0.05, 0.05, 1), 4.2, 15, M["cr_violet"], twist=0.2)
    cb.crystal(cc + Vector((-3.5, 2.5, 0)), (-0.35, 0.25, 1), 2.4, 9, M["cr_pink"], twist=0.5)
    cb.crystal(cc + Vector((3.0, 3.5, 0)), (0.3, 0.35, 1), 2.2, 7.5, M["cr_cyan"], twist=0.1)
    cb.crystal(cc + Vector((-4.0, -2.5, 0)), (-0.4, -0.3, 1), 1.6, 6, M["cr_gold"])
    cb.crystal(cc + Vector((-1.0, 4.5, 0)), (0.0, 0.5, 1), 1.5, 5, M["cr_violet"])
    cb.build()
    crate_cols = [("cyan", "teal"), ("violet", "purple"), ("gold", "trim")]
    for k, (cr, body) in enumerate(crate_cols):
        ang = math.radians(-82 + k * 36)
        p = cc + Vector((math.cos(ang), math.sin(ang), 0)) * 9.0
        rz = math.atan2(SPAWN.y - p.y, SPAWN.x - p.x) - math.pi / 2  # front (-Y local) faces spawn
        rz = face_rz(p, SPAWN)
        mx = Matrix.Translation(p) @ Matrix.Rotation(rz, 4, "Z")
        m2 = MB("tmp")
        m2.box((0, 0, 1.6), (4.2, 3.4, 3.2), M[body])
        m2.box((0, 0, 3.35), (4.6, 3.8, 0.3), M["cream"])
        m2.box((0, -1.75, 1.9), (2.6, 0.2, 1.4), M["screen"])
        m2.prism((0, -1.8, 0.6), 0.45, 0.15, M["gold_metal"], n=8, mx=Matrix.Rotation(math.pi / 2, 4, "X") @ Matrix.Translation((0, 0, 0)))
        m2.crystal((0, 0, 3.6), (0, 0, 1), 1.0, 1.4, M["cr_" + cr], tip=1.0, n=4)
        m2.crystal((0, 0, 3.7), (0, 0, -1), 1.0, 0.0, M["cr_" + cr], tip=0.01, n=4)
        mb.add(m2.v, m2.f, [m2.mats[i] for i in m2.fm], mx)
        if k == 2:  # one player using a machine (others left free so the machines read from spawn)
            avatar(mb, *(p + (Vector((SPAWN.x, SPAWN.y, 0)) - p).normalized() * 2.6).xy, face_rz(SPAWN, p))
    fzc = face_rz(cc, SPAWN)
    tocc = (Vector((SPAWN.x, SPAWN.y, 0)) - cc).normalized()
    cmx = Matrix.Translation(cc + tocc * 4.6) @ Matrix.Rotation(fzc, 4, "Z")  # sign fixed to the crystal
    m3 = MB("tmp")
    m3.box((0, 0, 10.2), (8.4, 0.4, 2.4), M["navy"])
    m3.box((0, 0.05, 10.2), (8.9, 0.3, 2.8), M["trim"])
    mb.add(m3.v, m3.f, [m3.mats[i] for i in m3.fm], cmx)
    t = text("CRATES", cmx @ Vector((0, -0.25, 10.2)), 1.7, M["white"], extrude=0.05)
    t.rotation_euler = (math.pi / 2, 0, fzc)

    # Shop tent (right)
    sp = Vector((22.0, 11.0, 0))
    stripes = [M["tent_red"], M["cream"]]
    mb.prism(sp, 7.0, 5.0, M["cream"], n=12, side_mats=stripes)
    mb.prism(sp + Vector((0, 0, 5.0)), 8.2, 6.0, M["tent_red"], n=12, rt=0.0, side_mats=stripes)
    mb.prism(sp + Vector((0, 0, 10.6)), 0.15, 3.0, M["plank_dark"], n=4)
    mb.box(sp + Vector((0.9, 0, 12.9)), (1.8, 0.1, 1.1), M["yellow"])
    face = (Vector((SPAWN.x, SPAWN.y, 0)) - sp).normalized()
    cpos = sp + face * 8.0
    mb.box(cpos + Vector((0, 0, 1.4)), (6.5, 2.0, 2.8), M["plank"], rz=math.atan2(face.y, face.x) + math.pi / 2)
    mb.box(cpos + Vector((0, 0, 2.9)), (7.0, 2.4, 0.25), M["cream"], rz=math.atan2(face.y, face.x) + math.pi / 2)
    gem = sp + face * 8.4 + Vector((0, 0, 4.6))
    mb.crystal(gem, (0, 0, 1), 0.9, 0.2, M["cr_cyan"], tip=0.9, n=6)
    mb.crystal(gem + Vector((0, 0, 0.2)), (0, 0, -1), 0.9, 0.0, M["cr_cyan"], tip=1.2, n=6)
    fzs = face_rz(sp, SPAWN)
    smx2 = Matrix.Translation(sp + face * 9.2) @ Matrix.Rotation(fzs, 4, "Z")
    m3 = MB("tmp")
    m3.box((0, 0, 5.6), (6.4, 0.4, 2.2), M["navy"])
    m3.box((0, 0.05, 5.6), (6.9, 0.3, 2.6), M["trim"])
    for px in (-2.9, 2.9):
        m3.box((px, 0.2, 4.0), (0.4, 0.4, 3.0), M["plank_dark"])
    mb.add(m3.v, m3.f, [m3.mats[i] for i in m3.fm], smx2)
    st = text("SHOP", smx2 @ Vector((0, -0.25, 5.6)), 1.6, M["white"], extrude=0.05)
    st.rotation_euler = (math.pi / 2, 0, fzs)
    side_v = Vector((-face.y, face.x, 0))
    shopper = cpos + face * 1.9 - side_v * 2.4
    avatar(mb, shopper.x, shopper.y, face_rz(shopper, shopper - face), shirt="green")

    # "Hall of fame" behind spawn: two leaderboards flanking the champion statue, facing the plaza
    for k, (sx, title) in enumerate(((-14.0, "TOP WINS"), (14.0, "TOP STREAK"))):
        lp = Vector((sx, -21.0, 0))
        fz = face_rz(lp, (0, 0))  # board front faces the plaza
        mx = Matrix.Translation(lp) @ Matrix.Rotation(fz, 4, "Z")
        m2 = MB("tmp")
        for px in (-5.2, 5.2):
            m2.box((px, 0, 6.0), (0.9, 0.9, 12.0), M["plank_dark"])
        m2.box((0, 0, 8.3), (11.4, 0.7, 7.8), M["trim"])
        m2.box((0, 0.3, 8.3), (10.8, 0.25, 7.2), M["navy"])
        m2.box((0, -0.12, 8.3), (10.6, 0.7, 7.0), M["navy"])
        m2.box((0, -0.5, 11.0), (9.6, 0.1, 1.1), M["screen_gold"])
        for row in range(4):
            m2.box((0.6, -0.5, 9.4 - row * 1.35), (8.0, 0.1, 0.8), M["screen"])
            m2.box((-4.3, -0.5, 9.4 - row * 1.35), (0.8, 0.1, 0.8), M[("cr_gold", "white", "coral", "white")[row]])
        m2.crystal((0, 0, 12.2), (0, 0, 1), 0.8, 1.0, M["cr_gold"], tip=1.0)
        mb.add(m2.v, m2.f, [m2.mats[i] for i in m2.fm], mx)
        tt = text(title, mx @ Vector((0, -0.62, 11.0)), 0.8, M["navy"], extrude=0.02)
        tt.rotation_euler = (math.pi / 2, 0, fz)

    # Daily reward chest (left of spawn) and codes board (right of spawn)
    dp = Vector((-12.5, -12.0, 0))
    dz = face_rz(dp, SPAWN)
    mx = Matrix.Translation(dp) @ Matrix.Rotation(dz, 4, "Z")
    m2 = MB("tmp")
    m2.prism((0, 0, 0), 2.6, 0.8, M["marble"], n=8)
    m2.box((0, 0, 1.6), (3.2, 2.2, 1.6), M["plank"])
    m2.prism((0, 0, 0), 1.1, 3.2, M["plank"], n=8, mx=Matrix.Translation((-1.6, 0, 2.4)) @ Matrix.Rotation(math.pi / 2, 4, "Y"), sx=1.0, sy=1.0)
    for bx in (-1.0, 1.0):
        m2.box((bx, 0, 2.0), (0.35, 2.3, 2.5), M["gold_metal"])
    m2.box((0, -1.15, 2.2), (0.6, 0.15, 0.7), M["gold_metal"])
    mb.add(m2.v, m2.f, [m2.mats[i] for i in m2.fm], mx)
    tdl = text("DAILY", mx @ Vector((0, 0, 5.4)), 1.2, M["cr_gold"], extrude=0.12)
    tdl.rotation_euler = (math.pi / 2, 0, dz)

    cp = Vector((12.5, -12.0, 0))
    cz = face_rz(cp, SPAWN)
    mx = Matrix.Translation(cp) @ Matrix.Rotation(cz, 4, "Z")
    m2 = MB("tmp")
    m2.beam((-1.6, 0.6, 0), (-1.0, 0.0, 5.6), 0.35, 0.35, M["plank_dark"])
    m2.beam((1.6, 0.6, 0), (1.0, 0.0, 5.6), 0.35, 0.35, M["plank_dark"])
    m2.beam((0, 1.6, 0), (0, 0.3, 5.4), 0.35, 0.35, M["plank_dark"])
    m2.box((0, -0.1, 3.8), (4.6, 0.3, 3.2), M["board"])
    m2.box((0, -0.1, 3.8), (4.9, 0.25, 3.5), M["plank"])
    mb.add(m2.v, m2.f, [m2.mats[i] for i in m2.fm], mx)
    tc = text("CODES", mx @ Vector((0, -0.32, 4.0)), 1.05, M["white"], extrude=0.02)
    tc.rotation_euler = (math.pi / 2, 0, cz)

    # Collection index: arc of pedestals with glassies (owned = glass, locked = silhouette)
    ic = Vector((38.0, -5.0, 0))
    slots = [("pop", None), ("jam", None), ("prism", None), ("pop", "silhouette"), ("jam", "silhouette"), ("prism", "silhouette")]
    look = Vector((0.0, -6.0, 0))
    base_ang = math.atan2(look.y - ic.y, look.x - ic.x)
    for k, (gid, mono) in enumerate(slots):
        ang = base_ang + math.radians(-50 + k * 20)
        p = ic + Vector((math.cos(ang), math.sin(ang), 0)) * 7.5
        mb.prism((p.x, p.y, 0), 1.3, 3.0, M["marble"], n=8)
        mb.prism((p.x, p.y, 3.0), 1.5, 0.3, M["trim"], n=8)
        place_glassy(gid, Matrix.Translation((p.x, p.y, 3.3 + 2.5)) @ Matrix.Rotation(ang, 4, "Z"), mono=mono)
    bz = math.atan2(look.y - ic.y, look.x - ic.x) + math.pi / 2
    mxb = Matrix.Translation(ic) @ Matrix.Rotation(bz, 4, "Z")
    m2 = MB("tmp")
    m2.box((0, 1.0, 4.5), (14, 0.8, 9), M["navy"])
    m2.box((0, 0.55, 8.4), (12, 0.2, 1.6), M["screen_gold"])
    mb.add(m2.v, m2.f, [m2.mats[i] for i in m2.fm], mxb)
    ti = text("INDEX", mxb @ Vector((0, 0.4, 8.4)), 1.3, M["navy"], extrude=0.05)
    ti.rotation_euler = (math.pi / 2, 0, bz)

    # Champion statue (gold avatar on a pedestal, crystal ring) on the left front
    chp = Vector((0.0, -22.6, 0))
    mb.prism((chp.x, chp.y, 0), 4.2, 1.0, M["marble"], n=8)
    mb.prism((chp.x, chp.y, 1.0), 3.0, 2.6, M["marble"], n=8)
    mb.prism((chp.x, chp.y, 3.6), 3.4, 0.4, M["trim"], n=8)
    avatar(mb, chp.x, chp.y, face_rz(chp, (0, 0)), z=4.0, s=1.5, mono="gold_metal")
    for k in range(7):
        ang = 2 * math.pi * k / 7
        mb.crystal((chp.x + math.cos(ang) * 5.0, chp.y + math.sin(ang) * 5.0, 0), (math.cos(ang) * 0.35, math.sin(ang) * 0.35, 1),
                   0.6, 2.0 + (k % 2), M["cr_gold"])
    th = text("CHAMPION", (chp.x, chp.y, 13.6), 1.4, M["cr_gold"], extrude=0.15)
    th.rotation_euler = (math.pi / 2, 0, face_rz(chp, (0, 0)))
    # gold trophy glassy held against the chest
    tz = face_rz(chp, (0, 0))
    hold = Matrix.Translation((chp.x, chp.y, 4.0)) @ Matrix.Rotation(tz, 4, "Z") @ Matrix.Translation((0, -1.85, 6.4))
    place_glassy("prism", hold @ Matrix.Scale(1.5, 4), mono="gold_metal")

    # greenery, rocks, lamps, rim crystals
    for p in ((-41, -15), (42, 14), (-27, -22), (27, -22), (-40, 6)):
        tree(mb, p, r, s=r.uniform(0.9, 1.15))
    for p in ((-36, -5), (33, -19), (-33, 21), (35, 21)):
        rocks(mb, (p[0], p[1], 0), r, 3, 1.2)
    for p in ((-5.5, 10), (5.5, 10), (-5.5, 26), (5.5, 26)):
        lamp(mb, *p, col="gold")
    for p, cols in (((-43, 15), ["pink", "violet"]), ((44, -18), ["cyan", "violet"]), ((-16, 23), ["violet", "cyan"]),
                    ((16, 23), ["pink", "gold"])):
        crystal_cluster(mb, (p[0], p[1], 0), 1.0, cols, r)
    # a few players in the lobby
    for p in ((-8.5, 14), (9, 16), (-18, -9), (19, -8), (30, -8)):
        avatar(mb, p[0], p[1], r.uniform(0, 6.28))
    mb.build()
    sg = MB("ArenaGate")
    for sx in (-5.2, 5.2):
        sg.box((sx, 26.5, 5.0), (0.9, 0.9, 10.0), M["plank_dark"])
        sg.crystal((sx, 26.5, 10.0), (0, 0, 1), 0.6, 0.8, M["cr_cyan"], tip=0.9)
    sg.box((0, 26.5, 8.6), (11.6, 0.6, 2.2), M["navy"])
    sg.box((0, 26.5, 8.6), (12.2, 0.4, 2.6), M["trim"])
    sg.build()
    t2 = text("ARENAS", (0, 26.1, 8.6), 1.5, M["white"], extrude=0.1)
    t2.rotation_euler = (math.pi / 2, 0, 0)


PAIRS = [("pop", "jam"), ("prism", "pop"), ("jam", "prism"), ("pop", "prism"), ("jam", "pop"), ("prism", "jam")]
POSES = [(40, 0), (0, 0), (8, 30), (0, 0), (25, 0), (0, 38)]  # (A outward deg, B outward deg)
ACTIVE_ARENAS = {0, 2, 4, 5}


def build_arena_islands():
    idx = 0
    for ii, isl in enumerate(ARENA_ISLANDS):
        with lifted(isl["z"]):
            idx = _arena_island(ii, isl, idx)


def _arena_island(ii, isl, idx):
    if True:
        strings = MB("Strings_%d" % (ii + 1))
        cy = isl["cy"]
        pts = island("Isle_Arena%d" % (ii + 1), isl, seed=10 + ii, crystals_under=24)
        fence("Fence_Arena%d" % (ii + 1), isl, pts, [(0, cy - isl["b"]), (0, cy + isl["b"])])
        r = random.Random(100 + ii)
        mb = MB("Arena%d_Props" % (ii + 1))
        mb.box((0, cy, 0.0), (17.5, 2 * isl["b"] + 1, 0.12), M["path"])
        for side in (-1, 1):
            ax = side * ARENA_X
            smx = Matrix.Translation((ax, cy, STAND_Z)) @ Matrix.Rotation(math.pi / 2, 4, "Z")
            stand_instance("Stand_%d" % (idx + 1), smx)
            # stone apron so the pen sits on something
            mb.prism((ax, cy, -0.06), 15.6, 0.14, M["plaza_dark"], n=8, rz=math.pi / 8)
            ga, gb = PAIRS[idx]
            pa, pb = POSES[idx]
            hang(strings, smx, "A", ga, pa)
            hang(strings, smx, "B", gb, pb)
            pads = {}
            for s, lx in (("A", -PAD_LOCAL), ("B", PAD_LOCAL)):
                p = smx @ Vector((lx, 0, 0))
                p.z = 0
                queue_pad(mb, p, s)
                pads[s] = p
            # arena number plate on top of the crossbar, facing the walkway
            plate = Vector((ax, cy, 19.3))
            fz = math.pi / 2 if side < 0 else -math.pi / 2
            mb.box(plate, (0.5, 4.2, 3.0), M["navy"])
            mb.box(plate + Vector((0, 0, -1.6)), (0.6, 1.2, 0.6), M["plank_dark"])
            tn = text(str(idx + 1), plate + Vector((-side * 0.3, 0, 0)), 2.4, M["white"], extrude=0.05)
            tn.rotation_euler = (math.pi / 2, 0, fz)
            if idx in ACTIVE_ARENAS:
                for s in ("A", "B"):
                    p = pads[s]
                    avatar(mb, p.x, p.y, face_rz(p, (ax, cy)), z=0.43)
                # spectators on the walkway side and the outer bleacher
                for k in range(r.randint(2, 4)):
                    sxp = side * r.uniform(3.0, 7.5)
                    syp = cy + r.uniform(-9, 9)
                    cam = CAMS["arena"][0]
                    if math.hypot(sxp - cam[0], syp - cam[1]) < 16:  # keep the arena close-up clear
                        continue
                    avatar(mb, sxp, syp, face_rz((sxp, syp), (ax, cy)) + r.uniform(-0.2, 0.2))
            # outer two-step bleacher
            ox = side * 42.0
            mb.box((ox, cy, 0.5), (3.0, 16, 1.0), M["plank"])
            mb.box((ox + side * 1.5, cy, 1.0), (3.0, 16, 2.0), M["plank_dark"])
            if idx in ACTIVE_ARENAS and r.random() < 0.8:
                avatar(mb, ox - side * 0.2, cy + r.uniform(-5, 5), face_rz((ox, cy), (ax, cy)), z=1.0)
            idx += 1
        # lamps along the walkway + rim crystals in the corners
        for ly in (cy - 18, cy + 18):
            for lx in (-7.5, 7.5):
                lamp(mb, lx, ly, col=("cyan", "pink", "violet")[ii])
        cols = [["cyan", "violet"], ["pink", "gold"], ["violet", "pink"]][ii]
        for sx in (-1, 1):
            for sy in (-1, 1):
                crystal_cluster(mb, (sx * 40.5, cy + sy * 17.5, 0), 0.8, cols, r, n_small=3)
        tree(mb, (r.choice((-1, 1)) * 43, cy + r.uniform(-4, 4)), r, 0.8) if ii == 1 else None
        mb.build()
        strings.build()
    return idx


def build_featured():
    with lifted(FEATURED["z"]):
        _featured()


def _featured():
    isl = FEATURED
    cy = isl["cy"]
    pts = island("Isle_Featured", isl, seed=21, crystals_under=36, exp=3.0)
    fence("Fence_Featured", isl, pts, [(0, cy - isl["b"])])
    r = random.Random(77)
    mb = MB("Featured_Props")
    smx = Matrix.Translation((0, cy, STAND_Z + 0.5)) @ Matrix.Scale(FEAT_SCALE, 4)
    # raised gold-trimmed stage
    mb.prism((0, cy, -0.05), 19.5, 0.35, M["trim"], n=8, rz=math.pi / 8)
    mb.prism((0, cy, 0.3), 18.6, 0.3, M["marble"], n=8, rz=math.pi / 8)
    stand_instance("Stand_Featured", smx)
    strings = MB("Strings_Featured")
    hang(strings, smx, "A", "prism", 42)
    hang(strings, smx, "B", "pop", 0)
    strings.build()
    for s, sx in (("A", -1), ("B", 1)):
        p = smx @ Vector((sx * FEAT_PAD_LOCAL.x, FEAT_PAD_LOCAL.y, 0))
        p.z = 0
        queue_pad(mb, p, s)
        avatar(mb, p.x, p.y, face_rz(p, (0, cy)), z=0.43)
    # path from the bridge to the arch and a stone viewing apron in front of the stage
    mb.box((0, cy - 22.0, 0.0), (12, 8, 0.12), M["path"])
    # back bleacher crescent
    for k in range(7):
        ang = math.radians(90 - 54 + k * 18)
        for tier, (rad, h) in enumerate(((23.0, 1.0), (26.0, 2.0))):
            p = Vector((math.cos(ang) * rad * 1.05, cy + math.sin(ang) * rad * 0.82, 0))
            mb.box((p.x, p.y, h / 2), (8.6, 2.8, h), M["plank" if tier == 0 else "plank_dark"],
                   rz=ang + math.pi / 2)
        if k % 2 == 0:
            p = Vector((math.cos(ang) * 23.0 * 1.05, cy + math.sin(ang) * 23 * 0.82, 0))
            avatar(mb, p.x, p.y, face_rz(p, (0, cy)), z=1.0)
    # crystal arch at the entrance
    ay = cy - isl["b"] + 4.5
    cb = MB("CrystalArch")
    for sx in (-1, 1):
        base = Vector((sx * 7.5, ay, 0))
        crystal_cluster(cb, base, 1.6, ["pink", "violet", "gold"], r, n_small=4, lean=0.05)
        cb.crystal(base + Vector((0, 0, 0)), (sx * -0.06, 0, 1), 1.3, 12, M["cr_violet"])
    for k in range(9):
        t = k / 8
        ang = math.pi * t
        p = Vector((-math.cos(ang) * 7.5, ay, 13.0 + math.sin(ang) * 6.0))
        d = Vector((-math.cos(ang), 0, math.sin(ang)))
        cb.crystal(p - d * 1.2, d, 1.1 if k % 2 else 1.4, 2.0, M["cr_" + ("gold" if k % 2 else "pink")])
    cb.crystal(Vector((0, ay, 18.0)), (0, 0, 1), 2.0, 3.5, M["cr_gold"])
    cb.build()
    tf = text("FEATURED", (0, ay - 1.6, 23.6), 1.7, M["cr_gold"], extrude=0.2)
    tf.rotation_euler = (math.pi / 2, 0, 0)
    # tall backdrop crystals behind the stage
    for p, s, cols in (((-22, cy + 14), 2.4, ["violet", "pink"]), ((22, cy + 13), 2.2, ["cyan", "violet"]),
                       ((0, cy + 22), 2.0, ["gold", "pink"]), ((-30, cy + 2), 1.3, ["pink", "gold"]),
                       ((30, cy + 1), 1.3, ["cyan", "gold"])):
        crystal_cluster(cb2 := MB("Backdrop_%d" % int(p[0])), (p[0], p[1], 0), s, cols, r, n_small=5)
        cb2.build()
    for lx in (-6.5, 6.5):
        lamp(mb, lx, cy - 19, col="gold")
    mb.build()


def build_bridges():
    spans = []
    prev = LOBBY
    for isl in ARENA_ISLANDS + [FEATURED]:
        spans.append((prev["cy"] + prev["b"], isl["cy"] - isl["b"], prev["z"], isl["z"]))
        prev = isl
    for k, (a, b, za, zb) in enumerate(spans):
        bridge("Bridge_%d" % k, a, b, za, zb)
    return spans


def build_clouds():
    r = random.Random(5)
    mb = MB("Clouds")

    def cloud(c, s):
        for _ in range(r.randint(4, 7)):
            off = Vector((r.uniform(-2.2, 2.2), r.uniform(-1.2, 1.2), r.uniform(-0.2, 0.6))) * s
            rr = s * r.uniform(0.9, 1.6)
            mb.ico(Vector(c) + off, rr, M["cloud"], sub=2, scale=(1.25, 1.0, 0.62), rz=r.random() * 6)

    for _ in range(110):  # sea of clouds below
        cloud((r.uniform(-170, 170), r.uniform(-130, 340), r.uniform(-75, -48)), r.uniform(5, 11))
    for _ in range(16):  # drifting clouds level with / below the islands, off to the sides
        sx = r.choice((-1, 1))
        cloud((sx * r.uniform(75, 160), r.uniform(-60, 300), r.uniform(-30, -6)), r.uniform(3, 6))
    mb.build()


# ---------------------------------------------------------------------------
# World, light, cameras, render
# ---------------------------------------------------------------------------
def setup_world():
    scene = bpy.context.scene
    w = bpy.data.worlds.new("CI_World")
    scene.world = w
    try:
        w.use_nodes = True
    except Exception:  # noqa: BLE001
        pass
    nt = w.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg_cam = nt.nodes.new("ShaderNodeBackground")
    bg_amb = nt.nodes.new("ShaderNodeBackground")
    lp = nt.nodes.new("ShaderNodeLightPath")
    mix = nt.nodes.new("ShaderNodeMixShader")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    mr = nt.nodes.new("ShaderNodeMapRange")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    mr.inputs["From Min"].default_value = -0.35
    mr.inputs["From Max"].default_value = 0.7
    cr = ramp.color_ramp
    cr.elements[0].position = 0.0
    cr.elements[0].color = srgb("#BFDDFB")  # haze below (cloud sea glow)
    cr.elements[1].position = 1.0
    cr.elements[1].color = srgb("#4C9BEA")
    cr.elements.new(0.33).color = srgb("#FFE0B8")  # warm horizon
    cr.elements.new(0.22).color = srgb("#D9E6FF")
    cr.elements.new(0.55).color = srgb("#9CCBF5")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    nt.links.new(mr.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg_cam.inputs["Color"])
    bg_amb.inputs["Color"].default_value = srgb("#B8D8F5")
    bg_amb.inputs["Strength"].default_value = 0.8
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs["Fac"])
    nt.links.new(bg_amb.outputs[0], mix.inputs[1])
    nt.links.new(bg_cam.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])

    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.8
    sun.angle = math.radians(3)
    sun.color = srgb("#FFDDB0")[:3]
    so = bpy.data.objects.new("Sun", sun)
    # golden afternoon sun from behind spawn, a little to the left: faces toward spawn are lit
    so.rotation_euler = Euler((math.radians(55), 0, math.radians(-30)))
    scene.collection.objects.link(so)


def setup_render():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cy = scene.cycles
    cy.device = "CPU"
    cy.samples = SAMPLES
    cy.use_adaptive_sampling = True
    cy.max_bounces = 8
    cy.diffuse_bounces = 2
    cy.glossy_bounces = 3
    cy.transmission_bounces = 8
    cy.transparent_max_bounces = 8
    try:
        cy.use_denoising = True
        cy.denoiser = "OPENIMAGEDENOISE"
    except Exception as exc:  # noqa: BLE001
        print("denoiser unavailable:", exc)
        cy.use_denoising = False
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = RES_PCT
    scene.render.image_settings.file_format = "PNG"
    vs = scene.view_settings
    try:
        vs.view_transform = _arg("--vt", "Standard")
        vs.look = _arg("--look", "Medium High Contrast")
    except Exception:  # noqa: BLE001
        try:
            vs.look = "Punchy"
        except Exception:  # noqa: BLE001
            pass
    vs.exposure = float(_arg("--exp", "-0.3"))


def camera(name, loc, target, lens):
    scene = bpy.context.scene
    cd = bpy.data.cameras.new(name)
    cd.lens = lens
    cd.clip_start = 0.3
    cd.clip_end = 5000
    co = bpy.data.objects.new(name, cd)
    co.location = loc
    co.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(co)
    return co


CAMS = {  # name: (location, look-at target, lens mm)
    "aerial": ((-150.0, -105.0, 92.0), (2.0, 98.0, -10.0), 30.0),
    "spawn": ((SPAWN.x, SPAWN.y - 3.0, 6.0), (0.0, 80.0, 6.5), 18.0),
    "arena": ((8.0, 44.0, 2.0 + 11.0), (-24.0, 55.0, 2.0 + 9.0), 24.0),
}


CAMS_DEBUG = {  # not rendered by default; handy for checking other corners (--views featured,hall)
    "featured": ((26.0, 172.0, 30.0), (0.0, 212.0, 14.0), 26.0),
    "hall": ((10.0, 10.0, 14.0), (0.0, -20.0, 5.0), 24.0),
}
CAMS.update(CAMS_DEBUG)


def render_all():
    scene = bpy.context.scene
    os.makedirs(OUT_DIR, exist_ok=True)
    for name in VIEWS:
        if name not in CAMS:
            print("unknown view", name, "- choose from", ", ".join(CAMS))
            continue
        loc, tgt, lens = CAMS[name]
        scene.camera = camera("Cam_" + name, loc, tgt, lens)
        png = os.path.join(OUT_DIR, name + ".png")
        scene.render.filepath = png
        try:
            bpy.ops.render.render(write_still=True)
        except RuntimeError as exc:
            if not scene.cycles.use_denoising:
                raise
            print("render failed with denoiser, retrying without:", exc)
            scene.cycles.use_denoising = False
            bpy.ops.render.render(write_still=True)
        jpg = os.path.join(OUT_DIR, name + ".jpg")
        subprocess.run(
            ["/usr/bin/python3", "-c",
             "import sys;from PIL import Image;Image.open(sys.argv[1]).convert('RGB').save(sys.argv[2],quality=85)",
             png, jpg],
            check=True,
        )
        os.remove(png)
        print("wrote", jpg)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_materials()
    load_assets()
    build_lobby()
    build_arena_islands()
    build_featured()
    spans = build_bridges()
    build_clouds()
    setup_world()
    setup_render()
    print("bridges (y0, y1):", spans)
    last = ARENA_ISLANDS[-1]
    far = last["cy"] + PAD_LOCAL
    walk_n = (last["cy"] - last["b"] - SPAWN.y) + math.hypot(ARENA_X, far - (last["cy"] - last["b"]))
    fp = Vector((FEAT_PAD_LOCAL.x * FEAT_SCALE, FEATURED["cy"] + FEAT_PAD_LOCAL.y * FEAT_SCALE, 0))
    walk_f = (FEATURED["cy"] - FEATURED["b"] - SPAWN.y) + math.hypot(fp.x, fp.y - (FEATURED["cy"] - FEATURED["b"]))
    print("walk spawn -> farthest normal pad ~%.0f studs (%.1f s), -> featured pad ~%.0f studs (%.1f s)"
          % (walk_n, walk_n / 16, walk_f, walk_f / 16))
    if os.environ.get("CI_SAVE"):
        bpy.ops.wm.save_as_mainfile(filepath=os.environ["CI_SAVE"])
    render_all()


main()
