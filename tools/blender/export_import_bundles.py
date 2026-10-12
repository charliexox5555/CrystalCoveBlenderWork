"""Run through the Blender MCP after loading glassclash_blender.py.

Package the approved, saved art into four multi-mesh FBX imports. Source files
are read only; temporary appended scenes are removed after exporting.
"""

import json


def export_import_bundles():
    output = repo_path("assets", "blender", "import")
    os.makedirs(output, exist_ok=True)
    sources = {
        "clash_stand": repo_path("assets", "blender", "map", "clash_stand.blend"),
        **{gid: repo_path("assets", "blender", "glassies", gid, f"{gid}.blend")
           for gid in ("pop", "jam", "prism")},
    }
    original_scene = bpy.context.window.scene
    manifest = {}
    try:
        for asset, source in sources.items():
            with bpy.data.libraries.load(source, link=False) as (available, loaded):
                loaded.scenes = available.scenes
            assert len(loaded.scenes) == 1, f"Expected one asset scene: {source}"
            scene = loaded.scenes[0]
            bpy.context.window.scene = scene
            objects = list(scene.objects)
            meshes = [obj for obj in objects if obj.type == "MESH"]
            entries = []
            try:
                with bpy.context.temp_override(scene=scene, view_layer=scene.view_layers[0]):
                    for obj in meshes:
                        # Appending can add a numeric suffix because names are global.
                        canonical = re.sub(r"\.\d+$", "", obj.name)
                        obj.name = f"M1_{asset}_{canonical}"
                        obj["source_name"] = canonical
                        if asset != "clash_stand":
                            role = ("Shard" if canonical.startswith("Shard_") else
                                    "Body" if canonical == "Body" else "Detail")
                            obj["asset_role"] = role
                            obj["glassy_id"] = asset
                        entries.append({
                            "name": obj.name,
                            "source_name": canonical,
                            "role": obj.get("asset_role", "Stand"),
                            "origin": list(obj.location),
                            "bounds": [list(obj.matrix_world @ Vector(v)) for v in obj.bound_box],
                            "studio_color": obj.get("studio_color"),
                            "studio_material": obj.get("studio_material"),
                        })
                    if asset != "clash_stand":
                        assert sum(e["role"] == "Body" for e in entries) == 1
                        assert sum(e["role"] == "Shard" for e in entries) == 16
                        assert all(obj.location.length < 1e-5 for obj in meshes)
                    filename = f"M1_{asset}.fbx"
                    export_fbx(meshes, os.path.join(output, filename))
                    manifest[asset] = {"file": filename, "meshes": entries}
            finally:
                bpy.context.window.scene = original_scene
                for obj in objects:
                    bpy.data.objects.remove(obj, do_unlink=True)
                bpy.data.scenes.remove(scene)
    finally:
        bpy.context.window.scene = original_scene
    with open(os.path.join(output, "manifest.json"), "w", encoding="utf-8") as file:
        json.dump(manifest, file, indent=2)
        file.write("\n")
    return {asset: {"file": item["file"], "meshes": len(item["meshes"])}
            for asset, item in manifest.items()}


result = export_import_bundles()
