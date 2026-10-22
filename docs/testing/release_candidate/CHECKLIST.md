# Release-candidate checklist (Oct 22, 2026)

QA pass before today's group test and Saturday's public release. Each check is marked:

- **PASS**: verified in code or in Studio, with evidence.
- **FIXED**: was broken; fixed in this pass (commit named).
- **CREATOR**: needs the creator (a setting, a dashboard step or a decision).

Scope: no redesigns. Only real bugs and security or data issues were fixed.

## How the checks were chosen (sources)

| Area | What the source says | Source |
|---|---|---|
| Remotes | Validate types, reject NaN/inf (`math.isfinite`), cap string and table sizes, check bounds and ownership, recompute results on the server. Rate-limit on the server (client limits are not enough) and clear limiter data when players leave. | [Securing the client-server boundary](https://create.roblox.com/docs/scripting/security/client-server-boundary) |
| Remotes | The engine throttles each client at about 500 remote calls per second per remote type, so the server's own limits do the real work. | [RemoteEvent reference](https://create.roblox.com/docs/reference/engine/classes/RemoteEvent) |
| Purchases | Grant only in `ProcessReceipt`; key the grant on `PurchaseId`; return `PurchaseGranted` only once the grant is saved; return `NotProcessedYet` when the player is absent or the save fails. Never trust `PromptProductPurchaseFinished`. | [ProcessReceipt](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService/ProcessReceipt), client-server boundary page (Purchases) |
| Data | Wrap store calls in `pcall`. A failed write may still have landed. Watch the request budgets; `UpdateAsync` spends the read and the write budget. GetAsync budget per minute is 60 + 40 × players. | [Data store error codes and limits](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits) |
| Data | Session locking stops item duplication across servers. ProfileStore is loleris's successor to ProfileService. `BindToClose` gives about 30 s to finish saves. | [ProfileStore (DevForum)](https://devforum.roblox.com/t/profilestore/3190543), [DataModel.BindToClose](https://create.roblox.com/docs/reference/engine/classes/DataModel), [DevForum: BindToClose and data loss](https://devforum.roblox.com/t/bindtoclose-data-loss-risk/135693) |
| Paid random items | Show every outcome with real odds (percentages adding to 100%) before Robux or Robux-bought currency is spent; a pop-up is fine if its button says "Info"/"Details" (not a bare (i)). Where `ArePaidRandomItemsRestricted` is true, hide or replace the item. | [Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items) |
| Text | Developers must filter text they display that they don't control (TextBox input, stored player text). Default Roblox chat is already filtered. | [Text filtering](https://create.roblox.com/docs/ui/text-filtering) |
| Publishing | Every public experience needs an accurate Maturity & Compliance questionnaire; unrated experiences are restricted. Minimal/Mild labels can reach Roblox Kids (5–8) and Select (9–15). | [Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity) |
| Publishing | Under-16 players can only play once the game passes Kids & Select eligibility (creator verified + 2-step verification, a Plus/Premium subscription or a refundable fee, the full questionnaire, then 250 unique plays from highly engaged age-checked 16+ players within 60 days, or a refundable expedited review). | [Roblox Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select), [DevForum: Kids and Select global launch](https://devforum.roblox.com/t/roblox-kids-and-select-global-launch-upcoming-updates-to-eligibility-ads-manager-and-expedited-review/4685717) |
| Streaming | Streaming on, `ModelStreamingBehavior = Improved`, `StreamingIntegrityMode = PauseOutsideLoadedArea`, keep the default `StreamingMinRadius` (64) so low-end phones can scale down. | [Streaming techniques](https://create.roblox.com/docs/workspace/streaming/techniques) |

## 1. Security

| Check | Status | Evidence |
|---|---|---|
| Every client → server remote validates its arguments and is rate-limited per player | **PASS** | All 25 client → server remotes in `src/shared/Remotes.luau` read end to end (read-only `roblox-reviewer` audit plus my own read). Every handler type-checks and size-checks, rejects NaN/inf (`RemoteGuard.finite`) and is rate-limited through `Util/RemoteGuard` (`Balance.Match.*RateSeconds`, `Balance.Data`, `Balance.Retention`, `Config/GroupReward`, `Config/Offers`). Table: [Remote verdicts](#remote-verdicts). |
| Nothing grants currency, items or XP from client input | **PASS** | Grants come only from server rules: the match result (`MatchService` → `DataService:RecordMatch`), Kiln pulls (server quote token, server price, policy gate), codes (server list; StudioOnly codes refused live), retention (server-tracked progress), the group reward (server membership check; claimed flag set without a yield in between), and receipts. Remote flood: see [Remote flood](#remote-flood). |
| Remote flood (malformed input through every remote) gives nothing | **PASS** | New fixture `tools/studio/verify_release_remotes.luau` (Studio Play, Client): NaN, ±inf, a 5,000-char string, a table, an Instance, `true`, -1 and 1e300 sent 20 times through all 25 client remotes (180 calls each, paced under Roblox's ~500/s throttle). Coins, Marbles, Trophies, XP, glassies and Kiln pulls unchanged; private profile fields not sent to the client; no server errors ([bot_session.json](bot_session.json) `RemoteFlood`). |
| Dev hooks are Studio-only | **PASS** | All 12 `*Dev` BindableFunctions (Data, Match, Store, Retention, Cosmetic, Onboarding, GroupReward, Badge, Hill, Leaderboard, Fight, PerfProbeServer) are created inside `if RunService:IsStudio()` (FightService returns early before creating it) and parented to ServerStorage, which clients can't see. The QA harness RemoteEvents (`Dev/*Harness.server.luau`) exist only in Studio **and** only under a matching `StudioTestService` test name. `MultiplayerLauncher` asserts Studio + Edit. Studio placeholder purchases (fake receipts) only run in Studio (`StoreService:Prompt`). |
| Kiln odds must be opened before a pull | **PASS** | `KilnService:Pull` refuses without a one-use quote token from the odds view (expires after `KilnQuoteSeconds`, invalid if the pool changed). |
| Perfect release is judged on the client's aim number | **CREATOR** (accepted design risk) | `SetAim` sends the aim value; the server clamps it and judges Perfect from it. A modified client can send the sweet spot every round: +15 XP per Perfect and the Perfect coins on a loss. Small rewards, no currency for Robux. Options: accept, or cap Perfect rewards per match. Not changed (it's the aim mechanic). |
| Codes list is visible to clients | **PASS** (low) | `Config/Retention.Codes` is in ReplicatedStorage. Studio codes are refused live; RELEASE and HALLOWEEN are public anyway. A future code with a `Starts` date could be read early: keep secret codes out of it, or move Codes to the server later. |

## 2. Data

| Check | Status | Evidence |
|---|---|---|
| Session locking | **PASS** | ProfileStore `StartSessionAsync`; a session taken by another server kicks the player ("opened in another server"). A failed load kicks; it never starts a blank profile. A profile from a newer schema kicks ("needs a newer server"). |
| Reconcile for every new field | **PASS** | `ProfileSchema.reconcile` fills from `Schema.new` and repairs types for Xp (levels), `Badges` (BadgeRules.reconcile), `Flags.GroupRewardClaimed`, `Store`/`Deals` (Starter Pack, Daily Glassy, Daily Marbles through DailyStoreRules/OfferRules.reconcile), `Calendar`, `FreePulls`, `Stats`, `Spend`. Lune: ProfileTests, BadgeTests, GroupRewardTests, OfferTests, DailyGlassyTests (267/267 passing). |
| Autosave and BindToClose | **PASS** | ProfileStore autosaves every 300 s and its own `BindToClose` waits for the final saves; `DataService` releases every profile on close. Purchases, Kiln pulls, codes, matches and claims save right away (`Profile:Save()`). Players leaving: released 0.25 s after `PlayerRemoving`, after any forfeit is recorded. |
| No mock path in live | **PASS** | `DataService.Mock = IsStudio() and StudioMock` (same in LeaderboardService). DataDev "Marbles"/"MockProfile", StoreDev "Receipt"/"Offset"/"ResetDeals" all need Mock. |
| Live and Studio data separate | **PASS** | Profiles: `GlassClash_Studio_v3` vs `GlassClash_v3` (since `5eb60a6`); Studio runs on the mock anyway. Leaderboards: Studio prefix. Settings store is shared (`GlassClashSettings_v1`), which only matters for the creator's own volume settings in Studio. |
| Profile viewer could drain the server's read budget | **FIXED** `f8069d2` | `RequestPlayerProfile` reads offline profiles from the store (1 per s per player). A spammer could spend the GetAsync budget that profile loads share. Store reads now stop while the budget is under `Balance.Levels.ViewReadReserve` (40). |
| Settings overwritten with defaults after a failed read | **FIXED** `96d2bb0` | If the settings read failed and the player then changed a setting, the save replaced their stored settings with defaults. A failed read now skips this visit's saves. |
| Tester Marbles in live | **PASS** (resolved by the creator, `5eb60a6`) | Found `Config/Testing.TesterMarbles` ON (10,000 Marbles to every joiner, saved in the live store, more than the 3,999 R$ Chest). The creator turned it off and moved live data to a fresh store `GlassClash_v3` (leaderboards follow; v2 playtest data kept untouched), so nobody starts the release with tester Marbles. |

## 3. Purchases

| Check | Status | Evidence |
|---|---|---|
| `ProcessReceipt` is idempotent for every product | **PASS** | One owner (`StoreService`). `DailyStoreRules.applyReceipt` writes `ProcessedReceipts[PurchaseId]` in the same step as the grant (no yield); a repeat returns "Duplicate". `PurchaseGranted` only after a completed save contains that PurchaseId; otherwise `NotProcessedYet`. Player absent / profile not loaded within 10 s → `NotProcessedYet`. Covers all Marble packs (7), bundles (2), daily-store Robux products (19) and the 3 deals (Starter, Daily Glassy, Daily Marbles). Lune: DailyStoreTests, OfferTests. |
| One-time and daily limits refused before the prompt | **PASS** | Starter Pack once ever, Daily Glassy and Daily Marbles once per day, a daily offer once, a bundle refused when every item is owned (`OfferRules.intent`, `DailyStoreRules.beginIntent`). The intent is saved and confirmed before `PromptProductPurchase`. |
| Price guard | **PASS** | `Util/ProductPrices` reads every product's dashboard price; a product whose price differs from config shows SOON and never prompts. An unknown price (lookup failed) doesn't block, since Roblox's dialog shows the real price. |
| Paid random items hidden by PolicyService; odds first | **PASS** | `MatchService` fetches `ArePaidRandomItemsRestricted` per player and fails closed (no answer = restricted). Gated: Marble Kiln opens, Reroll, Daily Glassy, the group reward's Marble Kiln (falls back to a Coin Kiln). Daily Glassy: an ODDS button on the tile and the popup's odds column with DETAILS (every glassy, rounded per the policy) before the Robux prompt. Kiln: quote token as above. |
| No grant twice on rejoin | **PASS** | PurchaseId kept in the saved profile (last 200); session lock stops two servers granting at once. Group reward: flag checked again after the yield. Codes: `CodesRedeemed`. Tester Marbles: once per wave flag. |
| Receipt with no saved intent | **PASS** (low) | Only reachable if an exploiter prompts a product from their own client. It returns `NotProcessedYet` and grants nothing; this is the tested rule (DailyStoreTests "both paid prompts honored"). |
| Game-pass spend on the supporter boards | **PASS** (low) | `PromptGamePassPurchaseFinished` records any pass id; no passes are on sale. If passes are added, keep an allowlist of this game's pass ids. |
| Products held back for price mismatches | **PASS** | StoreDev "Held" in Studio Play returned none: every product's dashboard price matches config right now. Re-check after any dashboard price change (the game holds a mismatched product as SOON). |

## 4. Multiplayer and stability

| Check | Status | Evidence |
|---|---|---|
| Two-client harness (`MultiplayerLauncher.run()`) | **FIXED** then **PASS** `7d3e791` | The harness was stale: new QA profiles hit the onboarding claim card (decision 100) before the pad queue, and fight snapshots only reach players near an arena (decision 103), so the late joiner at spawn saw none. Fixed the harness, not the game. Result: all 6 stages pass in 220 s, zero errors ([multiplayer.json](multiplayer.json)): isolated profiles and invalid inputs refused; two-human pad queue; seven moving fights (server 59.8 FPS, fight step 0.05 ms mean / 4.3 ms max); full PvP settlement with cameras and controls restored; Play Again plus a disconnect forfeit (no rewards for an abandoned match); a late joiner with its own profile and live spectator state. |
| Watch harness (`.watch()`) | **PASS** | Watch QA passed, 4 watched rounds, zero errors ([watch.json](watch.json)): watching with another player in the arena, respawn into the watched arena, own match isolation (others hidden, restored after), watching a human match until the forfeit ends the watch. |
| Leaks across 10+ rounds; errors in a long bot session | **PASS** | Studio Play, MatchDev "AllBots" twice: 14 bot matches, **74 rounds**, 6.5 min, with the player standing between the arenas ([bot_session.json](bot_session.json)). Server: `game` descendants **62,556 before, after wave 1 and after wave 2** (no instance growth), Lua heap 19.7 → 21.0 MB (GC noise), no matches left running, **zero errors and zero warnings** from game code. Client: no fight leftovers in Workspace (every "shard" instance belongs to the lobby showcases); the client's Workspace count changed only through streaming as the player moved. Only console noise: `rbxassetid://203785492` "Asset type does not match" (an asset in the place, not in `src`; seen in earlier reports too). |

## 5. Content and safety

| Check | Status | Evidence |
|---|---|---|
| No alcohol | **PASS** | ConfigTests "no alcohol in names or descriptions" covers every glassy and power (Lune). Searched all config names: none. Internal names like "Mystery Brew" (a potion) and "Nightcap" (a motion key, never shown) are fine. |
| No brands or copyrighted names | **PASS** | Searched every `Name = "..."` in `src/shared/Config` and code for common brands (soda, toy, game and film brands): none. Names are generic objects (Ketchup Bottle, Milk Bottle, Lemonade Bottle, Glass Unicorn...). Music is Roblox library audio. |
| No wagering | **PASS** | No stake on any match result: rewards come from `MatchLogic`; Marbles only buy Reroll / Pick Any for your own hand. |
| Player text filtered | **PASS** | The only TextBox is the code box (Rewards); the code is matched against a server list and never shown to other players. No player-typed text is displayed anywhere. Arena boards show `DisplayName`; offline leaderboard and profile names come from `GetNameFromUserIdAsync` (the Roblox username, already moderated by Roblox). Chat is Roblox's own. |
| **Supporter boards vs the design rules** | **CREATOR** | GAME_DESIGN §10 says "no spending leaderboards", but decision 101 (Proposed, a creator request) shows two "TOP SUPPORTERS" boards ranked by Robux spent. Roblox doesn't forbid this, but for an audience of mostly kids it can read as pressure to spend. Worth a second look before Saturday: keep, swap to another stat in `Config/Leaderboards`, or keep only the all-time board. Not changed. |

## 5b. No free or test grants live

Everything that hands out currency or items outside normal play, and whether it can run on a live server. Locked in by a new Lune suite, `src/tests/ReleaseGuardTests.luau` (270/270 passing): it fails if tester Marbles come back on, if a `TEST*`/`STUDIO*` code isn't StudioOnly, if any StudioOnly code works live, if a live code gives free Marbles, or if Studio and live share a profile store.

| Grant path or switch | Live state | Evidence |
|---|---|---|
| Tester Marbles (`Config/Testing`) | **Off** | `Enabled = false` (creator, `5eb60a6`); live data starts fresh in `GlassClash_v3`. ReleaseGuardTests. |
| Studio codes: STUDIOCLASH, TESTMARBLES, TESTKILN, TESTFLYER, TESTITEM, TESTEXPIRED | **Refused live** | All `StudioOnly = true`; `RetentionRules.redeem` refuses them unless the server is Studio. RetentionTests ("TESTMARBLES ... Studio only") and ReleaseGuardTests. |
| Live codes: RELEASE (300 Coins), HALLOWEEN (1 free Finisher crate pull, ends Nov 8 00:00 UTC) | **On (intended?)** | Both redeem once per player. **CREATOR:** confirm you want both at launch; they're the only live codes. |
| Dev hooks (12 `*Dev` BindableFunctions) | **Not created live** | All created inside `if RunService:IsStudio()`, parented to ServerStorage (not visible to clients). |
| QA harness remotes (`Dev/*Harness.server.luau`) | **Not created live** | Return early unless Studio **and** a matching `StudioTestService` test name. |
| Client dev scripts (UIAudit, PerfProbe, harnesses, CombatFeel/PowerVFX/UI previews) | **Inactive live** | Each returns or asserts on `IsStudio()`; they run on the client only and can't grant anything. |
| Mock profiles (`DataService.Mock`, LeaderboardService) | **Studio only** | `Mock = IsStudio() and StudioMock`. Mock-only commands (DataDev "Marbles"/"MockProfile", StoreDev "Receipt"/"Offset"/"ResetDeals") sit behind it. |
| Studio placeholder purchases (fake receipts, product ids 1-3) | **Studio only** | `StoreService:Prompt` and `OfferRules.product` use them only when the server is Studio; live uses the real product ids in `Config/ProductIds`. |
| Studio-only switches (workspace attributes `PerfNoCull`, `PowerFXLowDetail`, `LoadNoLater`; `PlayerGui.DevInput`) | **Ignored live** | Every read is `IsStudio() and ...`. |
| Debug prints (funnel, "would award" badges, placeholder purchases) | **Studio only** | Printed only in Studio; live sends the real analytics/badge calls. |
| Scripts in the place outside Rojo | **None of ours** | Scanned the place: the 54 non-Rojo scripts are Roblox's default PlayerModule and character scripts. No `require(<id>)`, `getfenv`, `loadstring`, HTTP, currency, badge, purchase or teleport code. `HttpEnabled` is off. |
| Old `Config/Retention.GroupId = 0` | **Harmless** | A leftover from before the group reward; it only sets `GroupConfigured = false` in the Rewards view. The group reward itself uses `Config/GroupReward.GroupId` (11116787). |
| Settings store (`GlassClashSettings_v1`) | **Unchanged (fine)** | Volumes and toggles only; nothing grantable. |

Free grants that remain on are the designed ones: welcome opens, Daily Rewards calendar, playtime gifts, daily quests, first-win prize, the group reward and the two live codes.

## 6. Publishing settings to set on the Creator Dashboard

Recommendations only; nothing was changed.

| Setting | Recommendation | Why |
|---|---|---|
| Server size | **16** | 7 arenas × 2 = 14 fighters plus a couple watching. The perf pass measured ~27 kbps per player with 7 fights on. The place currently reports MaxPlayers 60, far more than the lobby can use: most players would be waiting. Raise later if queues stay empty. |
| StreamingEnabled | Keep **on** (it is). Check `ModelStreamingBehavior = Improved`, `StreamingIntegrityMode = PauseOutsideLoadedArea` (or Default), `StreamingMinRadius` 64, `StreamingTargetRadius` 256 or more | Creator Docs streaming techniques; the whole lobby is a few hundred studs, so a 256+ target keeps every arena loaded. Only 2,150 parts on the server. |
| Private servers | **Off** for launch | Matches need other players (bots fill in, but the lobby and boards are the point); a paid private server adds little. Turn on later, free or cheap, for friends groups. |
| Devices | **Computer, Phone, Tablet** on; **Console off** until a real controller is tried; **VR off** | The UI is built for touch and mouse. Controller support exists (decision 107) but was only tested in Studio with a simulated gamepad; the input session asked the creator to try a real controller first, and another player's profile can't be opened with a controller yet. No VR camera work. |
| Genre | **Party & Casual → Minigame** (creator's choice) | Fits short 1v1 rounds. |
| Maturity & Compliance | Fill in **every** question honestly (needed for Kids & Select). Expected label: **Minimal or Mild** (cartoon glass shattering, no blood, no realistic violence). Declare: paid random items (Marble Kiln, Daily Glassy) with odds and PolicyService; no user-generated content; no free-form social hangout; Roblox chat only. | Content maturity docs. |
| **Kids & Select eligibility** | **Important for a kids' game:** without it, only age-checked players **16+** can play. Needs creator ID/age verification, 2-step verification, a Roblox Plus/Premium subscription (2+ months) or the refundable per-game fee, the full questionnaire, then 250 unique plays from highly engaged 16+ players within 60 days (or the refundable 50,000 R$ expedited review). | Kids and Select docs. Plan Saturday's launch knowing under-16s may not see it right away. |
| Social links | Add the **Roblox group** link (the group reward uses group 11116787). Other social links are hidden from under-16s anyway. | Kids and Select changes (social links hidden for under-16s since June 30). |
| Badges | The 5 badges exist and are enabled (decision 118). Check their icons passed moderation; publish and check the Welcome badge arrives on a live server (ROADMAP item). | `Config/Badges` ids. |
| Paid items on the dashboard | Make each developer product's dashboard price match config, or the game holds it back as SOON (see Purchases). | `Util/ProductPrices`. |

## Remote verdicts

| Remote | Verdict |
|---|---|
| PickGlassy | OK: string ≤ 64, must be in this round's offers, only while Rolling, 0.25 s |
| Reroll | OK: match id, round, revision and quoted cost must match; policy-gated; Marble debit and reroll without a yield; 0.5 s |
| PickAny | OK: as Reroll, plus the glassy must be owned; 0.5 s |
| SetAim | OK (finite, clamped, once per phase, 0.05 s); Perfect judging is a design risk (§1) |
| CastPower | OK: own side in a running fight; 0.15 s |
| LeaveQueue, JoinNearestArena | OK: no arguments accepted; 0.25 s / 0.5 s |
| RequestRematch, RequestFightState, RequestProfile, RequestKiln, RequestStore | OK: no arguments used; 0.5 s |
| RequestPlayerProfile | OK: integer user id 1..2^53, 1 s; store reads now budget-gated (FIXED) |
| PullKiln | OK: count 1 or 10, one-use quote token, category/currency checked, Marble opens policy-gated, server cost; 0.75 s |
| ClaimRetention | OK: server-tracked progress; 0.5 s |
| RedeemCode | OK: ≤ 32 chars, pattern-checked, once per code, StudioOnly refused live; 1 s |
| EquipRoundCosmetic | OK: owned and installed only; 0.5 s |
| BuyStoreOffer | OK: slot range, id ≤ 40, server day, server Coin price, not in a match; 1 s |
| BuyStoreBundle, BuyMarblePack | OK: id looked up in config; 1 s (shared "Buy" limit) |
| Deals | OK: fixed actions; kind looked up in `Offers.Kinds`; 1 s / 0.5 s / 5 s |
| OnboardingAction | OK: each action only works on its own step; 0.5 s |
| RequestSettings, SetSetting | OK: keys allowlisted, values finite/boolean and clamped; 1 s / 0.2 s |
| GroupReward | OK: membership checked by the server; claim flag re-checked after the yield; 2 s / 1.5 s |

Every service drops its RemoteGuard entry and per-player tables on `PlayerRemoving`.

## Go / no-go for today's group test

**Go**, with these done first:

1. **Tester Marbles are now off and live data starts fresh in `GlassClash_v3`** (creator, `5eb60a6`). The group test runs on the release store, so testers' progress carries into Saturday; if you want a clean launch, bump `Balance.Data.StoreName` again before Saturday.
2. **Save and publish the place from Studio with Rojo connected**, so the published place has today's code and the Studio-only installs several sessions left unsaved (group reward stand, Daybreak set, daily glassies, re-uploaded meshes, flyer installs).
3. **Confirm the two live codes** (RELEASE 300 Coins, HALLOWEEN a free Finisher pull until Nov 8) are wanted at launch.
4. **On the live server**, check: the Welcome badge arrives; a purchase works end to end (cheapest Marble pack or Daily Marbles, through the real Roblox prompt); the lobby boards fill (published ordered stores).
5. **Maturity & Compliance questionnaire**: done on the Creator Hub side per the creator; it must cover every question (required for Kids & Select).

Already fine for the test: all remotes validated and rate-limited, purchases idempotent with limits before the prompt, ProfileStore session locking and reconcile, dev hooks Studio-only, both two-client harnesses and a 74-round bot session clean.

**Know before Saturday:**

- Until the game passes **Kids & Select** eligibility, only age-checked players **16 and older** can play it. Start the creator steps now (verification, 2-step verification, Plus/Premium or the refundable fee, full questionnaire).
- Creator decisions, not blockers: the TOP SUPPORTERS boards vs GAME_DESIGN §10, and the client-judged Perfect release (§1).
- Server size 16, Console and VR off for now, private servers off (§6).
