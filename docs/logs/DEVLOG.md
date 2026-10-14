# Dev log

Newest at the top. One entry per work session. Keep it short.

```
## YYYY-MM-DD — <agent or person> — <milestone>
Done:
- ...
Next:
- ...
Problems / questions for the user:
- ...
Balance sim (if balance changed):
- ...
```

## 2026-10-14 — Codex — F3 backend / profile storage
Done:
- Reviewed all 2,243 lines of official ProfileStore; pinned unmodified source/Apache license/hash in docs/vendor. Added session ownership, cancellation/release/BindToClose integration, schema reconciliation, starters, one-time match rewards, observed fight stats and private-field-free snapshots. Studio uses isolated mocks; production fails closed on profile load failure.
- Added duplicate stars/overflow coins and welcome eligibility; coin Kiln backend uses pure Formula with an optional available-art set, filtered/normalized odds, single-use quotes, validation and limiting. Default formulas/numbers remain unchanged. Added an original native-Part Kiln placeholder through a reproducible installer without touching manual decor.
- Lune/Studio: 65 passed, 0 failed. Mock save/reload retained 321 coins and Pop ★1. Studio API access is off (expected ProfileStore probe message); fallback verified. Starter-only pool rejected a pull, retained 321 coins and 0 pulls. Fixed a legacy-star reconciliation bug caught by the new tests. Vendor hash verified unchanged.
Next:
- Kiln reveal/collection/index/Lobby UI, then the broader device pass, Blender exports and free retention.
Problems:
- No non-starter art is installed, so production coin pulls remain unavailable until manual imports. Recorded normal-reward forfeits for Claude's eligibility review; no economy retune. Source/decision detail: Proposed 37 and MORNING.md.

## 2026-10-14 — Codex — F2 seven-arena match flow
Done:
- Added ArenaService queues/bot fill/step-off/Leave/Play Again and runtime arena labels; MatchRunner/MatchService orchestrate all phases via MatchLogic, with free-only rerolls, ownership/phase validation, common remote limiting, reset/disconnect forfeits and one-time completion.
- Generalized FightService and client FightView to concurrent arenas, side-A/B aiming, local camera/label/audio focus and nearby spectator updates. Rolls/bots use installed assets only. Added Roll/Queue/Results screens with spinning starter portraits, heart tracking and session rewards. Reduced visual tumble cap for clearer pass-bys; no fight/economy rule values changed.
- Lune/Studio: 60 passed, 0 failed. Native queue/leave/card/lock/results/requeue checks; phone side-B Perfect + LOCK; seven matches completed concurrently with no gameplay Output errors, ~60 desktop FPS over 5 s (max frame 18.4 ms). Reset cleanup verified. Studio returned to default viewport. Evidence: docs/testing/F2_MATCH_FLOW.md.
Next:
- F3 ProfileStore, coin Kiln and collection/index; then full UI/device pass and Blender exports. Real phone and publishing stay with the user.
Problems:
- No current blocker. Two-client integration remains on the later bug-hunt pass. Only three starter assets are installed; no unimported glassy enters a normal roll.
Simulators (unchanged rules):
- Mirrors 20–44 s, 0% timeouts, side bias 49%; starter triangle 66/69/64%; Perfect vs worst 67%; equal-stat field 39–60%. Economy ~3.7 min/match, 4 pulls day 1 / 96 day 30, Rare 47 min / Epic 2.1 h / Legendary 9 h, 20% Mythic in 30 days. Full reports: F2_balance.txt, F2_economy.txt. F1 calibration candidate still awaits Claude.

## 2026-10-14 — Codex — F1 fight prototype and overnight continuation
Done:
- Built server 60 Hz / three-substep spherical pendulums with seeded wander, reciprocal guidance, bounces, spin and tumble; FightRules owns hits/powers/KO. Added validated/rate-limited aim, compact 20 Hz snapshots, reliable timed events, Hermite rendering, strings, aim/ghost/Perfect/LOCK, HUD charge rings, all passive/power cues, cracks, sound layers, big-hit hitstop/shake/haptics, side-on shatter and heart pop.
- Corrected scaled details/shards/cracks and duplicate angular-velocity restoration in ShatterController. Added Studio-only replay/calibration/live-watch helpers. No manual lobby edits changed. Motion/presentation choice recorded as Proposed 35.
- Lune/Studio: 55 passed, 0 failed. iPhone 17 Pro landscape input/visual checks pass. Final ten live rounds: no Output errors, 13.93–43.57 s, one double KO. Invalid aim rejected; cancel restored camera and removed local scene/HUD. Report/evidence: docs/testing/F1_FIGHT.md.
Next:
- Standing overnight permission: continue F2 on seven arenas, then data/Kiln/UI/art/free retention. User publishing and real-phone check remain pending; exact handoff in MORNING.md.
Problems:
- Measured SimModel candidate fails Jam mirror duration (45.882 s) and Prism Blade fairness (63%); recorded for Claude and restored passing baseline. No Fight/Powers/rarity/economy retuning. Debug IDs without art use tinted starter proxies; normal rolls will require imported assets.
Calibration / simulators:
- Actual integrator: 80 Lune + 40 Studio rounds, 0 timeouts; .461–.467 hits/s, ~36% pass-bys; median speed 20.45–20.67, shareA ~.499; median round 31.55–32.56 s. Lune aimed powers 66/99 landed. Candidate/baseline reports preserved in docs/testing/.
- Passing baseline balance: mirrors 20–44 s, 0% timeouts, side bias 49%; starters pop>jam 66%, jam>prism 69%, prism>pop 64%; Perfect vs worst 67%; 59% comebacks, 2.0 lead changes, 2.4 powers/glassy; 37% aimed misses; equal-stat powers 39–60%.
- Economy unchanged: ~3.7 min/match; 4 pulls day 1, 96 by day 30; first Rare ~47 min, Epic 2.1 h, Legendary 9 h; 20% Mythic in 30 days.

## 2026-10-14 — Claude — Auto powers and erratic 3D swing (rules + F1 prompt)
Done:
- User: no power button; powers should fire at random moments (e.g. Rage +75% for a few seconds) so luck and suspense drive rounds like Ball VS Ball; swings should be erratic 3D with pass-bys, deflections and spin. DECISIONS 33–34.
- FightRules: powers fire by themselves (random first wait 5–14 s, repeats 9–18 s, max 3, hits bring them closer; placeholder formula), aimed powers (Beam, Freeze) can miss via a `PowerLands` callback from the swing code (LandChance in the sim), new Rage power (hot_sauce, grizzly_guardian), frozen glass is brittle, aim yaw. UseSpecial remote removed.
- Balance.Motion gained 3D starting values (wander, deflect, spin, tumble, AimYawMax). SimModel adds swing-throughs (MissChance 0.3). Simulator reports comebacks, lead changes, powers per round and miss rate; tests check them. 52 tests pass.
- GAME_DESIGN v0.3.1 (luck pillar, 3D swing, powers), UI_SPEC (no buttons; power banners, glow rings, MISSED!), AGENTS, ROADMAP F1, rewritten F1 prompt for Codex.
Next:
- Codex builds F1 on Arena 1 and calibrates SimModel from bot-vs-bot rounds.
Balance sim (200 rounds per matchup, FightModel stand-in):
- Mirrors 20–44 s (12–26 hits), 0% timeouts, side bias 49%. Luck: winner was behind at some point in 59% of rounds, 2.0 lead changes a round, 2.4 powers per glassy per round, 37% of aimed powers miss. Starters: pop>jam 66%, jam>prism 69%, prism>pop 64%. Perfect vs worst aim 67%. Fizzy ladder vs Common: Rare 83%, Legendary 88%, Mythic 91%; 5 stars vs 0: 81%. Equal-stat power table 39–60%.

## 2026-10-14 — Codex — L1 Part B sky lobby handoff
Done:
- Recorded 3,202-instance keep/move/delete inventory; salvaged eight prop prototypes to LegacyKit, preserved imported art/Rojo, moved PlayerReference and LightingPreset to Unsorted, cleared the old map/terrain/lighting.
- Corrected island importer scale, placed flat collision, four placeholder bridges, seven stands, fourteen tagged pads, lobby spots/spawn, gradient sky and golden-afternoon lighting. Added server FallService through Rojo. Normalized hooks to six studs, including a final hook-only correction after user stand resizing; preserved their new fences and all other manual edits.
- Full original-layout walk: 33 waypoints, zero failures. Reduced nominal gaps 5→4 studs to bring the featured pad entry from 14.17→13.92 s. Shortened retest reached 14 waypoints without failures before the user stopped play and asked to finish. Final static ground checks pass. All five fall rescues preserved health. iPhone 17 Pro landscape ~60 FPS in desktop emulator; clear row view. Lune/Studio: 51 passed, 0 failed; play console clean.
- Lobby budget: 584 descendants, 17,846 imported-mesh triangles plus native primitive geometry (~20–22k visible total). Full report, inventory, screenshots and asset IDs in docs/testing/L1_SKY_LOBBY.md and assets/blender/map/sky/studio_assets.json.
Next:
- User completes fences/decor and publishes from Studio. L1 implementation finished; F1 fight prototype is next when requested.
Problems / questions for the user:
- No blocker. Studio left in Edit; device simulation off. Windows Application Control blocked StyLua, so the small service was formatted manually. Do not rerun the initial builder over manual edits.
Balance/economy simulators (Balance only gained Lobby settings):
- Mirrors 20.8–39.0 s, 0% timeouts, side bias 50%; pop>jam 64%, jam>prism 76%, prism>pop 62%; Perfect vs worst 61%, special use 70%. Economy ~3.7 min/match, 4 pulls day 1 / 96 by day 30; first Rare ~47 min, Epic 2.1 h, Legendary 9 h; 20% obtain Mythic in 30 days.

## 2026-10-13 — Codex — L1 Part A island platforms
Done:
- Built five Crystal Isles platforms only: exact 96×56 / 92×46 / 72×48 grass footprints, flat Z=0 tops, 1.4-stud grass, inset 2.5-stud dirt bands, and 30–34-stud faceted rock undersides. Arena variants have distinct rims, ledges, depths and 2–4 connected hanging chunks; Featured has a rounder outline.
- Saved five FBXs using the unchanged glassy export helper, isolated asset scenes plus the row preview in `sky_islands.blend`, local bounds/top-centre origins and Part B positions in `manifest.json`, and manual import instructions. Reviewed renders and improved camera, matte lighting, rim variation and chunk proportions. Added reproducible build/validation scripts.
- All 15 meshes pass closed-manifold, winding, positive-volume, nondegenerate-triangle and self-intersection checks. Grass tops are exactly flat. 4,210 triangles total; largest mesh 536. Saved-source/FBX round trips preserve all vertices/bounds within 0.000005 studs and all pivots at zero; results in `validation.json`. Lune: 51 passed, 0 failed.
Next:
- User backs up the place, imports the five FBXs with Studs scale / separate meshes / imported pivots / anchored, then says “islands imported, backup done” to begin Part B.
Problems / questions for the user:
- None. Studio was not accessed; import, collision and placement testing are deliberately deferred to Part B. No new design decisions. Existing unrelated untracked assets were left untouched.

## 2026-10-13 — Claude — F0 restructure (lobby arena matches)
Done:
- User pivoted to a Ball VS Ball-style structure: simple linear lobby, arena pads, 1v1, 3 hearts, roll 3 from your collection (gem/Marble rerolls), aim, release, watch, one special tap. Research brief in docs/research/BALL_VS_BALL.md (sources could only be read as search snippets; marked unverified).
- New pure rules: FightRules (damage from hit speed/share/mass/type/crit, 9 passives, 6 specials, double KO, overtime, timeout), MatchLogic (rolls, rerolls, picks, aim, hearts, rewards, bot collections and counter-picks), Formula trimmed (stats, stars, types, crits, Kiln odds/rolls). Glassies rewritten with powers and radii (31). Remotes contract updated.
- The swing itself is Codex's job (DECISIONS 24); Balance.Motion has starting values. Simulators use src/tests/FightModel.luau as a stand-in; Codex should measure the real swing and update Balance.SimModel.
- Balance + economy simulators and tests: 51 passed. Removed the meter battle, trainers, zones, Kilnport map tools/docs and M1 Studio scripts (in git history at 8119b7b).
- Docs: GAME_DESIGN v0.3, ECONOMY, DECISIONS 22–29, ROADMAP (F0–F5), UI_SPEC, ART_BIBLE, AGENTS, Codex prompt docs/prompts/01_fight_prototype.md.
Next:
- User picks a lobby concept (MAP_PLAN). Codex builds F1 (fight prototype) from the prompt.
Problems / questions for the user:
- Paid rerolls kept as asked; research suggests earn-only (DECISIONS 25). Free "pick any" once per match? Final names (Marbles, the Kiln)?
Balance sim (200 rounds per matchup, FightModel stand-in):
- Mirror rounds 21–39 s (17–33 hits), 0% timeouts, side bias 50%. Starters: pop>jam 64%, jam>prism 76%, prism>pop 62%. Perfect vs worst aim 61%. Special used vs never 70% (64–75% per special). Fizzy rarity ladder vs Common: Rare 75%, Legendary 94%, Mythic 86%; 5 stars vs 0: 92%. Equal-stat power table 42–58% for every glassy.
- Economy: match ~3.7 min; 4 Kiln pulls on day 1; first Rare ~47 min, Epic ~2.1 h, Legendary ~9 h of play; 20% get a Mythic in 30 days.

## 2026-10-12 — Codex — Early map first pass
Done:
- User requested map construction while M1 phone approval is pending. Built isolated Blender kit/layout scenes without changing approved art: 16 original kit pieces, 320-stud Glass Town plaza and 600.43-stud Recycling Yard path with six trainer clearings, two wild regions, repair stop, conveyors and Rusty's arena. Kept Studio-first coloring; no texture/library/Toolbox additions.
- Saved linked source scenes, two previews and eight color-separated FBX chunks (128 meshes / 24,296 triangles). Final FBX round-trip checks passed; maximum bounds error below 0.000062 studs. Fixed coplanar ground overlap and evaluated the loaded approved stand's transforms before preview duplication.
- Created explicitly temporary native-Part walking proxies from Blender transforms in Workspace.Map, reused approved stands, preserved the practice stand/baseplate, moved spawn to the plaza and tagged future trainer/wild/repair placements. Shops and non-practice stands have no gameplay yet. Proposed implementation decision 20.
- User imported all eight FBXs. Normalized town 6.4x / yard 8.5333x importer scale and horizontal-axis orientation; applied Studio colors/SmoothPlastic, disabled mesh collision and organized 128 visual meshes in Map. Preserved raw imports and all proxy decorations in ServerStorage; retained 56 simple invisible map colliders. Recorded all mesh IDs/transforms in studio_assets.json and normalization in tools/studio/finalize_map_import.luau. Post-import route walk passed in 37.46 s with 305/305 ground hits; full five-clash practice battle ended Shattered with clean camera/HUD restoration and Output.
- Actual Humanoid MoveTo traversal: town 17.63 s, route 37.48 s; no blocked segment. All 305 route ground samples passed. Practice prompt/Space input still enters battle; reset clears HUD, returns Custom camera/WalkSpeed 16 and respawns in town. Output clean. Lune and Studio RunAll: 28 passed, 0 failed.
Next:
- Publish the open Studio place, review the first map pass on a phone, then refine terrain boundaries, building fronts, landmarks and performance. M1 still awaits real-phone feel feedback; other M2 systems remain pending.
Problems / questions for the user:
- User completed local imports. Edit publishing remains unavailable through the connected MCP; use Studio File > Publish to Roblox to save the world online.

## 2026-10-12 — Codex — M1 feel and HUD refinement
Done:
- Followed user's expanded polish request after the gameplay pass: generated and saved an image-led HUD reference plus exact prompt; rebuilt compact Theme glass cards with native mesh portraits, type glyphs, thin animated HP rails/damage trails, diamond needle, centered meter and caption contrast backdrop. No new external assets/library/plugin used; the user-added icon pack remains untouched.
- Batched anchored fighter movement with Model:PivotTo; five-clash full-effect retest kept body/details/cracks aligned within 0.000003 studs, reached 17 fragments and restored the Custom camera with no Output errors.
- Buffered screen/Space holds during rebound into the next timing window; real input registered Perfect after an early hold. Added gentle idle sway, closer portrait framing, floor collisions/restitution for client-only shards and proper spin restoration after slow motion.
- Galaxy A06 landscape Touch battle: five-clash win with four Perfect releases, peak 17 fragments, floor rebounds observed. iPhone 17 Pro landscape/portrait checked; all visible text fits, touch release accepted. Active-battle reset returns Interrupted, clears HUD/effects/backdrop, restores Custom camera/WalkSpeed 16 and idle models after respawn. Fresh Output clean. Four audio templates loaded; no cache growth across battles.
- Lune and Roblox RunAll: 28 passed, 0 failed. Updated design/brief/UI spec, roadmap, Proposed decisions 17–19 and a precise phone checklist in docs/testing/M1_PHONE_CHECK.md. Studio left in Edit with default viewport.
Next:
- Publish from Studio, then user checks motion, input, audio and final shatter on a real phone. User has since requested that map construction begin while that check is pending; other M2 systems remain gated.
Problems / questions for the user:
- MCP Edit publication is still blocked by the SavePlaceAsync server-context restriction. No runtime snapshot was published. Use File > Publish to Roblox in the open place.
Balance sim (3000 battles/matchup; presentation-only changes):
- Even starters 4.24–5.77 clashes; Pop vs Jam 85.1% / 5.32 clashes. Zone 1 non-boss 73.9–99.9%; Rusty 45.5–49.2%. Skill 0 vs 0.5: 23.8%; skill 1 vs 0.5: 74.6%. Evolution level 15 after 24 wins. Damage/stat math unchanged.

## 2026-10-12 — Codex — M1 Step 4 gameplay pass
Done:
- Built battle camera, anchored glassies/details and Beam strings, responsive Theme HUD, PC/gamepad input and screen-wide touch hold. User-directed continuous curved swing now runs on a fixed server cadence; releasing locks a bonus without stopping motion. Added elastic recoil, impact spark burst, 80 ms hitstop, damage/Perfect/crit popups, haptics and final side-on slow-motion shatter with flash, 16 shards plus cap/lid, sparkles, layered sound and cleanup.
- Replaced floating planar cracks with Blender-projected surface paths for all three starters. Blender BVH confirms Pop/Jam contact begins at 0.10815 radians; configured contact is 0.11. Corrected template WorldPivot so hooks stay left/right and marked stand Persistent for streaming.
- Galaxy A06 landscape: real emulated Touch inputs completed a five-clash Pop win; Great releases accepted. iPhone 17 Pro checked landscape and portrait. Desktop Space input registered Perfect. Fixed-RNG comparison: Weak deals 24, Perfect 44. Timeout/loss, victory and reset cleanup checked; HUD, movement and camera restore, shards expire. Studio reset to default viewport.
- All four user-approved audio clips load as parented Sound instances (raw URL preload was incorrect); source links and IDs recorded. Lune and Studio RunAll: 28 passed, 0 failed; 14 server validation checks pass; gameplay Output clean.
Next:
- User authorized further polish while away: improve the M1 HUD from a generated visual reference, then retest. Real-phone feel/listening check remains necessary.
Problems / questions for the user:
- Publishing through AssetService in the MCP Edit context fails: "Game:SavePlace can only be called from a server script". Use Studio File > Publish to Roblox after the final polish; no runtime-server snapshot was published.
- User-added assets/Free Icon Pack v3.1 (Basic) remains untouched and excluded from this commit.
Balance sim (3000 battles/matchup):
- Damage/stat math unchanged: even starters 4.24–5.77 clashes; Pop vs Jam 85.1% wins / 5.32 clashes. Zone 1 non-boss 73.9–99.9%; Rusty 45.5–49.2%. Skill 0 vs 0.5: 23.8%; skill 1 vs 0.5: 74.6%. Evolution level 15 after 24 wins.

## 2026-10-12 — Codex — M1 Step 3 complete
Done:
- Added shared remote definitions and BattleService: distance-checked/rate-limited stand prompt, level-10 Pop vs Jam (NPC skill 0.35), per-player state, server RNG, validated one-shot releases, Weak timeout, scheduled impacts, server HP application at impact and respawn/leave cleanup.
- Added M1 presentation/pacing constants to Balance without changing existing damage/stat math. Added tools/studio/verify_m1_server.luau with 14 meaningful invalid-input/rate-limit/duplicate/expiry checks.
- Play-tested real prompt/remotes: four Perfect clashes ended in Pop victory and clean BattleEnded; separate no-input test produced seven Weak releases. Reset cleaned up the active battle. Fresh play session Output clean. Lune and Roblox RunAll: 28 passed, 0 failed.
Next:
- Step 4 battle visuals, responsive HUD/input, cracks and final shatter; audio selection and phone Device Simulator verification.
Problems / questions for the user:
- Figma battle link could not be fetched; using the repository's Battle layout and Theme as the documented visual reference.
Balance sim (3000 battles/matchup):
- Even starter matches average 4.24–5.77 clashes; level-10 Pop vs Jam wins 85.1%, average 5.32 clashes. Zone 1 non-boss wins 73.9–99.9%; Rusty wins 45.5–49.2%. Skill 0 vs 0.5 wins 23.8%; skill 1 vs 0.5 wins 74.6%. Evolution level 15 after 24 wins. Damage/stat balance unchanged.

## 2026-10-12 — Codex — M1 Step 2 complete
Done:
- Imported assets supplied by user; corrected glassies' 100x FBX scale and the stand's separate importer limit scale against approved Blender measurements. Heights: Pop 2.46, Jam 2.04, Prism 2.52 studs; stand 28.68 wide / 17.80 high. Restored common hang pivots and preserved raw imports in ServerStorage.M1ImportedSources.
- Organized ReplicatedStorage.Assets.ClashStand and Glassies.<id> Body/Shards/Details. Applied Glass/Tint/0.3 transparency, red Pop cap, pale bubbles and gold Jam lid in Studio. Added HookA/HookB attachments and a Workspace stand, walkable floor and arena spotlight.
- Applied bright Realistic lighting, quality priority, soft atmosphere, slight saturation and low bloom. Proposed current-engine replacement for legacy Future setting (decision 16). Saved repeatable setup in tools/studio/setup_m1.luau.
- MCP play-test started cleanly; runtime checks verified every 16-shard set, Glass material and hang pivot. Output: no gameplay errors. Lune and Studio tests: 28 passed, 0 failed. Stopped play mode.
Next:
- Step 3 server-authoritative NPC battle, then Step 4 anchored animations/HUD/cracks/shatter.
Problems / questions for the user:
- No blocker. Publishing the finished milestone remains pending.

## 2026-10-12 — Codex — M1 Step 2 import handoff
Done:
- User approved all revised art and authorized Steps 2–4. Rojo is serving and the expected synced folders exist in Studio.
- Prepared four FBX bundles in assets/blender/import from the approved saved .blend files, with stable mesh names and a bounds/material manifest. Original approved source files and icons are unchanged. Blender FBX round-trip verified all 113 meshes and bounds (maximum error below 0.000002 units).
- Added a reproducible Blender bundling script and Studio import instructions. Updated roadmap art approval; import/gameplay tasks remain unchecked.
- Lune reports 28 passed, 0 failed; Studio RunAll returns true. No gameplay, world or lighting changes yet; imported-art play-test is pending.
Next:
- User imports the four M1_*.fbx bundles into Workspace using Studio's File > Import, preserving separate meshes, imported pivots and Studs scale. Then finish Step 2 organization/colors/lighting, play-test, commit/push; continue Steps 3 and 4.
Problems / questions for the user:
- Studio MCP exposes no local FBX import/upload operation; AssetImportService is unavailable in this connection. Manual file import is required. No third-party library, plugin or Toolbox asset added.

## 2026-10-12 — Codex — M1 Step 1 art revisions
Done:
- Replaced the rejected upright/braced frame with four splayed A-frame swing-set legs and individual foot pads. No braces under the bar. Verified all 44 pen/plank/rail/corner/post-cap meshes are geometrically unchanged. Revised stand: 55 meshes / 1,948 triangles.
- Pop now has brighter cyan preview glass using Tint #8FE3FF, a separate red cap, and five small internal bubbles. Jam now has a separate gold lid. Bodies exclude caps/lids; each revised glass body has 16 closed shards. All component origins coincide at the full assembly hang point. Intact budgets including details: Pop 1,344 triangles; Jam 816.
- Exported revised .blend/body/shards/details FBX and transparent icons; re-rendered the stand. Re-imported revised FBX in Blender and verified topology, mesh counts, origins and budgets. Updated assets/blender/m1_art_validation.json. SHA256 checks confirm all four approved Prism files are unchanged.
- Recorded the user's Studio-first colour/material direction in ART_BIBLE and DECISIONS. Stand and detail preview materials are untextured; no new colour textures. Proposed an optional Details folder for caps/lids/bubbles alongside Body and Shards (decision 15).
- Lune and Studio RunAll both pass: 28 passed, 0 failed. No new Studio imports; asset play-testing remains deferred until art approval. Fixed cross-scene collection-name reuse in the Blender helper; preserved the original scene and prior art revisions.
Next:
- Await approval of revised Pop/Jam icons and swing-set preview; Prism is already approved. Then continue M1 import and gameplay implementation.
Problems / questions for the user:
- Art approval pending; optional Details import layout is proposed. No Accepted decision reversed, no third-party assets/plugins added.

## 2026-10-12 — Codex — M1 Step 1, art approval checkpoint
Done:
- Built and exported Pop (rounded soda bottle), Jam (wide screw-top jar), Prism (faceted perfume bottle with gem stopper), and a matte low-poly wooden Clash Stand with braces, metal eyelets, planked octagon floor and capped low walls.
- Saved each starter's isolated .blend, body/shard FBX and transparent 512x512 icon. Each has 16 closed shards and a top-centre hang origin. Body budgets: Pop 1,056 tris / 2.46 studs; Jam 768 / 2.04; Prism 224 / 2.52. Stand: 55 meshes, 1,916 tris total, shared packed 256x256 palette, .blend/FBX/768px preview.
- Refined the Blender helper's silhouettes and glossy preview material; batch builds preserve the original scene. Fixed collection selection across scenes, hidden-shard export and stale bounds; exports apply rotation/scale and use FBX -Z forward / Y up. Fixed a temporary fracture BMesh leak.
- Verified closed topology, matching shard origins, volume preservation, saved object names and icon sizes. Re-imported all FBX files into Blender: correct mesh counts and starter scale/pivots. Results: assets/blender/m1_art_validation.json. Actual Studio importer settings still need verification in Step 2.
- User screenshot confirms Rojo connected. Baseline Studio play-test starts cleanly (0 services); server RunAll and Lune both report 28 passed, 0 failed. Stopped play mode afterwards. New art has not been imported or play-tested in Studio, per the requested approval checkpoint.
Next:
- Await approval of the three starter icons and stand preview, then import into Studio and continue M1 Steps 2–4 with play-tests, tests, commits and pushes after each step.
Problems / questions for the user:
- Art approval pending. No new design decisions or third-party assets/plugins.

## 2026-10-12 — Codex — M1 orientation and setup checks
Done:
- Pulled the latest repo and read AGENTS, roadmap, decisions, M1 brief, game design, art bible and UI spec. No gameplay or production assets built; implementation awaits the user's go.
- Lune and Studio `ServerStorage.Tests.RunAll` both passed: 28 passed, 0 failed. The required Shared, Server and Tests folders exist in the Glass Clash place (129420351303019).
- Loaded the Blender helper with GLASSCLASH_REPO set to this checkout. Blender 5.2.2 LTS self_check passed: repo found, assets writable, 576-triangle temporary body, 8 test shards.
- Found the existing toolchain in `%USERPROFILE%\.rokit\bin` and added it to the test shell's PATH. Started Rojo serving this repo at localhost:34872.
Next:
- Reconnect the Studio Rojo plugin, then await go. Follow M1 in order: Blender art, Studio import, server battle service, client animation/HUD/cracks/shatter. Play-test, inspect Output, test, commit and push after each step.
Problems / questions for the user:
- Studio Output reports Rojo disconnected. The server is now listening; click Connect in the Rojo plugin before code edits. The roadmap setup checkbox stays unticked until the live connection is confirmed.
- The normal shell PATH does not include the existing Rokit bin folder; commands work when it is added for the session.

## 2026-10-12 — Claude — M0 Setup
Done:
- Wrote GAME_DESIGN.md, RESOURCES.md, ART_BIBLE.md, MAP_PLAN.md, UI_SPEC.md and the rest of `docs/`.
- Built UI mockups in Figma (Glassies screen, Battle screen, style kit).
- Set up the repo: AGENTS.md, Rojo project, Rokit toolchain, StyLua config, CI.
- Wrote the pure game logic and content config in `src/shared`, the UI `Theme` tokens, tests and the balance simulator.
- Wrote the Blender helper script and tested it in Blender 5.2 (bpy): `self_check()`, `build_all_starters()` and `export_clash_stand()` all work and produce FBX, .blend and icons.
- Balance: tuned with the simulator. Even fights ~5 clashes, type advantage ~80-85%, Zone 1 trainers 74-100% for the player, Rusty ~45-49% for every starter (bosses mirror your type), level 15 after ~24 wins.
Next:
- M1 feel prototype (see ROADMAP). Start with docs/prompts/01_feel_prototype.md.
Problems / questions for the user:
- Final game name and collectible name are still placeholders.
