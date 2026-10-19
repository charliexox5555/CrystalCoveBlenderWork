"""Hollowlight v5: Moonlantern Carriage polish (same item id `lantern_skiff`, same part names as v4).

Headless only (C owns the Blender MCP window):
    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/blender/build_lantern_carriage_v5.py

Writes assets/blender/seasonal/hollowlight_v5/{moonlantern_carriage_v5.fbx, hollowlight_v5.blend,
moonlantern_carriage_v5_review.png, anchors.json, parts.json}. Refuses to overwrite an existing export; v1-v4 are
never touched.

What changes from v4 (docs/vfx/HOLLOWLIGHT_PREMIUM.md section 5):
- smoother glass hull (140 x 28 loft instead of 90 x 20) with a mint glow inlay along each side (HullGlow_L/R)
- gold star studs along the trims (HullStars)
- wings split at the wrist so the outer tips can flex after the beat (WingTip_L/R + WingTipRibs_L/R), with neon
  trailing edges (WingEdge_L/R, WingTipEdge_L/R)
- a two-link lantern chain under the hook (LanternChain) and gold rings round the engine nozzles (EngineRing_L/R)
Axes as v4: 1 BU = 1 stud, Z up, nose toward +Y (Roblox -Z), origin = seat top centre.
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
GLASSCLASH_REPO = REPO
exec(open(os.path.join(HERE, "glassclash_blender.py"), encoding="utf-8").read())
set_repo(REPO)

R = 2.6
ZC = 1.85
ARC_BACK, ARC_FRONT = math.radians(-200), math.radians(12)
CURL_LENGTH, CURL_RADIUS = 1.7, 0.26
SAMPLES = 140
SECTION = 28
WING_SCALE = 1.15
WRIST = (1.6, 0.65)
SPLIT = (2.0, -0.55)


def to_roblox(v):
    return [round(v.x, 4), round(v.z, 4), round(-v.y, 4)]


def hull_centerline():
    arc = R * (ARC_FRONT - ARC_BACK)
    total = arc + CURL_LENGTH
    pos = Vector((0, R * math.cos(ARC_BACK), ZC + R * math.sin(ARC_BACK)))
    heading = ARC_BACK + math.pi / 2
    points, ds = [], total / SAMPLES
    for i in range(SAMPLES + 1):
        s = i * ds
        points.append((pos.copy(), heading, s))
        k = 1 / R if s < arc else 1 / R + (1 / CURL_RADIUS - 1 / R) * min(1, (s - arc) / CURL_LENGTH)
        heading += k * ds
        pos += Vector((0, math.cos(heading), math.sin(heading))) * ds
    return points, arc


def profile(s, arc):
    if s <= arc:
        u = s / arc
        bump = math.sin(math.pi * u)
        return 0.22 + 1.75 * bump**0.6, 0.12 + 0.95 * bump**0.9
    c = min(1, (s - arc) / CURL_LENGTH)
    return 0.22 - 0.1 * c, 0.12 - 0.05 * c


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def loft(name, frames, section=SECTION, cap=True):
    bm = bmesh.new()
    rings = []
    for centre, side, up, a, b in frames:
        ring = []
        for j in range(section):
            phi = 2 * math.pi * j / section
            ring.append(bm.verts.new(centre + side * (a * math.cos(phi)) + up * (b * math.sin(phi))))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for j in range(section):
            bm.faces.new((r0[j], r0[(j + 1) % section], r1[(j + 1) % section], r1[j]))
    if cap:
        for ring, centre in ((rings[0], frames[0][0]), (rings[-1], frames[-1][0])):
            tip = bm.verts.new(centre)
            for j in range(section):
                bm.faces.new((ring[j], ring[(j + 1) % section], tip))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    return link(bpy.data.objects.new(name, mesh))


def tube(name, points, radius, taper=1.0, section=10):
    frames = []
    for i, p in enumerate(points):
        a = points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]
        t = a.normalized()
        side = t.cross(Vector((0, 0, 1)))
        side = side.normalized() if side.length > 1e-4 else Vector((1, 0, 0))
        up = side.cross(t).normalized()
        r = radius * (1 - (1 - taper) * i / max(1, len(points) - 1))
        frames.append((p, side, up, r, r))
    return loft(name, frames, section=section)


def slab(name, outline, thickness, bevel=0.03, plane="XY", segments=3):
    bm = bmesh.new()
    verts = []
    for x, y in outline:
        verts.append(bm.verts.new((x, y, -thickness / 2) if plane == "XY" else (x, -thickness / 2, y)))
    face = bm.faces.new(verts)
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    moved = [g for g in ext["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=moved, vec=(0, 0, thickness) if plane == "XY" else (0, thickness, 0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = link(bpy.data.objects.new(name, mesh))
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width, mod.segments, mod.limit_method = bevel, segments, "ANGLE"
    return obj


def rounded_box(name, size, location, bevel=0.12, tilt=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = link(bpy.data.objects.new(name, mesh))
    obj.location, obj.rotation_euler = location, (tilt, 0, 0)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width, mod.segments = bevel, 5
    for poly in mesh.polygons:
        poly.use_smooth = True
    return obj


def star_outline(radius, inner=0.45, points=5):
    out = []
    for i in range(points * 2):
        a = math.pi / 2 + i * math.pi / points
        r = radius if i % 2 == 0 else radius * inner
        out.append((r * math.cos(a), r * math.sin(a)))
    return out


def star(name, radius, location, thickness=0.14):
    obj = slab(name, star_outline(radius), thickness, bevel=0.03, plane="XZ")
    obj.location = location
    return obj


def torus(name, major, minor, location, rotation=(0, 0, 0), major_segments=20, minor_segments=8):
    bm = bmesh.new()
    rings = []
    for i in range(major_segments):
        u = 2 * math.pi * i / major_segments
        c = Vector((math.cos(u) * major, math.sin(u) * major, 0))
        n = Vector((math.cos(u), math.sin(u), 0))
        ring = []
        for j in range(minor_segments):
            v = 2 * math.pi * j / minor_segments
            ring.append(bm.verts.new(c + n * (math.cos(v) * minor) + Vector((0, 0, math.sin(v) * minor))))
        rings.append(ring)
    for i in range(major_segments):
        r0, r1 = rings[i], rings[(i + 1) % major_segments]
        for j in range(minor_segments):
            bm.faces.new((r0[j], r0[(j + 1) % minor_segments], r1[(j + 1) % minor_segments], r1[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    obj = link(bpy.data.objects.new(name, mesh))
    obj.location, obj.rotation_euler = location, rotation
    return obj


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    with bpy.context.temp_override(active_object=objs[0], selected_editable_objects=objs, selected_objects=objs):
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    return obj


def wing(side):
    """Inner membrane + flexing tip, ribs and neon edges for one side. Returns parts and wing-space anchors."""
    s = WING_SCALE
    mirror = (lambda pts: [(-x, y) for x, y in reversed(pts)]) if side < 0 else (lambda pts: pts)
    scale = lambda pts: [(x * s, y * s) for x, y in pts]
    inner = [(0, 0.35), WRIST, SPLIT, (2.0, -1.4), (1.1, -0.8), (0.1, -0.6)]
    tip = [WRIST, (3.2, 0.2), (2.5, -0.12), (2.9, -0.8), SPLIT]
    suffix = "R" if side > 0 else "L"
    membrane = slab(f"Wing_{suffix}", scale(mirror(inner)), 0.05, bevel=0.018)
    tip_membrane = slab(f"WingTip_{suffix}", scale(mirror(tip)), 0.045, bevel=0.016)

    def p(x, y, z=0.0):
        return Vector((x * side * s, y * s, z))

    wrist = p(*WRIST)
    ribs = [
        tube(f"WingRib_{suffix}_arm", [p(0, 0.3), wrist], 0.075, taper=0.7),
        tube(f"WingRib_{suffix}_in", [wrist, (wrist + p(2.0, -1.4)) / 2 + Vector((0, 0, 0.05)), p(2.0, -1.4)], 0.05, taper=0.35),
    ]
    tip_ribs = [
        tube(f"WingTipRib_{suffix}_{i}", [wrist, (wrist + p(x, y)) / 2 + Vector((0, 0, 0.05)), p(x, y)], 0.05, taper=0.3)
        for i, (x, y) in enumerate([(3.2, 0.2), (2.9, -0.8)])
    ]
    edge = tube(f"WingEdge_{suffix}", [p(*SPLIT), p(2.0, -1.4), p(1.1, -0.8), p(0.1, -0.6)], 0.035, section=8)
    tip_edge = tube(f"WingTipEdge_{suffix}", [p(3.2, 0.2), p(2.5, -0.12), p(2.9, -0.8), p(*SPLIT)], 0.035, section=8)
    rib = join(ribs, f"WingRibs_{suffix}")
    tip_rib = join(tip_ribs, f"WingTipRibs_{suffix}")
    root = Vector((0.82 * side, -0.15, 0.2))
    rot = (math.radians(-6), math.radians(-18 * side), 0)
    parts = [membrane, tip_membrane, rib, tip_rib, edge, tip_edge]
    for obj in parts:
        obj.rotation_euler = rot
        obj.location = root
    bpy.context.view_layer.update()
    m = membrane.matrix_world
    anchors = {
        f"WingRoot_{suffix}": to_roblox(root),
        f"WingWrist_{suffix}": to_roblox(m @ wrist),
        f"WingSplit_{suffix}": to_roblox(m @ p(*SPLIT)),
    }
    return parts, anchors


def build():
    folder = repo_path("assets", "blender", "seasonal", "hollowlight_v5")
    fbx = os.path.join(folder, "moonlantern_carriage_v5.fbx")
    if os.path.exists(fbx):
        raise RuntimeError("hollowlight_v5 export exists; make a new revision instead of overwriting")
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    scene = bpy.context.scene
    scene.name = "HollowlightV5_MoonlanternCarriage"
    anchors = {}

    points, arc = hull_centerline()
    frames, rims, glows = [], {1: [], -1: []}, {1: [], -1: []}
    for pos, heading, s in points:
        tangent = Vector((0, math.cos(heading), math.sin(heading)))
        up = Vector((1, 0, 0)).cross(tangent).normalized()
        w, t = profile(s, arc)
        frames.append((pos, Vector((1, 0, 0)), up, w / 2, t / 2))
        if s <= arc and 0.04 < s / arc < 0.96:
            for side in (1, -1):
                rims[side].append(pos + Vector((side * w / 2 * 0.9, 0, 0)) + up * (t * 0.18))
        if s <= arc and 0.08 < s / arc < 0.92:
            for side in (1, -1):
                glows[side].append(pos + Vector((side * w / 2 * 0.985, 0, 0)) - up * (t * 0.12))
    hull = loft("Hull", frames)
    trims = [tube(f"HullTrim_{'R' if side > 0 else 'L'}", pts[::2], 0.055, section=10) for side, pts in rims.items()]
    hull_glow = [tube(f"HullGlow_{'R' if side > 0 else 'L'}", pts[::3], 0.032, section=8) for side, pts in glows.items()]

    # Gold star studs along each trim, facing outward.
    studs = []
    for side, pts in rims.items():
        for k in range(5):
            i = int((k + 1) / 6 * (len(pts) - 1))
            st = slab(f"HullStar_{side}_{k}", star_outline(0.14), 0.05, bevel=0.01, plane="XZ", segments=1)
            st.location = pts[i] + Vector((side * 0.07, 0, 0.04))
            st.rotation_euler = (0, 0, math.radians(90 * side))
            studs.append(st)
    bpy.context.view_layer.update()
    for st in studs:
        st.select_set(True)
    hull_stars = join(studs, "HullStars")

    tip = points[-1][0]
    anchors["LanternHook"] = to_roblox(tip + Vector((0, 0, -0.08)))
    hook = tube("Hook", [tip + Vector((0, 0.0, 0.02)), tip + Vector((0, 0.06, -0.12)), tip + Vector((0, 0, -0.24))], 0.035)
    chain = join(
        [
            torus("ChainLink_0", 0.06, 0.016, tip + Vector((0, 0, -0.3)), rotation=(math.pi / 2, 0, 0)),
            torus("ChainLink_1", 0.06, 0.016, tip + Vector((0, 0, -0.4)), rotation=(math.pi / 2, 0, math.pi / 2)),
        ],
        "LanternChain",
    )
    anchors["ChainBottom"] = to_roblox(tip + Vector((0, 0, -0.46)))
    seat = rounded_box("Seat", (1.3, 1.15, 0.3), (0, 0.25, -0.15))
    back = rounded_box("Backrest", (1.2, 0.26, 1.1), (0, -0.5, 0.5), tilt=math.radians(-14))
    bar = [Vector((-0.75, 1.05, -0.05)), Vector((-0.75, 1.15, 0.9)), Vector((-0.45, 1.3, 1.08)),
           Vector((0, 1.22, 1.1)), Vector((0.45, 1.3, 1.08)), Vector((0.75, 1.15, 0.9)), Vector((0.75, 1.05, -0.05))]
    handlebar = tube("Handlebar", bar, 0.06, section=12)
    footrest = tube("Footrest", [Vector((-0.6, 1.78, 0.42)), Vector((0, 1.82, 0.45)), Vector((0.6, 1.78, 0.42))], 0.07, section=12)
    back_tip = points[0][0]
    tail = star("TailStar", 0.32, back_tip + Vector((0, -0.05, 0.2)))
    anchors["Stern"] = to_roblox(back_tip + Vector((0, -0.2, 0.1)))

    wing_parts = []
    for side in (1, -1):
        parts, a = wing(side)
        wing_parts += parts
        anchors.update(a)
    pods = []
    for side in (1, -1):
        suffix = "R" if side > 0 else "L"
        centre = Vector((1.05 * side, -0.45, -0.75))
        body = [(centre + Vector((0, 0.5 - 1.0 * i / 16, 0)), 0.04 + 0.22 * math.sin(math.pi * i / 16) ** 0.7)
                for i in range(17)]
        pod = loft(f"EnginePod_{suffix}", [(p, Vector((1, 0, 0)), Vector((0, 0, 1)), r, r) for p, r in body], section=18)
        core = loft(f"EngineCore_{suffix}", [(p, Vector((1, 0, 0)), Vector((0, 0, 1)), r * 0.55, r * 0.55) for p, r in body[3:-3]], section=12)
        ring = torus(f"EngineRing_{suffix}", 0.17, 0.03, centre + Vector((0, -0.36, 0)), rotation=(math.pi / 2, 0, 0))
        pods += [pod, core, ring]
        anchors["Exhaust_" + suffix] = to_roblox(centre + Vector((0, -0.55, 0)))
    anchors["Seat"] = to_roblox(Vector((0, 0.25, 0)))
    anchors["Footrest"] = to_roblox(Vector((0, 1.8, 0.44)))
    anchors["HandlebarGrip"] = to_roblox(Vector((0, 1.22, 1.1)))

    by = {o.name: o for o in [hull, *trims, *hull_glow, hull_stars, hook, chain, seat, back, handlebar, footrest, tail,
                                *wing_parts, *pods]}
    palette = {
        "#3B2466": ["Hull"],
        "#DDA84D": ["HullTrim_R", "HullTrim_L", "HullStars", "Hook", "LanternChain", "Handlebar", "Footrest", "TailStar",
                    "WingRibs_R", "WingRibs_L", "WingTipRibs_R", "WingTipRibs_L", "EngineRing_R", "EngineRing_L"],
        "#FFB347": ["Seat", "Backrest"],
        "#7A55C8": ["Wing_R", "Wing_L", "WingTip_R", "WingTip_L"],
        "#61EFBD": ["EnginePod_R", "EnginePod_L", "EngineCore_R", "EngineCore_L", "HullGlow_R", "HullGlow_L"],
        "#C79BFF": ["WingEdge_R", "WingEdge_L", "WingTipEdge_R", "WingTipEdge_L"],
    }
    colours = {}
    for hex_color, names in palette.items():
        mat = glossy_preview_material("GC_Preview_" + hex_color.lstrip("#"), hex_color)
        for n in names:
            o = by[n]
            o.data.materials.clear()
            o.data.materials.append(mat)
            colours[n] = hex_color
    objects = list(by.values())
    for o in objects:
        o.modifiers.new("Triangulate", "TRIANGULATE")
    bpy.context.view_layer.update()
    os.makedirs(folder, exist_ok=True)
    export_fbx(objects, fbx)
    render_icon(objects, os.path.join(folder, "moonlantern_carriage_v5_review.png"), size=768, samples=32)
    with open(os.path.join(folder, "anchors.json"), "w", encoding="utf-8") as f:
        json.dump(anchors, f, indent=2)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    tris = {}
    for o in objects:
        m = o.evaluated_get(depsgraph).to_mesh()
        tris[o.name] = sum(len(p.vertices) - 2 for p in m.polygons)
        o.evaluated_get(depsgraph).to_mesh_clear()
    with open(os.path.join(folder, "parts.json"), "w", encoding="utf-8") as f:
        json.dump({"tris": tris, "total": sum(tris.values()), "colours": colours}, f, indent=2)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(folder, "hollowlight_v5.blend"), compress=True)
    return {"fbx": fbx, "tris": sum(tris.values()), "by_part": tris}


result = build()
print("RESULT", json.dumps(result))
