# Overnight prompt for Codex: keep building after F1

Paste everything below the line into the **current** Codex session (it queues after what it's doing). Keep Studio (with Rojo connected) and Blender open, and the PC awake (turn sleep off).

---

I'm going to bed. **Don't stop and wait for me.** Keep building the game until I'm back, working down the backlog below, committing as you go. Treat this as standing permission to continue from milestone to milestone, within the rules here.

## How to work while I'm away

- **The phone check is mine.** Finish F1, do your own Device Emulator checks, leave "U: real-phone check" unticked for me, and move on. Don't wait for approval of the feel; keep improving it as you go.
- **Small loops:** pick the next item → build → play-test through the MCP (watch the Output for errors) → `lune run tools/run_tests` + `require(game.ServerStorage.Tests.RunAll)()` → commit with a clear message and **push** → short DEVLOG line → next item. Never leave the repo with failing tests.
- **Time-box:** if something takes more than ~1 hour without progress, write down what's blocking in `docs/logs/MORNING.md`, leave it in a safe state, and move on to the next item.
- **Anything that needs me** (importing FBX files into Studio, publishing, Robux products, uploads that need my account, a design choice): don't block on it. Add it to `docs/logs/MORNING.md` with exact steps for me, and continue with something else.
- **Make the world reproducible:** when you build things in the place, keep the build steps in `tools/studio/*.luau` scripts (like you did for the sky lobby), so nothing is lost if Studio crashes. Never re-run a builder over my manual edits (fences, decor).
- **Decisions:** anything the docs don't cover → pick the simplest option that fits GAME_DESIGN 1 (pillars), record it as **Proposed** in `DECISIONS.md`, carry on.

## Hard rules (don't break these, even to finish something)

- Don't change **Accepted** decisions, the content/safety rules in AGENTS.md, or delete my work (fences, decor, LegacyKit, imported assets). Move things to `ServerStorage.Unsorted` instead of deleting when unsure.
- **No paid features:** no developer products, gamepasses, Robux prices or Marble purchases yet. Paid rerolls stay disabled (free reroll only) until I've set up products.
- **No new third-party code** except **ProfileStore** (already chosen in AGENTS.md): get it only from its official source, read it, record the version. No Toolbox models or plugins. Creator Store **sounds/images** are OK if they contain no scripts; record their IDs and names in `src/shared/Config/Audio.luau` / docs.
- **Balance numbers:** you own `Balance.Motion`, `Balance.Feel` and the `SimModel` calibration. Don't retune `Balance.Fight`, `Powers.luau`, rarities or the economy; if the balance tests fail after calibration, log the numbers in MORNING.md for Claude and keep going.
- No force-pushes or history rewrites. Don't publish (you can't anyway); remind me in MORNING.md.

## Backlog (in order)

**1. Finish F1 (fight prototype)** from `docs/prompts/01_fight_prototype.md`, including the bot-vs-bot calibration. Then a **satisfaction pass** on the fight using GAME_DESIGN 9: hit sounds layered by size and speed, hitstop on big hits only, shake, sparks, crack stages, power banners and effects, the slow-mo shatter and shard bounce. Watch 10 bot-vs-bot rounds and fix whatever looks dull, confusing or janky.

**2. F2: match flow on all 7 arenas** (GAME_DESIGN 2, UI_SPEC 2–7, `MatchLogic`):
- `ArenaService`: pads (tags `QueuePad`, `ArenaStand` from the lobby build), queue, bot fill after `QueueBotAfterSeconds`, leave by stepping off. Several matches running at once without lag.
- `MatchService`: phases Roll → Aim → Countdown → Fight → Round end → (repeat) → Results, all through `MatchLogic` (`rollOffers`, `reroll` free only, `pick`, `autoPick`, `setAim`, `endRound`, `rewards`). Remotes `PickGlassy`, `Reroll`, `SetAim`, `LeaveQueue`, `MatchState`, `RollOffers`, `MatchResult`, validated and rate-limited.
- Screens: Queue panel, Roll (3 cards with spinning models, reroll), Aim, Countdown, Round end with the **glass heart popping**, Results with "Play again" and "Lobby".
- Spectating: fights are visible from the walkway; add a floating label over each running arena (names, hearts, round).
- Until data exists, every player has the 3 starters; rewards are shown but not saved.

**3. F3: data, Kiln and collection:**
- `DataService` with ProfileStore and the schema in GAME_DESIGN 14 (session locking, BindToClose). If Studio API access is off, use an in-memory fallback in Studio and note it in MORNING.md.
- Save coins, trophies, stats and the collection; grant starters to new players; match rewards from `MatchLogic.rewards`.
- `KilnService` + Kiln screen: **odds list first** (`Formula.kilnOdds`), coin pulls (`Formula.rollKiln`), glassblowing reveal, duplicates → stars, welcome pull after the first match. Place it at the `Kiln` lobby spot.
- Collection + Index screens (silhouettes for unowned).

**4. UI pass** across everything built so far: crisp-glass `Theme` and components, Lobby HUD (coins, trophies, Kiln/Glassies/Index buttons), consistent fonts and colors, safe insets, tap targets, animations. Check every screen on two phone presets and a tablet in the Device Emulator; fix overlaps and tiny text.

**5. Assets in Blender** (follow ART_BIBLE; export to the repo; add each import to MORNING.md with exact steps, since importing FBX needs me):
- Sky kit: crystal kit (single, small cluster, big cluster), the Kiln crystal, the featured-island arch, 3 cloud meshes (CONCEPT.md "Pieces").
- New glassies, Commons first: `milk_bottle`, `pickle_jar`, `glass_cup`, `ketchup_bottle`, `water_jug`, `lemonade_bottle`, then the Uncommons. Each with body (origin at the hang point), details, 12–20 shards, crack paths and a 512×512 icon with the shared camera. Kid-friendly, no alcohol shapes, original designs. Until they're imported, they can't appear in rolls; keep the Kiln to glassies that have assets in the place (log which).

**6. F4 (free parts only):** daily quests (3 a day), playtime gifts, first win of the day, login streak (free Marbles off for now), codes (one test code), leaderboards (Trophies, Wins, Shatters) at the lobby spots, group-join reward (needs my group ID → MORNING.md).

**7. Keep improving** until I'm back, in rounds: watch fights and the lobby with fresh eyes and pick the 3 things that would most improve fun, look or clarity; fix them; repeat. Also a performance pass (many arenas running), a remote/security pass (validation, rate limits, server authority) and a bug hunt in play mode with 2+ simulated players.

## When I'm back

Leave `docs/logs/MORNING.md` up to date:
1. What you finished (by backlog item), with screenshots in `docs/testing/` for the big ones.
2. **What I need to do**, in order, with exact steps (imports, publish, phone check, IDs you need).
3. Problems, open questions and Proposed decisions.
4. Test results and the balance/economy sim summaries.
