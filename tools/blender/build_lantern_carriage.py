"""Hollowlight v4: the Moonlantern Carriage flyer (replaces the Lantern Skiff look, same item id).

Run through Blender MCP after loading glassclash_blender.py and set_repo(). Builds in its own scene, then
writes assets/blender/seasonal/hollowlight_v4/{moonlantern_carriage.fbx, hollowlight_v4.blend,
moonlantern_carriage_review.png, anchors.json}. Refuses to overwrite an existing export.

Axes: 1 BU = 1 stud, Z up, nose toward +Y (Roblox -Z), origin = seat top centre (the rider's hips sit
at the pivot). anchors.json lists hinge/hook/exhaust points already converted to Roblox (x, z, -y).
The hanging lantern is not modelled here: Studio reuses the installed Hollowlight pumpkin.
"""
import json
import math
import os
import bmesh
import bpy
from mathutils import Vector

R = 2.6  # hull arc radius
ZC = 1.85  # hull arc centre height
ARC_BACK, ARC_FRONT = math.radians(-200), math.radians(12)
CURL_LENGTH, CURL_RADIUS = 1.7, 0.26
SAMPLES = 90
SECTION = 20


def to_roblox(v):
    return [round(v.x, 4), round(v.z, 4), round(-v.y, 4)]


def hull_centerline():
    """Turtle walk: constant-curvature moon arc, then a tightening forward scroll."""
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
        return 0.22 + 1.75 * bump**0.6, 0.12 + 0.95 * bump**0.9  # width, thickness
    c = min(1, (s - arc) / CURL_LENGTH)
    return 0.22 - 0.1 * c, 0.12 - 0.05 * c


def loft(name, frames, collection, section=SECTION, cap=True):
    """frames: [(centre, side_axis, up_axis, half_side, half_up)] -> closed tube mesh."""
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
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    return obj


def tube(name, points, radius, collection, taper=1.0, section=10):
    frames = []
    for i, p in enumerate(points):
        a = points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]
        t = a.normalized()
        side = t.cross(Vector((0, 0, 1)))
        side = side.normalized() if side.length > 1e-4 else Vector((1, 0, 0))
        up = side.cross(t).normalized()
        r = radius * (1 - (1 - taper) * i / max(1, len(points) - 1))
        frames.append((p, side, up, r, r))
    return loft(name, frames, collection, section=section)


def slab(name, outline, thickness, collection, bevel=0.03, plane="XY"):
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
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width, mod.segments, mod.limit_method = bevel, 2, "ANGLE"
    return obj


def rounded_box(name, size, location, collection, bevel=0.12, tilt=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.location, obj.rotation_euler = location, (tilt, 0, 0)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width, mod.segments = bevel, 4
    for poly in mesh.polygons:
        poly.use_smooth = True
    return obj


def star(name, radius, location, collection):
    outline = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        r = radius if i % 2 == 0 else radius * 0.45
        outline.append((r * math.cos(a), r * math.sin(a)))
    obj = slab(name, outline, 0.14, collection, bevel=0.03, plane="XZ")
    obj.location = location
    return obj


def wing(side, collection):
    s = 1.15
    outline = [(0, 0.35), (1.6, 0.65), (3.2, 0.2), (2.5, -0.12), (2.9, -0.8), (2.0, -0.55), (2.0, -1.4),
               (1.1, -0.8), (0.1, -0.6)]
    if side < 0:
        outline = [(-x, y) for x, y in reversed(outline)]
    outline = [(x * s, y * s) for x, y in outline]
    suffix = "R" if side > 0 else "L"
    membrane = slab(f"Wing_{suffix}", outline, 0.05, collection, bevel=0.018)
    wrist, tips = Vector((1.6 * side * s, 0.65 * s, 0)), [(3.2, 0.2), (2.9, -0.8), (2.0, -1.4)]
    ribs = [tube(f"WingRib_{suffix}_arm", [Vector((0, 0.3 * s, 0)), wrist], 0.07, collection, taper=0.7)]
    for i, (x, y) in enumerate(tips):
        tip = Vector((x * side * s, y * s, 0))
        mid = wrist.lerp(tip, 0.5) + Vector((0, 0, 0.05))
        ribs.append(tube(f"WingRib_{suffix}_{i}", [wrist, mid, tip], 0.05, collection, taper=0.3))
    # Join ribs into one gold mesh per side.
    bpy.ops.object.select_all(action="DESELECT")
    for r in ribs:
        r.select_set(True)
    bpy.context.view_layer.objects.active = ribs[0]
    bpy.ops.object.join()
    rib = bpy.context.view_layer.objects.active
    rib.name = f"WingRibs_{suffix}"
    root = Vector((0.82 * side, -0.15, 0.2))
    for obj in (membrane, rib):
        obj.rotation_euler = (math.radians(-6), math.radians(-18 * side), 0)
        obj.location = root
    return membrane, rib, root


def build_lantern_carriage():
    folder = repo_path("assets", "blender", "seasonal", "hollowlight_v4")
    fbx = os.path.join(folder, "moonlantern_carriage.fbx")
    if os.path.exists(fbx):
        raise RuntimeError("hollowlight_v4 export exists; make a new revision instead of overwriting")
    window = bpy.context.window
    previous = window.scene
    scene = bpy.data.scenes.new("HollowlightV4_MoonlanternCarriage")
    window.scene = scene
    col = scene.collection
    anchors = {}
    try:
        points, arc = hull_centerline()
        frames, rims = [], {1: [], -1: []}
        for pos, heading, s in points:
            tangent = Vector((0, math.cos(heading), math.sin(heading)))
            up = Vector((1, 0, 0)).cross(tangent).normalized()
            w, t = profile(s, arc)
            frames.append((pos, Vector((1, 0, 0)), up, w / 2, t / 2))
            if s <= arc and 0.04 < s / arc < 0.96:
                for side in (1, -1):
                    rims[side].append(pos + Vector((side * w / 2 * 0.9, 0, 0)) + up * (t * 0.18))
        hull = loft("Hull", frames, col)
        trims = [
            tube(f"HullTrim_{'R' if side > 0 else 'L'}", pts[::2], 0.055, col, section=8) for side, pts in rims.items()
        ]
        tip = points[-1][0]
        anchors["LanternHook"] = to_roblox(tip + Vector((0, 0, -0.08)))
        hook = tube("Hook", [tip + Vector((0, 0.0, 0.02)), tip + Vector((0, 0.06, -0.12)), tip + Vector((0, 0, -0.24))], 0.035, col)
        seat = rounded_box("Seat", (1.3, 1.15, 0.3), (0, 0.25, -0.15), col)
        back = rounded_box("Backrest", (1.2, 0.26, 1.1), (0, -0.5, 0.5), col, tilt=math.radians(-14))
        bar = [Vector((-0.75, 1.05, -0.05)), Vector((-0.75, 1.15, 0.9)), Vector((-0.45, 1.3, 1.08)),
               Vector((0, 1.22, 1.1)), Vector((0.45, 1.3, 1.08)), Vector((0.75, 1.15, 0.9)), Vector((0.75, 1.05, -0.05))]
        handlebar = tube("Handlebar", bar, 0.06, col)
        footrest = tube("Footrest", [Vector((-0.6, 1.78, 0.42)), Vector((0, 1.82, 0.45)), Vector((0.6, 1.78, 0.42))], 0.07, col)
        back_tip = points[0][0]
        tail = star("TailStar", 0.32, back_tip + Vector((0, -0.05, 0.2)), col)
        wings, ribs = [], []
        for side in (1, -1):
            membrane, rib, root = wing(side, col)
            wings.append(membrane)
            ribs.append(rib)
            anchors["WingRoot_" + ("R" if side > 0 else "L")] = to_roblox(root)
        pods = []
        for side in (1, -1):
            suffix = "R" if side > 0 else "L"
            centre = Vector((1.05 * side, -0.45, -0.75))
            body = [(centre + Vector((0, 0.5 - 1.0 * i / 12, 0)), 0.04 + 0.22 * math.sin(math.pi * i / 12) ** 0.7)
                    for i in range(13)]
            pod = loft(f"EnginePod_{suffix}", [(p, Vector((1, 0, 0)), Vector((0, 0, 1)), r, r) for p, r in body], col, section=14)
            core = loft(f"EngineCore_{suffix}", [(p, Vector((1, 0, 0)), Vector((0, 0, 1)), r * 0.55, r * 0.55) for p, r in body[2:-2]], col, section=10)
            pods += [pod, core]
            anchors["Exhaust_" + suffix] = to_roblox(centre + Vector((0, -0.55, 0)))
        anchors["Seat"] = to_roblox(Vector((0, 0.25, 0)))
        anchors["Footrest"] = to_roblox(Vector((0, 1.8, 0.44)))
        anchors["HandlebarGrip"] = to_roblox(Vector((0, 1.22, 1.1)))

        palette = {"#3B2466": [hull], "#DDA84D": trims + [hook, handlebar, footrest, tail] + ribs,
                   "#FFB347": [seat, back], "#7A55C8": wings, "#61EFBD": pods}
        for hex_color, objs in palette.items():
            mat = glossy_preview_material("GC_Preview_" + hex_color.lstrip("#"), hex_color)
            for o in objs:
                o.data.materials.clear()
                o.data.materials.append(mat)
        objects = [hull, *trims, hook, seat, back, handlebar, footrest, tail, *wings, *ribs, *pods]
        for o in objects:
            o.modifiers.new("Triangulate", "TRIANGULATE")
        bpy.context.view_layer.update()
        os.makedirs(folder, exist_ok=True)
        export_fbx(objects, fbx)
        render_icon(objects, os.path.join(folder, "moonlantern_carriage_review.png"), size=768, samples=40)
        with open(os.path.join(folder, "anchors.json"), "w", encoding="utf-8") as f:
            json.dump(anchors, f, indent=2)
        bpy.data.libraries.write(os.path.join(folder, "hollowlight_v4.blend"), {scene}, fake_user=True, compress=True)
        depsgraph = bpy.context.evaluated_depsgraph_get()
        tris = {}
        for o in objects:
            m = o.evaluated_get(depsgraph).to_mesh()
            tris[o.name] = sum(len(p.vertices) - 2 for p in m.polygons)
            o.evaluated_get(depsgraph).to_mesh_clear()
        return {"fbx": fbx, "tris": sum(tris.values()), "by_part": tris, "anchors": anchors}
    finally:
        window.scene = previous


result = build_lantern_carriage()
