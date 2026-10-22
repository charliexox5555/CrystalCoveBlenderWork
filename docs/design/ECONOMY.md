# Economy

All numbers live in `src/shared/Config/Balance.luau` (`Match.Rewards`, `Economy`, `Rarities`, `Growth`). This page explains them. After changing any of them, run:

```
lune run tools/economy_sim     # pacing report
lune run tools/run_tests       # EconomyTests check the targets below
```

## 1. Currencies

| Currency | How you get it | What it's for |
|---|---|---|
| **Coins** | Playing: rounds, matches, quests, gifts, first win of the day | The Kiln (new glassies), coin cosmetics |
| **Marbles** (premium) | Robux packs; small free amounts: login streak (days 3 and 7), group join (20) | Rerolls, Shatter FX, cosmetics |
| **Trophies** | Winning matches against players (+20, −8, never below 0); +5 for beating a bot | Leaderboard and the Champion Arena; never spent |

Marbles are deliberately a glass object (on theme) and **not** called gems or diamonds (Ball VS Ball's names).

## 2. Earning coins

| Source | Coins | Notes |
|---|---|---|
| Round won | 10 | |
| Match won / lost | 60 / 20 | Losing still pays, so kids never walk away with nothing |
| Against a bot | ×0.6 | Bots exist to fill pads, not to farm |
| Daily quests | 75 each, 3 a day | |
| First win of the day | 100 | |
| Playtime gifts | 40 / 60 / 100 / 150 at 5 / 15 / 30 / 60 min | Reset daily |
| Duplicate past 5 stars | 50 | |

A typical player (50% wins, 40% bot matches) earns about **800 coins an hour** from matches, plus ~500 a day from quests and the first win.

## 3. The Kiln (coin gacha)

- **300 coins** a pull, **2,700** for 10 (one free). New players get **1 free pull after their first match**.
- Rarity first, then a glassy of that rarity uniformly (`Formula.rollKiln`). **The odds screen lists every glassy with its exact chance** (`Formula.kilnOdds`) and is shown before every pull.
- Duplicates add a star (+2% stats, max 5); past that they turn into 50 coins.

| Rarity | Odds | Glassies | Each |
|---|---|---|---|
| Common | 56.25% | 6 | 9.38% |
| Uncommon | 22% | 3 | 7.33% |
| Rare | 14% | 4 | 3.5% |
| Epic | 6% | 7 | 0.86% |
| Legendary | 1.5% | 6 | 0.25% |
| Mythic | 0.25% | 2 | 0.125% |

Each glassy must be less likely than every glassy of a lower rarity (tested). When new glassies are added to a rarity, each one's chance drops; re-check that rule when adding several at once.

## 4. Pacing (simulated: 40 min a day, 30 days)

| What | Result | Target (EconomyTests) |
|---|---|---|
| Match length | ~3.7 min (4.1 rounds) | 2.5–5 min |
| Kiln pulls on day 1 | 4 | ≥ 3 |
| First Rare | ~47 min of play | ≤ 90 min |
| First Epic | ~2 h | ≤ 6 h |
| First Legendary | ~9 h (80% of players within a month) | 4–25 h |
| Mythic | 20% of players within a month | < 50% |
| Unique glassies | 12 by day 7, 18 by day 30 (of 28) | not completed in a month |

**Why these targets:** kids need a new glassy in the first session (the welcome pull + ~3 more), something exciting within the first few sessions (Epic), a reason to come back for weeks (Legendary), and a long chase that makes Mythics special. Rarity adds only a small stat edge (Mythic ×1.10), so the chase is about flair, not power.

## 5. Marbles and rerolls

- Every match: **1 free reroll**, then **5 / 10 / 20 Marbles** (the last cost repeats).
- Rerolls only reshuffle the player's own glassies; they never grant an item.
- Free Marbles: 20 for joining the group, 5 on streak day 3, 15 on day 7 (~20 a week): enough for a few paid rerolls a week without paying.
- Packs, Daily Marbles, the Starter Pack and the Daily Glassy: see [MONETIZATION.md](MONETIZATION.md) (decision 116); payer pacing in `src/tests/PayerSim.luau`.
- **Watch after launch:** if paid rerolls are a large share of Marble spending or players call it pay-to-win, make rerolls coins-only or earned (DECISIONS 25).

## 6. Guard rails

- No betting, wagering or trading at launch.
- No stronger Robux-only glassies; paid exclusives are cosmetic.
- Any paid random item (a future Marble Kiln) shows odds before purchase and is hidden when `PolicyService` → `ArePaidRandomItemsRestricted`.
- Every Robux purchase goes through an idempotent `ProcessReceipt`.

## 7. What to measure after launch

Coins earned per hour vs simulated, Kiln pulls per day, time to first Rare/Epic/Legendary, share of rerolls paid with Marbles, Marble pack conversion, D1/D7 retention by "got an Epic on day 1" vs not. Update `Balance.EconomyModel` from real data and re-run the sim.
