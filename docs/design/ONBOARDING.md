# Onboarding (first session)

October 20, 2026 · **status: Accepted (creator, decision 100); being built.** Light-touch: get a new player from
spawn to their first win in about 3 minutes, teaching by doing, with almost no text.

## Research, in short

- **Roblox's own guidance:** onboarding is judged by Day-1 retention and funnel completion. Teach only the essentials
  (controls and the core loop), reach the fun fast, give players a reason to keep going, and end on a moment of joy
  (reward, animation, effect). Measure every step as a funnel and A/B test variants.
- **Bots for a first win are standard practice** (PUBG Mobile, Naraka, Spellbreak): an easy, confidence-building first
  match. The backlash cases are about bots that feel fake or matches that never stop being easy. So: one assisted match
  that still looks and plays like a real fight, then normal play.
- **Win margin:** a small controlled study found players enjoy **clear wins** more than near misses (near misses felt
  boring and frustrating). A close finish is exciting only if you win it. So the player wins rounds clearly, and the
  tension comes from one lost round, not from scraping by.
- **Gacha onboarding:** beginner banners bound the early luck (a guaranteed good result, no wasted duplicates). Ours: the
  welcome pulls never give a duplicate and are shaped to a fun spread, with **their own odds shown before opening**
  (Roblox requires the real odds of every outcome, summing to 100%; we never show the normal Kiln odds for a shaped pull).

## Creator calls

- **Q1** first match: win **3–1**, the bot takes round 2.
- **Q2** welcome opens: **1 Common, 1 Uncommon, 1 Rare**, one of each type (Heavy, Fizzy, Sharp), never owned.
- **Q3** win open: **Rare 70% / Epic 30%**, never owned.
- **Q4** daily step: the screen **closes by itself** after the claim celebration.

## The flow

| Step | What the player sees | Notes |
|---|---|---|
| 1. Welcome | After the character spawns: a Stained Glass card "Welcome to Glass Clash! Here are **3 free Kiln opens**", the Welcome odds line, and an **OPEN** button | One button, no close. Resumes if they rejoin mid-flow |
| 2. Three pulls | The normal Kiln opening with 3 cards (one shot, same reels/reveal) | 3 new glassies, no duplicates (**Q2**) |
| 3. Daily reward | The Daily Rewards screen opens with a pointer on Day 1's CLAIM | After the claim celebration it closes by itself (**Q4**) |
| 4. Go battle | "Your arena is ready!" A guide beam runs from the player to a **reserved arena** (the nearest free one), whose board reads "RESERVED FOR <name>". Stepping on the pad starts at once against a bot | After 20 s without arriving, the PLAY button pulses with "Press PLAY" (PLAY goes to the reserved arena) |
| 5. First match | A normal match against **"Rookie Bot"**, with a few gentle hints (below) and an assisted outcome (**Q1**) | Their 6 glassies (3 starters + 3 new) form the hand as usual |
| 6. Win | Normal results + coins, then "You won! **Free Kiln open**" → one more opening | New glassy, no duplicate (**Q3**) |
| 7. Free play | Nothing else. The notice dots and the PLAY button carry them on | Onboarding marked done |

**Hints in the first match only** (each shown once, small, near the thing they point at):
- Pick: the selection timer is longer (40 s instead of 25 s) and a soft pulse sits on the cards: "Tap a glassy".
- Aim: the existing "Drag to pull • aim for gold" line, plus a gentle pulse on the gold band.
- CAST: the first time the button lights up, a pointer and "Tap CAST to fire your power!"; the auto-fire window is
  longer that one time.
- Nothing else is new. No text walls, no forced camera tour.

**The assisted match (Q1):** the server plans the round outcomes and nudges the fight to land there without it looking
fake:
- The bot plays like a low-skill bot (no manual casts, loose aim).
- In rounds the player should win, the player's glassy can't drop below 1 HP until the bot shatters, and the bot hits a
  bit softer. In the round the bot should win, the bot hits a bit harder. Overtime still guarantees every round ends.
- Pure presentation stays identical: same physics, hits, powers and finishers.

**Who gets it:** new profiles only. Anyone with a finished match or an earlier welcome pull skips it. Rejoining
resumes at the current step. Each step is logged with `AnalyticsService:LogOnboardingFunnelStepEvent` so the funnel
shows where players drop off. The old one-pull welcome after the first match is replaced by this flow.

## Build outline

- **Data:** `Onboarding = { Step, Done }` in the profile, plus a `Welcome` pull rule (no duplicates, a rarity spread)
  in a pure, Lune-tested module (`OnboardingRules`).
- **Server:** `OnboardingService` drives the steps. Kiln: a welcome opening of 3 through the normal opening, with its
  odds shown. ArenaService: reserve an arena, show "RESERVED" on the board, start at once with "Rookie Bot".
  MatchRunner and FightRules: per-round `Assist` (damage scale and an HP floor), off for every other match.
- **Client:** welcome card, guide beam and PLAY pulse, the three in-match hints, the 3-card opening layout.
- **Tests:** rules (no duplicates, pools, assist math), plus a full Studio run as a fresh profile.

Sources: [Roblox onboarding guide](https://create.roblox.com/docs/production/game-design/onboarding),
[Roblox engagement analytics](https://create.roblox.com/docs/production/analytics/engagement),
[Roblox paid random items policy](https://create.roblox.com/docs/production/monetization/paid-random-items),
[PC Gamer: Naraka bot first match](https://www.pcgamer.com/uk/naraka-bladepoint-bots/),
[GameSpot: PUBG Mobile bots](https://www.gamespot.com/articles/pubg-mobile-heres-why-you-keep-winning-maybe/1100-6457532/),
[Flinders: near miss in a video game](https://researchnow.flinders.edu.au/en/publications/near-miss-in-a-video-game-an-experimental-study/),
[Gacha beginner banner rules (GFL2)](https://www.prydwen.gg/gfl-exilium/guides/gacha-explained).
