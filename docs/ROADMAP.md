# Roadmap

Tick items as they're done (`- [x]`). One milestone at a time. Design: [GAME_DESIGN v0.3](GAME_DESIGN.md).
**Current milestone: F5 — integration polish.** Wave1 imports, fitted fences and the native multiplayer/security pass are complete. Real-phone checks, final UI artwork and publishing remain with the creator; paid features stay disabled.

Owner key: **C** = Codex (code / Studio MCP), **B** = Codex with Blender MCP, **CL** = Claude (research, design, pure rules, docs), **U** = you.

## F0 — Restructure (Claude, Oct 13)

- [x] **CL:** Ball VS Ball research brief ([research/BALL_VS_BALL.md](research/BALL_VS_BALL.md))
- [x] **CL:** GAME_DESIGN v0.3, DECISIONS 22–29, ECONOMY, this roadmap
- [x] **CL:** pure rules: `FightRules` (damage, powers, specials, shatter, timeout), `MatchLogic` (roll, reroll, pick, aim, hearts, rewards, bots), `Formula` (stats, types, Kiln), `Config/Powers`, 31 glassies with powers
- [x] **CL:** balance + economy simulators and tests (`lune run tools/run_tests`, `balance_sim`, `economy_sim`)
- [x] **CL:** removed the meter battle, trainers, zones, Kilnport map tools (all in git history)
- [x] **CL:** lobby map concepts ([art/MAP_PLAN.md](art/MAP_PLAN.md))
- [x] **U:** picked the lobby: **Crystal Isles** (sky islands)
- [ ] **U:** answer the open questions in GAME_DESIGN 17 (rerolls, free pick, names)

## L1 — Sky lobby (Oct 13–15)

Prompt: [prompts/02_sky_lobby.md](prompts/02_sky_lobby.md).

- [x] **B:** 5 floating island platforms (grass / dirt / rock), exported to `assets/blender/map/sky/` with manifest and preview
- [x] **U:** back up the place, import the 5 FBX files
- [x] **C:** clear the old place (keep code, glassies, ClashStand, audio, icons; old props → `ServerStorage.LegacyKit`)
- [x] **C:** place islands, invisible collision, placeholder bridges, lighting and sky
- [x] **C:** 7 arena stands (hooks at ±3), tagged queue pads and lobby spots, SpawnLocation, FallService
- [x] **C:** walk test, phone check, screenshots ([L1 report](testing/L1_SKY_LOBBY.md); user approved the look and requested finish)
- [x] **C:** fit creator's fence style around all five islands and bridges; preserve originals, verify edge collision and all-pad walk route
- [ ] **U:** trees/final decor, save place and publish

## F1 — Fight prototype (Oct 14–21)

Goal: on Arena 1, aim → release → an erratic, readable 3D fight with spins, pass-bys and powers firing by themselves → a great shatter. **Nothing else until this feels great on a phone.** Prompt: [prompts/01_fight_prototype.md](prompts/01_fight_prototype.md).

- [x] **CL:** rules for auto powers (no button), Rage, aimed powers that can miss, aim yaw, luck/suspense metrics in the simulator (DECISIONS 33–34)
- [x] **C:** `FightService`: 3D pendulum swing (Balance.Motion), wander, deflecting bounces, spin and tumble; hits → `FightRules.hit`; `FightRules.tick`; `PowerLands` from positions
- [x] **C:** stream `FightSnapshot` (20 Hz, unreliable) + `FightEvents`; `SetAim` remote validated and rate-limited
- [x] **C:** `FightController`: interpolated 3D CFrames with twist/tilt, string Beams, follow camera, side-on slow-mo final blow
- [x] **C:** aim input (drag distance + direction, Perfect band, lock), 3-2-1 release
- [x] **C:** Fight HUD: HP bars, cracks, power glow rings, power banners, MISSED!, CRIT!/SMASH!/WHOOSH; effects for every power
- [x] **C:** bot-vs-bot calibration: 80 Lune + 40 Studio rounds; ten live rounds watched; measurements/candidate in [F1 report](testing/F1_FIGHT.md)
- [x] **CL:** review calibrated SimModel candidate: failures were model artifacts (real Jam mirrors 33–35 s, Prism Blade 55%); size/slow-aware FightModel fitted to the real swing, 76 tests pass, no Fight/Powers changes ([review](testing/CALIBRATION_REVIEW.md))
- [ ] **U:** publish, play on a phone, record a clip, approve the feel

## F2 — Match flow and lobby blockout (Oct 20–26)

- [x] **C:** `ArenaService` pads + queue + bot fill; `MatchService` phases with `MatchLogic`; seven concurrent arenas, free rerolls only
- [x] **C:** Roll screen (3 cards, reroll), Aim, Countdown, Round end (glass heart pops), Results; [F2 report](testing/F2_MATCH_FLOW.md)
- [x] **B/C:** sky kit exported/imported/placed: crystal kit, Kiln hero, featured arch and clouds

## F3 — Data, Kiln and collection (Oct 27–Nov 2)

- [x] **C:** ProfileStore `DataService` (schema in GAME_DESIGN 14); Studio mock save/reload verified, production session locking integrated
- [x] **C:** `KilnService` + odds-first screen, glassblowing reveal, duplicates → stars; native nine-item pool, single/ten pulls and quote replay rejection verified
- [x] **C:** Collection + Index screens; configured completion rewards pending
- [x] **B/C:** 9 more glassies exported/imported (body, details, 16 shards, cracks, 512 icon): native pivots, portraits, cracks/shatter verified; 12 playable total
- [x] **C:** first lobby art pass: fitted fences/bridge rails, normalized sky kit, native Kiln hero, featured arch, crystals/clouds

## F4 — Retention and monetization (Nov 3–9)

- [x] **C:** daily quests, playtime gifts, login streak tracking (no free Marbles), first win bonus, Studio test code; [F4 report](testing/F4_FREE_RETENTION.md)
- [ ] **U/C:** group reward: owner group ID and permitted reward configuration pending; free Marbles disabled
- [ ] **C:** Marbles, Marble packs, gamepasses, idempotent `ProcessReceipt`, PolicyService checks
- [x] **C:** Trophies, Match Wins and Shatters boards; published ordered-store verification pending
- [ ] **C:** Shatter FX shop + 3 effects (paid features deferred under current instructions)
- [ ] **C:** analytics events (GAME_DESIGN 15b)

## F5 — Polish and soft launch (Nov 10–16)

- [x] **B:** original furnace Kiln, three leaderboard frames, five irregular island fence assemblies and four bridge assemblies; saved sources/FBX/previews/manifests and geometry QA in [lobby v2](../assets/blender/map/lobby_v2/README.md); built only, not installed
- [x] **B:** generated original HUD / Inventory / Store concepts and exact prompts; Coins/Marbles, two square main buttons, bottom-center Play and grid/right-details layout; [concepts](ui/concepts/lobby_v2/README.md)
- [ ] **C/U:** after Claude's Studio handover, back up/import lobby v2, preserve prompts/board text/safety collision and verify live placement, all-pad walk and phone readability; concepts still require functional UI integration
- [x] **C:** Device Emulator layout pass: A06, iPhone and iPad, 39 states, 14 editable scale-only ScreenGuis; final UI artwork belongs to the creator
- [x] **C:** native two-client PvP + third staggered join, seven moving arenas, dropped snapshots, replay/disconnect and cleanup; [F5 report](testing/F5_MULTIPLAYER_SECURITY.md)
- [x] **C:** remote validation/rate-limit/security review and double-KO cleanup soak; 71 tests pass
- [x] **U/C:** no rewards before a real completed round; native disconnect verifies zero currency and unchanged match stats, 74 tests pass
- [ ] **U:** real low-end-phone performance/MicroProfiler, manual close/gamepad checks, published datastore/leaderboard verification
- [ ] **B:** remaining launch glassies (target 18+ playable)
- [ ] **U:** maturity questionnaire, icon, thumbnails, description; cross-promote from your other game

## After launch

- [ ] Weekly: 2–3 new glassies + a code
- [ ] Winter event (~Dec 12): snow globes, ornaments, glass reindeer
- [ ] Bracket tournament event, 2v2, party pads, Rainbow "re-melt"
