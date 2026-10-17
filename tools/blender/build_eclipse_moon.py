"""Hollowlight v3: the glass crescent moon for the reworked Lantern Eclipse finisher.

Run through Blender MCP after loading glassclash_blender.py and set_repo(). Builds in its own scene
(the open file and the v2 package are untouched), then writes
assets/blender/seasonal/hollowlight_v3/{eclipse_moon.fbx, hollowlight_v3.blend, eclipse_moon_review.png}.
1 BU = 1 stud. The crescent stands in Blender's X-Z plane facing -Y (Roblox +Z), origin at its centre.
Refuses to overwrite an existing export so revisions stay preserved.
"""
import math
import os
import bmesh
import bpy

HEIGHT = 3.4  # studs, tip to tip
THICKNESS = 0.42
RIM_OUTSET = 0.07
RIM_THICKNESS = 0.2
OUTLINE_POINTS = 56


def crescent_outline(radius, inner_radius, inner_offset, points):
    """Outer arc then inner arc (both in X-Z), counter-clockwise, as one closed loop."""
    # Tips sit where the two circles intersect.
    x = (radius**2 - inner_radius**2 + inner_offset**2) / (2 * inner_offset)
    tip = math.acos(max(-1.0, min(1.0, x / radius)))
    outer = [
        (radius * math.cos(a), radius * math.sin(a))
        for a in (tip + (2 * math.pi - 2 * tip) * i / points for i in range(points + 1))
    ]
    inner_tip = math.atan2(radius * math.sin(tip), x - inner_offset)
    # Back along the inner circle's left side (the part inside the outer circle), lower tip to upper.
    sweep = 2 * math.pi - 2 * inner_tip
    inner = [
        (inner_offset + inner_radius * math.cos(a), inner_radius * math.sin(a))
        for a in (2 * math.pi - inner_tip - sweep * i / points for i in range(1, points))
    ]
    return outer + inner


def slab(name, outline, thickness, bevel, collection):
    bm = bmesh.new()
    verts = [bm.verts.new((x, -thickness / 2, z)) for x, z in outline]
    face = bm.faces.new(verts)
    extruded = bmesh.ops.extrude_face_region(bm, geom=[face])
    moved = [g for g in extruded["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=moved, vec=(0, thickness, 0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width, mod.segments, mod.limit_method = bevel, 3, "ANGLE"
    tri = obj.modifiers.new("Triangulate", "TRIANGULATE")
    tri.keep_custom_normals = True
    for poly in mesh.polygons:
        poly.use_smooth = True
    return obj


def build_eclipse_moon():
    folder = repo_path("assets", "blender", "seasonal", "hollowlight_v3")
    fbx = os.path.join(folder, "eclipse_moon.fbx")
    if os.path.exists(fbx):
        raise RuntimeError("hollowlight_v3 export exists; make a new revision instead of overwriting")
    window = bpy.context.window
    previous = window.scene
    scene = bpy.data.scenes.new("HollowlightV3_EclipseMoon")
    scene.unit_settings.system = "METRIC"
    window.scene = scene
    try:
        radius = HEIGHT / 2
        outline = crescent_outline(radius, radius * 0.86, radius * 0.62, OUTLINE_POINTS)
        rim_outline = crescent_outline(radius + RIM_OUTSET, radius * 0.86 - RIM_OUTSET, radius * 0.62, OUTLINE_POINTS)
        glass = slab("EclipseMoon_Glass", outline, THICKNESS, 0.09, scene.collection)
        rim = slab("EclipseMoon_Rim", rim_outline, RIM_THICKNESS, 0.05, scene.collection)
        glass.data.materials.append(glossy_preview_material("GC_Preview_MoonGlass", "#F4EBC8"))
        rim.data.materials.append(glossy_preview_material("GC_Preview_MoonRim", "#DDA84D"))
        # Centre the pair on the crescent's bounding box so Roblox pivots sit in the middle.
        bpy.context.view_layer.update()
        xs = [(glass.matrix_world @ v.co).x for v in glass.data.vertices]
        shift = -(min(xs) + max(xs)) / 2
        for obj in (glass, rim):
            obj.location.x = shift
        bpy.context.view_layer.update()
        os.makedirs(folder, exist_ok=True)
        export_fbx([glass, rim], fbx)
        render_icon([glass, rim], os.path.join(folder, "eclipse_moon_review.png"), size=512, samples=32)
        bpy.data.libraries.write(os.path.join(folder, "hollowlight_v3.blend"), {scene}, fake_user=True, compress=True)
        depsgraph = bpy.context.evaluated_depsgraph_get()
        tris = 0
        for obj in (glass, rim):
            evaluated = obj.evaluated_get(depsgraph).to_mesh()
            tris += sum(len(p.vertices) - 2 for p in evaluated.polygons)
            obj.evaluated_get(depsgraph).to_mesh_clear()
        return {"fbx": fbx, "tris": tris, "width": max(xs) - min(xs), "height": HEIGHT}
    finally:
        window.scene = previous


result = build_eclipse_moon()
