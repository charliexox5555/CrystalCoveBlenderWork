# Moving the work to Claude Code (Studio + Blender connected)

Claude can only drive Roblox Studio and Blender from a session **running on your PC** (Studio's MCP server and the Blender add-on are local). A cloud session can't reach them. So run Claude Code locally in your repo folder: the **Claude Desktop app → Code** tab, or `claude` in a terminal in `Documents\CrystalCoveBlenderWork` (`claude remote-control` there also lets you follow it from the Claude app).

## 1. One-time setup (Windows)

1. **Claude Code**: install the Claude Desktop app (Code tab) or the CLI. Open it in `Documents\CrystalCoveBlenderWork` and `git pull`.
2. **Roblox Studio (official, built in)**: in Studio open **Assistant → … → Manage MCP Servers**, turn on **Enable Studio as MCP server**, and use **Quick connect** for **Claude Code**. Restart Claude Code and check `/mcp` shows the Roblox Studio server as connected. Keep Rojo serving as before.
   - If Quick connect isn't there in your Studio version, the older standalone server still works: download `rbx-studio-mcp.exe` from github.com/Roblox/studio-rust-mcp-server and run `claude mcp add --transport stdio Roblox_Studio -- "C:\path\to\rbx-studio-mcp.exe" --stdio`.
3. **Blender**: install **uv** (`powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"`), run `uvx blender-mcp install-addon` (or install `addon.py` from github.com/ahujasid/blender-mcp via Edit → Preferences → Add-ons), enable **Interface: Blender MCP**, then in Blender press **N → BlenderMCP → Start/Connect**. The repo's `.mcp.json` already registers `blender` for Claude Code (approve it when asked). **Only one AI client can use the Blender add-on at a time: close Codex's connection first.**
4. **Plugin**: in Claude Code run `/plugin` and install **roblox-dev** (Luau typing, security, performance, UI patterns, reviewer agent) from the Anthropic directory.
5. **Project skills (already in the repo)**: `.claude/skills/roblox-vfx` (VFX playbook for this game) and `.claude/skills/blender-pipeline` load automatically in this folder.
6. Check: `lune run tools/run_tests` passes, `/mcp` shows Roblox Studio + blender connected, Studio has the place open with Rojo connected, Blender is open with the add-on running.

Optional extras (read every file before installing community skills; AGENTS.md rule): `nonlooped/roblox-suite` has a `roblox-vfx` sub-skill (`npx skills add https://github.com/nonlooped/roblox-suite --skill roblox`); community "game-feel" / "vfx-realtime" skills are engine-agnostic. Our project skills already cover what they add.

## 2. First prompt for the local Claude session

Paste this after setup:

---

You're taking over Glass Clash from Codex, focusing on **visual effects, finishers and sound**. You have the Roblox Studio MCP and the Blender MCP connected.

1. `git pull`. Read `AGENTS.md`, then **`docs/HANDOFF_CLAUDE_HALLOWEEN_REWORK.md` (Codex's handoff: it is the task and it overrides older prompts)**, the current ROADMAP milestone, the last DEVLOG entries, `docs/vfx/VFX_LIST.md`, and the skills `roblox-vfx` and `blender-pipeline`.
2. Check the connections without reinstalling anything: confirm the connected Studio place is **Glass Clash** (not Cookie Inc) and Rojo is connected; run `require(game.ServerStorage.Tests.RunAll)()`; in Blender load `tools/blender/glassclash_blender.py` and run `self_check()`. Report anything broken before changing code.
3. Follow the handoff's priorities: the pumpkin as its own glassy with its own powers (remove the Skins tab), a much cooler flyer, much cooler finishers, and sound effects for every finisher. Show me a short plan first.
4. Work one effect at a time: implement → trigger it in Studio → short clip or screenshot → tune → focused tests → commit. Make geometry and textures in Blender (`assets/vfx/`, glassy folders) and tell me exactly which files to import into Studio.
5. Respect the handoff's limits (don't touch the map, arenas, lighting or my unrelated files; don't stage the dirty files it lists; no publishing or paid activation) and the usual rules (client-only effects, pooled and cleaned up, mobile budget, numbers in `Balance.Feel`, kid-friendly, Stained Glass palette). Keep usage modest: focused checks, no broad suites unless needed. Update DEVLOG and ROADMAP, commit and push as you go.
