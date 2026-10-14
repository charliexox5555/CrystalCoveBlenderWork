# Current handoff — 2026-10-14

**Fitted fences, Wave1 native imports and the approved early-abandonment rule are complete.** Code is committed/pushed at each milestone; world/UI instances still need a Studio save.

## Your next actions

1. **Save the place in Studio now.** All five islands and bridges have fitted fences. The nine glassies and eight sky assets are installed; no more Wave1 imports are needed.
2. Work on final UI art/styling under **StarterGui's 14 ScreenGuis**. Keep named controls/Templates folders; layouts use Scale with zero offsets. [Editing guide](../ui/EDITING_UI.md).
3. Publish manually, then check real ProfileStore reconnect/session locking and global leaderboard updates in a published test server. Studio remains on isolated mock profiles even with API access enabled.
4. On a real phone, check pick → pull to gold → lock → powers/shatter → results/replay. Check tap/close controls, audio and low-end frame rate/MicroProfiler; manual gamepad checks remain open because MCP ButtonB is blocked by CoreGui.
5. Supply the group ID/permitted reward configuration if you want the join reward. Index completion rewards also need a chosen rule. Paid features and free Marbles stay disabled.

## Latest work

[Fence/import/reward report and screenshots](../testing/FENCES_AND_WAVE1_NATIVE.md):

- All five exact grass rims fitted with the creator's 3-stud brown-post/two-rail style, ~5-stud spacing, .9-stud inset and 11-stud bridge gates. Matching bridge rails; 232 posts, 464 rails, 232 invisible safety colliders. Zero post-corner overhang. Originals preserved in **ServerStorage.Unsorted.OriginalPerimeterFences**.
- All-pad walk: 33 visits, no falls/blockages; featured pad 13.95 s. Real character blocked from walking off at X=45.20.
- Nine new glassies installed and native-validated, **12 playable total**. Each has Body/Details, 16 shards and surface cracks. Eight sky assets normalized; native Kiln hero, arch, crystals/clouds placed. Raw sources and previous Kiln preserved.
- Real single/ten Kiln pulls, duplicate stars and used-quote rejection passed with Studio mock coins. Actual pool has nine installed non-starters; Rare+ models remain unbuilt/unavailable. Odds reflect this pool.
- Your accepted rule: no rewards/progress/welcome eligibility before a real round completes. Early disconnect gives zero coins/trophies and leaves match stats/streaks unchanged. Existing amounts after a completed round stay unchanged.
- Native two-client PvP/replay/disconnect plus third staggered join passes with zero errors. Seven moving fights: server 59.98 FPS, .168 ms simulation/frame. Client Studio samples ~59/15 FPS with spikes; real-phone verification remains open.
- **74 tests pass in Lune and Studio.** Final Output clean. Studio left in Edit.

## Earlier backlog completed

| Item | Result | Evidence |
|---|---|---|
| F1 fight | Custom server 3D pendulums, pass-bys/spin/tumble, auto powers, aim/LOCK, interpolation, layered hits/cracks, slow-mo shards. 80 Lune + 40 Studio calibration rounds, ten live watched rounds. | [F1](../testing/F1_FIGHT.md) |
| F2 matches | Seven arenas, pad queues/bots, full rounds/hearts/results, free rerolls, replay, reset/disconnect and nearby spectator fights. | [F2](../testing/F2_MATCH_FLOW.md) |
| F3 data/UI | Reviewed pinned ProfileStore, locked production profiles, starter grants, idempotent settlement, saved collection/stats, coin Kiln/reveal, collection filters/details/Index. Native pulls now verified. | [F3](../testing/F3_DATA_KILN.md), [vendor review](../vendor/ProfileStore_REVIEW.md) |
| UI placeholders | Fourteen editable scale-based templates. 39 layout states on A06, iPhone and iPad pass safe-screen and 44 px target checks. Authored geometry preserved by controller binding. Final art is yours. | [F5](../testing/F5_MULTIPLAYER_SECURITY.md), [editing](../ui/EDITING_UI.md) |
| Blender | Eight sky props + nine glassies exported/imported; 17 bundles / 183 meshes. Original source scenes/starters preserved. | [Asset wave](../testing/ASSET_WAVE1.md), [native follow-up](../testing/FENCES_AND_WAVE1_NATIVE.md) |
| Free F4 | Three daily quests, playtime gifts, first observed win bonus, check-in streak, one-use Studio code, Daily/Codes kiosks and Trophies/Wins/Shatters boards. | [F4](../testing/F4_FREE_RETENTION.md) |
| Security/cleanup | Remote floods/malformed inputs limited; private fields hidden. Late-join hook replication, double-KO flash leak and distant final-event drain fixed. Twenty cleanup cycles / 123 checks pass. | [F5](../testing/F5_MULTIPLAYER_SECURITY.md) |

## Reproducible world work

- Fences: `tools/studio/fit_island_fences.luau` refuses existing fitted fences. Exact rim regeneration: `python tools/map/export_fence_paths.py`. Read-only checks: `tools/studio/verify_fences.luau`.
- Imports: `stage_wave1_imports.luau` → `install_wave1_glassies.luau` → `install_wave1_sky.luau`. Already done; do not rerun builders over manual edits.
- Native mesh IDs/transforms: `assets/blender/import_wave1/studio_assets.json`. Raw imported sources remain in ServerStorage.Wave1ImportedSources.
- Manual decor/LegacyKit remain preserved. Original fences and previous Kiln are recoverable backups, not deleted.

## Calibration for Claude

80 actual-integrator rounds, seeds 101–180: 0 timeouts, .461 hits/s, 36.7% pass-bys, encounter interval 1.372 s. Median speed 20.67 studs/s (P10 7.22, P90 29.45), ShareA .499, median round 32.56 s. Beam/Freeze combined 66.7% landed. Max string error .0000015 studs. Raw: `docs/testing/F1_calibration_draft.json`.

Candidate SimModel: HitInterval=1.37, SpeedAtAmplitude=24.5, SpeedSpread=.67, ShareSpread=.245, MissChance=.367. It fails Jam mirror duration (45.882 s >45) and Prism Blade fairness (63% >62%). Passing baseline restored; no Fight/Powers/rarity/economy numeric retuning.

Current standard full-catalog baseline: mirrors 22.3/43.6/19.9 s, no timeouts; ~3.7 min matches, 4 day-one / 96 day-30 pulls, first Rare 47 min / Epic 2.1 h / Legendary 9 h. Actual nine-item Kiln odds are filtered/normalized separately; these Rare+ projections assume the full catalog.
