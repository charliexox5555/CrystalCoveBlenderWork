# Prompt: start the next content batch (new glassies, flyers, finishers)

Paste this into a new Claude Code chat opened on the repo folder.

---

Continue Glass Clash in this repo (branch `claude/roblox-game-concepts-0x0lnj`). We're starting the next batch of new content: glassies, flyers and finishers.

First, `git pull`. Then read and understand everything below. Don't build or change anything yet.

1. `AGENTS.md`.
2. `docs/HANDOFF_CONTENT_BATCH.md`, and every document it lists under "Read first". Read the design docs fully: `docs/design/ROSTER_V2.md`, `docs/design/COSMETICS_V2.md`, `docs/art/FLYERS_V3.md`, `docs/vfx/FINISHERS_V2.md` and `docs/art/IMPORT_RUNBOOK.md`.
3. `docs/DECISIONS.md` entries 85 onward, the current milestone in `docs/ROADMAP.md`, and the newest 3 entries in `docs/logs/DEVLOG.md`. Another chat is building other game features at the same time, so check `git log` for anything newer than the handoff.
4. Look at the pipeline code the handoff names, enough to know how each step works:
   - `docs/art/glassy_revamp/tools/build_glassy_v4.py`, `tools/blender/build_flyers_launch.py` and `tools/blender/build_finishers_v4.py`
   - `tools/opencloud/upload_assets.py`, the installers in `tools/blender/`, `tools/release_matrix.sh` and `tools/studio_lock.sh`

Then check, without changing anything:
- `~/.rokit/bin/lune run tools/run_tests` passes.
- `zsh -i -c 'python3 tools/opencloud/upload_assets.py --check'` says `assets: OK`.
- Roblox Studio is connected on "Testing glass game" with Rojo serving.
- Blender is reachable.

When you're done, reply with:
- a short summary of the current state and what's planned next
- which items are queued next
- anything broken or unclear

Then wait. I'll give you the next tasks.
