# Glass Clash: next patch handoff (levels + profile, featured stage, viewing)

Written Oct 20, 2026, at the end of the onboarding / UI / fix-list session. Use it to start the next patch in a fresh
chat. Other chats may work in this repo at the same time, so check `git log` and the newest DEVLOG entries for anything
that changed after this was written.

## Where the game is

Everything below is committed on `claude/roblox-game-concepts-0x0lnj` and pushed. Lune tests pass (189).

- **Onboarding (decision 100):**
  - Loading screen: `ReplicatedFirst/LoadingScreen` preloads everything, then hands off to onboarding.
  - Welcome claim card: one Kiln with "x3", OPEN gives 3 free opens (1 Common / 1 Uncommon / 1 Rare, never owned, random per player). The opening shows 3 stacked reels.
  - Daily Rewards opens with a pointer and closes itself after the claim.
  - A reserved arena with a gold chevron beam. A pointer lands on PLAY after 20 s.
  - Assisted first match vs Rookie Bot (3–1 win), then a "YOU WON!" claim card that opens one free Kiln pull.
  - No hint text anywhere ("kids don't read"). See `docs/design/ONBOARDING.md`.
- **Tutorial funnel:** 12 server-side `LogOnboardingFunnelStepEvent` steps, from Joined to Second Match Finished (`OnboardingRules.Funnel`). It shows in the Creator Dashboard only after the game is published.
- **No starter glassies (decision 102):**
  - New players start with the 3 welcome opens.
  - Pop, Jam and Prism are Common Kiln drops; the Kiln has 36 glassies.
  - `Glassies.Fallback` lends a hand to anyone with fewer than 3 glassies; it's never granted.
- **Free claim cards show no odds line.** Paid pulls keep their odds.
- **Top bar (TopbarPlus, decision 98):**
  - Settings button.
  - Rewards gift with a dropdown: Daily, Playtime, Codes.
  - Config lives in `src/shared/Config/Topbar.luau`. Screens are editable StarterGui templates in the Stained Glass kit.
- **Lobby:**
  - Stained-glass leaderboards v3 (decision 101, Proposed): weekly Robux spent, total wins, all-time Robux spent. Emblems are centred flat reliefs.
  - Decor kit in `Workspace.Lobby.Decor`.
  - The flyer showcase fades between flyers.
- **Fights:**
  - Powers stay attached to their glassies (power audit).
  - The finisher hits the losing avatar with matte chips and an outline flash (no more "ghost glass").
  - Kiln reels use card-shaped tiles. A 10-pull is a 5×2 grid of short sideways reels; the creator rejected vertical reels.

**Still open with the creator:**
- Save and publish the place.
- Phone checks.
- Robux prices for some cosmetics.
- Monetization: Marble packs and gamepasses.
- Phone layout.
- The Quests screen (on hold).

## Read first

1. `AGENTS.md` (rules, workflow, safety) and `CLAUDE.md`.
2. `docs/DECISIONS.md` from 85 on, especially:
   - 98 (top bar), 99 (rewards and settings), 100 (onboarding), 101 (leaderboards), 102 (no starters).
3. The current milestone in `docs/ROADMAP.md` and the newest 3 entries in `docs/logs/DEVLOG.md`.
4. UI:
   - `docs/ui/UI_SPEC.md`, `docs/ui/EDITING_UI.md` and `docs/ui/topbar/README.md`.
   - The Stained Glass kit: `src/client/UI/Components/StainedGlass.luau`, `Motion.luau` and `UIAssets`.
   - How the top bar screens were built: `tools/studio/build_topbar_screens.luau` and `tools/ui/*_art.py`.
5. For task 3:
   - `src/client/Controllers/FightController.luau`
   - `src/client/Presentation/FightView.luau` (`Watch`, `EnterView`, `ExitView`), `FightScene.luau`, `FightFinisher.luau`
   - `src/server/Services/FightService.luau` and `MatchService.luau` (the `Spectate` flags)
   - `src/client/LocalSettings.luau` ("Hide Others' Cosmetics")
6. Reference screenshot for task 1 (Ball v Ball profile): `docs/references/images/ballvball_profile.webp`. It stays local, not in git, because the repo is public. Use it for layout ideas only, and don't copy its art.

## The three tasks (in this order of priority)

### 1. Levels + player profile

The creator wants a **Profile** button in the top bar that opens the player's profile.

**Reference (Ball v Ball):**
- Left column of big tabs: Profile, and one tab per collection (theirs: Balls, Explosions, Flyers). Ours would be Glassies, Finishers, Flyers.
- Main page:
  - Big name banner.
  - Avatar portrait with "Lv.N" and an XP bar underneath.
  - Stat tiles: Wins, Win Rate, Best Streak.

**Levels:**
- Players earn XP and level up. Leave **level rewards** out for now.
- Keep a **small empty area at the bottom** of the profile page for them later.

**Inventory tabs:** show the player's collection by category. Reuse what exists in `InventoryScreen` / `CollectionScreen` / `CosmeticCatalog` rather than building a second inventory. Decide with the creator whether these tabs are the profile's own read-only grids or jump into the existing Inventory.

**What exists:**
- `Profile.Stats` already has MatchWins, MatchLosses, WinStreak, BestStreak, Shatters, Perfects and more.
- `Profile.Trophies` exists too.
- There is no XP or level yet.

**Build it the project's way:**
- **Pure rules:** a Lune-tested `LevelRules` module covering XP per match (win, loss, rounds won, maybe perfects) and the level curve. Numbers go in `Balance.Levels`.
- **Profile fields:** add them with a reconcile migration. Existing players start at level 1 with 0 XP, or get XP back-filled from their wins if the creator agrees.
- **Server:** grants XP after each match. Track it, and use the funnel or `AnalyticsService` custom events if it helps.
- **Client:** a `ProfileScreen` built as an editable StarterGui template in the Stained Glass kit.
- **Top bar:** add a Profile entry in `Config/Topbar.luau`, with an avatar headshot icon if TopbarPlus allows; otherwise a profile icon in `UIAssets`.
- **Design first:** show the creator screenshots or mockups and get approval before wiring the logic. This is how the Settings, Daily, Playtime and Codes screens were done.

**Questions for the creator** (ask all at once):
- XP sources and how fast levels come.
- Whether other players' profiles can be opened, for example by clicking them.
- Which stats to show beyond Wins, Win Rate and Best Streak (Trophies? Shatters?).
- The tab set.

### 2. Featured stage: brainstorm only

The featured island at the end of the lobby (Arena 7, z ≈ −206, board text "FEATURED ARENA") currently runs normal matches, like the other arenas. GAME_DESIGN 193 once suggested showing the highest-trophy fights on a big board.

The creator wonders whether it should be something special, such as a **king of the hill**, and isn't sure.

Deliver a short options document (`docs/design/FEATURED_STAGE.md`):
- 3–5 concepts. Examples:
  - King of the Hill: the winner stays on and challengers queue.
  - Champion's Stage: the top-trophy player defends.
  - Spectator stage with a big screen of the best live fight.
  - A rotating event mode (Bracket Hour, Boss Bot).
  - A daily featured matchup.
- For each concept:
  - What a kid sees and does.
  - Why they'd come back.
  - Rewards. No wagering of coins or Robux, ever.
  - Rough build cost, using the existing swing, match and bot code.
  - Risks: empty servers, toxicity, griefing.
- A recommendation.

**Don't build** until the creator picks.

### 3. Viewing (spectating) fixes

Two problems the creator noticed:

**a) Watching should last the whole match.**
- Once you start viewing an arena, stay in the viewing camera for the entire match: every round, power effects, the round-end shatter, finishers and heart pops.
- It ends only when the match ends or the player exits (StopWatching).
- **Cause found so far:** watching is state on a single round's fight scene. `FightView:Watch` / `Viewing` sit on a scene named `LocalFight_<matchId>-round-N`. Each round builds a new scene, so the view drops between rounds, and non-viewed scenes run in `LowDetail`.
- **Fix:** make "watching match X in arena Y" a match-level state in `FightController`. Re-enter the view for each new round scene of that match, keep finishers and effects at full detail, and leave the view only on match end or exit. Check that the server keeps streaming what spectators need between rounds; see the `Spectate` flags in FightService and MatchService.

**b) Hide other players while in a match or viewing.**
- Anyone who walks into your arena currently shows up in the shot.
- While you're in a match or viewing one, locally hide every player character that isn't part of that match. That covers parts, accessories, decals, nameplates and flyers. `LocalTransparencyModifier` or a client-side hide works, and so does handling characters that spawn or respawn during it.
- Restore everything on exit.
- The two participants' avatars must stay visible: the finisher flies to the losing avatar.
- This is separate from the "Hide Others' Cosmetics" setting, which stays as it is.
- Verify with the multiplayer harness (`src/server/Dev/MultiplayerHarness.server.luau`, `src/client/Dev/MultiplayerHarness.client.luau`) or a 2-player Studio test.

## Working rules that matter

- **One shared Roblox Studio:** "Testing glass game", place 129420351303019.
  - Run `tools/studio_lock.sh acquire <name>` before Play or Edit work, and `release` after.
  - The creator may be playing in Studio at the same time, so keep Play sessions short.
  - Play uses a copy of the code from when it started. After code edits, restart Play to see them.
  - Studio uses isolated ProfileStore mock sessions, so every Play starts as a brand-new player at the Welcome step.
  - Dev hooks (Studio only) live in ServerStorage: `OnboardingDev` ("Step", player, step), `MatchDev` ("Start", arenaId, playerA, playerB), `DataDev`, `RetentionDev`, `FightDev`.
- **Rojo** syncs `src/` live into Studio.
  - Never edit Rojo-managed scripts in Studio.
  - Compile-check edits before saving.
- **Tools:**
  - Lune, stylua and rojo live in `~/.rokit/bin` (not on PATH).
  - Run stylua only on your own files.
- **Commits:**
  - Commit by exact path; never use `git add -A`, stash or reset.
  - Add a DEVLOG entry, record new decisions in `docs/DECISIONS.md`, and tick items in `docs/ROADMAP.md`.
- **Public repo:** keep third-party images out of git, in `docs/references/images/` (ignored).
- **Uploads:** Open Cloud uploads go through `zsh -i -c 'python3 tools/opencloud/upload_assets.py <list.json>'`.
  - Decals resolve to image ids in Studio via `InsertService:LoadAsset(id)` → `Decal.Texture`.
- **Asking the creator:**
  - The creator likes design screenshots before functionality, and short questions in one batch.
  - When they say they're away, decide yourself and leave a report.
- **Kids' game:** keep text minimal on new UI (pictures and motion over reading).
