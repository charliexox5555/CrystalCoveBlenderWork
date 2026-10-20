# Rewards, Codes and Settings: functionality plan

October 19, 2026 · **status: decided and built (decision 99).** The creator's answers are in §6; the questions below are kept for the record. This plan makes the four
top bar screens work (decision 98; screen designs in `docs/ui/screens/`). Numbers are first-pass and get checked with
`lune run tools/economy_sim` before they ship.

## 0. What already exists (reuse, don't rebuild)

| Piece | Where | Today |
|---|---|---|
| Daily bookkeeping (pure, Lune-tested) | `src/server/Data/RetentionRules.luau` | UTC day (`Balance.Data.DaySeconds`, decision 39); streak counts logins but pays nothing |
| Server service + remotes | `RetentionService`, `ClaimRetention`, `RedeemCode`, `RetentionResult` | rate-limited, server-authoritative, saves the profile after a claim |
| Playtime clock | `RetentionService` tick | adds real server time per UTC day, capped at the last gift |
| Playtime gifts | `Balance.Economy.PlaytimeGifts` | 5/15/30/60 min → 40/60/100/150 coins |
| Login-streak Marbles | `Balance.Economy.DailyStreakMarbles = {0,0,5,0,0,0,15}` | defined, **never granted** (free Marbles off, decision 39) |
| Codes | `Config/Retention.Codes`, `data.CodesRedeemed` | one Studio-only test code |
| Music prefs | `MusicPrefsService` (own DataStore) + `MusicController` | mute + volume, failure-tolerant |
| Reduced motion | `Motion.reduced()` | reads `PlayerGui.ReducedMotion` or Roblox's own setting |
| Low-detail effects | `LowDetail` paths in PowerFX, finishers, CombatFeel | used today for fights you aren't watching |
| Bot fill | `Balance.Match.QueueBotAfterSeconds = 15` | an empty slot gets a bot after 15 s |

Economy context: the sim's player (40 min/day) earns about 3 Kiln pulls (≈ 900 coins) a day. Daily and playtime
rewards should feel generous but stay a bonus, not the main income.

## 1. Daily Rewards (7-day calendar)

**Flow:** the day changes at 00:00 UTC (6 PM CST, the same reset as the Daily Store). Each day, today's cell glows; tap CLAIM
(server checks the day) → reward granted → cell shows claimed, progress bar `x/7` advances, timer shows "Next reward in hh:mm:ss".
After Day 7 the calendar starts again at Day 1.

**Missed days (Q1):**
- **A. Keep your place (recommended):** the calendar only moves when you claim; missing a day costs nothing, you
  just continue from the next day. Kind to kids, no pressure, no "you lost your streak" sadness.
- **B. Classic reset:** missing a whole UTC day sends you back to Day 1. Stronger daily pull, more frustration.
- **C. One grace day** per week, then reset.

**Rewards (Q2), first pass:**

| Day | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| Coins only | 50 | 75 | 100 | 125 | 150 | 200 | **free Kiln pull + 250** |
| With Marbles | 50 | 75 | **5 Marbles** | 125 | 150 | 200 | **free Kiln pull + 15 Marbles** |

The Marble version uses the already-defined `DailyStreakMarbles` but needs decision 39 reversed (free Marbles are
off today). A free Kiln pull uses the normal Coin Kiln with its odds shown, like `WelcomeKilnPulls`. A cosmetic
(crate spin) on Day 7 is another option.

**Build:** `Daily = { Index, LastClaimDay }` in the profile (schema bump + migration), `Rules.claimDaily`,
`Rules.view` gains `Daily = { Index, ClaimedToday, ResetAt, Rewards }`. Tests in `src/tests`.

## 2. Playtime Rewards (10–60 minutes)

**Flow:** six gifts at 10, 20, 30, 40, 50, 60 minutes. The bar fills in real time on the client (from
`PlaytimeSeconds` + local ticking); a gift turns "ready" at its time and stays claimable until reset; tap CLAIM.

**Timer rule (Q3):**
- **A. Per day, keeps across sessions (recommended, already built):** time adds up over the UTC day even if you rejoin;
  resets at 00:00 UTC. Fair for kids on flaky connections.
- **B. Per session:** resets when you leave (Roblox's own Engagement Rewards package works this way). Encourages
  long single sessions, punishes disconnects.

AFK: Roblox kicks idle players after 20 minutes, so we count all time in game. (Counting only active input is
possible later.)

**Rewards (Q4), first pass:** 10 → 30 coins, 20 → 40, 30 → 60, 40 → 80, 50 → 100, 60 → **150 coins** (or a special
60-minute reward: Marbles or a free crate spin). Total 460 coins/day, close to today's 350.

**Build:** replace `PlaytimeGifts` with the six steps; claims keep the existing `Gift` path.

## 3. Codes

**Rules:** case-insensitive, letters/digits/underscore, one redemption per account, server-only granting, 1 s rate
limit (all built). Add: **expiry date** (`Expires` UTC) and optional **start date**, so codes switch off by themselves.
Status messages map to the screen's `Status` label: redeemed (+reward), already redeemed, expired, not a code.

**Where codes live (Q5):**
- **A. In `Config/Retention` (recommended for launch):** add codes in the repo, publish the game to make them live.
  Simplest, reviewed in git, no admin tools to secure.
- **B. In a DataStore:** add/remove codes from Studio without publishing; all servers pick them up within a minute.
  Needs a small admin script and a refresh loop.

**Rewards a code can give (Q6):** coins (default), Marbles (needs decision 39 change), a free Kiln pull, a specific
cosmetic or glassy (good for launch/milestone codes like "1K likes").

## 4. Settings

**Saving:** one settings record per player, failure-tolerant (a failed load just uses defaults), replacing today's
music-only `MusicPrefsService` store (old music values migrate in). Changes apply instantly on the client and save
on leave and every ~30 s if changed.

| Setting | Default | How it works |
|---|---|---|
| Master volume | 100% | a top `SoundGroup` all sounds route through |
| Music volume | 80% | the existing music SoundGroup |
| SFX volume | 100% | an SFX SoundGroup for UI, fight, power and finisher sounds |
| Bot Play | On | **server:** your queued arena only adds a bot after 15 s if this is On; Off waits for a real player (the board says "Waiting for a player") |
| Auto-Cast Powers | Off | client hides the CAST button; the server already auto-casts after `Cast.AutoSeconds` |
| Large Effects | On | Off forces the existing low-detail effect paths for your own fights and lobby displays |
| Reduced Motion | follows Roblox's setting | sets `PlayerGui.ReducedMotion`, which `Motion.reduced()` already reads |
| Hide Others' Cosmetics | Off | other players' lobby flyers and finisher shows aren't drawn for you |

**Q7:** the round ♪ music button in the top right: remove it once Settings has volume sliders, or keep it as a quick mute?

## 5. Shared pieces

- **Notice dots (Q8):** the gift button shows a red count when something is claimable (daily ready, gift ready),
  using TopbarPlus `notify()`; each dropdown row shows its own dot.
- **Old Rewards window:** retire `RewardsScreen` and point the lobby rewards board (its `OpenRewards` prompt) at the
  new Daily Rewards screen. Quests stay in the code, unchanged and hidden, until their redesign.
- **Order of work:** Settings → Codes → Daily → Playtime → notice dots → retire the old window. Each step: pure rules
  + Lune tests, then service, then client wiring onto the StarterGui templates by element name, then a Studio Play
  test.

Sources: [Roblox Engagement Rewards package](https://create.roblox.com/docs/resources/feature-packages/engagement-rewards),
[DevForum: live redeemable codes](https://devforum.roblox.com/t/live-redeemable-codes/274442/16),
[DevForum: code system help](https://devforum.roblox.com/t/i-need-help-with-code-system/1268904),
[DevForum: codes with DataStore2](https://devforum.roblox.com/t/codes-system-using-datastore2/345845),
[DevForum: playtime gift rewards](https://devforum.roblox.com/t/help-with-playtime-gift-rewards/2644815).

## 6. Decided and built (Oct 19)

| Q | Answer | Built as |
|---|---|---|
| Q1 missed day | Keep your place | `Calendar { Index, LastDay }`, `RetentionRules.calendar/claimDaily` |
| Q2 daily prizes | Coins + free Kiln pull on Day 7 | `Balance.Economy.DailyRewards` 50/75/100/125/150/200, Day 7 = 250 + Kiln pull |
| Q3 timer | Adds up all day (UTC) | existing playtime clock |
| Q4 playtime | Coins, special 60 min | 10/20/30/45/60 → 30/50/75/100 coins, 60 min rotates Kiln pull / Finisher crate / Flyer crate by day |
| Q5 code storage | Game config | `Config/Retention.Codes` with `Starts`/`Expires`; RELEASE (300 coins), HALLOWEEN (Finisher crate, ends Nov 8 2026 UTC) |
| Q6 code rewards | All kinds | coins, Marbles, free pulls, a specific item (`RewardGrant`); Studio-only TEST* codes cover each kind |
| Q7 music button | Remove | removed; Music slider replaces it (old mute/volume migrate in) |
| Q8 notice dots | (default) | red counts on the gift and its Daily / Playtime rows |

Free pulls are **tickets** (`FreePulls`) spent in the normal Shop: the crate's OPEN 1 button reads FREE, odds shown as always.
Settings: `Config/Settings`, `SettingsService` (own DataStore, failure-tolerant), `SettingsController`, `AudioGroups`
(Master > Music/SFX SoundGroups), `LocalSettings` readers used by PowerFX, CombatFeel, FinisherFX, BundleStage, CastButton,
RideController and FightFinisher. Bot Play is read by ArenaService (no bot fill when the lone queued player turned it off).
Quests are hidden; the economy sim now counts 0 quests a day (89 Kiln pulls by day 30, was 92).
