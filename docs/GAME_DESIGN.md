# Glass Clash — Game Design Doc (v0.3)

> **v0.3 (Oct 13) replaces the Pokémon-style structure** (routes, trainers, catching, evolution) with **lobby arena matches**, inspired by the success of *Ball VS Ball* ([research brief](research/BALL_VS_BALL.md)). Older versions are in git history.
> Working names: **Glass Clash** (game), **glassies** (collectibles), **Marbles** (premium currency), **the Kiln** (gacha). All can change.
> **UI mockups:** [Figma](https://www.figma.com/design/r3guIIk5deo7vNxLzJN0RZ) (v0.2 screens; the new screens are listed in [UI_SPEC](ui/UI_SPEC.md)). **Tools and practices:** [RESOURCES.md](RESOURCES.md). **Economy numbers:** [design/ECONOMY.md](design/ECONOMY.md).

## 1. Pitch

**Pick a glass. Pull it back. Let go. Watch it smash.**

Walk up to an arena, roll three glassies from your collection, pick one, aim your pull-back and let go. The two glassies swing on their strings and crash into each other again and again, firing their powers, until one **shatters**. Each player has **3 glass hearts**; lose a round and one pops. Win matches, earn coins, fire up the Kiln for new glassies, from soda bottles all the way to glass dragons.

- **Audience:** all ages, mostly kids. **Mobile first.**
- **Inspiration:** real-life videos where glass bottles hang on strings over a wooden pen and swing into each other until one breaks. The game should be **recognizable as that format**. The match structure (lobby pads, draft from your collection, hearts, auto-battle) is the proven *Ball VS Ball* loop, built in our own form (section 16).

### Pillars

1. **The shatter is the reward.** Every round ends in a slow-motion, loud, sparkly shatter. If a change makes it less satisfying, don't make it.
2. **Simple to play, fun to watch.** Two decisions per round (which glassy, how far to pull back) plus one tap (your special). Everything else is a show. Anyone watching the arena should understand it in 3 seconds.
3. **From kitchen to fantasy.** Common glassies are things from your kitchen; rare ones are swords, unicorns and dragons. Players see the fantasy ones from day one (the Kiln, other players' fights) so they have something to chase.
4. **Fair and readable.** Rarity adds flair and a small edge, never an auto-win. Every glassy has one clear gimmick you can see happen.
5. **Always something to watch.** Arenas sit along the lobby path, so waiting players watch real fights.

## 2. Match loop

```
Lobby  →  step on an arena pad (1v1; a bot joins after 15 s)
  → Round (repeat until someone loses 3 hearts):
       Roll: 3 random glassies from YOUR collection → pick 1 (8 s; reroll: 1 free, then Marbles)
       Aim: drag to set your pull-back angle; a Perfect band glows on the arc (6 s)
       3-2-1 → both release at once
       Fight: they swing and smash; passives fire by themselves; tap SPECIAL once when charged
       Shatter → the loser's heart pops
  → Results: coins (+ trophies vs players), quest progress
  → the Kiln (coins → new glassy, odds shown) → back to the pads
```

| Phase | Time | Notes |
|---|---|---|
| Queue | until 2 players, or a bot after `QueueBotAfterSeconds` (15 s) | Standing on the pad = queued; stepping off leaves. |
| Roll | `RollSeconds` 8 s | Offers are uniform from owned glassies, no repeats. Timer out → first offer. Picks are hidden until both lock in. |
| Aim | `AimSeconds` 6 s | No aim → `AimDefault`. |
| Countdown | 3 s | Shows both picks with type icons ("Fizzy beats Heavy!"). |
| Fight | ~15–45 s (avg ~27) | Section 3. Overtime after 45 s, timeout at 75 s. |
| Round end | 4 s | Shatter, heart pops, short replay of the final blow. |

A match is **first to make the other lose 3 hearts** (3–5 rounds, ~3.7 min on average). Numbers: `Balance.Match`.

**Example 10-minute session:** claim the daily streak, play 3 matches (win 2), pull the Kiln twice (a Rare light bulb!), finish a "Win 3 rounds with a Sharp glassy" quest, watch a friend's fight while waiting, leave.

## 3. The fight

### 3.1 The swing (built by Codex in Studio)

A **Clash Stand** is an A-frame swing set (never a gallows) over a wooden octagon pen. Two glassies hang from hooks on one crossbar, `HookGap` apart, on strings of `StringLength` 5 studs (drawn with `Beam`s).

- The swing is a **pendulum in the stand's plane**, simulated by our own code on the server (not Roblox physics), streamed to clients, which interpolate and render anchored glassies with CFrames.
- Each glassy **keeps itself swinging** toward a target height from its Swing stat (`Motion.AmplitudeBase + AmplitudePerSwing × Swing`), so the fight never dies down.
- When they touch (circle radius `Glassy.Radius`) they **bounce** (`Restitution`, heavier glass pushes harder: `MassByType`). Every bounce faster than `MinHitSpeed` is a **hit** and is reported to `FightRules.hit(speed, shareA)`.
- **Starting values** are in `Balance.Motion`. Codex tunes them by eye in Studio; the goal is a hit roughly every 1–1.5 s with clear wind-ups, big smashes and the occasional glancing tap.

### 3.2 Aim

Before release you drag your glassy back along an arc (`AimMin`–`AimMax` radians). Each round a random **Perfect band** (`SweetSpotWidth` either side) glows on the arc, the same for both players. Release inside it for a **Perfect Release**: your first hit deals ×`PerfectFirstHitMult` (2.0) and your special starts `PerfectCharge` (25%) charged. Pulling back further also gives a faster first swing.

### 3.3 Damage (both glassies take damage on every hit)

```
damage = DamageScale × Power
       × min((speed / RefSpeed) ^ SpeedExponent, SpeedFactorMax)   -- big swings smash
       × (ShareBase + ShareWeight × share)                         -- who moved into the hit
       × (2m / (m + m_other)) ^ MassExponent                       -- heavier glass hits a bit harder
       × type × variance (0.6–1.4) × crit (×2) × powers × overtime
```

Crit chance = `CritBase + CritPerSwing × Swing` (max 30%), plus Lucky. All in `FightRules.hitDamage`.

### 3.4 Types (rock-paper-scissors)

**Heavy** beats **Sharp**, **Sharp** beats **Fizzy**, **Fizzy** beats **Heavy** (×1.04 / ×0.96). Type advantage wins about 60–80% of even fights: it matters, but it never decides a fight alone. Types also set base-stat leans and mass:

| Type | Lean (Power / HP / Swing) | Mass | Feel |
|---|---|---|---|
| Heavy | 20 / 112 / 6 | 1.3 | Slow, steady, pushes the other glass around |
| Fizzy | 20 / 110 / 10 | 1.0 | Balanced |
| Sharp | 21 / 105 / 14 | 0.85 | Swings high, crits more, cracks a bit sooner |

### 3.5 Powers

Every glassy has **one passive** (fires by itself) and **one special** (charges up; the player taps once to fire it, once per round). Glassies can rename them ("Lid Shield", "Prism Beam"). Numbers live in `Config/Powers.luau`.

| Passive | Effect |
|---|---|
| Fizz Burst | Every 4th hit fizzes over: +75% damage |
| Sharp Edge | Hits leave cracks that chip 15% of the hit over 3 s (3 stacks) |
| Sturdy | Takes 12% less damage |
| Spiky Rim (thorns) | Bounces 12% of damage taken back |
| Sticky | Hits slow the other glass's swing 15% for 3 s (3 stacks) |
| Lucky Glint | +20% crit chance |
| Second Wind | Once per round, survives a shattering hit with 10% HP |
| Glow Core | Heals 0.45% max HP per second |
| Momentum | +4% damage per hit landed (max 5 stacks); a crit taken resets it |

| Special | Effect |
|---|---|
| Slam | The next hit within 3 s deals ×3.5 and knocks the other glass back hard |
| Shield | Blocks all damage for 2.2 s |
| Big Swing (pump) | Swings 50% higher and hits 30% harder for 5 s |
| Freeze | The other glass stops driving its swing for 4 s |
| Beam | Zaps the other glass for 8% of its max HP, from a distance |
| Glaze | Heals 8% max HP and seals all cracks |

**Charge:** `ChargePerSecond` + per hit dealt + per hit taken (full in ~10–15 s). A glowing **SPECIAL** button appears when ready. **Bots** fire theirs 0.2–1.5 s after it's ready. Using your special wins about 70% of otherwise even fights; good timing (shield before a smash, slam on a big swing) is the skill.

### 3.6 HP, cracks and round end

- HP comes from base stats × rarity × stars (`Formula.stats`). Crack stages at 75 / 50 / 25 % HP.
- **Shatter:** HP 0 → slow-mo shatter, the loser's heart pops.
- **Double KO:** if both drop to 0 on the same hit, the one with more HP *before* the hit survives on 1 HP (a clutch moment).
- **Overtime** after 45 s: damage grows 6% per second. **Timeout** at 75 s: higher HP % wins (rare: <1% in the sim).

### 3.7 Balance targets (checked by `lune run tools/run_tests`)

| Target | Value |
|---|---|
| Round length | 15–45 s, 8–40 hits; timeouts < 5% |
| Side bias | 42–58% |
| Starter triangle | each starter beats one, loses to one (52–90%) |
| Perfect vs worst aim | 53–75% |
| Special used vs never | 55–80% |
| Mythic vs Common, 5 stars vs 0 | 60–95% / 60–98% |
| Every glassy at equal stats vs the field | 38–62% |

These run against **FightModel**, a stand-in for the swing. When the real swing works in Studio, log real hits per second and speeds and update `Balance.SimModel` so the simulator stays honest.

### 3.8 Server authority and anti-exploit

- The server runs the swing and `FightRules`; clients only render. Inputs: `PickGlassy`, `Reroll`, `SetAim`, `UseSpecial`, `LeaveQueue`. Validate types and ranges, and **rate-limit every remote** (`Balance.Match.*RateSeconds`).
- Rewards are granted by the server from `MatchLogic.rewards`. Bots never take trophies.
- Log suspicious patterns (e.g. Perfect Release rate per player) for review.

## 4. Glassies and collection

### 4.1 Glassies are data

One entry in `Config/Glassies.luau` + one asset folder = a new glassy. Fields: Type, Rarity, Base stats, Passive, Special (+ names), Radius, Tint, ClinkPitch, Asset, Description.

### 4.2 Rarity: from kitchen to fantasy

| Rarity | Stat × | Kiln odds | Examples |
|---|---|---|---|
| Starter | 1.02 | — (everyone owns all 3) | Pop, Jam, Prism |
| Common | 1.00 | 56.25% | milk bottle, pickle jar, glass cup |
| Uncommon | 1.02 | 22% | mason jar, hot sauce |
| Rare | 1.04 | 14% | perfume, potion flask, light bulb |
| Epic | 1.06 | 6% | rocket pop, jack-o'-glass, crystal ball |
| Legendary | 1.08 | 1.5% | glass sword, unicorn, crystal crown |
| Mythic | 1.10 | 0.25% | glass dragon, galaxy orb |

Rarity is mostly **flair, size and a cooler power**, with a small stat edge. A Mythic beats a Common about 80% of the time.

### 4.3 Stars and Rainbow

- **Duplicates** from the Kiln add a **star** (+2% stats each, max 5). Past 5 stars a duplicate gives `DuplicateCoinsAtMaxStars` coins.
- **Rainbow** variant: 1 in 500 Kiln pulls, +5% stats and an iridescent shimmer. (Later: fuse duplicates into Rainbow like Ball VS Ball's Shiny/Rainbow, but in our own way, e.g. "re-melt" 5 stars into Rainbow in the Kiln.)

### 4.4 The roster (31)

Starters Pop (Fizzy), Jam (Heavy), Prism (Sharp) plus 28 in the Kiln: see `Config/Glassies.luau`. Models exist for the 3 starters; the rest are built in Blender in batches (ART_BIBLE).

## 5. World: the lobby

One compact lobby, **linear**: spawn at one end, a path lined with arenas, shops and the Kiln along it, and the best arenas at the far end. Map concepts and the chosen direction: [art/MAP_PLAN.md](art/MAP_PLAN.md).

- **Spawn plaza** with the Kiln (or close by) and the daily rewards.
- **8 arena stands** along the path (more later), each with 2 pads, a scoreboard and a few spectator benches. Arenas are 1v1; their pens are visible from the path so walking past means watching fights.
- **Champion Arena** at the end: same rules, highest-trophy players' fights get shown on a big board.
- Shops: Shatter FX booth, Marble shop (with the Kiln odds board), leaderboards (Trophies, Wins, Shatters).
- No routes or zones for the MVP. Later: seasonal decorations, a second themed arena row.

## 6. Bots

- Fill any pad after 15 s alone. Name them like players' pets ("Bottle Bot", original names only), with a small BOT tag.
- **Collection:** the starters plus random glassies up to the player's best rarity, same size as the player's collection (`MatchLogic.botCollection`).
- **Skill** 0.2–0.7 (`BotSkillMin/Max`): aim error and smarter picks (counter the player's last type). Bots auto-fire specials.
- Rewards vs bots: 60% coins, +5 trophies on a win, never lose trophies.

## 7. Social and events

- **Spectating:** arena pens face the path; a spectator camera button on each scoreboard.
- **Friends:** invite a friend to your pad (party pads). 2v2 is a later update.
- **Weekly events (post-launch):** new glassies + a code every week; weekend "Double Shatters" coin events; a seasonal bracket tournament (8 players, bracket board in the lobby, free "Pick the Winner").
- No trading at launch (scam and policy risk).

## 8. Economy (summary; full numbers in [design/ECONOMY.md](design/ECONOMY.md))

- **Coins** (earned): 10 per round won + 60 for a match win or 20 for a loss (60% vs bots); daily quests 75 each; playtime gifts; first win of the day 100.
- **The Kiln:** 300 coins a pull (10 for 2,700). **Odds are always shown before pulling.** New players get 1 free pull after their first match.
- **Marbles** (premium): Robux packs + small free amounts (login streak, group join). Spent on **rerolls** (5 / 10 / 20 after the free one each match), Shatter FX, and later cosmetics.
- Pacing targets (simulated): ~3 pulls on day 1, first Rare in under an hour, first Epic in ~2 h, first Legendary in ~9 h of play, Mythics as a long chase.

## 9. Game feel checklist (the shatter)

**Every hit**
- [ ] Hitstop 60–100 ms on big hits only (speed above ~RefSpeed), so fights keep flowing
- [ ] Clink pitched by size (`ClinkPitch`), crack sound layered when a new crack stage starts
- [ ] Camera shake scaled to damage; damage numbers; **CRIT!**, **SMASH!** (big speed), power names when passives fire
- [ ] Crack stage swaps at 75 / 50 / 25 %
- [ ] Haptic pulse on mobile and controller

**Specials**
- [ ] Each special has its own color, sound and screen-edge flash (Shield bubble, Freeze frost, Beam ray, Slam glow, Big Swing trail, Glaze shine)

**Final blow**
- [ ] Slow motion 0.3× for ~1 s, camera cuts side-on and pushes in
- [ ] One white flash frame; swap to pre-fractured shards with velocity and spin; liquid splash if filled; glitter
- [ ] Layered shatter sound, then the tinkle of falling shards
- [ ] The winner's **Shatter FX** plays; **SHATTERED!** banner; shards fade after 3 s
- [ ] The loser's **glass heart** cracks and pops above their pad

**Test:** record a round on a phone. If the last 3 seconds don't make a good clip, keep tuning before adding content.

## 10. Monetization (kid-safe)

| Item | Kind | Notes |
|---|---|---|
| Marble packs | Dev products | 40 / 100 / 220 / 600 Marbles; value improves gently with size |
| VIP | Gamepass | Chat tag, +10% coins, VIP bench at the Champion Arena |
| 2× Coins | Gamepass | |
| Shatter FX, Fills, stand skins, heart skins | Marbles / Robux direct buy | The main cosmetics: everyone in the arena sees them |
| Private server | | |

**Rules (non-negotiable):**
- Kiln odds shown before every pull. If we ever add a **Robux or Marble Kiln**, show odds before purchase and **hide it for players where `PolicyService` → `ArePaidRandomItemsRestricted`**, with direct-buy alternatives.
- **No Robux-only glassies that are stronger.** Paid exclusives are cosmetic variants only.
- No serial-numbered paid scarcity or countdown pressure aimed at kids; no spending leaderboards; no betting or wagering, ever.
- Paid rerolls only reshuffle *your own* glassies (they don't grant items). Keep them cheap, keep one free reroll per match, and give Marbles for free regularly so it never feels pay-to-win. (Revisit after launch data; see DECISIONS.)

## 11. Retention and community

- 7-day login streak (Marbles on days 3 and 7), 3 daily quests ("Win 3 rounds", "Land 2 Perfect Releases", "Shatter a Heavy glassy"), playtime gifts at 5 / 15 / 30 / 60 min.
- **Group join** reward (20 Marbles) and like reminder.
- **Index:** every glassy, unowned ones as silhouettes; rewards for owning all of a rarity.
- Leaderboards: Trophies, Match Wins, Shatters, Best Win Streak.
- **Weekly updates:** 2–3 new glassies + a code. Community votes on the next glassy on Discord; build it with the Blender pipeline.

## 12. Marketing

- Render **bracket videos in the real-life format** with in-game models ("16 glassies, only one survives"), mixing kitchen glass with fantasy glass. End with "Play on Roblox".
- Record slow-mo shatters in-game for Shorts and TikTok; the arena camera should make this easy.
- Cross-promote from your existing game at launch. Paid ads only once D1 retention is healthy.
- **Seasonal:** winter (snow globes, ornaments, glass reindeer), Valentine's (heart bottles, glass roses), Halloween (pumpkins, ghost jars).

## 13. UI

The **crisp glass** style from v0.2 stays: dark frosted panels, thin cyan → violet edges, Montserrat, color meanings (green buy, red close, yellow special, blue neutral, purple fuse), rarity and type colors. Build from `Theme` and the shared components in `src/client/UI`. Screens and layouts: **[ui/UI_SPEC.md](ui/UI_SPEC.md)**.

Key screens: Lobby HUD, Queue panel, **Roll** (3 cards + reroll), **Aim** (drag on the arc, Perfect band, lock button), **Fight HUD** (HP bars, hearts, SPECIAL button), Results, **Kiln** (odds first), Collection + Index, Shop.

## 14. Technical plan

```
ServerScriptService/Server/Services/
  DataService        -- ProfileStore: coins, marbles, collection, trophies, quests, receipts
  ArenaService       -- pads, queue, bot fill, one MatchRunner per arena
  MatchService       -- match phases + timers; uses MatchLogic; handles PickGlassy/Reroll/SetAim/LeaveQueue
  FightService       -- swing simulation (Codex) + FightRules; UseSpecial; streams FightSnapshot/FightEvents
  KilnService        -- odds, pulls (Formula.rollKiln), duplicates -> stars, PolicyService checks
  RewardService      -- quests, playtime gifts, login streak, codes, group reward
  MonetizationService -- gamepasses, ProcessReceipt (idempotent)
ReplicatedStorage/Shared/
  Config/  Balance, Glassies, Powers, Cosmetics, Audio, CrackPaths
  FightRules, MatchLogic, Formula, Rng   -- pure, tested in Lune
  Remotes                                -- the remote contract
StarterPlayerScripts/Client/
  Controllers/  ArenaController, FightController (render + camera), ShatterController, UIController
  UI/  Theme, Components, Screens (LobbyHud, Roll, Aim, FightHud, Results, Kiln, Collection, Shop)
ServerStorage/Tests/  RunAll + suites, BalanceSim, EconomySim, FightModel
```

- **Pure modules** (`FightRules`, `MatchLogic`, `Formula`, `Config/*`) have no Roblox APIs and run in Lune: `lune run tools/run_tests`, `lune run tools/balance_sim`, `lune run tools/economy_sim`.
- **Snapshots:** the server steps the swing at 60 Hz and sends `FightSnapshot` (angles, angular speeds, HP, charge) at 20 Hz on an `UnreliableRemoteEvent`; clients render ~0.1 s behind and interpolate. `FightEvents` (reliable) carry hits, powers and the shatter, timestamped so effects line up with the motion.
- **Save data** (ProfileStore):

```lua
{
	Version = 2,
	Coins = 0,
	Marbles = 0,
	Trophies = 0,
	Glassies = { -- [id] = { Stars = 0, Rainbow = false, Count = 1, FirstAt = os.time() }
	},
	Cosmetics = { ShatterFx = { "default" }, EquippedShatterFx = "default", Fills = {} },
	Stats = { MatchWins = 0, MatchLosses = 0, RoundWins = 0, Shatters = 0, Perfects = 0, BestStreak = 0, KilnPulls = 0 },
	Daily = { Streak = 0, LastClaimDay = 0, Quests = {}, FirstWinDay = 0, PlaytimeClaimed = {} },
	Flags = { WelcomePullUsed = false, GroupRewardClaimed = false },
	CodesRedeemed = {},
	ProcessedReceipts = {},
}
```

- **Blender asset spec** per glassy is in ART_BIBLE (body with origin at the hang point, 12–20 shards, icon).

## 15. Milestones (see ROADMAP)

| Week | Dates | Goal |
|---|---|---|
| 1 | Oct 13–19 | **Fight prototype:** swing + FightRules on one stand, aim, special button, shatter. Feels great on a phone. |
| 2 | Oct 20–26 | Match flow: pads, queue, bots, roll/aim/fight/hearts/results. Lobby blockout. |
| 3 | Oct 27–Nov 2 | Data, Kiln, collection, 9 more glassies modelled, lobby art pass |
| 4 | Nov 3–9 | Quests, gifts, codes, shop, Shatter FX, Marbles, PolicyService, analytics |
| 5 | Nov 10–16 | Polish, phone testing, **soft launch** |
| After | weekly | 2–3 glassies + code a week; winter event ~Dec 12; tournaments and 2v2 later |

## 15b. Metrics

- D1 / D7 retention, session length, matches per session, ARPDAU, payer conversion.
- Custom events: rounds played, % rounds with a Perfect Release, special use rate and timing, rerolls (free vs paid), Kiln pulls, time to first Rare/Epic/Legendary, bot vs player match share.
- Funnel: join → first match → first round win → first Kiln pull → second session.

## 16. Not a copy of Ball VS Ball

What we take is the structure (lobby pads, draft from your collection, hearts, auto-battle, coin gacha, weekly content). What's ours:
- **Glass on strings** swinging over a wooden pen, from real-life videos, not balls in a box.
- **Aim = pull-back** with a Perfect band; **one special tap** per round.
- **Glass hearts** that pop (we never fling anything at players' avatars).
- **The Kiln** (glassblowing reveal), **Marbles**, kitchen-to-fantasy glass.
- Our own names, art, UI and powers. Don't copy their names ("Flyers", "Explosions", "Gems/Diamonds"), balls, abilities, screens or arena.

## 17. Open questions

- Final names (game, glassies, Marbles, Kiln).
- Lobby theme: pick one of the map concepts (MAP_PLAN).
- Paid rerolls: keep (user's call) or make them earn-only (research recommendation)? See DECISIONS 25.
- Should each player get one free "pick any glassy" per match (Ball VS Ball has this)? Proposed, not in code yet.
