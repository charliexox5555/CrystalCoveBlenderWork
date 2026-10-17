"""Lobby landmark kit (Glass Clash): Arena Gate, guardian plinth, spawn rosette and a crystal cluster.

Low-poly, flat-shaded Stained Glass pieces. 1 Blender unit = 1 stud, Z up; every piece has its origin at the
floor centre. Each colour is a separate mesh (colours/materials are set in Studio; Blender materials are
previews). Builds into its own scene "LobbyLandmarks_v1" and exports one FBX per piece to
assets/blender/map/landmarks_v1/. Run inside Blender through the MCP:

    exec(open(r"<repo>/tools/blender/build_lobby_landmarks.py").read())
"""
import math
import os

import bmesh
import bpy

REPO = globals().get("GLASSCLASH_REPO") or r"C:/Users/charl/Documents/CrystalCoveBlenderWork"
OUT = os.path.join(REPO, "assets", "blender", "map", "landmarks_v1")
SCENE = "LobbyLandmarks_v1"
PREVIEW = {
    "Lead": (0.12, 0.09, 0.19), "Gold": (0.96, 0.65, 0.14), "Milk": (0.93, 0.9, 0.85),
    "Ruby": (0.89, 0.23, 0.33), "Amber": (0.96, 0.65, 0.14), "Emerald": (0.13, 0.71, 0.45),
    "Aqua": (0.12, 0.76, 0.83), "Amethyst": (0.55, 0.31, 0.88), "Sapphire": (0.18, 0.42, 0.9),
    "Glass": (0.6, 0.9, 1.0),
}


def scene():
    sc = bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)
    for o in list(sc.collection.all_objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.window.scene = sc
    return sc


def material(name):
    m = bpy.data.materials.get("LL_" + name) or bpy.data.materials.new("LL_" + name)
    m.diffuse_color = (*PREVIEW[name], 1.0)
    return m


class Mesh:
    """Collects geometry for one coloured mesh, then links it as a flat-shaded object."""

    def __init__(self, name, colour):
        self.name, self.colour, self.bm = name, colour, bmesh.new()

    def prism(self, sides, radius, z0, z1, x=0.0, y=0.0, top_radius=None, rot=0.0, scale=(1, 1)):
        top_radius = radius if top_radius is None else top_radius
        bottom, top = [], []
        for i in range(sides):
            a = rot + i * 2 * math.pi / sides
            bottom.append(self.bm.verts.new((x + math.cos(a) * radius * scale[0], y + math.sin(a) * radius * scale[1], z0)))
            top.append(self.bm.verts.new((x + math.cos(a) * top_radius * scale[0], y + math.sin(a) * top_radius * scale[1], z1)))
        self.bm.faces.new(list(reversed(bottom)))
        self.bm.faces.new(top)
        for i in range(sides):
            j = (i + 1) % sides
            self.bm.faces.new((bottom[i], bottom[j], top[j], top[i]))

    def box(self, cx, cy, cz, sx, sy, sz, rx=0.0, ry=0.0):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co.x *= sx
            v.co.y *= sy
            v.co.z *= sz
            if ry:
                x, z = v.co.x, v.co.z
                v.co.x, v.co.z = x * math.cos(ry) + z * math.sin(ry), -x * math.sin(ry) + z * math.cos(ry)
            if rx:
                y, z = v.co.y, v.co.z
                v.co.y, v.co.z = y * math.cos(rx) - z * math.sin(rx), y * math.sin(rx) + z * math.cos(rx)
            v.co.x += cx
            v.co.y += cy
            v.co.z += cz
        self.merge(bm)

    def strut(self, a, b, width, depth):
        """Square-section bar from point a to b in the XZ plane (y = 0)."""
        dx, dz = b[0] - a[0], b[1] - a[1]
        length = math.hypot(dx, dz)
        self.box((a[0] + b[0]) / 2, 0, (a[1] + b[1]) / 2, length + width * 0.5, depth, width, ry=-math.atan2(dz, dx))

    def panel(self, points, y, thickness):
        """Flat glass panel from an XZ polygon, centred on y."""
        front = [self.bm.verts.new((p[0], y - thickness / 2, p[1])) for p in points]
        back = [self.bm.verts.new((p[0], y + thickness / 2, p[1])) for p in points]
        self.bm.faces.new(front)
        self.bm.faces.new(list(reversed(back)))
        n = len(points)
        for i in range(n):
            j = (i + 1) % n
            self.bm.faces.new((front[j], front[i], back[i], back[j]))

    def flat(self, points, z0, z1):
        """Flat floor tile from an XY polygon between z0 and z1."""
        low = [self.bm.verts.new((p[0], p[1], z0)) for p in points]
        high = [self.bm.verts.new((p[0], p[1], z1)) for p in points]
        self.bm.faces.new(list(reversed(low)))
        self.bm.faces.new(high)
        n = len(points)
        for i in range(n):
            j = (i + 1) % n
            self.bm.faces.new((low[i], low[j], high[j], high[i]))

    def gem(self, x, y, z, r):
        self.prism(4, r, z, z + r, x, y, top_radius=0.001, rot=math.pi / 4)
        self.prism(4, 0.001, z - r * 0.8, z, x, y, top_radius=r, rot=math.pi / 4)

    def merge(self, other):
        data = bpy.data.meshes.new("tmp")
        other.to_mesh(data)
        other.free()
        self.bm.from_mesh(data)
        bpy.data.meshes.remove(data)

    def link(self, sc, collection):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        data = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(data)
        self.bm.free()
        for p in data.polygons:
            p.use_smooth = False
        data.materials.append(material(self.colour))
        obj = bpy.data.objects.new(self.name, data)
        collection.objects.link(obj)
        return obj


def arc(cx, cz, r, a0, a1, steps):
    return [(cx + math.cos(a0 + (a1 - a0) * i / steps) * r, cz + math.sin(a0 + (a1 - a0) * i / steps) * r) for i in range(steps + 1)]


def build_gate(sc):
    """Arena Gate: hex pillars with glass bands, pointed lead arch, rose window, gem finials. 10.4 wide."""
    col = bpy.data.collections.new("ArenaGate")
    sc.collection.children.link(col)
    lead, gold = Mesh("Gate_Lead", "Lead"), Mesh("Gate_Gold", "Gold")
    glass = {c: Mesh("Gate_Glass" + c, c) for c in ("Ruby", "Amber", "Emerald", "Aqua", "Amethyst", "Sapphire")}
    half, spring = 4.6, 9.0
    for x in (-half, half):
        lead.prism(6, 1.0, 0, 0.6, x)
        lead.prism(6, 0.62, 0.6, spring, x)
        lead.prism(6, 0.9, spring, spring + 0.5, x, top_radius=0.75)
        for i, c in enumerate(("Emerald", "Aqua", "Amethyst")):
            z = 1.8 + i * 2.3
            glass[c].prism(6, 0.68, z, z + 1.5, x)
        gold.gem(x, 0, spring + 0.9, 0.42)
    lead.box(0, 0, spring + 0.25, half * 2 + 1.4, 0.95, 0.55)
    # Pointed (equilateral) arch: two arcs centred on the opposite springing points.
    r = half * 2
    apex_angle = math.acos(0.5)
    left = arc(half, spring + 0.5, r, math.pi, math.pi - apex_angle, 8)
    right = arc(-half, spring + 0.5, r, 0, apex_angle, 8)
    for pts in (left, right):
        for a, b in zip(pts, pts[1:]):
            lead.strut(a, b, 0.65, 0.85)
    apex = left[-1]
    gold.gem(0, 0, apex[1] + 0.35, 0.55)
    # Tympanum glass between the lintel and the arch, behind a rose window.
    tymp = [(-half, spring + 0.55)] + right[1:] + list(reversed(left[1:-1])) + [(half, spring + 0.55)]
    glass["Sapphire"].panel(tymp, 0.12, 0.16)
    rose_c, rose_r = (0, spring + 3.3), 2.0
    ring = arc(rose_c[0], rose_c[1], rose_r, 0, 2 * math.pi, 16)
    for a, b in zip(ring, ring[1:]):
        lead.strut(a, b, 0.32, 0.6)
    colours = ("Ruby", "Amber", "Emerald", "Aqua", "Amethyst", "Ruby")
    for i in range(6):
        a0, a1 = i * math.pi / 3, (i + 1) * math.pi / 3
        petal = [rose_c] + arc(rose_c[0], rose_c[1], rose_r - 0.1, a0, a1, 3)
        glass[colours[i]].panel(petal, -0.12, 0.14)
        tip = (rose_c[0] + math.cos(a0) * rose_r, rose_c[1] + math.sin(a0) * rose_r)
        lead.strut(rose_c, tip, 0.18, 0.5)
    gold.gem(rose_c[0], 0, rose_c[1] - 0.2, 0.42)  # rose hub
    objs = [m.link(sc, col) for m in [lead, gold, *glass.values()]]
    return objs


def build_plinth(sc):
    """Guardian plinth: hex base, column with six glass insets, top slab, gold trim and corner gems."""
    col = bpy.data.collections.new("GuardianPlinth")
    sc.collection.children.link(col)
    lead, gold, glass, milk = Mesh("Plinth_Lead", "Lead"), Mesh("Plinth_Gold", "Gold"), Mesh("Plinth_Glass", "Glass"), Mesh("Plinth_Milk", "Milk")
    lead.prism(6, 2.35, 0, 0.5, rot=math.pi / 6)
    milk.prism(6, 1.8, 0.5, 2.6, rot=math.pi / 6)
    lead.prism(6, 2.2, 2.6, 3.0, top_radius=2.05, rot=math.pi / 6)
    gold.prism(6, 1.95, 2.45, 2.62, rot=math.pi / 6)
    gold.prism(6, 2.42, 0.42, 0.56, rot=math.pi / 6)
    for i in range(6):
        a = i * math.pi / 3
        # Glass inset on each column face, slightly proud of the milk glass.
        nx, ny = math.cos(a), math.sin(a)
        apothem = 1.8 * math.cos(math.pi / 6)
        cx, cy = nx * (apothem + 0.04), ny * (apothem + 0.04)
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co.x *= 0.12
            v.co.y *= 1.25
            v.co.z *= 1.45
            x, y = v.co.x, v.co.y
            v.co.x, v.co.y = x * nx - y * ny + cx, x * ny + y * nx + cy
            v.co.z += 1.55
        glass.merge(bm)
        ca = a + math.pi / 6
        gold.gem(math.cos(ca) * 2.15, math.sin(ca) * 2.15, 3.05, 0.22)
    return [m.link(sc, col) for m in (lead, milk, gold, glass)]


def build_rosette(sc):
    """Spawn rosette: 13-stud walkable stained-glass floor medallion, at most 0.3 tall."""
    col = bpy.data.collections.new("SpawnRosette")
    sc.collection.children.link(col)
    lead, gold = Mesh("Rose_Lead", "Lead"), Mesh("Rose_Gold", "Gold")
    glass = {c: Mesh("Rose_Glass" + c, c) for c in ("Ruby", "Amber", "Emerald", "Aqua", "Amethyst", "Sapphire")}
    lead.prism(32, 6.2, 0, 0.1)
    rim = [(math.cos(i * math.pi / 16) * 6.6, math.sin(i * math.pi / 16) * 6.6) for i in range(32)]
    rim_in = [(x * 6.15 / 6.6, y * 6.15 / 6.6) for x, y in rim]
    for i in range(32):
        j = (i + 1) % 32
        lead.flat([rim[i], rim[j], rim_in[j], rim_in[i]], 0, 0.3)
    lip = [(x * 6.8 / 6.6, y * 6.8 / 6.6) for x, y in rim]
    for i in range(32):
        j = (i + 1) % 32
        gold.flat([lip[i], lip[j], rim[j], rim[i]], 0, 0.14)
    lead.prism(24, 1.25, 0.12, 0.24)
    outer = ("Aqua", "Amethyst", "Amber", "Emerald", "Ruby", "Sapphire", "Amber", "Amethyst")
    inner = ("Sapphire", "Aqua", "Ruby", "Aqua", "Sapphire", "Aqua", "Ruby", "Aqua")
    for i in range(8):
        a = i * math.pi / 4
        half = math.pi / 8
        # Pointed outer petal (kite) and an inner wedge, each a thin glass tile.
        kite = [
            (math.cos(a) * 2.6, math.sin(a) * 2.6),
            (math.cos(a + half) * 4.2, math.sin(a + half) * 4.2),
            (math.cos(a) * 6.1, math.sin(a) * 6.1),
            (math.cos(a - half) * 4.2, math.sin(a - half) * 4.2),
        ]
        glass[outer[i]].flat(kite, 0.1, 0.2)
        wedge = [(math.cos(a - half) * 1.35, math.sin(a - half) * 1.35), (math.cos(a + half) * 1.35, math.sin(a + half) * 1.35),
                 (math.cos(a + half) * 2.45, math.sin(a + half) * 2.45), (math.cos(a - half) * 2.45, math.sin(a - half) * 2.45)]
        glass[inner[i]].flat(wedge, 0.1, 0.2)
        # Lead lines raised just above the glass.
        for r0, r1 in ((1.3, 6.4),):
            bm = bmesh.new()
            bmesh.ops.create_cube(bm, size=1.0)
            for v in bm.verts:
                v.co.x = v.co.x * (r1 - r0) + (r0 + r1) / 2
                v.co.y *= 0.14
                v.co.z = v.co.z * 0.12 + 0.2
                x, y = v.co.x, v.co.y
                ang = a + half
                v.co.x, v.co.y = x * math.cos(ang) - y * math.sin(ang), x * math.sin(ang) + y * math.cos(ang)
            lead.merge(bm)
    for r in (2.55, 4.25):
        ring = [(math.cos(i * math.pi / 16) * r, math.sin(i * math.pi / 16) * r) for i in range(32)]
        inner_ring = [(x * (r - 0.14) / r, y * (r - 0.14) / r) for x, y in ring]
        for i in range(32):
            j = (i + 1) % 32
            lead.flat([ring[i], ring[j], inner_ring[j], inner_ring[i]], 0.12, 0.26)
    star = []
    for i in range(16):
        rr = 1.15 if i % 2 == 0 else 0.5
        star.append((math.cos(i * math.pi / 8) * rr, math.sin(i * math.pi / 8) * rr))
    gold.flat(star, 0.2, 0.28)
    return [m.link(sc, col) for m in [lead, gold, *glass.values()]]


def build_crystals(sc):
    """Crystal cluster for island corners: five faceted glass prisms on a lead rock base."""
    col = bpy.data.collections.new("CrystalCluster")
    sc.collection.children.link(col)
    rock, glass = Mesh("Crystal_Rock", "Lead"), Mesh("Crystal_Glass", "Glass")
    rock.prism(7, 1.6, 0, 0.6, top_radius=1.1)
    for x, y, h, r, tilt in ((0, 0, 3.2, 0.5, 0), (0.7, 0.3, 2.2, 0.38, 0.35), (-0.6, 0.4, 2.5, 0.4, -0.3),
                             (0.2, -0.7, 1.8, 0.34, 0.25), (-0.4, -0.5, 1.4, 0.3, -0.2)):
        bm = bmesh.new()
        tmp = Mesh("tmp", "Glass")
        tmp.prism(6, r, 0, h * 0.78, top_radius=r * 0.9)
        tmp.prism(6, r * 0.9, h * 0.78, h, top_radius=0.02)
        tmp.bm.to_mesh(data := bpy.data.meshes.new("tmp2"))
        tmp.bm.free()
        bm.from_mesh(data)
        bpy.data.meshes.remove(data)
        for v in bm.verts:
            z = v.co.z
            v.co.x += x + math.sin(tilt) * z
            v.co.y += y
            v.co.z = math.cos(tilt) * z + 0.45
        glass.merge(bm)
    return [m.link(sc, col) for m in (rock, glass)]


def build_all(export=True):
    sc = scene()
    pieces = {"ArenaGate": build_gate(sc), "GuardianPlinth": build_plinth(sc), "SpawnRosette": build_rosette(sc), "CrystalCluster": build_crystals(sc)}
    # Spread the pieces out for review renders only; exports reset each piece to the origin.
    report = {}
    os.makedirs(OUT, exist_ok=True)
    for name, objs in pieces.items():
        tris = 0
        for o in objs:
            tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
        report[name] = {"meshes": [o.name for o in objs], "triangles": tris}
        if export:
            ns = globals().get("_GC_HELPER")
            if ns is None:
                ns = {"GLASSCLASH_REPO": REPO}
                exec(open(os.path.join(REPO, "tools", "blender", "glassclash_blender.py")).read(), ns)
                globals()["_GC_HELPER"] = ns
            ns["export_fbx"](objs, os.path.join(OUT, name + ".fbx"))
    offsets = {"ArenaGate": (0, 0), "GuardianPlinth": (10, 0), "SpawnRosette": (-12, 0), "CrystalCluster": (17, 0)}
    for name, objs in pieces.items():
        for o in objs:
            o.location = (*offsets[name], 0)
    return report


result = build_all(export=globals().get("LL_EXPORT", False))
