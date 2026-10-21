"""Glass Clash marketing kit: builds thumbnail/icon scenes from the real game assets and renders passes.

Run headless (does not touch an open Blender session):
  /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/marketing/thumbnail_kit.py -- T1a T2a [--draft]

Per scene id it writes assets/marketing/thumbnails/kit/<T#>/<id>_{beauty,subject,background,mask}.png and
<id>_scene.blend. --draft renders a quick Eevee beauty only (<id>_draft.png). No logo or text in any render.
"""

import bpy
import math
import os
import random
import sys
from mathutils import Matrix, Vector, Euler

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
A = os.path.join(REPO, "assets", "blender")
KIT = os.path.join(REPO, "assets", "marketing", "thumbnails", "kit")
GLASSY_SCALE = 1.75  # Balance.GlassyScale
STRING = 7.0 * GLASSY_SCALE / 1.75  # Balance.Motion.StringLength (studs)
HOOK_GAP = 6.0  # Balance.Motion.HookGap

# Stained Glass palette (DECISIONS 49, src/client/UI/Theme.luau)
PAL = {
    "lead": "#1F1830", "smoke": "#261D3B", "smoke2": "#332854", "ruby": "#E23A55", "rubyL": "#FF8EA0",
    "amber": "#F5A524", "amberL": "#FFD98A", "emerald": "#22B573", "emeraldL": "#86EDB8", "aqua": "#1FC2D3",
    "aquaL": "#9BF3F8", "sapphire": "#2E6BE6", "sapphireL": "#93BCFF", "amethyst": "#8B4FE0", "amethystL": "#CDAAFF",
}


def rgb(h, a=1.0):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return (*c, a)


# ---------------------------------------------------------------------------------------------------------------
# Scene plumbing
# ---------------------------------------------------------------------------------------------------------------


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    for name in ("SUBJECT", "BACKGROUND", "FX"):
        sc.collection.children.link(bpy.data.collections.new(name))
    return sc


def coll(name):
    return bpy.data.collections[name]


def append(path, scene_name=None, keep=None, into="BACKGROUND"):
    """Appends the objects of one scene of a .blend (no cameras/lights) into collection `into`."""
    before = set(bpy.data.images)
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.scenes = [scene_name or src.scenes[0]]
    sc = dst.scenes[0]
    # Relative texture paths (the map palette) point next to the source .blend; make them absolute.
    for img in set(bpy.data.images) - before:
        if img.filepath.startswith("//"):
            img.filepath = os.path.normpath(os.path.join(os.path.dirname(path), img.filepath[2:]))
            img.reload()
    objs = [o for o in sc.objects if o.type not in ("CAMERA", "LIGHT") and (keep is None or keep(o))]
    for o in objs:
        coll(into).objects.link(o)
    bpy.data.scenes.remove(sc)
    return objs


def bounds(objs):
    pts = []
    for o in objs:
        if o.type == "MESH" and not o.hide_render:
            pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def mesh_center(o):
    vs = o.data.vertices
    c = sum((v.co for v in vs), Vector()) / max(len(vs), 1)
    return o.matrix_world @ c


def root_of(objs, name, into):
    root = bpy.data.objects.new(name, None)
    coll(into).objects.link(root)
    for o in objs:
        if o.parent is None:
            o.parent = root
    return root


def emission(name, hexc, strength=8.0):
    m = bpy.data.materials.new(name)
    nt = m.node_tree if m.node_tree else None
    if nt is None:
        m.use_nodes = True
        nt = m.node_tree
    nt.nodes.clear()
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = rgb(hexc)
    e.inputs["Strength"].default_value = strength
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(e.outputs[0], out.inputs[0])
    return m


def matte(name, hexc, rough=0.8):
    m = bpy.data.materials.new(name)
    if not m.node_tree:
        m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = rgb(hexc)
    p.inputs["Roughness"].default_value = rough
    return m


# ---------------------------------------------------------------------------------------------------------------
# Assets
# ---------------------------------------------------------------------------------------------------------------


def glassy_blend(gid):
    if gid == "hollowlight":
        return os.path.join(A, "seasonal", "hollowlight_v2", "hollowlight_v2.blend"), lambda o: "Pumpkin" in o.name
    d = os.path.join(A, "glassies", gid)
    vers = sorted(v for v in os.listdir(d) if v.startswith("v") and os.path.isdir(os.path.join(d, v)))
    return os.path.join(d, vers[-1], f"{gid}.blend"), None


class Glassy:
    def __init__(self, gid, loc=(0, 0, 0), rot=(0, 0, 0), scale=GLASSY_SCALE, into="SUBJECT"):
        path, keep = glassy_blend(gid)
        objs = [o for o in append(path, keep=keep, into=into) if o.type in ("MESH", "EMPTY")]
        self.gid = gid
        self.shards = [o for o in objs if o.type == "MESH" and "shard" in o.name.lower()]
        self.body = [o for o in objs if o not in self.shards]
        for s in self.shards:
            s.hide_render = s.hide_viewport = True
        bpy.context.view_layer.update()
        lo, hi = bounds(self.body)
        # Hang point: v4 glassies already have it at the origin; recentre anything that doesn't (the pumpkin).
        hang = Vector((0, 0, 0)) if abs(hi.z) < 0.6 else Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, hi.z))
        self.root = root_of(objs, f"G_{gid}", into)
        for o in objs:
            if o.parent == self.root:
                o.location -= hang
        self.height = hi.z - lo.z
        self.root.scale = (scale,) * 3
        self.root.location = loc
        self.root.rotation_euler = Euler([math.radians(a) for a in rot])
        bpy.context.view_layer.update()

    def place_standing(self, floor_z):
        bpy.context.view_layer.update()
        lo, _ = bounds(self.body)
        self.root.location.z += floor_z - lo.z
        bpy.context.view_layer.update()

    def centre(self):
        lo, hi = bounds(self.body)
        return (lo + hi) / 2

    def spray(self, impact, toward, count=None, dist=(1.0, 4.0), cone=0.9, seed=1, scale=(0.55, 1.0), hide_body=False):
        """Shows the real shard set flying out of `impact` (world) along `toward`, shrunk and spinning."""
        rnd = random.Random(seed)
        toward = Vector(toward).normalized()
        shards = self.shards[:]
        rnd.shuffle(shards)
        shards = shards[: count or len(shards)]
        bpy.context.view_layer.update()
        mid = self.centre()
        for s in shards:
            s.hide_render = s.hide_viewport = False
            bpy.context.view_layer.update()
            mw = s.matrix_world.copy()
            c = mesh_center(s)
            s.parent = None
            out = (c - mid).normalized()
            d = toward + out * 0.6 + Vector([rnd.uniform(-1, 1) for _ in range(3)]) * cone
            target = impact + d.normalized() * rnd.uniform(*dist)
            spin = Euler([rnd.uniform(-1.2, 1.2) for _ in range(3)]).to_matrix().to_4x4()
            k = rnd.uniform(*scale)
            s.matrix_world = Matrix.Translation(target) @ spin @ Matrix.Scale(k, 4) @ Matrix.Translation(-c) @ mw
        if hide_body:
            for o in self.body:
                o.hide_render = o.hide_viewport = True
        return shards


def string(hook, hang, into="SUBJECT", radius=0.06):
    hook, hang = Vector(hook), Vector(hang)
    d = hook - hang
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=radius, depth=d.length, location=(hook + hang) / 2)
    o = bpy.context.active_object
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    for c in o.users_collection:
        c.objects.unlink(o)
    coll(into).objects.link(o)
    o.data.materials.append(matte("String", "#F4EEDF", 0.5))
    o.name = "String"
    return o


def swing_pose(g, hook, angle_deg):
    """Hangs glassy `g` from `hook` on a StringLength string swung `angle_deg` from vertical (+ = toward +X)."""
    a = math.radians(angle_deg)
    hang = Vector(hook) + Vector((math.sin(a), 0, -math.cos(a))) * STRING
    g.root.location = hang
    g.root.rotation_euler = Euler((0, -a, g.root.rotation_euler.z))
    bpy.context.view_layer.update()
    return hang


def stand(loc=(0, 0, 0), rot_z=0):
    objs = append(os.path.join(A, "map", "clash_stand.blend"))
    root = root_of(objs, "ClashStand", "BACKGROUND")
    root.location = loc
    root.rotation_euler.z = math.radians(rot_z)
    bpy.context.view_layer.update()
    bar = next(o for o in objs if o.name.startswith("Crossbar"))
    lo, hi = bounds([bar])
    centre = (lo + hi) / 2
    along = Vector((1, 0, 0)) if (hi.x - lo.x) > (hi.y - lo.y) else Vector((0, 1, 0))
    under = Vector((centre.x, centre.y, lo.z))
    # Studio moves the hooks to +-HookGap/2 (DECISIONS 30); the .blend still has them at +-1.5.
    for o in objs:
        if o.name.startswith(("HookA", "HookB")):
            o.location += along * (HOOK_GAP / 2 - 1.5) * (-1 if o.name.startswith("HookA") else 1)
    return objs, under - along * HOOK_GAP / 2, under + along * HOOK_GAP / 2


def island(name="Isle_Featured", loc=(0, 0, 0), rot_z=0, scale=1.0):
    objs = append(os.path.join(A, "map", "sky", "sky_islands.blend"), scene_name=f"{name}_Asset")
    root = root_of(objs, name, "BACKGROUND")
    bpy.context.view_layer.update()
    lo, hi = bounds(objs)
    for o in objs:
        o.location.z -= hi.z
    root.location = loc
    root.rotation_euler.z = math.radians(rot_z)
    root.scale = (scale,) * 3
    return objs


def kit(name, loc, scale=1.0, rot_z=0, sub="sky_kit"):
    objs = append(os.path.join(A, "map", sub, name, f"{name}.blend"))
    root = root_of(objs, name, "BACKGROUND")
    root.location, root.scale = loc, (scale,) * 3
    root.rotation_euler.z = math.radians(rot_z)
    return objs


def decor(keep, loc, scale=1.0, rot_z=0):
    objs = append(os.path.join(A, "map", "decor_kit", "decor_kit.blend"), keep=lambda o: keep in o.name)
    root = root_of(objs, keep, "BACKGROUND")
    # The kit's palette texture doesn't survive the append; use the live place's flat colours.
    colours = {"Canopy": "#3E8E3A", "Leaves": "#3FA34D", "Trunk": "#6B4426", "Stone": "#8E86A8"}
    for o in objs:
        o.location.x = o.location.y = 0
        for k, c in colours.items():
            if k in o.name:
                o.data.materials.clear()
                o.data.materials.append(matte(f"Decor{k}", c, 0.9))
    root.location, root.scale = loc, (scale,) * 3
    root.rotation_euler.z = math.radians(rot_z)
    return objs


def kiln(loc, rot_z=0, scale=1.0):
    objs = append(os.path.join(A, "map", "lobby_v2", "Kiln_Furnace.blend"))
    root = root_of(objs, "Kiln", "BACKGROUND")
    root.location, root.scale = loc, (scale,) * 3
    root.rotation_euler.z = math.radians(rot_z)
    return objs


# ---------------------------------------------------------------------------------------------------------------
# FX (stand-ins for the in-game hit sparks; ChatGPT polishes them)
# ---------------------------------------------------------------------------------------------------------------


def sparks(centre, count=40, radius=(0.5, 4.0), colours=("#FFFFFF", "#FFD98A", "#F5A524"), seed=3, streak=0.9,
           size=0.08):
    rnd = random.Random(seed)
    mats = [emission(f"Spark{i}", c, 18) for i, c in enumerate(colours)]
    for i in range(count):
        d = Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 0.8))).normalized()
        r = rnd.uniform(*radius)
        bpy.ops.mesh.primitive_cube_add(size=1, location=Vector(centre) + d * r)
        o = bpy.context.active_object
        L = streak * rnd.uniform(0.4, 1.4) * (r / radius[1] + 0.3)
        o.scale = (size, size, L)
        o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        for c in o.users_collection:
            c.objects.unlink(o)
        coll("FX").objects.link(o)
        o.data.materials.append(rnd.choice(mats))
    # A soft flash at the hit point.
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=0.45, location=centre)
    o = bpy.context.active_object
    for c in o.users_collection:
        c.objects.unlink(o)
    coll("FX").objects.link(o)
    o.name = "Flash"
    o.data.materials.append(emission("Flash", "#FFF6DA", 25))
    light("HitGlow", "POINT", 2500, centre, colour="#FFE2A8", size=0.5)


# ---------------------------------------------------------------------------------------------------------------
# Lighting, sky, camera
# ---------------------------------------------------------------------------------------------------------------


def light(name, kind, energy, loc, target=None, colour="#FFFFFF", size=2.0, angle=None):
    data = bpy.data.lights.new(name, kind)
    data.energy = energy
    data.color = rgb(colour)[:3]
    if kind == "AREA":
        data.size = size
    elif kind in ("POINT", "SPOT"):
        data.shadow_soft_size = size
    if kind == "SUN" and angle:
        data.angle = math.radians(angle)
    o = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    if target is not None:
        o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return o


SKIES = {
    # Golden hour like the live place (SunsetSereneSky, ClockTime 17.25): warm horizon, peach band, soft blue top.
    "golden": [(0.0, "#FFE3A3"), (0.42, "#FFC08A"), (0.55, "#F7A9A0"), (0.75, "#9EB9EC"), (1.0, "#5D86D6")],
    # Deep jewel night: amethyst horizon into sapphire and lead.
    "purple": [(0.0, "#C77DFF"), (0.4, "#8B4FE0"), (0.62, "#3B2F8E"), (0.85, "#261D5B"), (1.0, "#1F1830")],
    # Halloween dusk: pumpkin glow under violet.
    "halloween": [(0.0, "#FFB25A"), (0.4, "#E86A3A"), (0.55, "#8B4FE0"), (0.8, "#3B2560"), (1.0, "#1F1830")],
}


def sky(kind, strength=1.0):
    sc = bpy.context.scene
    w = bpy.data.worlds.new(f"Sky_{kind}")
    sc.world = w
    try:
        w.use_nodes = True
    except Exception:
        pass
    nt = w.node_tree
    nt.nodes.clear()
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 0.0
    mr.inputs["From Max"].default_value = 1.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    stops = SKIES[kind]
    els[0].position, els[0].color = stops[0][0], rgb(stops[0][1])
    els[1].position, els[1].color = stops[-1][0], rgb(stops[-1][1])
    for pos, c in stops[1:-1]:
        e = els.new(pos)
        e.color = rgb(c)
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.inputs["Strength"].default_value = strength
    out = nt.nodes.new("ShaderNodeOutputWorld")
    nt.links.new(tc.outputs["Window"], sep.inputs[0])
    nt.links.new(sep.outputs["Y"], mr.inputs["Value"])
    nt.links.new(mr.outputs[0], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], bg.inputs["Color"])
    nt.links.new(bg.outputs[0], out.inputs["Surface"])


def golden_lights(focus, sun_dir=(-0.6, 0.8, 0.35), warm="#FFD7A0", rim="#CFE6FF", k=1.0):
    f = Vector(focus)
    light("Sun", "SUN", 4.0 * k, f + Vector(sun_dir) * 50, target=f, colour=warm, angle=3)
    light("Key", "AREA", 1800 * k, f + Vector((-9, -12, 8)), target=f, colour="#FFF1DE", size=8)
    light("Rim", "AREA", 2600 * k, f + Vector((7, 12, 6)), target=f, colour=rim, size=6)
    light("RimL", "AREA", 1400 * k, f + Vector((-10, 9, 3)), target=f, colour=warm, size=5)


def front_fill(target, energy=30, dist=14):
    """A soft white light from just above the lens so glass keeps its true tint against coloured backdrops."""
    t = Vector(target)
    light("FrontFill", "AREA", energy * dist * dist / 4, t + Vector((1.5, -dist, 3)), target=t, colour="#FFFFFF",
          size=dist * 0.8)


def camera(loc, look, lens=50, dof=None, fstop=2.8, shift=(0, 0)):
    data = bpy.data.cameras.new("Cam")
    data.lens = lens
    data.shift_x, data.shift_y = shift
    cam = bpy.data.objects.new("Cam", data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = loc
    cam.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    if dof:
        data.dof.use_dof = True
        data.dof.focus_distance = (Vector(dof) - Vector(loc)).length
        data.dof.aperture_fstop = fstop
    bpy.context.scene.camera = cam
    return cam


def aim(target, az=0.0, el=8.0, dist=25.0, lens=50, shift=(0, 0), fstop=4.0):
    """Camera `dist` from `target`, `az` degrees round from the front (-Y), `el` degrees up, looking at the target.
    `shift` moves the frame (fractions of the width) so the target sits off-centre: (-0.15, 0.03) puts it right/low."""
    a, e = math.radians(az), math.radians(el)
    d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    return camera(Vector(target) + d * dist, target, lens=lens, dof=target, fstop=fstop, shift=shift)


def clouds(spots, seed=5, tint="#FFF4EA"):
    """Sky-kit clouds as soft, slightly glowing puffs (like the live place's cloud layer)."""
    rnd = random.Random(seed)
    names = ["cloud_bank", "cloud_puff", "cloud_long"]
    m = matte("Cloud", tint, 1.0)
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Emission Color"].default_value = rgb(tint)
    p.inputs["Emission Strength"].default_value = 0.35
    for i, (loc, s) in enumerate(spots):
        for o in kit(names[i % 3], loc, s, rnd.uniform(0, 360)):
            if o.type == "MESH":
                o.data.materials.clear()
                o.data.materials.append(m)


# ---------------------------------------------------------------------------------------------------------------
# Scenes. Each returns (resolution, notes). Clear zone "TL" = top-left calm, "TC" = top-centre calm.
# ---------------------------------------------------------------------------------------------------------------


def arena_backdrop(bg="golden", extra_islands=True):
    sky(bg)
    island("Isle_Featured", (0, 0, 0))
    objs, hookA, hookB = stand((0, 0, 0))
    if extra_islands:
        island("Isle_Arena2", (-80, 95, -18), 25, 0.9)
        island("Isle_Arena1", (95, 120, -30), -20, 0.9)
        island("Isle_Lobby", (-30, 190, -40), 10, 1.0)
    clouds([((-70, 80, -45), 3.0), ((80, 90, -50), 3.5), ((10, 160, -60), 4.0), ((-120, 170, -40), 3.0),
            ((140, 60, -55), 3.0)], tint="#FFF4EA" if bg == "golden" else "#D9C2FF")
    decor("TreeRound", (-22, 12, 0), 1.3)
    decor("TreePine", (24, 14, 0), 1.3)
    return hookA, hookB


def clash_pair(a, b, hookA, hookB, overlap=0.25, spray_count=9, seed=2, turn=(14, -14), spark_count=40):
    """The hit moment: both glassies swung in toward each other until their bodies just meet."""
    ga, gb = Glassy(a, rot=(0, 0, turn[0])), Glassy(b, rot=(0, 0, turn[1]))
    theta = 0.0
    while theta < 60:
        swing_pose(ga, hookA, theta)
        swing_pose(gb, hookB, -theta)
        _, ua = bounds(ga.body)
        lb, _ = bounds(gb.body)
        if ua.x - lb.x >= overlap:
            break
        theta += 0.5
    string(hookA, ga.root.location)
    string(hookB, gb.root.location)
    impact = (ga.centre() + gb.centre()) / 2
    toward = (gb.centre() - impact).normalized() + Vector((0, -1.2, 0.4))
    gb.spray(impact, toward, count=spray_count, dist=(2.5, 7.0), seed=seed, scale=(0.35, 0.7))
    sparks(impact, seed=seed, count=spark_count)
    return ga, gb, impact


def scene_T1(zone="TL", bg="golden", pair=("glass_phoenix", "comet")):
    hookA, hookB = arena_backdrop(bg)
    ga, gb, impact = clash_pair(pair[0], pair[1], hookA, hookB)
    golden_lights(impact, k=0.8 if bg != "golden" else 1.0,
                  warm="#FFD7A0" if bg == "golden" else "#FFB070", rim="#CFE6FF" if bg == "golden" else "#C9A6FF")
    if zone == "TL":
        aim(impact, az=-24, el=5, dist=36, lens=85, shift=(-0.16, 0.03), fstop=2.8)
    else:
        aim(impact, az=-12, el=5, dist=36, lens=85, shift=(0, 0.1), fstop=2.8)
    return impact


def scene_T2(zone="TL", bg="golden", gid="glass_dragon"):
    sky(bg)
    island("Isle_Featured", (0, 40, -14), 15)
    island("Isle_Arena1", (-70, 120, -40), 25, 0.9)
    clouds([((-50, 90, -45), 3.5), ((60, 100, -50), 3.5), ((0, 170, -60), 4.5), ((-120, 160, -45), 3.0)],
           tint="#FFF4EA" if bg == "golden" else "#D9C2FF")
    g = Glassy(gid, loc=(0, 0, 0), rot=(0, 0, 18), scale=GLASSY_SCALE * 1.6)
    c = g.centre()
    impact = c + Vector((1.6, -0.6, 0.6))
    g.spray(impact, (0.8, -1.0, 0.35), count=None, dist=(3.0, 11.0), cone=0.6, seed=7, scale=(0.4, 0.9))
    sparks(impact, count=30, radius=(0.6, 3.5), seed=7)
    string(c + Vector((0, 0, 60)), g.root.location, radius=0.08)
    golden_lights(c, k=1.6, warm="#FFD7A0" if bg == "golden" else "#FFB070",
                  rim="#CFE6FF" if bg == "golden" else "#E2C2FF")
    front_fill(c, 40)
    lo, hi = bounds(g.body)
    h = hi.z - lo.z  # frame by the hero's height so the dragon and unicorn both fill ~70% of it
    if zone == "TL":
        aim(c, az=-8, el=4, dist=3.3 * h, lens=50, shift=(-0.16, -0.03), fstop=3.2)
    else:
        aim(c, az=-4, el=4, dist=3.5 * h, lens=50, shift=(0, 0.02), fstop=3.2)
    return impact


def scene_T3(zone="TL"):
    hookA, hookB = arena_backdrop("golden")
    ga, gb, impact = clash_pair("honey_bear", "prism_blade", hookA, hookB, seed=11)
    golden_lights(impact)
    # Wide enough for two avatars on the pads either side (composited from Studio shots).
    if zone == "TL":
        camera(impact + Vector((-2.5, -24, -2.0)), impact + Vector((-1.2, 0, 0.6)), lens=32, dof=impact, fstop=5.6)
    else:
        camera(impact + Vector((0, -24, -2.0)), impact + Vector((0, 0, 1.4)), lens=32, dof=impact, fstop=5.6)
    return impact


T4_ROWS = [
    # (rarity colour, glassies) front (low) to back (high)
    ("#EEE7D9", ["pop", "jam", "ketchup_bottle", "lemonade_bottle", "milk_bottle", "pickle_jar"]),
    ("#22B573", ["glass_top", "piggy_bank", "chime", "bubble_wand", "mason_jar"]),
    ("#2E6BE6", ["potion_flask", "light_bulb", "hourglass", "frostglobe"]),
    ("#8B4FE0", ["honey_bear", "rocket_pop", "crystal_ball", "glass_duck"]),
]


def scene_T4(zone="TL"):
    sky("purple", 0.25)
    floor = bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=30, depth=1, location=(0, 0, -0.5))
    bpy.context.active_object.data.materials.append(matte("Floor", "#3B2F5E"))
    gl = []
    step_h, step_d = 2.2, 4.2
    for i, (col, ids) in enumerate(T4_ROWS):
        z = i * step_h
        y = i * step_d
        width = 4.6 * len(ids) + 2
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, y, z / 2 + step_h / 2 - 0.5))
        st = bpy.context.active_object
        st.scale = (width, step_d, z + step_h)
        st.data.materials.append(matte(f"Step{i}", "#4A3A72", 0.7))
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, y - step_d / 2 + 0.05, z + step_h - 0.62))
        trim = bpy.context.active_object
        trim.scale = (width, 0.12, 0.22)
        trim.data.materials.append(emission(f"Trim{i}", col, 3))
        top = z + step_h - 0.5
        for j, gid in enumerate(ids):
            x = (j - (len(ids) - 1) / 2) * 4.6
            g = Glassy(gid, loc=(x, y - 0.3, 0), rot=(0, 0, random.Random(j + i).uniform(-25, 25)))
            g.place_standing(top)
            gl.append(g)
    # Legendary in the spotlight on a pedestal at the top.
    zt = len(T4_ROWS) * step_h
    yt = len(T4_ROWS) * step_d
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=3.2, depth=zt + 2.4, location=(0, yt, (zt + 2.4) / 2 - 0.5))
    bpy.context.active_object.data.materials.append(matte("Pedestal", "#4A3A72", 0.6))
    bpy.ops.mesh.primitive_torus_add(major_radius=3.2, minor_radius=0.12, location=(0, yt, zt + 1.9))
    bpy.context.active_object.data.materials.append(emission("PedTrim", "#F5A524", 5))
    leg = Glassy("glass_unicorn", loc=(0, yt, 0), rot=(0, 0, -15), scale=GLASSY_SCALE * 1.6)
    leg.place_standing(zt + 1.9)
    lc = leg.centre()
    light("Spot", "SPOT", 9000, lc + Vector((0, -6, 18)), target=lc, colour="#FFE6B0", size=1.0)
    bpy.data.lights["Spot"].spot_size = math.radians(28)
    kiln((15, yt + 9, 0), rot_z=200, scale=1.3)
    light("KilnGlow", "POINT", 6000, (13, yt + 5, 4), colour="#FFA640", size=3)
    front_fill((0, 6, 5), 30, 26)
    for x in (-28, 28):
        light("Accent", "AREA", 2500, (x, 2, 14), target=(0, 8, 4), colour="#CDAAFF" if x < 0 else "#9BF3F8", size=10)
    light("Front", "AREA", 5000, (0, -26, 16), target=(0, 6, 4), colour="#FFFFFF", size=14)
    look = Vector((0, 9, 7))
    if zone == "TL":
        aim(look + Vector((0, 0, 5)), az=-18, el=16, dist=48, lens=40, shift=(-0.12, 0.0), fstop=8)
    else:
        aim(look + Vector((0, 0, 5)), az=0, el=16, dist=50, lens=40, shift=(0, 0.03), fstop=8)
    return lc


def scene_T5(zone="TL"):
    sky("golden")
    island("Isle_Featured", (0, 0, 0))
    objs, hookA, hookB = stand((0, 0, 0))
    kit("featured_arch", (0, 17, 0), 1.0)
    island("Isle_Arena3", (-62, -10, -14), 90, 0.9)
    island("Isle_Arena2", (70, 30, -22), -80, 0.9)
    island("Isle_Lobby", (0, 110, -38), 0, 1.0)
    clouds([((-60, 60, -24), 3.0), ((70, 70, -30), 3.5), ((10, 140, -35), 4.0), ((-110, 150, -20), 3.0)])
    for p in ((-24, 12, 0), (26, 10, 0), (-28, -10, 0)):
        decor("TreePine" if p[0] > 0 else "TreeRound", p, 1.2)
    ga, gb, impact = clash_pair("grizzly_guardian", "pop", hookA, hookB, spray_count=10, seed=4)
    golden_lights(impact)
    if zone == "TL":
        aim(impact + Vector((0, 0, 2)), az=30, el=12, dist=34, lens=45, shift=(-0.12, 0.04), fstop=8)
    else:
        aim(impact + Vector((0, 0, 2)), az=-6, el=12, dist=36, lens=45, shift=(0, 0.1), fstop=8)
    return impact


def sunburst(centre, facing, colours, rays=16, r=40):
    """Stained-glass sunburst behind an icon subject: alternating jewel rays with dark lead edges."""
    import bmesh
    mats = [emission(f"Ray{i}", c, 0.55) for i, c in enumerate(colours)]
    lead = matte("Lead", PAL["lead"], 0.6)
    me = bpy.data.meshes.new("Sunburst")
    bm = bmesh.new()
    for i in range(rays):
        a0, a1 = i / rays * math.tau, (i + 1) / rays * math.tau
        v = [bm.verts.new((0, 0, 0)), bm.verts.new((math.cos(a0) * r, math.sin(a0) * r, 0)),
             bm.verts.new((math.cos(a1) * r, math.sin(a1) * r, 0))]
        f = bm.faces.new(v)
        f.material_index = i % len(mats)
    bm.to_mesh(me)
    o = bpy.data.objects.new("Sunburst", me)
    coll("BACKGROUND").objects.link(o)
    for m in mats:
        me.materials.append(m)
    o.location = centre
    o.rotation_euler = Vector(facing).to_track_quat("Z", "Y").to_euler()
    w = o.modifiers.new("Lead", "WIREFRAME")
    w.thickness, w.use_replace = 0.35, False
    me.materials.append(lead)
    w.material_offset = len(mats)
    return o


def scene_I1():
    sky("purple", 0.4)
    g = Glassy("glass_dragon", rot=(0, 0, 18), scale=GLASSY_SCALE * 1.6)
    c = g.centre()
    impact = c + Vector((1.5, -0.8, 0.5))
    g.spray(impact, (1.0, -0.8, 0.4), count=11, dist=(3.5, 7.5), cone=0.55, seed=9, scale=(0.35, 0.65))
    sparks(impact, count=24, radius=(0.5, 3.0), seed=9)
    sunburst(c + Vector((0, 14, 0)), (0, -1, 0), [PAL["amber"], PAL["ruby"], PAL["amethyst"], PAL["sapphire"],
                                                  PAL["aqua"], PAL["emerald"]])
    golden_lights(c, k=1.4)
    front_fill(c, 45, 17)
    aim(c, az=0, el=2, dist=19, lens=50, shift=(0.05, 0.0), fstop=5.6)
    return c


def scene_I2():
    sky("golden")
    hookA, hookB = Vector((-3, 0, 20)), Vector((3, 0, 20))
    ga, gb, impact = clash_pair("glass_phoenix", "comet", hookA, hookB, spray_count=8, seed=13, spark_count=18)
    golden_lights(impact, k=1.2)
    aim(impact, az=0, el=3, dist=14, lens=50, fstop=5.6)
    return impact


def scene_I3():
    sky("purple", 0.5)
    sb = sunburst(Vector((0, 16, 3)), (0, -1, 0), [PAL["amber"], PAL["amethyst"], PAL["sapphire"], PAL["amberL"]],
                  rays=20)
    for m in sb.data.materials[:-1]:
        m.node_tree.nodes["Emission"].inputs["Strength"].default_value = 0.85
    back_l = Glassy("potion_flask", loc=(-3.6, 3.0, 0), rot=(0, 0, 20))
    back_r = Glassy("honey_bear", loc=(3.6, 3.0, 0), rot=(0, 0, -20))
    front = Glassy("glass_unicorn", loc=(0, -1.0, 0), rot=(0, 0, -10), scale=GLASSY_SCALE * 1.25)
    for g in (back_l, back_r):
        g.place_standing(0.9)
    front.place_standing(0)
    c = front.centre()
    sparks(c + Vector((0, -0.5, 1.5)), count=18, radius=(2.5, 5.0), colours=("#FFFFFF", "#FFD98A"), seed=5,
           streak=0.4, size=0.06)
    bpy.data.objects["HitGlow"].data.energy = 400
    bpy.data.objects["Flash"].scale = (0, 0, 0)
    golden_lights(c, k=1.2)
    front_fill(c, 40, 17)
    camera(c + Vector((0, -14, 1.6)), c + Vector((0, 0, 0.4)), lens=50, dof=c, fstop=8)
    return c


SCENES = {
    "T1a": ("T1", (1920, 1080), lambda: scene_T1("TL", "golden")),
    "T1b": ("T1", (1920, 1080), lambda: scene_T1("TC", "golden")),
    "T1c": ("T1", (1920, 1080), lambda: scene_T1("TL", "purple")),
    "T1d": ("T1", (1920, 1080), lambda: scene_T1("TC", "purple")),
    "T1h": ("T1", (1920, 1080), lambda: scene_T1("TL", "halloween", ("hollowlight", "galaxy_orb"))),
    "T2a": ("T2", (1920, 1080), lambda: scene_T2("TL", "golden")),
    "T2b": ("T2", (1920, 1080), lambda: scene_T2("TC", "golden")),
    "T2c": ("T2", (1920, 1080), lambda: scene_T2("TL", "purple", "glass_unicorn")),
    "T3a": ("T3", (1920, 1080), lambda: scene_T3("TL")),
    "T3b": ("T3", (1920, 1080), lambda: scene_T3("TC")),
    "T4a": ("T4", (1920, 1080), lambda: scene_T4("TL")),
    "T4b": ("T4", (1920, 1080), lambda: scene_T4("TC")),
    "T5a": ("T5", (1920, 1080), lambda: scene_T5("TL")),
    "T5b": ("T5", (1920, 1080), lambda: scene_T5("TC")),
    "I1": ("I1", (1024, 1024), scene_I1),
    "I2": ("I2", (1024, 1024), scene_I2),
    "I3": ("I3", (1024, 1024), scene_I3),
}


# ---------------------------------------------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------------------------------------------


def setup_render(res, draft, samples=64):
    sc = bpy.context.scene
    r = sc.render
    r.resolution_x, r.resolution_y = res
    r.resolution_percentage = 50 if draft else 100
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGBA"
    try:
        sc.view_settings.view_transform = "AgX"
        sc.view_settings.look = "AgX - Punchy"
    except Exception:
        pass
    r.engine = "CYCLES"
    if draft:
        samples = 24
    prefs = bpy.context.preferences.addons["cycles"].preferences
    try:
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        sc.cycles.device = "GPU"
    except Exception:
        pass
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 12
    sc.cycles.transmission_bounces = 12
    sc.cycles.glossy_bounces = 6
    sc.cycles.transparent_max_bounces = 16
    sc.cycles.film_transparent_glass = True


def set_visible(name, visible):
    # Per-collection: toggling hide_render object by object doesn't stick on these appended scenes.
    coll(name).hide_render = not visible


def render_to(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def mask_from_alpha(src, dst):
    img = bpy.data.images.load(src)
    px = list(img.pixels)
    out = [0.0] * len(px)
    for i in range(0, len(px), 4):
        a = px[i + 3]
        out[i] = out[i + 1] = out[i + 2] = a
        out[i + 3] = 1.0
    m = bpy.data.images.new("mask", img.size[0], img.size[1], alpha=True)
    m.pixels = out
    m.filepath_raw = dst
    m.file_format = "PNG"
    m.save()


def build(sid, draft=False):
    folder, res, fn = SCENES[sid]
    reset()
    fn()
    out = os.path.join(KIT, folder)
    os.makedirs(out, exist_ok=True)
    sc = bpy.context.scene
    setup_render(res, draft)
    if draft:
        render_to(os.path.join(out, f"{sid}_draft.png"))
        return
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, f"{sid}_scene.blend"), compress=True)
    sc.render.film_transparent = False
    render_to(os.path.join(out, f"{sid}_beauty.png"))
    # Subject: glassies, strings, shards and sparks only, on transparent.
    sc.render.film_transparent = True
    set_visible("BACKGROUND", False)
    render_to(os.path.join(out, f"{sid}_subject.png"))
    mask_from_alpha(os.path.join(out, f"{sid}_subject.png"), os.path.join(out, f"{sid}_mask.png"))
    # Background only.
    sc.render.film_transparent = False
    set_visible("BACKGROUND", True)
    set_visible("SUBJECT", False)
    set_visible("FX", False)
    for o in bpy.data.objects:
        if o.type == "LIGHT" and o.name.startswith("HitGlow"):
            o.data.energy = 0
    render_to(os.path.join(out, f"{sid}_background.png"))


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    draft = "--draft" in argv
    ids = [a for a in argv if not a.startswith("--")] or list(SCENES)
    for sid in ids:
        build(sid, draft)
        print("KIT_DONE", sid, flush=True)
