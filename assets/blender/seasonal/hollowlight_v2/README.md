# Hollowlight — refined import package

**Ready for creator import, October 16, 2026.** Supersedes the v1 prototype exports. Original v1 sources and the creator's open Blender scene are preserved. This package is original art for a seasonal **Pop appearance**, Lantern Skiff flyer and Lantern Eclipse finisher. The release remains 24 glassies; no new combat stats, sales or product activation.

## What to import

Import **HOLLOWLIGHT_V2_IMPORT.fbx** once with Studio's **3D Importer**, scale **1**. Keep all **68 meshes** selected and preserve their **HH2_** names. Import as one model and leave that model in Workspace. Do not manually resize, move individual meshes, recolor or ungroup it; the subsequent installation pass will normalize the importer scale and assign native materials. Do not publish the place.

This single FBX includes everything geometric:

| Group | Meshes | Purpose |
|---|---:|---|
| Pumpkin | 13 | Glass body, stem, leaves, surface-fitting face |
| Shards | 16 | Closed pre-broken body pieces, common hang origin |
| Flyer | 20 | Hull, deck, independent wings/inlays, lanterns and exhaust |
| Finisher | 19 | Matching pumpkin core, three ghosts/faces/tails, rings and spirals |

The shards and finisher are component assets, not a finished assembled scene. The raw import intentionally contains overlapping groups; installation will separate them. Confirm the importer finishes uploading every mesh, then let Codex know the import is complete. If Studio shows a mesh/import error, retain that message rather than accepting an incomplete set.

**HollowlightVFX.rbxm** is a separate, script-free, editable native particle/beam prototype kit. A copy already exists at `ReplicatedStorage.Assets.VFX.HollowlightPrototype`; no duplicate import is needed if it is still there. Restore the file into the VFX asset library only when that kit is missing. Its emitters/ribbons remain disabled until runtime integration.

PNG files are review/UI icons, not 3D imports. `hollowlight_v2.blend` is the editable Blender source, not a Studio import. `mouth_candidate.png` is a superseded draft retained for provenance; use `pumpkin_front_review.png` for the refined face.

## Refinement

- Replaced the floating tube smile with a filled crescent grin, two small teeth and a dark carved rim, projected onto the pumpkin's actual ribbed surface. Reduced mint brightness for a cleaner face.
- Narrower pumpkin silhouette with exactly matching shards; thicker leaves and softer glass preview finish.
- Added a flat skiff deck inlay and flowing tapered exhaust. Wings stay separate for animation.
- Finisher uses a miniature of the complete refined pumpkin; ghosts have independent combined face meshes and tapered tails.

Source units remain **1 Blender unit = 1 stud**, coordinates map to Roblox `(x,z,-y)`. All mesh objects share identity transforms and origin `(0,0,0)`; pumpkin origin is its hang reference. The skiff deck is Blender z=0.33. Material colors are previews; use `manifest.json` for native Studio color/material assignment. Determine the rider's facing from the hull in Studio; pumpkin face points Blender −Y. Preserve mesh assembly offsets during installation.

## Verification and remaining work

`validation.json`: **68 meshes / 23,772 triangles**, largest mesh **1,792 triangles**; body **1,056 triangles**, 16 closed positive-volume shards with volume-sum error below 0.00000004. Source transforms applied; one material per mesh; no remaining modifiers. FBX round trip preserves every custom mesh ID, triangle count, material slot, origin and bounds (maximum bounds error **0.000000239 studs**). Both mouth surfaces pass triangle-center clearance checks. Front and three-quarter renders reviewed at 512×512.

Builder: `tools/blender/finalize_hollowlight_v2.py` (fresh scene only); final refinement/validation: `tools/blender/validate_hollowlight_v2.py`. Run through Blender MCP. The validator changes only the generated v2 scene, preserving prior mesh datablocks; it restores the original active scene and filepath.

**After import:** record permanent mesh IDs, normalize and archive the raw import, assemble the seasonal Pop appearance and cosmetic sources, assign native materials, animate wings/ghosts/rings and integrate the original VFX kit. Verify real-round readability, riding pose, shatter cleanup and phone budgets. These renders show static art; the animated seasonal effects are not yet implemented. The map and paid features remain untouched.
