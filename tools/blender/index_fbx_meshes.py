"""Indexes every mesh in the repo's FBX exports (triangles, vertices, bounds) so in-game MeshIds can be matched back
to their source geometry (tools/blender/item_icons.py). Headless:
    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P tools/blender/index_fbx_meshes.py -- <out.json>
"""
import json
import os
import sys

import bpy

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
out_path = sys.argv[sys.argv.index("--") + 1]
index = []
files = []
for root, _, names in os.walk(os.path.join(REPO, "assets", "blender")):
    for name in names:
        if name.lower().endswith(".fbx") and "shard" not in name.lower() and "/backups" not in root:
            files.append(os.path.join(root, name))
files.sort()
for path in files:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    try:
        bpy.ops.import_scene.fbx(filepath=path)
    except Exception as error:
        print("FAIL", path, error, flush=True)
        continue
    bpy.context.view_layer.update()
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        mesh = obj.data
        tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
        corners = [obj.matrix_world @ v.co for v in mesh.vertices]
        if not corners:
            continue
        lo = [min(c[i] for c in corners) for i in range(3)]
        hi = [max(c[i] for c in corners) for i in range(3)]
        index.append({
            "file": os.path.relpath(path, REPO),
            "object": obj.name,
            "tris": tris,
            "verts": len(mesh.vertices),
            "dims": [round(hi[i] - lo[i], 4) for i in range(3)],
        })
    print("OK", os.path.relpath(path, REPO), flush=True)
with open(out_path, "w") as f:
    json.dump(index, f)
print("INDEXED", len(index), "meshes from", len(files), "files")
