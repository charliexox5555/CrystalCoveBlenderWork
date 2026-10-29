# Glass vs Glass: core-loop research and playable hypotheses

Research date: October 29, 2026. Scope: primary-source competitor review, the supplied funnel, existing design/code, and the simplification being implemented in this session. This is a prioritization report, not evidence that retention has improved. No competitor's private retention, revenue, conversion, or playtest data was available.

## The strongest diagnosis

The player should be able to describe the game as **pick a glassy, pull and release, watch a smash, earn the next glassy, try it**. The collecting and the fighting must join into one loop. A reward that only ends an opening animation is a weak reason to start another match; a new glassy with a visibly different power that can be tried immediately is a stronger, testable proposition.

The funnel supports prioritizing that transition:

| Observed transition | Conversion | Interpretation |
|---|---:|---|
| Joined → First Match Started | 666 / 826 = 80.63% | Navigation/onboarding deserves work, but most logged joiners reach a match. |
| Win Prize Collected → Second Match Started | 187 / 336 = 55.65% | 149 collectors do not start the next match. This is the clearest replay problem in this screenshot. |
| Second Match Started → Second Match Finished | 123 / 187 = 65.78% | A second match must also hold attention. Historically this finish event could include a forfeit. |
| Joined → Second Match Finished | 123 / 826 = 14.89% | A logged progression result, not Day 1 retention. |

Do not label the 610 First Round Finished → 394 First Match Won gap as 216 quits. Losses, legacy bugs, and later-event backfilling complicate that interpretation. Dates/build and acquisition mix remain unknown. The creator reports roughly four-minute playtime and zero retention; the underlying cohort graphs have not been supplied. See the [earlier diagnostic](RETENTION_DIAGNOSTIC_2026_10_26.md).

## What the reference games actually establish

| Primary source | Verified public proposition | Useful inference for Glass vs Glass |
|---|---|---|
| [Ball VS Ball](https://www.roblox.com/games/96510596525082/Ball-VS-Ball) | Its creator describes automatic PvP, a three-ball choice, one free pick-any per match, and more than 40 balls with distinct skills. | Pre-battle choice plus collectible identity can carry an auto-battle's promise. The page does not verify a particular aiming gesture or explain its retention. |
| [Super Auto Pets, developer page](https://teamwood.itch.io/super-auto-pets) | The developer describes choosing animals with distinct abilities that fight for the player. Its advertised arena mode offers asynchronous opponents and a ten-win objective. | Automatic combat still needs decisions with readable consequences and a visible run goal. Importing its team/shop complexity or asynchronous infrastructure is unnecessary for this pass. |
| [Blade Ball, creator page](https://www.roblox.com/games/13772394625/Blade-Ball) | Its central threat increases in speed. Its listed controls include block and ability inputs, and its progression includes abilities, ranks, skins, and finishers. | Escalating, readable danger is relevant. It is inaccurate to claim this proves successful games have only one button. Do not reintroduce CAST/PUSH merely to imitate it. |
| [Bee Swarm Simulator, creator page](https://www.roblox.com/games/1537690962/Bee-Swarm-Simulator) | Its description connects collecting pollen, making honey, growing the hive, unlocking exploration, and discovering distinct bees. | The next reward should change what the player can do or show off. A coin number with no visible destination is a weaker progression explanation. |

These are descriptions of advertised mechanics, not controlled comparisons. This review did not play those games or verify their current onboarding screens, fight durations, asset quality, or active-player counts. The static Roblox page's “no running experiences” text is not a reliable activity measurement.

Roblox's [onboarding guidance](https://create.roblox.com/docs/production/game-design/onboarding) recommends essential controls, early value, visible goals, and an enjoyable finishing moment. Its [core-loop guidance](https://create.roblox.com/docs/production/game-design/core-loops) connects repeated interaction to progression. The application here is to finish a short smash-and-unlock cycle, rather than teach every existing menu before the first fight.

## Ranked implementation priorities

### 1. Make the first new glassy usable immediately

The first-prize replay prompt should show the actual prize, give one obvious continuation action, and make that owned glassy available in the next hand. Keep the regular free pick-any choice. Avoid a purchase popup or another claim menu between unlocking and trying it. The current `ReplayGlassy` / `FirstOffer` implementation is aimed at this hypothesis.

**Check:** an unfamiliar player can point to the new glassy, start the next match, and select it without being told to search Inventory. Verify reconnects, menu interruptions, reset, and an unowned/invalid preferred ID. A guaranteed card is not a paid pull and must not alter displayed Kiln odds.

### 2. Let players finish the smallest honest version of the loop

A single-round Rookie Bot introduction can teach selection and the release gesture, show the shatter, and award the existing first prize. The existing Day 1 gift can be secured without opening the calendar as an extra prerequisite. Preserve normal three-heart matches and truthful bot labeling.

**Check:** measure loading-complete → first release → first shatter → new-prize collection → next-match start. Report median and p90, not only an average. A proposed local aim is to show the first shatter within the first minute of active play; this is our test target, not an industry benchmark or a guaranteed outcome. Do not make an eight-second first-pick timeout so short that a beginner cannot inspect and choose a card.

### 3. Give automatic powers clear personalities

With manual casting and modifiers removed, the collectible must supply the surprise. A shield should look like a shield at the moment damage is blocked; a beam should visibly originate from the attacking glassy; cracks and HP should agree. The player should recognize one signature action per glassy without learning trigger, passive, burst, Heat, glint, and twist vocabularies together.

**Check:** after one fight, ask “What happened?” and “What would you change next time?” without teaching the answer. If players cannot identify their glassy, the winner, or a power's effect, fix camera/scale/contrast/timing before adding more particles. If all three offered glassies feel equivalent, make their existing powers more readable before increasing roster size. These are design hypotheses, not a finding from a completed novice test.

### 4. Keep the match moving after its first dramatic moment

Long setup and repeated waits consume a large share of a short session. Keep the previous selection and aim as safe defaults, advance when both sides are ready, and make later-round changes optional. Preserve a short finisher payoff, then return to a decision. Avoid replacing removed mechanics with more intermediate screens.

**Check:** measure time spent choosing, aiming, counting down, fighting, and finishing separately. A player looking at a beautiful arena for twenty seconds is not necessarily enjoying combat. Test at least one quiet matchup and one power-heavy matchup; simulator “events per second” is not a measure of fun.

### 5. Expose a short goal using the economy that already exists

Show coins toward one 300-coin Kiln open, plus the actual Day 2 Whiskers promise when eligible. Let the new glassy carry the immediate replay reason and the existing daily collectible carry a return reason. Do not add a new paid feature or inflate rewards to mask an unclear fight.

**Check:** ask “What would you earn by playing again?” A valid answer is a particular unlock or progress toward the next open. Check the goal against the authoritative profile, current price, claimed-day state, and supported phone layouts.

### 6. Refine the map only where it interrupts the loop

The existing map and UI art already establish a recognizable glass identity. Prioritize the spawn view, PLAY visibility, arena route, and in-fight framing. A complete map rebuild is lower priority than replay and combat comprehension unless unfamiliar players actually fail to find a match. Keep gameplay visually primary over shop displays and offers during the introduction.

## Playtest and live evaluation

First use a small diagnostic group of unfamiliar touchscreen players. Let them act without coaching and record the point of confusion, extra taps, idle waits, and whether they voluntarily start another match. Five to eight participants is a practical initial diagnostic batch, not statistical proof. Roblox explicitly recommends [early small-group tests](https://create.roblox.com/docs/get-started/strategies) to find usability and fun problems before expanding scope.

Once the build is technically sound, compare stable, dated cohorts with similar acquisition and device mix. Use the new versioned match funnel for starts, first real fight/shatter, and natural completion. Keep early-end reasons separate. Retain the legacy funnel for history; do not interpret mixed-build step changes as a treatment effect. Use Roblox's actual [first-session retention chart](https://create.roblox.com/docs/production/analytics/engagement) for the share still playing at five and ten minutes, and [D1 cohorts](https://create.roblox.com/docs/production/analytics/retention) for next-day returns.

Success should mean more players choose and complete another match, understand the fight, and return—not merely more clicks on a replay button. Inspect crashes/frame rate and losses as guardrails. A before/after result is directional when traffic differs; use a controlled experiment if a causal claim is needed.

No purchase-data diagnosis is justified yet. Audit offer exposure, eligibility, policy filtering, checkout prompts, and receipt fulfillment before changing prices or adding offers. Monetization can be assessed once users understand and repeat the game.

## Bounded monetization exposure and receipt audit

Read-only source audit on October 29. StoreService was also read from the live Studio Server DataModel; no prompt, receipt, purchase, policy, account, or store state was changed. A later attempt to read the runtime held-product list found Studio back in Edit mode; no held-product result was obtained. Actual published exposure, Roblox product listing settings, dashboard prices, and buyer counts remain unverified.

**Configured sales are broader than the roadmap header suggests.** `src/shared/Config/ProductIds.luau:20` contains non-nil Starter, Daily Glassy, Daily Marbles, and additional product IDs. `src/server/Services/StoreService.luau:337` registers Marble packs, direct bundles, daily direct items, and the three deals. `src/server/Services/KilnService.luau:67` includes Marble crate quotes when the account is paid-random eligible, and line 131 rejects restricted requests on the server. There is no global “all Marble packs disabled” switch in these paths. The old F5 header should not be used as a current availability statement. Gamepasses have no configured sales path in this review; tester Marble grants are explicitly disabled in `src/shared/Config/Testing.luau:7`.

Eligibility and exposure checks found:

| Path at audit time | Behavior | Implication/action |
|---|---|---|
| `src/server/Services/StoreService.luau:65`, `:105`, `:230`; `src/server/Util/ProductPrices.luau:57` | Known dashboard/config price mismatches make products unavailable; an unknown price permits Roblox's native prompt. | “SOON” can be a price hold rather than a disabled feature. Check the live held list and native price before making a pricing diagnosis. No mismatch was established by this audit. |
| `src/shared/OfferRules.luau:147`, `:180` | Starter is one purchase, has a 72-hour window from first server exposure, and can auto-open at most twice. | An eligible, populated product is not evidence a player saw or understood its popup. |
| `src/shared/OfferRules.luau:240`, `:330` | Daily Glassy is hidden/rejected without positive paid-random eligibility; it is limited to one purchase per UTC day. | Restricted or unresolved-policy players are intentionally outside this offer's eligible denominator. |
| `src/client/Controllers/DealsController.luau:162`, `:352` | A paid random tile labeled “Daily” and priced 9 Robux is distinct from the free Daily Rewards calendar in the gift menu. | Consider the clearer caption “Daily Glassy.” This is a comprehension hypothesis, not measured evidence of lost purchases. The tile's ODDS control is separately accessible. |
| `src/client/Controllers/DealsController.luau:380` | Starter auto-open waits for Done, a free lobby, no menu/match/queue, and no `PlayAgainShown`, then 3.5 seconds of quiet. It has no second-natural-match-completion gate in the audited snapshot. | Replay gets priority while shown, but after its 30-second timeout a paid popup can still arrive before match two. Recommended: defer this automatic popup until the second natural finish; keep manual store access. Main implementation may supersede these line references. |

**Receipt-misuse verdict: PASS for the narrow silent-loss check.** Section A blockers: none found. Section B taxonomy warnings: none found in the inspected active paths. There is one active server assignment to `MarketplaceService.ProcessReceipt` (`StoreService.luau:357`). No grant is performed from `PromptProductPurchaseFinished`; that event only cancels an unfinished intent or restores client UI (`StoreService.luau:372`, `DealsController.luau:471`). Missing player/data/intent returns `NotProcessedYet` (`StoreService.luau:261–283`). `SaveAndWait` checks the saved profile (`:132`), and `PurchaseGranted` is returned only after the processed receipt is saved (`:286–308`).

The grant helpers inspected were `ReplicatedStorage.Shared.DailyStoreRules`, `ReplicatedStorage.Shared.OfferRules`, `ReplicatedStorage.Shared.RoundCosmeticRules`, and `ServerScriptService.Server.Data.ProfileSchema`, with `ServerScriptService.Server.Util.ProductPrices` for offer gating. Inventory grants assert valid content; `DailyStoreRules.luau:471` deduplicates PurchaseId before granting and records it with the profile at line 497. The processed-receipt history is explicitly capped at 200 entries (`Config/DailyStore.luau:122`, `DailyStoreRules.luau:505`), so this is bounded history, not a claim of unlimited idempotency.

**Functional limitation requiring review:** `DailyStoreRules.luau:475–477` requires an existing persisted in-game intent for every product, including fixed Marble packs. An out-of-experience purchase with no such intent remains pending; `StoreService.luau:283` safely refuses to acknowledge it. This is not silent purchase loss under the misuse taxonomy, and it cannot explain a zero-sale count by itself. Before enabling or advertising Store-tab/other external product purchase, define deterministic recovery for fixed-grant products and an explicit policy for dynamic offer products. Do not reconstruct a random/dynamic item from today's offer if it differs from what the buyer saw. No receipt or offer code was changed by this audit.

## Defer until the short loop works

Trading, new modes, more arena events, more currencies, a larger roster, elaborate quests, and a map replacement all add scope without directly addressing the measured first-prize-to-replay gap. They can be revisited after observed players enjoy two matches and the live cohorts show sustained improvement. None of the public sources reviewed establishes that copying one feature will make this game popular.
