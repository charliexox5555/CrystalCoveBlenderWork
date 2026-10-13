"""Glass Clash map concept: "Glassblower's Boardwalk".

Builds the whole concept from scratch in headless Blender (bpy module) and renders
three views (aerial, spawn, arena) to docs/art/concepts/boardwalk/.

Run:  <bpyenv>/bin/python build.py
Optional env vars for quick iteration:
  BW_VIEWS=aerial,spawn,arena   which views to render (default all)
  BW_SAMPLES=24                 Cycles samples
  BW_SCALE=100                  resolution percentage
  BW_SAVE=/path/file.blend      also save the built scene

Layout units are studs (1 Blender unit = 1 stud), Z is up.
X runs from the shore (negative) out along the pier (positive); +Y is north.
"""

import bpy  # noqa: I001  (bpy must be imported before bmesh/mathutils)
import bmesh
import math
import os
import random
import subprocess
from mathutils import Euler, Matrix, Vector

REPO = "/home/user/CrystalCoveBlenderWork"
OUT_DIR = os.path.join(REPO, "docs/art/concepts/boardwalk")
STAND_BLEND = os.path.join(REPO, "assets/blender/map/clash_stand.blend")
STAND_COLLECTION = "GlassClash_ClashStand.001"
GLASSY_DIR = os.path.join(REPO, "assets/blender/glassies")

VIEWS = [v for v in os.environ.get("BW_VIEWS", "aerial,spawn,arena").split(",") if v]
SAMPLES = int(os.environ.get("BW_SAMPLES", "24"))
RES_PCT = int(os.environ.get("BW_SCALE", "100"))

random.seed(7)

# ---------------------------------------------------------------------------
# Layout constants (studs)
# ---------------------------------------------------------------------------
SAND_Z = 2.9  # beach / plaza ground
DECK_Z = 3.1  # top of the boardwalk planks
PLAZA_Z = 3.2  # top of the paved plaza
PLAT_Z = 3.5  # top of each arena platform (small step up from the walkway)
STAND_FLOOR = 0.4  # the stand's pen floor hangs 0.4 below its origin
WALK_HALF = 8.0  # walkway is 16 wide
WALK_X0, WALK_X1 = -6.0, 178.0
ARENA_X = [28.0, 68.0, 108.0, 148.0]  # 40-stud pitch, 4 per side -> 8 arenas
ARENA_Y = 30.0  # arena centre distance from the pier centre line
PLAT_HALF_X = 18.0
PLAT_Y0, PLAT_Y1 = 8.0, 51.0  # platform extent (north side; mirrored south)
PAD_OFFSET_X = 7.0  # queue pads sit in front of HookA / HookB sides
PAD_Y = 11.9
FEAT_C = Vector((202.0, 0.0))
FEAT_R = 27.0
FEAT_SCALE = 1.25
SPAWN = Vector((-48.0, 0.0))
PLAZA_C = Vector((-30.0, 0.0))
PLAZA_R = 27.0
HOOK_LOCAL = {"A": Vector((-1.5, 0.0, 15.1)), "B": Vector((1.5, 0.0, 15.1))}
STRING_LEN = 5.0  # Balance.Feel.StringLength


# ---------------------------------------------------------------------------
# Scene reset
# ---------------------------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def coll(name, parent=None):
    c = bpy.data.collections.new(name)
    (parent or scene.collection).children.link(c)
    return c


C_SHORE = coll("Shore")
C_PIER = coll("Pier")
C_ARENAS = coll("Arenas")
C_FEAT = coll("Featured")
C_SEA = coll("Sea")
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


_MATS = {}


def mat(name, hex_col, rough=0.85, emit=0.0, metal=0.0):
    if name in _MATS:
        return _MATS[name]
    m = bpy.data.materials.new(name)
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = srgb(hex_col)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if emit > 0:
        p.inputs["Emission Color"].default_value = srgb(hex_col)
        p.inputs["Emission Strength"].default_value = emit
    m.diffuse_color = srgb(hex_col)
    _MATS[name] = m
    return m


def glass_mat(name, hex_col):
    """Preview-only glossy tinted glass (in Roblox: Glass material, Transparency ~0.3)."""
    m = bpy.data.materials.new(name)
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = srgb(hex_col)
    p.inputs["Roughness"].default_value = 0.03
    p.inputs["IOR"].default_value = 1.45
    p.inputs["Transmission Weight"].default_value = 0.8
    p.inputs["Coat Weight"].default_value = 0.6
    p.inputs["Coat Roughness"].default_value = 0.02
    p.inputs["Emission Color"].default_value = srgb(hex_col)
    p.inputs["Emission Strength"].default_value = 0.25
    return m


PAL = {
    "sand": "#F2D59B",
    "sand_wet": "#E2BE7E",
    "grass": "#8BCB6B",
    "grass_dark": "#5FAE55",
    "rock": "#A3ABB5",
    "rock_dark": "#7D8794",
    "plank_a": "#DDBE8E",
    "plank_b": "#CFAE7C",
    "plank_c": "#E6CB9F",
    "beam": "#8C6142",
    "piling": "#6E4C35",
    "trim": "#2F8FC0",
    "trim_feat": "#F2B83B",
    "rail": "#FBF5E8",
    "plaza": "#EFD9B0",
    "plaza_ring": "#4FC3C0",
    "lamp_post": "#2C5D6B",
    "lamp_glow": "#FFE6A3",
    "pad_a": "#3EC6FF",
    "pad_b": "#FF8A4C",
    "pad_gold": "#FFD25A",
    "pad_base": "#FFFFFF",
    "coral": "#F27B5B",
    "red": "#EF5B5B",
    "yellow": "#FFD166",
    "teal": "#4ECDC4",
    "sky": "#8FE3FF",
    "violet": "#C9A8FF",
    "cream": "#FFF4E2",
    "brick": "#C8664A",
    "brick_dark": "#9E4B36",
    "kiln_glow": "#FF8A3D",
    "navy": "#26476B",
    "gold": "#F2C14E",
    "silver": "#C9D3DE",
    "bronze": "#D08A52",
    "chalk": "#2F5A4A",
    "white": "#FFFFFF",
    "dark": "#3B3B4F",
    "leaf": "#4FB453",
    "leaf_light": "#79CF5A",
    "trunk": "#A47148",
    "seaglass": "#86D9BE",
    "cork": "#C9935B",
    "machine_g": "#6CCB7E",
    "machine_b": "#5AA9E6",
    "machine_p": "#B084F5",
}
M = {k: mat("BW_" + k, v) for k, v in PAL.items()}
M["lamp_glow"] = mat("BW_lamp_glow_e", PAL["lamp_glow"], emit=6.0)
M["kiln_glow"] = mat("BW_kiln_glow_e", PAL["kiln_glow"], emit=8.0)
M["pad_a_glow"] = mat("BW_pad_a_e", PAL["pad_a"], emit=3.0)
M["pad_b_glow"] = mat("BW_pad_b_e", PAL["pad_b"], emit=3.0)
M["chest_glow"] = mat("BW_chest_glow_e", PAL["yellow"], emit=2.5)
M["spawn_glow"] = mat("BW_spawn_glow_e", PAL["sky"], emit=2.5)
M["light_room"] = mat("BW_light_room_e", "#FFF1B8", emit=10.0)
M["seaglass"] = mat("BW_seaglass_frost", PAL["seaglass"], rough=0.35)
M["water_foam"] = mat("BW_foam", "#FFFFFF", rough=0.9)

GLASS = {
    "pop": glass_mat("GC_Glass_pop", "#8FE3FF"),
    "jam": glass_mat("GC_Glass_jam", "#FF6B8B"),
    "prism": glass_mat("GC_Glass_prism", "#C9A8FF"),
}


def beam_mat():
    """Soft see-through spotlight beam for the champion statue."""
    m = bpy.data.materials.new("BW_beam")
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = srgb("#FFF0B0")
    em.inputs["Strength"].default_value = 0.9
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.inputs["Fac"].default_value = 0.1
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return m


M["beam"] = beam_mat()


def water_mat():
    """Shallow turquoise near the beach fading to deep blue (by world X)."""
    m = bpy.data.materials.new("BW_water")
    nt = m.node_tree
    p = nt.nodes.get("Principled BSDF")
    p.inputs["Roughness"].default_value = 0.18
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 15.0
    mr.inputs["From Max"].default_value = 130.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = srgb("#7FE6D8")
    ramp.color_ramp.elements[1].color = srgb("#2E93D1")
    ramp.color_ramp.elements[1].position = 1.0
    nt.links.new(geo.outputs["Position"], sep.inputs[0])
    nt.links.new(sep.outputs["X"], mr.inputs["Value"])
    nt.links.new(mr.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], p.inputs["Base Color"])
    return m


M["water"] = water_mat()


# ---------------------------------------------------------------------------
# Mesh builder: many primitives -> one mesh with several materials
# ---------------------------------------------------------------------------
def rot_to(d):
    """Rotation that maps +Z onto direction d."""
    return Vector(d).normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()


class MB:
    def __init__(self):
        self.bm = bmesh.new()
        self.mats = []

    def _mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def _tag(self, verts, m):
        mi = self._mi(m)
        faces = {f for v in verts for f in v.link_faces}
        for f in faces:
            f.material_index = mi
            f.smooth = False

    def box(self, c, s, m, rz=0.0, rot=None):
        R = rot if rot is not None else Euler((0, 0, rz)).to_matrix().to_4x4()
        mx = Matrix.Translation(Vector(c)) @ R @ Matrix.Diagonal((*s, 1.0))
        r = bmesh.ops.create_cube(self.bm, size=1.0, matrix=mx)
        self._tag(r["verts"], m)
        return self

    def cyl(self, base, r, h, m, seg=8, r2=None, rot=None, rz=0.0):
        """Cylinder/cone standing on `base` (along +Z, or along `rot`)."""
        R = rot if rot is not None else Euler((0, 0, rz)).to_matrix().to_4x4()
        mx = Matrix.Translation(Vector(base)) @ R @ Matrix.Translation((0, 0, h / 2))
        res = bmesh.ops.create_cone(
            self.bm, cap_ends=True, cap_tris=False, segments=seg,
            radius1=r, radius2=(r if r2 is None else r2), depth=h, matrix=mx,
        )
        self._tag(res["verts"], m)
        return self

    def rod(self, a, b, r, m, seg=6):
        a, b = Vector(a), Vector(b)
        d = b - a
        return self.cyl(a, r, d.length, m, seg=seg, rot=rot_to(d))

    def ico(self, c, r, m, sub=1, scale=(1, 1, 1), rz=0.0):
        mx = Matrix.LocRotScale(Vector(c), Euler((0, 0, rz)), Vector(scale))
        res = bmesh.ops.create_icosphere(self.bm, subdivisions=sub, radius=r, matrix=mx)
        self._tag(res["verts"], m)
        return self

    def poly(self, pts_bottom, pts_top, m):
        """Prism from two matching vertex rings (bottom, top)."""
        vb = [self.bm.verts.new(p) for p in pts_bottom]
        vt = [self.bm.verts.new(p) for p in pts_top]
        n = len(vb)
        self.bm.faces.new(list(reversed(vb)))
        self.bm.faces.new(vt)
        for i in range(n):
            j = (i + 1) % n
            self.bm.faces.new((vb[i], vb[j], vt[j], vt[i]))
        self._tag(vb + vt, m)
        return self

    def tri(self, a, b, c, m):
        vs = [self.bm.verts.new(p) for p in (a, b, c)]
        self.bm.faces.new(vs)
        self._tag(vs, m)
        return self

    def mesh(self, name):
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        return me

    def obj(self, name, collection, loc=(0, 0, 0), rz=0.0, scale=1.0):
        return place(self.mesh(name), name, collection, loc, rz, scale)


def place(me, name, collection, loc=(0, 0, 0), rz=0.0, scale=1.0):
    o = bpy.data.objects.new(name, me)
    o.location = loc
    o.rotation_euler = (0, 0, rz)
    o.scale = (scale, scale, scale)
    collection.objects.link(o)
    return o


def instance(col, name, collection, matrix):
    e = bpy.data.objects.new(name, None)
    e.instance_type = "COLLECTION"
    e.instance_collection = col
    e.matrix_world = matrix
    collection.objects.link(e)
    return e


def text(body, loc, rz, size, m, collection, extrude=0.08, rx=math.pi / 2):
    cu = bpy.data.curves.new("T_" + body, "FONT")
    cu.body = body
    cu.size = size
    cu.extrude = extrude
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    o = bpy.data.objects.new("Text_" + body, cu)
    o.location = loc
    o.rotation_euler = (rx, 0, rz)
    o.data.materials.append(m)
    collection.objects.link(o)
    return o


# ---------------------------------------------------------------------------
# Real assets: Clash Stand + glassies (bodies and details only, no shards)
# ---------------------------------------------------------------------------
with bpy.data.libraries.load(STAND_BLEND) as (src, dst):
    dst.collections = [STAND_COLLECTION]
STAND = dst.collections[0]

GLASSY = {}
for gid, keep in (("pop", ("Body", "Cap", "Bubble_")), ("jam", ("Body", "Lid")), ("prism", ("Body",))):
    with bpy.data.libraries.load(os.path.join(GLASSY_DIR, gid, gid + ".blend")) as (src, dst):
        dst.objects = [n for n in src.objects if n.startswith(keep) and not n.startswith("Shard")]
    gc = bpy.data.collections.new("Glassy_" + gid)
    for o in dst.objects:
        if o is None:
            continue
        o.parent = None
        o.matrix_world = Matrix.Identity(4)
        if o.name.startswith("Body"):
            o.data.materials.clear()
            o.data.materials.append(GLASS[gid])
        gc.objects.link(o)
    GLASSY[gid] = gc


def stand_matrix(x, y, rz, s=1.0, top=PLAT_Z):
    return Matrix.LocRotScale(Vector((x, y, top + STAND_FLOOR * s)), Euler((0, 0, rz)), Vector((s, s, s)))


def hang(stand_mx, side, gid, angle, collection, tag):
    """Hang a glassy from HookA/B with a string, swung by `angle` (radians) in the swing plane."""
    hook = HOOK_LOCAL[side]
    pose = Matrix.Translation(hook) @ Matrix.Rotation(angle, 4, "Y")
    instance(GLASSY[gid], f"{tag}_{side}_{gid}", collection, stand_mx @ pose @ Matrix.Translation((0, 0, -STRING_LEN)))
    mb = MB().cyl((0, 0, -STRING_LEN), 0.045, STRING_LEN, M["rail"], seg=5)
    o = mb.obj(f"{tag}_{side}_string", collection)
    o.matrix_world = stand_mx @ pose


# ---------------------------------------------------------------------------
# Terrain: beach, plaza ground, dunes and two headlands framing a bay
# ---------------------------------------------------------------------------
def shore_x(y):
    ay = abs(y)
    return 4.0 + 3.0 * math.sin(y / 9.0) + 4.0 * math.sin(y / 23.0) + max(0.0, ay - 105.0) * 1.35


def ground_z(x, y):
    sx = shore_x(y)
    ay = abs(y)
    land = SAND_Z
    if x < -88:  # dunes behind the plaza
        land += (-88 - x) * 0.22 + 2.0 * math.sin(y / 17.0) * min(1.0, (-88 - x) / 20)
    if ay > 115:  # headland plateaus
        land += min(9.0, (ay - 115) * 0.35)
    if x <= sx:
        return land
    # slope into the sea; headlands drop as cliffs
    drop = 0.26 if ay < 110 else 0.9
    return max(-7.0, land - (x - sx) * drop * (land + 3) / 6.0)


def build_terrain():
    bm = bmesh.new()
    xs = [x * 4.0 for x in range(-60, 46)]  # -240 .. 180
    ys = [y * 6.0 for y in range(-45, 46)]  # -270 .. 270
    grid = []
    for x in xs:
        row = []
        for y in ys:
            j = 0.0
            if not (-62 < x < 14 and abs(y) < 60):  # keep the plaza flat
                j = random.uniform(-0.25, 0.25)
            row.append(bm.verts.new((x + random.uniform(-0.6, 0.6) * (abs(y) > 60), y, ground_z(x, y) + j)))
        grid.append(row)
    me = bpy.data.meshes.new("Terrain")
    for i in range(len(xs) - 1):
        for k in range(len(ys) - 1):
            bm.faces.new((grid[i][k], grid[i + 1][k], grid[i + 1][k + 1], grid[i][k + 1]))
    mats = [M["sand"], M["grass"], M["rock"], M["sand_wet"]]
    for f in bm.faces:
        c = f.calc_center_median()
        if c.z > SAND_Z + 2.5 and abs(c.y) < 112:
            f.material_index = 1
        elif abs(c.y) > 112 and c.z > SAND_Z + 1.0:
            f.material_index = 1 if c.z > SAND_Z + 8 or c.x < shore_x(c.y) - 6 else 2
        elif abs(c.y) > 112 and c.x > shore_x(c.y) - 6:
            f.material_index = 2
        elif c.z < SAND_Z - 0.4:
            f.material_index = 3
        f.smooth = False
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    place(me, "Terrain", C_SHORE)


def build_sea():
    bm = bmesh.new()
    n = 70
    size = 840.0
    x0, y0 = -120.0, -size / 2
    step = size / n
    verts = [[bm.verts.new((x0 + i * step, y0 + k * step, random.uniform(-0.18, 0.18))) for k in range(n + 1)] for i in range(n + 1)]
    for i in range(n):
        for k in range(n):
            bm.faces.new((verts[i][k], verts[i + 1][k], verts[i + 1][k + 1], verts[i][k + 1]))
    me = bpy.data.meshes.new("Sea")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(M["water"])
    place(me, "Sea", C_SEA)
    # Far ocean out to the horizon
    MB().box((300, 0, -0.3), (4000, 4000, 0.2), M["water"]).obj("SeaFar", C_SEA)
    # Foam line where the beach slope meets the water
    mb = MB()
    for k in range(-52, 52):
        y = k * 2.2
        if abs(y) > 112:
            continue
        xf = shore_x(y) + SAND_Z / (0.26 * (SAND_Z + 3) / 6.0)
        mb.box((xf + random.uniform(-0.4, 0.4), y, 0.12), (random.uniform(1.2, 2.0), 2.3, 0.2), M["water_foam"], rz=random.uniform(-0.2, 0.2))
    mb.obj("ShoreFoam", C_SEA)


# ---------------------------------------------------------------------------
# Boardwalk: walkway, arena platforms, pilings, railings, lamps, bunting
# ---------------------------------------------------------------------------
def build_walkway():
    mb = MB()
    planks = [M["plank_a"], M["plank_b"], M["plank_c"]]
    x = WALK_X0
    i = 0
    while x < WALK_X1:
        mb.box((x + 0.75, 0, DECK_Z - 0.25), (1.42, WALK_HALF * 2, 0.5), planks[i % 3])
        x += 1.5
        i += 1
    for y in (-WALK_HALF + 0.8, -2.5, 2.5, WALK_HALF - 0.8):  # stringers
        mb.box(((WALK_X0 + WALK_X1) / 2, y, DECK_Z - 1.0), (WALK_X1 - WALK_X0, 0.8, 1.0), M["beam"])
    mb.obj("Walkway", C_PIER)


def build_platform(x, side, mb_top, mb_piles, trim):
    yc = (PLAT_Y0 + PLAT_Y1) / 2 * side
    depth = PLAT_Y1 - PLAT_Y0
    mb_top.box((x, yc, PLAT_Z - 0.5), (PLAT_HALF_X * 2, depth, 1.0), M["plank_b"])
    mb_top.box((x, yc, PLAT_Z - 1.15), (PLAT_HALF_X * 2 + 0.4, depth + 0.4, 0.7), trim)
    for px in (-17, -8.5, 0, 8.5, 17):
        for py in (PLAT_Y0 + 1.5, (PLAT_Y0 + PLAT_Y1) / 2, PLAT_Y1 - 1.0):
            mb_piles.cyl((x + px, py * side, -8), 0.6, PLAT_Z - 1.5 + 8, M["piling"], seg=7)


def rail(mb, a, b, h=3.0, step=4.0):
    a, b = Vector(a), Vector(b)
    d = b - a
    n = max(1, int(d.length / step))
    for i in range(n + 1):
        p = a + d * (i / n)
        mb.box((p.x, p.y, p.z + h / 2), (0.45, 0.45, h), M["rail"])
    ang = math.atan2(d.y, d.x)
    mid = (a + b) / 2
    mb.box((mid.x, mid.y, mid.z + h), (d.length + 0.5, 0.35, 0.3), M["rail"], rz=ang)
    mb.box((mid.x, mid.y, mid.z + h * 0.5), (d.length, 0.2, 0.2), M["rail"], rz=ang)


def lamp(mb, x, y, base_z):
    mb.cyl((x, y, base_z), 0.75, 0.6, M["lamp_post"], seg=8)
    mb.cyl((x, y, base_z), 0.3, 9.0, M["lamp_post"], seg=8)
    mb.box((x, y, base_z + 9.6), (1.2, 1.2, 1.3), M["lamp_glow"])
    mb.cyl((x, y, base_z + 10.25), 1.0, 0.7, M["lamp_post"], seg=4, r2=0.2, rz=math.pi / 4)


BUNT_COLS = ["red", "yellow", "teal", "sky", "violet", "coral"]


def bunting(mb, a, b, sag=1.6, spacing=1.4):
    a, b = Vector(a), Vector(b)
    d = b - a
    n = max(2, int(d.length / spacing))
    pts = []
    for i in range(n + 1):
        t = i / n
        p = a + d * t
        p.z -= sag * 4 * t * (1 - t)
        pts.append(p)
    for i in range(n):
        mb.rod(pts[i], pts[i + 1], 0.05, M["rail"], seg=4)
        if 0 < i < n:
            p, q = pts[i], pts[i + 1]
            mid = (p + q) / 2
            mb.tri(p, q, Vector((mid.x, mid.y, mid.z - 1.1)), M[BUNT_COLS[i % len(BUNT_COLS)]])


def build_pier():
    top, piles, rails, lamps, bunt = MB(), MB(), MB(), MB(), MB()
    x = WALK_X0 + 3  # walkway pilings
    while x < WALK_X1:
        for y in (-WALK_HALF + 0.8, WALK_HALF - 0.8):
            piles.cyl((x, y, -8), 0.55, DECK_Z - 1.5 + 8, M["piling"], seg=7)
        x += 10
    for ax in ARENA_X:  # arena platforms with side + back rails (front open to the walkway)
        for side in (1, -1):
            build_platform(ax, side, top, piles, M["trim"])
            y0, y1 = PLAT_Y0 * side, PLAT_Y1 * side
            rail(rails, (ax - PLAT_HALF_X + 0.3, y0 + side * 2.5, PLAT_Z), (ax - PLAT_HALF_X + 0.3, y1 - side * 0.3, PLAT_Z))
            rail(rails, (ax + PLAT_HALF_X - 0.3, y0 + side * 2.5, PLAT_Z), (ax + PLAT_HALF_X - 0.3, y1 - side * 0.3, PLAT_Z))
            rail(rails, (ax - PLAT_HALF_X + 0.3, y1 - side * 0.3, PLAT_Z), (ax + PLAT_HALF_X - 0.3, y1 - side * 0.3, PLAT_Z))
    # walkway rails in the gaps between platforms and at the ends
    gaps = [(WALK_X0 + 14, ARENA_X[0] - PLAT_HALF_X)]
    for i in range(len(ARENA_X) - 1):
        gaps.append((ARENA_X[i] + PLAT_HALF_X, ARENA_X[i + 1] - PLAT_HALF_X))
    gaps.append((ARENA_X[-1] + PLAT_HALF_X, WALK_X1 - 4))
    for g0, g1 in gaps:
        for side in (1, -1):
            rail(rails, (g0, side * (WALK_HALF - 0.3), DECK_Z), (g1, side * (WALK_HALF - 0.3), DECK_Z))
    # lamps in the gaps; bunting only ACROSS the walkway so it never blocks the view of a stand
    lamp_x = [6.0] + [ARENA_X[i] + 20 for i in range(len(ARENA_X) - 1)] + [170.0]
    for lx in lamp_x:
        for side in (1, -1):
            lamp(lamps, lx, side * (WALK_HALF + 0.6), DECK_Z)
        bunting(bunt, (lx, -WALK_HALF - 0.6, DECK_Z + 9.4), (lx, WALK_HALF + 0.6, DECK_Z + 9.4), sag=1.8)
    top.obj("ArenaPlatforms", C_PIER)
    piles.obj("Pilings", C_PIER)
    rails.obj("Railings", C_PIER)
    lamps.obj("Lamps", C_PIER)
    bunt.obj("Bunting", C_PIER)
    # entrance arch with sign
    arch = MB()
    for side in (1, -1):
        arch.box((WALK_X0 + 4, side * (WALK_HALF + 0.8), DECK_Z + 7), (1.6, 1.6, 14), M["trim"])
        arch.cyl((WALK_X0 + 4, side * (WALK_HALF + 0.8), DECK_Z + 14), 1.3, 1.8, M["yellow"], seg=8, r2=0.3)
    arch.box((WALK_X0 + 4, 0, DECK_Z + 12.2), (1.4, WALK_HALF * 2 + 3.6, 3.4), M["coral"])
    arch.box((WALK_X0 + 4, 0, DECK_Z + 10.3), (1.6, WALK_HALF * 2 + 3.6, 0.5), M["cream"])
    arch.obj("PierArch", C_PIER)
    text("CLASH PIER", (WALK_X0 + 3.2, 0, DECK_Z + 12.2), -math.pi / 2, 2.2, M["cream"], C_PIER)


# ---------------------------------------------------------------------------
# Arenas: stand + queue pads + number post + small back bleacher
# ---------------------------------------------------------------------------
def queue_pad(mb, x, y, z, glow, scale=1.0):
    mb.cyl((x, y, z), 2.9 * scale, 0.2, glow, seg=16)
    mb.cyl((x, y, z), 2.4 * scale, 0.32, M["pad_base"], seg=16)
    mb.cyl((x, y, z), 1.6 * scale, 0.36, glow, seg=16)


def flag_post(mb, x, y, z, col, h=7.5, facing=1):
    mb.cyl((x, y, z), 0.15, h, M["rail"], seg=5)
    mb.box((x + 0.9 * facing, y, z + h - 0.8), (1.8, 0.12, 1.3), col)


MATCHUPS = {  # (arena index, side): (glassy A, glassy B, swing angle A, swing angle B)
    (0, 1): ("pop", "jam", 0.35, -0.1),
    (1, 1): ("pop", "jam", 0.62, -0.08),  # the close-up arena
    (2, 1): ("prism", "pop", -0.05, -0.45),
    (0, -1): ("jam", "prism", 0.2, -0.2),
    (2, -1): ("pop", "prism", 0.05, -0.05),
    (3, -1): ("jam", "pop", 0.5, 0.05),
}


def build_arenas():
    pads = MB()
    bleach = MB()
    for i, ax in enumerate(ARENA_X):
        for side in (1, -1):
            idx = i + 1 if side == 1 else i + 5
            ay = ARENA_Y * side
            rz = 0.0 if side == 1 else math.pi
            smx = stand_matrix(ax, ay, rz)
            instance(STAND, f"Arena{idx}", C_ARENAS, smx)
            # Pads: HookA side is -X of the stand (mirrored for the south row)
            pa = ax - PAD_OFFSET_X * side
            pb = ax + PAD_OFFSET_X * side
            queue_pad(pads, pa, PAD_Y * side, PLAT_Z, M["pad_a_glow"])
            queue_pad(pads, pb, PAD_Y * side, PLAT_Z, M["pad_b_glow"])
            flag_post(pads, pa - 3.6 * side, (PAD_Y - 0.6) * side, PLAT_Z, M["pad_a"], facing=-side)
            flag_post(pads, pb + 3.6 * side, (PAD_Y - 0.6) * side, PLAT_Z, M["pad_b"], facing=side)
            # number sign between the pads
            pads.cyl((ax, (PAD_Y - 2.0) * side, PLAT_Z), 0.2, 3.2, M["rail"], seg=5)
            pads.cyl((ax, (PAD_Y - 2.0) * side, PLAT_Z + 3.0), 1.3, 0.25, M["navy"], seg=12,
                     rot=Euler((math.pi / 2, 0, 0)).to_matrix().to_4x4())
            text(str(idx), (ax, (PAD_Y - 2.0) * side - 0.35 * side, PLAT_Z + 3.1),
                 0.0 if side == 1 else math.pi, 1.6, M["cream"], C_ARENAS, extrude=0.05)
            # two-step spectator bleacher behind the pen
            yb = (PLAT_Y1 - 3.2) * side
            bleach.box((ax, yb, PLAT_Z + 0.4), (20, 3.6, 0.8), M["coral"] if i % 2 == 0 else M["teal"])
            bleach.box((ax, yb + 0.9 * side, PLAT_Z + 1.2), (20, 1.8, 0.8), M["cream"])
            if (i, side) in MATCHUPS:
                ga, gb, an_a, an_b = MATCHUPS[(i, side)]
                hang(smx, "A", ga, an_a, C_ARENAS, f"A{idx}")
                hang(smx, "B", gb, an_b, C_ARENAS, f"A{idx}")
    pads.obj("QueuePads", C_ARENAS)
    bleach.obj("Bleachers", C_ARENAS)


# ---------------------------------------------------------------------------
# Featured arena at the pier head + glass-bottle lighthouse
# ---------------------------------------------------------------------------
def build_featured():
    fx, fy = FEAT_C
    mb = MB()
    seg = 24
    mb.cyl((fx, fy, PLAT_Z + 0.1 - 1.0), FEAT_R, 1.0, M["plank_a"], seg=seg)
    mb.cyl((fx, fy, PLAT_Z + 0.1 - 1.7), FEAT_R + 0.3, 0.8, M["trim_feat"], seg=seg)
    piles = MB()
    for k in range(16):
        a = k / 16 * math.tau
        piles.cyl((fx + math.cos(a) * (FEAT_R - 1.5), fy + math.sin(a) * (FEAT_R - 1.5), -8), 0.7, PLAT_Z + 8 - 1.6, M["piling"], seg=7)
    piles.obj("FeaturedPilings", C_FEAT)
    # 3-tier ring of bleachers around the back (the side facing the walkway is open)
    for t, (r0, r1, h) in enumerate(((19.6, 21.8, 0.9), (21.8, 24.0, 1.8), (24.0, 26.2, 2.7))):
        n = 22
        a0, a1 = math.radians(-128), math.radians(128)
        for k in range(n):
            a = a0 + (a1 - a0) * (k + 0.5) / n
            rm = (r0 + r1) / 2
            arc = (a1 - a0) / n * rm + 0.15
            col = M["sky"] if k % 2 == 0 else M["cream"]
            if t == 2:
                col = M["trim_feat"] if k % 2 == 0 else M["cream"]
            mb.box((fx + math.cos(a) * rm, fy + math.sin(a) * rm, PLAT_Z + 0.1 + h / 2), (r1 - r0, arc, h), col, rz=a)
    # stand scaled up 1.25 and turned to face the walkway; queue pads at the end of the walkway
    smx = stand_matrix(fx, fy, -math.pi / 2, FEAT_SCALE, PLAT_Z + 0.1)
    instance(STAND, "FeaturedArena", C_FEAT, smx)
    pad_x = fx - FEAT_R + 5.0
    queue_pad(mb, pad_x, 9.0, PLAT_Z + 0.1, M["pad_a_glow"], 1.15)
    queue_pad(mb, pad_x, -9.0, PLAT_Z + 0.1, M["pad_b_glow"], 1.15)
    for y in (13.5, -13.5):
        mb.cyl((pad_x, y, PLAT_Z + 0.1), 0.25, 12, M["rail"], seg=6)
        mb.box((pad_x, y + (1.6 if y > 0 else -1.6), PLAT_Z + 9.0), (0.15, 3.0, 5.0), M["trim_feat"])
        mb.cyl((pad_x, y, PLAT_Z + 12.1), 0.6, 0.6, M["yellow"], seg=8, r2=0.1)
    mb.obj("FeaturedStage", C_FEAT)
    hang(smx, "A", "prism", 0.0, C_FEAT, "Feat")
    hang(smx, "B", "pop", -0.55, C_FEAT, "Feat")
    # Lighthouse: a big frosted sea-glass bottle on a rock island (built at origin, scaled 1.3)
    lx, ly = 0.0, 0.0
    LH_S = 1.3
    lh = MB()
    for k in range(9):
        a = k / 9 * math.tau
        lh.ico((lx + math.cos(a) * 10, ly + math.sin(a) * 10, -1.0), random.uniform(4.5, 6.5), M["rock"] if k % 2 else M["rock_dark"], sub=1,
               scale=(1.2, 1.0, 0.7), rz=a)
    lh.cyl((lx, ly, -3), 13, 6.0, M["rock"], seg=9)
    lh.cyl((lx, ly, 3), 9.5, 2.5, M["cream"], seg=12)
    lh.cyl((lx, ly, 5.5), 7.2, 20.0, M["seaglass"], seg=16)  # bottle body
    lh.cyl((lx, ly, 25.5), 7.2, 6.0, M["seaglass"], seg=16, r2=2.6)  # shoulder
    lh.cyl((lx, ly, 31.5), 2.6, 4.0, M["seaglass"], seg=16)  # neck
    lh.cyl((lx, ly, 35.5), 4.2, 0.5, M["white"], seg=16)  # gallery
    lh.cyl((lx, ly, 36.0), 2.4, 3.6, M["light_room"], seg=12)  # lamp room
    lh.cyl((lx, ly, 39.6), 3.2, 3.0, M["cork"], seg=12, r2=2.8)  # cork roof
    lh.cyl((lx, ly, 42.6), 0.8, 1.2, M["red"], seg=8, r2=0.2)
    lh.cyl((lx, ly, 13.0), 7.35, 5.0, M["red"], seg=16)  # label band
    lh.box((lx - 7.2, ly, 7.8), (0.8, 3.0, 4.6), M["cork"])  # door
    for z in (20.0, 27.5):
        lh.box((lx - 6.6 if z < 25 else lx - 4.7, ly, z), (0.6, 1.6, 2.0), M["navy"])
    lh.obj("BottleLighthouse", C_FEAT, loc=(fx + FEAT_R + 17, 0, 0), scale=LH_S)
    lt = bpy.data.lights.new("LighthouseLamp", "POINT")
    lt.energy = 3000
    lt.color = srgb("#FFE6A3")[:3]
    lo = bpy.data.objects.new("LighthouseLamp", lt)
    lo.location = (fx + FEAT_R + 17, 0, 37.8 * LH_S)
    C_FEAT.objects.link(lo)


# ---------------------------------------------------------------------------
# Lobby on the shore plaza
# ---------------------------------------------------------------------------
def avatar(mb, x, y, z, rz, shirt, pants, skin="#FFD7A8", s=1.0, arm_up=False):
    """Blocky stand-in avatar (~5.5 studs), built facing +X then turned by rz."""
    R = Matrix.Translation((x, y, z)) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Diagonal((s, s, s, 1))

    def b(c, size, m):
        mb.box(R @ Vector(c), [v * s for v in size], m, rz=rz)

    sk = mat("BW_skin_" + skin, skin)
    b((0, -0.5, 1.0), (0.95, 0.95, 2.0), pants)
    b((0, 0.5, 1.0), (0.95, 0.95, 2.0), pants)
    b((0, 0, 3.0), (1.0, 2.0, 2.0), shirt)
    b((0, -1.5, 3.0), (0.9, 0.9, 2.0), sk)
    b((0, 1.5, 4.8 if arm_up else 3.0), (0.9, 0.9, 2.0), sk)
    mb.cyl(R @ Vector((0, 0, 4.0)), 0.62 * s, 1.15 * s, sk, seg=10)
    b((0, 0, 5.25), (1.15, 1.15, 0.35), M["dark"])  # hair / hat


SHIRTS = ["red", "teal", "yellow", "violet", "sky", "coral", "machine_g", "machine_b", "white"]
PANTS = ["navy", "dark", "lamp_post", "beam", "navy"]
SKINS = ["#FFD7A8", "#E8B48A", "#C68B5E", "#8D5A3B", "#F5CBA7"]


def rand_avatar(mb, x, y, z, rz, **kw):
    avatar(mb, x, y, z, rz, M[random.choice(SHIRTS)], M[random.choice(PANTS)], random.choice(SKINS), **kw)


def face(x, y, tx, ty):
    """rz so an avatar at (x, y) looks toward (tx, ty)."""
    return math.atan2(ty - y, tx - x)


def palm(mb, x, y, z, h=12.0, lean=0.0):
    pts = []
    for i in range(6):
        t = i / 5
        pts.append(Vector((x + math.sin(lean) * h * t * t * 0.4, y + math.cos(lean) * h * t * t * 0.4 * 0.3, z + h * t)))
    for i in range(5):
        mb.rod(pts[i], pts[i + 1], 0.75 - i * 0.08, M["trunk"], seg=6)
    top = pts[-1]
    for k in range(7):
        a = k / 7 * math.tau + random.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), math.sin(a), 0))
        tip = top + d * 6.0 + Vector((0, 0, -2.6))
        midp = top + d * 3.0 + Vector((0, 0, 0.6))
        sidev = Vector((-d.y, d.x, 0)) * 1.1
        col = M["leaf"] if k % 2 else M["leaf_light"]
        mb.tri(top, midp + sidev, midp - sidev, col)
        mb.tri(midp + sidev, tip, midp - sidev, col)
    for k in range(3):
        a = k / 3 * math.tau
        mb.ico(top + Vector((math.cos(a) * 0.6, math.sin(a) * 0.6, -0.6)), 0.45, M["trunk"], sub=1)


def umbrella(mb, x, y, z, col):
    mb.cyl((x, y, z), 0.12, 6.0, M["rail"], seg=5)
    mb.cyl((x, y, z + 5.2), 3.4, 1.4, col, seg=8, r2=0.25)


def round_tree(mb, tx, ty):
    tz = ground_z(tx, ty)
    mb.cyl((tx, ty, tz - 0.5), 0.6, 3.5, M["trunk"], seg=5)
    mb.ico((tx, ty, tz + 5.0), random.uniform(2.6, 3.8), M[random.choice(("leaf", "grass_dark", "leaf_light"))], sub=1, scale=(1, 1, 1.15))


def build_lobby():
    mb = MB()
    # paved plaza disc with a teal tile ring
    mb.cyl((PLAZA_C.x, PLAZA_C.y, SAND_Z - 0.2), PLAZA_R + 1.2, PLAZA_Z - SAND_Z + 0.15, M["plaza_ring"], seg=32)
    mb.cyl((PLAZA_C.x, PLAZA_C.y, SAND_Z - 0.2), PLAZA_R, PLAZA_Z - SAND_Z + 0.2, M["plaza"], seg=32)
    # spawn pad with a ring of short bollards
    mb.cyl((SPAWN.x, SPAWN.y, PLAZA_Z - 0.1), 7.0, 0.35, M["spawn_glow"], seg=24)
    mb.cyl((SPAWN.x, SPAWN.y, PLAZA_Z - 0.1), 6.2, 0.45, M["cream"], seg=24)
    mb.cyl((SPAWN.x, SPAWN.y, PLAZA_Z - 0.1), 2.0, 0.5, M["sky"], seg=12)
    for k in range(8):
        a = k / 8 * math.tau + math.pi / 8
        mb.cyl((SPAWN.x + math.cos(a) * 7.6, SPAWN.y + math.sin(a) * 7.6, PLAZA_Z), 0.55, 0.9, M["trim"], seg=6)
        mb.cyl((SPAWN.x + math.cos(a) * 7.6, SPAWN.y + math.sin(a) * 7.6, PLAZA_Z + 0.9), 0.55, 0.3, M["yellow"], seg=6)
    mb.obj("PlazaGround", C_SHORE)

    # plaza inlays: a sun-burst mosaic, teal "follow me" stripes to the pier, planters
    mo = MB()
    cxp, cyp = PLAZA_C.x + 6, PLAZA_C.y
    mo.cyl((cxp, cyp, PLAZA_Z - 0.1), 11.5, 0.14, M["plaza_ring"], seg=24)
    mo.cyl((cxp, cyp, PLAZA_Z - 0.1), 10.3, 0.17, M["cream"], seg=24)
    for k in range(12):
        a = k / 12 * math.tau
        d = Vector((math.cos(a), math.sin(a), 0))
        sd = Vector((-d.y, d.x, 0))
        r = 9.6 if k % 2 == 0 else 6.5
        c = Vector((cxp, cyp, PLAZA_Z + 0.09))
        mo.tri(c + sd * 1.6, c + d * r, c - sd * 1.6, M["yellow"] if k % 2 == 0 else M["coral"])
    mo.cyl((cxp, cyp, PLAZA_Z - 0.1), 2.4, 0.22, M["sky"], seg=12)
    for side in (1, -1):
        for x0, x1 in ((SPAWN.x + 7.2, cxp - 11.6), (cxp + 11.6, WALK_X0 + 1.0)):
            mo.box(((x0 + x1) / 2, side * 4.2, PLAZA_Z + 0.02), (x1 - x0, 0.9, 0.1), M["plaza_ring"])
    for k, a in enumerate((70, 110, 160, 200, 250, 290)):
        r = PLAZA_R - 2.5
        px, py = PLAZA_C.x + math.cos(math.radians(a)) * r, PLAZA_C.y + math.sin(math.radians(a)) * r
        mo.cyl((px, py, PLAZA_Z - 0.1), 2.6, 1.3, M["brick"], seg=8)
        mo.ico((px, py, PLAZA_Z + 1.6), 2.2, M["leaf"], sub=1, scale=(1, 1, 0.8))
        mo.ico((px + 1.2, py - 0.6, PLAZA_Z + 2.4), 0.5, M[["red", "yellow", "violet"][k % 3]], sub=1)
        mo.ico((px - 1.0, py + 0.8, PLAZA_Z + 2.3), 0.45, M[["yellow", "violet", "red"][k % 3]], sub=1)
    mo.obj("PlazaInlays", C_SHORE)

    # --- Glassblower's workshop + 3 crate machines (north) ---
    ws = MB()
    wx, wy = -36.0, 40.0
    ws.box((wx, wy, SAND_Z + 4.5), (24, 12, 9), M["cream"])
    for sgn in (-1, 1):  # gable roof slopes
        ws.poly(
            [(wx - 13, wy + 7 * sgn, SAND_Z + 9), (wx + 13, wy + 7 * sgn, SAND_Z + 9),
             (wx + 13, wy + 7 * sgn, SAND_Z + 9.6), (wx - 13, wy + 7 * sgn, SAND_Z + 9.6)],
            [(wx - 13, wy, SAND_Z + 14.5), (wx + 13, wy, SAND_Z + 14.5), (wx + 13, wy, SAND_Z + 15.1), (wx - 13, wy, SAND_Z + 15.1)],
            M["coral"],
        )
    ws.poly(  # gable ends
        [(wx - 11.9, wy - 6, SAND_Z + 9), (wx - 11.9, wy + 6, SAND_Z + 9), (wx - 11.9, wy, SAND_Z + 14.4)],
        [(wx + 11.9, wy - 6, SAND_Z + 9), (wx + 11.9, wy + 6, SAND_Z + 9), (wx + 11.9, wy, SAND_Z + 14.4)],
        M["cream"],
    )
    ws.box((wx, wy - 6.05, SAND_Z + 3.4), (8, 0.3, 6.8), M["beam"])  # doorway
    ws.box((wx, wy - 6.15, SAND_Z + 3.2), (6.6, 0.3, 6.2), M["dark"])
    for dx in (-8.5, 8.5):
        ws.box((wx + dx, wy - 6.1, SAND_Z + 5.0), (3.6, 0.3, 3.0), M["navy"])
        ws.box((wx + dx, wy - 6.2, SAND_Z + 5.0), (3.9, 0.2, 0.3), M["cream"])
    # kiln: chunky brick dome with a glowing mouth, and a tall chimney
    kx, ky = wx + 17, wy + 1
    ws.cyl((kx, ky, SAND_Z), 6.0, 3.5, M["brick"], seg=10)
    ws.ico((kx, ky, SAND_Z + 3.5), 5.6, M["brick"], sub=1, scale=(1, 1, 0.8))
    ws.cyl((kx - 1.5, ky - 4.5, SAND_Z + 1.0), 1.9, 2.0, M["kiln_glow"], seg=8, rot=Euler((math.pi / 2, 0, 0)).to_matrix().to_4x4())
    ws.cyl((kx + 1.5, ky + 1.5, SAND_Z + 6), 1.6, 13, M["brick_dark"], seg=8)
    ws.cyl((kx + 1.5, ky + 1.5, SAND_Z + 19), 2.1, 1.0, M["brick"], seg=8)
    # crate machines: mini kilns with a dome, glowing hatch and coin plate (one per crate tier)
    for dx, col in ((-9.0, "machine_g"), (0.0, "machine_b"), (9.0, "machine_p")):
        cx, cy = wx + dx, wy - 13.5
        ws.box((cx, cy, SAND_Z + 1.9), (5.0, 5.0, 3.8), M[col])
        ws.box((cx, cy, SAND_Z + 0.25), (5.6, 5.6, 0.5), M["dark"])
        ws.ico((cx, cy, SAND_Z + 3.8), 2.6, M["cream"], sub=1, scale=(1, 1, 0.9))
        ws.ico((cx, cy, SAND_Z + 6.4), 0.9, M[col], sub=1)
        ws.box((cx, cy - 2.55, SAND_Z + 2.3), (2.4, 0.2, 1.6), M["kiln_glow"])
        ws.box((cx + 1.6, cy - 2.55, SAND_Z + 1.0), (0.8, 0.2, 0.8), M["gold"])
        ws.cyl((cx, cy - 2.7, SAND_Z + 7.8), 0.12, 2.0, M["rail"], seg=4)
    ws.box((wx, wy - 13.5, SAND_Z + 10.2), (24, 0.5, 2.4), M["navy"])  # sign arch
    for dx in (-12.5, 12.5):
        ws.box((wx + dx, wy - 13.5, SAND_Z + 5.4), (0.6, 0.6, 10.8), M["beam"])
    ws.obj("Workshop", C_SHORE)
    text("GLASS CRATES", (wx, wy - 13.85, SAND_Z + 10.2), 0.0, 1.6, M["yellow"], C_SHORE, extrude=0.05)

    # --- Shop kiosk (south-west) ---
    sh = MB()
    sx, sy = -40.0, -38.0
    sh.box((sx, sy, SAND_Z + 1.9), (14, 6, 3.8), M["cream"])
    sh.box((sx, sy - 3.05, SAND_Z + 2.0), (13.6, 0.2, 2.4), M["sky"])
    for dx in (-6.6, 6.6):
        sh.box((sx + dx, sy + 2, SAND_Z + 5.0), (0.5, 0.5, 6.2), M["rail"])
    for k in range(8):  # striped awning
        sh.box((sx - 6.125 + k * 1.75, sy - 1.0, SAND_Z + 8.2), (1.75, 7.5, 0.4), M["red"] if k % 2 == 0 else M["cream"],
               rot=Euler((-0.25, 0, 0)).to_matrix().to_4x4())
    sh.box((sx, sy + 1.0, SAND_Z + 9.8), (6, 0.6, 2.4), M["navy"])
    sh.ico((sx, sy + 1.0, SAND_Z + 13.0), 1.8, M["sky"], sub=0, scale=(1, 1, 1.4))  # gem
    sh.obj("ShopKiosk", C_SHORE)
    text("SHOP", (sx, sy + 0.65, SAND_Z + 9.8), 0.0, 1.5, M["yellow"], C_SHORE, extrude=0.05)

    # --- Glass Gallery (collection index pavilion, south-east) ---
    gx, gy = -12.0, -38.0
    ga = MB()
    ga.cyl((gx, gy, SAND_Z), 10.0, 0.6, M["plaza_ring"], seg=8)
    for k in range(8):
        a = k / 8 * math.tau + math.pi / 8
        ga.cyl((gx + math.cos(a) * 8.8, gy + math.sin(a) * 8.8, SAND_Z + 0.6), 0.45, 8.0, M["rail"], seg=6)
    ga.cyl((gx, gy, SAND_Z + 8.6), 10.4, 0.8, M["teal"], seg=8)
    ga.cyl((gx, gy, SAND_Z + 9.4), 9.6, 4.2, M["teal"], seg=8, r2=0.8)
    ga.ico((gx, gy, SAND_Z + 14.0), 1.0, M["yellow"], sub=1)
    for t, (r, h) in enumerate(((5.0, 1.2), (3.4, 2.4), (1.8, 3.6))):  # tiered display stand
        ga.cyl((gx, gy, SAND_Z + 0.6), r, h, M["cream"] if t % 2 == 0 else M["sky"], seg=12)
    ga.obj("GlassGallery", C_SHORE)
    heights = {"pop": 2.46, "jam": 2.04, "prism": 2.52}
    gids = ["pop", "jam", "prism"]
    n = 0
    for (r, z), cnt in zip(((4.2, 1.8), (2.6, 3.0), (0.0, 4.2)), (8, 5, 1)):
        for k in range(cnt):
            a = k / cnt * math.tau + 0.3
            gid = gids[n % 3]
            n += 1
            s = 0.75 if r > 0 else 1.1
            loc = Vector((gx + math.cos(a) * r, gy + math.sin(a) * r, SAND_Z + z + heights[gid] * s))
            instance(GLASSY[gid], f"Gallery_{gid}_{n}", C_SHORE, Matrix.LocRotScale(loc, Euler((0, 0, a)), Vector((s, s, s))))

    # --- Champion statue under a spotlight (north-east, by the pier gate) ---
    st = MB()
    cx, cy = -12.0, 24.0
    rz = face(cx, cy, SPAWN.x, SPAWN.y)
    st.cyl((cx, cy, SAND_Z), 4.6, 0.6, M["trim_feat"], seg=12)
    st.cyl((cx, cy, SAND_Z + 0.6), 4.0, 3.2, M["cream"], seg=12)
    st.cyl((cx, cy, SAND_Z + 3.8), 4.3, 0.4, M["trim_feat"], seg=12)
    avatar(st, cx, cy, SAND_Z + 4.2, rz, M["gold"], M["gold"], "#F2C14E", s=1.9, arm_up=True)
    st.obj("ChampionStatue", C_SHORE)
    hand = Matrix.Translation((cx, cy, SAND_Z + 4.2)) @ Matrix.Rotation(rz, 4, "Z") @ Vector((0, 1.5 * 1.9, 5.8 * 1.9 + 3.3))
    instance(GLASSY["prism"], "ChampionTrophy", C_SHORE, Matrix.LocRotScale(hand, Euler((0, 0, 0)), Vector((1.4, 1.4, 1.4))))
    MB().cyl((cx, cy, SAND_Z + 0.7), 5.0, 32.0, M["beam"], seg=12, r2=1.4).obj("ChampionBeam", C_SHORE)
    sp = bpy.data.lights.new("ChampionSpot", "SPOT")
    sp.energy = 9000
    sp.spot_size = math.radians(22)
    sp.color = srgb("#FFF0C0")[:3]
    so = bpy.data.objects.new("ChampionSpot", sp)
    so.location = (cx, cy, SAND_Z + 34)
    C_SHORE.objects.link(so)

    # --- Leaderboards behind spawn, codes board, daily chest ---
    lb = MB()
    for (bx, by, brz) in ((-68.0, 14.0, -0.35), (-68.0, -14.0, 0.35)):
        R = Euler((0, 0, brz)).to_matrix().to_4x4()
        for dy in (-5.4, 5.4):
            p = Matrix.Translation((bx, by, 0)) @ R @ Vector((0, dy, 0))
            lb.box((p.x, p.y, SAND_Z + 6.5), (0.8, 0.8, 13), M["beam"], rz=brz)
        lb.box((bx, by, SAND_Z + 8.0), (0.6, 11.0, 9.0), M["navy"], rz=brz)
        lb.box((bx - 0.1, by, SAND_Z + 12.7), (0.7, 11.6, 0.6), M["trim_feat"], rz=brz)
        for r, col in enumerate(("gold", "silver", "bronze", "cream", "cream", "cream")):
            p = Matrix.Translation((bx, by, 0)) @ R @ Vector((0.35, 0.0, 0))
            lb.box((p.x, p.y, SAND_Z + 11.0 - r * 1.25), (0.2, 9.0 - (2.0 if r > 2 else 0), 0.8), M[col], rz=brz)
    cbx, cby = -58.0, 16.0  # codes board: chalkboard easel
    lb.box((cbx, cby, SAND_Z + 3.0), (0.4, 4.4, 3.2), M["chalk"], rz=0.6)
    lb.box((cbx, cby, SAND_Z + 3.0), (0.3, 4.9, 3.7), M["beam"], rz=0.6)
    for k in range(3):
        lb.box((cbx + 0.15, cby, SAND_Z + 3.9 - k * 0.8), (0.1, 3.0 - k * 0.6, 0.25), M["cream"], rz=0.6)
    lb.box((cbx + 0.6, cby, SAND_Z + 0.75), (0.3, 0.3, 1.5), M["beam"], rz=0.6)
    chx, chy = -58.0, -16.0  # daily reward chest on a glowing ring
    lb.cyl((chx, chy, PLAZA_Z - 0.05), 3.6, 0.25, M["chest_glow"], seg=16)
    lb.box((chx, chy, PLAZA_Z + 1.0), (3.6, 2.4, 2.0), M["brick"], rz=-0.6)
    lb.cyl((chx, chy, PLAZA_Z + 2.0), 1.2, 3.6, M["brick"], seg=8,
           rot=Euler((0, math.pi / 2, -0.6)).to_matrix().to_4x4() @ Matrix.Translation((0, 0, -1.8)))
    for d in (-1.1, 1.1):
        p = Vector((chx, chy, 0)) + Euler((0, 0, -0.6)).to_matrix() @ Vector((d, 0, 0))
        lb.box((p.x, p.y, PLAZA_Z + 1.6), (0.35, 2.55, 3.2), M["gold"], rz=-0.6)
    lb.obj("LobbyBoards", C_SHORE)
    text("CODES", (cbx + 0.25, cby, SAND_Z + 5.4), 0.6 + math.pi / 2, 0.9, M["cream"], C_SHORE, extrude=0.03)

    # --- Beach dressing: palms, umbrellas, towels, sandcastle, trees on the headlands ---
    deco = MB()
    for (px, py, h, lean) in ((-72, 34, 13, 0.4), (-78, -30, 12, -0.3), (-58, 52, 11, 1.2), (-60, -56, 14, 2.4), (-20, 60, 12, 0.8),
                              (-28, -62, 12, 2.0), (2, 40, 11, 1.4), (4, -44, 13, 1.8), (-92, 8, 14, 0.2), (-96, -48, 12, 0.5),
                              (-90, 60, 12, 0.9), (20, 76, 10, 1.0), (14, -82, 12, 2.2)):
        palm(deco, px, py, ground_z(px, py) - 0.3, h, lean)
    for (ux, uy, col) in ((6, 22, "red"), (10, 30, "yellow"), (4, -22, "teal"), (12, -30, "violet"), (-2, 66, "coral"), (8, -62, "sky")):
        umbrella(deco, ux, uy, SAND_Z - 0.1, M[col])
        deco.box((ux + 2.6, uy, SAND_Z + 0.05), (2.0, 4.6, 0.12), M[random.choice(["sky", "coral", "yellow", "white"])], rz=0.3)
    scx, scy = 0.0, 52.0  # sandcastle
    deco.box((scx, scy, SAND_Z + 1.0), (5, 5, 2), M["sand_wet"])
    for dx in (-2.5, 2.5):
        for dy in (-2.5, 2.5):
            deco.cyl((scx + dx, scy + dy, SAND_Z), 1.0, 3.2, M["sand_wet"], seg=6)
            deco.cyl((scx + dx, scy + dy, SAND_Z + 3.2), 1.0, 1.0, M["sand_wet"], seg=6, r2=0.1)
    deco.cyl((scx, scy, SAND_Z + 2), 0.06, 3.0, M["rail"], seg=4)
    deco.box((scx + 0.6, scy, SAND_Z + 4.6), (1.2, 0.08, 0.8), M["red"])
    for _ in range(46):
        side = random.choice((1, -1))
        tx, ty = random.uniform(-200, 70), side * random.uniform(122, 250)
        if tx > shore_x(ty) - 10:
            continue
        round_tree(deco, tx, ty)
    for _ in range(18):
        round_tree(deco, random.uniform(-230, -110), random.uniform(-110, 110))
    deco.obj("BeachDeco", C_SHORE)


# ---------------------------------------------------------------------------
# Life: rocks, boats, buoys, gulls, players
# ---------------------------------------------------------------------------
def boat(mb, x, y, rz, hull, sail=True):
    R = Matrix.Translation((x, y, -0.4)) @ Matrix.Rotation(rz, 4, "Z")
    s = 1.6
    bot = [R @ Vector(p) for p in ((-3.5 * s, -0.8 * s, 0), (2.5 * s, -0.8 * s, 0), (4.0 * s, 0, 0.3), (2.5 * s, 0.8 * s, 0), (-3.5 * s, 0.8 * s, 0))]
    top = [R @ Vector(p) for p in ((-4 * s, -1.5 * s, 1.6 * s), (3 * s, -1.5 * s, 1.6 * s), (5.2 * s, 0, 2.0 * s), (3 * s, 1.5 * s, 1.6 * s), (-4 * s, 1.5 * s, 1.6 * s))]
    mb.poly(bot, top, hull)
    mb.box(R @ Vector((-0.5, 0, 1.6 * s + 0.1)), (6.5 * s, 2.6 * s, 0.25), M["plank_a"], rz=rz)
    if sail:
        mb.rod(R @ Vector((0.5, 0, 1.6 * s)), R @ Vector((0.5, 0, 1.6 * s + 11)), 0.18, M["beam"])
        mb.tri(R @ Vector((0.9, 0, 1.6 * s + 1.0)), R @ Vector((0.9, 0, 1.6 * s + 10.5)), R @ Vector((6.5, 0, 1.6 * s + 1.0)), M["cream"])
        mb.tri(R @ Vector((0.1, 0, 1.6 * s + 1.4)), R @ Vector((0.1, 0, 1.6 * s + 9.0)), R @ Vector((-4.5, 0, 1.6 * s + 1.4)), M["coral"])
    else:
        mb.box(R @ Vector((-2.5, 0, 1.6 * s + 1.2)), (3, 2.6, 2.2), M["cream"], rz=rz)
        mb.box(R @ Vector((-2.5, 0, 1.6 * s + 2.5)), (3.4, 3.0, 0.3), M["red"], rz=rz)


def gull(mb, x, y, z, rz, s=1.0):
    R = Matrix.Translation((x, y, z)) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Diagonal((s, s, s, 1))
    mb.ico(R @ Vector((0, 0, 0)), 0.5 * s, M["white"], sub=1, scale=(1.8 * s, 0.9 * s, 0.8 * s), rz=rz)
    for side in (1, -1):
        rot = Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(side * 0.35, 4, "X")
        mb.box(R @ Vector((0, side * 1.4, 0.35)), (0.9 * s, 2.6 * s, 0.12 * s), M["white"], rot=rot)
        mb.box(R @ Vector((0.1, side * 2.6, 0.78)), (0.7 * s, 0.4 * s, 0.13 * s), M["dark"], rot=rot)
    mb.box(R @ Vector((0.95, 0, 0.05)), (0.5 * s, 0.2 * s, 0.2 * s), M["yellow"], rz=rz)


def build_life():
    sea = MB()
    for (rx, ry, n) in ((70, 78, 4), (128, -84, 5), (196, 58, 3), (205, -60, 4), (36, -72, 3), (250, 30, 3), (95, 120, 3)):
        for k in range(n):
            sea.ico((rx + random.uniform(-6, 6), ry + random.uniform(-6, 6), random.uniform(-1.5, 0.2)), random.uniform(2.2, 4.8),
                    M["rock"] if k % 2 else M["rock_dark"], sub=1, scale=(1.3, 1.0, 0.8), rz=random.uniform(0, 3))
    boat(sea, 96, -112, 0.4, M["red"])
    boat(sea, 168, 96, 2.6, M["yellow"])
    boat(sea, 30, 108, -0.3, M["trim"], sail=False)
    boat(sea, 250, -96, 1.2, M["teal"])
    for (bx, by) in ((50, 64), (90, 64), (130, 64), (50, -64), (90, -64), (130, -64), (175, 42), (175, -42)):  # buoys
        sea.cyl((bx, by, -0.6), 1.1, 1.2, M["red"], seg=8)
        sea.cyl((bx, by, 0.6), 0.9, 1.5, M["white"], seg=8, r2=0.2)
    sea.obj("SeaLife", C_LIFE)
    birds = MB()
    for k in range(11):
        gull(birds, random.uniform(-10, 220), random.uniform(-60, 60), random.uniform(26, 44), random.uniform(0, math.tau), random.uniform(1.0, 1.4))
    birds.obj("Gulls", C_LIFE)

    ppl = MB()
    ax = ARENA_X[1]  # two players on the pads of the close-up arena (Arena 2)
    for sx in (-PAD_OFFSET_X, PAD_OFFSET_X):
        avatar(ppl, ax + sx, PAD_Y, PLAT_Z + 0.36, math.pi / 2, M["teal"] if sx < 0 else M["coral"], M["navy"], random.choice(SKINS))
    queued = {(ARENA_X[0] + 7, -PAD_Y), (ARENA_X[0] - 7, -PAD_Y), (ARENA_X[2] + 7, PAD_Y)}
    spots = [  # spectators along the walkway, beside the pens and on the back bleachers
        (ax - 15.5, 20, 0.0), (ax + 15.5, 24, math.pi), (ax + 19, 4.0, math.pi / 2), (ax + 13, 3.2, math.pi / 2), (ax + 10, 5, math.pi / 2),
        (ax - 21, 2.0, math.pi / 2 + 0.3), (ax + 5, 47.5, -math.pi / 2), (ax - 4, 47.5, -math.pi / 2),
        (ARENA_X[0] + 3, 5.0, math.pi / 2), (ARENA_X[0] - 6, 4.5, math.pi / 2), (ARENA_X[2] + 1, 3.5, math.pi / 2),
        (ARENA_X[0] - 2, -4.0, -math.pi / 2), (ARENA_X[2] - 4, -4.6, -math.pi / 2), (ARENA_X[3] + 3, -3.5, -math.pi / 2),
        (ARENA_X[0] + 7, -PAD_Y, -math.pi / 2), (ARENA_X[0] - 7, -PAD_Y, -math.pi / 2),
        (ARENA_X[2] + 7, PAD_Y, math.pi / 2),
        (ARENA_X[3] - 12, 0.5, 0.0), (ARENA_X[1] - 22, -1.0, 0.0), (ARENA_X[2] + 20, 1.5, math.pi),
    ]
    for (x, y, rz) in spots:
        z = PLAT_Z if abs(y) > WALK_HALF else DECK_Z
        if (x, y) in queued:
            z = PLAT_Z + 0.36
        rand_avatar(ppl, x, y, z, rz)
    fx, fy = FEAT_C  # featured crowd on the bleachers + two queued players
    for k in range(18):
        a = math.radians(random.uniform(-120, 120))
        r, h = random.choice(((20.7, 0.9), (22.9, 1.8), (25.1, 2.7)))
        rand_avatar(ppl, fx + math.cos(a) * r, fy + math.sin(a) * r, PLAT_Z + 0.1 + h, a + math.pi)
    for y in (9.0, -9.0):
        rand_avatar(ppl, fx - FEAT_R + 5.0, y, PLAT_Z + 0.5, 0.0)
    lobby = [  # (x, y, facing or None to face the target below)
        (-45, 26, None), (-36, 25, None), (-27, 25.5, None), (-40, -30, None), (-35, -31, None), (-12, -26, None), (-16, -29, None),
        (-24, 31, 0.2), (-16, -13, 0.3), (-8, -6, 0.1), (-60, -12, None), (-34, -15, 0.6), (-18, 18, None),
    ]
    targets = {(-45, 26): (-45, 40), (-36, 25): (-36, 40), (-27, 25.5): (-27, 40), (-40, -30): (-40, -38), (-35, -31): (-35, -38),
               (-12, -26): (-12, -38), (-16, -29): (-12, -38), (-60, -12): (-58, -16), (-18, 18): (-12, 24)}
    for (x, y, rz) in lobby:
        if rz is None:
            rz = face(x, y, *targets[(x, y)])
        rand_avatar(ppl, x, y, PLAZA_Z if math.hypot(x - PLAZA_C.x, y - PLAZA_C.y) < PLAZA_R else SAND_Z, rz)
    ppl.obj("Players", C_LIFE)


# ---------------------------------------------------------------------------
# World, light, cameras, render
# ---------------------------------------------------------------------------
def setup_world():
    w = bpy.data.worlds.new("BW_World")
    scene.world = w
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
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    cr = ramp.color_ramp  # camera sees a horizon-to-zenith gradient; lighting uses a flat sky blue
    cr.elements[0].position = 0.0
    cr.elements[0].color = srgb("#D6F1FA")
    cr.elements[1].position = 0.6
    cr.elements[1].color = srgb("#3F9BE0")
    cr.elements.new(0.12).color = srgb("#86CBF3")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg_cam.inputs["Color"])
    bg_amb.inputs["Color"].default_value = srgb("#A9D6F2")
    bg_amb.inputs["Strength"].default_value = 0.75
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs["Fac"])
    nt.links.new(bg_amb.outputs[0], mix.inputs[1])
    nt.links.new(bg_cam.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])

    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.6
    sun.angle = math.radians(2.5)
    sun.color = srgb("#FFE2B8")[:3]
    so = bpy.data.objects.new("Sun", sun)
    # golden afternoon: sun from the south-west (left of the aerial camera), shadows fall north-east
    so.rotation_euler = Euler((math.radians(54), 0, math.radians(-32)))
    scene.collection.objects.link(so)


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
        try:
            vs.look = "Punchy"
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
    "aerial": ((-92.0, -158.0, 122.0), (68.0, 6.0, -6.0), 28.0),
    "spawn": ((SPAWN.x + 1.0, -1.0, PLAZA_Z + 0.35 + 5.6), (40.0, 6.0, 9.0), 21.0),
    "arena": ((ARENA_X[1] - 15.0, -11.0, DECK_Z + 12.5), (ARENA_X[1] + 0.5, 24.0, 8.0), 31.0),
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
             "import sys;from PIL import Image;Image.open(sys.argv[1]).convert('RGB').save(sys.argv[2],quality=85)", png, jpg],
            check=True,
        )
        os.remove(png)
        print("wrote", jpg)


build_terrain()
build_sea()
build_walkway()
build_pier()
build_arenas()
build_featured()
build_lobby()
build_life()
setup_world()
setup_render()
if os.environ.get("BW_SAVE"):
    bpy.ops.wm.save_as_mainfile(filepath=os.environ["BW_SAVE"])
render_all()
