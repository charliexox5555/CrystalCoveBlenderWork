# Glass Clash (working title)

A Roblox game where glass collectibles ("glassies") hang on strings, swing into each other, and **shatter**. Pokémon-style progression, lobby tournaments, low-poly world, glossy glass heroes.

- **Start here (agents and humans):** [AGENTS.md](AGENTS.md)
- **Design:** [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) · **Roadmap:** [docs/ROADMAP.md](docs/ROADMAP.md) · **Decisions:** [docs/DECISIONS.md](docs/DECISIONS.md)
- **UI mockups:** [Figma](https://www.figma.com/design/r3guIIk5deo7vNxLzJN0RZ)

## Setup (once per computer)

1. **Install:** [Roblox Studio](https://create.roblox.com/), [Git](https://git-scm.com/), [Rokit](https://github.com/rojo-rbx/rokit) (toolchain manager) and, optionally, [Git LFS](https://git-lfs.com) for big Blender files.
2. **Clone and check out the branch:**
   ```
   git clone https://github.com/charliexox5555/CrystalCoveBlenderWork.git
   cd CrystalCoveBlenderWork
   git checkout claude/roblox-game-concepts-0x0lnj
   ```
   (Once this branch is merged into `main`, use `main` instead.)
3. **Install the tools pinned in `rokit.toml`** (Rojo, Lune, StyLua):
   ```
   rokit install
   ```
4. **Install the Rojo plugin into Studio:** `rojo plugin install`, then restart Studio.
5. **Check the code works:** `lune run tools/run_tests` → should end with `28 passed, 0 failed`.
6. **Connect Studio:** open your place (a new Baseplate is fine), run `rojo serve` in this folder, then click **Connect** in the Rojo plugin. The scripts from `src/` appear in Studio.
7. **Open Codex in this folder.** It reads `AGENTS.md` automatically. Make sure the **Roblox Studio MCP** and **Blender MCP** are enabled in Codex, and Blender is open with its MCP add-on running.
8. Paste the kickoff prompt from [docs/prompts/00_kickoff.md](docs/prompts/00_kickoff.md).

## Everyday commands

| Command | What it does |
|---|---|
| `rojo serve` | Live-syncs `src/` into Studio |
| `lune run tools/run_tests` | Runs all tests outside Studio |
| `lune run tools/balance_sim` | Prints win rates, battle lengths and XP pacing |
| `stylua src tools` | Formats the code |
| `rojo build -o build/GlassClash.rbxl` | Builds a place file from `src/` (scripts only) |

## Folder map

```
AGENTS.md              instructions every agent reads first (CLAUDE.md points here too)
default.project.json   Rojo: which src folders map to which Studio services
rokit.toml             pinned tool versions
src/
  shared/              ReplicatedStorage.Shared: pure logic + Config (balance, glassies, trainers, zones, cosmetics)
  server/              ServerScriptService.Server: Main + Services/
  client/              StarterPlayerScripts.Client: Main + Controllers/ + UI/ (Theme, Components, Screens)
  tests/               ServerStorage.Tests: test suites, balance simulator
tools/
  run_tests.luau       Lune test runner
  balance_sim.luau     Lune balance report
  blender/             Blender helper script for the Blender MCP
docs/
  GAME_DESIGN.md       the design (source of truth)
  ROADMAP.md           milestones and tasks
  DECISIONS.md         decision log
  RESOURCES.md         tools, plugins, best practices
  art/                 ART_BIBLE (style rules), MAP_PLAN (lobby + zones)
  ui/                  UI_SPEC (screens, components, Figma links)
  audio/  vfx/         sound list, effects list
  marketing/           launch and content plan
  references/          reference material and notes
  prompts/             ready-made prompts for Codex, one per milestone
  logs/DEVLOG.md       session log
assets/
  blender/glassies/<id>/   .blend source + FBX exports per glassy
  blender/map/             low-poly map kit and layouts
  icons/  ui/  vfx/  audio/  concepts/  marketing/
places/                optional .rbxl snapshots at milestones
```
