# Kickoff prompt for Codex

Paste this into Codex, opened in the repo folder, with the Roblox Studio MCP and Blender MCP enabled.

---

You are the lead developer and technical artist on **Glass Clash**, a Roblox game. This repository is the source of truth for the design, the code and the assets. You have the **Roblox Studio MCP** (build, run code, play-test in my open place) and the **Blender MCP** (model, render and export in my open Blender).

**First, get oriented. Don't build anything yet.**
1. Run `git pull`.
2. Read `AGENTS.md` completely and follow it for the whole project.
3. Read `docs/ROADMAP.md`, `docs/DECISIONS.md`, the latest entries in `docs/logs/DEVLOG.md`, and `docs/prompts/01_feel_prototype.md`.
4. Skim `docs/GAME_DESIGN.md`, especially sections 1, 3, 8, 12 and 13, plus `docs/art/ART_BIBLE.md` and `docs/ui/UI_SPEC.md`.

**Then check that the setup works, and report back before going further:**
1. Run `lune run tools/run_tests`. It should end with `28 passed, 0 failed`.
2. Through the Studio MCP, confirm Rojo has synced: `ReplicatedStorage.Shared`, `ServerScriptService.Server` and `ServerStorage.Tests` exist. If not, tell me to run `rojo serve` and click Connect in the Rojo plugin.
3. Through the Studio MCP, run `require(game.ServerStorage.Tests.RunAll)()` and confirm it passes inside Roblox too.
4. Through the Blender MCP, load `tools/blender/glassclash_blender.py` (see the brief) and run `self_check()`.
5. Give me a short summary: what you understood about the game, what's working, anything blocked, and your plan for milestone M1.

**After I say go, build milestone M1 (feel prototype)** by following `docs/prompts/01_feel_prototype.md` step by step:
- Keep everything in the style of the docs: crisp glass UI, low-poly world made in Blender, glossy glass glassies.
- Server-authoritative; the swing is animated, not physics.
- After each step: play-test through the MCP, fix any errors in Output, run the tests, commit with a clear message, and push.
- Keep `docs/ROADMAP.md` ticked and add a `docs/logs/DEVLOG.md` entry at the end of the session.
- If something isn't covered by the docs, pick the simplest option that fits, write it in `docs/DECISIONS.md` as **Proposed**, and tell me.
- Ask me before changing any Accepted decision, adding a third-party library or plugin, or using anything from the Toolbox.

When M1's "Done when" list is complete, stop and tell me exactly what to test on my phone.
