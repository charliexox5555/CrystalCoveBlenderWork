# Combat release asset production — 2026-10-15

Scope: fixed 24-glassy art production, shared original VFX assets, recoverable sources and import preparation. Live kits, acquisition filters and balance integration remain pending the native mesh-import gate.

## Source safety

- Pulled latest; original 12 source `.blend` files remained untouched and were hash-checked against their source-audit records.
- Entry Blender state: unsaved clean `Scene`, Cube/Camera/Light, Cube selected. Recovery copy: `assets/blender/backups/combat_release_start_20261015.blend`. Builders use isolated scenes and restore the original scene; no desktop automation/device settings.
- Output packages are under `assets/blender/glassies/<id>/release_v2/`. First appearance sources and the two batch-A detail iterations remain recoverable. Reproducible builders are in `tools/blender/build_combat_release.py` and `build_combat_vfx.py`.
- Existing unrelated lobby/map/art files were excluded from task staging.

## Checks actually performed

- Exactly 24 unique IDs, in the approved four batches; original IDs/names retained. No runtime catalog, profile, ownership, rarity, Kiln odds or match-hand changes.
- Each asset: intact triangle budget, 16 closed/manifold positive-volume shards, aligned origins and recombined bounds, fracture-volume ratio within 0.1%, regenerated surface-projected crack paths, hashes, upright 512×512 RGBA icon with padding.
- Active crack JSON is canonical LF in both builder output and Git attributes. Recorded hashes were checked against staged Git bytes, avoiding Windows newline conversion drift; coordinates are unchanged.
- Validation caught a loose cut edge in Arc Coil and an FBX exporter requirement for floating-point custom-property vectors. Both were corrected before the accepted packages were written; failed temporary meshes were not promoted.
- Each bundle was actually imported back into an isolated Blender scene. Mesh/part count, source-name properties, hang origins, body/shard manifold topology and world-space bounds were checked. Source and FBX geometry agree within 0.0001 units. This is **Blender FBX round-trip evidence**, not a Roblox import claim.
- Original-source before/after renders for all 12 revisions; contact sheets include genuine 64px samples. Final material pass uses the same upright camera/light rig, 64 Cycles samples, transparent film and a more transparent body preview so internal details read. Final game appearance still requires Studio review.
- Shared kit: 10 original meshes, six analytic grayscale RGBA masks, two original Blender-rendered 16-frame 4×4 sheets. Alpha/gutters/frame ordering verified in files over dark and bright cards; final frame is fully transparent. Source frames and editable render source preserved.
- All eight texture images uploaded through Studio MCP; actual IDs saved in `assets/vfx/combat_release/roblox_textures.json` and the kit manifest. Native ImageLabel-based ContentProvider preload returned Success for all eight; an earlier raw-string probe returned mixed statuses. Unparented probes do not establish rendered-client readiness. Results: `docs/art/combat_release/native_texture_fetch.json`. No mesh upload occurred.
- Isolated `ServerStorage.VFXPreview_CombatRelease` fixture created using **original installed** starter bodies and staged outcomes. Particle layout/OneShot properties accepted. Edit screenshots did not provide a readable rendered effect proof; native animation/alpha order/readability remains pending. No claim of hit detection, damage, first-six kits or performance validation.
- Fixture removed from Workspace into ServerStorage, particles cleared/disabled, original viewport FOV restored. Studio left in Edit. No production publication.

## Import gate and remaining work

The connected Studio MCP exposes image upload but no local FBX import capability. Creator import list: [BATCH_IMPORT.md](../art/combat_release/BATCH_IMPORT.md). One bundle per glassy plus the shared kit, with exact paths and manifest bounds/settings. Continue from Pop/shared-kit import proof, then validate all six A kits against the real fight camera/current lighting before engineering expansion.

Still required: revised native material/pivot/scale/shard/crack proof; native VFX timing and actual hit/miss/block outcomes; shared authoritative contacts/turnarounds/storage/threshold rules; first-six live kits; all-24 expansion; profile ownership audit; deliberate new rarities/acquisition mapping; consistent explicit release allowlist; required simulator/native/multiplayer/cleanup/performance checks. Publishing and real-device review belong to the creator.

The offline `timelines.json` contains presentation drafts, not implemented gameplay or confirmed timing. No active kit was changed or advertised as complete.

## Reproduction

Load `tools/blender/glassclash_blender.py`, `build_combat_release.py`, then `validate_combat_release.py` through Blender MCP. `build_release_asset(id)` preserves existing packages; explicit `repair=True` copies the previous package before rebuilding. `validate_release_fbx(id)` imports temporary copies and records its actual checks. `refine_release_preview(id)` preserves the previous editable appearance source before updating preview materials/exports/icons.

File QA: `python tools/blender/review_combat_release.py`, `python tools/blender/review_combat_vfx.py`, `python tools/blender/package_combat_release.py`. Test results are recorded in the session DEVLOG after the final checks.
