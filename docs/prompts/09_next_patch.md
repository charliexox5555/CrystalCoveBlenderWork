# Prompt: next patch (levels + profile, featured stage, viewing fixes)

Paste this into a new Claude Code chat opened on the repo folder.

---

Continue Glass Clash in this repo (branch `claude/roblox-game-concepts-0x0lnj`). We're starting the next patch.

First, `git pull`. Then read:

1. `AGENTS.md`.
2. `docs/HANDOFF_NEXT_PATCH.md`, and every document it lists under "Read first".
3. `docs/DECISIONS.md` entries 85 onward, the current milestone in `docs/ROADMAP.md`, and the newest 3 entries in `docs/logs/DEVLOG.md`.
4. Check `git log` for anything newer than the handoff.

Look at the reference screenshot `docs/references/images/ballvball_profile.webp` (Ball v Ball's profile). It's for layout ideas only: don't copy its art.

Then run the checks without changing anything:
- `~/.rokit/bin/lune run tools/run_tests` passes.
- Roblox Studio is connected on "Testing glass game" with Rojo serving.

The three tasks for this patch are in the handoff:

1. **Levels + player profile.** A Profile button in the top bar opens the profile page. It shows:
   - avatar, name, level and XP bar
   - Wins, Win Rate and Best Streak
   - tabs for my glassies, finishers and flyers
   - a small empty area at the bottom kept for level rewards later

   No level rewards yet.
2. **Featured stage brainstorm.** What should the featured arena be? King of the hill, or something else? Write the options and a recommendation. Don't build it yet.
3. **Viewing fixes.**
   - Once I start viewing an arena, I stay in the view for the whole match: all rounds, effects, finishers. It ends only when the match ends or I exit.
   - While I'm in a match or viewing one, hide every other player who isn't in that match, so people walking into the arena don't get in the shot.

When you've read everything, reply with:
- a short summary of the current state
- your plan for the three tasks
- all your questions for me in one batch (task 1's XP/levels and tabs, anything unclear in task 3)

Then start on task 3 (the viewing fixes), since it needs no design decisions. For task 1, show me mockups or screenshots before wiring the logic.
