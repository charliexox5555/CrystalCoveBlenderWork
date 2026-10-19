"""Collects every assets/blender/glassies/<id>/v4/manifest.json of the Roster V2 launch glassies into the
Studio-facing files (same shapes as docs/art/glassy_revamp/tools/collect_manifest.py):

    python3 docs/art/launch_glassies/tools/collect_launch.py

- docs/art/launch_glassies/motion_manifest.json: per glassy, every part with pivot, axis and motion.
- docs/art/launch_glassies/launch_import_data.json: {"assets": {id: {"meshes": [...]}}} (the shape
  tools/studio/normalize_combat_release.luau reads), plus "release_geometry": {id: {Radius, Center}}
  measured from the Body bounds for src/shared/Config/ReleaseGeometry.luau.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / "docs/art/launch_glassies"
ORDER = ["cookie_jar", "fishbowl", "glass_top", "piggy_bank", "bubble_wand", "crystal_ball",
         "honey_bear", "potion_flask", "light_bulb", "grizzly_guardian", "glass_unicorn", "glass_phoenix"]

motion, imports, geometry = {}, {}, {}
for gid in ORDER:
    path = ROOT / "assets/blender/glassies" / gid / "v4/manifest.json"
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
            for k in ("idle_layers", "note", "follows"):
                if k in e["motion"]:
                    row[k] = e["motion"][k]
        parts.append(row)
    motion[gid] = {
        "name": m["name"], "rarity": m["rarity"], "tint": m["tint"], "version": m["version"], "bundle": m["files"]["bundle"],
        "icon": m["files"].get("icon"), "intact_triangles": m["intact_triangles"], "shard_count": m["shard_count"],
        "release_geometry": m["release_geometry"], "radius_target": m["radius_target"],
        "body_dimensions_roblox": m["measured_body_dimensions_roblox"],
        "fbx_roundtrip": m.get("fbx_roundtrip", {}).get("passed", False),
        "animated_parts": sum(1 for p in parts if p.get("idle", {}).get("type", "static") != "static" or p.get("hit", {}).get("type", "none") != "none"),
        "parts": parts,
    }
    imports[gid] = {"meshes": [{k: e[k] for k in ("name", "source_name", "role", "triangles", "bounds_blender", "origin", "color",
                                                   "material", "animation_pivot", "effect_only")} for e in m["meshes"]]}
    geometry[gid] = m["release_geometry"]

doc = {
    "schema": "launch_glassies_v4/1 (glassy_revamp_v3/1 plus `follows` and the `drip` idle type)",
    "coordinates": "Roblox model space: roblox = (x, z, -y) of Blender; studs at GlassyScale 1; origin = hang point",
    "idle_types": {"sway": "rotate about axis amp_deg*sin(2*pi*t/period_s+phase)", "spin": "rotate about axis at deg_per_s",
                   "bob": "translate along axis amp_studs*sin(...)", "pulse": "scale about pivot 1+amp*sin(...); Neon parts also brighten",
                   "slosh": "rotate about axis by -gain*swing angular velocity (deg/s), clamp max_deg, spring freq_hz/damping",
                   "flicker": "random scale jitter amp at rate_hz", "blink": "scale along axis to 0.1 for dur_s every interval_s (+-40%)",
                   "drip": "loop every period_s: scale 0->1 over grow_s at the pivot, then slide fall_studs along the axis while fading, reset",
                   "static": "no idle motion"},
    "hit_types": {"kick": "rotate deg about axis (sign from hit side), spring back", "flare": "rotate deg outward, spring back",
                  "hop": "translate studs along axis, spring back", "squash": "scale factor along axis, spring back",
                  "flash": "Neon/brighten for dur_s", "spin_boost": "add deg_per_s decaying over dur_s", "none": "no reaction"},
    "follows": "A part with `follows` rides the named part: apply the parent's motion first, then its own idle/hit in the parent's frame "
               "(fish tail on the fish, eye shine on the eyes, chips on their cookie). Parts with the same motion as the parent repeat it.",
    "body_motion": "Glass Top's Body has a cosmetic spin about the hang axis; its stripes, ring, knob and tip follow it.",
    "lod": "Low-detail mode: animate only parts with lod_keep=true (plus client-driven kit names).",
    "glassies": motion,
}
(OUT / "motion_manifest.json").write_text(json.dumps(doc, indent=1) + "\n")
(OUT / "launch_import_data.json").write_text(json.dumps({"assets": imports, "release_geometry": geometry}, indent=1) + "\n")
print(f"{len(motion)} launch glassies collected: {', '.join(motion)}")
