# Glass Clash — Live-ops plan (launch → winter event)

Written Oct 21, 2026 · Claude · **status: Proposed. A plan only; nothing in it is built, and no game code or config changes with it.** The creator: "Lets make a plan, not act on it yet."

Builds on decisions 86 (rarity edge), 87 and 88 (roster grows from 36 to 50 in **Saturday** drops, "no simplified fallback powers", Kiln rarity odds unchanged), 94 (24 flyers and 24 finishers), 95, 115–117, and on [ROSTER_V2](ROSTER_V2.md), [COSMETICS_V2](COSMETICS_V2.md), [POWER_BRAINSTORM_24](POWER_BRAINSTORM_24.md) and [MONETIZATION](MONETIZATION.md).

**Calendar anchor.** Today is Wed Oct 21. Group test Thu Oct 22. **Launch Sat Oct 24.** Saturdays after launch: Oct 31 (Halloween), Nov 7, 14, 21, 28 (Thanksgiving weekend), Dec 5, Dec 12 (winter event). That is 7 drop Saturdays after launch.

## 0. The short version

- **Keep the weekly Saturday drop through Nov 28**, which gets the roster to exactly 50 in five drops (3, 3, 3, 4, 1 glassies), each with up to 3 flyers and 3 finishers. After Dec 12, drop to every second Saturday plus one event per 6-8 weeks.
- **The thing that is scarce is not model-building, it is the creator's review-publish-community loop.** Recent builds took 30-45 minutes per glassy when Claude builds headless (§3). A drop's fixed human steps (feel check, save place, publish, posts, hotfixes) cost the same whether it holds 1 item or 9. So every drop has a **Floor** (a smaller version that still ships) and a **Target**.
- **The roster, odds and economy stay as decided.** New glassies join the Kiln, the Daily Glassy and the daily store automatically through `ReleaseRoster`; no new developer products are needed per drop (they are keyed by rarity, not by item).
- **Decisions the creator needs to make are in §8** (12 short items).

## 1. Research (what the evidence says, and what it doesn't)

The creator wanted proven methods. Honest summary first: **Roblox publishes no number for "update-day spike" and no "Updated" sort.** The Creator Docs discovery page lists the signals and says updates are one of the things that move them, and nothing more. Third-party "40-60% higher CCU for weekly updaters" claims (RoLearn and the SEO "UPD" pages) cite no data and are **not used here**.

### 1.1 How Roblox discovery treats updates (primary sources)

| Finding | Source |
|---|---|
| Home "Recommended for You" ranks on **per-user averages**: play days per user, playtime per user, play-through rate, first-play bounce rate (negative), qualified sessions, spend days, Robux per user. Only players who arrived *from* Recommended count. | [Creator Docs: Discovery](https://create.roblox.com/docs/en-us/discovery) |
| "Updates to your game" is named as one thing creators do that moves those signals. After a content update brings a burst of new users, Roblox *explores* which users suit the game; if that cohort engages and spends well it keeps recommending to similar users. | same |
| **Traffic peaks on Saturday** and dips on weekdays; summer, back-to-school and holidays shift it. | same, and the [Aug 6 2026 DevForum post by Roblox's Chief Growth Officer](https://devforum.roblox.com/t/boost-your-discovery-by-building-games-people-want-to-play/4779042) |
| Since **June 15 2026** the signals use a **28-day window** with three retention windows: Day 1, Day 2-7, Day 8-28. So the weeks *after* a player arrives matter, not just the first session. | [DevForum announcement (BurningEmbar, Jun 15 2026)](https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575) |
| "Retention is the foundation." Monetization helps discovery only alongside retention. No fixed update cadence is given; the advice is ongoing content and "new reasons to return". | Aug 6 2026 DevForum post (above) |
| Distribution also moves with Roblox's own algorithm changes, total Home traffic, and how well competing games engage. So a flat week can be the platform, not you. | Jun 15 DevForum post and Discovery doc |

**Implication for us:** a Saturday drop lands on the biggest traffic day, and what it must produce is *return visits for 28 days*, not one spike. The things that buy return visits are the ones we already have (Daily Rewards, playtime gifts, daily store, collection chase). Drops feed the *collection chase*; they don't replace the habit loops.

### 1.2 How often to update (Roblox's own number, plus what top games do)

- **Roblox's retention guide**, in its Day-30 section, calls a common frequency smaller updates to existing mechanics every **2-4 weeks** and bigger feature updates every **2-3 months**. It also says to measure events through **weekly new-user cohorts** (e.g. "are users who joined during a big event sticking around longer?"). [Creator Docs: Retention](https://create.roblox.com/docs/en-us/production/analytics/retention). It also notes a dip in D1/D7/D30 right after a big influx of new users is "typical and temporary", so don't read launch-week retention as a verdict.
- **Weekly is what the biggest collector games do, with teams.** Grow a Garden ships **every Saturday** (new pets, seeds, mutations) at a fixed time, 7 am PT / 10 am ET ([PCGamesN schedule](https://www.pcgamesn.com/grow-a-garden/update-schedule)). Adopt Me ships weekly on Fridays and runs themed events of 4-5 weeks that drip new content weekly, with a "limited pets are leaving" warning in the last week (aggregator sources, lower reliability: [Sugarfest / Summer Camp schedule](https://stealthygaming.com/adopt-me-new-update-april-2026/)).
- **Our closest competitor** Ball VS Ball did about 8 code-numbered updates in about 8 weeks, each with a 100-coin code, and the code-listing sites (PCGamesN, Beebom and others) wrote up each one, which is free press ([research brief](../research/BALL_VS_BALL.md), lines 77-78, 89).
- **GameAnalytics' 2025 Roblox report** measures no live-ops effect, but it does recommend "regular content, events, and meta-layer updates" to hold engagement, and credits the 2025 rise in return frequency to daily quests, time-gated rewards, rotating shops and idle progression (we have all four). Benchmarks to compare against: median Day-1 retention 10-11% for games with 13+ minute sessions, Day-7 about 1-2%, Day-30 about 0.3-0.5%, with the best 10% at 15-19% / 3-6% / 1-1.5%. [GameAnalytics 2025 Roblox report](https://www.gameanalytics.com/reports/2025-roblox-report)

### 1.3 Roblox's own promotion tools (free, and they fit the drop rhythm)

- **Events & Updates** (Creator Dashboard > Engagement). **Events:** title, subtitle, start/end, place; up to **10 ongoing or upcoming** at once; players press **Notify Me** and get an inbox notification when it starts; a public event is shown on the experience page the moment it is created; a custom event thumbnail is recommended. **Updates:** 60 characters, **one per three days**, only to players who opted in. [Creator Docs: Events and updates](https://create.roblox.com/docs/en-us/production/promotion/experience-events)
- **Trending Events** needs an event that started within 7 days, **1,000+ RSVPs** and public visibility. **Off-platform featuring** (Roblox's own marketing) is by application **at least 7 days before the start**, and the creator must be 13+ with a linked email. Same doc.
- **Notifications reach few kids.** Roblox's Creator Hub pages say experience notifications go to opted-in players **13 and over** (as read from search summaries of the notification pages; I did not confirm the exact under-13 wording; check the dashboard). Our audience is "mostly kids", so **the in-game announcement (a What's New card at join) matters more than any push**. Discord is 13+, so it can't be the only channel either; the Roblox group wall and Events page are the all-ages ones.
- **Codes** are the ecosystem standard: players find them on the game page, the group, Discord and YouTube, and they expire (low-quality sources, but consistent with Ball VS Ball above). Our `Config/Retention.Codes` already supports `Starts` and `Expires` and every reward kind.

### 1.4 How much a solo creator can sustain

- Roblox's own guidance is **2-4 weeks** for small updates, and weekly appears only for teams (RoLearn suggests weekly only for "one experienced solo developer", with a backlog banked for low-energy weeks; it cites no data, so treat it as opinion). [RoLearn: update cadence](https://rolearn.dev/guidance/update-cadence-content-planning)
- **Balatro's solo developer** delayed a promised update and said announcing a date at all was a mistake, after burning out post-launch. Lesson used below: announce a *rhythm and a theme*, never a content list or a date for a specific item. [PocketGamer.biz](http://www.pocketgamer.biz/localthunk-delays-balatro-update-to-avoid-crunch-and-burnout/)
- The weekly rhythm is **the creator's choice (decision 87/88) and matches the biggest traffic day**; the evidence only says it is *more* than Roblox's own example. That is why the plan has a Floor for every drop (§2), a quiet week (Dec 5), and a slower steady state after the roster reaches 50.

## 2. The calendar: 8 Saturdays, week by week

**How to read it.** *Target* is the full drop. *Floor* is what ships if the week goes badly (a launch hotfix, a sick day, a kit that won't tune). *Bench* is what slides to the next free slot. Nothing ships below the quality bar of decision 88: **no placeholder or simplified-power versions; an item that isn't ready moves to a later drop.**

Glassy picks follow ROSTER_V2's themes, reordered by **engineering readiness** (the new rule each kit needs is in the "Needs" column; existing shapes first). Type tally and rarity are in brackets. All 14 cards already exist in [ROSTER_V2 §4](ROSTER_V2.md); cosmetics are in [COSMETICS_V2 §1.5](COSMETICS_V2.md).

| Sat | Theme / event | New glassies (Target) | Flyers · Finishers (Target) | Floor | Code | Kiln / daily store |
|---|---|---|---|---|---|---|
| **Oct 24 — LAUNCH** | Halloween window opens | none. 36 + Hollowlight + the three exclusives (Whiskers, Midnight daily; Sunny with the Starter Pack) are live | 12 flyers · 13 finishers live (including Moonlantern and Lantern Eclipse) | n/a | `RELEASE` (300 coins), `HALLOWEEN` (Finisher crate, ends Sat Nov 7, 6 PM CST) | Hollowlight Collection 699 R$ (no end date is set in config yet, #12). Kiln 36 glassies. |
| **Oct 31 — W1 Kitchen & Sweets** (Halloween day) | Last week of the Halloween window; "candy night" tie-in for the Lollipop | **Salt Shaker** (C, Sharp), **Cocoa Mug** (C, Heavy), **Glass Lollipop** (E, Fizzy). All existing shapes (volley, guard, pulse + slow). | **Teacup Twirl, Swirl Board, Cupcopter** · **Popcorn, Sundae, Jellyquake** | Lollipop + Salt Shaker + Sundae + Teacup Twirl | `SWEETS`: 1 free Glassy pull | Pool 39 glassies. Lollipop is Epic, so it also enters the Daily Glassy pool. Bench: **Popcorn Jar** (needs `fuse` and the self-damage OK, decision list #5). |
| **Nov 7 — W2 Toy Box** | **Halloween window ends 6 PM CST** (the `HALLOWEEN` code expiry; the Hollowlight sale too if #12 agrees). "Last hours" post on the day. | **Wind-Up Robot** (U, Heavy; boost), **Kaleidoscope** (R, Sharp; reuses Potion's `Cycle`), **Crystal Crown** (L, Sharp; needs `Shots` and the multi-tap answer, #6) | **Top Spinner, Toy Racer, Biplane** · **Boing Box, Origami, Blastoff** | Robot + Kaleidoscope + Boing Box + Top Spinner | `TOYBOX`: 1 free Finisher crate | Pool 42. First new Legendary: Crown. Bench: Crown (then **Glass Bee** takes its slot). |
| **Nov 14 — W3 Sky** | Mid-point check: first 3-week cohort read (§6) | **Icicle** (U, Sharp; projectile), **Glass Bee** (U, Sharp; mark), **Popcorn Jar** (R, Heavy; `fuse`, moved here from W1) | **Sky Kite, Sky Balloon, Sky Castle (L)** · **Cloudburst, Balloons, Aurora** | Icicle + Bee + Cloudburst + Sky Kite | `SKYHIGH`: 200 coins | Pool 45. Sharp would be 15 of 45: run the type check (§5.1). |
| **Nov 21 — W4 Deep Sea** | Biggest cosmetic day: Whalesong + Tidewhale | **Conch Shell** (C, Sharp; stored), **Message in a Bottle** (R, Fizzy; orbit centred on self), **Glass Jellyfish** (E, Fizzy; boost + mitigation), **Tidewhale** (L, Heavy; `Push`) | **Pearl Clam, Sea Turtle, Jelly Glider** · **Splash, Whalesong (L)** | Conch + Message + Splash + Pearl Clam; Tidewhale to W5 | `DEEPSEA`: 1 free Glassy pull | Pool 49. Second new Legendary: Tidewhale. |
| **Nov 28 — W5 "50"** (Thanksgiving weekend) | "Roster complete" milestone and press hook | **Moonmirror Moth** (M, Sharp; the `mimic` rule, the riskiest one, alone in its week) | none. Spare time goes to bench items and the winter build. | Moth slides to Dec 5; nothing else lost | `GLASS50`: 1 free Glassy pull + 300 coins | Pool 50. Fourth Mythic: each Mythic at 0.0625% a pull (§5.2). |
| **Dec 5 — quiet week** | Breather and winter prep. Create the Winter event page on Roblox (needs to be public ≥ 7 days before Dec 12 if applying for off-platform featuring). | none (Moth if it slid) | none | n/a | `WINTERSOON` (small coins) | Snow decor and a "Winter coming" lobby sign. Teaser only. |
| **Dec 12 — Winter event** | Snow globes, ornaments, glass reindeer (ROADMAP "After launch") | **Seasonal set outside the 50** (like Hollowlight): one glassy, one flyer, one finisher | see §2.2 | the glassy + the code + the lobby decor; flyer or finisher can slip a week | `WINTER` | Seasonal bundle (price decision, #9). Ordinary pools unchanged. |

Roster check: 36 → 39 → 42 → 45 → 49 → 50. Flyers: 12 live + 3 + 3 + 3 + 3 = 24. Finishers: 13 live + 3 + 3 + 3 + 2 = 24 (counted as COSMETICS_V2 does; the Daybreak finisher and Dawn Kite are outside the 24, like the other exclusives).

### 2.1 Why this order

- **W1** takes only kits that need **no new rule**, because launch week will also be a hotfix week.
- **Popcorn Jar** (the `fuse` rule plus self-damage that "a kid may feel cheated" by) moves to W3 so it has two weeks of thinking time. Its W1 slot is just a fourth glassy, which is the first thing to cut.
- **Crystal Crown** (a Legendary that needs `Shots` and multi-tap) goes to W2 as a stretch, with Glass Bee as the instant replacement.
- **Moonmirror Moth** is last and alone: it's the only kit whose bugs are open-ended (copying a copy, copying a fuse; ROSTER_V2 risk 6), so its week must have no other new rule in it.
- **Tidewhale** (`Push`) and the three Deep Sea glassies need three small rule extensions in one week. If W3 is tight, move **Message in a Bottle** to W5; it has the lightest story attached.

### 2.2 The Halloween window and the winter event

- **Halloween (Oct 24 - Nov 7).** Everything already exists: Hollowlight, its finisher and flyer, the `HALLOWEEN` code (expires `1794096000` = Sun Nov 8 00:00 UTC, i.e. Sat Nov 7, 6 PM CST) and the 699 R$ bundle. The code has an end date but the **bundle has none in config yet**; without one it would simply stay on sale (#12). Live-ops work is only posts: a launch post, a "Halloween night" post on Oct 31 (the Saturday *is* Halloween), and a "last hours" post on Nov 7. **Nothing new needs building for Halloween.** The Oct 31 drop's sweets theme is the nod.
- **Winter event (Dec 12).** Modelled on how Hollowlight was sold: a **seasonal set outside the 50**, never in the Kiln, crates or daily store, sold as one bundle plus a free code. Proposed content, reusing what exists: **a glass reindeer or snow-globe glassy (Epic)** with its own power, a **sleigh flyer** (an existing riding family), a **snow-globe finisher**, and a lobby re-skin (snow, ornaments on the fences). The Frostglobe and Frost Pop already carry a winter feel, so the set should not fight them. Start building on Nov 28 so Dec 5 is for QA, not for scrambling. The Hollowlight premium pass took a full day across several parallel sessions (decisions 89-92), so **plan 1.5-2 days of Claude time for a premium seasonal set**, not the 85 minutes the Starter Pack set took.
- **Off-platform featuring** needs an application at least 7 days before an event starts; the winter event page should exist (public) by **Dec 5** at the latest.

### 2.3 Daily store, Kiln, crates

- A glassy or cosmetic **enters every pool when its id goes into `ReleaseRoster` / the installed catalog**, with no per-drop dashboard work: the Robux products are keyed by `[Category][Rarity][Band]` (`Config/DailyStore`). So a drop is a publish, not a product launch.
- The Daily Glassy (9 R$) draws from the Kiln pool at Rare 60 / Epic 32 / Legendary 6.5 / Mythic 1.5 with odds shown; new Rare+ glassies join it, which is the same dilution as the Kiln (§5.2).
- New cosmetics join the Coin and Marble crate pools. Mythic cosmetics stay Marble-only (decision 95).
- The daily store picks per player, so a new item may never show for a given player that day. To make a drop *visible*, a "New this week" slot would be needed (#8). That is a code change, so it is only a decision for now.

## 3. Production checklist per glassy, with real timings

**What the timings are.** They come from commit times in git and DEVLOG entries, not from timers. A commit time is when a stage was *finished*, several AI sessions worked in parallel on launch day, and creator-only steps (feel check, saving the place) leave no trace. Treat them as order of magnitude.

| Chain | What it included | Elapsed |
|---|---|---|
| **Whiskers + Midnight** (Oct 21) | Research and concepts (18:12), two models with 18-20 shards each, two **new** powers (a new `MarkDamage` rule), bespoke PowerFX and 6 sounds, the rewards system changes, item pictures, upload + install, real-swing tune (19:25) | **about 73 min for 2 glassies, ≈ 35 min each** |
| **Sunny + Daybreak + Dawn Kite** (Oct 21, one Epic glassy, one finisher, one flyer) | Headless Blender builds, bespoke power kit, finisher show with sound cues, flyer with effects and a riding profile, icons, tests, Studio fight, tuning from 39.7% to 51.0% (two number edits) | **about 85 min for 3 items** (start inferred from the previous commit, 19:25, → 20:53) |
| **12 launch glassies** (Oct 19) | Design doc 00:07 → batch 1 at 01:49 → heroes and batches 2-3 by 10:34 → retune passes 1-5 done 11:30 → upload and install 16:08 | **about 16 h wall-clock with up to 9 parallel sessions**; the retune of all 37 took **about 40 min** (10:49-11:30) |
| **7 launch flyers + 7 finishers** (Oct 19) | Installed in three flyer batches 16:35-17:29 and the finishers at 16:53 (the models were built earlier) | **about 1 h to install and fit** |
| **Upload** | Open Cloud uploads of the whole v4 batch (see `docs/art/IMPORT_RUNBOOK.md`) | **15-25 min** for 72 assets; a drop of ~10 items should be under 10 min |

**Checklist for each new glassy** (the order recent work followed). Steps 1-9 are Claude, 10-12 are the creator:

1. **Card.** The design entry already exists for all 14 (ROSTER_V2 §4). Adjust numbers if the kit's first pass fails.
2. **Rule support.** Only if the kit needs a new rule (`fuse`, `Shots`, `mimic`, `Push`, `Cycle`, boost `Mitigation`, orbit `Center`): pure code in `FightRules` / `SignatureTraits` plus Lune tests. Existing-shape kits skip this. This is the step that varies most (Whiskers' `MarkDamage` fit inside the 73 minutes above).
3. **Model.** Headless Blender with the launch builder (`build_launch.py` / `build_daily.py`): v4 glass, body + details + **16-20 shards**, hang point at the origin, the shared icon camera, FBX round-trip validation.
4. **Power in config.** `Balance.CombatRelease.Kits` (the numbers), plus the `Glassies` entry for new ids.
5. **PowerFX + sounds.** Bespoke kit in `Config/PowerVFX` / `CombatKitVisuals` / `PowerAudio` at the rarity tier (Crisp, Rare, Epic, Hero); Ready / cast / armed language shared (decision 90). Legendary and Mythic need the 3-beat treatment.
6. **Motion, geometry, cracks.** `tools/gen_glassy_motion.luau` (GlassyMotion), `ReleaseGeometry`, `ReleaseCrackPaths`.
7. **Upload + install.** `tools/opencloud/upload_assets.py <list>` then `tools/studio/glassy_install_chunk.py --set <name>`; check "verify Ok". **Upload by Wednesday**: asset moderation can lag (Midnight's 1024 px picture was still in moderation at its commit).
8. **Item picture.** `tools/blender/item_icons.py` → `Config/ItemIcons` (512 px, 1024 px for big slots; decision 113). An item without a picture falls back to a live 3D view, so new drops still show.
9. **Real-swing tuning.** `tools/release_matrix.sh` (8 rounds per pair against ~40 kits): **gate = 45-55% at equal stats** (decision 86), then with rarity (~55% for Legendary/Mythic) and with bots casting. Sunny needed two number passes; budget two.
10. **Wire in.** `LoadTiers` (Soon, or Essential if it appears in the first minute), and `ReleaseRoster` (this adds it to the Kiln, daily store and Collection). *Check the Collection / Inventory "Unowned" section shows it dimmed with its power text.*
11. **Tests.** `lune run tools/run_tests` and `RunAll` on the Studio **Play server** (not Edit; stale require cache), then one real bot fight with the new kit, watching its Ready, cast and shatter.
12. **Creator.** Feel check of each new power and flyer, **save the place**, publish.

**Cosmetics.** Flyers: the launch flyer builder + a riding family from `Config/RideFamilies` (handle flyers need `GripL/GripR`), FX, loop sound, Studio fit. Finishers: the `Config/FinisherShows` module kit, a timed show, `FinisherAudio` cues, portrait. Both get icons and a rarity (no config for prices; the product matrix is by rarity).

**A weekly budget to plan with** (estimates from the table, not promises): about 9 items × 35-45 min ≈ 6 h of Claude time, plus 1-3 h for the week's new rule, plus about 3 h of creator time (feel check 30 min, save + publish 30 min, posts and thumbnails 45 min, watching and hotfixes 60+ min).

## 4. Drop-day runbook

Times are Central (the daily reset is 00:00 UTC = 6 PM CST all year, `DailyStore.ResetOffsetSeconds`). Proposed go-live: **Saturday 10:00 AM CST (16:00 UTC)**, the same shape as Grow a Garden's fixed weekend morning slot, so players learn the time. The alternative is the 00:00 UTC rollover (Friday 6 PM CST), where daily store, Daily Rewards and codes flip together (#3).

**Prerequisite, not built yet:** codes already support `Starts`, but a glassy is live only when its id is in `ReleaseRoster`, which needs a publish. A **go-live timestamp on a drop** (the same idea as `Starts`) would let the creator publish on Thursday or Friday and have the drop appear by itself, so the hard moment is a clock, not a publish at 10 AM. This is a small piece of code to write *before* W1 if the creator agrees (#3). Without it, publish Saturday at 09:30 and rehearse once.

| When | Step | Owner |
|---|---|---|
| **Sat, a week before** | Teaser post (the theme and one silhouette, never a list or a date for a specific item). Create the **Event** on the Roblox experience page (Events & Updates) with a thumbnail, so players can press Notify Me. | Creator + Claude drafts |
| **Mon-Tue** | Build (§3 steps 1-6). | Claude |
| **Wed** | Upload assets (moderation lead time), install, item pictures. | Claude, creator starts upload |
| **Thu** | `release_matrix` gate, Lune + `RunAll` on the Play server, a bot fight per new kit. **Creator feel check in the evening.** | Claude, creator |
| **Fri** | Freeze. Save the place; publish (with the go-live timestamp: publish now). Draft posts: group shout, Roblox update line (≤60 characters), a 15-second clip of the best new shatter. Add the week's code to `Config/Retention` (with `Starts`). | Claude, creator |
| **Sat T-60 min** | Final check on the live place: join on a phone, open the Kiln, open a crate, check the code. | Creator |
| **Sat T0** | Drop goes live. Post to the Roblox group wall and the Event/Update. Post the clip. Share the code. | Creator |
| **T0 to T+6 h** | **Watch** (§6): errors, CCU, new-user D1 later. Reply to feedback. If a new kit is plainly broken, **remove its id from `ReleaseRoster`** and publish; owners keep their copies (dormant definitions and ownership are preserved). | Creator, Claude on call |
| **Sun** | Hotfix window. D1 for Saturday's cohort is available Sunday evening. | Both |
| **Mon** | Ten-minute retro: DEVLOG entry, tick the ROADMAP, move bench items, decide next week's Target vs Floor by Tuesday noon. | Claude |

**Rules of the runbook:** (1) one announcement format every week, so players learn it; (2) never announce a specific item more than 3 days ahead; (3) the code is the same size each week (about one Kiln pull) so it never becomes the reason to wait for a drop; (4) a missed Saturday is a post ("one week to polish"), not silence.

## 5. Risks

### 5.1 Power creep (decision 86)

Decision 86 caps the rarity edge at about 55% and tunes every kit to 45-55% at equal stats. The creep vector in a live game is **newer = flashier = stronger**, plus every new kit shifts every old kit's win rate a little.

- **Gate every kit** on `release_matrix` (equal stats, with rarity, with bots casting) before it enters `ReleaseRoster`. No exceptions for "it's a Mythic".
- **Re-run the whole matrix after each drop**, not just the new kits (the full retune of 37 took about 40 min). If an *old* kit leaves 45-55% because of a new one, retune the new kit first.
- Use the **expected-damage budget** in ROSTER_V2 §2; kits that need a new rule (Moth's copy at 80%, Tidewhale's push) are the ones most likely to hide extra value.
- **Type skew:** the last balance sim (the stand-in model, 36 glassies, not the real swing) read Fizzy 46% / Heavy 48% / **Sharp 58%**. Seven of the 14 drops are Sharp. Re-check type win rates on the real swing before W3 and, if Sharp is still high, swap one Sharp drop for a Heavy or Fizzy bench item.
- **Paid power:** none. Payer edge stays tiny (PayerSim: +0.1% to +0.9%, the whale case +3.1%, cap +6.1%) and new drops don't change that because nothing is Robux-only.

### 5.2 Kiln odds dilution (decision 88 keeps rarity odds unchanged)

Rarity odds stay Legendary 1.5% and Mythic 0.25% in total, so each extra Legendary or Mythic makes each one rarer. With about 105 Coin pulls in a player's first 30 days (EconomySim, 40 min a day):

| | per pull | chance to get *that one specific* glassy in 30 days (~105 pulls) |
|---|---|---|
| A specific Legendary today (3 in the pool) | 0.50% | about 41% |
| A specific Legendary at 50 (5 in the pool) | 0.30% | about 27% |
| A specific Mythic today (3) | 0.083% | about 8% |
| A specific Mythic at 50 (4) | 0.0625% | about 6% |

(Computed from the totals above; the odds are per rarity, so any Legendary is still very reachable.) The pyramid stays healthy, but a kid chasing "the whale" will feel it. **Mitigations that don't change odds** (decision 88): (a) the weekly free pull codes; (b) duplicates → stars, which already give a reason to keep pulling; (c) the **Collection completion rewards** (ROADMAP F3: "configured completion rewards pending") so a full set of a theme week pays; (d) a named direct-sale slot for the new week's item in the daily store (#8). A visible "new glassy rate-up" would change odds on a paid random item, which ROSTER_V2 asked the creator about (open question 5); this plan does **not** assume it.

### 5.3 Burnout

- **The evidence of load is in the git log:** launch week's content was built overnight on Oct 19, and the monetization, rewards and daily-store work on Oct 21 ran past 22:00. That worked for launch; it is not a rhythm.
- Mitigations in this plan: the **Floor** for every drop; **Dec 5 is a planned quiet week**; Nov 28 is light; **no dated promises** about specific items (Balatro's lesson); **bank one drop ahead** after W2 so Saturday isn't a Friday-night crunch; weekly retro on Monday, not Sunday; and the post-Dec 12 cadence drops to every second Saturday.
- Warning sign to watch: two Floors in a row means the cadence is too fast, and the next drop should be skipped on purpose, not by accident.

### 5.4 Smaller risks

- **Asset moderation lag** delays a drop; upload by Wednesday and keep the bench ready.
- **Launch-week hotfixes** eat W1: that is why W1 holds only existing-shape kits and has the smallest Floor.
- **Self-damage (Popcorn Jar):** kids may feel cheated by their own kernel; decision #5. `SelfScale` can drop to 0.4.
- **The notification gap:** most of our players are under 13 and can't be pushed to; the in-game What's New card and NEW badges (§7) matter more than any dashboard tool.
- **Free-pull inflation:** one pull a week adds about +5 pulls to a 105-pull month (≈ 5%); run `lune run tools/economy_sim` before the codes go live.
- **Kid-safety:** every new name and model is checked against AGENTS.md (no alcohol, no brands, no gore): "Message in a Bottle" must read as a sea bottle, with no cork-popping or drink reference; "Cocoa Mug", "Salt Shaker", "Popcorn Jar" are fine. Limited sales (Hollowlight, winter) use **real dates only, with no fake countdowns** (already the rule).
- **Roblox disclosure rules** still apply to every paid random item: odds shown before every pull, hidden where `PolicyService` restricts paid random items.

## 6. What to watch after each drop

- **Creator Dashboard:** Analytics > Retention (use the **weekly new-user cohorts** to compare a drop week's cohort against the week before; Roblox's guide says to read events this way); Acquisition > Home Recommendations (impressions and play-through rate move with distribution, which is also affected by Roblox's own changes); Monetization (Starter Pack, Daily Glassy and daily-store conversion); Events (RSVP count).
- **Via the analytics tools in Claude Code** (`query_metric`: `DailyActiveUsers`, `ForwardD1Retention`, `DailyRevenue`, hourly granularity available): a quick hourly read at T+1, T+3 and T+6.
- **In-game:** the onboarding funnel (already logged); per-glassy pick and win rate, which does **not exist yet** (GAME_DESIGN 15b analytics events are still open on the ROADMAP). Without it, the first read on a new kit's balance is from player reports, so do the matrix gate hard.
- **Read the data with the right expectations:** a D1 dip after an influx of new players is typical (Roblox's retention guide), and Roblox says the platform's own algorithm changes also move impressions. Judge a drop on its **28-day cohort**, not on Saturday.
- **Success looks like** (targets, not guarantees, benchmarked to the report above): D1 ≥ 10%, D7 ≥ 2% for new players, a visible Saturday CCU lift that holds on Sunday, and the new glassies appearing in the Collection screens of returning players.

## 7. Things the plan suggests building later (none now)

Listed so the creator can say yes or no; each is small and none touches fights or odds.

1. **Go-live timestamp** on a roster drop (publish early, appear on a clock).
2. **What's New card** at join (the week's theme, three pictures, the code) and **NEW badges** in the Collection, Inventory and Kiln for items less than 7 days old.
3. **Per-glassy analytics** (picked, won, shattered) and a drop-view event, so balance can be read live.
4. **"New this week" daily-store slot** (a named item at its usual price).
5. **Collection milestone rewards** (sets by theme week).

## 8. Decisions the creator needs to make

1. **Cadence.** Weekly Saturdays through Nov 28, then every second Saturday plus an event every 6-8 weeks? (Roblox's own example is every 2-4 weeks; weekly is the top-game norm.) *Recommended: yes.*
2. **Floors.** May a drop ship at its Floor (1-2 glassies and a code) instead of missing a Saturday? *Recommended: yes, and two Floors in a row means skip one on purpose.*
3. **Drop time and mechanism.** Saturday 10:00 AM CST (16:00 UTC) or the 00:00 UTC rollover (Friday 6 PM CST)? And may Claude later add a **go-live timestamp** so drops are published ahead? *Recommended: 10 AM CST and yes.*
4. **Order.** Accept the reorder (W1 three glassies; Popcorn Jar to W3; Moonmirror Moth alone on Nov 28 as the "50" milestone; Sharp swap if the type check says so)?
5. **Popcorn Jar self-damage** for this audience (ROSTER_V2 open question 3).
6. **Crystal Crown multi-tap** (one CAST per gem, or one per Ready) (ROSTER_V2 open question 4).
7. **Kiln dilution.** Keep decision 88 (odds unchanged), plus free-pull codes and Collection set rewards? Or consider anything else later? *Recommended: keep, and add the set rewards.*
8. **A "New this week" named slot** in the daily store, and the NEW badges / What's New card (§7)? *Recommended: yes for both; they are the only way most kids find a drop.*
9. **Winter event scope and price.** One seasonal glassy, one flyer, one finisher, a lobby re-skin, a bundle (Hollowlight sold at 699 R$) and a 2-3 week window, with the build starting Nov 28?
10. **Rest.** Is Dec 5 an official quiet week (no new roster items), and is every-other-Saturday the steady state after Dec 12?
11. **Channels.** Is there a Discord yet (MARKETING_PLAN says to start one)? Discord is 13+, so the plan treats the Roblox group wall, the Events page and the in-game card as the main channels and Discord as the extra. Confirm the group wall is where the weekly posts go.
12. **Hollowlight end date.** Make the 699 R$ Collection end together with the `HALLOWEEN` code (Sun Nov 8 00:00 UTC = Sat Nov 7, 6 PM CST), and does it come back next Halloween only? (A real date, no fake countdown.)

## Sources

- Roblox Creator Docs: [Discovery](https://create.roblox.com/docs/en-us/discovery), [Retention analytics](https://create.roblox.com/docs/en-us/production/analytics/retention), [Experience events and updates](https://create.roblox.com/docs/en-us/production/promotion/experience-events)
- Roblox DevForum: [Recommended For You improvements, 28-day retention (Jun 15 2026)](https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575), [Boost your discovery (Aug 6 2026)](https://devforum.roblox.com/t/boost-your-discovery-by-building-games-people-want-to-play/4779042)
- [GameAnalytics 2025 Roblox report](https://www.gameanalytics.com/reports/2025-roblox-report)
- [PCGamesN: Grow a Garden update schedule](https://www.pcgamesn.com/grow-a-garden/update-schedule); [Adopt Me events (aggregator)](https://stealthygaming.com/adopt-me-new-update-april-2026/)
- [PocketGamer.biz: Balatro solo developer delays an update to avoid crunch](http://www.pocketgamer.biz/localthunk-delays-balatro-update-to-avoid-crunch-and-burnout/)
- [RoLearn: update cadence](https://rolearn.dev/guidance/update-cadence-content-planning) (opinion; its numeric claims are unverified and not used)
- In the repo: [BALL_VS_BALL research](../research/BALL_VS_BALL.md), [MONETIZATION](MONETIZATION.md), [MARKETING_PLAN](../marketing/MARKETING_PLAN.md), [IMPORT_RUNBOOK](../art/IMPORT_RUNBOOK.md), DEVLOG Oct 19-21 and git commit times for the timings in §3.

**Not found:** an official Roblox "Updated" sort or any measured size of an update-day spike (the Discovery doc does not mention either); a measured effect of live-ops cadence in the GameAnalytics report; a Roblox-published recommended cadence for solo creators.
