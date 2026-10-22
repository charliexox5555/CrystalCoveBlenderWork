"""Collects the Starter Pack glassy' manifests into Studio-facing files, reusing collect_launch.py's logic:

    python3 docs/art/starter_pack/tools/collect_starter.py

- docs/art/starter_pack/motion_manifest.json (read by tools/gen_glassy_motion.luau)
- docs/art/starter_pack/starter_import_data.json ({"assets", "release_geometry"})
- prints the Config/ReleaseGeometry and Config/ReleaseCrackPaths rows to paste (cracks.json is already Roblox hang space).
"""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
src = (ROOT / "docs/art/launch_glassies/tools/collect_launch.py").read_text()
src = src.replace('OUT = ROOT / "docs/art/launch_glassies"', 'OUT = ROOT / "docs/art/starter_pack"')
start = src.index("ORDER = [")
end = src.index("]", src.index('"glass_phoenix"')) + 1
src = src[:start] + 'ORDER = ["sunny_rooster"]' + src[end:]
src = src.replace('"launch_import_data.json"', '"starter_import_data.json"').replace("launch glassies collected", "starter glassy collected")
exec(compile(src, "collect_launch.py (daily)", "exec"), {"__file__": str(ROOT / "docs/art/launch_glassies/tools/collect_launch.py"), "__name__": "collect_starter"})
for gid in ["sunny_rooster"]:
    m = json.loads((ROOT / "assets/blender/glassies" / gid / "v4/manifest.json").read_text())
    g = m["release_geometry"]
    print("ReleaseGeometry: %s = { Radius = %.6f, Center = %.6f }," % (gid, g["Radius"], g["Center"]))
