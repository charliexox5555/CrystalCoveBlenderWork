# Round revamp: faster, busier, more to do (decision 122, Oct 23)

**Why:** creator playtests and watching real players: rounds feel boring, there isn't much to do, some rounds last too long, and players leave mid-round. Ball VS Ball works because there is always something happening on screen and luck keeps changing who's ahead.

**Creator choices (Oct 23):** A "faster but not too fast", fights about **18 s**; **B, C and D** all go ahead; **Bumpers yes, as one twist** (reopens decision 56 for that twist only).

## 0. As built (Oct 23)

| Piece | Where | Numbers |
|---|---|---|
| Pacing | `Balance.Fight`, `Balance.Motion` | DamageScale 0.27 → **0.29**, Gravity 77 → **88** (swing ~1.8 s), MELTDOWN (overtime) 45 → **15 s** at +8%/s, timeout 75 → **40 s** |
| Setup timers | `Balance.Match` | pick **12 s** round 1, **8 s** later rounds (no pick = last round's glassy), aim 15 → **10 s** starting from last round's aim, countdown 4 → **3 s**, round end 6 → **4.5 s** (finishers still play every round: they are bought cosmetics) |
| Glints, Heat, twists, PUSH, Last Glass | `src/shared/ArenaRules.luau`, `Balance.Arena` | glints every 2.5–4 s (×0.6 after 8 s, ×0.5 in Glint Rain), 6 kinds; PUSH 3 charges, +1 per 4 s, 0.6 s cooldown, not while frozen |
| Swing half (glint places and grabs, bumpers, wind, magnet, shoves) | `Simulation/Pendulum.luau`, `Simulation/PushBrain.luau` (bots and simulator sides push) | 6 bumper posts: one behind each backswing, four at the outer corners; middle posts blocked the clashes in testing |
| Match side (twist per round, never twice in a row; last pick/aim kept; Last Glass; On Fire streak) | `MatchLogic`, `MatchService` (tutorial match stays Calm) | |
| Remote | `Push` (FightService, rate-limited `Match.PushRateSeconds`) | |
| Client | `Presentation/ArenaFX.luau` (glints with pictures, held Smash/Bubble, bombs, posts, wind, Heat bar, twist + MATCH POINT banner, On Fire flame, "+10 COINS" when you take a heart while behind), `UI/Screens/PushButton.luau` (Shift / R, Y / L1 / L2) | |
| Analytics | custom events `MatchLeft<Phase>` (value = round) from every forfeit | |
| Tools | `tools/pacing_report` (dead-air probe, `twist=` and `Table.Key=value` overrides), `tools/release_matrix_win.sh` | |

Real-swing probe after the build (108 rounds, all 24 kits, twists rolled): fight **mean 18.4 s, p90 24.9 s**, contacts 0.56 a second (was 0.47), dead air **13% → 0%**, longest quiet stretch median 2.0 s (was 4.8 s); about 9 glints a round, nearly all grabbed.

Changes from the proposal below: the Charge and Twister glints became **Zoom** (a big shove) because "power Ready now" means something different for every kit; the Double Trouble twist was dropped for the same reason; the full finisher stays on every round. Sections 1–4 are the original proposal.

## 1. What's wrong (measured, not guessed)

Measured on the real deterministic swing with `lune run tools/pacing_report` (108 rounds, all 24 release kits). An "event" is something a viewer notices: a hit worth at least 6% HP, a power, or the shatter.

| | Now |
|---|---|
| Fight length | mean **28.3 s**, p90 **37.9 s** (overtime only starts at 45 s, timeout 75 s) |
| Contacts | **0.47 a second**: one touch every ~2.1 s; ~13 hits to break a glassy |
| Events | 0.63 a second; **13%** of fight time is spent more than 3 s after the last event |
| Longest quiet stretch per round | median 4.8 s, p90 6.3 s |
| Setup around every round | pick up to **25 s** + aim up to **15 s** + countdown **4 s** + round end **6 s** + finisher |
| Whole match (3–5 rounds) | about **4–5 minutes**, of which well under half is fighting |

What that feels like:

1. **The waiting is longer than the fight.** In a PvP match a slow opponent makes you sit through 40 s of menus every round, and you re-pick and re-aim every round even if nothing changed.
2. **The pendulum settles into a rhythm.** Two glassies swinging toward each other meet about every two seconds, like a clock. Ball VS Ball balls bounce off four walls, so they are always moving somewhere new.
3. **Nothing happens in the space between them.** The pen is empty. All the action is the two glassies and one power every ~8 s.
4. **After the release you have almost nothing to do.** CAST lights up a couple of times a round, and that's it.
5. **Rounds don't get more exciting as they go.** Overtime at 45 s is past the point where most players have already left.

## 2. The revamp in four packages

Each package works on its own, so we can ship and measure them one at a time.

### Package A: Faster (tuning only, no new systems)

| Number | Now | Proposed |
|---|---|---|
| `Fight.DamageScale` | 0.27 | **0.36** (~9 hits to break instead of 13) |
| `Motion.Gravity` | 77 (swing ~1.9 s) | **110** (swing ~1.6 s, harder hits) |
| `Fight.OvertimeAt` / `OvertimePerSecond` | 45 s / +6% | **15 s / +10%** |
| `Fight.RoundTimeout` | 75 s | **35 s** |
| `Match.RollSeconds` | 25 s every round | **10 s** at match start, **5 s** between rounds with last round's glassy pre-selected (one tap to keep it) |
| `Match.AimSeconds` | 15 s | **7 s**, starting from your last aim |
| `Match.CountdownSeconds` | 4 s | **2 s** |
| `Match.RoundEndSeconds` | 6 s | **3 s**; quick break on normal rounds, the full finisher show only on the match-winning round |

Real-swing probe with the four fight numbers: fight **mean 13.4 s, p90 19.1 s**; contacts 0.61 a second; dead air **13% → 6%**; longest quiet stretch median 2.8 s. A round including setup drops from ~60–80 s to **~25–30 s**, and a match from ~4–5 min to **~1.5–2.5 min**.

Costs: every kit was tuned for 28 s fights. Kits that count things (Lantern Seeds' 3 seeds, Hourglass's 3 turnarounds, timers, stored charges) get fewer chances in a 13 s fight, so their thresholds and timers have to shrink in step, then the release matrix (45–55%) runs again. The new swing speed is a starting value; Codex tunes it by eye.

### Package B: Chaos in the pen (new system, the big one)

**Glints (pickups).** Every 2.5–4 s a glowing glass gem pops into the space between the two glassies, somewhere both can reach. Whichever glassy swings through it first grabs it. Every pickup is a race the crowd can see coming, which is our version of Ball VS Ball's "always something going on". Server-decided from the pendulum positions (we already predict where glassies will be for zone powers), so it stays fair and exploit-proof.

| Glint | Effect | Picture |
|---|---|---|
| Smash | your next hit deals ×2 | red star |
| Bubble | blocks the next hit | blue bubble |
| Patch | heals 10% max HP | green heart |
| Charge | your power is Ready right now | gold bolt |
| Fizz Bomb | sticks to the other glass and pops 1 s later | orange fizz |
| Frost | the other glass swings slowly for 1.5 s | ice cube |
| Twister | spins both glassies wildly | purple swirl |

One picture per glint, no text, so a 6-year-old reads it in a second. A glint nobody touches fades after 3 s. At most 2 on screen.

**The Heat.** A glowing kiln bar under the arena board fills as the round goes on (replaces the silent overtime):
- 0–8 s: normal.
- **8 s, "HEATING UP!"**: glints come twice as fast.
- **15 s, "MELTDOWN!"**: the glass glows orange, strings shorten a little (faster swings), damage climbs each second.
- A round can't drag past ~25 s, and the end of every round gets louder, not quieter.

**Arena twists (one per round).** At the countdown a big banner rolls one twist for the round, so no two rounds look alike:
- **Windy**: gusts push both glassies sideways.
- **Bouncy**: everything bounces harder.
- **Magnet**: the glassies pull toward each other (more smashes).
- **Glint Rain**: twice as many glints.
- **Double Trouble**: both powers charge twice as fast.
- **Bumpers**: crystal posts in the pen that glassies ricochet off (the closest thing to Ball VS Ball's walls; this reopens decision 56, which chose no visible bounce boundaries).
- **Calm** (sometimes): a normal round, so the twists stay special.

### Package C: Something to do during the fight

**PUSH button** beside CAST: tap to give your glassy a shove in the direction it's swinging. 3 charges a round, one comes back every 4 s. You use it to win the race to a glint, to line up a big smash, or to dodge when you're low. Mashing is fine for young players; timing is better. Bots use it too. PUSH is never automatic, even with Auto-Cast on: a player who only watches still gets a fair fight.

This changes the "pick, aim, then watch" input from decisions 23/33/85, so it needs the creator's OK. It also gives a reason to keep watching your own fight instead of leaving.

### Package D: Stakes and comebacks

- **Last Glass:** a player down to their last heart starts the round holding a random glint.
- **Match point:** the deciding round gets the Overtime music, a "MATCH POINT" banner and the full finisher.
- **On Fire:** winning two rounds in a row lights your glassy's string with a flame the whole lobby sees (cosmetic only).
- **Mid-round leavers:** losers already get coins per heart taken (decision 84); show "+10" coin pops when you take a heart, so players can see that staying pays even when behind.

## 3. Order and how we'll know it worked

1. **A first** (1–2 sessions): tuning, kit retune, release matrix, Codex by-eye pass on the swing.
2. **B** (glints + Heat first, twists after): pure rules in `FightRules` + simulator support, glint geometry in `Pendulum`, visuals by Codex.
3. **C and D** after the creator plays B.

**Add analytics before A ships** so we can compare: `RoundLeft` (a player left during Fighting, with seconds in), round length, rounds per session, matches per session, glints grabbed. Target after A+B: fight 12–18 s, match ≤ 2.5 min, mid-round leaves down by half, matches per session up.

**New test targets** (replace GAME_DESIGN 3.7 "Round length 15–45 s"): fight 10–20 s mean, p90 ≤ 25 s; dead air ≤ 6%; ≥ 1 lead change a round; every kit still 45–55% equal-stat on the real swing.

## 4. What stays

The shatter as the reward, glass on strings over the pen, 3 glass hearts, pick from your own collection, the pull-back aim with the Perfect band, signature powers with optional CAST, all cosmetics and the economy (coin numbers per match stay; matches just get shorter, so coins per minute go up; EconomySim reruns with Package A).
