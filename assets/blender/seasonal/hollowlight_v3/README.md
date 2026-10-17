# Hollowlight v3: Lantern Eclipse moon

October 16, 2026 (Claude). Adds one new actor to the reworked Lantern Eclipse finisher; hollowlight_v1/v2 and their installed meshes are unchanged.

| File | What |
|---|---|
| `eclipse_moon.fbx` | `EclipseMoon_Glass` (crescent body, 2.57 × 3.4 × 0.42 studs) + `EclipseMoon_Rim` (gold outline). 3,704 tris total. |
| `hollowlight_v3.blend` | Source scene `HollowlightV3_EclipseMoon`. |
| `eclipse_moon_review.png` | 512 px review render. |

Built by `tools/blender/build_eclipse_moon.py` (refuses to overwrite an existing export; make a new revision instead).

## Installed in Studio

- Creator imported the FBX (File → Import 3D). It arrived at 100× scale, like v2.
- Claude installed a normalized copy as `ReplicatedStorage.Assets.Seasonal.Hollowlight.EclipseMoon`: pivot at the crescent centre, Glass `#F4EBC8` at 0.15 transparency, rim `#DDA84D` (the finisher switches it to Neon on release), anchored and non-colliding.
- The raw import is archived in `ServerStorage.HollowlightV3Import`.
- The place must be saved to keep these.
- `HollowlightFX` falls back to a neon half ring if `EclipseMoon` is missing.
