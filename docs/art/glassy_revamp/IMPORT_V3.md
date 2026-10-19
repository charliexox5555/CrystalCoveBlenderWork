# Importing the v3 / v4 glassies into Studio

**Import v4** (`assets/blender/glassies/<id>/v4/`, data in [`v4_import_data.json`](v4_import_data.json) and [`motion_manifest_v4.json`](motion_manifest_v4.json)). Everything below applies unchanged to v4: same file names inside the folder, same manifest schema, same normalizer steps (use `GlassyV4Imports` / `GlassyV4Staged` / `ReleaseVersion` 4). v4 keeps every client-driven name listed below. v4-only names (Dragon `WingRibs_L/R`, `EarFin_L/R`, `Fangs`, `Arms`, `BellyPlates`, `Spines`, `Sparkles`, `Cheeks`; Rocket `BoosterFlameCore`, `PortholeGlass`, `RaceStripe`, `Fizz`; Duck `BeakLower`; every glassy's inner layer, such as `SodaFill`, `Brine`, `InnerGlow`) collide with none of the client patterns, except that `WingRibs_*` deliberately match `Wing` so they rock with the wings. Parts whose names contain `Bubble` are skipped as shatter pieces by the client, which is intended for the floating bubbles. Body transparency hint is 0.38 (clear shell) with inner layers at 0.15–0.65 in `transparency`; the release_v2 normalizer sets 0.28 for every Glass part, so use the manifest value if you want the two-layer look.

All 24 v3 bundles are exported and FBX round-trip verified in Blender 5.2.2. Nothing has been imported into Studio yet. The steps follow the release_v2 path in [BATCH_IMPORT](../combat_release/BATCH_IMPORT.md), which worked.

## Files

Per glassy, in `assets/blender/glassies/<id>/v3/`:

| File | What it is |
|---|---|
| `<id>_bundle.fbx` | **Import this one.** Body + Details + Shards, all with their origin at the hang point |
| `<id>_body.fbx`, `<id>_details.fbx`, `<id>_shards.fbx` | The same meshes split up, if you need to recover one group |
| `manifest.json` | Same schema as release_v2 (`meshes[]` with `name`, `source_name`, `role`, `bounds_blender`, `color`, `material`, `animation_pivot`, `effect_only`), plus `transparency`, `motion`, `pivot_empty`, `collision` and `fbx_roundtrip` |
| `<id>_icon.png` | 512×512 transparent icon, release icon rig (front, orthographic, key/rim/fill) |
| `<id>.blend` | Editable source, including `Pivot_<Detail>` empties (local Z = motion axis) |
| `cracks.json` | Crack segments in Roblox hang space, same format as release_v2 |

Collected for code: [`motion_manifest.json`](motion_manifest.json) (every part of every glassy with Roblox-space pivot, axis, idle motion and hit reaction) and [`v3_import_data.json`](v3_import_data.json) (`{assets: {id: {meshes}}}`, the same shape as `tools/studio/combat_release_import_data.json`).

The pivot empties are **not** in the FBX files (FBX carries meshes only, as before), so the Roblox importer makes no extra parts or bones. Pivots reach Studio through the manifest.

## Steps

1. **Import.** In Studio, File > Import 3D, one `<id>_bundle.fbx` at a time, into a new `ServerStorage.GlassyV3Imports` folder. Settings as before: keep meshes separate (Merge Meshes off), use imported pivots, no cameras/lights, anchored. Expect the same quirks as release_v2: a 100× scale and a baked 180° yaw. Correct them against the manifest bounds, not by eye.
2. **Normalize.** Copy `tools/studio/normalize_combat_release.luau` and change only its folder and flag names (`CombatReleaseImports` → `GlassyV3Imports`, `CombatReleaseStaged` → `GlassyV3Staged`, the backup folder name, `ReleaseV2Normalized` → `GlassyV3Normalized`, `ReleaseVersion` 2 → 3, `ReleaseCount` 24). Pass it `v3_import_data.json` decoded with `HttpService:JSONDecode`. It already matches parts by exported `name`, renames them to `source_name`, sets `SourceName`, `AssetRole`, `EffectOnly`, colour and material, converts `animation_pivot` to the `AnimationPivot` attribute in Roblox axes and checks every bound. Neon parts have `material = "Neon"` and transparency 0.
3. **Verify.** Every part's normalized bounds should match the manifest within 0.001 stud, all shards should recombine to the body bounds, and the model pivot should be at the origin (the normalizer asserts all three).
4. **Swap in (when the creator approves).** Replace `ReplicatedStorage.Assets.Glassies.<id>` children with the v3 `Body`, `Details` and `Shards`. Keep the release_v2 models as a backup folder. `Glassies.luau` `Radius` does not need to change (§Collision).
5. **Icons.** Upload the 24 `<id>_icon.png` through Asset Manager > Bulk Import or the Open Cloud script (group 11116787) and record the IDs where the release_v2 icon IDs live.

## Names the current client already drives

All kept, so v3 drops into the current presentation code without code changes:

- `ChargeBubble_1..3` (Pop), `CoilSegment_1..3` (Arc Coil), `Thorn_1..3` (Briar Flask, pivot-scaled), `RayLens` (Prism), `Cap` (Pop rattle; Jam Lid Guard), `StressBand_1..2`, `Ember_1..3`, `LemonPulp`, `StarCore` (Comet, Galaxy Orb), `CrystalSprout` (glow on charge), `WaterInsert`, `SandInsert` (scaled by charge), `FoamBubble_1..3`, `FrameCap_*`/`FramePost_*` (Hourglass flip), `OrbitBand_1..2` and `OrbitBand_n_Moons` (spun about their centre), `Wing_L/R` (Dragon, Duck), `Jaw`, `Clapper` (rocked about `AnimationPivot`), `AxeHead`/`AxeHandle` (effect-only, Crescent Axe).
- Jam's new cloth cover is named `CapCloth`/`CapTie`, so `HeroPowers` (which lifts every detail whose name contains `Cap`) raises it with the lid.
- `Kits.crescent_axe.CrescentWeapon` is a separate Studio model built from release_v2's `AxeHead`/`AxeHandle`. It can be rebuilt from the v3 meshes, but nothing breaks if it is left alone.

## Renamed or removed vs release_v2 (nothing in `src/` references these)

Dragon `Snout` → `Muzzle`, `Eye.002/.003` → `Eyes` + `EyeShine`, `CurledTail` → `Tail`. Duck `Eye`/`Eye.001` → `Eyes` + `EyeShine`, `Wing`/`Wing.001` → `Wing_L/R`. Comet `Tail` → `TailFin_1..3`. Galaxy Orb `OffsetStarCore` → `StarCore` (now picks up the client's charge glow). Jam `LidRidge` removed (hidden by the cloth). Hourglass `FrameCap`/`FramePost` → `FrameCap_Bottom/Top`, `FramePost_1/2`.

## Collision

Body bounds stay within 2.5% of release_v2 on every axis (most are identical, because organic bodies are scale-fit to the release_v2 box). `Glassies.luau` `Radius` is unchanged for all 24. Largest changes: Hot Sauce 2.45% (depth with 18 segments), Chime 2.27%, Crescent Axe 2.13%, Frostglobe 2.06%. Each manifest's `collision` block has both sets of dimensions. Wings, tails, fins and orbit rings are Details, so they never affect the fight geometry.

## Driving the idle motion

Per part, `motion_manifest.json` gives `pivot_roblox`, `axis_roblox`, `idle`, optional `idle_layers`, `hit`, `lod_keep`. The vocabulary (`sway`, `spin`, `bob`, `pulse`, `slosh`, `flicker`, `blink`; hits `kick`, `flare`, `hop`, `squash`, `flash`, `spin_boost`) is defined at the top of that file and in [GLASSY_REVAMP §3](../GLASSY_REVAMP.md). A part tagged "moves with X" in `note` uses the same pivot and motion as X, so drive them together. Parts the client already animates by name keep that behaviour; the manifest motion layers on top or replaces it, whichever the presentation owner prefers. Budget tip: on low detail, animate only `lod_keep` parts.
