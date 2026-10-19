"""Writes the uploaded rider animation ids into src/shared/Config/RideFamilies.luau.

    python3 tools/write_ride_animation_ids.py

Reads assets/animations/rider/roblox_assets.json (written by tools/opencloud/upload_assets.py) and replaces the
block between "-- BEGIN ANIMATION IDS" and "-- END ANIMATION IDS". Keys are <Family>_<Clip>_<Rig>.
"""
import json
import os
import re

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RECORD = os.path.join(REPO, "assets", "animations", "rider", "roblox_assets.json")
CONFIG = os.path.join(REPO, "src", "shared", "Config", "RideFamilies.luau")
CLIPS = ["Idle", "LeanLeft", "LeanRight", "Launch", "Land"]

assets = json.load(open(RECORD))["Assets"]
ids = {}
for key, info in assets.items():
    family, clip, rig = key.split("_")
    ids.setdefault(family, {}).setdefault(clip, {})[rig] = "rbxassetid://" + str(info["AssetId"])
lines = ["F.AnimationIds = {"]
for family in sorted(ids):
    lines.append("\t%s = {" % family)
    for clip in CLIPS:
        rigs = ids[family].get(clip)
        if rigs:
            inner = ", ".join('%s = "%s"' % (rig, rigs[rig]) for rig in ("R15", "R6") if rig in rigs)
            lines.append("\t\t%s = { %s }," % (clip, inner))
    lines.append("\t},")
lines.append("}")
text = open(CONFIG).read()
text = re.sub(r"-- BEGIN ANIMATION IDS\n.*?\n-- END ANIMATION IDS",
              "-- BEGIN ANIMATION IDS\n" + "\n".join(lines) + "\n-- END ANIMATION IDS", text, flags=re.S)
open(CONFIG, "w").write(text)
print("ids for", sum(len(c) for f in ids.values() for c in f.values()), "assets")
