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
