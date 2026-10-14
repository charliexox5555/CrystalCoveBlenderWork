# Roadmap

Tick items as they're done (`- [x]`). One milestone at a time. Design: [GAME_DESIGN v0.3](GAME_DESIGN.md).
**Current milestone: F3 — Data, Kiln and collection.** Overnight work authorized; real-phone checks and publishing remain with the user.

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
- [ ] **U:** fences, trees, decor; publish

## F1 — Fight prototype (Oct 14–21)

Goal: on Arena 1, aim → release → an erratic, readable 3D fight with spins, pass-bys and powers firing by themselves → a great shatter. **Nothing else until this feels great on a phone.** Prompt: [prompts/01_fight_prototype.md](prompts/01_fight_prototype.md).

- [x] **CL:** rules for auto powers (no button), Rage, aimed powers that can miss, aim yaw, luck/suspense metrics in the simulator (DECISIONS 33–34)
- [x] **C:** `FightService`: 3D pendulum swing (Balance.Motion), wander, deflecting bounces, spin and tumble; hits → `FightRules.hit`; `FightRules.tick`; `PowerLands` from positions
- [x] **C:** stream `FightSnapshot` (20 Hz, unreliable) + `FightEvents`; `SetAim` remote validated and rate-limited
- [x] **C:** `FightController`: interpolated 3D CFrames with twist/tilt, string Beams, follow camera, side-on slow-mo final blow
- [x] **C:** aim input (drag distance + direction, Perfect band, lock), 3-2-1 release
- [x] **C:** Fight HUD: HP bars, cracks, power glow rings, power banners, MISSED!, CRIT!/SMASH!/WHOOSH; effects for every power
- [x] **C:** bot-vs-bot calibration: 80 Lune + 40 Studio rounds; ten live rounds watched; measurements/candidate in [F1 report](testing/F1_FIGHT.md)
- [ ] **CL:** review calibrated SimModel candidate (Jam duration / Prism Blade fairness failures); Fight/Powers values frozen under overnight instructions; passing baseline retained
- [ ] **U:** publish, play on a phone, record a clip, approve the feel

## F2 — Match flow and lobby blockout (Oct 20–26)

- [x] **C:** `ArenaService` pads + queue + bot fill; `MatchService` phases with `MatchLogic`; seven concurrent arenas, free rerolls only
- [x] **C:** Roll screen (3 cards, reroll), Aim, Countdown, Round end (glass heart pops), Results; [F2 report](testing/F2_MATCH_FLOW.md)
- [ ] **B:** sky kit: crystal kit (3 meshes), Kiln crystal, featured arch, clouds (MAP_PLAN / CONCEPT.md "Pieces")

## F3 — Data, Kiln and collection (Oct 27–Nov 2)

- [x] **C:** ProfileStore `DataService` (schema in GAME_DESIGN 14); Studio mock save/reload verified, production session locking integrated
- [x] **C:** `KilnService` + odds-first screen, glassblowing reveal, duplicates → stars; actual pulls gated until non-starter art imports
- [x] **C:** Collection + Index screens; configured completion rewards pending
- [ ] **B:** 9 more glassies (body, details, shards, icon): 6 Commons + 3 Uncommons first
- [ ] **C:** lobby art pass

## F4 — Retention and monetization (Nov 3–9)

- [ ] **C:** daily quests, playtime gifts, login streak, first win bonus, codes, group reward
- [ ] **C:** Marbles, Marble packs, gamepasses, idempotent `ProcessReceipt`, PolicyService checks
- [ ] **C:** Shatter FX shop + 3 effects; leaderboards
- [ ] **C:** analytics events (GAME_DESIGN 15b)

## F5 — Polish and soft launch (Nov 10–16)

- [ ] **C:** phone UI pass (Device Emulator presets), performance (MicroProfiler), exploit and rate-limit pass
- [ ] **B:** remaining launch glassies (target 18+ playable)
- [ ] **U:** maturity questionnaire, icon, thumbnails, description; cross-promote from your other game

## After launch

- [ ] Weekly: 2–3 new glassies + a code
- [ ] Winter event (~Dec 12): snow globes, ornaments, glass reindeer
- [ ] Bracket tournament event, 2v2, party pads, Rainbow "re-melt"
