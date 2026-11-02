# Glass vs Glass relaunch plan

Status: **Proposed, awaiting creator direction.** A private slice is playable in Studio (not published). Live stays as it is until the creator approves a release. Evidence and screenshots: [testing/relaunch/REPORT.md](../testing/relaunch/REPORT.md).

## What went wrong

The idea holds up. Glass things on strings smashing into each other is easy to understand and fun to watch. The execution buried it. What follows comes from playing the live first session and reading the funnel: 826 joined, 666 started a match, 336 collected the prize, 187 started a second match, 123 finished it. Reported sessions are about 5 minutes with near-zero D1 and no revenue. Those last figures came from the creator; the cohort graphs were never supplied.

| Problem | What a new player sees | Why it hurts |
|---|---|---|
| **The collectibles aren't characters.** | Half the roster is pale bottles and cups with no face, and several are near-duplicates. On a bright sky the glass almost disappears. | Nobody wants to collect a tumbler. A collection needs characters you can recognise at a glance. |
| **Fighting and collecting are separate games.** | Win coins, walk to a Kiln, spin for something random. | Fights have no goal of their own, and 44% of prize collectors never start a second match. |
| **Too much before the fun.** | Welcome card, three-pull reveal, then cards reading "Mirror Catch: Catches part of a ray and returns a glint." | Teaches systems before the verb. Vault target: first big reward by 40 s. |
| **The frame is about the furniture.** | A timber A-frame fills the screen, the glass is small, and HP is text. | It's hard to tell who is winning, and harder on a phone. |
| **Built for a crowd it doesn't have.** | Seven arenas and a lobby walk, usually with nobody there. | At low player counts an empty lobby reads as a dead game, and most matches become bots. |
| **Scope beat depth.** | 40 glassies, finishers, flyers, several kilns, hill mode, boards. About 83k lines of Luau. | Effort went wide before the core was fun. |
| **Repeated loop rewrites.** | CAST, PUSH, Heat and twists were added, then removed. | Each pass changed mechanics, while the first two problems stayed. |

## The new game in one line

**Smash a glass to win its shards. Collect enough and it joins your shelf.**

| Pillar | How it works | Status |
|---|---|---|
| **Glass Buddies** | Every glassy is a character: big face, bright liquid in clear glass, its own silhouette, swappable expressions. | Six built and in Studio |
| **Collect what you smash** | Rivals are glassies you can still earn. Winning drops shards; enough shards unlock it. Replaces coins-to-random as the main way to get glassies. | Built |
| **The Gauntlet** | One pull, then fights chain automatically. Three hearts per run. A loss costs a heart and rematches the rival. Ends on a summary and one PLAY AGAIN. Keeps decision 129's seamless flow. | Built |
| **One meaningful choice** | Tap a glassy between fights. A green STRONG tag marks the one that beats the next rival, which then has less HP. | Built |
| **Glass is its own health bar** | Liquid drains as HP drops, faces react to hits, and a small bar backs it up. | Built |
| **The Shelf** | Everything you own stands behind the fight; locked ones wait as dark silhouettes. | Built on the stage; public version is next |
| **Kiln Room stage** | Dark, warm room so tinted glass is the brightest thing on screen. | First pass (parts only) |

## Roadmap

### Phase 1: prove it (now)
Play the slice yourself, then watch 5 to 8 unfamiliar players on phones with no coaching. Ask "what did your glass do?" and "what do you want next?". **Go signal:** they name a glassy they want and press PLAY AGAIN without being asked.

### Phase 2: ship the core (estimate: about 2 weeks)
- Move the Gauntlet out of `Dev` into real services with saved shards and shelf (ProfileStore, existing receipts). Keep every glassy players already own, and don't remove anything they paid for.
- New first session: join to first pull in about 10 s, first shatter under 40 s, first unlock under 2 minutes. No pop-ups before the first unlock.
- Rebuild the 12 most-owned glassies in the v5 style, including the existing face characters (Whiskers, Piggy, Duck, Bear).
- A proper Kiln Room model in Blender, plus hit and unlock sound passes. Check phones.
- Telemetry from day one: bounce under 60 s, first shatter, first unlock, run length, voluntary PLAY AGAIN.
- Controlled rollout, comparing like-for-like cohorts.

### Phase 3: reasons to return (estimate: about 2 weeks)
- **Ghost rivals:** the Gauntlet fights other players' real glassies, under their names, recorded asynchronously and clearly labelled. This handles empty servers without faking players, and it's social.
- **Public shelves:** the lobby becomes a gallery of player shelves, one tap from play. No walk is needed to start.
- **Overnight firing:** put shards in the Kiln and a rare glassy finishes tomorrow. One clear D1 promise rather than a stack of daily pop-ups.
- **Weekly boss glass:** a limited glassy earned only by beating it that week, with a shared countdown.

### Phase 4: money (after retention moves)
Cosmetic-first and never pay-to-win: finishers and flyers already exist and fit this well. Add a one-time starter pack after the first run, shelf themes, and a shard-boost pass with its numbers stated up front. Any paid random item keeps odds shown first and stays hidden where `PolicyService` restricts it. Needs the creator's approval as a paid feature, and an audit before enabling.

## Targets

These are rule-of-thumb soft-launch bars from the LihFolk vault, not Roblox benchmarks. Roblox publishes no D1 or D7 values.

| Measure | Now | Target |
|---|---|---|
| First shatter | After menus and setup (not measured) | Under 40 s |
| Median first session | About 5 min (reported) | 10+ min |
| Largest single-step funnel drop | 49% (first match to prize, wins and losses mixed); 44% prize to second match | Under 15% to 25% |
| Second run or match started | 56% of prize collectors | 80%+ |
| D1 | Near zero (reported) | Set a baseline first, then improve it |

Roblox's recommendations (June 2026) weigh first-play bounce and 28-day retention, so the opening minute and the return hook are what affect discovery.

## Open risks

- **Nobody has played this but automation.** That proves it runs, not that it's fun.
- **Agency is still low:** one pull, one optional switch. Decision 129 asks for this flow. If testers get bored, the first experiment is one tap during a swing.
- **Difficulty numbers are first guesses.** Rung HP, shard counts and counter strength need tuning on real runs.
- **Existing owners** need a migration rule when shards replace coin pulls as the main route.
