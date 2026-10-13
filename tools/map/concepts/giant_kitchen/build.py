"""Glass Clash map concept: "Toy-Sized Kitchen" (slug: giant_kitchen).

Players are toy-sized on a giant kitchen counter. Eight arenas sit on giant cutting
boards in two rows facing a tea-towel runner (the main walkway); the featured arena
sits on a round serving tray at the far end. The lobby is a woven placemat with a
gumball-machine crate row, a toaster shop, a cookie-jar daily reward, a spice-rack
index, recipe-card leaderboards, a sticky-note codes board and a champion on a cake
stand. A big sunny window sits above the backsplash behind the arena row.

Builds everything from scratch in headless Blender (bpy module, Cycles CPU) and
renders three views (aerial, spawn, arena) to docs/art/concepts/giant_kitchen/.

Run:  <bpyenv>/bin/python build.py          (from any directory)
Optional env vars for quick iteration:
  GK_VIEWS=aerial,spawn,arena   which views to render (default all)
  GK_SAMPLES=24                 Cycles samples
  GK_SCALE=100                  resolution percentage
  GK_SAVE=/path/file.blend      also save the built scene

Units are studs (1 Blender unit = 1 stud), Z is up, counter top is Z = 0.
+X runs from the lobby (left) down the arena row to the featured tray (right).
+Y points to the back wall (backsplash + window); -Y is the open front edge.
"""

import bpy  # noqa: I001  (bpy must be imported before bmesh/mathutils)
import bmesh
import math
import os
import random
import subprocess
from mathutils import Euler, Matrix, Vector

REPO = "/home/user/CrystalCoveBlenderWork"
OUT_DIR = os.path.join(REPO, "docs/art/concepts/giant_kitchen")
STAND_BLEND = os.path.join(REPO, "assets/blender/map/clash_stand.blend")
STAND_COLLECTION = "GlassClash_ClashStand.001"
GLASSY_DIR = os.path.join(REPO, "assets/blender/glassies")

VIEWS = [v for v in os.environ.get("GK_VIEWS", "aerial,spawn,arena").split(",") if v]
SAMPLES = int(os.environ.get("GK_SAMPLES", "24"))
RES_PCT = int(os.environ.get("GK_SCALE", "100"))

random.seed(11)

# ---------------------------------------------------------------------------
# Layout constants (studs). Measured Clash Stand: 28.68 x 28.68 x 17.8
# (octagon pen floor top at origin Z=0, floor 0.4 thick, pen walls 2.4 high,
#  crossbar top 16.95, post caps 17.4, hooks at X=+-1.5, hook bottom Z=15.02).
# ---------------------------------------------------------------------------
X_WALL_L, X_WALL_R = -112.0, 246.0  # kitchen side walls
Y_FRONT, Y_BACK = -75.0, 78.0  # counter front edge / backsplash face
BOARD_TOP = 1.2  # cutting board thickness
ARENA_X = [18.0, 56.0, 94.0, 132.0]  # 38-stud pitch; back row + front row = 8 arenas
BOARD_HALF_X = 17.0
BOARD_Y0, BOARD_Y1 = 9.0, 53.0  # board extent from the aisle (mirrored for the front row)
PEN_Y = 34.0  # stand centre distance from the aisle centre line
PAD_X, PAD_Y = 7.0, 14.0  # queue pads (bottle caps) relative to the arena centre
AISLE_HALF = 8.0  # tea-towel runner is 16 wide
FEAT_C = Vector((180.0, 0.0))
FEAT_R = 29.0
FEAT_TOP = 1.0
FEAT_SCALE = 1.25
SPAWN = Vector((-60.0, 0.0))
MAT_C = Vector((-50.0, 0.0))  # woven placemat = lobby plaza
MAT_R = 36.0
CHAMP = Vector((-34.0, -15.0))
HOOK_LOCAL = {"A": Vector((-1.5, 0.0, 15.02)), "B": Vector((1.5, 0.0, 15.02))}
STRING_LEN = 5.0  # Balance.Feel.StringLength
WIN_X0, WIN_X1, WIN_Z0, WIN_Z1 = 6.0, 158.0, 54.0, 122.0  # window opening
SPLASH_TOP = 44.0  # top of the tiled backsplash
WALL_TOP = 140.0

# ---------------------------------------------------------------------------
# Scene reset
# ---------------------------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def coll(name):
    c = bpy.data.collections.new(name)
    scene.collection.children.link(c)
    return c


C_ROOM = coll("Room")
C_LOBBY = coll("Lobby")
C_ARENAS = coll("Arenas")
C_FEAT = coll("Featured")
C_PROPS = coll("Props")
C_LIFE = coll("Life")


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------
def srgb(h):
    h = h.lstrip("#")
    out = []
    for i in range(3):
        c = int(h[i * 2 : i * 2 + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


def mat(name, hex_col, rough=0.85, emit=0.0, metal=0.0):
    m = bpy.data.materials.new(name)
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = srgb(hex_col)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if emit > 0:
        p.inputs["Emission Color"].default_value = srgb(hex_col)
        p.inputs["Emission Strength"].default_value = emit
    m.diffuse_color = srgb(hex_col)
    return m


def glass_mat(name, hex_col, rough=0.03, emit=0.25):
    """Preview-only glossy tinted glass (in Roblox: Glass material, Transparency ~0.3)."""
    m = bpy.data.materials.new(name)
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = srgb(hex_col)
    p.inputs["Roughness"].default_value = rough
    p.inputs["IOR"].default_value = 1.45
    p.inputs["Transmission Weight"].default_value = 0.8
    p.inputs["Coat Weight"].default_value = 0.6
    p.inputs["Coat Roughness"].default_value = 0.02
    p.inputs["Emission Color"].default_value = srgb(hex_col)
    p.inputs["Emission Strength"].default_value = emit
    return m


PAL = {
    # room
    "counter": "#F6EBDC",
    "counter_edge": "#E4D3BE",
    "speck_a": "#D8C3AA",
    "speck_b": "#9FD3C7",
    "speck_c": "#F3B0A6",
    "grout": "#E3D8C6",
    "tile": "#FFFDF6",
    "tile_mint": "#8ED8C6",
    "tile_coral": "#F59C8C",
    "wall": "#FFE2A6",
    "frame": "#FFFFFF",
    "curtain": "#F7A3A8",
    "curtain_b": "#FFF4F0",
    "cab": "#97D3C2",
    "cab_dark": "#78BFAC",
    "brass": "#E7B04B",
    "floor_a": "#F4E2C4",
    "floor_b": "#E59C7E",
    # boards / walkway
    "maple": "#EBC48E",
    "maple_dk": "#D2A06A",
    "walnut": "#C08353",
    "walnut_dk": "#9C6338",
    "towel": "#FFF8EE",
    "towel_red": "#E8505B",
    "towel_blue": "#4C8FE0",
    "weave": "#E8C27A",
    "weave_dk": "#CE9F57",
    "cork": "#C9935B",
    "cork_dk": "#A97440",
    "tray": "#3FB8AF",
    "gold": "#F2C14E",
    "pad_a": "#3EC6FF",
    "pad_b": "#FF8A4C",
    "white": "#FFFFFF",
    "plate_rim": "#5BA4E6",
    # props
    "gum_red": "#E8434B",
    "gum_blue": "#3E8EDE",
    "gum_purple": "#9B6BE0",
    "chrome": "#C9D3DE",
    "toaster": "#FF8F6B",
    "toast": "#F2C37A",
    "crust": "#B87333",
    "jar_cream": "#FFF1DC",
    "jar_blue": "#5BA4E6",
    "cookie": "#D49A5A",
    "choc": "#5A3A28",
    "note": "#FFE066",
    "note_line": "#E8B93C",
    "card": "#FFFDF8",
    "card_line": "#B8D8F0",
    "ink": "#3B3B4F",
    "wood": "#D9A66B",
    "wood_dk": "#A8743F",
    "kettle": "#E8434B",
    "mug_y": "#FFD166",
    "mug_t": "#4ECDC4",
    "mug_p": "#FF9FB2",
    "can_mint": "#A8E6CF",
    "can_peach": "#FFC8A2",
    "can_lav": "#CDB8F2",
    "orange": "#FF9F1C",
    "apple": "#E63946",
    "green": "#8AC926",
    "banana": "#FFE066",
    "leaf": "#4FB453",
    "leaf_lt": "#79CF5A",
    "pot": "#D9754C",
    "book_a": "#5BA4E6",
    "book_b": "#F2C14E",
    "book_c": "#E8505B",
    "book_d": "#6CCB7E",
    "sponge": "#FFD34E",
    "sponge_g": "#4FB453",
    "lemon": "#FFE45C",
    "statue": "#F2C14E",
    # pastel plastic cutting boards (arena colour codes)
    "bd_mint": "#A6E3C8",
    "bd_mint_dk": "#7FCDAA",
    "bd_sky": "#A9D8F5",
    "bd_sky_dk": "#7FBFE8",
    "bd_butter": "#FFE39A",
    "bd_butter_dk": "#EFC965",
    "bd_lilac": "#D8C8F6",
    "bd_lilac_dk": "#B9A3EC",
    "room": "#F6DDB0",
}
M = {k: mat("GK_" + k, v) for k, v in PAL.items()}
M["chrome"] = mat("GK_chrome_m", PAL["chrome"], rough=0.35, metal=0.6)
M["pad_a_glow"] = mat("GK_pad_a_e", PAL["pad_a"], emit=3.0)
M["pad_b_glow"] = mat("GK_pad_b_e", PAL["pad_b"], emit=3.0)
M["gold_glow"] = mat("GK_gold_e", PAL["gold"], emit=2.0)
M["spawn_glow"] = mat("GK_spawn_e", "#8FE3FF", emit=2.5)
M["daily_glow"] = mat("GK_daily_e", "#FFD166", emit=2.0)
M["statue"] = mat("GK_statue_m", "#F0A818", rough=0.35, emit=0.1)
M["gold"] = mat("GK_gold_m", PAL["gold"], rough=0.5, metal=0.4)

GLASS = {
    "pop": glass_mat("GC_Glass_pop", "#8FE3FF"),
    "jam": glass_mat("GC_Glass_jam", "#FF6B8B"),
    "prism": glass_mat("GC_Glass_prism", "#C9A8FF"),
}
# gumball globe: clear but frosted, so it never out-shines the glassies
M["globe"] = glass_mat("GK_globe", "#F4FBFF", rough=0.18, emit=0.0)
M["string"] = mat("GK_string", "#FFFFFF", rough=0.9)
M["bubble"] = mat("GK_bubble", "#FFFFFF", rough=0.2, emit=0.6)


def nodes_mat(name):
    m = bpy.data.materials.new(name)
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    return m, nt


def beam_mat(name, hex_col, strength, fac):
    """Soft see-through light shaft (window sun shafts, champion spotlight)."""
    m, nt = nodes_mat(name)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = srgb(hex_col)
    em.inputs["Strength"].default_value = strength
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.inputs["Fac"].default_value = fac
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return m


M["beam"] = beam_mat("GK_beam", "#FFF0B0", 1.0, 0.12)
M["shaft"] = beam_mat("GK_shaft", "#FFE6B0", 1.0, 0.07)


def sky_mat():
    """Emissive garden-sky backdrop seen through the window (vertical gradient)."""
    m, nt = nodes_mat("GK_sky")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Strength"].default_value = 1.6
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 40.0
    mr.inputs["From Max"].default_value = 150.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = srgb("#FFE9B8")
    ramp.color_ramp.elements[1].color = srgb("#7CC8F2")
    nt.links.new(geo.outputs["Position"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    nt.links.new(mr.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


M["sky"] = sky_mat()
M["out_hill"] = mat("GK_out_hill", "#9BD67A", emit=0.9)
M["out_tree"] = mat("GK_out_tree", "#5FB65A", emit=0.8)
M["out_trunk"] = mat("GK_out_trunk", "#A47148", emit=0.6)
M["out_fence"] = mat("GK_out_fence", "#FFFFFF", emit=0.9)


# ---------------------------------------------------------------------------
# Mesh builder: many primitives -> one mesh with several materials (flat shaded)
# ---------------------------------------------------------------------------
def rot_to(d):
    """Rotation matrix (3x3) that maps +Z onto direction d."""
    return Vector(d).normalized().to_track_quat("Z", "Y").to_matrix()


class MB:
    def __init__(self):
        self.bm = bmesh.new()
        self.mats = []
        self.smooth_mats = set()

    def _mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def _tag(self, verts, m):
        mi = self._mi(m)
        faces = set()
        for v in verts:
            faces.update(v.link_faces)
        for f in faces:
            f.material_index = mi

    def box(self, c, s, m, rz=0.0, rot=None):
        """Box centred at c with full size s."""
        r = rot if rot is not None else Euler((0, 0, rz)).to_matrix()
        mx = Matrix.LocRotScale(Vector(c), r.to_quaternion(), Vector(s))
        g = bmesh.ops.create_cube(self.bm, size=1.0, matrix=mx)
        self._tag(g["verts"], m)

    def boxz(self, x0, x1, y0, y1, z0, z1, m):
        """Axis-aligned box from min/max extents."""
        self.box(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0), m)

    def cyl(self, base, r, h, m, seg=12, r2=None, rot=None, rz=0.0):
        """Cylinder / cone standing on `base` (along local +Z, or along `rot`)."""
        r2 = r if r2 is None else r2
        R = (rot if rot is not None else Matrix.Identity(3)) @ Euler((0, 0, rz)).to_matrix()
        mx = Matrix.Translation(Vector(base)) @ R.to_4x4() @ Matrix.Translation((0, 0, h / 2))
        g = bmesh.ops.create_cone(
            self.bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=r2, depth=h, matrix=mx
        )
        self._tag(g["verts"], m)

    def rod(self, a, b, r, m, seg=6):
        a, b = Vector(a), Vector(b)
        d = b - a
        self.cyl(a, r, d.length, m, seg=seg, rot=rot_to(d))

    def ball(self, c, r, m, sub=1, scale=(1, 1, 1), rot=(0, 0, 0)):
        mx = Matrix.LocRotScale(Vector(c), Euler(rot), Vector(scale))
        g = bmesh.ops.create_icosphere(self.bm, subdivisions=sub, radius=r, matrix=mx)
        self._tag(g["verts"], m)

    def uvball(self, c, r, m, seg=16, rings=10, scale=(1, 1, 1)):
        mx = Matrix.LocRotScale(Vector(c), Euler((0, 0, 0)), Vector(scale))
        g = bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=rings, radius=r, matrix=mx)
        self._tag(g["verts"], m)

    def lathe(self, base, prof, m, seg=16, mx=None, mats=None):
        """Revolve profile [(r, z), ...] around local Z. r == 0 points collapse to the axis.
        `mats` optionally gives a material per profile segment."""
        base_mx = Matrix.Translation(Vector(base)) @ (mx if mx is not None else Matrix.Identity(4))
        rings = []
        for r, z in prof:
            if r < 1e-5:
                rings.append([self.bm.verts.new(base_mx @ Vector((0, 0, z)))])
            else:
                ring = []
                for i in range(seg):
                    a = 2 * math.pi * i / seg
                    ring.append(self.bm.verts.new(base_mx @ Vector((r * math.cos(a), r * math.sin(a), z))))
                rings.append(ring)
        for k in range(len(rings) - 1):
            r0, r1 = rings[k], rings[k + 1]
            mm = mats[k] if mats else m
            mi = self._mi(mm)
            for i in range(seg):
                j = (i + 1) % seg
                if len(r0) == 1 and len(r1) == 1:
                    continue
                if len(r0) == 1:
                    vs = [r0[0], r1[j], r1[i]]
                elif len(r1) == 1:
                    vs = [r0[i], r0[j], r1[0]]
                else:
                    vs = [r0[i], r0[j], r1[j], r1[i]]
                try:
                    f = self.bm.faces.new(vs)
                    f.material_index = mi
                except ValueError:
                    pass

    def ngon_prism(self, pts, z0, z1, m):
        """Vertical prism from a 2D polygon."""
        bot = [self.bm.verts.new((x, y, z0)) for x, y in pts]
        top = [self.bm.verts.new((x, y, z1)) for x, y in pts]
        mi = self._mi(m)
        fs = [self.bm.faces.new(list(reversed(bot))), self.bm.faces.new(top)]
        n = len(pts)
        for i in range(n):
            j = (i + 1) % n
            fs.append(self.bm.faces.new([bot[i], bot[j], top[j], top[i]]))
        for f in fs:
            f.material_index = mi

    def obj(self, name, collection, smooth=False, shadow=True):
        me = bpy.data.meshes.new(name)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        if smooth:
            for p in me.polygons:
                p.use_smooth = True
        o = bpy.data.objects.new(name, me)
        collection.objects.link(o)
        if not shadow:
            o.visible_shadow = False
        return o


def text(body, loc, rz, size, m, collection, extrude=0.12, rx=math.pi / 2):
    """Text standing up (rx=90deg) and facing -Y rotated by rz; rx=0 lies flat."""
    cu = bpy.data.curves.new("Txt_" + body, "FONT")
    cu.body = body
    cu.size = size
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.extrude = extrude
    cu.materials.append(m)
    o = bpy.data.objects.new("Txt_" + body, cu)
    o.location = loc
    o.rotation_euler = (rx, 0, rz)
    collection.objects.link(o)
    return o


def face_rz(frm, to):
    """rz so that a text / front facing -Y ends up facing from `frm` toward `to`."""
    d = Vector(to) - Vector(frm)
    return math.atan2(d.x, -d.y)


def instance(col, name, collection, matrix):
    e = bpy.data.objects.new(name, None)
    e.instance_type = "COLLECTION"
    e.instance_collection = col
    e.matrix_world = matrix
    collection.objects.link(e)
    return e


# ---------------------------------------------------------------------------
# Real assets: Clash Stand + glassies
# ---------------------------------------------------------------------------
with bpy.data.libraries.load(STAND_BLEND) as (src, dst):
    dst.collections = [STAND_COLLECTION]
STAND = bpy.data.collections[STAND_COLLECTION]
# warm the stand woods slightly so they read against maple boards
for _m in bpy.data.materials:
    if _m.name.startswith("GC_World") and _m.node_tree:
        _p = _m.node_tree.nodes.get("Principled BSDF")
        if _p and _m.name == "GC_World_wood_light":
            _p.inputs["Base Color"].default_value = srgb("#F0B27A")

GLASSY = {}
_PARTS = {"pop": ("Body", "Cap", "Bubble_"), "jam": ("Body", "Lid"), "prism": ("Body",)}
for gid, keep in _PARTS.items():
    with bpy.data.libraries.load(os.path.join(GLASSY_DIR, gid, gid + ".blend")) as (src, dst):
        dst.objects = [n for n in src.objects if n.startswith(keep) and not n.startswith("Shard")]
    c = bpy.data.collections.new("Glassy_" + gid)
    for o in dst.objects:
        if o is None:
            continue
        c.objects.link(o)
        if o.type != "MESH":
            continue
        if o.name.startswith("Body"):
            m = GLASS[gid]
        elif o.name.startswith("Cap"):
            m = M["gold"]
        elif o.name.startswith("Bubble"):
            m = M["bubble"]
        else:  # jam lid
            m = M["gum_red"]
        o.data.materials.clear()
        o.data.materials.append(m)
        for p in o.data.polygons:
            p.use_smooth = True
    GLASSY[gid] = c
GLASSY_H = {"pop": 2.46, "jam": 2.04, "prism": 2.52}  # hang point -> bottom


def stand_matrix(x, y, top, rz=0.0, s=1.0):
    # pen floor is 0.4 thick under the origin; sit its underside on `top`
    return Matrix.LocRotScale(Vector((x, y, top + 0.4 * s)), Euler((0, 0, rz)), Vector((s, s, s)))


def hang(stand_mx, side, gid, angle, collection, tag, mb):
    """Hang a glassy on HookA/HookB with a string; `angle` swings it about the stand's Y axis."""
    hook = HOOK_LOCAL[side]
    pose = Matrix.Translation(hook) @ Matrix.Rotation(angle, 4, "Y")
    instance(GLASSY[gid], f"{tag}_{side}_{gid}", collection, stand_mx @ pose @ Matrix.Translation((0, 0, -STRING_LEN)))
    a = stand_mx @ hook
    b = stand_mx @ pose @ Vector((0, 0, -STRING_LEN))
    mb.rod(a, b, 0.07 * stand_mx.to_scale().x, M["string"], seg=5)


# ---------------------------------------------------------------------------
# Room: counter, cabinets, floor, walls, backsplash tiles, window, cabinets above
# ---------------------------------------------------------------------------
def tile_strip(mb, axis, fixed, a0, a1, z0, z1, facing, size=8.0, gap=0.6):
    """Raised square tiles on a wall. axis 'x' -> wall along X at y=fixed; 'y' -> along Y at x=fixed.
    facing = +1/-1: which way the tile faces protrude."""
    n_a = int((a1 - a0) // size)
    n_z = int((z1 - z0) // size)
    off_a = a0 + ((a1 - a0) - n_a * size) / 2
    for i in range(n_a):
        for k in range(n_z):
            if k == n_z - 1:
                m = M["tile_coral"]
            elif k == 2:
                m = M["tile_mint"] if (i % 2 == 0) else M["tile"]
            else:
                m = M["tile"]
            ca = off_a + (i + 0.5) * size
            cz = z0 + (k + 0.5) * size
            d = 0.5
            if axis == "x":
                mb.box((ca, fixed + facing * d / 2, cz), (size - gap, d, size - gap), m)
            else:
                mb.box((fixed + facing * d / 2, ca, cz), (d, size - gap, size - gap), m)


def build_room():
    mb = MB()
    # counter slab
    mb.boxz(X_WALL_L, X_WALL_R, Y_FRONT, Y_BACK + 2, -5.0, 0.0, M["counter"])
    mb.boxz(X_WALL_L, X_WALL_R, Y_FRONT - 0.3, Y_FRONT + 0.4, -5.2, -3.6, M["counter_edge"])
    # lower cabinets and toe kick
    mb.boxz(X_WALL_L, X_WALL_R, Y_FRONT + 3, Y_BACK, -78.0, -5.0, M["cab_dark"])
    mb.boxz(X_WALL_L, X_WALL_R, Y_FRONT + 6, Y_BACK, -84.0, -78.0, M["ink"])
    x = X_WALL_L + 4
    while x < X_WALL_R - 30:
        w = 40.0
        mb.boxz(x, x + w - 2, Y_FRONT + 2, Y_FRONT + 3, -16.0, -7.0, M["cab"])  # drawer
        mb.box((x + w / 2 - 1, Y_FRONT + 1.6, -11.5), (8, 1.2, 1.4), M["brass"])
        mb.boxz(x, x + w - 2, Y_FRONT + 2, Y_FRONT + 3, -76.0, -18.0, M["cab"])  # door
        mb.boxz(x + 3, x + w - 5, Y_FRONT + 1.6, Y_FRONT + 2, -72.0, -22.0, M["cab_dark"])
        mb.cyl((x + w / 2 - 1, Y_FRONT + 1.6, -26.0), 1.2, 1.6, M["brass"], seg=8, rot=rot_to((0, -1, 0)))
        x += w
    mb.obj("Counter", C_ROOM)

    # speckles on the counter (Roblox: a tiling Texture on the counter part)
    mb = MB()
    for _ in range(650):
        px = random.uniform(X_WALL_L + 2, X_WALL_R - 2)
        py = random.uniform(Y_FRONT + 2, Y_BACK - 2)
        m = random.choice([M["speck_a"], M["speck_a"], M["speck_b"], M["speck_c"]])
        mb.cyl((px, py, 0.0), random.uniform(0.5, 1.2), 0.05, m, seg=6, rz=random.uniform(0, 1))
    mb.obj("CounterSpeckles", C_ROOM)

    # walls (built around the window hole); walls do not cast shadows so the sun reads as
    # coming in through the window and over the room
    mb = MB()
    t = 3.0
    yb = Y_BACK
    mb.boxz(X_WALL_L, X_WALL_R, yb, yb + t, 0, SPLASH_TOP, M["grout"])
    mb.boxz(X_WALL_L, WIN_X0, yb, yb + t, SPLASH_TOP, WALL_TOP, M["wall"])
    mb.boxz(WIN_X1, X_WALL_R, yb, yb + t, SPLASH_TOP, WALL_TOP, M["wall"])
    mb.boxz(WIN_X0, WIN_X1, yb, yb + t, SPLASH_TOP, WIN_Z0, M["wall"])
    mb.boxz(WIN_X0, WIN_X1, yb, yb + t, WIN_Z1, WALL_TOP, M["wall"])
    for xs, sgn in ((X_WALL_L, -1), (X_WALL_R, 1)):
        x0, x1 = (xs - t, xs) if sgn < 0 else (xs, xs + t)
        mb.boxz(x0, x1, Y_FRONT, yb + t, 0, SPLASH_TOP, M["grout"])
        mb.boxz(x0, x1, Y_FRONT, yb + t, SPLASH_TOP, WALL_TOP, M["wall"])
    # tiles
    tile_strip(mb, "x", yb, X_WALL_L, X_WALL_R, 0.0, SPLASH_TOP, -1)
    tile_strip(mb, "y", X_WALL_L, Y_FRONT, Y_BACK, 0.0, SPLASH_TOP, 1)
    tile_strip(mb, "y", X_WALL_R, Y_FRONT, Y_BACK, 0.0, SPLASH_TOP, -1)
    # window frame, mullions, sill
    fw = 3.0
    for x0, x1, z0, z1 in (
        (WIN_X0 - fw, WIN_X0, WIN_Z0 - fw, WIN_Z1 + fw),
        (WIN_X1, WIN_X1 + fw, WIN_Z0 - fw, WIN_Z1 + fw),
        (WIN_X0, WIN_X1, WIN_Z1, WIN_Z1 + fw),
    ):
        mb.boxz(x0, x1, yb - 1.5, yb + t + 0.5, z0, z1, M["frame"])
    mb.boxz(WIN_X0 - 6, WIN_X1 + 6, yb - 9, yb + t + 0.5, WIN_Z0 - 3, WIN_Z0, M["frame"])  # sill
    for k in (1, 2, 3):
        xm = WIN_X0 + (WIN_X1 - WIN_X0) * k / 4
        mb.boxz(xm - 1.0, xm + 1.0, yb + 0.5, yb + 2.0, WIN_Z0, WIN_Z1, M["frame"])
    zm = (WIN_Z0 + WIN_Z1) / 2 + 6
    mb.boxz(WIN_X0, WIN_X1, yb + 0.5, yb + 2.0, zm - 1.0, zm + 1.0, M["frame"])
    # curtains (wavy panels) and valance
    for xc, dirn in ((WIN_X0 - 14, 1), (WIN_X1 + 14, -1)):
        for i in range(6):
            xx = xc + (i - 2.5) * 3.2
            dy = 1.0 if i % 2 else 0.0
            m = M["curtain"] if i % 2 == 0 else M["curtain_b"]
            mb.box((xx, yb - 3.0 - dy, (WIN_Z0 + WIN_Z1 + 10) / 2 - 2), (3.4, 1.6, WIN_Z1 - WIN_Z0 + 6), m)
        mb.box((xc + dirn * 2, yb - 4.6, WIN_Z0 + 18), (13, 1.2, 2.0), M["gold"])  # tie-back
    for i in range(16):
        xx = WIN_X0 - 18 + i * (WIN_X1 - WIN_X0 + 36) / 15
        mb.box((xx, yb - 3.2, WIN_Z1 + 6), (9.0, 2.0, 7.0), M["curtain"] if i % 2 == 0 else M["curtain_b"])
    mb.boxz(WIN_X0 - 24, WIN_X1 + 24, yb - 2, yb, WIN_Z1 + 10, WIN_Z1 + 11.5, M["wood"])  # rod
    # upper cabinets over the lobby and over the featured end
    for x0, x1 in ((X_WALL_L, WIN_X0 - 26), (WIN_X1 + 26, X_WALL_R)):
        mb.boxz(x0, x1, yb - 18, yb, 62, 128, M["cab"])
        mb.boxz(x0, x1, yb - 19, yb, 126, 130, M["cab_dark"])
        n = max(1, int((x1 - x0) // 20))
        w = (x1 - x0) / n
        for i in range(n):
            cx = x0 + (i + 0.5) * w
            mb.boxz(cx - w / 2 + 1.2, cx + w / 2 - 1.2, yb - 18.6, yb - 18, 64.5, 124, M["cab_dark"])
            mb.boxz(cx - w / 2 + 3, cx + w / 2 - 3, yb - 19.2, yb - 18.6, 67, 121.5, M["cab"])
            kx = cx + (w / 2 - 5) * (1 if i % 2 == 0 else -1)
            mb.cyl((kx, yb - 19.2, 70), 1.2, 1.6, M["brass"], seg=8, rot=rot_to((0, -1, 0)))
    mb.obj("Walls", C_ROOM, shadow=False)

    # outside the window: emissive sky + garden (does not need the sun)
    mb = MB()
    mb.boxz(WIN_X0 - 60, WIN_X1 + 60, yb + 60, yb + 62, 0, 190, M["sky"])
    mb.boxz(WIN_X0 - 60, WIN_X1 + 60, yb + 20, yb + 58, 0, 62, M["out_hill"])
    for i in range(9):
        tx = WIN_X0 - 10 + i * 21 + random.uniform(-5, 5)
        ty = yb + 36 + random.uniform(-6, 12)
        h = random.uniform(16, 26)
        mb.cyl((tx, ty, 50), 1.8, h * 0.6, M["out_trunk"], seg=6)
        mb.ball((tx, ty, 50 + h * 0.75), random.uniform(9, 13), M["out_tree"], sub=1, scale=(1, 1, 0.85))
    for i in range(30):
        fx = WIN_X0 - 20 + i * 7
        mb.box((fx, yb + 18, 56.5), (1.2, 1.0, 13), M["out_fence"])
    mb.boxz(WIN_X0 - 25, WIN_X1 + 25, yb + 17.5, yb + 18.5, 59, 60.5, M["out_fence"])
    mb.obj("Outside", C_ROOM, shadow=False)

    # rest of the kitchen (front wall, side walls down to the floor): camera-only so it
    # neither blocks the sun nor darkens the bounce light
    mb = MB()
    yf = -330.0
    mb.boxz(X_WALL_L - 3, X_WALL_R + 3, yf - 3, yf, -85, 180, M["room"])
    for xs in (X_WALL_L - 3, X_WALL_R):
        mb.boxz(xs, xs + 3, yf, Y_FRONT, -85, 180, M["room"])
        mb.boxz(xs, xs + 3, Y_FRONT, Y_BACK, -85, 0, M["cab_dark"])
    # giant fridge against the right-hand room wall, seen past the end of the counter
    fx0, fx1, fy0, fy1 = X_WALL_R - 45, X_WALL_R, -230.0, -150.0
    mb.boxz(fx0, fx1, fy0, fy1, -84, 150, M["can_mint"])
    mb.boxz(fx0 - 0.6, fx0, fy0 + 2, fy1 - 2, 52, 148, M["bd_mint_dk"])
    mb.boxz(fx0 - 0.6, fx0, fy0 + 2, fy1 - 2, -82, 50, M["bd_mint_dk"])
    mb.boxz(fx0 - 3.5, fx0 - 0.6, fy1 - 9, fy1 - 6, 60, 110, M["chrome"])
    mb.boxz(fx0 - 3.5, fx0 - 0.6, fy1 - 9, fy1 - 6, 0, 44, M["chrome"])
    for i, (my_, mz, col) in enumerate(((-205, 125, "gum_red"), (-190, 118, "gold"), (-175, 130, "pad_a"),
                                       (-200, 92, "gum_purple"), (-180, 98, "pad_b"))):
        mb.box((fx0 - 1.2, my_, mz), (1.4, 7, 7), M[col], rz=0.0)
    # big kitchen clock on the far end wall: a landmark straight down the runner
    cxw = X_WALL_R
    mb.cyl((cxw, 0, 92), 26, 1.5, M["gum_red"], seg=32, rot=rot_to((-1, 0, 0)))
    mb.cyl((cxw - 1.5, 0, 92), 23, 0.8, M["white"], seg=32, rot=rot_to((-1, 0, 0)))
    for k in range(12):
        a = 2 * math.pi * k / 12
        mb.box((cxw - 2.4, 19 * math.cos(a), 92 + 19 * math.sin(a)), (0.5, 2.0 if k % 3 else 3.0, 2.0 if k % 3 else 3.0), M["ink"])
    mb.box((cxw - 2.8, 0, 92 + 6.5), (0.5, 2.0, 13), M["ink"])
    mb.box((cxw - 3.0, 7.5, 92 - 2.0), (0.5, 16, 1.6), M["ink"], rot=Euler((0.3, 0, 0)).to_matrix())
    mb.cyl((cxw - 3.4, 0, 92), 1.6, 1.2, M["gum_red"], seg=10, rot=rot_to((-1, 0, 0)))
    mb.cyl((40, yf, 110), 16, 2, M["white"], seg=24, rot=rot_to((0, 1, 0)))
    mb.cyl((40, yf, 110), 17.5, 1.2, M["gum_red"], seg=24, rot=rot_to((0, 1, 0)))
    mb.box((40, yf + 2.2, 114), (1.2, 0.4, 9), M["ink"])
    mb.box((44, yf + 2.2, 110), (8, 0.4, 1.2), M["ink"])
    for i in range(-6, 12):  # checker floor
        for j in range(-9, 0):
            m = M["floor_a"] if (i + j) % 2 == 0 else M["floor_b"]
            mb.box((i * 30.0 + 15, Y_FRONT + j * 30.0 + 15, -84.5), (30, 30, 1), m)
    enc = mb.obj("KitchenShell", C_ROOM, shadow=False)
    enc.visible_diffuse = False

    # herb pots on the sill
    mb = MB()
    for i, xx in enumerate((WIN_X0 + 10, WIN_X0 + 44, WIN_X1 - 44, WIN_X1 - 10)):
        z = WIN_Z0
        mb.lathe((xx, yb - 4.5, z), [(0, 0), (3.2, 0), (4.0, 6.0), (4.6, 6.0), (4.6, 7.2), (0, 7.2)], M["pot"], seg=10)
        for k in range(5):
            a = k * 1.26 + i
            mb.ball((xx + 2.2 * math.cos(a), yb - 4.5 + 1.6 * math.sin(a), z + 10 + (k % 2) * 2.5), 3.0, M["leaf"] if k % 2 else M["leaf_lt"], sub=1)
    mb.obj("SillHerbs", C_PROPS)


# ---------------------------------------------------------------------------
# Small builders: queue pad (bottle cap), toothpick flag, avatars
# ---------------------------------------------------------------------------
def bottle_cap(mb, x, y, z, col, glow, s=1.0):
    r = 3.3 * s
    mb.cyl((x, y, z), r, 0.9 * s, M[col], seg=20)
    for i in range(18):
        a = 2 * math.pi * i / 18
        mb.box((x + r * math.cos(a), y + r * math.sin(a), z + 0.45 * s), (0.9 * s, 0.7 * s, 0.9 * s), M[col], rz=a)
    mb.cyl((x, y, z + 0.9 * s), 2.6 * s, 0.08, M[glow], seg=20)
    mb.cyl((x, y, z + 0.98 * s), 2.0 * s, 0.06, M["white"], seg=20)


def toothpick_flag(mb, x, y, z, label, facing_rz, col, collection, h=15.0):
    mb.cyl((x, y, z), 0.45, h, M["wood"], seg=6)
    mb.cyl((x, y, z + h), 0.45, 1.4, M["wood"], seg=6, r2=0.05)
    # paper flag (two-sided), tangent along the facing direction's perpendicular
    d = Euler((0, 0, facing_rz)).to_matrix() @ Vector((1, 0, 0))
    c = Vector((x, y, z + h - 2.4)) + d * 3.0
    mb.box(c, (6.0, 0.25, 4.2), M[col], rz=facing_rz)
    nrm = Euler((0, 0, facing_rz)).to_matrix() @ Vector((0, -1, 0))
    text(label, c + nrm * 0.25, facing_rz, 2.8, M["white"], collection, extrude=0.05)


SHIRTS = ["#3E8EDE", "#E8434B", "#6CCB7E", "#FFD166", "#9B6BE0", "#FF8A4C", "#4ECDC4", "#FF9FB2", "#FFFFFF"]
PANTS = ["#26476B", "#3B3B4F", "#5A3A28", "#2F5A4A", "#4C8FE0"]
SKINS = ["#FFD7A8", "#E8B48A", "#C68B5E", "#8D5A3B", "#FFE0BD"]
_AV_M = {}


def _am(h):
    if h not in _AV_M:
        _AV_M[h] = mat("GK_av_" + h, h)
    return _AV_M[h]


def avatar(mb, x, y, z, rz, shirt=None, pants=None, skin=None, s=1.0, arm_up=False, m_all=None):
    shirt = _am(shirt or random.choice(SHIRTS)) if m_all is None else m_all
    pants = _am(pants or random.choice(PANTS)) if m_all is None else m_all
    skin = _am(skin or random.choice(SKINS)) if m_all is None else m_all
    R = Euler((0, 0, rz)).to_matrix()

    def b(c, size, m, rot=None):
        p = Vector((x, y, z)) + R @ (Vector(c) * s)
        mb.box(p, Vector(size) * s, m, rot=(R @ rot) if rot is not None else R)

    b((-0.5, 0, 1.0), (0.9, 0.9, 2.0), pants)
    b((0.5, 0, 1.0), (0.9, 0.9, 2.0), pants)
    b((0, 0, 3.0), (2.0, 1.0, 2.0), shirt)
    b((-1.5, 0, 3.0), (0.9, 0.9, 2.0), skin)
    if arm_up:
        b((1.5, 0, 4.4), (0.9, 0.9, 2.0), skin)
    else:
        b((1.5, 0, 3.0), (0.9, 0.9, 2.0), skin)
    b((0, 0, 4.7), (1.25, 1.25, 1.25), skin)


def crowd(mb, pts, look_at):
    for x, y in pts:
        rz = face_rz((x, y), look_at)
        avatar(mb, x + random.uniform(-0.4, 0.4), y + random.uniform(-0.4, 0.4), 0.35, rz,
               arm_up=random.random() < 0.3)


# ---------------------------------------------------------------------------
# Arenas: cutting boards along the tea-towel runner
# ---------------------------------------------------------------------------
BOARD_COLS = [("bd_mint", "bd_mint_dk"), ("bd_sky", "bd_sky_dk"), ("bd_butter", "bd_butter_dk"),
              ("bd_lilac", "bd_lilac_dk")]
GLASSY_SETS = [("pop", "jam"), ("prism", "pop"), ("jam", "prism"), ("pop", "pop"),
               ("jam", "jam"), ("prism", "jam"), ("pop", "prism"), None]


def build_runner():
    mb = MB()
    x0, x1 = -14.0, FEAT_C.x - FEAT_R + 1
    mb.boxz(x0, x1, -AISLE_HALF, AISLE_HALF, 0.0, 0.3, M["towel"])
    for yy in (-6.0, -4.6, 4.6, 6.0):
        mb.boxz(x0, x1, yy - 0.45, yy + 0.45, 0.3, 0.36, M["towel_red"])
    # blue cross bands mark each arena pair
    for ax in ARENA_X:
        mb.boxz(ax - 2.5, ax + 2.5, -AISLE_HALF, AISLE_HALF, 0.3, 0.36, M["towel_blue"])
    # fringe at the lobby end
    for i in range(14):
        yy = -AISLE_HALF + 0.6 + i * (2 * AISLE_HALF - 1.2) / 13
        mb.boxz(x0 - 1.6, x0, yy - 0.25, yy + 0.25, 0.0, 0.2, M["towel"])
    mb.obj("TeaTowelRunner", C_ARENAS)


def build_arenas():
    mb = MB()
    num = 0
    for i, ax in enumerate(ARENA_X):
        for side in (1, -1):
            num += 1
            wood = BOARD_COLS[(num - 1) % 4]
            yc = side * (BOARD_Y0 + BOARD_Y1) / 2
            mb.box((ax, yc, BOARD_TOP / 2), (2 * BOARD_HALF_X, BOARD_Y1 - BOARD_Y0, BOARD_TOP), M[wood[0]])
            # juice groove ring
            g0x, g1x = ax - BOARD_HALF_X + 1.6, ax + BOARD_HALF_X - 1.6
            gy0, gy1 = side * (BOARD_Y0 + 1.6), side * (BOARD_Y1 - 1.6)
            gy0, gy1 = min(gy0, gy1), max(gy0, gy1)
            for a, b in (((g0x, gy0), (g1x, gy0 + 0.5)), ((g0x, gy1 - 0.5), (g1x, gy1)),
                         ((g0x, gy0), (g0x + 0.5, gy1)), ((g1x - 0.5, gy0), (g1x, gy1))):
                mb.boxz(a[0], b[0], a[1], b[1], BOARD_TOP, BOARD_TOP + 0.04, M[wood[1]])
            # handle tab with a hole, pointing away from the aisle
            hy = side * (BOARD_Y1 + 4.0)
            mb.box((ax, hy, BOARD_TOP / 2), (12, 8.2, BOARD_TOP), M[wood[0]])
            mb.cyl((ax, hy + side * 0.8, BOARD_TOP), 2.0, 0.05, M["counter_edge"], seg=12)
            # stand + glassies
            rz = 0.0 if side > 0 else math.pi
            smx = stand_matrix(ax, side * PEN_Y, BOARD_TOP, rz)
            instance(STAND, f"Arena{num}", C_ARENAS, smx)
            gs = GLASSY_SETS[num - 1]
            if num == 3:  # the close-up arena: glassy A pulled back, about to swing in
                hang(smx, "A", gs[0], 0.75, C_ARENAS, f"A{num}", mb)
                hang(smx, "B", gs[1], -0.05, C_ARENAS, f"A{num}", mb)
            elif gs:
                swing = random.choice([0.0, 0.25, -0.15])
                hang(smx, "A", gs[0], 0.18 + swing, C_ARENAS, f"A{num}", mb)
                hang(smx, "B", gs[1], -0.12 + swing * 0.5, C_ARENAS, f"A{num}", mb)
            # queue pads: HookA side is -X on the back row, +X on the front row (stand rotated 180)
            pa = (ax - side * PAD_X, side * PAD_Y)
            pb = (ax + side * PAD_X, side * PAD_Y)
            bottle_cap(mb, pa[0], pa[1], BOARD_TOP, "pad_a", "pad_a_glow")
            bottle_cap(mb, pb[0], pb[1], BOARD_TOP, "pad_b", "pad_b_glow")
            # arena number flag on the aisle-side corner
            fr = 0.0 if side > 0 else math.pi
            toothpick_flag(mb, ax - BOARD_HALF_X + 1.5, side * (BOARD_Y0 + 1.5), BOARD_TOP, str(num), fr,
                           "towel_blue", C_ARENAS)
    mb.obj("ArenaBoards", C_ARENAS)


# ---------------------------------------------------------------------------
# Featured arena: round serving tray with plate-stack bleachers and a cake-topper banner
# ---------------------------------------------------------------------------
def plate_stack(mb, x, y, radii, step=2.0):
    z = 0.0
    for r in radii:
        mb.lathe((x, y, z), [(0, 0), (r * 0.8, 0), (r, step * 0.7), (r, step), (0, step)], M["white"], seg=24)
        mb.lathe((x, y, z + step), [(r - 1.6, 0.0), (r - 0.9, 0.0), (r - 0.9, 0.05), (r - 1.6, 0.05)],
                 M["plate_rim"], seg=24)
        z += step


def build_featured():
    mb = MB()
    cx, cy = FEAT_C
    R = FEAT_R
    mb.lathe((cx, cy, 0), [(0, 0), (R + 1.5, 0), (R + 1.5, FEAT_TOP + 1.6), (R, FEAT_TOP + 1.6),
                            (R, FEAT_TOP), (0, FEAT_TOP)], M["tray"], seg=40,
             mats=[M["tray"], M["gold"], M["gold"], M["gold"], M["tray"]])
    # gold inner ring pattern
    mb.lathe((cx, cy, FEAT_TOP), [(R - 4, 0), (R - 2.5, 0), (R - 2.5, 0.05), (R - 4, 0.05)], M["gold"], seg=40)
    # handles
    for sgn in (1, -1):
        a = Vector((cx - 7, cy + sgn * (R + 1.0), 1.0))
        b = Vector((cx + 7, cy + sgn * (R + 1.0), 1.0))
        mb.rod(a, a + Vector((0, sgn * 3.5, 1.5)), 0.6, M["gold"])
        mb.rod(b, b + Vector((0, sgn * 3.5, 1.5)), 0.6, M["gold"])
        mb.rod(a + Vector((0, sgn * 3.5, 1.5)), b + Vector((0, sgn * 3.5, 1.5)), 0.6, M["gold"])
    smx = stand_matrix(cx, cy, FEAT_TOP, rz=math.pi / 2, s=FEAT_SCALE)
    instance(STAND, "FeaturedArena", C_FEAT, smx)
    hang(smx, "A", "prism", 0.35, C_FEAT, "Feat", mb)
    hang(smx, "B", "jam", -0.1, C_FEAT, "Feat", mb)
    # pads on the approach side (HookA is -Y after the 90deg turn)
    for sy, col, glow in ((-1, "pad_a", "pad_a_glow"), (1, "pad_b", "pad_b_glow")):
        px, py = cx - 23.5, cy + sy * 8.0
        mb.cyl((px, py, FEAT_TOP), 4.6, 0.3, M["gold"], seg=24)
        bottle_cap(mb, px, py, FEAT_TOP + 0.3, col, glow, s=1.2)
    # plate-stack bleachers either side
    for sy in (1, -1):
        plate_stack(mb, cx + 2, cy + sy * 47, [15.0, 12.0, 9.0, 6.0], step=2.2)
    # cake-topper banner behind the stand
    bx = cx + 24
    for sy in (1, -1):
        mb.cyl((bx, cy + sy * 16, FEAT_TOP), 0.7, 34, M["wood"], seg=6)
        mb.ball((bx, cy + sy * 16, FEAT_TOP + 34.5), 1.6, M["gold"], sub=1)
    mb.box((bx, cy, FEAT_TOP + 27.0), (0.6, 30, 8.0), M["gum_purple"])
    mb.box((bx - 0.1, cy, FEAT_TOP + 27.0), (0.6, 31, 9.0), M["gold"])
    t = text("FEATURED", (bx - 0.45, cy, FEAT_TOP + 27.0), -math.pi / 2, 4.6, M["white"], C_FEAT, extrude=0.1)
    # pennant garland
    for k in range(10):
        yy = cy - 15 + k * 30 / 9
        sag = 3.0 * math.sin(math.pi * k / 9)
        col = ["gum_red", "gold", "pad_a", "gum_purple", "pad_b"][k % 5]
        mb.box((bx - 0.6, yy, FEAT_TOP + 21.0 - sag), (0.25, 2.2, 2.6), M[col], rot=Euler((0.785, 0, 0)).to_matrix())
    mb.obj("FeaturedTray", C_FEAT)


# ---------------------------------------------------------------------------
# Lobby
# ---------------------------------------------------------------------------
def gumball_machine(mb, x, y, body, label, rz):
    # pedestal
    mb.lathe((x, y, 0), [(0, 0), (6.5, 0), (6.5, 1.2), (5.0, 2.2), (4.2, 9.0), (5.2, 10.0), (0, 10.0)], M[body], seg=16)
    # coin box + knob + chute on the front (facing rz)
    R = Euler((0, 0, rz)).to_matrix()
    fwd = R @ Vector((0, -1, 0))
    c = Vector((x, y, 0))
    mb.box(c + fwd * 4.4 + Vector((0, 0, 6.6)), (4.6, 1.6, 3.6), M["chrome"], rot=R)
    mb.cyl(c + fwd * 5.2 + Vector((0, 0, 6.8)), 1.3, 1.0, M["chrome"], seg=10, rot=R @ rot_to((0, -1, 0)))
    mb.box(c + fwd * 4.9 + Vector((0, 0, 3.2)), (2.6, 1.2, 2.0), M["ink"], rot=R)
    # globe + gumballs
    gz = 17.0
    mb.lathe((x, y, 10.0), [(0, 0), (4.5, 0), (4.5, 1.0), (0, 1.0)], M["chrome"], seg=16)
    cols = ["gum_red", "gum_blue", "gum_purple", "gold", "pad_a", "pad_b", "green", "white"]
    for _ in range(60):
        while True:
            p = Vector((random.uniform(-5, 5), random.uniform(-5, 5), random.uniform(-5.5, 2.5)))
            if p.length < 5.2:
                break
        mb.ball(Vector((x, y, gz)) + p, 1.15, M[random.choice(cols)], sub=1)
    mb.lathe((x, y, gz + 4.6), [(3.2, 0), (3.6, 0.6), (2.6, 2.6), (0.8, 3.4), (0, 3.4)], M[body], seg=16)
    mb.ball((x, y, gz + 8.4), 1.3, M[body], sub=1)
    g = MB()
    g.uvball((x, y, gz), 6.6, M["globe"], seg=24, rings=14)
    g.obj("GumballGlobe_" + label, C_LOBBY, smooth=True)
    text(label, c + fwd * 5.25 + Vector((0, 0, 8.9)), rz, 1.0, M["white"], C_LOBBY, extrude=0.05)


def sign_card(mb, x, y, z0, w, h, label, col, rz, collection, txt_col="white", size=3.4):
    """Card on two skewers, text facing rz."""
    R = Euler((0, 0, rz)).to_matrix()
    side = R @ Vector((1, 0, 0))
    fwd = R @ Vector((0, -1, 0))
    for s in (-1, 1):
        mb.cyl(Vector((x, y, 0)) + side * s * (w / 2 - 1.5), 0.45, z0 + h, M["wood"], seg=6)
    mb.box(Vector((x, y, z0 + h / 2)), (w, 0.5, h), M[col], rot=R)
    text(label, Vector((x, y, z0 + h / 2)) + fwd * 0.3, rz, size, M[txt_col], collection, extrude=0.06)


def build_lobby():
    mb = MB()
    # woven placemat plaza
    mx, my = MAT_C
    rings = [(MAT_R, "weave"), (MAT_R - 3, "weave_dk"), (MAT_R - 4.5, "weave"), (MAT_R - 15, "weave_dk"),
             (MAT_R - 16.5, "weave")]
    for k, (r, col) in enumerate(rings):
        mb.cyl((mx, my, 0.0 + k * 0.02), r, 0.35, M[col], seg=40)
    # cork coaster spawn
    sx, sy = SPAWN
    mb.cyl((sx, sy, 0.37), 10.0, 0.9, M["cork"], seg=24)
    for _ in range(40):
        a, rr = random.uniform(0, 6.28), random.uniform(0, 9)
        mb.cyl((sx + rr * math.cos(a), sy + rr * math.sin(a), 1.27), random.uniform(0.3, 0.6), 0.04, M["cork_dk"], seg=5)
    mb.lathe((sx, sy, 1.27), [(7.0, 0), (8.0, 0), (8.0, 0.06), (7.0, 0.06)], M["spawn_glow"], seg=32)

    # champion on a cake stand, under a spotlight
    cx, cy = CHAMP
    mb.lathe((cx, cy, 0), [(0, 0), (5.5, 0), (5.5, 0.8), (2.0, 1.6), (1.4, 6.0), (2.2, 6.6), (8.5, 7.0),
                           (8.8, 8.0), (0, 8.0)], M["white"], seg=24)
    mb.lathe((cx, cy, 8.0), [(7.0, 0), (8.0, 0), (8.0, 0.06), (7.0, 0.06)], M["gold"], seg=24)
    crz = face_rz(CHAMP, SPAWN)
    avatar(mb, cx, cy, 8.0, crz, s=1.7, arm_up=True, m_all=M["statue"])
    hand = Vector((cx, cy, 8.0)) + Euler((0, 0, crz)).to_matrix() @ Vector((1.5, 0, 5.5)) * 1.7
    instance(GLASSY["prism"], "ChampionTrophy", C_LOBBY,
             Matrix.LocRotScale(hand + Vector((0, 0, 4.0)), Euler((0, 0, 0)), Vector((1.5, 1.5, 1.5))))
    sp_dir = (Vector(SPAWN) - Vector(CHAMP)).normalized() * 10.0
    sign_card(mb, cx + sp_dir.x, cy + sp_dir.y, 1.5, 10, 2.8, "CHAMPION", "gum_purple", crz, C_LOBBY, size=1.5)
    beam = MB()
    beam.cyl((cx, cy, 0.3), 9.5, 60.0, M["beam"], seg=24, r2=4.0)
    beam.obj("ChampionBeam", C_LOBBY, shadow=False)
    sp = bpy.data.lights.new("ChampSpot", "SPOT")
    sp.energy = 60000
    sp.spot_size = math.radians(22)
    sp.color = srgb("#FFF0C0")[:3]
    so = bpy.data.objects.new("ChampSpot", sp)
    so.location = (cx, cy, 60)
    C_LOBBY.objects.link(so)

    # gumball machines = crates (common / rare / epic)
    for (gx, gy), body, label in (((-64, 40), "gum_red", "COMMON"), ((-45, 46), "gum_blue", "RARE"),
                                  ((-26, 40), "gum_purple", "EPIC")):
        gumball_machine(mb, gx, gy, body, label, face_rz((gx, gy), (gx + 4, 0)))
    sign_card(mb, -45, 58, 28, 22, 6, "CRATES", "gum_red", 0.0, C_LOBBY, size=4.0)

    # toaster shop
    tx, ty = -56.0, -44.0
    mb.boxz(tx - 14, tx + 14, ty - 7, ty + 7, 1.0, 19.0, M["toaster"])
    mb.boxz(tx - 14.4, tx + 14.4, ty - 7.4, ty + 7.4, 7.5, 9.0, M["chrome"])
    for fx in (-11, 11):
        for fy in (-5, 5):
            mb.cyl((tx + fx, ty + fy, 0), 1.2, 1.0, M["ink"], seg=8)
    for k, sxl in enumerate((-6.0, 6.0)):
        mb.boxz(tx + sxl - 5.5, tx + sxl + 5.5, ty - 1.4, ty + 1.4, 18.9, 19.1, M["ink"])
        h = 9.0 if k == 0 else 6.0
        mb.boxz(tx + sxl - 5.0, tx + sxl + 5.0, ty - 0.9, ty + 0.9, 13.0, 19.0 + h, M["crust"])
        mb.boxz(tx + sxl - 4.3, tx + sxl + 4.3, ty - 1.0, ty + 1.0, 13.0, 18.3 + h, M["toast"])
    mb.box((tx + 15.2, ty, 14.0), (1.4, 3.0, 1.6), M["ink"])  # lever
    mb.box((tx - 6.0, ty + 1.05, 25.0), (3.2, 0.2, 3.2), M["pad_a"], rot=Euler((0, 0.785, 0)).to_matrix())  # gem on toast
    mb.boxz(tx - 9, tx + 9, ty + 7, ty + 7.3, 10.5, 16.5, M["white"])
    text("SHOP", (tx, ty + 7.45, 13.5), math.pi, 4.4, M["toaster"], C_LOBBY, extrude=0.08)
    # awning-like striped mat in front of the shop
    for i in range(6):
        mb.boxz(tx - 12 + i * 4, tx - 8 + i * 4, ty + 7.5, ty + 13, 0.0, 0.25, M["gum_red"] if i % 2 else M["white"])

    # cookie-jar daily reward
    jx, jy = -28.0, -40.0
    mb.lathe((jx, jy, 0), [(0, 0), (6.0, 0), (7.4, 2.0), (7.6, 9.0), (6.6, 12.0), (5.0, 12.6), (0, 12.6)],
             M["jar_cream"], seg=20, mats=[M["jar_cream"], M["jar_cream"], M["jar_blue"], M["jar_cream"], M["jar_cream"], M["jar_cream"]])
    mb.lathe((jx, jy, 12.6), [(0, 0), (5.6, 0), (5.6, 1.2), (4.0, 2.4), (0, 2.6)], M["jar_blue"], seg=20)
    mb.ball((jx, jy, 16.0), 1.6, M["jar_cream"], sub=1)
    mb.lathe((jx, jy, 0.01), [(9.0, 0), (10.0, 0), (10.0, 0.06), (9.0, 0.06)], M["daily_glow"], seg=28)
    for k in range(5):
        a = 1.2 + k * 0.5
        px, py = jx + 9.5 * math.cos(a), jy + 9.5 * math.sin(a)
        mb.cyl((px, py, 0), 2.4, 0.8, M["cookie"], seg=10)
        for c in range(3):
            mb.cyl((px + random.uniform(-1.3, 1.3), py + random.uniform(-1.3, 1.3), 0.8), 0.4, 0.15, M["choc"], seg=5)
    text("DAILY", (jx, jy + 7.6, 6.0), math.pi, 2.6, M["jar_blue"], C_LOBBY, extrude=0.3)

    # spice-rack index (glassies displayed in cubbies)
    rx0, rx1, ry0, ry1 = -108.0, -74.0, 64.0, 74.0
    mb.boxz(rx0, rx1, ry1 - 1, ry1, 0, 32, M["wood_dk"])  # back
    for xx in (rx0, rx1 - 1.5):
        mb.boxz(xx, xx + 1.5, ry0, ry1, 0, 33, M["wood"])
    for zz in (0.0, 10.5, 21.0, 31.0):
        mb.boxz(rx0, rx1, ry0, ry1, zz, zz + 1.3, M["wood"])
    for zz in (0.0, 10.5, 21.0):
        mb.boxz(rx0, rx1, ry0 - 0.2, ry0 + 0.4, zz + 3.6, zz + 4.2, M["wood_dk"])  # guard rail
    ids = ["pop", "jam", "prism", "jam", "pop", "prism", "prism", "pop", "jam"]
    k = 0
    for zz in (1.3, 11.8, 22.3):
        for xi in range(3):
            gid = ids[k]
            k += 1
            gx = rx0 + 6.0 + xi * 11.0
            s = 2.6
            instance(GLASSY[gid], f"Index_{gid}_{k}", C_LOBBY,
                     Matrix.LocRotScale(Vector((gx, ry0 + 5.0, zz + GLASSY_H[gid] * s)), Euler((0, 0, 0.3)), Vector((s, s, s))))
            mb.box((gx, ry0 - 0.1, zz + 0.65), (4.5, 0.3, 1.0), M["card"])
    mb.box(((rx0 + rx1) / 2, ry0 + 1, 38.0), (18, 0.6, 6), M["jar_blue"])
    mb.cyl(((rx0 + rx1) / 2, ry0 + 1, 32.3), 0.4, 3, M["wood"], seg=6)
    text("INDEX", ((rx0 + rx1) / 2, ry0 + 0.6, 38.0), 0.0, 3.8, M["white"], C_LOBBY, extrude=0.06)

    # recipe-card leaderboards at the mouth of the arena row
    for yy, label in ((21.0, "TOP WINS"), (-21.0, "TOP STREAK")):
        lx = -6.0
        mb.boxz(lx - 2, lx + 2, yy - 7, yy + 7, 0, 2.0, M["wood"])
        R = Euler((0, 0, -math.pi / 2 + 0.12 * (1 if yy > 0 else -1))).to_matrix()
        rot = R @ Euler((-0.12, 0, 0)).to_matrix()
        mb.box((lx, yy, 9.5), (18, 0.4, 13), M["card"], rot=rot)
        fwd = R @ Vector((0, -1, 0))
        up = rot @ Vector((0, 0, 1))
        c0 = Vector((lx, yy, 9.5)) + fwd * 0.25
        mb.box(c0 + up * 5.0, (18, 0.1, 2.6), M["gum_red"], rot=rot)
        for r in range(5):
            mb.box(c0 + up * (2.2 - r * 2.0), (15, 0.1, 0.22), M["card_line"], rot=rot)
            mb.box(c0 + up * (3.0 - r * 2.0) + (R @ Vector((-6.5, 0, 0))), (1.4, 0.12, 1.4),
                   M[["gold", "chrome", "cookie", "card_line", "card_line"][r]], rot=rot)
        t = text(label, c0 + up * 5.0 + fwd * 0.12, -math.pi / 2 + 0.12 * (1 if yy > 0 else -1), 1.8, M["white"],
                 C_LOBBY, extrude=0.03, rx=math.pi / 2 - 0.12)

    # sticky-note codes board
    nx, ny = -86.0, 22.0
    rz = face_rz((nx, ny), SPAWN)
    R = Euler((0, 0, rz)).to_matrix()
    for i in range(6):
        mb.box(Vector((nx, ny, 7.5)) - R @ Vector((0, -0.25 * i, 0)), (13, 0.25, 13), M["note"] if i else M["note"], rot=R)
    fwd = R @ Vector((0, -1, 0))
    for r in range(4):
        mb.box(Vector((nx, ny, 4.0 + r * 1.8)) + fwd * 0.2, (10, 0.1, 0.25), M["note_line"], rot=R)
    text("CODES", Vector((nx, ny, 11.0)) + fwd * 0.2, rz, 2.8, M["ink"], C_LOBBY, extrude=0.05)
    mb.box(Vector((nx, ny, 14.2)), (3.0, 0.8, 1.6), M["gum_red"], rot=R)  # magnet clip
    # giant pencil leaning on it
    a = Vector((nx, ny, 0)) + R @ Vector((8.5, -2.0, 0))
    b = a + R @ Vector((-2.0, 0.5, 16.0))
    mb.rod(a + (b - a).normalized() * 2.5, b, 0.9, M["gold"], seg=6)
    mb.cyl(a, 0.01, 2.5, M["toast"], seg=6, r2=0.9, rot=rot_to(b - a))
    mb.rod(b, b + (b - a).normalized() * 1.6, 0.92, M["mug_p"], seg=6)

    # lobby edge props
    mug(mb, -98.0, -18.0, 7.0, 12.0, "mug_y", rz=0.6)
    rolling_pin(mb, -104.0, -6.0, Y_FRONT + 6.0, 4.0)
    lemon_pair(mb, -100.0, -48.0)
    mb.obj("Lobby", C_LOBBY)


# ---------------------------------------------------------------------------
# Scenery props
# ---------------------------------------------------------------------------
def mug(mb, x, y, r, h, col, rz=0.0):
    mb.lathe((x, y, 0), [(0, 0.0), (r * 0.9, 0), (r, 0.6), (r, h), (r - 0.9, h), (r - 0.9, 1.2), (0, 1.2)], M[col], seg=16)
    mb.cyl((x, y, 0.0), r - 0.95, h - 2.0, M["choc"], seg=16)  # cocoa inside
    R = Euler((0, 0, rz)).to_matrix()
    c = Vector((x, y, h * 0.55)) + R @ Vector((r + 0.2, 0, 0))
    pts = []
    for i in range(7):
        a = -math.pi / 2 + math.pi * i / 6
        pts.append(c + R @ Vector((math.cos(a) * h * 0.25, 0, math.sin(a) * h * 0.28)))
    for p, q in zip(pts, pts[1:]):
        mb.rod(p, q, 0.9, M[col], seg=6)


def canister(mb, x, y, r, h, col, label, collection, face_to=(0, -100)):
    mb.lathe((x, y, 0), [(0, 0), (r, 0), (r, h), (0, h)], M[col], seg=16)
    mb.lathe((x, y, h), [(0, 0), (r + 0.5, 0), (r + 0.5, 1.6), (r * 0.6, 2.4), (0, 2.6)], M["wood"], seg=16)
    mb.ball((x, y, h + 3.2), 1.2, M["wood_dk"], sub=1)
    rz = face_rz((x, y), face_to)
    fwd = Euler((0, 0, rz)).to_matrix() @ Vector((0, -1, 0))
    p = Vector((x, y, h * 0.55)) + fwd * (r - 0.05)
    mb.box(p, (r * 1.2, 0.3, h * 0.28), M["white"], rz=rz)
    text(label, p + fwd * 0.2, rz, h * 0.13, M["ink"], collection, extrude=0.04)


def rolling_pin(mb, x0, x1, y, r):
    mb.rod((x0, y, r), (x1, y, r), r, M["wood"], seg=10)
    mb.rod((x0 - 9, y, r), (x0, y, r), r * 0.45, M["wood_dk"], seg=8)
    mb.rod((x1, y, r), (x1 + 9, y, r), r * 0.45, M["wood_dk"], seg=8)
    mb.ball((x0 - 9, y, r), r * 0.6, M["wood_dk"], sub=1)
    mb.ball((x1 + 9, y, r), r * 0.6, M["wood_dk"], sub=1)


def lemon_pair(mb, x, y):
    mb.ball((x, y, 3.2), 3.6, M["lemon"], sub=2, scale=(1.35, 1, 0.9), rot=(0, 0, 0.4))
    mb.ball((x + 6, y - 2, 3.0), 3.4, M["lemon"], sub=2, scale=(1.35, 1, 0.9), rot=(0, 0, -0.5))
    mb.ball((x + 7, y + 4, 1.0), 1.5, M["leaf"], sub=1, scale=(2, 1, 0.3))


def utensil_crock(mb, x, y):
    mb.lathe((x, y, 0), [(0, 0), (6.5, 0), (7.0, 13.0), (7.6, 14.0), (6.8, 14.0), (6.2, 1.0), (0, 1.0)], M["jar_blue"], seg=16)
    for k, (dx, dy, tilt) in enumerate(((-2, 1, -0.25), (2, -1, 0.2), (0, 2, 0.05), (1.5, 1.5, 0.35))):
        base = Vector((x + dx, y + dy, 2))
        d = Vector((math.sin(tilt), 0.15 * (k - 1.5), 1)).normalized()
        top = base + d * 30
        mb.rod(base, top, 0.8, M["wood"], seg=6)
        mb.ball(top + d * 3.0, 3.2, M["wood"] if k != 2 else M["gum_red"], sub=1,
                scale=(1.0, 0.35, 1.4), rot=(0, tilt, 0))


def fruit_bowl(mb, x, y):
    mb.lathe((x, y, 0), [(0, 0), (8, 0), (8, 1.5), (16, 8.0), (17, 9.0), (15.6, 9.0), (7, 2.5), (0, 2.5)],
             M["jar_blue"], seg=20)
    fr = [("orange", 4.6), ("apple", 4.3), ("green", 4.2), ("orange", 4.4), ("apple", 4.4), ("orange", 4.2)]
    for i, (col, r) in enumerate(fr):
        a = i * 1.05
        rr = 6.5 if i < 5 else 0
        mb.ball((x + rr * math.cos(a), y + rr * math.sin(a), 7.5 + (3 if i == 5 else 0)), r, M[col], sub=2)
    # banana arc
    pts = [Vector((x - 8 + i * 3.2, y - 2 + 0.6 * i, 12.5 + 3.0 * math.sin(math.pi * i / 5))) for i in range(6)]
    for p, q in zip(pts, pts[1:]):
        mb.rod(p, q, 1.7, M["banana"], seg=6)
    mb.ball(pts[0], 0.9, M["choc"], sub=1)
    mb.cyl((x + 3, y + 3, 14.0), 0.4, 3.0, M["choc"], seg=5)
    mb.ball((x + 4, y + 3, 17.0), 1.6, M["leaf"], sub=1, scale=(1.8, 0.9, 0.3))


def kettle(mb, x, y, rz=0.0):
    mb.lathe((x, y, 0), [(0, 0), (8.5, 0), (9.5, 4), (9.0, 11), (6.0, 15.0), (2.5, 16.0), (0, 16.0)], M["kettle"], seg=18)
    mb.ball((x, y, 17.0), 1.8, M["ink"], sub=1)
    R = Euler((0, 0, rz)).to_matrix()
    a = Vector((x, y, 6)) + R @ Vector((8.0, 0, 0))
    mb.cyl(a, 2.4, 12.0, M["kettle"], seg=10, r2=0.9, rot=rot_to(R @ Vector((0.9, 0, 1.0))))
    p0 = Vector((x, y, 15.5)) + R @ Vector((-5.0, 0, 0))
    p1 = Vector((x, y, 21.5)) + R @ Vector((-2.0, 0, 0))
    p2 = Vector((x, y, 21.5)) + R @ Vector((2.0, 0, 0))
    p3 = Vector((x, y, 15.5)) + R @ Vector((5.0, 0, 0))
    for p, q in ((p0, p1), (p1, p2), (p2, p3)):
        mb.rod(p, q, 1.0, M["ink"], seg=6)


def salt_pepper(mb, x, y):
    for dx, col in ((-3.0, "white"), (3.0, "ink")):
        mb.lathe((x + dx, y, 0), [(0, 0), (2.4, 0), (2.6, 6.0), (2.0, 8.5), (0.6, 9.4), (0, 9.4)], M[col], seg=12)
        mb.lathe((x + dx, y, 6.2), [(2.65, 0), (2.7, 0.8)], M["chrome"], seg=12)


def cookbooks(mb, x, y):
    z = 0.0
    for i, (w, d, h, col) in enumerate(((22, 16, 3.5, "book_a"), (20, 15, 3.0, "book_c"), (21, 15, 4.0, "book_d"),
                                        (18, 13, 2.8, "book_b"))):
        rz = (i - 1.5) * 0.08
        mb.box((x, y, z + h / 2), (w, d, h), M[col], rz=rz)
        mb.box((x + 0.6, y, z + h / 2), (w - 0.6, d + 0.3, h - 0.8), M["card"], rz=rz)
        z += h


def sponge(mb, x, y, rz):
    mb.box((x, y, 2.0), (14, 9, 4.0), M["sponge"], rz=rz)
    mb.box((x, y, 4.75), (14, 9, 1.5), M["sponge_g"], rz=rz)


def build_props():
    mb = MB()
    # back row, between the cutting-board handles (and below the window)
    canister(mb, 30.0, 70.0, 6.0, 15.0, "can_mint", "FLOUR", C_PROPS)
    canister(mb, 42.5, 70.5, 5.0, 12.0, "can_peach", "SUGAR", C_PROPS)
    mug(mb, 70.0, 68.0, 6.0, 10.5, "mug_t", rz=2.6)
    mug(mb, 81.0, 71.0, 5.5, 9.0, "mug_p", rz=0.4)
    utensil_crock(mb, 113.0, 69.0)
    salt_pepper(mb, 148.0, 69.0)
    canister(mb, 160.0, 69.0, 6.5, 16.0, "can_lav", "TEA", C_PROPS)
    # far end around the featured tray
    fruit_bowl(mb, 226.0, 50.0)
    kettle(mb, 228.0, -50.0, rz=math.pi * 0.85)
    cookbooks(mb, 232.0, 4.0)
    mug(mb, 222.0, -18.0, 6.0, 11.0, "mug_y", rz=2.0)
    # front edge (low, so the aerial view stays clear)
    sponge(mb, 38.0, -67.0, 0.15)
    lemon_pair(mb, 108.0, -67.0)
    rolling_pin(mb, 132.0, 170.0, -68.0, 3.0)
    mb.obj("Props", C_PROPS)


# ---------------------------------------------------------------------------
# People for scale
# ---------------------------------------------------------------------------
def build_life():
    mb = MB()
    sx, sy = SPAWN
    avatar(mb, sx + 5.0, sy + 13.0, 0.35, -math.pi / 2 + 0.3)
    avatar(mb, sx + 2.0, sy - 7.0, 1.27, -math.pi / 2 - 0.4)
    crowd(mb, [(-30, 28), (-50, 30), (-44, -30), (-24, -29), (-82, 30)],
          (-45, 50))
    # queue + spectators at several arenas
    for i, ax in enumerate(ARENA_X):
        for side in (1, -1):
            if (i, side) in ((3, -1),):
                continue
            pa = (ax - side * PAD_X, side * PAD_Y)
            avatar(mb, pa[0], pa[1], BOARD_TOP + 1.0, 0.0 if side > 0 else math.pi)
            if (i + (side > 0)) % 2 == 0:
                pb = (ax + side * PAD_X, side * PAD_Y)
                avatar(mb, pb[0], pb[1], BOARD_TOP + 1.0, 0.0 if side > 0 else math.pi)
            for k in range(random.randint(1, 3)):
                x = ax + random.uniform(-14, 14)
                y = side * random.uniform(-3.5, 3.5) + 0.0
                avatar(mb, x, y, 0.3, face_rz((x, y), (ax, side * PEN_Y)))
    # spectators lining the front of the close-up arena (board edge and runner)
    ax = ARENA_X[1]
    for x, y in ((ax - 13, 12.0), (ax + 13.5, 12.5), (ax - 2.5, 4.5), (ax + 3.5, 3.0), (ax + 10, -3.0),
                 (ax - 9, -2.0), (ax + 15.5, 18.0)):
        z = BOARD_TOP if y > BOARD_Y0 else 0.3
        avatar(mb, x, y, z, face_rz((x, y), (ax, PEN_Y)), arm_up=random.random() < 0.5)
    # featured crowd on the bleachers and around the tray
    for sy_ in (1, -1):
        for k, (r, z) in enumerate(((13.0, 2.2), (10.0, 4.4), (7.0, 6.6))):
            for j in range(3 - k // 2):
                a = -math.pi / 2 * sy_ + (j - 1) * 0.55 + random.uniform(-0.1, 0.1)
                x = FEAT_C.x + 2 + r * math.cos(a) * 0.95
                y = FEAT_C.y + sy_ * 47 + r * math.sin(a) * 0.95
                avatar(mb, x, y, z, face_rz((x, y), FEAT_C), arm_up=random.random() < 0.5)
    avatar(mb, FEAT_C.x - 23.5, -8.0, FEAT_TOP + 1.38, -math.pi / 2)
    avatar(mb, FEAT_C.x - 23.5, 8.0, FEAT_TOP + 1.38, -math.pi / 2)
    for x, y in ((140, -4), (146, 5), (150, -2)):
        avatar(mb, x, y, 0.3, face_rz((x, y), FEAT_C))
    mb.obj("Players", C_LIFE)


# ---------------------------------------------------------------------------
# World, lights, render
# ---------------------------------------------------------------------------
def setup_world():
    w = bpy.data.worlds.new("GK_World")
    scene.world = w
    nt = w.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.inputs["Color"].default_value = srgb("#FFE4C2")
    bg.inputs["Strength"].default_value = 0.75
    bgc = nt.nodes.new("ShaderNodeBackground")  # what the camera sees in any gap: warm wall
    bgc.inputs["Color"].default_value = srgb(PAL["room"])
    bgc.inputs["Strength"].default_value = 1.0
    lp = nt.nodes.new("ShaderNodeLightPath")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs["Fac"])
    nt.links.new(bg.outputs[0], mix.inputs[1])
    nt.links.new(bgc.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])

    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.4
    sun.angle = math.radians(3.0)
    sun.color = srgb("#FFE0B0")[:3]
    so = bpy.data.objects.new("Sun", sun)
    # golden afternoon from the front-left of the room: shadows fall toward the backsplash
    d = Vector((0.55, 0.62, -0.56)).normalized()
    so.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(so)
    # warm fill pouring in from the window
    ar = bpy.data.lights.new("WindowFill", "AREA")
    ar.energy = 350000
    ar.shape = "RECTANGLE"
    ar.size = WIN_X1 - WIN_X0
    ar.size_y = WIN_Z1 - WIN_Z0
    ar.color = srgb("#FFD9A0")[:3]
    ao = bpy.data.objects.new("WindowFill", ar)
    ao.location = ((WIN_X0 + WIN_X1) / 2, Y_BACK - 2, (WIN_Z0 + WIN_Z1) / 2)
    ao.rotation_euler = Vector((0, -1, -0.55)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(ao)


def setup_render():
    scene.render.engine = "CYCLES"
    cy = scene.cycles
    cy.device = "CPU"
    cy.samples = SAMPLES
    cy.use_adaptive_sampling = True
    cy.max_bounces = 6
    cy.diffuse_bounces = 2
    cy.glossy_bounces = 3
    cy.transmission_bounces = 6
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
        vs.view_transform = "AgX"
        vs.look = "AgX - Punchy"
    except Exception:  # noqa: BLE001
        pass
    vs.exposure = 0.0


def camera(name, loc, target, lens):
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
    "aerial": ((60.0, -178.0, 190.0), (66.0, 16.0, -4.0), 26.0),
    "spawn": ((SPAWN.x - 6.0, 4.0, 1.27 + 6.0), (60.0, -6.0, 10.0), 21.0),
    "arena": ((ARENA_X[1] + 9.0, -13.0, 19.0), (ARENA_X[1] - 1.5, 27.0, 7.5), 29.0),
}


def render_all():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name in VIEWS:
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


build_room()
build_runner()
build_arenas()
build_featured()
build_lobby()
build_props()
build_life()
setup_world()
setup_render()
if os.environ.get("GK_SAVE"):
    bpy.ops.wm.save_as_mainfile(filepath=os.environ["GK_SAVE"])
render_all()
