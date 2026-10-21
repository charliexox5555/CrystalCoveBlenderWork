# Glass Clash — Game Design Doc (v0.3)

> **v0.3.1 (Oct 14):** powers fire by themselves at random moments (no button), and the swing is erratic and 3D with spin. Luck and suspense are a pillar.
> **v0.3 (Oct 13) replaces the Pokémon-style structure** (routes, trainers, catching, evolution) with **lobby arena matches**, inspired by the success of *Ball VS Ball* ([research brief](research/BALL_VS_BALL.md)). Older versions are in git history.
> Working names: **Glass Clash** (game), **glassies** (collectibles), **Marbles** (premium currency), **the Kiln** (gacha). All can change.
> **UI mockups:** [Figma](https://www.figma.com/design/r3guIIk5deo7vNxLzJN0RZ) (v0.2 screens; the new screens are listed in [UI_SPEC](ui/UI_SPEC.md)). **Tools and practices:** [RESOURCES.md](RESOURCES.md). **Economy numbers:** [design/ECONOMY.md](design/ECONOMY.md).

## 1. Pitch

**Pick a glass. Pull it back. Let go. Watch it smash.**

Walk up to an arena, roll three glassies from your collection, pick one, aim your pull-back and let go. The two glassies swing wildly on their strings, in every direction, crash into each other, sometimes whoosh past, spin and wobble, and their powers go off at random moments, until one **shatters**. Each player has **3 glass hearts**; lose a round and one pops. Win matches, earn coins, fire up the Kiln for new glassies, from soda bottles all the way to glass dragons.

- **Audience:** all ages, mostly kids. **Mobile first.**
- **Inspiration:** real-life videos where glass bottles hang on strings over a wooden pen and swing into each other until one breaks. The game should be **recognizable as that format**. The match structure (lobby pads, draft from your collection, hearts, auto-battle) is the proven *Ball VS Ball* loop, built in our own form (section 16).

### Pillars

1. **The shatter is the reward.** Every round ends in a slow-motion, loud, sparkly shatter. If a change makes it less satisfying, don't make it.
2. **Simple to play, fun to watch.** Two decisions per round (which glassy, and how and where to pull it back). Everything after the release is a show. Anyone watching the arena should understand it in 3 seconds.
3. **Luck and suspense.** Like Ball VS Ball, the best glassy doesn't always win. Swings miss, powers fire at good or bad moments and can whiff, a lucky smash turns a round around. Strong glassies win more often, never every time.
4. **From kitchen to fantasy.** Common glassies are things from your kitchen; rare ones are swords, unicorns and dragons. Players see the fantasy ones from day one (the Kiln, other players' fights) so they have something to chase.
5. **Fair and readable.** Rarity adds flair and a small edge, never an auto-win. Every glassy has one clear gimmick you can see happen.
6. **Always something to watch.** Arenas sit along the lobby path, so waiting players watch real fights.

## 2. Match loop

```
Lobby  →  step on an arena pad (1v1; a bot joins after 15 s)
  → Round (repeat until someone loses 3 hearts):
       Match start: roll 3 equally likely, distinct owned glassies once; retain this hand all match.
       Each round: pick from that hand (8 s), or use round-only Pick Any. Paid reroll replaces the hand.
       Aim: drag to pull your glassy back: how far (a Perfect band glows) and which way (6 s)
       3-2-1 → both release at once
       Fight: they swing, smash, miss, spin; passives and powers fire by themselves (no input)
       Shatter → the loser's heart pops
  → Results: coins (+ trophies vs players), quest progress
  → the Kiln (coins → new glassy, odds shown) → back to the pads
```

| Phase | Time | Notes |
|---|---|---|
| Queue | until 2 players, or a bot after `QueueBotAfterSeconds` (15 s) | Standing on the pad = queued; stepping off leaves. |
| Roll | `RollSeconds` 8 s | Initial hand is uniform from owned glassies with no repeats; retained across rounds. Paid rerolls replace all three. Pick Any chooses any owned glassy for this round without changing the hand. Timer out → first offer. Picks are hidden until both lock in. |
| Aim | `AimSeconds` 6 s | No aim → `AimDefault`. |
| Countdown | 3 s | Shows both picks with type icons ("Fizzy beats Heavy!"). |
| Fight | ~15–45 s (avg ~27) | Section 3. Overtime after 45 s, timeout at 75 s. |
| Round end | 4 s | Shatter, heart pops, short replay of the final blow. |

A match is **first to make the other lose 3 hearts** (3–5 rounds, ~3.7 min on average). Numbers: `Balance.Match`.

**Example 10-minute session:** claim the daily streak, play 3 matches (win 2), pull the Kiln twice (a Rare light bulb!), finish a "Win 3 rounds with a Sharp glassy" quest, watch a friend's fight while waiting, leave.

## 3. The fight

### 3.1 The swing: erratic, 3D, spinning (built by Codex in Studio)

A **Clash Stand** is an A-frame swing set (never a gallows) over a wooden octagon pen. Two glassies hang from hooks on one crossbar, `HookGap` (6) apart, on strings of `StringLength` (7), shown `GlassyScale` (1.75×) bigger than true size (DECISIONS 30).

- **3D pendulums** (DECISIONS 34): each glassy swings on a sphere around its hook, not just in the stand's plane. They can **swing past each other**, loop round and come back. Random sideways nudges (`WanderStrength`) keep swings from repeating, so no two rounds look alike.
- **Bounces with spin:** when they touch they bounce (`Restitution`, heavier glass pushes harder: `MassByType`). An off-centre hit throws the glass sideways (`HitDeflect`) and **spins it on its string** (`SpinFromHit`): the string winds up and unwinds (`TwistStiffness`). Big hits also **tumble** the body (tilt and wobble back).
- Each glassy **keeps itself swinging** toward a target height from its Swing stat, so the fight never dies down.
- Our own simulation on the server (not Roblox physics), streamed to clients, which interpolate and render anchored glassies with CFrames. Every touch faster than `MinHitSpeed` is a **hit** → `FightRules.hit(speed, shareA)`.
- **Feel target:** a mix of big smashes, glancing taps and near-misses, roughly one real hit every 1.5–2 s, swings you can't quite predict. Starting values in `Balance.Motion`; Codex tunes by eye.

### 3.2 Aim

Before release you drag your glassy back: **how far** (`AimMin`–`AimMax`) and **which way** (up to `AimYawMax` either side of straight at the other glass). Each round a random **Perfect band** on the pull distance glows, the same for both players. Release inside it for a **Perfect Release**: your first hit deals ×`PerfectFirstHitMult` (2.0) and your first power comes `PerfectPowerAdvance` (3 s) sooner. Angled pulls make wilder 3D swings: riskier, sometimes better.

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

### 3.5 Powers (automatic, with an optional CAST)

Every glassy has **one signature power** with its own trigger (contacts, swing turnarounds, a timer, low HP, hits taken). When the trigger fires, the power becomes **Ready** and a big **CAST** button lights up (DECISIONS 85, revising 33):

- **Tap CAST** to fire it now. The button glows gold and says NOW! at a good moment (the glassies closing in, or a smash about to land), so timing is learnable.
- **Ignore it** and it fires by itself after `Cast.AutoSeconds` (1.6 s). Young players can just watch; pressing as soon as it lights up is never worse than waiting (real swing: 52% vs auto).
- **Contact powers** (Pop, Pickle Jar, Ketchup, Briar Flask, Mason Jar) **arm** instead: the next contact within `Cast.ArmedSeconds` (3 s) pays off. Arm right before a smash; an arm with no contact fades.
- Bots press CAST with a reaction delay and moment-reading that scale with their skill.
- Target: a quick player who times casts beats an auto-only player 55–62% with the same glassy. Skill matters, never decides alone.

The legacy passive/burst tables below describe dormant definitions. The 24 release kits live in `Balance.CombatRelease.Kits`. Glassies can rename them ("Lid Shield", "Prism Beam", "Hot Streak"). Numbers live in `Config/Powers.luau`.

**When powers fire (placeholder formula, to be refined):** the first after a random 5–14 s, then again after 9–18 s, at most 3 times a round. Every hit (dealt or taken) brings the next one 0.5 s closer. A Perfect Release brings the first one 3 s closer. (`Balance.Fight.Power*`)

**Luck is the point:** a Rage that fires while the glasses are far apart is wasted; a Shield that pops just before a smash saves the round; a Slam only counts if a hit comes within 3 s. **Aimed powers (Beam, Freeze) can miss** depending on where the glasses are when they fire: the swing code decides from the 3D positions (`PowerLands`), the simulator rolls `LandChance`. Counter-powers between glassies come later (glass brainstorms).

| Passive | Effect |
|---|---|
| Fizz Burst | Every 4th hit fizzes over: +75% damage |
| Sharp Edge | Hits leave cracks that chip 15% of the hit over 3 s (3 stacks) |
| Sturdy | Takes 12% less damage |
| Spiky Rim (thorns) | Bounces 12% of damage taken back |
| Sticky | Hits slow the other glass's swing 20% for 3 s (3 stacks) |
| Lucky Glint | +20% crit chance |
| Second Wind | Once per round, survives a shattering hit with 8% HP |
| Glow Core | Heals 0.55% max HP per second |
| Momentum | +4% damage per hit landed (max 5 stacks); a crit taken resets it |

| Burst power | Effect | Can miss? |
|---|---|---|
| Rage | +75% damage for 3 s | No (but wasted if no hits land) |
| Slam | The next hit within 3 s deals ×2.3 and knocks the other glass back hard | No (wasted without a hit) |
| Shield | Blocks all damage for 1.8 s | No |
| Big Swing (pump) | Swings 50% higher and hits 30% harder for 4 s | No |
| Freeze | The other glass barely swings for 3 s and turns brittle (×1.5 damage taken from you) | Yes (~30%) |
| Beam | Zaps the other glass for 9.5% of its max HP | Yes (~35%) |
| Glaze | Heals 6% max HP and seals all cracks | No |

### 3.6 HP, cracks and round end

- HP comes from base stats × rarity × stars (`Formula.stats`). Crack stages at 75 / 50 / 25 % HP.
- **Shatter:** HP 0 → slow-mo shatter, the loser's heart pops.
- **Double KO:** if both drop to 0 on the same hit, the one with more HP *before* the hit survives on 1 HP (a clutch moment).
- **Overtime** after 45 s: damage grows 6% per second. **Timeout** at 75 s: higher HP % wins (rare: <1% in the sim).

### 3.7 Balance targets (checked by `lune run tools/run_tests`)

| Target | Value |
|---|---|
| Round length | 15–45 s, 6–40 hits; timeouts < 5% |
| Side bias | 42–58% |
| Starter triangle | each starter beats one, loses to one (52–90%) |
| Perfect vs worst aim | 53–75% |
| Luck | winner was behind at some point in 35–80% of rounds; ≥ 1 lead change a round; 1.2–3 powers per glassy; 20–50% of aimed powers miss |
| Mythic vs Common at equal kit strength, 5 stars vs 0 | ~55% / ≤ 62% (DECISIONS 86) |
| Every release glassy at equal stats vs the field, **real swing** (`tools/release_matrix.sh`) | 45–55% |
| Timed CAST vs auto-only, same glassy | 55–62% |

These run against **FightModel**, a stand-in for the swing. When the real swing works in Studio, log real hits per second and speeds and update `Balance.SimModel` so the simulator stays honest.

### 3.8 Server authority and anti-exploit

- The server runs the swing and `FightRules`; clients only render. Inputs: `PickGlassy`, `Reroll`, `SetAim`, `LeaveQueue`. Validate types and ranges, and **rate-limit every remote** (`Balance.Match.*RateSeconds`).
- Rewards are granted by the server from `MatchLogic.rewards`. Bots never take trophies.
- Log suspicious patterns (e.g. Perfect Release rate per player) for review.

## 4. Glassies and collection

### 4.1 Glassies are data

One entry in `Config/Glassies.luau` + one asset folder = a new glassy. Fields: Type, Rarity, Base stats, Passive, Special (+ names), Radius, Tint, ClinkPitch, Asset, Description.

### 4.2 Rarity: from kitchen to fantasy

| Rarity | HP × | Kiln odds | Examples |
|---|---|---|---|
| Starter | 1.01 | — (unused since decision 102: Pop, Jam, Prism are Commons) | — |
| Common | 1.00 | 56.25% | milk bottle, pickle jar, glass cup |
| Uncommon | 1.01 | 22% | mason jar, hot sauce |
| Rare | 1.015 | 14% | crescent axe, frostglobe |
| Epic | 1.02 | 6% | rocket pop, prism blade |
| Legendary | 1.025 | 1.5% | comet |
| Mythic | 1.03 | 0.25% | glass dragon, galaxy orb |

Rarity buys **flair, size, more complex powers and bigger presentation**, not numbers (DECISIONS 86, like Blade Ball's sidegrade abilities). The multiplier touches **HP only**; Power and Swing stay at the glassy's base. At equal skill a Mythic beats a Common about **55%** of the time.

### 4.3 Stars and Rainbow

- **Duplicates** from the Kiln add a **star** (+0.6% HP each, max 5, so +3% at most; 5 stars beat 0 about 55%). Past 5 stars a duplicate gives `DuplicateCoinsAtMaxStars` coins.
- **Rainbow** variant: 1 in 500 Kiln pulls, +2% HP and an iridescent shimmer. (Later: fuse duplicates into Rainbow like Ball VS Ball's Shiny/Rainbow, but in our own way, e.g. "re-melt" 5 stars into Rainbow in the Kiln.)

### 4.4 The roster (31)

Pop (Fizzy), Jam (Heavy) and Prism (Sharp) were the starters; since decision 102 they are Common Kiln drops and new players start with the 3 welcome opens. Plus 28 configured for the Kiln: see `Config/Glassies.luau`. Twelve native models are installed (3 starters + 6 Commons + 3 Uncommons). The Kiln only rolls the nine installed non-starters and displays their normalized odds; remaining art is built in Blender batches (ART_BIBLE).

## 5. World: the lobby

**Crystal Isles** (DECISIONS 28): a row of floating grassy islands above the clouds, joined by short bridges, climbing gently away from spawn. Layout and build plan: [art/MAP_PLAN.md](art/MAP_PLAN.md).

- **Lobby island:** spawn, the Kiln, shop, daily reward, codes, Index, leaderboards and the champion statue.
- **3 arena islands**, 2 stands each (arenas 1–6), with a viewing walkway down the middle so passers-by see every swing side-on. Each stand has 2 queue pads (A blue, B orange) with a floating free/busy marker.
- **Featured island** at the end (arena 7) under a crystal arch, with bleachers: same rules, highest-trophy players' fights get shown on a big board.
- Falling off teleports you back onto the island (no death).
- Shops: Shatter FX booth, Marble shop (with the Kiln odds board), leaderboards (Trophies, Wins, Shatters).
- No routes or zones for the MVP. Later: seasonal decorations, a second themed arena row.

## 6. Bots

- Fill any pad after 15 s alone. Name them like players' pets ("Bottle Bot", original names only), with a small BOT tag.
- **Collection:** random glassies up to the player's best rarity, same size as the player's collection, at least 3 (`MatchLogic.botCollection`).
- **Skill** 0.2–0.7 (`BotSkillMin/Max`): aim error and smarter picks (counter the player's last type). Bots auto-fire specials.
- Rewards vs bots: same coins as vs players, +5 trophies on a win, never lose trophies.

## 7. Social and events

- **Spectating:** arena pens face the path; a spectator camera button on each scoreboard.
- **Friends:** invite a friend to your pad (party pads). 2v2 is a later update.
- **Weekly events (post-launch):** new glassies + a code every week; weekend "Double Shatters" coin events; a seasonal bracket tournament (8 players, bracket board in the lobby, free "Pick the Winner").
- No trading at launch (scam and policy risk).

## 8. Economy (summary; full numbers in [design/ECONOMY.md](design/ECONOMY.md))

- **Coins** (earned, decision 84): **100 for every match win**; a loss pays 8 + 10 per heart taken + 5 per glassy of chip damage + 2 per Perfect Release, max 40 (quitting pays 0); daily quests 75 each; playtime gifts; first win of the day 100.
- **Abandoned matches:** until at least one real round completes, neither player earns coins, trophies, match/quest stats or welcome-pull eligibility. Results say "No rewards — finish a round first". After a completed round, existing MatchLogic forfeit rewards apply. Creator accepted October 14 (DECISIONS 42).
- **The Kiln:** 300 coins a pull (10 for 2,700). **Odds are always shown before pulling.** New players get 1 free pull after their first match.
- **Marbles** (premium): Robux packs + small free amounts (login streak, group join). Spent on **match-hand rerolls** (3 / 3 / 6 / 6 / 9, capped at 9) and **Pick Any** (one free per match, then 6 / 9 / 12, capped at 12), Shatter FX, and later cosmetics. Both usage counters reset each match. Marble packs and free grants remain deferred in the current implementation.
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
- Paid rerolls only reshuffle *your own* glassies (they don't grant items), with equal odds and no duplicates. Every paid action asks for confirmation; rerolls show every eligible outcome and inclusion probability and are hidden when paid-random policy is restricted or unavailable. Pick Any is deterministic and selects only this round's glassy; one use per match is free. See decision 55 for accepted prices.

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

Key screens: Lobby HUD, Queue panel, **Roll** (retained 3-card hand + Pick Any + paid reroll), **Aim** (drag to pull back: distance + direction, Perfect band, lock button), **Fight HUD** (HP bars, hearts, power banners; no buttons), Results, **Kiln** (odds first), Collection + Index, Shop.

## 14. Technical plan

```
ServerScriptService/Server/Services/
  DataService        -- ProfileStore: coins, marbles, collection, trophies, quests, receipts
  ArenaService       -- pads, queue, bot fill, one MatchRunner per arena
  MatchService       -- match phases + timers; uses MatchLogic; handles PickGlassy/Reroll/SetAim/LeaveQueue
  FightService       -- 3D swing simulation (Codex) + FightRules; streams FightSnapshot/FightEvents
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
| 1 | Oct 13–19 | **Fight prototype:** erratic 3D swing + FightRules on one stand, aim, auto powers, shatter. Feels great on a phone. |
| 2 | Oct 20–26 | Match flow: pads, queue, bots, roll/aim/fight/hearts/results. Lobby blockout. |
| 3 | Oct 27–Nov 2 | Data, Kiln, collection, 9 more glassies modelled, lobby art pass |
| 4 | Nov 3–9 | Quests, gifts, codes, shop, Shatter FX, Marbles, PolicyService, analytics |
| 5 | Nov 10–16 | Polish, phone testing, **soft launch** |
| After | weekly | 2–3 glassies + code a week; winter event ~Dec 12; tournaments and 2v2 later |

## 15b. Metrics

- D1 / D7 retention, session length, matches per session, ARPDAU, payer conversion.
- Custom events: rounds played, % rounds with a Perfect Release, special use rate and timing, paid rerolls and Pick Any (free vs paid), Kiln pulls, time to first Rare/Epic/Legendary, bot vs player match share.
- Funnel: join → first match → first round win → first Kiln pull → second session.

## 16. Not a copy of Ball VS Ball

What we take is the structure (lobby pads, draft from your collection, hearts, auto-battle, coin gacha, weekly content). What's ours:
- **Glass on strings** swinging over a wooden pen, from real-life videos, not balls in a box.
- **Aim = pull-back** (distance + direction) with a Perfect band; **erratic 3D swings with spin** on strings.
- **Glass hearts** that pop (we never fling anything at players' avatars).
- **The Kiln** (glassblowing reveal), **Marbles**, kitchen-to-fantasy glass.
- Our own names, art, UI and powers. Don't copy their names ("Flyers", "Explosions", "Gems/Diamonds"), balls, abilities, screens or arena.

## 17. Open questions

- Final names (game, glassies, Marbles, Kiln).
- Match selection and prices are confirmed in decision 55; future Marble earning/packs remain separate work.
- Should each player get one free "pick any glassy" per match (Ball VS Ball has this)? Proposed, not in code yet.
