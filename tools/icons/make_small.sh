#!/bin/zsh
# Downsizes the 1024 px item icons to 512 px (macOS sips keeps the alpha) and writes the Open Cloud upload list.
#   tools/icons/make_small.sh            -> assets/icons/items/512/*.png + assets/icons/items/upload_list.json
cd "$(dirname "$0")/../.."
mkdir -p assets/icons/items/512
for f in assets/icons/items/1024/*.png; do
	sips -Z 512 "$f" --out "assets/icons/items/512/${f:t}" >/dev/null
done
python3 - <<'PY'
import json, os
# One list (and record) per size, so both can upload at the same time.
for size, suffix in (("512", ""), ("1024", "_1024")):
    items = []
    for name in sorted(os.listdir(f"assets/icons/items/{size}")):
        if name.endswith(".png"):
            key = name[:-4]
            items.append({"Key": f"{size}/{key}", "Path": f"assets/icons/items/{size}/{name}", "Type": "Decal",
                          "Name": f"GC icon {key} {size}"[:50]})
    json.dump({"Record": f"assets/icons/items/roblox_assets{suffix}.json", "Items": items},
              open(f"assets/icons/items/upload_list{suffix}.json", "w"), indent=1)
    print(len(items), f"items in upload_list{suffix}.json")
PY
