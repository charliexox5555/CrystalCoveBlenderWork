"""Collects the Daily Rewards glassies' manifests into Studio-facing files, reusing collect_launch.py's logic:

    python3 docs/art/daily_glassies/tools/collect_daily.py

- docs/art/daily_glassies/motion_manifest.json (read by tools/gen_glassy_motion.luau)
- docs/art/daily_glassies/daily_import_data.json ({"assets", "release_geometry"})
- prints the Config/ReleaseGeometry and Config/ReleaseCrackPaths rows to paste (cracks.json is already Roblox hang space).
"""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
src = (ROOT / "docs/art/launch_glassies/tools/collect_launch.py").read_text()
src = src.replace('OUT = ROOT / "docs/art/launch_glassies"', 'OUT = ROOT / "docs/art/daily_glassies"')
start = src.index("ORDER = [")
end = src.index("]", src.index('"glass_phoenix"')) + 1
src = src[:start] + 'ORDER = ["whiskers", "midnight_moon"]' + src[end:]
src = src.replace('"launch_import_data.json"', '"daily_import_data.json"').replace("launch glassies collected", "daily glassies collected")
exec(compile(src, "collect_launch.py (daily)", "exec"), {"__file__": str(ROOT / "docs/art/launch_glassies/tools/collect_launch.py"), "__name__": "collect_daily"})
for gid in ["whiskers", "midnight_moon"]:
    m = json.loads((ROOT / "assets/blender/glassies" / gid / "v4/manifest.json").read_text())
    g = m["release_geometry"]
    print("ReleaseGeometry: %s = { Radius = %.6f, Center = %.6f }," % (gid, g["Radius"], g["Center"]))
