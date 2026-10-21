"""Maps in-game MeshIds to the repo FBX objects they were imported from (assets/icons/items/source/mesh_map.json).

    python3 tools/icons/match_meshes.py <fingerprints.json> <fbx_index.json>

fingerprints.json: tools/studio/dump_portraits.luau MODE = "fingerprints" ({id: [verts, tris, dx, dy, dz (cm), ...,
name]}); fbx_index.json: tools/blender/index_fbx_meshes.py. A mesh matches on triangle count and bounds (Roblox
(x, y, z) = Blender (x, z, y), centimetres -> studs); ties prefer the object named like the part and the newest
version folder. Meshes EditableMesh can't open match by name and proportions.
"""
import collections
import json
import os
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
fingerprints = json.load(open(sys.argv[1]))
index = json.load(open(sys.argv[2]))
items = json.load(open(os.path.join(REPO, "assets/icons/items/source/portraits.json")))["items"]
parts = {}
for item in items:
    for part in item["parts"]:
        if part.get("mesh"):
            parts.setdefault(part["mesh"], part)
by_tris = collections.defaultdict(list)
for entry in index:
    by_tris[entry["tris"]].append(entry)


def preference(entry, name):
    score = -10 if name.lower() in entry["object"].lower() else 0
    for i, tag in enumerate(("v5", "v4", "v3", "release_v2")):
        if f"/{tag}/" in entry["file"] or f"_{tag}" in entry["file"]:
            return score - (4 - i)
    return score


mapping, missing = {}, []
for mesh_id, part in parts.items():
    fp = fingerprints.get(mesh_id)
    if fp and fp[0] != "fail":
        dims = [fp[2] / 100, fp[3] / 100, fp[4] / 100]
        scale = max(max(dims), 1e-3)
        found = [
            (preference(e, part["name"]), e)
            for e in by_tris.get(fp[1], [])
            if sum(abs(a - b) for a, b in zip((e["dims"][0], e["dims"][2], e["dims"][1]), dims)) / scale < 0.01
        ]
    else:
        size = part["size"]
        ratio = [s / max(size) for s in size]
        found = []
        for e in index:
            if part["name"].lower() in e["object"].lower():
                d = (e["dims"][0], e["dims"][2], e["dims"][1])
                if max(d) > 0 and sum(abs(a / max(d) - b) for a, b in zip(d, ratio)) < 0.05:
                    found.append((preference(e, part["name"]), e))
    found.sort(key=lambda f: f[0])
    if found:
        mapping[mesh_id] = {"file": found[0][1]["file"], "object": found[0][1]["object"]}
    else:
        missing.append((mesh_id, part["name"]))
json.dump(mapping, open(os.path.join(REPO, "assets/icons/items/source/mesh_map.json"), "w"), indent=0, sort_keys=True)
print(len(mapping), "mapped;", len(missing), "missing", missing[:10])
