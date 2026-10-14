# AGENTS.md — Glass Clash (Roblox)

Instructions for AI coding agents (Codex, Claude) working on this repo. Read this file first, every session.

## What we're building

**Glass Clash** (working title) is a Roblox game for all ages, mostly kids. Players collect glass collectibles called **glassies** and battle them in a simple lobby of arenas: step on a pad (1v1, a bot joins if nobody comes), roll 3 glassies from your collection and pick one, aim the pull-back, let go, and watch the two glassies swing on their strings and smash into each other until one **shatters**. Each glassy has a passive and a burst power that fires by itself at random moments; swings are erratic and 3D, so luck keeps every round tense. Each player has 3 glass hearts; lose a round, lose a heart. Coins buy pulls from **the Kiln** (gacha, odds always shown). Glassies range from everyday bottles to fantasy glass (swords, unicorns, dragons).

**Who does what:** Claude does research, design, docs, concepts and the pure rules/formulas/economy (`src/shared` pure modules, `Config`, simulators). **Codex** builds everything in Studio: swing motion, services, UI, map, effects, and tunes `Balance.Motion` by eye (DECISIONS 24).

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
| Tests, balance and economy simulators | `src/tests` → `ServerStorage.Tests` | Rojo |
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

- **Outside Studio (fast):** `lune run tools/run_tests` runs everything in `src/tests` against the pure modules. `lune run tools/balance_sim` prints round lengths and win rates; `lune run tools/economy_sim` prints coin and Kiln pacing.
- **Inside Studio (through MCP `run_code`):** `require(game.ServerStorage.Tests.RunAll)()`, `print(require(game.ServerStorage.Tests.BalanceSim)())`, `print(require(game.ServerStorage.Tests.EconomySim)())`.
- Any change to `Config/Balance.luau`, `Glassies.luau` or `Powers.luau` → run both simulators and paste the summary into the DEVLOG entry.
- The simulators use `src/tests/FightModel.luau`, a stand-in for the real swing. Once the swing runs in Studio, measure real hits per second and hit speeds and update `Balance.SimModel` so they stay honest.
- Pure logic (`FightRules`, `MatchLogic`, `Formula`, `Rng`, `Config/*`) must stay free of Roblox APIs so it runs in Lune. Inside those modules, sibling requires use `if script then require(script.Parent.X) else require("./X")`.

## Code rules

- **Luau**, `--!strict` where practical. Format with StyLua (`stylua src`); config in `stylua.toml`.
- **Server-authoritative.** The server runs the swing and `FightRules` and decides HP, damage, crits, rolls, Kiln pulls, rewards and purchases. Clients only send inputs (`PickGlassy`, `Reroll`, `SetAim`, `LeaveQueue`; see `src/shared/Remotes.luau`). Validate every remote's arguments and **rate-limit** every remote (`Balance.Match.*RateSeconds`).
- **No Roblox physics for the swing.** The server steps its own pendulum simulation and streams snapshots; clients animate anchored glassies with CFrame and interpolate (GAME_DESIGN 3.1, 14). Shards are client-only.
- **Rules go through `FightRules` and `MatchLogic`.** Don't re-implement damage, powers, rolls or rewards in services; call the pure modules so tests and simulators cover them.
- **Data:** ProfileStore with session locking. Purchases through an idempotent `MarketplaceService.ProcessReceipt`.
- **Numbers** go in `src/shared/Config/Balance.luau`, not inline. Content (glassies, powers, cosmetics) goes in `src/shared/Config/`.
- **UI:** build from the `Theme` module and shared components in `src/client/UI` (GAME_DESIGN 12.5). Match the Figma mockups. Interactive UI stays in `CoreUISafeInsets`. Test with the Device Emulator on phone presets.
- Use `task.wait`/`task.spawn`/`task.delay`, never deprecated `wait`/`spawn`/`delay`.
- Clean up connections and effects (Debris or explicit `:Destroy()`); no leaks across battles.
- Keep scripts small and focused; one service per file.

## Content and safety rules (non-negotiable)

- Kid-friendly. **No alcohol bottles or references** (beer, wine, champagne, liquor). No gore.
- **No copyrighted characters or brands.** All glassies, NPCs and names are original.
- **The Kiln (and any paid random item) must show odds before every pull**; any Robux/Marble-paid random item must be hidden for players where `PolicyService` says paid random items are restricted. No betting or wagering of coins or Robux. No stronger Robux-only glassies.
- **No free models, plugins or scripts from the Toolbox without reading every script inside first.** Remove anything with `require(<number>)`, `getfenv`, `loadstring`, obfuscated code or HTTP calls you didn't write.
- Never commit secrets (API keys, Open Cloud keys, cookies).

## Art rules (summary; full version in ART_BIBLE)

- **World:** low-poly, flat-shaded, chunky shapes. The lobby is built mostly in Studio from parts, with a small Blender kit for hero pieces (MAP_PLAN).
- **Glassies:** smooth, glossy, tinted glass, toy-like proportions. They must stand out against the matte world.
- **Every glassy:** body mesh with origin at its **hang point**, a pre-broken shard set (12–20 pieces), and a 512×512 icon rendered with the shared camera and lighting.
- **1 Blender unit = 1 stud.** Apply transforms before export.

## When unsure

- If the design doc doesn't cover something, pick the simplest option that fits the pillars (GAME_DESIGN 1), note it as **Proposed** in DECISIONS.md, and tell the user.
- Ask the user before: changing a decision in DECISIONS.md, adding a paid feature, adding a third-party library or plugin, or deleting work.
