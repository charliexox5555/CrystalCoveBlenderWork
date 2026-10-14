# Current handoff — 2026-10-14 (evening, Claude polish pass)

**Playtested polish pass complete:** fight clarity fixes, Watch any nearby fight, arena state/signs, lobby lane and lighting, faster forfeit, −83% snapshot bandwidth, −30% fight render cost, and a calibrated simulator. Code is committed and pushed (`634554a` … latest). **World/UI instances live in the place and need a Studio save.** [Full report with before/after screenshots](../testing/POLISH_PASS.md).

## Your next actions

1. **Save the place in Studio now.** This pass changed StarterGui templates (RoundEnd banner, FightHud side stripes, STOP WATCHING), Lighting, added Workspace.Lobby.Paths and levelled one lobby collision slab. Backups: ServerStorage.UIBackups.Polish_2026_10_14 and ServerStorage.WorldBackups.Lighting_2026_10_14. Studio is left in Edit mode.
2. Studio is free for Codex's **lobby-v2 import** (furnace Kiln, leaderboard frames, Blender fences) — see assets/blender/map/lobby_v2/README.md. Claude did not touch the fences, Kiln or leaderboards.
3. On a real phone: a full match (pick → aim for gold → shatter → round banner → results), **Watch** a nearby fight and STOP, and low-end frame rate/MicroProfiler. Gamepad B/close still needs a manual check (MCP cannot press it).
4. Decide on balance note: Rocket Pop / Momentum sits near the fairness floor (real swing 39%). Suggested lever: Momentum +5% per hit instead of +4%. Not applied. Decisions 45–47 are Proposed.
5. Final UI art/styling under **StarterGui**; new styleable elements are listed in [EDITING_UI](../ui/EDITING_UI.md). Publish manually, then verify ProfileStore session locking and global boards in a published server. Group/Index rewards still need your configuration; paid features and free Marbles stay disabled.

## This pass (Claude)

- **Bugs fixed from play:** gold Perfect band was frozen at the template position (PERFECT! could show outside it); round banner and heart pop appeared before the shatter; no way to tell your glassy in mirror matches (now owner names, pad-coloured stripes and an in-world YOU ▼); survivor froze mid-air; distant fights froze; reset forfeited 5 s late; invisible 1.4-stud ledge on the spawn→bridge path; idle arenas had no sign and distant signs stacked; lobby hint stayed up while queued; greyed Kiln pulls gave no reason; every bot was "Glint Bot".
- **New:** Watch prompt at each busy stand (camera + HUD, follows rounds, STOP WATCHING); pad glows open/waiting/busy; countdown ticks, release whoosh, heart-pop sound; stepping-stone lane with spurs to every pad; calmer saturation with low bloom.
- **Performance:** 7 fights — fight render 0.80 → 0.55 ms mean, max 4.0 → 2.8 ms; idle Highlights 14 → 0; snapshot payload ~750 → 128 bytes. Desktop numbers; the earlier "15 FPS" client samples were Studio throttling an unfocused/minimized window.
- **Calibration:** the F1 candidate's failures were model artifacts. Real swing: Jam mirrors 33–35 s, Prism Blade 55%. FightModel is now size- and slowdown-aware, fitted to 31 real mirrors; tests pass honestly. [Review](../testing/CALIBRATION_REVIEW.md).
- **Verified:** 76 tests in Lune and Studio; native two-client PvP/drop/replay/disconnect/late-join with zero errors; 39 layout states on A06/iPhone/iPad; simulators run (economy unchanged).

## Earlier: fences, Wave1 and the reward rule


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

## Calibration (resolved)

The measured F1 candidate's failures (Jam mirror 45.9 s, Prism Blade 63%) came from the stand-in model, not the game: on the real integrator Jam mirrors last 33–35 s and Prism Blade wins 55%. FightModel now uses a size- and slowdown-aware pass-by chance fitted to 31 real mirrors; all tests pass without retuning Fight/Powers/rarity/economy. Evidence and reproduce steps: [CALIBRATION_REVIEW.md](../testing/CALIBRATION_REVIEW.md).
