# Roadmap

Tick items as they're done (`- [x]`). One milestone at a time. Design: [GAME_DESIGN v0.3](GAME_DESIGN.md).
**Current milestone: F5 — integration polish.** Wave1 imports, fitted fences and the native multiplayer/security pass are complete. Real-phone checks, final UI artwork and publishing remain with the creator; Marble packs, gamepasses and Marble Kiln purchases stay disabled; creator-approved match selection spends are implemented.

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
- [ ] **C:** Marble packs, gamepasses and idempotent `ProcessReceipt`; match-selection wallet spends/policy checks completed in F5, paid storefront remains deferred
- [x] **C:** Trophies, Match Wins and Shatters boards; published ordered-store verification pending
- [ ] **C:** Shatter FX shop + 3 effects (paid features deferred under current instructions)
- [ ] **C:** analytics events (GAME_DESIGN 15b)

## F5 — Polish and soft launch (Nov 10–16)

- [x] **C:** once-per-match uniform three-card hand without duplicates, sequential vertical reels, retained hands across rounds, round-only owned Pick Any, escalating Marble prices/confirmation and policy-gated paid rerolls; saved wallet and replay/ownership/deadline guards. 79 Lune/Studio tests plus 75 native server and 117 UI checks pass; editable export/backup and [report](testing/MATCH_SELECTION.md). No device pass.

- [x] **C:** Inventory Owned → Unowned sections for all 31 catalog glassies; dimmed missing portraits, honest artwork placeholders, inspectable powers/base stats, acquisition migration and editable templates/backup. 2,505 native UI checks and 76 logic tests pass; [report](testing/INVENTORY_UNOWNED.md). Device work deferred.

- [x] **C:** UI-only Kiln reels and one shared firing for Open 1/10; transparent overlay, upright centered reward cards, Collect flight to Inventory, original effect assets, editable templates/backups. Existing Coin server flow retained. 733 native presentation checks and 76 logic tests pass; [report](testing/KILN_OPENING.md). Marble/daily purchasing and device work remain deferred.

- [x] **C:** Shop v0.6 UI: Featured daily-offer/showcase preview, Glassies with separate Coin/Marble Kiln models, enlarged rarity lists, preview strips/View All, Finishers/Flyers pages; upright centered portraits throughout UI. Existing Coin flow retained; daily/Marble purchases deferred. Opening completed in the follow-up above. Desktop checks and 76 tests pass; [report](testing/SHOP_V06.md).

- [x] **C:** preserve creator template edits; smaller Inventory/Shop, matching Marble/Inventory icons, repaired removed-Star binding, shop feedback, centered button anchors and interaction animation; grounded pad avatars, outward fixed camera, numeric glass HP, baseline avatar finisher/heart animation, removed result/power overlays. Native bot match/rewards/cleanup verified; 76 logic tests and 303 presentation checks pass. Device work deferred at creator request.
- [x] **C/U:** research and plan original contact/turnaround-triggered powers, 24-glassy shortlist, shared impact/shatter effects and Blender/Studio production split; creator confirms current arena with swing turnarounds. [Research](research/COMBAT_VFX_RESEARCH.md), [roster/work order](design/COMBAT_ROSTER_V1.md). Planning only; proposed kits await review.
- [x] **C/U:** lock release roster to 24, plan revisions to 12 existing Blender models plus 12 new models, research VFX production and write the complete [new-chat handoff](HANDOFF_COMBAT_RELEASE.md) / [execution prompt](prompts/05_combat_release_24.md). Planning only; Blender connection checked read-only.
- [ ] **B/C/U:** produce the four six-glassy batches, shared VFX kit, first-six import/live proof, then all 24 kits and release filtering. Current powers remain live until implementation; special finisher variations remain later work.
- [x] **B:** release batches A–D: 12 original model revisions and 12 first models, versioned editable sources, body/detail/shard/bundle FBXs, 16 closed shards each, regenerated cracks and upright transparent icons. Blender FBX round-trip and source/file QA; [production table](art/combat_release/PROGRESS.md).
- [x] **B/C:** original shared VFX kit: 10 meshes, six static masks, two rendered 4×4 flipbooks, source frames/alpha previews and eight uploaded texture IDs. Isolated developer fixture; native visual timing/readability remains pending.
- [ ] **U/C:** import revised FBX bundles from [batch import list](art/combat_release/BATCH_IMPORT.md), prove Pop/shared kit then all six A kits live; implement shared rules, expand 24 kits and audited release filtering afterward. Local FBX import is not exposed by connected MCP.

- [x] **C:** Stained Glass v0.5 editable Lobby / Inventory / Shop / Choose / Fight templates, 82 uploaded UI assets, v0.4 backup, complete silhouette/label clipping fixes approved, native bot flow and 76 tests pass; [report](testing/UI_V05.md)
- [ ] **U:** restyle the v0.5 StarterGui templates, then authorize the multi-device formatting pass

- [x] **B/C:** original furnace Kiln, three leaderboard frames and island/bridge fences built, imported and placed; corrected against live grass meshes, fence alignment creator-approved; [lobby v2](../assets/blender/map/lobby_v2/README.md)
- [x] **B:** generated original HUD / Inventory / Store concepts and exact prompts; Coins/Marbles, two square main buttons, bottom-center Play and grid/right-details layout; [concepts](ui/concepts/lobby_v2/README.md)
- [x] **C/U:** lobby-v2 import/placement, full lobby/raw-import backups, existing Kiln prompt/leaderboard labels preserved, native-rim alignment and clear center lane verified; [integration report](testing/LOBBY_V2_INTEGRATION.md)
- [ ] **U:** gameplay/bridge/pad/Kiln/board/phone checks, save place and publish; creator will test. Generated menu concepts still require functional UI integration
- [x] **C:** Device Emulator layout pass: A06, iPhone and iPad, 39 states, 14 editable scale-only ScreenGuis; final UI artwork belongs to the creator
- [x] **C:** native two-client PvP + third staggered join, seven moving arenas, dropped snapshots, replay/disconnect and cleanup; [F5 report](testing/F5_MULTIPLAYER_SECURITY.md)
- [x] **C:** remote validation/rate-limit/security review and double-KO cleanup soak; 71 tests pass
- [x] **U/C:** no rewards before a real completed round; native disconnect verifies zero currency and unchanged match stats, 74 tests pass
- [x] **CL:** playtested polish pass: Perfect-band/round-result/ownership fixes, survivor settle, arena state and signs, lobby lane, lighting, Watch any fight, faster forfeit, binary snapshots (−83% payload), render cost −30%; native multiplayer + 39 layouts pass ([report](testing/POLISH_PASS.md))
- [ ] **U:** real low-end-phone performance/MicroProfiler, manual close/gamepad checks, published datastore/leaderboard verification
- [ ] **B:** fixed release art roster: 24 playable glassies, including 12 existing-model revisions and 12 new models; source/export/icon/shard/import checklist in the combat handoff
- [ ] **U:** maturity questionnaire, icon, thumbnails, description; cross-promote from your other game

## After launch

- [ ] Weekly polish/events/codes; roster remains at 24 unless the creator later authorizes expansion
- [ ] Winter event (~Dec 12): snow globes, ornaments, glass reindeer
- [ ] Bracket tournament event, 2v2, party pads, Rainbow "re-melt"
