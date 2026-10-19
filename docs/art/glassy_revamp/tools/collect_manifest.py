"""Collects every assets/blender/glassies/<id>/v3/manifest.json into two Studio-facing files.

    python3 docs/art/glassy_revamp/tools/collect_manifest.py        # v3 -> motion_manifest.json, v3_import_data.json
    python3 docs/art/glassy_revamp/tools/collect_manifest.py v4     # v4 -> motion_manifest_v4.json, v4_import_data.json

- docs/art/glassy_revamp/motion_manifest.json: per glassy, every part with pivot, axis and motion.
- docs/art/glassy_revamp/v3_import_data.json: {"assets": {id: {"meshes": [...]}}}, the same shape
  tools/studio/normalize_combat_release.luau reads for release_v2.
"""
import json
import sys
from pathlib import Path

VERSION = sys.argv[1] if len(sys.argv) > 1 else "v3"
SUFFIX = "" if VERSION == "v3" else "_" + VERSION

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / "docs/art/glassy_revamp"
ORDER = ["glass_dragon", "galaxy_orb", "comet", "prism_blade", "rocket_pop", "glass_duck",
         "pop", "jam", "prism", "crescent_axe", "briar_flask", "arc_coil",
         "hourglass", "frostglobe", "mason_jar", "hot_sauce", "crystal_tumbler", "chime",
         "milk_bottle", "pickle_jar", "ketchup_bottle", "glass_cup", "water_jug", "lemonade_bottle"]

motion, imports = {}, {}
for gid in ORDER:
    path = ROOT / "assets/blender/glassies" / gid / VERSION / "manifest.json"
    if not path.exists():
        continue
    m = json.loads(path.read_text())
    parts = []
    for e in m["meshes"]:
        if e["role"] == "Shard":
            continue
        row = {"name": e["source_name"], "role": e["role"], "material": e["material"], "color": e["color"],
               "transparency": e.get("transparency", 0), "effect_only": e["effect_only"]}
        if "motion" in e:
            row["pivot_empty"] = e["pivot_empty"]
            row.update({k: e["motion"][k] for k in ("pivot_roblox", "axis_roblox", "idle", "hit", "lod_keep")})
            for k in ("idle_layers", "note"):
                if k in e["motion"]:
                    row[k] = e["motion"][k]
        parts.append(row)
    motion[gid] = {
        "rarity": m["rarity"], "version": m["version"], "bundle": m["files"]["bundle"], "icon": m["files"].get("icon"),
        "intact_triangles": m["intact_triangles"], "shard_count": m["shard_count"],
        "body_dimensions_roblox": m["collision"]["body_dimensions_roblox_" + VERSION],
        "body_dimension_change_pct": m["collision"]["max_dimension_change_pct"],
        "fbx_roundtrip": m.get("fbx_roundtrip", {}).get("passed", False),
        "animated_parts": sum(1 for p in parts if p.get("idle", {}).get("type", "static") != "static" or p.get("hit", {}).get("type", "none") != "none"),
        "parts": parts,
    }
    imports[gid] = {"meshes": [{k: e[k] for k in ("name", "source_name", "role", "triangles", "bounds_blender", "origin", "color",
                                                   "material", "animation_pivot", "effect_only")} for e in m["meshes"]]}

doc = {
    "schema": "glassy_revamp_v3/1",
    "version": VERSION,
    "coordinates": "Roblox model space after the release_v2 normalisation: roblox = (x, z, -y) of Blender; studs at GlassyScale 1; origin = hang point",
    "idle_types": {"sway": "rotate about axis amp_deg*sin(2*pi*t/period_s+phase)", "spin": "rotate about axis at deg_per_s",
                   "bob": "translate along axis amp_studs*sin(...)", "pulse": "scale about pivot 1+amp*sin(...); Neon parts also brighten",
                   "slosh": "rotate about axis by -gain*swing angular velocity (deg/s), clamp max_deg, spring freq_hz/damping",
                   "flicker": "random scale jitter amp at rate_hz", "blink": "scale along axis to 0.1 for dur_s every interval_s (+-40%)",
                   "static": "no idle motion"},
    "hit_types": {"kick": "rotate deg about axis (sign from hit side), spring back", "flare": "rotate deg outward, spring back",
                  "hop": "translate studs along axis, spring back", "squash": "scale factor along axis, spring back",
                  "flash": "Neon/brighten for dur_s", "spin_boost": "add deg_per_s decaying over dur_s", "none": "no reaction"},
    "lod": "Low-detail mode: animate only parts with lod_keep=true (plus client-driven kit names).",
    "glassies": motion,
}
(OUT / f"motion_manifest{SUFFIX}.json").write_text(json.dumps(doc, indent=1) + "\n")
(OUT / f"{VERSION}_import_data.json").write_text(json.dumps({"assets": imports}, indent=1) + "\n")
print(f"{len(motion)} {VERSION} glassies collected")
