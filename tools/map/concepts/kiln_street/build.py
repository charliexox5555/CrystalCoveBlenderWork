"""Glass Clash map concept: KILN STREET.

A cozy cobblestone glassblower village street. Spawn square with the crate machines in a
glowing kiln shop; six Clash Stand arenas in courtyards alternating left/right of the street;
a featured arena in front of a brick furnace chimney topped with a giant glass bottle.

Run (headless bpy 5.x, Cycles CPU), from any directory:
    <bpyenv>/bin/python tools/map/concepts/kiln_street/build.py [--quick] [--only aerial,spawn,arena]

Coordinates are studs (1 Blender unit = 1 stud). X = east (left/right of the street),
Y = north (down the street, away from spawn), Z = up. In Roblox: X = X, Y(rbx) = Z, Z(rbx) = -Y.
Renders aerial.jpg, spawn.jpg, arena.jpg into docs/art/concepts/kiln_street/.
"""

import bpy  # noqa: F401  (must be imported before bmesh/mathutils)
import bmesh
import math
import os
import random
import subprocess
import sys
from mathutils import Matrix, Vector


def _find_repo():
    d = os.path.dirname(os.path.abspath(__file__))
    for _ in range(8):
        if os.path.exists(os.path.join(d, "assets", "blender", "map", "clash_stand.blend")):
            return d
        d = os.path.dirname(d)
    return os.environ.get("GLASSCLASH_REPO", "/home/user/CrystalCoveBlenderWork")


REPO = _find_repo()
STAND_BLEND = os.path.join(REPO, "assets", "blender", "map", "clash_stand.blend")
STAND_COLLECTION = "GlassClash_ClashStand.001"
GLASSY_DIR = os.path.join(REPO, "assets", "blender", "glassies")
OUT_DIR = os.path.join(REPO, "docs", "art", "concepts", "kiln_street")

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
QUICK = "--quick" in ARGS
ONLY = None
for i, a in enumerate(ARGS):
    if a == "--only" and i + 1 < len(ARGS):
        ONLY = set(ARGS[i + 1].split(","))

random.seed(7)

# ---------------------------------------------------------------- layout numbers (studs)
STREET_HALF = 10.0  # cobbled street is 20 wide (x -10..10)
FRONT_LINE = 13.0  # cottage facades (3-stud sidewalks)
PEN_HALF = 14.34  # measured Clash Stand pen half-size (28.7 x 28.7 footprint, 17.4 tall)
HOOK_Z = 15.02  # measured bottom of HookA/HookB (re-measured below)
HOOK_X = 1.5  # measured hook offset from stand centre along the crossbar (re-measured below)
STRING = 5.0  # Balance.Motion StringLength
APRON = 7.2  # courtyard apron between street edge and pen (queue pads live here)
PEN_CX = STREET_HALF + APRON + PEN_HALF  # 31.5: courtyard pen centre distance from street axis
COURT_HALF_Y = 18.0  # courtyards are 36 along the street
ARENA_PITCH = 23.0  # alternate sides every 23 studs -> same side every 46 (10-stud cottage gap)
ARENA_Y0 = 42.0
N_ARENAS = 6
SPAWN = Vector((0.0, -22.0, 0.0))
FEATURED = Vector((0.0, 214.0, 0.0))
FEATURED_SCALE = 1.3
PLINTH_R = 28.0
PLINTH_H = 1.2
CHIMNEY_Y = 270.0
GROUND_Z = 0.12  # top of paving

ARENAS = []  # (index, side, y)
for i in range(N_ARENAS):
    side = -1 if i % 2 == 0 else 1
    ARENAS.append((i, side, ARENA_Y0 + i * ARENA_PITCH))

# ---------------------------------------------------------------- palette
PAL = {
    "grass": "#8CCB5E",
    "grass_dark": "#6DAE4A",
    "lawn": "#A6DB78",
    "cobble_a": "#C9B8A3",
    "cobble_b": "#B3A08A",
    "mortar": "#8E7C6A",
    "sidewalk": "#E3D3B8",
    "paver": "#E8C99A",
    "paver_b": "#DDB985",
    "brick": "#C0623F",
    "brick_dark": "#8E4430",
    "stone": "#CFC6B8",
    "stone_dark": "#9C9286",
    "wood": "#A0673C",
    "wood_dark": "#6E4425",
    "iron": "#3B3A45",
    "gold": "#F5C542",
    "kiln": "#FF8A2A",
    "lamp": "#FFD27A",
    "window": "#5B7FA6",
    "frame": "#FFF4DE",
    "hedge": "#4E9A47",
    "leaf": "#5FB64F",
    "leaf_b": "#7CCB55",
    "trunk": "#7A5233",
    "slate": "#56607A",
    "walls": ["#FFE6B8", "#FFC9A8", "#BDE8D2", "#BFDDF5", "#FFF1A8", "#F7C6D9", "#E4D3F5"],
    "roofs": ["#D9603B", "#2F9C95", "#8E5BA8", "#3F7FBF", "#C7493A", "#E08A2C"],
    "flowers": ["#FF5E7E", "#FFD23F", "#FFFFFF", "#FF8FB1", "#B388FF"],
    "bunting": ["#FF5E5E", "#FFD23F", "#4FC3F7", "#7ED957", "#FF8FD1", "#B388FF"],
    "pad_a": "#3FD0FF",
    "pad_b": "#FF9A3C",
    "pop": "#8FE3FF",
    "jam": "#FF6B8B",
    "prism": "#C9A8FF",
}


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c) + (1.0,)


# ---------------------------------------------------------------- scene reset
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
ROOT = scene.collection


def new_collection(name, parent=None):
    c = bpy.data.collections.new(name)
    (parent or ROOT).children.link(c)
    return c


COL = {k: new_collection(k) for k in ("Ground", "Lobby", "Street", "Arenas", "Featured", "Props", "People", "Nature")}

# ---------------------------------------------------------------- materials
_MATS = {}


def mat(hexcol, rough=0.85, emit=0.0, metal=0.0, name=None):
    key = (hexcol, rough, emit, metal)
    if key in _MATS:
        return _MATS[key]
    m = bpy.data.materials.new(name or f"M_{hexcol.strip('#')}_{len(_MATS)}")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = srgb(hexcol)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0:
        b.inputs["Emission Color"].default_value = srgb(hexcol)
        b.inputs["Emission Strength"].default_value = emit
    m.diffuse_color = srgb(hexcol)
    _MATS[key] = m
    return m


def glass_mat(hexcol, glow=0.45, name=None):
    """Glossy tinted preview glass (in Roblox: Glass material, Transparency ~0.3)."""
    m = bpy.data.materials.new(name or f"Glass_{hexcol.strip('#')}")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = srgb(hexcol)
    b.inputs["Roughness"].default_value = 0.04
    b.inputs["IOR"].default_value = 1.45
    b.inputs["Transmission Weight"].default_value = 0.7
    b.inputs["Coat Weight"].default_value = 0.6
    b.inputs["Coat Roughness"].default_value = 0.02
    b.inputs["Emission Color"].default_value = srgb(hexcol)
    b.inputs["Emission Strength"].default_value = glow
    m.diffuse_color = srgb(hexcol)
    return m


def pattern_mat(name, col_a, col_b, mortar, scale, brick_w=1.0, row_h=0.5, vertical=False, mortar_size=0.04):
    """Matte brick/cobble pattern from world position (concept hint only; in Studio use Cobblestone/Brick)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.9
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(geo.outputs["Position"], sep.inputs[0])
    if vertical:
        add = nt.nodes.new("ShaderNodeMath")
        add.operation = "ADD"
        nt.links.new(sep.outputs[0], add.inputs[0])
        nt.links.new(sep.outputs[1], add.inputs[1])
        nt.links.new(add.outputs[0], comb.inputs[0])
        nt.links.new(sep.outputs[2], comb.inputs[1])
    else:
        nt.links.new(sep.outputs[0], comb.inputs[0])
        nt.links.new(sep.outputs[1], comb.inputs[1])
    br = nt.nodes.new("ShaderNodeTexBrick")
    br.inputs["Color1"].default_value = srgb(col_a)
    br.inputs["Color2"].default_value = srgb(col_b)
    br.inputs["Mortar"].default_value = srgb(mortar)
    br.inputs["Scale"].default_value = scale
    br.inputs["Mortar Size"].default_value = mortar_size
    br.inputs["Brick Width"].default_value = brick_w
    br.inputs["Row Height"].default_value = row_h
    br.inputs["Bias"].default_value = 0.0
    nt.links.new(comb.outputs[0], br.inputs["Vector"])
    nt.links.new(br.outputs["Color"], b.inputs["Base Color"])
    m.diffuse_color = srgb(col_a)
    return m


M_COBBLE = pattern_mat("Cobble", PAL["cobble_a"], PAL["cobble_b"], PAL["mortar"], 0.45, 1.6, 0.8)
M_SQUARE = pattern_mat("SquarePaving", "#DCCBB2", "#CDB99D", PAL["mortar"], 0.22, 1.0, 1.0)
M_PAVER = pattern_mat("CourtPaver", PAL["paver"], PAL["paver_b"], "#B8946A", 0.25, 1.0, 1.0)
M_BRICK = pattern_mat("Brick", PAL["brick"], "#B3573A", "#E6CDB4", 0.9, 1.0, 0.45, vertical=True, mortar_size=0.03)

# ---------------------------------------------------------------- mesh primitives (shared data)
_MESH = {}


def _mesh_from(name, verts, faces):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    return me


def mesh_box():
    if "box" not in _MESH:
        v = [(x, y, z) for x in (-0.5, 0.5) for y in (-0.5, 0.5) for z in (-0.5, 0.5)]
        f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        _MESH["box"] = _mesh_from("U_Box", v, f)
    return _MESH["box"]


def mesh_cyl(n=12):
    k = f"cyl{n}"
    if k not in _MESH:
        v = []
        for z in (-0.5, 0.5):
            for i in range(n):
                a = 2 * math.pi * i / n + math.pi / n
                v.append((math.cos(a), math.sin(a), z))
        f = [tuple(range(n)), tuple(range(n, 2 * n))]
        for i in range(n):
            j = (i + 1) % n
            f.append((i, j, n + j, n + i))
        _MESH[k] = _mesh_from(f"U_Cyl{n}", v, f)
    return _MESH[k]


def mesh_cone(n=8, top=0.0):
    k = f"cone{n}_{top}"
    if k not in _MESH:
        v = []
        for i in range(n):
            a = 2 * math.pi * i / n + math.pi / n
            v.append((math.cos(a), math.sin(a), 0.0))
        if top <= 0:
            v.append((0, 0, 1.0))
            f = [tuple(range(n))] + [(i, (i + 1) % n, n) for i in range(n)]
        else:
            for i in range(n):
                a = 2 * math.pi * i / n + math.pi / n
                v.append((top * math.cos(a), top * math.sin(a), 1.0))
            f = [tuple(range(n)), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        _MESH[k] = _mesh_from(f"U_Cone{n}_{top}", v, f)
    return _MESH[k]


def mesh_roof():
    """Unit gable prism: base 1x1 at z=0, ridge along local Y at z=1."""
    if "roof" not in _MESH:
        v = [(-0.5, -0.5, 0), (0.5, -0.5, 0), (0, -0.5, 1), (-0.5, 0.5, 0), (0.5, 0.5, 0), (0, 0.5, 1)]
        f = [(0, 1, 2), (3, 5, 4), (0, 2, 5, 3), (1, 4, 5, 2), (0, 3, 4, 1)]
        _MESH["roof"] = _mesh_from("U_Roof", v, f)
    return _MESH["roof"]


def mesh_ico(sub=1):
    k = f"ico{sub}"
    if k not in _MESH:
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
        me = bpy.data.meshes.new(f"U_Ico{sub}")
        bm.to_mesh(me)
        bm.free()
        _MESH[k] = me
    return _MESH[k]


def mesh_uv(seg=24, rings=12):
    k = f"uv{seg}"
    if k not in _MESH:
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
        me = bpy.data.meshes.new(f"U_UV{seg}")
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = True
        _MESH[k] = me
    return _MESH[k]


def mesh_flag():
    if "flag" not in _MESH:
        _MESH["flag"] = _mesh_from("U_Flag", [(-0.5, 0, 0), (0.5, 0, 0), (0, 0, -1)], [(0, 1, 2)])
    return _MESH["flag"]


def mesh_octa():
    if "octa" not in _MESH:
        v = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1.4), (0, 0, -1.4)]
        f = [(0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4), (2, 0, 5), (1, 2, 5), (3, 1, 5), (0, 3, 5)]
        _MESH["octa"] = _mesh_from("U_Octa", v, f)
    return _MESH["octa"]


def obj(name, mesh, m, loc, scale=(1, 1, 1), rot=(0, 0, 0), col="Props", parent=None):
    o = bpy.data.objects.new(name, mesh)
    (COL[col] if isinstance(col, str) else col).objects.link(o)
    if m is not None:
        if len(mesh.materials) == 0:
            mesh.materials.append(None)
        o.material_slots[0].link = "OBJECT"
        o.material_slots[0].material = m
    o.location = loc
    o.scale = scale
    o.rotation_euler = rot
    if parent is not None:
        o.parent = parent
    return o


def box(name, center, size, m, rot_z=0.0, col="Props", parent=None, rot=None):
    return obj(name, mesh_box(), m, center, size, rot if rot else (0, 0, rot_z), col, parent)


def box_minmax(name, mn, mx, m, col="Props", parent=None):
    c = [(a + b) / 2 for a, b in zip(mn, mx)]
    s = [abs(b - a) for a, b in zip(mn, mx)]
    return box(name, c, s, m, col=col, parent=parent)


def cyl(name, base, r, h, m, n=12, col="Props", parent=None, rot=(0, 0, 0)):
    return obj(name, mesh_cyl(n), m, (base[0], base[1], base[2] + h / 2), (r, r, h), rot, col, parent)


def rod(name, p1, p2, r, m, n=6, col="Props", parent=None):
    p1, p2 = Vector(p1), Vector(p2)
    d = p2 - p1
    q = d.normalized().to_track_quat("Z", "Y")
    o = obj(name, mesh_cyl(n), m, (p1 + p2) / 2, (r, r, d.length), (0, 0, 0), col, parent)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = q
    return o


def empty(name, loc=(0, 0, 0), rot_z=0.0, col="Props", parent=None, scale=1.0):
    e = bpy.data.objects.new(name, None)
    (COL[col] if isinstance(col, str) else col).objects.link(e)
    e.location = loc
    e.rotation_euler = (0, 0, rot_z)
    e.scale = (scale, scale, scale)
    e.empty_display_size = 1
    if parent is not None:
        e.parent = parent
    return e


def text(name, body, loc, size, m, rot=(math.pi / 2, 0, 0), col="Props", extrude=0.08, parent=None):
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = body
    cu.size = size
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.extrude = extrude
    o = bpy.data.objects.new(name, cu)
    (COL[col] if isinstance(col, str) else col).objects.link(o)
    cu.materials.append(m)
    o.location = loc
    o.rotation_euler = rot
    if parent is not None:
        o.parent = parent
    return o


# ---------------------------------------------------------------- shared materials
M = {
    "grass": mat(PAL["grass"], 0.95),
    "grass_dark": mat(PAL["grass_dark"], 0.95),
    "lawn": mat(PAL["lawn"], 0.95),
    "sidewalk": mat(PAL["sidewalk"], 0.9),
    "stone": mat(PAL["stone"], 0.9),
    "stone_dark": mat(PAL["stone_dark"], 0.9),
    "brick_dark": mat(PAL["brick_dark"], 0.9),
    "wood": mat(PAL["wood"], 0.8),
    "wood_dark": mat(PAL["wood_dark"], 0.8),
    "iron": mat(PAL["iron"], 0.6, metal=0.3),
    "gold": mat(PAL["gold"], 0.3, metal=0.8),
    "gold_glow": mat(PAL["gold"], 0.3, emit=1.5),
    "kiln": mat(PAL["kiln"], 0.5, emit=6.0),
    "kiln_soft": mat("#FFB347", 0.5, emit=4.0),
    "lamp": mat(PAL["lamp"], 0.5, emit=6.0),
    "window": mat(PAL["window"], 0.25),
    "frame": mat(PAL["frame"], 0.8),
    "hedge": mat(PAL["hedge"], 0.95),
    "leaf": mat(PAL["leaf"], 0.95),
    "leaf_b": mat(PAL["leaf_b"], 0.95),
    "trunk": mat(PAL["trunk"], 0.9),
    "white": mat("#FFFFFF", 0.8),
    "cream": mat("#FFF4DE", 0.8),
    "ink": mat("#3A2A20", 0.8),
    "red": mat("#E8483F", 0.8),
    "slate": mat(PAL["slate"], 0.85),
    "pad_a": mat(PAL["pad_a"], 0.4, emit=1.8),
    "pad_b": mat(PAL["pad_b"], 0.4, emit=1.8),
    "pad_ring": mat("#FFFFFF", 0.4, emit=2.5),
    "skin": mat("#F2C9A0", 0.8),
    "skin2": mat("#C98E62", 0.8),
    "skin3": mat("#8D5A3B", 0.8),
}
G = {
    "pop": glass_mat(PAL["pop"], name="Glass_pop"),
    "jam": glass_mat(PAL["jam"], name="Glass_jam"),
    "prism": glass_mat(PAL["prism"], name="Glass_prism"),
    "clear": glass_mat("#E8FBFF", glow=0.1, name="Glass_clear"),
}

# ---------------------------------------------------------------- assets: stand + glassies
with bpy.data.libraries.load(STAND_BLEND, link=False) as (src, dst):
    dst.collections = [STAND_COLLECTION]
STAND = bpy.data.collections[STAND_COLLECTION]


def _bounds(objs):
    mn = Vector((1e9, 1e9, 1e9))
    mx = -mn
    for o in objs:
        if o.type != "MESH":
            continue
        mw = o.matrix_basis
        p = o.parent
        while p is not None:
            mw = p.matrix_basis @ mw
            p = p.parent
        for v in o.bound_box:
            w = mw @ Vector(v)
            mn = Vector(map(min, mn, w))
            mx = Vector(map(max, mx, w))
    return mn, mx


smn, smx = _bounds(STAND.all_objects)
print(f"[kiln_street] Clash Stand bounds min={tuple(round(x, 2) for x in smn)} max={tuple(round(x, 2) for x in smx)}")
print(f"[kiln_street] Clash Stand size = {smx.x - smn.x:.2f} x {smx.y - smn.y:.2f} x {smx.z:.2f} studs (floor top z=0)")
PEN_HALF = max(smx.x, smx.y)
for hn, ho in sorted((o.name, o) for o in STAND.all_objects if o.name.startswith("Hook")):
    hm, hx = _bounds([ho])
    print(f"[kiln_street] {hn} centre=({(hm.x + hx.x) / 2:.2f}, {(hm.y + hx.y) / 2:.2f}) bottom z={hm.z:.2f}")
    HOOK_X = abs((hm.x + hx.x) / 2)
    HOOK_Z = hm.z


def load_glassy(gid):
    path = os.path.join(GLASSY_DIR, gid, f"{gid}.blend")
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if not n.startswith("Shard")]
    c = bpy.data.collections.new(f"Glassy_{gid}")
    for o in dst.objects:
        if o is None or o.type != "MESH":
            continue
        c.objects.link(o)
        base = o.name.split(".")[0]
        if base.startswith("Bubble"):
            m = G["clear"]
        elif base == "Cap":
            m = mat("#E8483F", 0.35)
        elif base == "Lid":
            m = mat("#F5C542", 0.35, metal=0.6)
        else:
            m = G[gid]
        o.data.materials.clear()
        o.data.materials.append(m)
        for p in o.data.polygons:
            p.use_smooth = True
    return c


GLASSY = {g: load_glassy(g) for g in ("pop", "jam", "prism")}


def stand_instance(name, loc, rot_z, scale=1.0, col="Arenas"):
    e = empty(name, loc, rot_z, col, scale=scale)
    e.instance_type = "COLLECTION"
    e.instance_collection = STAND
    return e


def stand_spot(name, stand_empty, toward, col="Arenas"):
    """Soft warm spotlight on the hanging glassies (ART_BIBLE 4: arenas get a soft spotlight)."""
    s = stand_empty.scale.x
    target = Vector(stand_empty.location) + Vector((0, 0, (HOOK_Z - STRING) * s))
    src = target + Vector(toward).normalized() * 16 * s + Vector((0, 0, 14 * s))
    sp = bpy.data.lights.new(name, "SPOT")
    sp.energy = 2200 * s * s
    sp.color = (1.0, 0.93, 0.8)
    sp.spot_size = math.radians(38)
    sp.spot_blend = 0.6
    sp.shadow_soft_size = 1.5
    so = bpy.data.objects.new(name, sp)
    COL[col].objects.link(so)
    so.location = src
    so.rotation_mode = "QUATERNION"
    so.rotation_quaternion = (target - src).to_track_quat("-Z", "Y")
    return so


def hang_glassy(name, stand_empty, hook_sign, gid, swing_deg, col="Arenas"):
    """Hang glassy `gid` from HookA (hook_sign=-1) or HookB (+1); swing_deg = outward pull-back."""
    sm = Matrix.LocRotScale(stand_empty.location, stand_empty.rotation_euler.to_quaternion(), stand_empty.scale)
    s = stand_empty.scale.x
    hook_world = sm @ Vector((hook_sign * HOOK_X, 0, HOOK_Z))
    piv = empty(f"{name}_Pivot", hook_world, 0.0, col)
    piv.scale = (s, s, s)
    # swing about the stand's local Y axis (crossbar runs along local X); A pulls toward -x, B toward +x
    piv.rotation_euler = (0, math.radians(swing_deg) * (-hook_sign), stand_empty.rotation_euler.z)
    rod(f"{name}_String", (0, 0, 0.05), (0, 0, -STRING + 0.05), 0.045, M["frame"], 6, col, piv)
    g = empty(f"{name}_Glassy", (0, 0, -STRING), 0, col, piv)
    g.instance_type = "COLLECTION"
    g.instance_collection = GLASSY[gid]
    return piv


# ---------------------------------------------------------------- props
def lamp_post(name, x, y, col="Street", mast=False):
    cyl(f"{name}_Base", (x, y, 0), 0.55, 0.8, M["iron"], 8, col)
    cyl(f"{name}_Pole", (x, y, 0.8), 0.22, 8.2, M["iron"], 8, col)
    box(f"{name}_Lantern", (x, y, 9.7), (1.1, 1.1, 1.4), M["lamp"], col=col)
    obj(f"{name}_Hat", mesh_cone(4), M["iron"], (x, y, 10.35), (1.0, 1.0, 0.9), (0, 0, math.pi / 4), col)
    if mast:
        cyl(f"{name}_Mast", (x, y, 11.0), 0.12, 3.6, M["iron"], 6, col)
        obj(f"{name}_MastKnob", mesh_ico(1), M["gold"], (x, y, 14.7), (0.3,) * 3, (0, 0, 0), col)


def flower_box(name, center, width, col="Street", parent=None):
    """Window flower box in a facade's local frame (wall faces local -y)."""
    box(f"{name}_Box", center, (width, 0.6, 0.55), M["wood"], col=col, parent=parent)
    n = max(2, int(width / 0.7))
    for i in range(n):
        px = center[0] + ((i + 0.5) / n - 0.5) * width
        c = PAL["flowers"][(i + len(name)) % len(PAL["flowers"])]
        obj(f"{name}_F{i}", mesh_ico(0), mat(c, 0.8), (px, center[1], center[2] + 0.45), (0.34, 0.34, 0.34), (0, 0, i), col, parent)
        obj(f"{name}_L{i}", mesh_ico(0), M["leaf"], (px + 0.15, center[1] + 0.1, center[2] + 0.3), (0.26, 0.26, 0.22), (0, 0, i), col, parent)


def cottage(name, front_center, facing_rot, width, depth, floors, wall, roof, variant=0, col="Street", sign=None, kiln=False, ground=True):
    """Facade at local y=0 facing local -y; body extends to +y. width along local x."""
    root = empty(name, front_center, facing_rot, col)
    h = 3.0 + floors * 5.0
    wm = mat(wall, 0.9)
    rm = mat(roof, 0.85)
    box(f"{name}_Plinth", (0, depth / 2, 0.5), (width + 0.4, depth + 0.4, 1.0), M["stone_dark"], col=col, parent=root)
    box(f"{name}_Walls", (0, depth / 2, h / 2 + 0.5), (width, depth, h - 1.0), wm, col=col, parent=root)
    for sx in (-1, 1):  # timber trims
        box(f"{name}_Post{sx}", (sx * (width / 2 - 0.25), -0.12, h / 2), (0.5, 0.3, h), M["wood_dark"], col=col, parent=root)
    box(f"{name}_Beam", (0, -0.12, 5.6), (width, 0.3, 0.45), M["wood_dark"], col=col, parent=root)
    over = 0.9
    if variant % 2 == 0:  # ridge along the street, eaves over the facade
        box(f"{name}_Eave", (0, depth / 2, h + 0.15), (width + 2 * over, depth + 2 * over, 0.3), rm, col=col, parent=root)
        obj(f"{name}_Roof", mesh_roof(), rm, (0, depth / 2, h + 0.3), (depth + 2 * over, width + 2 * over, 4.5 + width * 0.08), (0, 0, math.pi / 2), col, root)
    else:  # gable facing the street
        obj(f"{name}_Roof", mesh_roof(), rm, (0, depth / 2, h), (width + 2 * over, depth + 2 * over, 3.5 + width * 0.3), (0, 0, 0), col, root)
        obj(f"{name}_Gable", mesh_roof(), wm, (0, 0.6, h), (width - 0.6, 1.0, 2.8 + width * 0.3), (0, 0, 0), col, root)
        box(f"{name}_GWin", (0, -0.05, h + 1.2), (1.4, 0.3, 1.4), M["window"], col=col, parent=root)
    cx = width * 0.25 * (1 if variant % 3 else -1)
    box(f"{name}_Chimney", (cx, depth * 0.7, h + 3.0), (1.4, 1.4, 5.0), M["brick_dark"], col=col, parent=root)
    dx = -width * 0.25 if width > 9 else 0
    if ground:
        box(f"{name}_DoorFrame", (dx, -0.15, 3.6), (3.0, 0.3, 6.4), M["frame"], col=col, parent=root)
        box(f"{name}_Door", (dx, -0.25, 3.4), (2.3, 0.3, 5.8), mat(PAL["roofs"][(variant + 2) % len(PAL["roofs"])], 0.7), col=col, parent=root)
        obj(f"{name}_Step", mesh_box(), M["stone"], (dx, -0.8, 0.25), (3.6, 1.4, 0.5), (0, 0, 0), col, root)
    wins = []
    if width > 9 and ground:
        wins.append((width * 0.2, 3.8))
    for f in range(1, floors):
        for wx in ((-width * 0.25, width * 0.22) if width > 8 else (0,)):
            wins.append((wx, 3.4 + f * 5.0))
    for i, (wx, wz) in enumerate(wins):
        glow = kiln and wz < 6
        box(f"{name}_WinF{i}", (wx, -0.12, wz), (2.6, 0.3, 2.8), M["frame"], col=col, parent=root)
        box(f"{name}_Win{i}", (wx, -0.22, wz), (2.0, 0.3, 2.2), M["kiln_soft"] if glow else M["window"], col=col, parent=root)
        box(f"{name}_WinX{i}", (wx, -0.3, wz), (0.18, 0.2, 2.2), M["frame"], col=col, parent=root)
        if wz > 6 or i % 2 == 0:
            flower_box(f"{name}_FB{i}", (wx, -0.6, wz - 1.75), 2.6, col, root)
    if sign:
        sxp = dx + (2.6 if dx <= 0 else -2.6)
        box(f"{name}_SignBoard", (sxp, -0.9, 6.9), (3.4, 0.25, 1.4), M["wood"], col=col, parent=root)
        text(f"{name}_SignText", sign, (sxp, -1.05, 6.9), 0.75, M["cream"], (math.pi / 2, 0, 0), col, 0.02, root)
    return root


def awning(name, center, width, depth, colors, rot_z=0.0, col="Props", z=6.4):
    root = empty(name, center, rot_z, col)
    n = max(3, int(width / 1.4))
    for i in range(n):
        x = -width / 2 + (i + 0.5) * width / n
        cm = mat(colors[i % len(colors)], 0.8)
        box(f"{name}_S{i}", (x, -depth / 2, z), (width / n, depth, 0.25), cm, col=col, parent=root, rot=(math.radians(-18), 0, 0))
        obj(f"{name}_V{i}", mesh_flag(), cm, (x, -depth - 0.05, z - depth * math.tan(math.radians(18)) + 0.1), (width / n, 1, 0.7), (0, 0, 0), col, root)
    return root


def market_stall(name, loc, rot_z, colors, goods, col="Props"):
    root = empty(name, loc, rot_z, col)
    box(f"{name}_Table", (0, 0, 1.6), (6.0, 2.6, 0.4), M["wood"], col=col, parent=root)
    box(f"{name}_Front", (0, -1.1, 0.8), (6.0, 0.3, 1.6), M["wood_dark"], col=col, parent=root)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(f"{name}_Post{sx}{sy}", (sx * 2.85, sy * 1.15, 2.6), (0.3, 0.3, 5.2), M["wood_dark"], col=col, parent=root)
    for i in range(5):
        box(f"{name}_Roof{i}", (-2.4 + i * 1.2, 0, 5.4), (1.2, 3.4, 0.3), mat(colors[i % 2], 0.8), col=col, parent=root, rot=(math.radians(10), 0, 0))
        obj(f"{name}_V{i}", mesh_flag(), mat(colors[i % 2], 0.8), (-2.4 + i * 1.2, -1.75, 5.15), (1.2, 1, 0.6), (0, 0, 0), col, root)
    for i in range(7):
        gx = -2.5 + i * 0.85
        c = goods[i % len(goods)]
        gm = G["clear"] if c == "glass" else mat(c, 0.6)
        if i % 2:
            cyl(f"{name}_G{i}", (gx, 0.1 * (i % 3), 1.8), 0.28, 1.0, gm, 10, col, root)
        else:
            obj(f"{name}_G{i}", mesh_uv(12, 6), gm, (gx, 0.2, 2.2), (0.38, 0.38, 0.38), (0, 0, 0), col, root)
    return root


def bunting(name, p1, p2, sag=1.6, col="Street"):
    p1, p2 = Vector(p1), Vector(p2)
    n_seg = 10
    pts = []
    for i in range(n_seg + 1):
        t = i / n_seg
        p = p1.lerp(p2, t)
        p.z -= sag * 4 * t * (1 - t)
        pts.append(p)
    for i in range(n_seg):
        rod(f"{name}_C{i}", pts[i], pts[i + 1], 0.04, M["white"], 4, col)
    d = p2 - p1
    ang = math.atan2(d.y, d.x)
    nf = int(d.length / 1.3)
    for i in range(1, nf):
        t = i / nf
        p = p1.lerp(p2, t)
        p.z -= sag * 4 * t * (1 - t)
        c = PAL["bunting"][(i + len(name)) % len(PAL["bunting"])]
        obj(f"{name}_F{i}", mesh_flag(), mat(c, 0.8), p, (0.95, 1, 1.1), (0, 0, ang), col)


def tree(name, x, y, s=1.0, col="Nature"):
    cyl(f"{name}_Trunk", (x, y, 0), 0.6 * s, 4 * s, M["trunk"], 6, col)
    m = M["leaf"] if (int(x * 7 + y * 3) % 2) else M["leaf_b"]
    obj(f"{name}_Leaf", mesh_ico(1), m, (x, y, 6.5 * s), (3.4 * s, 3.4 * s, 3.8 * s), (0.3, 0.2, x), col)
    obj(f"{name}_Leaf2", mesh_ico(1), m, (x + 0.8 * s, y - 0.5 * s, 8.8 * s), (2.3 * s, 2.3 * s, 2.4 * s), (0.1, 0.5, y), col)


def bench(name, loc, rot_z, col="Props"):
    root = empty(name, loc, rot_z, col)
    box(f"{name}_Seat", (0, 0, 1.4), (6.0, 1.4, 0.3), M["wood"], col=col, parent=root)
    box(f"{name}_Back", (0, 0.6, 2.4), (6.0, 0.25, 1.2), M["wood"], col=col, parent=root)
    for sx in (-2.6, 2.6):
        box(f"{name}_Leg{sx}", (sx, 0.1, 0.7), (0.35, 1.4, 1.4), M["iron"], col=col, parent=root)
    return root


SHIRTS = ["#FF5E5E", "#4FC3F7", "#7ED957", "#FFD23F", "#B388FF", "#FF8FD1", "#FFFFFF", "#FF9A3C"]
PANTS = ["#2F4B7C", "#3A3A48", "#5A3E2B", "#2E6B4F", "#6B4AA0"]


def person(name, x, y, rot_z, seed, col="People", z=0.0, scale=1.0):
    """Blocky ~5-stud kid avatar for scale."""
    r = random.Random(seed)
    root = empty(name, (x, y, z), rot_z, col, scale=scale)
    shirt = mat(r.choice(SHIRTS), 0.8)
    pants = mat(r.choice(PANTS), 0.8)
    skin = r.choice([M["skin"], M["skin2"], M["skin3"]])
    for sx in (-0.5, 0.5):
        box(f"{name}_Leg{sx}", (sx, 0, 1.0), (0.95, 0.95, 2.0), pants, col=col, parent=root)
        box(f"{name}_Arm{sx}", (sx * 3, 0, 3.0), (0.95, 0.95, 2.0), skin if r.random() < 0.4 else shirt, col=col, parent=root)
    box(f"{name}_Torso", (0, 0, 3.0), (2.0, 1.0, 2.0), shirt, col=col, parent=root)
    box(f"{name}_Head", (0, 0, 4.6), (1.15, 1.15, 1.15), skin, col=col, parent=root)
    if r.random() < 0.6:
        box(f"{name}_Hair", (0, 0.1, 5.25), (1.25, 1.25, 0.4), mat(r.choice(["#3A2A20", "#F5C542", "#8E4430", "#222222", "#FF8FD1"]), 0.8), col=col, parent=root)
    return root


def gaps(spans, start, end):
    out = []
    cur = start
    for a, b in sorted(spans):
        if a - cur > 6:
            out.append((cur, a))
        cur = max(cur, b)
    if end - cur > 8:
        out.append((cur, end))
    return out


# ---------------------------------------------------------------- ground
box_minmax("Grass", (-900, -900, -1.0), (900, 1100, 0.0), M["grass"], col="Ground")
box_minmax("Street", (-STREET_HALF, 16, 0.0), (STREET_HALF, 186, 0.1), M_COBBLE, col="Ground")
for s in (-1, 1):
    box_minmax(f"Sidewalk{s}", (min(s * STREET_HALF, s * FRONT_LINE), 16, 0.0), (max(s * STREET_HALF, s * FRONT_LINE), 186, 0.16), M["sidewalk"], col="Ground")
    box_minmax(f"Curb{s}", (s * STREET_HALF - 0.25, 16, 0.0), (s * STREET_HALF + 0.25, 186, 0.22), M["stone_dark"], col="Ground")
box_minmax("SpawnSquare", (-40, -44, 0.0), (40, 18, 0.12), M_SQUARE, col="Ground")
cyl("FeaturedPlaza", (FEATURED.x, FEATURED.y, 0.0), 42, 0.12, M_COBBLE, 32, "Ground")
box_minmax("FurnaceYard", (-20, FEATURED.y, 0.0), (20, CHIMNEY_Y - 2, 0.12), M_COBBLE, col="Ground")

# ---------------------------------------------------------------- spawn square (lobby)
cyl("SpawnRing0", (SPAWN.x, SPAWN.y, 0.12), 7.0, 0.1, M["stone"], 24, "Lobby")
cyl("SpawnRing1", (SPAWN.x, SPAWN.y, 0.14), 5.6, 0.1, mat("#4FC3F7", 0.5, emit=0.6), 24, "Lobby")
cyl("SpawnRing2", (SPAWN.x, SPAWN.y, 0.16), 4.2, 0.1, M["cream"], 24, "Lobby")
cyl("SpawnRing3", (SPAWN.x, SPAWN.y, 0.18), 2.4, 0.1, mat("#FFD23F", 0.5, emit=0.6), 8, "Lobby")
for i in range(8):
    a = i * math.pi / 4
    obj(f"SpawnTile{i}", mesh_flag(), mat(PAL["bunting"][i % 6], 0.6), (SPAWN.x + 3.3 * math.cos(a), SPAWN.y + 3.3 * math.sin(a), 0.27), (1.4, 1, 1.4), (math.pi / 2, 0, a + math.pi / 2), "Lobby")

# Kiln Shop (crates) on the west side, brick building with three glowing kiln arches facing +x
box_minmax("KilnShop_Plinth", (-38.4, -30.4, 0), (-23.6, 0.4, 1.0), M["stone_dark"], col="Lobby")
box_minmax("KilnShop_Walls", (-38, -30, 0), (-24, 0, 12.5), M_BRICK, col="Lobby")
box_minmax("KilnShop_Eave", (-39, -31, 12.3), (-23, 1, 12.8), M["slate"], col="Lobby")
obj("KilnShop_Roof", mesh_roof(), M["slate"], (-31, -15, 12.8), (16.0, 32.0, 6.5), (0, 0, 0), "Lobby")
for yy in (-30, 0):
    box(f"KilnShop_Corner{yy}", (-24.2, yy, 6.5), (1.0, 1.0, 13.0), M["stone"], col="Lobby")
for i, yy in enumerate((-24, -15, -6)):
    box(f"KilnShop_Arch{i}", (-23.35, yy, 3.6), (0.3, 5.4, 6.0), M["kiln"], col="Lobby")
    cyl(f"KilnShop_ArchTop{i}", (-23.35, yy, 6.6), 2.7, 0.3, M["kiln"], 12, "Lobby", rot=(0, math.pi / 2, 0)).location = (-23.35, yy, 6.6)
    box(f"KilnShop_ArchRim{i}", (-23.25, yy, 0.6), (0.5, 6.6, 1.2), M["stone"], col="Lobby")
box("KilnShop_SignBoard", (-23.1, -15, 10.8), (0.4, 17, 2.6), M["wood_dark"], col="Lobby")
text("KilnShop_Sign", "GLASS CRATES", (-22.85, -15, 10.8), 1.9, M["gold_glow"], (math.pi / 2, 0, math.pi / 2), "Lobby", 0.1)
box("KilnShop_Stack", (-33, -15, 17), (5, 5, 18), M_BRICK, col="Lobby")
box("KilnShop_StackTop", (-33, -15, 26.4), (6, 6, 1.2), M["stone_dark"], col="Lobby")
for i in range(3):
    obj(f"KilnShop_Smoke{i}", mesh_ico(1), mat("#F4EEE6", 0.95), (-33 + i * 1.5, -15 + i * 1.2, 29 + i * 3.2), (1.6 + i * 0.6,) * 3, (i, i, i), "Lobby")
for i, yy in enumerate((-27.5, -20, -10, -2.5)):
    flower_box(f"KilnShop_FB{i}", (0, -0.4, 0.3), 2.8, "Lobby", empty(f"KilnShop_FBroot{i}", (-24, yy, 0), math.radians(90), "Lobby"))

# Gacha / crate machines in front of the kiln arches (facing +x)
CRATE_TIERS = [("BASIC", "#4FC3F7"), ("RARE", "#B388FF"), ("EPIC", "#FFC93C")]
for i, ((label, colr), yy) in enumerate(zip(CRATE_TIERS, (-24, -15, -6))):
    x0 = -18.5
    cm = mat(colr, 0.5)
    box(f"Crate{i}_Base", (x0, yy, 2.0), (4.0, 4.0, 4.0), cm, col="Lobby")
    box(f"Crate{i}_Panel", (x0 + 2.05, yy, 2.4), (0.15, 2.6, 2.2), M["cream"], col="Lobby")
    cyl(f"Crate{i}_Knob", (x0 + 2.1, yy, 1.8), 0.55, 0.5, M["gold"], 12, "Lobby", rot=(0, math.pi / 2, 0)).location = (x0 + 2.35, yy, 1.8)
    box(f"Crate{i}_Chute", (x0 + 2.05, yy, 0.8), (0.3, 1.6, 1.0), M["ink"], col="Lobby")
    obj(f"Crate{i}_Dome", mesh_uv(24, 12), G["clear"], (x0, yy, 6.2), (2.3, 2.3, 2.3), (0, 0, 0), "Lobby")
    for b in range(9):
        r = random.Random(i * 31 + b)
        c = [PAL["pop"], PAL["jam"], PAL["prism"], "#FFD23F", "#7ED957"][b % 5]
        obj(f"Crate{i}_Ball{b}", mesh_uv(12, 6), mat(c, 0.35), (x0 + r.uniform(-1, 1), yy + r.uniform(-1, 1), 4.9 + r.uniform(0, 1.4)), (0.6, 0.6, 0.6), (0, 0, 0), "Lobby")
    cyl(f"Crate{i}_Cap", (x0, yy, 8.2), 1.4, 0.9, cm, 16, "Lobby")
    obj(f"Crate{i}_Gem", mesh_octa(), mat(colr, 0.3, emit=2.0), (x0, yy, 9.9), (0.7, 0.7, 0.7), (0, 0, 0.4), "Lobby")
    text(f"Crate{i}_Label", label, (x0 + 2.15, yy, 2.9), 0.65, M["ink"], (math.pi / 2, 0, math.pi / 2), "Lobby", 0.02)

# Gem shop (east, facade at x=24 facing -x)
cottage("GemShop", (24, -24, 0), math.radians(-90), 15, 13, 2, "#E4D3F5", "#8E5BA8", variant=1, col="Lobby")
awning("GemShop_Awning", (23.6, -24, 0), 15, 3.0, ["#B388FF", "#FFFFFF"], math.radians(-90), "Lobby", 6.9)
box("GemShop_SignBoard", (23.1, -24, 11.3), (0.4, 9, 2.4), M["wood_dark"], col="Lobby")
text("GemShop_Sign", "GEM SHOP", (22.85, -24, 11.3), 1.6, M["gold_glow"], (math.pi / 2, 0, -math.pi / 2), "Lobby", 0.1)
obj("GemShop_Gem", mesh_octa(), mat("#5CE1E6", 0.2, emit=2.5), (30, -24, 23.5), (2.0, 2.0, 2.0), (0, 0, 0.5), "Lobby")
for i in range(3):
    obj(f"GemShop_Display{i}", mesh_octa(), mat(["#5CE1E6", "#FF8FD1", "#FFD23F"][i], 0.2, emit=1.5), (21.5, -29.5 + i * 2.6, 2.6), (0.7, 0.7, 0.7), (0, 0, i), "Lobby")
    cyl(f"GemShop_Stand{i}", (21.5, -29.5 + i * 2.6, 0.1), 0.6, 1.4, M["stone"], 8, "Lobby")

# Index / collection gallery (east, facade at x=24 facing -x) with display shelves of glassies
cottage("Gallery", (24, -5, 0), math.radians(-90), 16, 13, 2, "#BDE8D2", "#2F9C95", variant=0, col="Lobby", ground=False)
box("Gallery_Window", (23.3, -5, 4.2), (0.3, 12.5, 6.4), M["frame"], col="Lobby")
box("Gallery_WindowBack", (23.15, -5, 4.2), (0.3, 11.8, 5.8), mat("#FFF8E8", 0.6, emit=0.8), col="Lobby")
for row in range(3):
    zz = 1.8 + row * 1.9
    box(f"Gallery_Shelf{row}", (22.8, -5, zz - 0.15), (0.9, 11.6, 0.2), M["wood"], col="Lobby")
    for k in range(9):
        gid = ["pop", "jam", "prism"][(k + row) % 3]
        yy = -10.2 + k * 1.3
        if gid == "prism":
            obj(f"Gallery_G{row}_{k}", mesh_octa(), G[gid], (22.8, yy, zz + 0.55), (0.42, 0.42, 0.42), (0, 0, 0.3), "Lobby")
        elif gid == "jam":
            cyl(f"Gallery_G{row}_{k}", (22.8, yy, zz), 0.45, 0.9, G[gid], 12, "Lobby")
        else:
            cyl(f"Gallery_G{row}_{k}", (22.8, yy, zz), 0.32, 1.25, G[gid], 12, "Lobby")
box("Gallery_SignBoard", (23.1, -5, 11.3), (0.4, 11, 2.4), M["wood_dark"], col="Lobby")
text("Gallery_Sign", "GLASS INDEX", (22.85, -5, 11.3), 1.5, M["gold_glow"], (math.pi / 2, 0, -math.pi / 2), "Lobby", 0.1)

# Back row behind spawn (facing +y)
for i, (x, w) in enumerate(((-30, 14), (-15, 13), (0, 14), (15, 13), (30, 14))):
    cottage(f"BackRow{i}", (x, -44.5, 0), math.radians(180), w - 0.6, 10, 2 + (i % 2), PAL["walls"][(i + 3) % 7], PAL["roofs"][(i + 1) % 6], variant=i, col="Lobby")

# Daily reward chest + codes board near spawn
cx, cy = -9.0, -33.0
box("Daily_Base", (cx, cy, 1.0), (4.0, 2.6, 2.0), mat("#B5652E", 0.7), col="Lobby")
cyl("Daily_Lid", (cx, cy, 2.0), 1.3, 4.0, mat("#B5652E", 0.7), 10, "Lobby", rot=(0, math.pi / 2, 0)).location = (cx, cy, 2.0)
for sx in (-1.4, 0, 1.4):
    box(f"Daily_Band{sx}", (cx + sx, cy, 1.9), (0.35, 2.75, 4.0), M["gold"], col="Lobby")
box("Daily_Lock", (cx, cy + 1.4, 1.9), (0.8, 0.3, 0.9), M["gold_glow"], col="Lobby")
cyl("Daily_Plinth", (cx, cy, 0), 3.2, 0.12, mat("#FFD23F", 0.5, emit=0.8), 16, "Lobby")
for k in range(5):
    a = k * 2 * math.pi / 5
    obj(f"Daily_Spark{k}", mesh_octa(), M["gold_glow"], (cx + 2.6 * math.cos(a), cy + 2.6 * math.sin(a), 4.2 + 0.4 * (k % 2)), (0.25, 0.25, 0.25), (0, 0, a), "Lobby")
text("Daily_Text", "DAILY", (cx, cy, 6.6), 1.2, M["gold_glow"], (math.pi / 2, 0, math.pi), "Lobby", 0.08)

bx, by = 9.0, -34.5
for sx in (-2.6, 2.6):
    box(f"Codes_Post{sx}", (bx + sx, by, 3.2), (0.5, 0.5, 6.4), M["wood_dark"], col="Lobby")
box("Codes_Board", (bx, by, 4.3), (5.6, 0.4, 3.6), M["wood"], col="Lobby")
obj("Codes_Roof", mesh_roof(), M["red"], (bx, by, 6.4), (6.6, 1.4, 1.2), (0, 0, 0), "Lobby")
for k in range(4):
    box(f"Codes_Note{k}", (bx - 1.6 + k * 1.1, by + 0.25, 4.0 + 0.3 * (k % 2)), (0.9, 0.1, 1.1), M["cream"] if k % 2 else mat("#FFF1A8", 0.8), col="Lobby")
text("Codes_Text", "CODES", (bx, by + 0.3, 5.45), 0.75, M["ink"], (math.pi / 2, 0, math.pi), "Lobby", 0.02)

# Leaderboards at the street gate (west), facing the spawn (-y)
for i, (lx, title, accent) in enumerate(((-28.0, "TOP WINS", "#FFC93C"), (-19.0, "BEST STREAK", "#4FC3F7"))):
    for sx in (-3.4, 3.4):
        box(f"Board{i}_Post{sx}", (lx + sx, 12.0, 5.0), (0.7, 0.7, 10.0), M["wood_dark"], col="Lobby")
    box(f"Board{i}_Frame", (lx, 12.0, 6.4), (7.6, 0.6, 7.4), M["wood_dark"], col="Lobby")
    box(f"Board{i}_Face", (lx, 11.65, 6.2), (6.6, 0.2, 6.2), mat("#20304A", 0.6, emit=0.15), col="Lobby")
    box(f"Board{i}_Title", (lx, 11.5, 8.6), (6.6, 0.2, 1.3), mat(accent, 0.5, emit=1.2), col="Lobby")
    text(f"Board{i}_TitleText", title, (lx, 11.35, 8.6), 0.75, M["ink"], (math.pi / 2, 0, 0), "Lobby", 0.02)
    for r_ in range(5):
        box(f"Board{i}_Row{r_}", (lx - 0.3, 11.5, 7.2 - r_ * 1.0), (5.6 - r_ * 0.5, 0.15, 0.55), mat(["#FFD23F", "#E0E0E0", "#E6A15C", "#BFD7FF", "#BFD7FF"][r_], 0.5, emit=0.6), col="Lobby")
    obj(f"Board{i}_Roof", mesh_roof(), M["slate"], (lx, 12.0, 10.1), (8.6, 1.8, 1.4), (0, 0, 0), "Lobby")

# Champion statue with spotlights at the street gate (east)
sx_, sy_ = 21.0, 9.0
cyl("Champ_Plinth0", (sx_, sy_, 0), 4.6, 0.8, M["stone"], 8, "Lobby")
cyl("Champ_Plinth1", (sx_, sy_, 0.8), 3.6, 0.8, M["stone_dark"], 8, "Lobby")
cyl("Champ_Plinth2", (sx_, sy_, 1.6), 2.8, 2.6, M["stone"], 8, "Lobby")
champ = person("Champ_Statue", sx_, sy_, math.radians(225), 99, "Lobby", z=4.2, scale=1.6)
for o in list(champ.children):
    o.material_slots[0].material = M["gold"]
box("Champ_ArmUp", (sx_ + 1.6, sy_ + 1.6, 12.6), (1.3, 1.3, 3.4), M["gold"], col="Lobby")
obj("Champ_Trophy", mesh_octa(), mat(PAL["prism"], 0.1, emit=2.0), (sx_ + 1.6, sy_ + 1.6, 15.4), (1.0, 1.0, 1.0), (0, 0, 0.4), "Lobby")
for k, (dx, dy) in enumerate(((-5, -5), (5, -5))):
    cyl(f"Champ_SpotPole{k}", (sx_ + dx, sy_ + dy, 0), 0.25, 6, M["iron"], 8, "Lobby")
    box(f"Champ_SpotHead{k}", (sx_ + dx, sy_ + dy, 6.2), (1.0, 1.0, 1.0), M["lamp"], col="Lobby")
    sp = bpy.data.lights.new(f"Champ_Spot{k}", "SPOT")
    sp.energy = 2500
    sp.color = (1.0, 0.9, 0.7)
    sp.spot_size = math.radians(40)
    so = bpy.data.objects.new(f"Champ_Spot{k}", sp)
    COL["Lobby"].objects.link(so)
    so.location = (sx_ + dx, sy_ + dy, 6.6)
    so.rotation_mode = "QUATERNION"
    so.rotation_quaternion = (Vector((sx_, sy_, 8)) - Vector(so.location)).to_track_quat("-Z", "Y")
text("Champ_Text", "CHAMPION", (sx_ - 3.5, sy_ - 3.5, 2.0), 0.7, M["ink"], (math.pi / 2, 0, math.radians(-45)), "Lobby", 0.02)

# Street gate arch (tall enough that the chimney + giant bottle read through it from spawn)
for s in (-1, 1):
    box(f"Gate_Pillar{s}", (s * 11.8, 17.5, 10.0), (2.6, 2.6, 20.0), M_BRICK, col="Lobby")
    box(f"Gate_Cap{s}", (s * 11.8, 17.5, 20.4), (3.2, 3.2, 0.8), M["stone"], col="Lobby")
    obj(f"Gate_Lamp{s}", mesh_ico(1), M["lamp"], (s * 11.8, 17.5, 21.6), (0.9, 0.9, 0.9), (0, 0, 0), "Lobby")
box("Gate_Beam", (0, 17.5, 18.4), (21.0, 1.2, 2.6), M["wood_dark"], col="Lobby")
text("Gate_Text", "KILN STREET", (0, 16.8, 18.4), 1.8, M["gold_glow"], (math.pi / 2, 0, 0), "Lobby", 0.1)
for k in range(5):
    rod(f"Gate_BString{k}", (-6 + k * 3, 17.5, 17.1), (-6 + k * 3, 17.5, 15.6), 0.04, M["frame"], 4, "Lobby")
    obj(f"Gate_Bottle{k}", mesh_cyl(10), G[["pop", "jam", "prism", "jam", "pop"][k]], (-6 + k * 3, 17.5, 15.0), (0.35, 0.35, 0.6), (0, 0, 0), "Lobby")

# Square dressing
market_stall("Stall_SqW", (-10, 4, 0), math.radians(90), ["#FF5E5E", "#FFF1D6"], ["glass", "#FFD23F", "glass"], "Lobby")
market_stall("Stall_SqE", (11, -9, 0), math.radians(-90), ["#4FC3F7", "#FFF1D6"], ["glass", "#FF8FB1", "glass"], "Lobby")
for k, (tx, ty) in enumerate(((-36, 10), (36, 10), (-36, -38), (36, -38))):
    cyl(f"Planter{k}", (tx, ty, 0), 2.6, 1.2, M["stone"], 8, "Lobby")
    obj(f"PlanterTree{k}", mesh_ico(1), M["leaf"], (tx, ty, 4.2), (2.8, 2.8, 3.2), (k, 0, k), "Lobby")
    cyl(f"PlanterTrunk{k}", (tx, ty, 1.2), 0.45, 1.6, M["trunk"], 6, "Lobby")
for k, (lx, ly) in enumerate(((-16, -38), (16, -38), (-16, -10), (16, 4), (-30, 8))):
    lamp_post(f"SqLamp{k}", lx, ly, "Lobby")
bunting("SqBunt0", (-23.5, -30, 11.5), (23.5, -30, 11.5), 2.2, "Lobby")
bunting("SqBunt1", (-23.5, -2, 11.5), (23.5, -2, 11.5), 2.2, "Lobby")

# ---------------------------------------------------------------- street + arena courtyards
court_spans = {-1: [], 1: []}
for idx, side, y in ARENAS:
    court_spans[side].append((y - COURT_HALF_Y, y + COURT_HALF_Y))

PAIRS = [("pop", "jam"), ("prism", "pop"), ("jam", "prism"), ("pop", "prism"), ("jam", "pop"), ("prism", "jam")]
SWINGS = [(24, 2), (26, 3), (3, 3), (30, 0), (10, 12), (4, 22)]  # outward pull-back angles (deg)

for idx, side, y in ARENAS:
    cx = side * PEN_CX
    name = f"Arena{idx + 1}"
    x_in = side * STREET_HALF
    x_back = side * (PEN_CX + PEN_HALF + 4.5)
    x_apron = side * (STREET_HALF + APRON - 0.4)
    box_minmax(f"{name}_Paving", (min(x_in, x_apron), y - COURT_HALF_Y, 0.0), (max(x_in, x_apron), y + COURT_HALF_Y, GROUND_Z), M_PAVER, col="Arenas")
    box_minmax(f"{name}_Lawn", (min(x_apron, x_back), y - COURT_HALF_Y, 0.0), (max(x_apron, x_back), y + COURT_HALF_Y, GROUND_Z - 0.02), M["lawn"], col="Arenas")
    box_minmax(f"{name}_Kerb", (min(x_apron, x_apron + side * 0.6), y - COURT_HALF_Y, 0.0), (max(x_apron, x_apron + side * 0.6), y + COURT_HALF_Y, GROUND_Z + 0.08), M["stone"], col="Arenas")
    # stand: crossbar parallel to the street so the swing reads side-on from the street
    st = stand_instance(f"{name}_Stand", (cx, y, GROUND_Z), math.radians(90))
    ga, gb = PAIRS[idx]
    sa, sb = SWINGS[idx]
    hang_glassy(f"{name}_A", st, -1, ga, sa)
    hang_glassy(f"{name}_B", st, 1, gb, sb)
    stand_spot(f"{name}_Spot", st, (-side, 0, 0))
    # queue pads on the apron, one per side (A = cyan, B = orange)
    for k, (dy, pm) in enumerate(((-7.0, M["pad_a"]), (7.0, M["pad_b"]))):
        px = side * (STREET_HALF + 3.6)
        cyl(f"{name}_PadRim{k}", (px, y + dy, 0.0), 2.9, 0.35, M["stone"], 16, "Arenas")
        cyl(f"{name}_Pad{k}", (px, y + dy, 0.0), 2.5, 0.45, pm, 16, "Arenas")
        cyl(f"{name}_PadDot{k}", (px, y + dy, 0.0), 1.0, 0.5, M["pad_ring"], 12, "Arenas")
        ppy = y + dy + (3.3 if dy > 0 else -3.3)
        rod(f"{name}_PadPole{k}", (px, ppy, 0), (px, ppy, 6.0), 0.12, M["iron"], 6, "Arenas")
        box(f"{name}_PadFlag{k}", (px - side * 0.9, ppy, 5.3), (1.8, 0.12, 1.2), pm, col="Arenas")
        obj(f"{name}_PadKnob{k}", mesh_ico(1), M["gold"], (px, ppy, 6.1), (0.25,) * 3, (0, 0, 0), "Arenas")
    # arena number sign on a post (front corner, facing the street)
    sgx, sgy = side * (STREET_HALF + 1.0), y - COURT_HALF_Y + 2.0
    rod(f"{name}_SignPole", (sgx, sgy, 0), (sgx, sgy, 8.0), 0.18, M["wood_dark"], 6, "Arenas")
    box(f"{name}_SignBoard", (sgx, sgy, 8.8), (0.4, 2.4, 2.4), M["wood"], col="Arenas")
    text(f"{name}_SignNum", str(idx + 1), (sgx - side * 0.25, sgy, 8.8), 1.8, M["cream"], (math.pi / 2, 0, -side * math.pi / 2), "Arenas", 0.05)
    # spectator benches along the courtyard sides + hedges + back wall + flower beds
    for sy in (-1, 1):
        bench(f"{name}_Bench{sy}", (side * (PEN_CX - 2), y + sy * (COURT_HALF_Y - 1.6), GROUND_Z), math.radians(0 if sy > 0 else 180))
        box_minmax(f"{name}_Hedge{sy}", (min(side * (FRONT_LINE + 13), x_back), y + sy * COURT_HALF_Y - 0.6, 0), (max(side * (FRONT_LINE + 13), x_back), y + sy * COURT_HALF_Y + 0.6, 2.6), M["hedge"], col="Arenas")
    box_minmax(f"{name}_BackWall", (min(x_back, x_back + side * 1.0), y - COURT_HALF_Y - 0.6, 0), (max(x_back, x_back + side * 1.0), y + COURT_HALF_Y + 0.6, 3.4), M_BRICK, col="Arenas")
    for k, dy in enumerate((-COURT_HALF_Y + 3.5, COURT_HALF_Y - 3.5)):
        flower = PAL["flowers"][(idx + k) % len(PAL["flowers"])]
        box(f"{name}_Bed{k}", (x_back - side * 2.0, y + dy, 0.6), (2.6, 4.0, 1.2), M["wood"], col="Arenas")
        for f in range(4):
            obj(f"{name}_Bed{k}_F{f}", mesh_ico(0), mat(flower, 0.8), (x_back - side * 2.0 + (f % 2 - 0.5), y + dy - 1.4 + f * 0.9, 1.5), (0.55,) * 3, (f, 0, f), "Arenas")
    # glassblower workshop behind the courtyard (frames the arena from the street)
    cottage(f"{name}_Workshop", (side * (PEN_CX + PEN_HALF + 7.5), y, 0), math.radians(90 if side < 0 else -90), 26, 12, 2,
            ["#FFE6B8", "#FFC9A8", "#FFF1A8"][idx % 3], PAL["roofs"][(idx + 3) % 6], variant=idx + 1, col="Street", kiln=True)  # warm walls behind glass

# Cottages filling the gaps between courtyards along each side of the street
SIGNS = ["BEADS", "BOTTLES", "LAMPS", "MARBLES", "JARS", "VASES", "BAKERY", "TOYS"]
ck = 0
for side in (-1, 1):
    for a, b in gaps(court_spans[side], 19.5, 182.0):
        n = max(1, round((b - a) / 12.5))
        w = (b - a) / n
        for j in range(n):
            yc = a + (j + 0.5) * w
            cottage(f"Cottage{ck}", (side * FRONT_LINE, yc, 0), math.radians(90 if side < 0 else -90), w - 0.4, 11, 2 + (ck % 3 == 1),
                    PAL["walls"][ck % 7], PAL["roofs"][(ck * 2 + 1) % 6], variant=ck, sign=SIGNS[ck % len(SIGNS)] if ck % 2 == 0 else None)
            ck += 1

# Lamps stand only in front of cottages (never on an arena apron), one per cottage gap,
# which makes them alternate sides; bunting zigzags between their masts high above the street
# (>= 13 studs, so it never blocks the default third-person camera).
LAMPS = []
for side in (-1, 1):
    for a, b in gaps(court_spans[side], 19.5, 186.0):
        LAMPS.append(((a + b) / 2 if b - a < 20 else a + 9, side))
LAMPS.sort()
for yy, side in LAMPS:
    lamp_post(f"Lamp{side}_{int(yy)}", side * (STREET_HALF + 1.3), yy, mast=True)
for k in range(len(LAMPS) - 1):
    (y1, s1), (y2, s2) = LAMPS[k], LAMPS[k + 1]
    bunting(f"Bunt{k}", (s1 * (STREET_HALF + 1.3), y1, 14.4), (s2 * (STREET_HALF + 1.3), y2, 14.4), 1.6)
print("[kiln_street] lamp/bunting anchors:", [(round(y), s) for y, s in LAMPS])

# a few market stalls along the street
market_stall("Stall_St1", (6.8, 30, 0), math.radians(-90), ["#7ED957", "#FFF1D6"], ["glass", "#FF5E5E", "glass"])
market_stall("Stall_St2", (-6.8, 176, 0), math.radians(90), ["#FF8FD1", "#FFF1D6"], ["glass", "#FFD23F", "glass"])

# ---------------------------------------------------------------- featured arena + furnace chimney
fx, fy = FEATURED.x, FEATURED.y
cyl("Feat_Step", (fx, fy, 0), PLINTH_R + 2.0, PLINTH_H / 2, M["stone"], 24, "Featured")
cyl("Feat_Plinth", (fx, fy, 0), PLINTH_R, PLINTH_H, M["stone_dark"], 24, "Featured")
cyl("Feat_GoldRing", (fx, fy, PLINTH_H - 0.05), PLINTH_R - 0.1, 0.1, M["gold"], 24, "Featured")
cyl("Feat_Top", (fx, fy, PLINTH_H), PLINTH_R - 0.9, 0.1, mat("#E8C99A", 0.8), 24, "Featured")
fst = stand_instance("Feat_Stand", (fx, fy, PLINTH_H + 0.05), 0.0, FEATURED_SCALE, "Featured")
hang_glassy("Feat_A", fst, -1, "jam", 18, "Featured")
hang_glassy("Feat_B", fst, 1, "prism", 3, "Featured")
stand_spot("Feat_Spot", fst, (0, -1, 0), "Featured")
FEAT_PAD_Y = fy - FEATURED_SCALE * PEN_HALF - 3.4
for k, (dx, pm) in enumerate(((-8.0, M["pad_a"]), (8.0, M["pad_b"]))):
    cyl(f"Feat_PadRim{k}", (fx + dx, FEAT_PAD_Y, PLINTH_H - 0.2), 3.2, 0.5, M["gold"], 16, "Featured")
    cyl(f"Feat_Pad{k}", (fx + dx, FEAT_PAD_Y, PLINTH_H - 0.2), 2.8, 0.6, pm, 16, "Featured")
    cyl(f"Feat_PadDot{k}", (fx + dx, FEAT_PAD_Y, PLINTH_H - 0.2), 1.1, 0.65, M["pad_ring"], 12, "Featured")
for k in range(8):  # banner poles (front kept open toward the street)
    a = math.radians(22.5 + k * 45)
    if math.sin(a) < -0.5:
        continue
    bx_, by_ = fx + (PLINTH_R - 1.2) * math.cos(a), fy + (PLINTH_R - 1.2) * math.sin(a)
    cyl(f"Feat_Pole{k}", (bx_, by_, PLINTH_H), 0.3, 14, M["iron"], 8, "Featured")
    obj(f"Feat_PoleTop{k}", mesh_octa(), M["gold_glow"], (bx_, by_, PLINTH_H + 14.8), (0.6, 0.6, 0.6), (0, 0, 0), "Featured")
    vertical = abs(math.cos(a)) > 0.5
    box(f"Feat_Banner{k}", (bx_, by_, PLINTH_H + 10.5), (0.15 if vertical else 2.6, 2.6 if vertical else 0.15, 5.0), mat(["#E8483F", "#3F7FBF"][k % 2], 0.8), col="Featured")
for k in range(-5, 6):  # curved spectator steps around the sides/back
    a = math.radians(90 + k * 15)
    for row in range(2):
        rr = PLINTH_R + 5 + row * 2.4
        box(f"Feat_Seat{k}_{row}", (fx + rr * math.cos(a), fy + rr * math.sin(a), 0.6 + row * 0.9), (2.4, 6.2, 1.2 + row * 1.8), M["wood"] if row == 0 else M["wood_dark"], rot_z=a, col="Featured")
text("Feat_Title", "CHAMPION ARENA", (fx, fy - PLINTH_R - 2.6, 1.2), 1.4, M["gold_glow"], (math.radians(70), 0, 0), "Featured", 0.05)

cy_ = CHIMNEY_Y
box_minmax("Furnace_Base", (-15, cy_ - 8, 0), (15, cy_ + 8, 14), M_BRICK, col="Featured")
box_minmax("Furnace_Cornice", (-16, cy_ - 9, 13.5), (16, cy_ + 9, 15.0), M["stone"], col="Featured")
for k, dx in enumerate((-9, 0, 9)):
    box(f"Furnace_Mouth{k}", (dx, cy_ - 8.05, 4.0), (5.0, 0.4, 6.0), M["kiln"], col="Featured")
    cyl(f"Furnace_MouthTop{k}", (dx, cy_ - 8.05, 7.0), 2.5, 0.4, M["kiln"], 12, "Featured", rot=(math.pi / 2, 0, 0)).location = (dx, cy_ - 8.05, 7.0)
    box(f"Furnace_Sill{k}", (dx, cy_ - 8.6, 0.6), (6.4, 1.2, 1.2), M["stone"], col="Featured")
obj("Furnace_Stack", mesh_cone(8, 0.78), M_BRICK, (0, cy_, 15.0), (7.0, 7.0, 40.0), (0, 0, 0), "Featured")
for k, zz in enumerate((24, 36, 48)):
    r_ = 7.0 - (zz - 15) / 40 * (7.0 - 5.46)
    cyl(f"Furnace_Band{k}", (0, cy_, zz), r_ + 0.4, 1.2, M["stone"], 8, "Featured")
cyl("Furnace_Collar", (0, cy_, 54.5), 6.8, 2.0, M["stone"], 8, "Featured")
cyl("Furnace_Ring", (0, cy_, 56.4), 6.2, 0.8, M["gold"], 16, "Featured")
gb = empty("GiantBottle", (0, cy_, 56.8 + 2.46 * 6.0), 0.4, "Featured", scale=6.0)
gb.instance_type = "COLLECTION"
gb.instance_collection = GLASSY["pop"]
gl = bpy.data.lights.new("GiantBottle_Glow", "POINT")
gl.energy = 30000
gl.color = (0.6, 0.9, 1.0)
gl.shadow_soft_size = 3
glo = bpy.data.objects.new("GiantBottle_Glow", gl)
COL["Featured"].objects.link(glo)
glo.location = (0, cy_ - 10, 64)
for k, (wx, wy, rz) in enumerate(((-44, 196, 90), (44, 196, -90), (-38, 246, 90 + 40), (38, 246, -90 - 40))):
    cottage(f"PlazaShop{k}", (wx, wy, 0), math.radians(rz), 18, 12, 2, PAL["walls"][(k + 4) % 7], PAL["roofs"][(k + 2) % 6], variant=k, col="Featured", kiln=True)
for k, (lx, ly) in enumerate(((-14, 182), (14, 182), (-38, 214), (38, 214))):
    lamp_post(f"PlazaLamp{k}", lx, ly, "Featured")
bunting("PlazaBunt0", (-14, 182, 9.6), (-38, 214, 9.6), 2.0, "Featured")
bunting("PlazaBunt1", (14, 182, 9.6), (38, 214, 9.6), 2.0, "Featured")

# ---------------------------------------------------------------- nature around the edges
rt = random.Random(3)
for k in range(320):
    x = rt.uniform(-260, 260)
    y = rt.uniform(-200, 420)
    if abs(x) < 66 and -52 < y < 196:
        continue
    if math.hypot(x - fx, y - fy) < 62 or (abs(x) < 30 and y > 196):
        continue
    tree(f"Tree{k}", x, y, rt.uniform(0.9, 1.6))
for k, (hx, hy, hr) in enumerate(((-120, 300, 70), (60, 340, 90), (150, 220, 60), (-160, 120, 60), (170, 40, 50))):
    obj(f"Hill{k}", mesh_ico(2), M["grass_dark"], (hx, hy, -hr * 0.55), (hr, hr, hr * 0.8), (0, 0, k), "Nature")
for k, (x, y) in enumerate(((-74, 30), (-72, 80), (-76, 130), (-70, 170), (74, 50), (72, 100), (76, 150), (70, 180), (-50, -60), (0, -62), (50, -60))):
    tree(f"EdgeTree{k}", x, y, 1.5)

# ---------------------------------------------------------------- people (scale + life)
P = [
    (-13, -11, 200), (-14, -18, 60), (-13, -14, 100), (-13.5, -6, 80), (18, -24, -100), (17, -6, -80),
    (3, 6, 10), (-4, 26, 0), (4, 45, 160), (-3, 70, 20), (2, 96, -10), (-5, 120, 30), (4, 150, 0), (-2, 178, 0),
]
for k, (x, y, r) in enumerate(P):
    person(f"Kid{k}", x, y, math.radians(r), k)
for idx, side, y in ARENAS:  # queued players + watchers at every arena
    px = side * (STREET_HALF + 3.6)
    person(f"Q{idx}a", px, y - 7.0, math.radians(90 if side < 0 else -90), 100 + idx, z=0.45)
    if idx % 2 == 0 or idx == 1:
        person(f"Q{idx}b", px, y + 7.0, math.radians(90 if side < 0 else -90), 200 + idx, z=0.45)
    for w in range(2 + idx % 2):
        person(f"W{idx}_{w}", side * (STREET_HALF - 2.5 - w * 1.8), y - 3 + w * 3.3, math.radians(-90 if side < 0 else 90) + 0.3 * (w - 1), 300 + idx * 7 + w)
    person(f"WB{idx}", side * (PEN_CX - 2), y + COURT_HALF_Y - 1.6, math.radians(180), 400 + idx, z=1.5)
for k in range(10):
    a = math.radians(-60 - k * 6)
    sgn = 1 if k < 5 else -1
    person(f"FeatW{k}", fx + (PLINTH_R + 3.5) * math.cos(a) * sgn, fy + (PLINTH_R + 3.5) * math.sin(a), math.atan2(-math.sin(a), -math.cos(a) * sgn) + math.pi / 2, 500 + k)
person("FeatQa", fx - 8, FEAT_PAD_Y, 0, 600, z=PLINTH_H + 0.5)
person("FeatQb", fx + 8, FEAT_PAD_Y, 0, 601, z=PLINTH_H + 0.5)

# ---------------------------------------------------------------- world, sun, render settings
world = bpy.data.worlds.new("Sky")
scene.world = world
world.use_nodes = True
wn = world.node_tree
bg = wn.nodes["Background"]
tc = wn.nodes.new("ShaderNodeTexCoord")
sep = wn.nodes.new("ShaderNodeSeparateXYZ")
ramp = wn.nodes.new("ShaderNodeValToRGB")
wn.links.new(tc.outputs["Generated"], sep.inputs[0])
wn.links.new(sep.outputs[2], ramp.inputs[0])
ramp.color_ramp.elements[0].position = 0.0
ramp.color_ramp.elements[0].color = srgb("#FFE3B8")
ramp.color_ramp.elements[1].position = 0.45
ramp.color_ramp.elements[1].color = srgb("#6FB4E6")
ramp.color_ramp.elements.new(0.12).color = srgb("#BFE0F2")
wn.links.new(ramp.outputs["Color"], bg.inputs["Color"])
bg.inputs["Strength"].default_value = 1.0

sun = bpy.data.lights.new("Sun", "SUN")
sun.energy = 4.2
sun.color = srgb("#FFE2B5")[:3]
sun.angle = math.radians(3)
so = bpy.data.objects.new("Sun", sun)
ROOT.objects.link(so)
sun_dir = Vector((-0.55, -0.45, 0.62)).normalized()  # light comes FROM the south-west, ~38 deg up
so.rotation_mode = "QUATERNION"
so.rotation_quaternion = sun_dir.to_track_quat("Z", "Y")

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 8 if QUICK else 28
scene.cycles.use_adaptive_sampling = True
scene.cycles.max_bounces = 6
scene.cycles.transmission_bounces = 6
scene.cycles.glossy_bounces = 3
scene.cycles.diffuse_bounces = 2
try:
    scene.cycles.use_denoising = True
    scene.cycles.denoiser = "OPENIMAGEDENOISE"
except Exception as ex:  # noqa: BLE001
    print("[kiln_street] denoiser unavailable:", ex)
    scene.cycles.use_denoising = False
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.resolution_percentage = 50 if QUICK else 100
scene.render.image_settings.file_format = "PNG"
try:
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
except Exception:  # noqa: BLE001
    scene.view_settings.view_transform = "Standard"
scene.view_settings.exposure = 0.35


def camera(name, loc, target, lens=24.0):
    cd = bpy.data.cameras.new(name)
    cd.lens = lens
    cd.clip_end = 2000
    co = bpy.data.objects.new(name, cd)
    ROOT.objects.link(co)
    co.location = loc
    co.rotation_mode = "QUATERNION"
    co.rotation_quaternion = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y")
    return co


VIEWS = {
    "aerial": camera("Cam_Aerial", (128, -92, 200), (-4, 104, 0), 23),
    "spawn": camera("Cam_Spawn", (7.0, SPAWN.y - 8, 6.0), (-10.0, 60.0, 11.0), 18),
    "arena": camera("Cam_Arena", (-15.0, 61.0, 21.0), (24.0, 65.5, 4.5), 27),
}

os.makedirs(OUT_DIR, exist_ok=True)
pngs = []
for vname, cam in VIEWS.items():
    if ONLY and vname not in ONLY:
        continue
    scene.camera = cam
    out = os.path.join(OUT_DIR, f"{vname}.png")
    scene.render.filepath = out
    print(f"[kiln_street] rendering {vname} -> {out}")
    bpy.ops.render.render(write_still=True)
    pngs.append(out)

# Convert PNG -> JPG (quality 85) with system python + PIL, then delete the PNGs.
if pngs:
    conv = "import sys\nfrom PIL import Image\nfor p in sys.argv[1:]:\n    Image.open(p).convert('RGB').save(p[:-4] + '.jpg', quality=85)\n"
    try:
        subprocess.run(["/usr/bin/python3", "-c", conv, *pngs], check=True)
        for p in pngs:
            os.remove(p)
            print(f"[kiln_street] wrote {p[:-4]}.jpg")
    except Exception as ex:  # noqa: BLE001
        print("[kiln_street] JPG conversion failed, PNGs kept:", ex)

print("[kiln_street] done")
