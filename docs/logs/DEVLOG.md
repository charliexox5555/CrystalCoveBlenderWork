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
