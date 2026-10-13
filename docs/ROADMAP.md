# Roadmap

Tick items as they're done (`- [x]`). One milestone at a time. Design: [GAME_DESIGN v0.3](GAME_DESIGN.md).
**Current milestone: F1 — Fight prototype.**

Owner key: **C** = Codex (code / Studio MCP), **B** = Codex with Blender MCP, **CL** = Claude (research, design, pure rules, docs), **U** = you.

## F0 — Restructure (Claude, Oct 13)

- [x] **CL:** Ball VS Ball research brief ([research/BALL_VS_BALL.md](research/BALL_VS_BALL.md))
- [x] **CL:** GAME_DESIGN v0.3, DECISIONS 22–29, ECONOMY, this roadmap
- [x] **CL:** pure rules: `FightRules` (damage, powers, specials, shatter, timeout), `MatchLogic` (roll, reroll, pick, aim, hearts, rewards, bots), `Formula` (stats, types, Kiln), `Config/Powers`, 31 glassies with powers
- [x] **CL:** balance + economy simulators and tests (`lune run tools/run_tests`, `balance_sim`, `economy_sim`)
- [x] **CL:** removed the meter battle, trainers, zones, Kilnport map tools (all in git history)
- [x] **CL:** lobby map concepts ([art/MAP_PLAN.md](art/MAP_PLAN.md))
- [ ] **U:** pick a lobby concept; answer the open questions in GAME_DESIGN 17

## F1 — Fight prototype (Oct 13–19)

Goal: one Clash Stand, two glassies swinging and smashing with powers, aim, the special button and a great shatter. **Nothing else until this feels great on a phone.** Prompt: [prompts/01_fight_prototype.md](prompts/01_fight_prototype.md).

- [ ] **C:** `FightService`: server pendulum swing (Balance.Motion), hit detection → `FightRules.hit`, `FightRules.tick`, powers applied to the motion (swingMultiplier / isFrozen / knockbackMultiplier)
- [ ] **C:** stream `FightSnapshot` (20 Hz, unreliable) + `FightEvents`; `UseSpecial` remote validated and rate-limited
- [ ] **C:** `FightController`: interpolated CFrame animation of anchored glassies, string Beams, 3/4 camera, side-on slow-mo final blow
- [ ] **C:** aim input (drag the glassy back on its arc, Perfect band, lock), 3-2-1 release
- [ ] **C:** Fight HUD: HP bars, crack stages, SPECIAL button with charge ring, power popups, CRIT!/SMASH!
- [ ] **C:** reuse `ShatterController` + `CrackPaths`; effects for each special
- [ ] **C:** debug command: bot vs bot on the stand with any two glassy ids; log hits/s and average speed and update `Balance.SimModel`
- [ ] **U:** publish, play on a phone, record a clip, approve the feel

## F2 — Match flow and lobby blockout (Oct 20–26)

- [ ] **C:** `ArenaService` pads + queue + bot fill; `MatchService` phases with `MatchLogic`
- [ ] **C:** Roll screen (3 cards, reroll), Aim, Countdown, Round end (glass heart pops), Results
- [ ] **C:** lobby blockout in Studio from the chosen concept; 8 arena stands along the path
- [ ] **B:** any Blender kit pieces the chosen concept needs (MAP_PLAN)

## F3 — Data, Kiln and collection (Oct 27–Nov 2)

- [ ] **C:** ProfileStore `DataService` (schema in GAME_DESIGN 14)
- [ ] **C:** `KilnService` + Kiln screen with the odds list, glassblowing reveal, duplicates → stars
- [ ] **C:** Collection + Index screens
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
