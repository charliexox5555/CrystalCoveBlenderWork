# Imported release assets — scale and anchoring correction

2026-10-15. The creator imported all bundles into `ServerStorage.CombatReleaseImports` and reported oversized models and mixed anchoring.

The importer produced exactly **100×** the intended scale and baked a 180° yaw into the meshes. Corrected all **527 imported parts** using the source dimensions and hang pivots; every processed import part is now anchored, non-colliding, non-touching and non-queryable. Raw shard geometry is hidden to avoid overlapping the intact body when an import is previewed. The extra Pop import remains recoverable; the canonical staging library contains exactly 24 unique glassies.

Locations in Studio:

- `ServerStorage.CombatReleaseImports` — corrected creator bundles, including the duplicate Pop.
- `ServerStorage.CombatReleaseStaged.Glassies` — 24 canonical `Body` / `Details` / `Shards` models at source scale 1, all part pivots aligned at the hang point.
- `ServerStorage.CombatReleaseStaged.VFX.combat_vfx` — ten normalized shared meshes.
- `ServerStorage.CombatReleaseStaged.VFX.Textures` — eight named Decal references using the already-recorded image IDs. Marketplace metadata confirms all eight IDs are Image assets. No extra upload or creator lookup is needed.
- `ServerStorage.CombatReleaseBackups.RawBeforeNormalization_20261015` — untouched raw imports, preserving original sizes, transforms and mixed anchoring. This inactive backup is intentionally the before-state.

Canonical models remain staged. No live glassy asset, catalog definition, ownership, acquisition pool, match selection, UI or combat rule was replaced in this fix.

## Evidence and checks

- 4,763 native checks passed for 506 canonical parts and 384 shards: actual native mesh IDs, counts, flags, colors/materials, scale, hang origins and source/native world bounds. Largest bounds deviation: `0.0000002732` studs.
- All 527 creator-import parts anchored; all raw originals preserved. Running the normalizer again returns `AlreadyNormalized` without shrinking models twice.
- First six actual imported models reviewed with current sky/lighting, fixed straight-on camera at distance 33 / FOV 52 and the existing 1.75 fight display scale. [Native preview](native_batch_A.png). This is a static imported-art review, not six live combat kits.
- Shared textures fetch successfully. Edit captures of image alpha cards did not show a usable image proof; client flipbook order, alpha and timing remain pending. Native meshes are available as the required texture-independent fallback.
- Lune: 79 passed, 0 failed. Native `RunAll` returned true. No balance/config/rules changes; simulators were not required or rerun.
- Exported `places/CombatRelease_Staged_v2.rbxm` and `places/CombatRelease_RawBeforeNormalization_20261015.rbxm`. Decoded RBXM headers verified; the staged snapshot was deserialized successfully with 24 glassies / 506 parts / eight textures / zero unanchored parts. Restore either snapshot under **ServerStorage**, especially the oversized raw backup.
- Studio left in Edit; temporary review moved into ServerStorage, original FOV restored. No publication or device/preset changes.

Reproduce normalization with `tools/studio/normalize_combat_release.luau` and `combat_release_import_data.json`; independent checks are in `verify_combat_release_imports.luau`. Actual part IDs and scale/pivot results are in [native_import_report.json](native_import_report.json).

Next: client effect/animation proof and shared server trigger/attack foundations for the first six, then the remaining kits and audited release filtering. Existing live assets stay active until that integration.
