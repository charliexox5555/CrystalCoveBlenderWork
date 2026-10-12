# Roadmap

Tick items as they're done (`- [x]`). One milestone at a time. Dates are targets from GAME_DESIGN 14.
**Current milestone: M1 — Feel prototype.**

Owner key: **C** = Codex (code / Studio MCP), **B** = Codex with Blender MCP, **U** = you (the user).

## M0 — Setup (done by Claude, Oct 12)

- [x] Design doc, resources doc, UI mockups in Figma
- [x] Repo structure, AGENTS.md, Rojo project, toolchain files
- [x] Pure game logic: `Balance`, `Formula`, `BattleLogic`, `Rng`, content config (glassies, trainers, zones, cosmetics)
- [x] Tests and balance simulator (`lune run tools/run_tests`, `lune run tools/balance_sim`)
- [x] UI `Theme` tokens matching Figma
- [x] Blender helper script (`tools/blender/glassclash_blender.py`)
- [x] **U:** clone the repo, install Rokit + Rojo, connect Rojo in Studio (README "Setup")

## M1 — Feel prototype (Oct 12–18)

Goal: one Clash Stand, two glassies, the meter, cracks and a great shatter. **Nothing else until this feels great on a phone.**

Art review: all starters and the revised A-frame stand approved and imported.
Scale normalized to Blender measurements; colors/materials assigned in Studio.

- [x] **C:** Rojo connected; `ServerStorage.Tests.RunAll` passes in Studio
- [x] **B:** low-poly Clash Stand (posts, crossbar, hooks) + octagon pen floor and low wall
- [x] **B:** starter glassies `pop`, `jam`, `prism`: body (origin at hang point), 12–20 shards, icon
- [x] **C:** import stand and starters; folder `ReplicatedStorage.Assets.Glassies.<id>` with `Body` + `Shards`
- [ ] **C:** `BattleService` (server): runs a battle with `BattleLogic`, sends each clash to clients, validates `ReleaseSwing`
- [ ] **C:** `BattleController` (client): pendulum animation with CFrame, string `Beam`s, 3/4 battle camera
- [ ] **C:** power meter UI + HOLD button (mobile, PC Space, console button), using `Theme`
- [ ] **C:** crack stages at 75 / 50 / 25 % HP
- [ ] **C:** `ShatterController`: hitstop, camera shake, slow-mo + side-on final shot, flash, shards, sparkles, layered sound
- [ ] **C:** a test NPC on the stand to fight (uses `BattleLogic.npcChooser`)
- [ ] **U:** play it on a phone, record a clip, decide if the shatter feels great

## M2 — Core loop (Oct 19–25)

- [ ] **C:** ProfileStore `DataService` with the schema in GAME_DESIGN 13.2
- [ ] **C:** starter pick screen; glassy follows the player like a pet
- [ ] **C:** NPC trainers from `Config/Trainers` (Zone 1), daily cooldowns, rewards
- [ ] **C:** XP, levels, evolution at level 15 / 35 (big transformation moment)
- [ ] **C:** Repair Bench with reverse-shatter animation
- [ ] **B:** Zone 1 "Recycling Yard" low-poly kit + layout (MAP_PLAN)
- [ ] **B:** evolution forms `rocket_pop`, `honey_bear`, `prism_blade`

## M3 — Catching and collection (Oct 26–Nov 1)

- [ ] **C:** wild glassies (spawns from `Config/Zones`), Cork catching
- [ ] **C:** coin crate with odds screen; `PolicyService` check
- [ ] **C:** Glassies inventory screen (Figma), Index screen
- [ ] **B:** Zone 1 wild glassies + crate roster (about 18 models with shards and icons)

## M4 — Tournaments and social (Nov 2–8)

- [ ] **C:** lobby tournament (8-slot bracket, bots, Rookie/Open cups, Pick the Winner, Champion Pedestal)
- [ ] **C:** PvP challenges
- [ ] **C:** Shatter FX and Fills cosmetics
- [ ] **B:** lobby "Glass Town" low-poly + octagon arena + bracket board

## M5 — Monetization and polish (Nov 9–15)

- [ ] **C:** gamepasses, dev products, `ProcessReceipt`
- [ ] **C:** daily login, quests, playtime gifts, group reward, codes
- [ ] **C:** final UI skin (texture kit), loading screen (RESOURCES 6)
- [ ] **C:** analytics events (GAME_DESIGN 15)
- [ ] **U:** test on low-end phone; MicroProfiler check

## M6 — Soft launch (Nov 16–22)

- [ ] **U:** maturity questionnaire, thumbnails, icon, description
- [ ] **U:** cross-promote from existing game
- [ ] **C:** fix issues from analytics and player reports

## M7+ — Updates

- [ ] Update 1: Zone 2 Sunny Beach (late Nov – early Dec)
- [ ] Winter event: snow globes, ornaments, glass reindeer (~Dec 12)
