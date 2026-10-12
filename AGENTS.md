# AGENTS.md — Glass Clash (Roblox)

Instructions for AI coding agents (Codex, Claude) working on this repo. Read this file first, every session.

## What we're building

**Glass Clash** (working title) is a Roblox game for all ages, mostly kids. Players own glass collectibles called **glassies** that hang on strings and swing into each other until one **shatters**. The structure is like Pokémon: a starter that evolves, NPC trainers along routes, wild glassies to catch, badges, and lobby tournaments. Glassies start as everyday bottles and become fantasy glass (swords, pumpkins, unicorns, dragons).

- **Design (source of truth):** [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md)
- **What to do next:** [docs/ROADMAP.md](docs/ROADMAP.md)
- **Tools, plugins and practices:** [docs/RESOURCES.md](docs/RESOURCES.md)
- **Art direction (low-poly world, glossy glass heroes):** [docs/art/ART_BIBLE.md](docs/art/ART_BIBLE.md), [docs/art/MAP_PLAN.md](docs/art/MAP_PLAN.md)
- **UI:** [docs/ui/UI_SPEC.md](docs/ui/UI_SPEC.md) and the [Figma mockups](https://www.figma.com/design/r3guIIk5deo7vNxLzJN0RZ)
- **Decisions already made:** [docs/DECISIONS.md](docs/DECISIONS.md). Don't re-open them without asking the user.

## Start of every session

1. `git pull` to get the latest.
2. Read this file, then the **current milestone** in `docs/ROADMAP.md`, then the last 2–3 entries in `docs/logs/DEVLOG.md`.
3. Read only the GAME_DESIGN sections the task needs.
4. Make sure Rojo is serving (`rojo serve`) and the Studio Rojo plugin is connected before editing code (see Workflow).

## End of every session

1. Run the tests (see Testing). Don't commit with failing tests.
2. Tick finished items in `docs/ROADMAP.md`.
3. Add a short entry to `docs/logs/DEVLOG.md`: what changed, what's next, any problems.
4. Record any new decision in `docs/DECISIONS.md`.
5. Commit with a clear message and push.

## Where things live

| What | Where | How it gets into the game |
|---|---|---|
| All Luau code | `src/` | **Rojo** syncs it into Studio (see `default.project.json`) |
| Shared code and config | `src/shared` → `ReplicatedStorage.Shared` | Rojo |
| Server code | `src/server` → `ServerScriptService.Server` | Rojo |
| Client code and UI | `src/client` → `StarterPlayer.StarterPlayerScripts.Client` | Rojo |
| Tests and balance simulator | `src/tests` → `ServerStorage.Tests` | Rojo |
| Map, models, lighting, sounds placed in the world | The Roblox place (Studio) | Built through the **Roblox Studio MCP**; publish to save |
| Blender source files and exports | `assets/blender/...` | Imported into Studio |
| Icons, UI textures, VFX textures, audio, concepts | `assets/...` | Uploaded to Roblox, IDs recorded in config |
| Blender helper script | `tools/blender/glassclash_blender.py` | Run inside Blender through the **Blender MCP** |
| Place file snapshots (optional) | `places/` | Saved from Studio at milestones |

**Never edit Rojo-managed scripts directly in Studio.** Rojo overwrites them. Edit the files in `src/`.

Rojo file naming: `Name.server.luau` = Script, `Name.client.luau` = LocalScript, `Name.luau` = ModuleScript, a folder with `init.luau` = a ModuleScript with children.

## Workflow

1. **Code:** edit files in `src/`. With `rojo serve` running and the Studio plugin connected, changes appear in Studio immediately.
2. **World:** use the Roblox Studio MCP to build and arrange things in the place (map pieces, Clash Stands, NPCs, lighting) and to playtest.
3. **Art:** use the Blender MCP for glassies, map kit pieces and icons. Load the helper first: `exec(open("<repo>/tools/blender/glassclash_blender.py").read())`. Follow ART_BIBLE.
4. **Check in Studio:** run tests and play-test through the MCP (`run_code`, play mode tools), read the output console, fix errors.
5. **Publish** to Roblox at the end of each milestone (place version history is the backup for the world).

## Testing

- **Outside Studio (fast):** `lune run tools/run_tests` — runs everything in `src/tests` against the pure modules. `lune run tools/balance_sim` prints win rates and battle lengths.
- **Inside Studio (through MCP `run_code`):** `require(game.ServerStorage.Tests.RunAll)()` and `print(require(game.ServerStorage.Tests.BalanceSim)())`.
- Any change to `src/shared/Config/Balance.luau`, `Glassies.luau` or `Trainers.luau` → run the balance simulator and paste the summary into the DEVLOG entry.
- Pure logic (`Formula`, `BattleLogic`, `Rng`, `Config/*`) must stay free of Roblox APIs so it runs in Lune. Inside those modules, sibling requires use `if script then require(script.Parent.X) else require("./X")`.

## Code rules

- **Luau**, `--!strict` where practical. Format with StyLua (`stylua src`); config in `stylua.toml`.
- **Server-authoritative.** The server decides HP, damage, crits, catches, rewards and purchases. Clients only send inputs (`ReleaseSwing`, `ThrowCork`, `ChallengePlayer`, `JoinTournament`, `PickWinner`). Validate every remote's arguments and **rate-limit** every remote.
- **No Roblox physics for the swing.** Clients animate anchored glassies with CFrame; the server decides the result (GAME_DESIGN 3.8). Shards are client-only.
- **Data:** ProfileStore with session locking. Purchases through an idempotent `MarketplaceService.ProcessReceipt`.
- **Numbers** go in `src/shared/Config/Balance.luau`, not inline. Content (glassies, trainers, zones, cosmetics) goes in `src/shared/Config/`.
- **UI:** build from the `Theme` module and shared components in `src/client/UI` (GAME_DESIGN 12.5). Match the Figma mockups. Interactive UI stays in `CoreUISafeInsets`. Test with the Device Emulator on phone presets.
- Use `task.wait`/`task.spawn`/`task.delay`, never deprecated `wait`/`spawn`/`delay`.
- Clean up connections and effects (Debris or explicit `:Destroy()`); no leaks across battles.
- Keep scripts small and focused; one service per file.

## Content and safety rules (non-negotiable)

- Kid-friendly. **No alcohol bottles or references** (beer, wine, champagne, liquor). No gore.
- **No copyrighted characters or brands.** All glassies, NPCs and names are original.
- **Paid crates must show odds before purchase**, and must be hidden for players where `PolicyService` says paid random items are restricted. No betting or wagering of coins or Robux.
- **No free models, plugins or scripts from the Toolbox without reading every script inside first.** Remove anything with `require(<number>)`, `getfenv`, `loadstring`, obfuscated code or HTTP calls you didn't write.
- Never commit secrets (API keys, Open Cloud keys, cookies).

## Art rules (summary; full version in ART_BIBLE)

- **World:** low-poly, flat-shaded, chunky shapes, mostly built in Blender as a modular kit.
- **Glassies:** smooth, glossy, tinted glass, toy-like proportions. They must stand out against the matte world.
- **Every glassy:** body mesh with origin at its **hang point**, a pre-broken shard set (12–20 pieces), and a 512×512 icon rendered with the shared camera and lighting.
- **1 Blender unit = 1 stud.** Apply transforms before export.

## When unsure

- If the design doc doesn't cover something, pick the simplest option that fits the pillars (GAME_DESIGN 1), note it as **Proposed** in DECISIONS.md, and tell the user.
- Ask the user before: changing a decision in DECISIONS.md, adding a paid feature, adding a third-party library or plugin, or deleting work.
