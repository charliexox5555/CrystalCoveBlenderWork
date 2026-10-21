"""Writes the Small / Large tables of src/shared/Config/ItemIcons.luau from the upload record and the decal -> image
map (Decal asset ids resolve to image ids in Studio: InsertService:LoadAsset(id) -> Decal.Texture).

    python3 tools/icons/write_config.py assets/icons/items/image_ids.json

image_ids.json: {"<decal asset id>": "<image asset id>"}. Keys in the record look like "512/glassies_pop".
"""
import json
import os
import re
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CATEGORIES = {"glassies": "Glassies", "rideables": "Rideables", "finishers": "Finishers", "machines": "Machines"}

record = {}
for name in ("roblox_assets.json", "roblox_assets_1024.json"):
    path = os.path.join(REPO, "assets/icons/items", name)
    if os.path.exists(path):
        record.update(json.load(open(path))["Assets"])
images = json.load(open(sys.argv[1]))
tables = {"Small": {c: {} for c in CATEGORIES.values()}, "Large": {c: {} for c in CATEGORIES.values()}}
for key, entry in record.items():
    size, name = key.split("/", 1)
    prefix, item = name.split("_", 1)
    category = CATEGORIES[prefix]
    if category == "Machines":
        item = item.replace("_", ":", 1)
    image = images.get(str(entry["AssetId"]))
    if not image:
        print("no image id for", key)
        continue
    tables["Small" if size == "512" else "Large"][category][item] = f"rbxassetid://{image}"


def block(name):
    lines = [f"ItemIcons.{name} = {{"]
    for category in CATEGORIES.values():
        lines.append(f"\t{category} = {{")
        for item, image in sorted(tables[name][category].items()):
            lines.append(f'\t\t["{item}"] = "{image}",')
        lines.append("\t},")
    lines.append("} :: Set")
    return "\n".join(lines)


path = os.path.join(REPO, "src/shared/Config/ItemIcons.luau")
source = open(path).read()
for name in ("Small", "Large"):
    source = re.sub(rf"ItemIcons\.{name} = \{{.*?\n\}} :: Set", lambda _: block(name), source, count=1, flags=re.S)
open(path, "w").write(source)
print({n: {c: len(v) for c, v in t.items()} for n, t in tables.items()})
