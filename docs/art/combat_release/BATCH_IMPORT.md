# Combat release — batch import

Import completed by the creator. All 24 glassies and the shared kit are now normalized and validated in Studio; no further import is requested.

Canonical models: `ServerStorage.CombatReleaseStaged.Glassies`. Shared meshes and eight named texture references: `ServerStorage.CombatReleaseStaged.VFX`. Raw models in `CombatReleaseImports` were corrected by 0.01× and anchored. Originals, including the extra Pop, are preserved in `CombatReleaseBackups.RawBeforeNormalization_20261015`.

Settings/checks: 1 unit = 1 stud; preserve imported pivots, keep meshes separate, import no cameras/lights, no collision on cosmetic parts. Do not promote over live assets yet. Match names and role attributes to manifest; use its colors/materials and bounds. Confirm source origin `(0,0,0)` at the hang point. Use DoubleSided on the thin VFX sheets if their back-face test needs it. Verify actual scale against each manifest rather than compensating by eye.

The imported geometry had a 100× unit conversion and baked 180° yaw. Both were corrected against actual source bounds and hang pivots, rather than by eye. Native first-six geometry/material review passed; client effect timing and flipbook/alpha validation remain pending.

## Export source references (already imported)

- **A · Pop**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/pop/release_v2/pop_bundle.fbx` — 1184 intact triangles; `manifest.json` alongside.
- **A · Jam**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/jam/release_v2/jam_bundle.fbx` — 1000 intact triangles; `manifest.json` alongside.
- **A · Prism**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/prism/release_v2/prism_bundle.fbx` — 288 intact triangles; `manifest.json` alongside.
- **A · Crescent Axe**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/crescent_axe/release_v2/crescent_axe_bundle.fbx` — 480 intact triangles; `manifest.json` alongside.
- **A · Briar Flask**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/briar_flask/release_v2/briar_flask_bundle.fbx` — 764 intact triangles; `manifest.json` alongside.
- **A · Arc Coil**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/arc_coil/release_v2/arc_coil_bundle.fbx` — 996 intact triangles; `manifest.json` alongside.
- **B · Milk Bottle**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/milk_bottle/release_v2/milk_bottle_bundle.fbx` — 1096 intact triangles; `manifest.json` alongside.
- **B · Pickle Jar**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/pickle_jar/release_v2/pickle_jar_bundle.fbx` — 680 intact triangles; `manifest.json` alongside.
- **B · Ketchup Bottle**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/ketchup_bottle/release_v2/ketchup_bottle_bundle.fbx` — 720 intact triangles; `manifest.json` alongside.
- **B · Glass Cup**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/glass_cup/release_v2/glass_cup_bundle.fbx` — 672 intact triangles; `manifest.json` alongside.
- **B · Water Jug**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/water_jug/release_v2/water_jug_bundle.fbx` — 904 intact triangles; `manifest.json` alongside.
- **B · Lemonade Bottle**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/lemonade_bottle/release_v2/lemonade_bottle_bundle.fbx` — 788 intact triangles; `manifest.json` alongside.
- **C · Mason Jar**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/mason_jar/release_v2/mason_jar_bundle.fbx` — 1072 intact triangles; `manifest.json` alongside.
- **C · Hot Sauce**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/hot_sauce/release_v2/hot_sauce_bundle.fbx` — 720 intact triangles; `manifest.json` alongside.
- **C · Crystal Tumbler**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/crystal_tumbler/release_v2/crystal_tumbler_bundle.fbx` — 500 intact triangles; `manifest.json` alongside.
- **C · Chime**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/chime/release_v2/chime_bundle.fbx` — 752 intact triangles; `manifest.json` alongside.
- **C · Hourglass**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/hourglass/release_v2/hourglass_bundle.fbx` — 824 intact triangles; `manifest.json` alongside.
- **C · Frostglobe**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/frostglobe/release_v2/frostglobe_bundle.fbx` — 688 intact triangles; `manifest.json` alongside.
- **D · Prism Blade**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/prism_blade/release_v2/prism_blade_bundle.fbx` — 220 intact triangles; `manifest.json` alongside.
- **D · Rocket Pop**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/rocket_pop/release_v2/rocket_pop_bundle.fbx` — 724 intact triangles; `manifest.json` alongside.
- **D · Glass Duck**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/glass_duck/release_v2/glass_duck_bundle.fbx` — 1232 intact triangles; `manifest.json` alongside.
- **D · Comet**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/comet/release_v2/comet_bundle.fbx` — 556 intact triangles; `manifest.json` alongside.
- **D · Glass Dragon**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/glass_dragon/release_v2/glass_dragon_bundle.fbx` — 1212 intact triangles; `manifest.json` alongside.
- **D · Galaxy Orb**: `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/glassies/galaxy_orb/release_v2/galaxy_orb_bundle.fbx` — 880 intact triangles; `manifest.json` alongside.

## Shared kit

- `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/blender/vfx/combat_release/combat_vfx_bundle.fbx` — 10 separate reusable meshes; origins recorded in `manifest.json`.
- `C:/Users/charl/Documents/CrystalCoveBlenderWork/assets/vfx/combat_release` — six 256px static RGBA textures, two 512px 4×4 atlases; source frames in `frames/`.

All eight texture images are already uploaded. Use their actual IDs in `assets/vfx/combat_release/roblox_textures.json`; no reupload is needed. Native visual alpha/order verification remains pending.

Keep ParticleEmitters disabled at rest, use bounded `Emit`, and `Clear` on interruption. No shaders, animation rigs or physics come from the FBXs.

Native imports are complete and staged; live kits/catalog changes are pending. Editable native snapshots are in places/CombatRelease_Staged_v2.rbxm and places/CombatRelease_RawBeforeNormalization_20261015.rbxm. Creator publishing and real-device review remain separate.
