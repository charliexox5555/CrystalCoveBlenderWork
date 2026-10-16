# Roadmap

Tick items as they're done (`- [x]`). One milestone at a time. Design: [GAME_DESIGN v0.3](GAME_DESIGN.md).
**Current milestone: F5 — integration polish.** Wave1 imports, fitted fences and the native multiplayer/security pass are complete. Real-phone checks, final UI artwork and publishing remain with the creator; Marble packs, gamepasses and Marble Kiln purchases stay disabled; creator-approved match selection spends are implemented.

- [x] **C:** creator selection/finish notes: longer preparation, one-tap reroll/Pick Any with inline odds and future-store hook, cleaner animated reels/selection, ghost-preview/detail cleanup, visible avatar impact and reset/zoom/return camera. 100 logic, 154 UI, 179 finish, 75 server and 4 power-number checks pass; [report](testing/combat_release/SELECTION_FINISH_POLISH.md), [24 powers/brainstorm](design/POWER_BRAINSTORM_24.md). Creator reviews feel and saves/publishes the place.

- [x] **C:** stronger signature mesh/shot/cone/pulse/orbit effects, returning Prism Blade and retained stored charges; creator-requested full-circle horizontal fight camera. 99 logic, 32 camera and 264 native presentation checks pass; one live orbit/cleanup check and 48 deterministic swings. [Review/controls](testing/combat_release/SPECTACLE_ORBIT.md); creator tests feel and real touch/gamepad performance.

- [x] **C:** creator's first-six feedback: glassy-following numeric HP, complete popup text/stroke fade, stronger contact/charge/release/block effects and fast-swing trails. 88 logic tests and 46 isolated native presentation checks pass; [checkpoint](testing/combat_release/FIRST_SIX_CHECKPOINT.md). Historical first-six checkpoint; all 24 kits are now integrated (see F5).

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
- [x] **C:** Finisher/Flyer Coin/Marble crate shops, matching owned/unowned inventories, duplicate counts and category opening effects; creator-approved provisional prices, policy-gated Marble spends, no Robux storefront. [Report](testing/CRATE_SHOPS.md); phone/feel review remains.
- [ ] **C:** analytics events (GAME_DESIGN 15b)

## F5 — Polish and soft launch (Nov 10–16)

- [x] **C:** creator shop feedback: repair looping prize-card anchors/backgrounds/nameplates; reuse stained-glass gem controls; fit/rescale both viewport axes and face the capsules forward. Editable templates and recovery export saved. 111 logic / 68 focused UI checks plus real mock purchases, duplicate save/reload, replay/policy/error handling pass; [report](testing/CRATE_SHOPS.md). No device or publication pass.

- [x] **C:** original riding keyframes, modern R15/R6 support, foot/seat contact and animation restoration; distinct finisher timing/texture layers. 655 pose, 32 lifecycle, 193 finisher and 1330 preview checks pass. Four Blender flyers/five mesh-VFX sources exported and FBX round-trip verified.
- [x] **C/U:** creator imports [Blender hero bundle](../assets/blender/round_cosmetics/hero_v2/README.md); install permanent meshes at normalized scale, refresh four lobby displays, record 32 mesh IDs and save native recovery snapshot. All 32 assets load; 193 finisher/1330 preview/32 lifecycle checks pass, native ray rider motion/exit verified. Creator normal-camera feel/phone review remains. Overnight schedule paused by request.

- [x] **C:** final bounded overnight follow-up: late-arriving ride models/animated parts now register; stage removal/rearrival clears listeners/references. 32 focused native lifecycle checks pass; live forced next-round motion and avatar restoration verified. Normal device/feel review remains creator work.

- [x] **C:** overnight follow-up: fit animated finisher previews to both axes instead of clipping them with icon framing; resize/replay/selection/close cleanup verified in a focused five-effect native fixture. Authored layout/native art and combat unchanged.

- [x] **C:** overnight lobby composition/gardens/wayfinding/glare pass; four functional match rides, five distinct cosmetic finishers and free earned/equipped Inventory/Shop catalogs. Profile ownership/rate guards, frozen match equipment and avatar restoration. 106 logic, 301 cosmetic / 179 finish checks, live round and mock save/reload pass; [report/recovery](testing/overnight/README.md). Creator feel/milestone/device review remains.

- [x] **C:** clearer Pop cap/pressure/recoil, Jam real lid/block, Prism aimed lens/white ray/afterglow, corrected actual Axe sweep/trail and shared impact spokes/rings. Creator-requested Hourglass spinning self-heal: 7% maximum HP twice, below 65%, eight-second cooldown and no overtime. 102 logic tests, 31 hero / 264 presentation / 179 finish checks, 48 real-swing regression rounds pass; [readability report](testing/combat_release/POWER_READABILITY_V3.md). Feel, full fairness and phone review remain open.

- [x] **C:** once-per-match uniform three-card hand without duplicates, sequential vertical reels, retained hands across rounds, round-only owned Pick Any, escalating Marble prices/confirmation and policy-gated paid rerolls; saved wallet and replay/ownership/deadline guards. 79 Lune/Studio tests plus 75 native server and 117 UI checks pass; editable export/backup and [report](testing/MATCH_SELECTION.md). No device pass.

- [x] **C:** Inventory Owned → Unowned sections for all 31 catalog glassies; dimmed missing portraits, honest artwork placeholders, inspectable powers/base stats, acquisition migration and editable templates/backup. 2,505 native UI checks and 76 logic tests pass; [report](testing/INVENTORY_UNOWNED.md). Device work deferred.

- [x] **C:** UI-only Kiln reels and one shared firing for Open 1/10; transparent overlay, upright centered reward cards, Collect flight to Inventory, original effect assets, editable templates/backups. Existing Coin server flow retained. 733 native presentation checks and 76 logic tests pass; [report](testing/KILN_OPENING.md). Marble/daily purchasing and device work remain deferred.

- [x] **C:** Shop v0.6 UI: Featured daily-offer/showcase preview, Glassies with separate Coin/Marble Kiln models, enlarged rarity lists, preview strips/View All, Finishers/Flyers pages; upright centered portraits throughout UI. Existing Coin flow retained; daily/Marble purchases deferred. Opening completed in the follow-up above. Desktop checks and 76 tests pass; [report](testing/SHOP_V06.md).

- [x] **C:** preserve creator template edits; smaller Inventory/Shop, matching Marble/Inventory icons, repaired removed-Star binding, shop feedback, centered button anchors and interaction animation; grounded pad avatars, outward fixed camera, numeric glass HP, baseline avatar finisher/heart animation, removed result/power overlays. Native bot match/rewards/cleanup verified; 76 logic tests and 303 presentation checks pass. Device work deferred at creator request.
- [x] **C/U:** research and plan original contact/turnaround-triggered powers, 24-glassy shortlist, shared impact/shatter effects and Blender/Studio production split; creator confirms current arena with swing turnarounds. [Research](research/COMBAT_VFX_RESEARCH.md), [roster/work order](design/COMBAT_ROSTER_V1.md). Planning only; proposed kits await review.
- [x] **C/U:** lock release roster to 24, plan revisions to 12 existing Blender models plus 12 new models, research VFX production and write the complete [new-chat handoff](HANDOFF_COMBAT_RELEASE.md) / [execution prompt](prompts/05_combat_release_24.md). Planning only; Blender connection checked read-only.
- [x] **B/C:** four six-glassy batches, shared VFX kit, all 24 live signature kits and release filtering integrated. Previous live models preserved; normal matches use the revised roster. [Full integration](testing/combat_release/FULL_RELEASE.md).
- [ ] **U/C:** review all 24 at normal speed, tune actual equal-stat matchups, extend performance/phone coverage and publish. First five finisher variations installed; further cosmetics remain optional later work.
- [x] **B:** release batches A–D: 12 original model revisions and 12 first models, versioned editable sources, body/detail/shard/bundle FBXs, 16 closed shards each, regenerated cracks and upright transparent icons. Blender FBX round-trip and source/file QA; [production table](art/combat_release/PROGRESS.md).
- [x] **B/C:** original shared VFX kit: 10 meshes, six static masks, two rendered 4×4 flipbooks, source frames/alpha previews and eight uploaded texture IDs. Isolated developer fixture; native visual timing/readability remains pending.
- [x] **U/C:** import all 24 revised bundles/shared kit; correct measured 100× import scale and baked yaw, anchor all 527 imported parts, stage canonical models and eight named texture references. 4,763 native checks, first-six fixed-camera art review and recoverable RBXM snapshots; [report](testing/combat_release/IMPORT_NORMALIZATION.md).
- [x] **C:** all 24 client VFX/rule kits enabled, revised art promoted, truthful ability copy and full 21-item Coin Kiln pool. 97 Lune/Studio tests, 264 all-model presentation checks, 48 actual swing rounds and two-client/seven-fight/rejoin/cleanup QA. Creator review and final balance/device coverage remain.
- [x] **C:** editable native VFX template library for 24 kits, first-six staged client previews, native flipbook progression/cleanup and 14 replacement audio candidates with onset cuts; 612 template checks, recoverable RBXM and [report](testing/combat_release/VFX_AUDIO_PROTOTYPES.md). Rojo connection subsequently resolved; subjective audio review remains pending.
- [x] **C:** first-six signature prototype code, validated turnaround/ray/sweep foundations, revised-geometry/crack support and refreshed audio playback. Historical [checkpoint](testing/combat_release/FIRST_SIX_CHECKPOINT.md) superseded by full integration above; global signatures are now enabled. Creator handles hands-on feel review.

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
