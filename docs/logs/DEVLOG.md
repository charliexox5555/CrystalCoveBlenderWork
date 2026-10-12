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
