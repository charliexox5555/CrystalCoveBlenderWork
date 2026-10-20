"""Lobby decor kit (map polish, 2026-10-20): a few faceted low-poly props for the sky islands.

Run inside Blender through the Blender MCP after loading the helper:
    exec(open("<repo>/tools/blender/glassclash_blender.py").read())
    exec(open("<repo>/tools/blender/map_decor_kit.py").read()); build_all()

Builds in its own scene ("MapDecorKit") so whatever is open stays untouched, writes
assets/blender/map/decor_kit/decor_kit.blend plus one FBX per prop, then switches back to the scene that was active.

Every prop: origin at the ground centre (Blender Z up; Roblox Y up after export), flat shading, one mesh per colour
so Studio can colour them (ART_BIBLE 1). 1 Blender unit = 1 stud. Sizes are toy-like next to a 5-stud avatar.
"""
import math
import os
import random

import bmesh
import bpy

KIT_SCENE = "MapDecorKit"
OUT = None  # set in build_all from repo_path


def _scene():
    scene = bpy.data.scenes.get(KIT_SCENE) or bpy.data.scenes.new(KIT_SCENE)
    return scene


def _new_object(scene, name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = False
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    return obj


def _jitter(bm, rng, amount, keep_bottom=None):
    for v in bm.verts:
        if keep_bottom is not None and v.co.z <= keep_bottom + 1e-4:
            continue
        v.co.x += rng.uniform(-amount, amount)
        v.co.y += rng.uniform(-amount, amount)
        v.co.z += rng.uniform(-amount, amount) * 0.6


def _ico(bm, radius, center, scale=(1, 1, 1), subdiv=1):
    geom = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    for v in geom["verts"]:
        v.co.x = v.co.x * scale[0] + center[0]
        v.co.y = v.co.y * scale[1] + center[1]
        v.co.z = v.co.z * scale[2] + center[2]
    return geom["verts"]


def _prism(bm, radius, height, sides, base=(0, 0, 0), top_radius=None):
    top_radius = radius if top_radius is None else top_radius
    geom = bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=sides, radius1=radius, radius2=top_radius, depth=height
    )
    for v in geom["verts"]:
        v.co.x += base[0]
        v.co.y += base[1]
        v.co.z += base[2] + height / 2
    return geom["verts"]


def tree_round(scene, seed=1):
    """Round-canopy tree, ~11 studs: a tapered 6-sided trunk and a canopy of three faceted blobs."""
    rng = random.Random(seed)
    bm = bmesh.new()
    _prism(bm, 0.95, 4.6, 6, top_radius=0.62)
    trunk = _new_object(scene, "Trunk", bm)
    bm = bmesh.new()
    for center, radius in (((0, 0, 7.0), 3.4), ((1.8, 0.7, 5.8), 2.4), ((-1.7, -0.8, 6.0), 2.5)):
        _ico(bm, radius, center, scale=(1, 1, 0.82), subdiv=2)
    _jitter(bm, rng, 0.22)
    canopy = _new_object(scene, "Canopy", bm)
    return [trunk, canopy]


def tree_pine(scene, seed=2):
    """Toy pine, ~10 studs: short trunk and three stacked 7-sided cones."""
    rng = random.Random(seed)
    bm = bmesh.new()
    _prism(bm, 0.55, 2.4, 6, top_radius=0.45)
    trunk = _new_object(scene, "Trunk", bm)
    bm = bmesh.new()
    for base, radius, height in ((1.6, 3.0, 3.6), (3.9, 2.4, 3.2), (6.0, 1.7, 3.6)):
        _prism(bm, radius, height, 7, base=(0, 0, base), top_radius=0.05)
    _jitter(bm, rng, 0.12)
    leaves = _new_object(scene, "Leaves", bm)
    return [trunk, leaves]


def bush(scene, seed=3):
    """Round bush, ~2.6 studs tall: two faceted blobs, base sunk slightly below ground."""
    rng = random.Random(seed)
    bm = bmesh.new()
    _ico(bm, 1.6, (0, 0, 1.1), scale=(1.15, 1, 0.85), subdiv=2)
    _ico(bm, 1.1, (1.3, 0.4, 0.8), scale=(1, 1, 0.85), subdiv=2)
    _jitter(bm, rng, 0.14)
    return [_new_object(scene, "Leaves", bm)]


def rock(scene, seed=4):
    """Chunky rock, ~2.8 x 1.4 studs, flat-bottomed."""
    rng = random.Random(seed)
    bm = bmesh.new()
    _ico(bm, 1.4, (0, 0, 0.55), scale=(1.1, 0.9, 0.62), subdiv=1)
    _jitter(bm, rng, 0.18)
    for v in bm.verts:
        v.co.z = max(v.co.z, -0.1)
    return [_new_object(scene, "Stone", bm)]


def flower_tuft(scene, seed=5):
    """Grass tuft with three little flowers, ~1.8 studs: Grass (blades and stems), Petals, Centers."""
    rng = random.Random(seed)
    bm = bmesh.new()
    for i in range(9):
        angle = i / 9 * math.tau + rng.uniform(-0.2, 0.2)
        r = rng.uniform(0.15, 0.5)
        x, y = math.cos(angle) * r, math.sin(angle) * r
        h = rng.uniform(0.7, 1.15)
        lean = 0.25
        # A thin tetrahedron per blade (closed, visible from every side).
        v1 = bm.verts.new((x - 0.09, y, 0))
        v2 = bm.verts.new((x + 0.09, y, 0))
        v4 = bm.verts.new((x, y + 0.07, 0))
        v3 = bm.verts.new((x + math.cos(angle) * lean, y + math.sin(angle) * lean, h))
        for face in ((v1, v2, v3), (v2, v4, v3), (v4, v1, v3), (v2, v1, v4)):
            bm.faces.new(face)
    flowers = []
    for i in range(3):
        angle = i / 3 * math.tau + 0.4
        x, y = math.cos(angle) * 0.45, math.sin(angle) * 0.45
        h = 1.25 + i * 0.18
        _prism(bm, 0.05, h, 4, base=(x, y, 0))
        flowers.append((x, y, h))
    grass = _new_object(scene, "Grass", bm)
    bm = bmesh.new()
    for x, y, h in flowers:
        _prism(bm, 0.36, 0.1, 6, base=(x, y, h - 0.02))  # flat six-petal disc
    petals = _new_object(scene, "Petals", bm)
    bm = bmesh.new()
    for x, y, h in flowers:
        _prism(bm, 0.14, 0.12, 5, base=(x, y, h + 0.04), top_radius=0.1)
    centers = _new_object(scene, "Centers", bm)
    return [grass, petals, centers]


PROPS = {
    "Decor_TreeRound": tree_round,
    "Decor_TreePine": tree_pine,
    "Decor_Bush": bush,
    "Decor_Rock": rock,
    "Decor_FlowerTuft": flower_tuft,
}


def _tris(objects):
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objects)


def build_all():
    global OUT
    OUT = repo_path("assets", "blender", "map", "decor_kit")
    os.makedirs(OUT, exist_ok=True)
    window = bpy.context.window
    previous = window.scene
    old = bpy.data.scenes.get(KIT_SCENE)
    if old:
        for obj in list(old.collection.all_objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.scenes.remove(old)
    scene = _scene()
    window.scene = scene
    report = {}
    try:
        offset = 0
        for name, builder in PROPS.items():
            objects = builder(scene)
            for obj in objects:
                obj["gc_prop"] = name
            export_fbx(objects, os.path.join(OUT, name + ".fbx"))
            # Spread them out in the review scene only (after export, so the FBX origins stay at zero), and free the
            # plain mesh names ("Trunk") for the next prop's export.
            for obj in objects:
                obj.location.x = offset
                obj.name = name + "_" + obj.name
            offset += 9
            report[name] = {"meshes": [o.name for o in objects], "tris": _tris(objects)}
        bpy.data.libraries.write(os.path.join(OUT, "decor_kit.blend"), {scene}, fake_user=True, compress=True)
    finally:
        window.scene = previous
    return report


PREVIEW_COLORS = {
    "Trunk": (0.45, 0.28, 0.16, 1),
    "Canopy": (0.36, 0.72, 0.30, 1),
    "Leaves": (0.25, 0.60, 0.35, 1),
    "Stone": (0.62, 0.60, 0.70, 1),
    "Grass": (0.40, 0.75, 0.30, 1),
    "Petals": (1.0, 0.55, 0.75, 1),
    "Centers": (1.0, 0.85, 0.3, 1),
}


def render_preview(path=None):
    """Workbench flat-colour render of the review row (object colours are preview only)."""
    path = path or os.path.join(repo_path("assets", "blender", "map", "decor_kit"), "decor_kit_preview.png")
    scene = bpy.data.scenes[KIT_SCENE]
    window = bpy.context.window
    previous = window.scene
    window.scene = scene
    try:
        for obj in scene.collection.all_objects:
            if obj.type == "MESH":
                obj.color = PREVIEW_COLORS.get(obj.name.split("_")[-1], (0.8, 0.8, 0.8, 1))
        cam_data = bpy.data.cameras.get("DecorKitCam") or bpy.data.cameras.new("DecorKitCam")
        cam = scene.objects.get("DecorKitCam") or bpy.data.objects.new("DecorKitCam", cam_data)
        if cam.name not in scene.collection.objects:
            scene.collection.objects.link(cam)
        cam.location = (18, -44, 11)
        cam.rotation_euler = (math.radians(80), 0, 0)
        cam_data.lens = 32
        scene.camera = cam
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "OBJECT"
        scene.render.resolution_x, scene.render.resolution_y = 1280, 640
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True, scene=scene.name)
    finally:
        window.scene = previous
    return path
