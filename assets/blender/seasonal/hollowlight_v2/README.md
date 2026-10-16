# Hollowlight — refined import package

**Imported and installed, October 16, 2026.** All 68 permanent meshes load. Sources are at `ReplicatedStorage.Assets.Seasonal.Hollowlight`; raw import preserved intact at `ServerStorage.HollowlightBeforeV2.HOLLOWLIGHT_V2_IMPORT`. Do not reimport or rerun the installer over this installed set. Supersedes the v1 prototypes, which remain preserved. This package is original art for a seasonal **Pop appearance**, Lantern Skiff flyer and Lantern Eclipse finisher. The release remains 24 glassies; no new combat stats, sales or product activation.

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

## Installed runtime support and recovery

`roblox_meshes.json` records all permanent IDs. Installer/metadata: `tools/studio/install_hollowlight_imports.luau` and `hollowlight_import_data.json`. Preflight checks all 68 names, uploaded IDs, importer scale and orientation before writing assets. Corrected 100× scale and baked half-turn; native glass/neon/plastic colors, nonphysical parts and common pivots applied. Pumpkin fits existing Pop width without changing its definition/hit rules; cap stem/curl participate in existing pressure recoil. Skiff deck top is y=0, its nose faces rider-forward −Z, ten wing/rim/vein pieces share hinges, and it uses the original glider pose through `PoseId`.

`HollowlightFX` animates the 19 finisher pieces: ghosts/faces/tails converge coherently, spiral ribbons turn, rings expand and the lantern clears the recipient on release. Four native one-shot layers use 36 particles; reduced detail uses ten mesh actors, twelve particles and no beams. Timings/shape tuning live in the editable kit attributes. Destruction disconnects the motion listener immediately; natural expiration retains particles through their lifetimes. `FinisherFX` dispatches `lantern_eclipse`; optional server-authored fight setup `Skin="hollowlight"` resolves only Pop's appearance, with a native mint pressure accent at confirmed contact. Other Pop appearances and all authoritative rules remain unchanged.

Focused native fixture `tools/studio/verify_hollowlight_import.luau`: **257 checks pass**, 68/68 mesh preload successes, common pivots, Pop-size/definition preservation, coherent ghost motion, phase/fade/ring checks, reduced detail, real RideController wing motion, normalized deck/facing, glider foot contact/default-animation restoration, cancellation/expiration and avatar health 100. Initial wing fixture was beyond the controller's 120-stud culling distance; moved it near the camera before retesting. Installed front/three-quarter art reviewed in an isolated temporary Studio sky fixture; all fixtures removed.

Native recovery: `places/Hollowlight_v2.rbxm`, **273265 bytes**, SHA256 `e84e6525e2d1994da2d2af88b8a4bc636a7cd4885f9c799a26ddd0e5908c581d`; script-free deserialize round trip **157 descendants**. Restore `Hollowlight` under `ReplicatedStorage.Assets.Seasonal` and `HollowlightBeforeV2` under `ServerStorage`. Source modules come from Rojo. Export helper: `tools/studio/export_hollowlight_v2.luau`; transfer `_G.HollowlightExport` in bounded chunks if needed. HTTP is disabled and was left unchanged.

**Remaining:** persisted seasonal skin/ownership/equip UI and server match serialization, limited-bundle storefront, final riding-pose refinements, creator normal-round feel and phone budgets. This installation supplies assets and animated presentation support; the set is not yet selectable through the normal inventory or ordinary crates. No sale dates, product IDs, paid grants or active countdown. Studio left Edit/unpublished, map and device settings untouched, scheduling paused.
