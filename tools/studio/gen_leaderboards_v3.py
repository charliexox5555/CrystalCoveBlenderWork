"""Generates tools/studio/install_leaderboards_v3.luau from the template, the Blender manifest and the uploaded asset
ids (assets/blender/map/leaderboards_v3/{manifest,roblox_assets}.json).

    python3 tools/studio/gen_leaderboards_v3.py
"""
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DIR = os.path.join(ROOT, "assets", "blender", "map", "leaderboards_v3")
manifest = json.load(open(os.path.join(DIR, "manifest.json")))
assets = json.load(open(os.path.join(DIR, "roblox_assets.json")))["Assets"]
# Mirrors src/shared/Config/Leaderboards.luau (LeaderboardService rewrites the texts at runtime anyway).
BOARDS = [
    ("WeeklySpend", "Left", "RobuxWeek", "Robux", "TOP SUPPORTERS", "THIS WEEK", "Be this week's first supporter!", "9BF3F8", "0F7C88"),
    ("Wins", "Middle", "MatchWins", "Number", "TOTAL WINS", "ALL TIME", "Clash to make the board!", "FFD98A", "B26E0B"),
    ("AllTimeSpend", "Right", "RobuxTotal", "Robux", "TOP SUPPORTERS", "ALL TIME", "Be the first supporter!", "CDAAFF", "57299F"),
]
data = {"Boards": []}
for bid, slot, stat, fmt, title, subtitle, empty, light, dark in BOARDS:
    m = manifest["Boards"][bid]
    data["Boards"].append({
        "Id": bid, "Slot": slot, "Stat": stat, "Format": fmt, "Title": title, "Subtitle": subtitle, "Empty": empty,
        "AccentLight": light, "AccentDark": dark, "Accent": m["Accent"], "Scale": m["Scale"],
        "AssetId": int(assets[bid]["AssetId"]), "Screen": m["Screen"], "Title_": None,
        # Emblems stay solid (glass made them read as muddy rings); the builder does the same on a rebuild.
        "Meshes": [{"Name": e["Name"], "Color": e["Color"],
                    "Material": "SmoothPlastic" if "_Emblem" in e["Name"] else e["Material"],
                    "Transparency": 0 if "_Emblem" in e["Name"] else e["Transparency"]} for e in m["Meshes"]],
    })
    data["Boards"][-1]["Title"] = title
    data["Boards"][-1]["TitleRect"] = m["Title"]
    del data["Boards"][-1]["Title_"]
template = open(os.path.join(ROOT, "tools", "studio", "install_leaderboards_v3.template.luau")).read()
out = template.replace("__DATA__", json.dumps(data, separators=(",", ":")))
open(os.path.join(ROOT, "tools", "studio", "install_leaderboards_v3.luau"), "w").write(out)
print("boards:", len(data["Boards"]), "bytes:", len(out))
