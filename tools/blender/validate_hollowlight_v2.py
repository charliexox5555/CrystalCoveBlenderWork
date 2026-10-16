"""Finalize only our v2 face meshes, then verify and export the creator import package."""
import bpy, bmesh, ast, json, math, os
from mathutils import Vector, Matrix
from mathutils.geometry import tessellate_polygon

ROOT = r"C:/Users/charl/Documents/CrystalCoveBlenderWork"
GLASSCLASH_REPO = ROOT
exec(open(ROOT + "/tools/blender/glassclash_blender.py").read())
OUT = ROOT + "/assets/blender/seasonal/hollowlight_v2"
scene = bpy.data.scenes["Hollowlight_v2"]
manifest = json.load(open(OUT + "/manifest.json"))
groups = {k: [scene.objects[x["name"]] for x in g] for k, g in manifest["groups"].items()}
source = ast.parse(open(ROOT + "/tools/blender/finalize_hollowlight_v2.py").read())
definitions = ast.Module(body=[x for x in source.body if isinstance(x, ast.FunctionDef)], type_ignores=[])
exec(compile(definitions, "hollowlight_functions", "exec"))
old_scene = bpy.context.window.scene
old_filepath = bpy.data.filepath
try:
    bpy.context.window.scene = scene
    bpy.context.view_layer.update()
    body = scene.objects["HH2_Pumpkin_Body"]
    mouth = grin_outline()
    for name, outline, mat, offset in [
        ("HH2_Pumpkin_GrinEdge", enlarged(mouth, 1.12), bpy.data.materials["HH2_CarvedEdge"], .022),
        ("HH2_Pumpkin_Grin", mouth, bpy.data.materials["HH2_WispMint"], .032),
    ]:
        current = scene.objects[name]
        replacement = project_patch("HH2_RefineTemporary", outline, body, mat, "pumpkin", offset)
        current.data.use_fake_user = True
        current.data = replacement.data
        groups["pumpkin"].remove(replacement)
        bpy.data.objects.remove(replacement, do_unlink=True)
    mini = Matrix.Translation((0,0,1.05)) @ Matrix.Diagonal((.8,.8,.8,1)) @ Matrix.Translation((0,0,1.05))
    for mat_name in ["WispMint", "CarvedEdge"]:
        mat = bpy.data.materials["HH2_" + mat_name]
        parts = [o for o in groups["pumpkin"] if o.data.materials[0] == mat]
        current = scene.objects["HH2_Eclipse_Core_" + mat_name]
        replacement = merge_material_group(parts, "HH2_RefineTemporary", mat, "finisher", mini)
        current.data.use_fake_user = True
        current.data = replacement.data
        groups["finisher"].remove(replacement)
        bpy.data.objects.remove(replacement, do_unlink=True)
    objects = [o for g in groups.values() for o in g]
    for o in objects:
        bm = bmesh.new(); bm.from_mesh(o.data)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.normal_update()
        if all(len(e.link_faces) == 2 for e in bm.edges) and bm.calc_volume(signed=True) < 0:
            bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
        bm.to_mesh(o.data); bm.free(); o.data.update()
        assert max(abs(o.matrix_world[i][j] - (1 if i == j else 0)) for i in range(4) for j in range(4)) < 1e-6, o.name
        assert len(o.modifiers) == 0 and len(o.data.materials) == 1, o.name
        o["HollowlightKey"] = o.name
    bpy.context.view_layer.update()
    # Face-front triangle centers must stay outside the ribbed body, not clip through it.
    clearance = {}
    for name in ["HH2_Pumpkin_GrinEdge", "HH2_Pumpkin_Grin"]:
        o = scene.objects[name]; o.data.calc_loop_triangles(); samples = []
        for tri in o.data.loop_triangles:
            if tri.normal.y > -.25: continue
            center = sum((o.data.vertices[i].co for i in tri.vertices), Vector()) / 3
            hit, pos, normal, index = body.ray_cast(Vector((center.x,-6,center.z)), Vector((0,1,0)))
            assert hit, name
            samples.append(pos.y - center.y)
        clearance[name] = min(samples)
        assert min(samples) > .002, (name, min(samples))
    volumes = {}
    for o in [body] + groups["shards"]:
        bm = bmesh.new(); bm.from_mesh(o.data)
        assert all(len(e.link_faces) == 2 for e in bm.edges), o.name
        volume = bm.calc_volume(signed=True); bm.free()
        assert volume > 0, o.name
        volumes[o.name] = volume
    volume_error = abs(sum(volumes[o.name] for o in groups["shards"]) - volumes[body.name])
    assert volume_error < .0001, volume_error
    def bounds(o):
        coords = [o.matrix_world @ v.co for v in o.data.vertices]
        return [[float(min(v[a] for v in coords)) for a in range(3)], [float(max(v[a] for v in coords)) for a in range(3)]]
    def triangles(o): return sum(len(p.vertices)-2 for p in o.data.polygons)
    for k, g in groups.items():
        for entry, o in zip(manifest["groups"][k], g):
            entry.update(vertices=len(o.data.vertices), triangles=triangles(o), min=bounds(o)[0], max=bounds(o)[1])
    export_fbx(objects, OUT + "/HOLLOWLIGHT_V2_IMPORT.fbx")
    # Independent FBX reimport into an isolated scene. Custom IDs survive exporter axis conversion.
    temp = bpy.data.scenes.new("HH2_ImportValidation")
    imported = []
    try:
        bpy.context.window.scene = temp
        bpy.ops.import_scene.fbx(filepath=OUT + "/HOLLOWLIGHT_V2_IMPORT.fbx", use_custom_props=True)
        imported = list(temp.objects)
        actual = {o.get("HollowlightKey"): o for o in imported if o.type == "MESH"}
        assert set(actual) == {o.name for o in objects}, (len(actual), len(objects))
        errors = []
        for o in objects:
            other = actual[o.name]
            assert triangles(other) == triangles(o), o.name
            assert len(other.data.materials) == 1, o.name
            errors.extend(abs(a-b) for va,vb in zip(bounds(o),bounds(other)) for a,b in zip(va,vb))
            assert other.matrix_world.translation.length < 1e-5, o.name
        max_error = max(errors)
        assert max_error < .0001, max_error
    finally:
        bpy.context.window.scene = scene
        for o in list(temp.objects): bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.scenes.remove(temp)
    report = {"meshCount":len(objects), "groups":{k:len(g) for k,g in groups.items()},
              "triangles":sum(triangles(o) for o in objects), "largestMeshTriangles":max(triangles(o) for o in objects),
              "closedPositiveBodyAndShards":len(volumes), "shardVolumeError":volume_error,
              "faceMinimumClearanceStuds":clearance, "fbxRoundTripBoundsErrorStuds":max_error,
              "commonOriginAndAppliedTransforms":True, "oneMaterialPerMesh":True, "originalsPreserved":True,
              "sourceScene":"Hollowlight_v2", "studsPerUnit":1, "releaseCount":24,
              "studioImportPending":True, "runtimeVFXPending":True}
    json.dump(manifest, open(OUT + "/manifest.json", "w"), indent=2)
    json.dump(report, open(OUT + "/validation.json", "w"), indent=2)
    save_blend_copy(OUT + "/hollowlight_v2.blend")
    for k in ["pumpkin", "finisher"]:
        render_icon(groups[k], OUT + "/" + k + "_icon.png", size=512, samples=32, engine="BLENDER_EEVEE")
    rotation = math.atan(1/1.35)
    try:
        for o in groups["pumpkin"]: o.rotation_euler.z = rotation
        render_icon(groups["pumpkin"], OUT + "/pumpkin_front_review.png", size=512, samples=32, engine="BLENDER_EEVEE")
    finally:
        for o in groups["pumpkin"]: o.rotation_euler.z = 0
finally:
    bpy.context.window.scene = old_scene
    assert bpy.data.filepath == old_filepath
result = report
