# Working on Glass Clash from a Mac

October 17, 2026. Sets up the same workflow as the Windows PC: GitHub repo, Rojo → Roblox Studio, Lune tests, Claude Code with the Roblox Studio and Blender MCP connections.

## A. Before leaving the PC (once)

1. **Save the place to Roblox.** In Studio: File → Save to Roblox, or Publish. The map, showcase, crate machines, flyer and moon installs live only in the place, not in Git. The Mac opens the place from Roblox.
2. **Push code.** Everything Claude made is already pushed to `claude/roblox-game-concepts-0x0lnj`. Your own uncommitted files are not on GitHub yet: the kilnport Blender work, `tools/blender/build_kilnport.py` / `export_kilnport.py`, map renders, the icon pack and `docs/HANDOFF_LOBBY_ART_UI.md`. Commit and push them if you want them on the Mac.
3. **Copy your Open Cloud key** (the value of the `ROBLOX_ASSETS_KEY` environment variable) into your password manager. Never commit it.

## B. Mac tools (Terminal)

1. **Homebrew:**
   `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
   Follow its "Next steps" to add brew to your PATH.
2. **Git, Git LFS, GitHub CLI:**
   `brew install git git-lfs gh` then `git lfs install` and `gh auth login` (choose GitHub.com, HTTPS, browser login).
3. **Line endings:** `git config --global core.autocrlf input`.
4. **Clone the repo:**
   ```
   git clone https://github.com/charliexox5555/CrystalCoveBlenderWork.git ~/Documents/CrystalCoveBlenderWork
   cd ~/Documents/CrystalCoveBlenderWork
   git checkout claude/roblox-game-concepts-0x0lnj
   git lfs pull
   ```
   `git lfs pull` downloads the `.blend`/`.fbx`/`.rbxm` files.
5. **Rokit (installs Rojo, Lune, StyLua at the project's versions):**
   `curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash`
   Open a new Terminal, `cd ~/Documents/CrystalCoveBlenderWork`, then `rokit install` (say yes to trusting the tools).
6. **Check:** `lune run tools/run_tests` should print `138 passed, 0 failed` (or more).

## C. Roblox Studio + Rojo

1. Install **Roblox Studio for Mac** (create.roblox.com → Start Creating) and sign in with the account that owns Glass Clash.
2. Open **Glass Clash** (place 129420351303019) from your experiences.
3. **Rojo plugin:** in Terminal, `rojo plugin install`, then restart Studio.
4. **Serve the code:** in the repo folder run `rojo serve default.project.json --port 34872`. Leave that Terminal open. In Studio, open the Rojo plugin and click **Connect** (localhost, 34872).
5. **Studio MCP for Claude:** in Studio open the **Assistant** panel → ⋯ → **Manage MCP Servers** → turn on **Enable Studio as MCP server** → **Quick connect** → **Claude**. Restart Claude afterwards.
   - If Quick connect isn't offered, use the standalone server (macOS build) from github.com/Roblox/studio-rust-mcp-server instead.

## D. Claude

1. Install the **Claude desktop app** for Mac (claude.ai/download), sign in, open the **Code** tab and choose the `~/Documents/CrystalCoveBlenderWork` folder.
2. **roblox-dev plugin:** run `/plugin` and install **roblox-dev**.
3. **Project skills** (`.claude/skills/roblox-vfx`, `blender-pipeline`) load automatically from the repo.
4. **Open Cloud key:** macOS apps opened from the Dock don't read `~/.zshrc`, so set the key for apps too:
   ```
   echo 'export ROBLOX_ASSETS_KEY="PASTE_KEY"' >> ~/.zshrc
   launchctl setenv ROBLOX_ASSETS_KEY "PASTE_KEY"
   ```
   Then quit and reopen Claude. `launchctl setenv` lasts until a reboot; run it again after restarting the Mac.
5. **Carry over Claude's local notes.** Claude's memory on the PC isn't synced, so tell the new session:
   - **Uploads:** Claude may upload Blender models via Open Cloud with `ROBLOX_ASSETS_KEY` to **group 11116787**.
   - **Tests:** run Studio tests in a **Play server**, because Edit-mode MCP `require` caching can be stale.

## E. Blender + Blender MCP

1. Install **Blender 5.2** for macOS (Apple Silicon) from blender.org.
2. **Blender side:** Edit → Preferences → Get Extensions, search **MCP** (by Blender Lab, blender.org/lab/mcp-server), install and enable it, then start its server as the add-on describes.
3. **Claude side:** Claude desktop → Settings → **Extensions** → find **Blender** (Blender Lab) → install. This is the connection used on the PC.
4. If Claude Code offers to enable the repo's `.mcp.json` server called `blender` (`uvx blender-mcp`, a different add-on), decline it. Only one Blender connection should be active.
5. **Helper script:** the project's Blender helper needs the repo path on the Mac. In Blender (or via Claude):
   `exec(open("/Users/<you>/Documents/CrystalCoveBlenderWork/tools/blender/glassclash_blender.py").read()); set_repo("/Users/<you>/Documents/CrystalCoveBlenderWork"); self_check()`

## F. First prompt on the Mac

> git pull. Read AGENTS.md, the current ROADMAP milestone and the last 3 DEVLOG entries. Then check the connections without installing anything: Studio MCP is on the Glass Clash place and Rojo is connected; `lune run tools/run_tests` passes and Studio RunAll passes in a Play server; in Blender, load tools/blender/glassclash_blender.py with set_repo(<this folder>) and run self_check(). Tell me anything broken. Notes: Open Cloud uploads go to group 11116787 with ROBLOX_ASSETS_KEY; run Studio tests in Play.

## G. Switching back to the PC

- On the Mac: commit and push, and **Save to Roblox** in Studio.
- On the PC: `git pull` and reopen the place from Roblox. Don't edit the place on both machines at once (unless Team Create is on).
