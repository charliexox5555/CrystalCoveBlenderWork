"""Renders item icons (glassies, flyers, finishers, crate machines) that match their in-game portraits.

Studio side: tools/studio/dump_portraits.luau builds each portrait exactly as the game does (GlassyPortrait /
CosmeticPortrait / ItemPresentation.crate) and returns its parts, colours, materials and camera; it also fingerprints
every MeshId (EditableMesh triangle count and bounds), and tools/blender/index_fbx_meshes.py indexes the repo FBX
exports so each MeshId maps to the FBX object it was imported from (mesh_map.json in the dump folder). This script
rebuilds the parts from those FBX objects and renders them through the shared icon rig (`render_icon`: key / rim /
fill lights, transparent background) with the game's own portrait camera, so angle, framing and tint match the
ViewportFrames they replace (docs/testing/viewports/AUDIT.md).

Run headless so an open Blender session is never touched:
    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P tools/blender/item_icons.py -- \
        --dump assets/icons/items/source --out assets/icons/items/1024 --size 1024 --samples 64 [--keys glassies_pop ...]
Then tools/icons/make_small.sh downsizes to assets/icons/items/512.
"""

import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
GLASSCLASH_REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
exec(open(os.path.join(HERE, "glassclash_blender.py")).read())

# Look, tuned against Studio captures of the live portraits (docs/testing/viewports/captures): portraits light
# items with a bright, slightly blue ambient (ViewportFrame.Ambient ~ #C3D3E6), so glass reads pale and bright.
LOOK = {
    "glass_alpha": 0.5,  # alpha = 1 - Transparency * this
    "glass_emission": 0.3,
    "neon_emission": 1.0,
    "world_strength": 1.2,
    "world_color": (0.62, 0.70, 0.80),
}

# Roblox (x, y, z) with Y up and -Z forward -> Blender (x, -z, y) with Z up.
TO_BLENDER = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def roblox_matrix(components):
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = components
    rot = TO_BLENDER @ Matrix(((r00, r01, r02), (r10, r11, r12), (r20, r21, r22)))
    m = rot.to_4x4()
    m.translation = TO_BLENDER @ Vector((x, y, z))
    return m


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def colour(hex_color):
    h = hex_color.lstrip("#")
    return tuple(srgb_to_linear(int(h[i : i + 2], 16) / 255) for i in (0, 2, 4))


_materials = {}


def material(part):
    """Studio look in Cycles: tinted see-through glass, glowing Neon, soft plastic. Same colour as in Studio."""
    key = (part["mat"], part["color"], round(part["tr"], 2), round(part.get("refl", 0), 2))
    if key in _materials:
        return _materials[key]
    mat = bpy.data.materials.new("GC_Item_" + "_".join(map(str, key)))
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    rgb = colour(part["color"])
    kind, transparency = part["mat"], part["tr"]
    _set_input(bsdf, "Base Color", (*rgb, 1.0))
    alpha = 1.0 - transparency
    if kind == "Neon":
        _set_input(bsdf, ["Emission Color", "Emission"], (*rgb, 1.0))
        _set_input(bsdf, "Emission Strength", LOOK["neon_emission"])
        _set_input(bsdf, "Roughness", 0.5)
    elif kind in ("Glass", "Ice", "ForceField"):
        # Roblox Glass in a ViewportFrame reads as a tinted, glossy, see-through shell: keep the tint strong
        # (no refraction darkening) and add the glossy coat that makes the icon nicer than the viewport.
        _set_input(bsdf, "Roughness", 0.08)
        _set_input(bsdf, ["Coat Weight", "Clearcoat"], 0.6)
        _set_input(bsdf, ["Coat Roughness", "Clearcoat Roughness"], 0.03)
        _set_input(bsdf, ["Specular IOR Level", "Specular"], 0.7)
        _set_input(bsdf, ["Emission Color", "Emission"], (*rgb, 1.0))
        _set_input(bsdf, "Emission Strength", LOOK["glass_emission"])
        alpha = 1.0 - transparency * LOOK["glass_alpha"]
    elif kind in ("Metal", "DiamondPlate", "Foil", "CorrodedMetal"):
        _set_input(bsdf, "Metallic", 0.85)
        _set_input(bsdf, "Roughness", 0.3)
    else:
        _set_input(bsdf, "Roughness", 0.45 if kind == "SmoothPlastic" else 0.6)
        _set_input(bsdf, ["Specular IOR Level", "Specular"], 0.4)
    if part.get("refl", 0) > 0:
        _set_input(bsdf, ["Coat Weight", "Clearcoat"], max(0.3, part["refl"] * 2))
    _set_input(bsdf, "Alpha", max(0.05, min(1.0, alpha)))
    try:
        mat.blend_method = "BLEND"
    except Exception:
        pass
    _materials[key] = mat
    return mat


def part_matrix(components):
    """World matrix for geometry built in Blender axes around a part's centre."""
    return roblox_matrix(components) @ TO_BLENDER.to_4x4().inverted()


# In-game MeshIds -> the repo FBX object they were imported from (matched by triangle count and bounds:
# tools/studio/dump_portraits.luau fingerprints, tools/blender/index_fbx_meshes.py index).
_mesh_map = {}
_library = {}


def library_object(file, name):
    """Imports an FBX once and keeps its objects out of the scene, renamed so later imports can't clash."""
    if file not in _library:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=os.path.join(GLASSCLASH_REPO, file))
        found = {}
        for obj in [o for o in bpy.data.objects if o not in before]:
            original = obj.name
            obj.name = f"LIB|{file}|{original}"
            for c in list(obj.users_collection):
                c.objects.unlink(obj)
            found[original] = obj
        _library[file] = found
    return _library[file].get(name)


def build_mesh_part(dump, part, collection):
    entry = _mesh_map.get(part["mesh"])
    source = entry and library_object(entry["file"], entry["object"])
    if source is None or source.type != "MESH":
        return None
    mesh = source.data.copy()
    mesh.transform(source.matrix_world)
    lo = [min(v.co[i] for v in mesh.vertices) for i in range(3)]
    hi = [max(v.co[i] for v in mesh.vertices) for i in range(3)]
    centre = Vector([(lo[i] + hi[i]) / 2 for i in range(3)])
    sx, sy, sz = part["size"]  # Roblox axes; Blender local axes are (x, -z, y)
    target = (sx, sz, sy)
    scale = [target[i] / (hi[i] - lo[i]) if hi[i] - lo[i] > 1e-6 else 1.0 for i in range(3)]
    # Re-imported FBX depth runs opposite to the Roblox mesh's Z (checked on Glass Dragon: belly plates face front in
    # Studio), so mirror Blender Y and flip the faces back.
    mesh.transform(Matrix.Diagonal((scale[0], -scale[1], scale[2], 1.0)) @ Matrix.Translation(-centre))
    mesh.flip_normals()
    if part.get("mirrorX"):
        # Asymmetric meshes from the headless daily_glassies builder (Midnight's crescent) came out left-right mirrored
        # against Studio with the transform above; portraits.json marks their parts, checked by a Studio capture.
        mesh.transform(Matrix.Diagonal((-1.0, 1.0, 1.0, 1.0)))
        mesh.flip_normals()
    mesh.name = part["name"]
    obj = bpy.data.objects.new(part["name"], mesh)
    obj.matrix_world = part_matrix(part["cf"])
    collection.objects.link(obj)
    return obj


def build_primitive(part, collection):
    sx, sy, sz = part["size"]
    shape = part.get("shape", "Block")
    special = part.get("special")
    if special:
        k = special["type"]
        sx, sy, sz = (sx * special["scale"][0], sy * special["scale"][1], sz * special["scale"][2])
        shape = {"Sphere": "Ball", "Brick": "Block", "Cylinder": "Cylinder"}.get(k, shape)
        if k == "FileMesh":
            return None
    if part["cls"] == "WedgePart":
        shape = "Wedge"
    if shape == "Ball":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=0.5)
        obj = bpy.context.active_object
        obj.scale = (sx, sz, sy) if special else (min(sx, sy, sz),) * 3
        bpy.ops.object.shade_smooth()
    elif shape == "Cylinder":
        bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.5, depth=1)
        obj = bpy.context.active_object
        # Roblox cylinders run along X; Blender's along Z.
        obj.rotation_euler = (0, math.pi / 2, 0)
        r = min(sy, sz)
        obj.scale = (r, r, sx)
    elif shape == "Wedge":
        mesh = bpy.data.meshes.new(part["name"])
        hx, hy, hz = sx / 2, sy / 2, sz / 2
        # Roblox wedge: full bottom, full-height back face at +Z, slope down to the front (-Z) bottom edge.
        v = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz), (-hx, hy, hz), (hx, hy, hz)]
        mesh.from_pydata([TO_BLENDER @ Vector(p) for p in v], [],
                         [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)])
        obj = bpy.data.objects.new(part["name"], mesh)
        bpy.context.scene.collection.objects.link(obj)
    else:
        bpy.ops.mesh.primitive_cube_add(size=1)
        obj = bpy.context.active_object
        obj.scale = (sx, sz, sy)
    if shape != "Wedge":
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    for c in obj.users_collection:
        c.objects.unlink(obj)
    collection.objects.link(obj)
    obj.name = part["name"]
    world = part_matrix(part["cf"])
    if special and any(special.get("offset", (0, 0, 0))):
        world = world @ Matrix.Translation(TO_BLENDER @ Vector(special["offset"]))
    obj.matrix_world = world
    return obj


_items = {}


def render_item(dump, key, out_path, size, samples):
    item = _items[key]
    collection = bpy.data.collections.new("GC_Item_" + key)
    bpy.context.scene.collection.children.link(collection)
    objects, skipped = [], []
    for part in item["parts"]:
        obj = build_mesh_part(dump, part, collection) if part.get("mesh") else build_primitive(part, collection)
        if obj is None:
            skipped.append(part["name"])
            continue
        obj.data.materials.clear()
        obj.data.materials.append(material(part))
        objects.append(obj)
    camera = (roblox_matrix(item["camera"]), math.radians(item["fov"]))
    render_icon(objects, out_path, size=size, samples=samples, camera=camera, world_strength=LOOK["world_strength"],
                view_transform="Standard", world_color=LOOK["world_color"])
    for obj in objects:
        mesh = obj.data
        bpy.data.objects.remove(obj, do_unlink=True)
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    bpy.data.collections.remove(collection)
    return {"key": key, "parts": len(objects), "skipped": skipped}


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    args = {"--size": "512", "--samples": "64", "--keys": []}
    flag = None
    for token in argv:
        if token.startswith("--"):
            flag = token
            if flag == "--keys":
                args["--keys"] = []
        elif flag == "--keys":
            args["--keys"].append(token)
        else:
            args[flag] = token
    # --dump: assets/icons/items/source (portraits.json + mesh_map.json) or a folder of split item_*.json files.
    dump, out = args["--dump"], args["--out"]
    with open(os.path.join(dump, "mesh_map.json")) as f:
        _mesh_map.update(json.load(f))
    combined = os.path.join(dump, "portraits.json")
    if os.path.exists(combined):
        with open(combined) as f:
            _items.update({item["key"]: item for item in json.load(f)["items"]})
    for name in os.listdir(dump):
        if name.startswith("item_") and name.endswith(".json"):
            with open(os.path.join(dump, name)) as f:
                item = json.load(f)
                _items[item["key"]] = item
    keys = args["--keys"] or sorted(_items)
    size, samples = int(args["--size"]), int(args["--samples"])
    scene = bpy.context.scene
    for obj in list(scene.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    scene.render.film_transparent = True
    scene.cycles.film_transparent_glass = True if hasattr(scene.cycles, "film_transparent_glass") else None
    try:
        scene.cycles.device = "GPU"
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
    except Exception:
        pass
    report = []
    for key in keys:
        path = os.path.join(out, f"{key}.png")
        try:
            report.append(render_item(dump, key, path, size, samples))
        except Exception as error:  # keep going; the report lists failures
            report.append({"key": key, "error": repr(error)})
        print("ITEM_ICON", json.dumps(report[-1]), flush=True)


main()
