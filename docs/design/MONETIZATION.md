# Monetization (decision 116, Proposed)

Robux in Glass Clash: what is sold, at what price, why, and how it stays fair for kids. The creator asked for this on
2026-10-21 and delegated the calls ("make the calls yourself"). Everything here is **Proposed** until the creator
reviews it. **Creator answers (2026-10-21):** 3-day Starter Pack window, the Daily Glassy odds table, a missed Daily
Marbles day keeps your place, Hollowlight at 699: all as proposed; and **keep an 8,999 R$ top Marble pack** (added).

**Rules that never bend** (AGENTS.md): odds before every paid random item, hidden where `PolicyService` restricts
paid random items, no betting or wagering of coins or Robux, no stronger Robux-only glassies, every purchase through an
idempotent `ProcessReceipt`.

## 1. What is on sale

| Offer | Price | What you get | Limit | Where |
|---|---|---|---|---|
| **Starter Pack** | 49 R$ | Sunny (Epic glassy), Daybreak (Epic finisher), Dawn Kite (Epic flyer), 150 Marbles | once ever, for 3 days after you first see it | HUD tile (right edge), tile beside the open Shop, pack popup; opens by itself twice at most |
| **Daily Glassy** | 9 R$ | one random glassy from the Kiln pool: Rare 60%, Epic 32%, Legendary 6.5%, Mythic 1.5% | once per UTC day | HUD tile at the top of the left column; a tap opens the Robux prompt; the rarity odds and an ODDS button sit beside it; the tile hides once bought until 00:00 UTC |
| **Daily Marbles** | 49 R$ | 60 → 65 → 70 → 75 → 80 → 85 → 100 Marbles (each day you buy, the next buy gives more; 100 repeats) | once per UTC day; a missed day keeps your place | under the Marble packs on the Marbles page (a scrolling page) |
| **Marble packs** | 99 – 8,999 R$ | 100 – 13,000 Marbles (table in §5) | none | Marbles page |
| **Daily store** | 49 – 699 R$ | one named glassy, finisher and flyer a day (decision 76) | one per slot per day | Featured page |
| **Hollowlight Collection** | 699 R$ (was 499) | Hollowlight + Moonlantern Carriage + Lantern Eclipse | once | Featured page / bundle preview |
| **Need Marbles** | – | tapping REROLL, PICK ANY, a Marble Kiln or Marble crate without enough Marbles opens one card: the cheapest offer that covers it, one BUY, and you stay where you were | – | over match selection and the Shop |

Sim results for these offers are in §7. Watch-an-ad for Marbles is **not built**; the recommendation is in §8.

## 2. Research

### 2.1 Roblox's own guidance

- **Starter packs.** Roblox's starter pack guide says to make the pack available "as soon as new players spawn for the
  first time" (gating it behind a tutorial or the first match means fewer players see it), use "2-5 items that help
  players jump into the fun quickly", give "outsized and obvious value", price it under 399 R$ ($5) (common points
  99/199/299 R$), "recommend a discount of around 90%", and run it "between 24 hours and 3 days". Industry benchmarks
  it cites put the revenue lift at 2-10%. Popups should be rare, e.g. on spawn in the offer's last day.
  [Starter pack design](https://create.roblox.com/docs/production/game-design/starter-pack-design)
- **Shops.** A shop should be integrated, contextual and inviting; a starter pack is "an initial offer … that a new user
  sees within the first few minutes". [Monetization foundations](https://create.roblox.com/docs/production/game-design/monetization-foundations)
- **Contextual purchases.** Offer the right item at the right time, between rounds or before play rather than in the
  middle of it, and don't stack modals. That is why Need Marbles opens during selection (before the fight), not in it.
  [Contextual purchases](https://create.roblox.com/docs/production/game-design/contextual-purchases)
- **Developer products and receipts.** Repeatable purchases are developer products. `ProcessReceipt` must grant and
  return `PurchaseGranted` only once the grant is saved, `NotProcessedYet` otherwise (Roblox retries), and be keyed by
  `PurchaseId`; purchases from the game page's Store tab also arrive through it.
  [Developer products](https://create.roblox.com/docs/production/monetization/developer-products),
  [MarketplaceService](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService)
- **Paid random items.** Anything random bought with Robux or with currency bought with Robux (our Marbles) must list
  every outcome with odds that sum to 100% *before* purchase; a long list may sit behind a button labelled "Info" or
  "Details" (a bare (i) is not enough). Where `PolicyService:GetPolicyInfoForPlayerAsync().ArePaidRandomItemsRestricted`
  is true the player must not use paid random items at all; hiding them is an allowed treatment. A June 2026 policy
  update applied the disclosure rules worldwide.
  [Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items),
  [TechTimes on the 2026 change](https://www.techtimes.com/articles/319148/20260626/koreas-loot-box-rules-push-roblox-disclose-item-odds-worldwide.htm)
- **Price optimization.** Roblox can A/B test product prices for you (about 3 weeks, applied only if total revenue
  rises; median +4%, often recommending *lower* prices), but only for experiences with ~60,000 transactions a month,
  and only for prices read from Roblox at runtime (`GetProductInfo`), not hard-coded ones.
  [Price optimization](https://create.roblox.com/docs/production/monetization/price-optimization),
  [DevForum: item-level recommendations](https://devforum.roblox.com/t/price-optimization-now-includes-item-level-price-recommendations/3894427)
- **Regional pricing.** Opt-in per product; Roblox reports a 22-45% rise in paying users for passes in Brazil, the
  Philippines and Mexico and a 26% median lift for in-experience items.
  [DevForum: regional pricing for developer products](https://devforum.roblox.com/t/introducing-regional-pricing-for-developer-products/3971235),
  [Roblox newsroom](https://about.roblox.com/newsroom/2025/04/roblox-launches-regional-pricing-for-in-experience-items)
- **Rewarded video ads.** §8.

### 2.2 Data

- **GameAnalytics 2025 Roblox report** (thousands of Roblox games, Jan 2023 – Jul 2025): the median *transaction* in
  games with 25+ minute sessions is **$1.29** (≈ 100 R$ at the 400 R$ = $4.99 store price), the 75th percentile $1.62;
  median daily ARPPU $2.12 there. Small, frequent buys are the norm on Roblox, so the ladder is dense at 49-199 R$.
  [GameAnalytics 2025 Roblox report](https://www.gameanalytics.com/reports/2025-roblox-report)
- **Payer share.** Roblox's filings give about 1.8 M daily unique payers against ~100 M DAU in 2025 (≈ 1.5-2% pay on a
  given day) and ~21% of DAU paying in a month. [Roblox 10-K FY2025](https://www.sec.gov/Archives/edgar/data/1315098/000131509826000024/rblx-20251231.htm),
  [Q2 2025 letter](https://www.sec.gov/Archives/edgar/data/1315098/000131509825000261/q225shletterex992.htm)
- **First purchases.** Unity's 2023 mobile report: first purchases cluster at $1.01-5.00 and 77% of players who ever
  pay do it within two weeks. That supports a cheap, early, one-time Starter Pack.
  [Unity 2023 Mobile Growth and Monetization Report](https://unity.com/en/blog/games/the-2023-mobile-growth-and-monetization-report-is-here)
- **Price endings.** Community pricing guides recommend 49/99/149/249 and prices ending in 9; Roblox's own guide uses
  99/199/299 for starter packs. [creation.dev pricing guide](https://www.creation.dev/learn/how-to-price-game-passes-roblox)
- **DevForum (developers).** Starter packs should be cheap compared with the rest of the shop ("it's not really getting
  a foot in the door if the first purchase isn't easy to make"), hold early-game items you could also earn by playing,
  and have a real deadline. [DevForum: starter pack price points](https://devforum.roblox.com/t/poll-starter-pack-price-points/397653).
  You can't decline a developer product purchase after the fact, so one-time offers must be refused *before* the
  prompt. [DevForum feature request](https://devforum.roblox.com/t/need-a-way-to-reject-developer-product-purchases-entirely-or-limit-the-amount-of-times-a-player-can-purchase-a-developer-product/2729460)

### 2.3 What similar games charge

| Game | Offer | Price |
|---|---|---|
| Ball VS Ball (creator's screenshots, 2026-10-21) | Beginner Pack: 50 gems, an exclusive ball, 5 Pick Any cards, "90% OFF", timer | 49 R$ |
| Ball VS Ball | Random Epic Ball (HUD tile with ODDS) | 99 → 9 R$ |
| Ball VS Ball | Daily Diamonds: 60 a day, streak Day 2-7 = 65/70/75/80/85/90 | 49 R$ a day |
| Ball VS Ball | Halloween Fright bundle (ball + explosion + flyer); other bundles | 1,599 R$; 1,699 / 4,499 / 9,999 R$ |
| Ball VS Ball | Gem packs ([research brief](../research/BALL_VS_BALL.md)) | 100 for 99 R$ … 13,000 for 9,999 R$ |
| Pet Simulator 99 | Super Starter Pack (egg, potions, hoverboard, enchant, 2,000 diamonds), shown on first join | 240 R$ ([guide](https://progameguides.com/roblox/is-the-super-starter-pack-worth-it-in-pet-simulator-99-roblox/)) |

Ball VS Ball's Beginner Pack ball is widely called pay-to-win; ours is tuned to the same 45-55% edge as everything else
(decision 86), and the pack is cosmetics-heavy.

## 3. Starter Pack: 49 R$, once ever

- **Contents.** The Daybreak set (decision 117): **Sunny** (Epic Heavy glassy, tuned to the normal
  edge), **Daybreak** (Epic finisher), **Dawn Kite** (Epic flyer), plus **150 Marbles**. Exclusive: never in the Kiln,
  crates or the daily store (`OfferRules.exclusive`, `Glassies.isStarterPack`, `RoundCosmetics.StarterPack`).
- **Honest value.** The popup shows the parts at their own prices, struck through: each item at the daily store's
  price for its category and rarity (Epic glassy 199, Epic finisher 149, Epic flyer 199) and the Marbles at the
  Handful's rate (150 → 149 R$), **696 R$ worth for 49 = -92%** (rounded down, `OfferRules.starterValue`). The number
  follows config, so it can never drift from what the shop charges.
- **Pick Any tickets: considered and left out.** Every match already gives one free Pick Any, so a ticket would only
  replace the 2nd+ Pick Any of a match (6-12 Marbles each); 5 tickets would be worth ~40 Marbles while looking bigger
  than that. 150 Marbles do the same job with nothing new to explain to kids.
- **Timing.** Available from the first spawn (Roblox's advice) for **72 hours** from the first time the server shows it
  (`Deals.StarterSeenAt`), with a countdown on the popup and the Shop tile. It opens by itself **at most twice**: once
  back in the lobby after onboarding (never over onboarding, a match, the queue, results, watching or another menu),
  and once in its last day. After that it only opens from its tiles.
- **One per player.** `Deals.StarterBought` is set by the receipt; the intent is refused before prompting once it is
  set or the window is over, so nobody can pay twice (a race between two prompts still grants, because Roblox has
  charged).

## 4. Daily Glassy: 9 R$ a day

- **Odds** (per glassy, the Kiln pool, evenly within a rarity): Rare 60% (7 × 8.57%), Epic 32% (5 × 6.4%), Legendary
  6.5% (3 × 2.17%), Mythic 1.5% (3 × 0.5%). No Commons or Uncommons. Each glassy is rarer than every glassy of a lower
  rarity, as in the Kiln (tested).
- **One tap to buy, odds always on screen** (creator, 2026-10-22). The tile sits at the top of the left HUD column
  (Shop and Inventory move down one step; on touch Inventory sits beside Shop, clear of the thumbstick). A tap opens
  the Robux prompt. Next to the tile, always visible, are a larger **ODDS** button and the rarity odds (Rare 60%, Epic
  32%, Leg 6.5%, Myth 1.5%). ODDS opens the table with each rarity's per-glassy chance, and its **DETAILS** lists every
  glassy with its exact percentage. Once bought, the tile, strip and button hide until the next 00:00 UTC reset.
- **Why this meets Roblox's rule.** The [paid random items policy](https://create.roblox.com/docs/production/monetization/paid-random-items)
  requires "all possible outcomes and the actual numerical odds" before purchase. It lets the itemized list sit in "a
  clickable pop-up with an 'Info' or 'Details' icon visible and accessible prior to purchase" (a bare (i) is not
  enough), and its example shows the odds by rarity tier on screen next to a clickable "Details" button. A labelled ODDS
  button alone would arguably qualify. The rarity strip keeps the tier odds on screen at the moment of the tap anyway,
  and each glassy's chance is one labelled tap away. The earlier version (odds popup first, then BUY) was stricter than
  the policy asks.
- **Policy.** Hidden (tile and popup) when `ArePaidRandomItemsRestricted` is true **or unknown**; the server refuses the
  intent too.
- **Fairness.** 9 R$ is a loss-leader: 30 a month at most (270 R$). It beats a Marble Kiln pull (30 Marbles ≈ 30 R$,
  5.9% Legendary or better) on purpose, the way Ball VS Ball's 9 R$ Epic does, but only once a day.
- **Duplicates** add a star like any Kiln duplicate (and past 5 stars turn into coins). The glassy plays out of a Kiln
  opening ("YOUR DAILY GLASSY!"). The draw is seeded from Roblox's `PurchaseId`, unknown before the purchase, using
  the odds snapshot saved before the prompt.

## 5. Marbles

### 5.1 Daily Marbles: 49 R$ a day

60, 65, 70, 75, 80, 85, then **100** Marbles for each later buy. Day 1 is +21% over the Handful (the same "+21%"
Ball VS Ball shows), the top step +102%. **A missed day keeps your place** instead of resetting, like Daily Rewards
(decision 99): a streak that resets punishes kids for a day off and pressures a daily purchase. Regulators treat
purchase pressure on kids seriously (the FTC's $245 M Epic Games order over purchase "dark patterns",
[FTC refunds](https://ftc.gov/news-events/news/press-releases/2024/12/ftc-sends-refund-payments-consumers-impacted-epic-games-unlawful-billing-practices)),
and the UK children's code asks designers not to exploit psychological biases
([ICO standard 13](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/childrens-information/childrens-code-guidance-and-resources/age-appropriate-design-a-code-of-practice-for-online-services/13-nudge-techniques/),
written for privacy choices). The ladder still rewards coming back; it just never takes anything away.

### 5.2 Pack ladder (was 100/99, 420/399, 900/799, 2,200/1,899, 5,000/3,999, 12,000/8,999)

| Pack | Marbles | Price | Bonus (vs Handful) |
|---|---|---|---|
| Handful | 100 | 99 | – |
| Pouch | 220 | 199 | +9% |
| Jar | 480 | 399 | +19% |
| Bucket | 1,000 | 799 | +23% |
| Barrel (new) | 2,600 | 1,999 | +28% |
| Chest | 5,600 | 3,999 | +38% |
| Vault | 13,000 | 8,999 | +43% |

- A rung at every common price point from 99 to 8,999: the old ladder jumped from 99 to 399, where most Roblox
  purchases (median ≈ 100 R$) never reach. 49 R$ is covered by Daily Marbles and the Starter Pack.
- Proposed a 3,999 R$ top for a kids' game; **the creator kept an 8,999 R$ Vault** (13,000, +43%, close to Ball VS
  Ball's ~+30% at 9,999). Bonuses rise smoothly and are computed (`OfferRules.bonus`) so the card is always true.
  The 3,999 and 8,999 products keep their dashboard prices; the 1,999 Barrel is a new product.
- Uses are unchanged: Pick Any (6/9/12 after the free one), rerolls (3/3/6/6/9), the Marble Kiln (30 / 300 for 10) and
  Marble crates (30 finisher, 100 flyer).

### 5.3 Need Marbles

REROLL, PICK ANY, a Marble Kiln open or a Marble crate without enough Marbles → one card: "{M} N more", the cheapest
offer that covers it (today's Daily Marbles if it does, else the smallest pack that does, else the biggest), **BUY**,
and in the Shop a **MORE** button for the Marble page. Buying keeps you on the selection screen or the Shop; the
Marbles arrive with the receipt and you tap again.

## 6. Repricing

| Item | Old | New | Why |
|---|---|---|---|
| Hollowlight Collection | 499 | **699** | parts at daily-store prices are 249 + 399 + 299 = 947, so 699 is 26% off; +40% on the old price (creator: "should be more"). Ball VS Ball's comparable bundle is 1,599 |
| Hollowlight alone | 249 | 249 | the Epic Featured glassy price |
| Glassies Epic / Epic Featured / Legendary | 179 / 229 / 349 | 199 / 249 / 399 | onto the 199/249/399 points; gameplay pieces stay a step above cosmetics |
| Finishers Uncommon / Rare / Legendary F | 39 / 79 / 279 | 49 / 99 / 299 | 39/79/279 aren't price points players see elsewhere |
| Flyers Uncommon / Rare / Epic F | 59 / 119 / 249 | 79 / 149 / 299 | flyers stay ~1.5× finishers (they cost 3.3× in crates) |
| **New:** Finisher Mythic, Flyer Epic, Flyer Legendary, Flyer Mythic | none (crate-only) | 499 / 199 / 399 / 599 | the ROADMAP's missing cosmetic prices; Emberwing, Carousel, Sunwing and Starwhale join the daily rotation once the products exist |
| Unchanged | | Glassies Uncommon 49, Rare 99, Rare F 129, Mythic 599, Mythic F 699; Finishers Epic 149 | already on the ladder |

Coin prices (crates, daily store Coin slot, the Kiln) are unchanged.

## 7. Economy safety (sims)

`lune run tools/economy_sim` (free report, then `src/tests/PayerSim.luau`), 600 players per persona, 40 min a day:

```
persona       R$/30d    pulls   unique7  unique30   Leg by7   Mythic30   edge d7  edge d30
Free               0      105        19        31       39%        21%      0.0%      0.0%
Starter           49      110        22        32       53%        26%      0.1%      0.0%
Occasional       247      116        23        33       59%        29%      0.2%      0.0%
Daily           1789      204        29        37       92%        78%      0.9%      0.8%
Whale          23807     1071        38        39      100%       100%      3.1%      1.2%
```

- **No power for Robux.** The "edge" is the HP of a player's best three glassies over a free player's; it is all rarity
  and stars ever buy (decision 86). Small payers are within 0.2%; a daily buyer within 1%; a whale (two Vaults a month) 3.1% in week one,
  1.2% by day 30, under the +6.1% cap (a 5-star Mythic). Free players reach a Legendary in week one 39% of the time.
- **Collecting faster is what money buys**, like every collector: a daily buyer (~$22 a month) owns 37 of 39 glassies by
  day 30 against a free player's 31. Free pacing (first Epic 40 min, first Legendary 4 h, 105 pulls by day 30) is
  unchanged.
- **Caps.** Daily offers are once a day; the Starter Pack once ever; the top pack is 8,999 R$. Nothing Robux buys can
  be traded or wagered (there is no trading).
- `EconomyTests` checks these bounds on every run.

## 8. Watch an ad for Marbles: recommendation (not built)

**Rules** ([Rewarded video ads](https://create.roblox.com/docs/production/promotion/rewarded-video-ads),
[ad integrations](https://create.roblox.com/docs/production/promotion/ad-integrations),
[DevForum, July 2025](https://devforum.roblox.com/t/more-creators-can-now-use-rewarded-video-ads/3838678)):

- **Viewers 13+ only.** `AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)` returns no ad for younger
  players (`PlayerIneligible`), so most of our audience would never see the button.
- **Publisher.** The experience must be public and unrestricted, have an approved Maturity & Compliance questionnaire
  and average 2,000+ unique visitors a month; the owner (for a group game, the group owner) must be 13+, ID-verified
  and use 2-step verification. Self-serve access started with 100K+ DAU games in 2025 and has been widening.
- **Reward.** It must be a developer product players could also buy (`AdService:CreateAdRewardFromDevProductId`,
  then `ShowRewardedVideoAdAsync(player, reward)`, granted in `ProcessReceipt`), worth roughly 3-10 R$, not random,
  not Robux, granted right after the ad, clearly labelled, and it must not unbalance the economy or gate progress.

**Recommendation: yes, after launch, small.** Once the game qualifies (2,000 monthly visitors), add a "watch an ad,
get 5 Marbles" button on the Marbles page and the Need Marbles card, **3 times a day**, as a 5 R$ developer product
("5 Marbles"). Show it only when an ad is available (so under-13s never see a dead button), turn on Roblox's "exclude
likely purchasers" option, and track it like any other source. 15 Marbles a day is one Pick Any or a third of a Marble
Kiln pull: a nice extra that doesn't move the sims above. It also gives non-paying teens a way into Marbles, which
decision 39 otherwise keeps out of free play. Don't build it before launch: it can't be tested without eligibility.

## 9. Developer products to create (creator)

**Done 2026-10-21:** all 8 created and all 13 prices updated through `products.py`; ids in `Config/ProductIds`. The price guard reports no mismatches.

Open Cloud can't create them right now: the `ROBLOX_ASSETS_KEY` key returns **"Scope not authorized"** for
developer products (it lost that scope when Assets read/write was added on 2026-10-19). Two ways:

**A. Give the key the scope (one command after).** Creator Hub → Open Cloud → API Keys → the key → add the
**developer-product** API system with **read and write** for universe 10770493435. Then:

```bash
zsh -i -c 'python3 tools/opencloud/products.py list'
```

and tell Claude; it creates and updates everything below with `products.py` and fills in `Config/ProductIds.luau`.

**B. By hand** (Creator Dashboard → Glass Clash → Monetization → Developer Products), regional pricing **off**:

| Create | Name | Price | Then paste the id into `src/shared/Config/ProductIds.luau` |
|---|---|---|---|
| new | Starter Pack | 49 | `StarterPack` |
| new | Daily Glassy | 9 | `DailyGlassy` |
| new | Daily Marbles | 49 | `DailyMarbles` |
| new | Marble Barrel | 1,999 | `MarbleBarrel` |
| new | Daily Offer: Mythic Finisher | 499 | `FinisherMythic` |
| new | Daily Offer: Epic Flyer | 199 | `FlyerEpic` |
| new | Daily Offer: Legendary Flyer | 399 | `FlyerLegendary` |
| new | Daily Offer: Mythic Flyer | 599 | `FlyerMythic` |

| Change price of | Id | From | To |
|---|---|---|---|
| Marble Pouch | 3719142028 | 399 | 199 |
| Marble Jar | 3719142039 | 799 | 399 |
| Marble Bucket | 3719142052 | 1,899 | 799 |

(Marble Chest 3,999 and Marble Vault 8,999 keep their prices; only their Marble amounts change in config.)

| Change price of | Id | From | To |
|---|---|---|---|
| Hollowlight Collection | 3719124109 | 499 | 699 |
| Glassy Epic | 3719124045 | 179 | 199 |
| Glassy Epic Featured | 3719124054 | 229 | 249 |
| Glassy Legendary | 3719124061 | 349 | 399 |
| Finisher Uncommon | 3719124072 | 39 | 49 |
| Finisher Rare | 3719124077 | 79 | 99 |
| Finisher Legendary Featured | 3719124089 | 279 | 299 |
| Flyer Uncommon | 3719124092 | 59 | 79 |
| Flyer Rare | 3719124095 | 119 | 149 |
| Flyer Epic Featured | 3719124103 | 249 | 299 |

Icons: any square picture works; the Starter Pack can use Sunny's item picture, the Daily Glassy the Marble Kiln
picture, Daily Marbles the Marble pile.

**Until this is done nothing is sold at a wrong price**: `Util/ProductPrices` reads each product's real price from
Roblox and holds back any product whose dashboard price differs from config (it shows SOON, the server refuses the
prompt and the output says which ids). The three new offers show SOON on live servers; in Studio they run on
placeholder ids with a simulated receipt (nothing is charged).

## 10. After launch

- Watch payer conversion, ARPPU and per-product sales in Creator Dashboard; Starter Pack conversion among new players;
  Daily Glassy / Daily Marbles repeat rate; how often Need Marbles leads to a buy.
- Turn on **regional pricing** per product once the dashboard prices are settled (§2.1). The cards then need the
  per-player price from `GetProductInfo` instead of config (and `ProductPrices` would compare the default price).
- At ~60,000 transactions a month, run **Price Optimization** (needs those scripted prices too).
- If players call rerolls pay-to-win, make them coins-only (decision 25's note still stands).
