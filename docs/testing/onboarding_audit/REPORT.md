# First-session tutorial audit (Oct 21 2026)

Goal (creator): "make sure the player can't stray away from what they want to do and make sure that it is seamless
and keeps on going". Scope: decision 100 / [ONBOARDING.md](../../design/ONBOARDING.md), played in Studio Play as a
new player (every Play is a fresh mock profile), with real clicks (`user_mouse_input`), walking
(`character_navigation`, keyboard W/Space) and the Galaxy A06 phone preset. Fixes are decision 112 (Proposed).

Runs: **A** the code as it was (break attempts), **B** the first fixed build (card, Settings, opening, Daily),
**C** the whole session through the second match, **D** the phone preset plus leave and rejoin, **E** every arena
busy. Captures are numbered in the order they were taken.

## Result

After the fixes, the whole first session runs end to end with no soft-lock, nothing granted twice, and every one
of the 12 funnel steps logged once, in order (server console, run C):

`1 Joined · 2 Welcome Opened · 3 Welcome Collected · 4 Daily Claimed · 5 First Match Started · 6 First Fight Started ·
7 First Round Finished · 8 First Match Won · 9 Win Prize Opened · 10 Win Prize Collected · 11 Second Match Started ·
12 Second Match Finished`

No script errors or `[Onboarding]` warnings in any run. Lune 222/222 (2 new tests).

## Research basis

The fixes follow published first-time-user-experience (FTUE) practice, not guesses. Sources are listed at the end.

| Practice (source) | What we do | Fit |
|---|---|---|
| Get new players to the fun fast, "ideally in 5 minutes or less" (Roblox, *Retention*) | An engaged kid is swinging in their first fight about a minute after joining: card ~5 s, opens ~10 s, Daily ~3 s, beam/PLAY, then pick and aim. The audit removed the places where the flow stopped (Daily lost, card stuck over a match). | Meets it. A kid who touches nothing takes ~5.5 min for the whole match; idea 3 below shortens that. |
| Guide with arrows, beams and highlights; a trail should strongly suggest an action without requiring it (Roblox, *Onboarding techniques*) | Gold chevron beam to the reserved arena, pointers on CLAIM, PLAY and CAST. Walking stays free on the Arena step, and any free arena now counts. | Matches the guidance. |
| Timed hints: show them only to players who need them, only the first time, after a delay found by playtesting (e.g. highlight at 11 s if most find it in 10 s), and tune the delay with Experiments (Roblox, *Onboarding techniques*) | The `Keep()` re-offers fire only for onboarding players, only when they are standing still with nothing open, and the post-tutorial PLAY pulse stops at the next match. | The 6 s delay is a first guess from the timings above. The guidance says to measure it: A/B 6 s vs 10 s (`Balance.Onboarding.IdleNudgeSeconds`) once there is live traffic. |
| Showing beats telling: highlighting "is more effective than describing it in text" (Roblox, *Onboarding techniques*). Children read little (ages 3–5 not at all, then tentatively, then by scanning), skip instruction blocks, like animation, want instant results and leave rather than wait (Nielsen Norman Group, children's UX, 125 children aged 3–12) | Still no hint text: pulses, pointers, beam, a card with one button. The fixes removed waits a kid would leave over (the dead Daily step, a card they could not get past). | Matches. It also supports ideas 2 and 3 (fewer waits). |
| Start gameplay at once; present non-essentials after onboarding and avoid "distracting players from completing onboarding" (Apple, *Onboarding for Games*) | Menus opened mid-step step aside and the step comes back. Trying to play before the welcome opens opens them (they are the player's first hand). | Matches. The welcome card is a one-tap reward, not a gate. |
| One easy first match against bots, then normal play (PUBG Mobile, Naraka; see ONBOARDING.md) | The assisted first match now starts from any free arena and also from the Daily step, so a kid who wanders still gets the easy first win. | Matches. |
| End onboarding with "a moment of joy"; show short-, mid- and long-term goals prominently (Roblox, *Onboarding*). Show the benefit of returning, e.g. daily rewards (Apple) | The "YOU WON!" Kiln open is the moment of joy. Daily Rewards is in the flow, and can no longer be lost. | The short-term goal after the tutorial is thin: idea 1 (Kiln goal badge) fills it. |
| Longer first sessions go with better D1 on Roblox: the median D1 is ~4.3% for 0–3 min sessions and ~11.5% for 19–24 min (GameAnalytics, 2025 Roblox benchmark report) | The PLAY pulse after the win prize pulls into the second match. Ideas 1–2 are aimed at the third. | Direction matches. These figures are correlation, not proof that nudges cause it. |
| Funnel steps are logged from the server, once per player, right after each step. A later step marks skipped ones complete. Fix the biggest drop first. After changing steps, read only dates after the change (Roblox, *Funnel events*) | Unchanged 12 steps, logged server-side, once each (verified). | Side effect of the new Daily rule: a player who skips Daily and plays logs step 5, which marks step 4 "Daily Claimed" as done. Step 4 can now read slightly high. If the creator wants it exact, Daily can move out of the funnel (a new funnel version). |

Where we go further than "suggest, don't require": the claim cards hold walking while they are up. A card is one big button that gives the player something, so holding them for one tap costs little. It also stops the worst case found in run A (a match with the loaner hand and the card stuck on top). Trying to play still works: it opens the claim instead of starting a match.

## Bugs found and fixed

| # | What a kid could do | What happened | Fix |
|---|---|---|---|
| 1 | **Walk away from the welcome card** (keyboard / controller; the card only gated touch) | Walked 42 studs with the card up, queued on a pad and got a normal, **unassisted** match vs "Marble Bot" with the loaner hand. The card stayed on top of the queue and pick screens ([02](02_bug_welcome_card_over_queue.jpg), [03](03_bug_welcome_card_over_pick.jpg)). Their real first match was gone. | The claim card holds walking and jumping while it is up (same Sink binding as a match). **Server:** trying to play (pad, PLAY, hill challenge) while a claim waits opens that claim instead (`OnboardingRules.claimBeforePlay`): at Welcome the 3 opens play ([05](05_pad_at_welcome_opens_claim.jpg)), at Win the prize opens. |
| 2 | **Close Daily Rewards without claiming** | Nothing ever offered it again: no beam, no pointer, the tutorial stopped at step Daily for good. | Daily re-opens (with its pointer) after 6 s standing still in the lobby. Checked: closed at 125.8 s, back at 131.8 s. |
| 3 | **Skip Daily and walk to a pad anyway** | Normal unassisted bot match; tutorial still stuck at Daily. | A solo bot match from Daily is the assisted first match too (`OnboardingRules.isFirstMatch`); Daily stays claimable from the gift button. |
| 4 | **Open Settings (or any top-bar menu) during the 3-reel opening** | The menu destroyed the opening; `Revealing` stayed set, so Daily was never offered and the funnel's "Collected" never fired (found by reading the code). | The opening is tracked; if something takes it off screen before COLLECT, it plays again once the lobby is free ([07](07_welcome_collect.jpg) is a replay), and a second loss just finishes it. |
| 5 | **Open Settings over the welcome / win card** | The card stayed on top of Settings (DisplayOrder 40 vs 20), and closing Settings gave the HUD and touch controls back under the card. | The card steps aside while a menu is open and comes back when it closes (checked: 37.4 s hidden, 43.4 s back). |
| 6 | **Walk to a different arena than the reserved one** | Worked, but the bot took the normal 10 s and the reserved arena stayed held. Also the 5 s renewal loop reserved a *second* arena while the player stood queued on the first ("Reserved for…" on two boards). | Any free arena gets the bot at once for a first-match player and the reservation is let go ([10](10_other_arena_rookie_bot_pick.jpg): Rookie Bot in 0.0 s). The renewal skips players who are queued or in a match. |
| 7 | **No free arena when the reservation is made** (all busy) | The beam never appeared later, even after an arena freed up: the pad listener only re-targeted an existing beam. | A new pad starts the beam whenever the lobby is free; with no pad, the idle PLAY pointer leads to "nearest free arena". Checked with every arena running a bot fight: beam off, no stale guide ([18](18_all_arenas_busy_no_beam.jpg)). |
| 8 | **Rejoin in the middle of the first match** | The server set the step back to Arena but published "Match" to the client first, so the client waited on a match that no longer existed: no beam, no pointer. | The attribute is set after the fix-up. Checked with `DataDev "Reload"` mid-match: Match → Arena with a fresh pad. |
| 9 | (fixed during the audit) my first watcher hid the card with `lobby:Close()`, which closed the opening that had just started | Soft-lock, caught in run B, never committed | The card is put away without touching the lobby; the opening owns it. |
| 10 | Welcome card could start under the loading screen | The step attribute can arrive before `ClientLoaded`; the change handler fired early. | Nothing shows until the loading screen has gone (`ready` gate). |
| 11 | (after decision 111) The loading screen now closes at ~4.7 s and the Coin Kiln model loads in the later "Soon" tier | The welcome card could open with an empty Kiln slot | The card first asks the loader for `asset:Kilns` and waits up to 2 s (`Balance.Onboarding.ClaimPreloadSeconds`); the watcher holds off until then. Checked: card with its Kiln at ~5 s of game time ([19](19_card_after_fast_load.jpg)). |

### Checked and fine (no change)

- **Double / triple tap OPEN** (80 ms apart): one `OpenWelcome`, one opening, funnel step 2 once. A tap while the card
  fades does nothing now.
- **Reset character on the Arena step**: beam re-attaches to the new body after respawn (~5 s), PLAY pointer back
  0.5 s later.
- **Leave mid first match**: step back to Arena, fresh reservation, beam on the same tick, PLAY pointer 6 s later;
  no funnel step repeats. The next match is still assisted.
- **Let the pick timer run out, never aim, ignore the CAST pointer**: the whole assisted match plays itself to the
  3-1 win; CAST pointer shown 4 s in round 1 ([11](11_first_fight_idle_player.jpg)).
- **Another player takes the reserved arena**: can't; `ArenaService:Queue` refuses other players while it is held
  (read, not played with two clients).
- **Watching a match on the Arena step**: beam hidden while the fight view is up, PLAY pointer hidden with the HUD.
- **Phone (Galaxy A06, 705x338)**: card, Daily pointer, chevron beam and PLAY pointer all fit and point at the
  right thing ([14](14_phone_welcome.jpg), [15](15_phone_daily_pointer.jpg),
  [16](16_phone_arena_beam_play_pointer.jpg), [17](17_phone_first_pick.jpg)). PLAY on the phone went straight
  into the reserved arena (match 0.2 s later).

### Not covered

- **Controller**: Studio can't fake a pad (injected ButtonA reaches neither GuiService nor CAS, as the input session
  found). By reading: the claim card pushes `GamepadNav` with OPEN first, and the walking hold now covers the stick.
  Needs a real controller.
- **A real rejoin** (leave the game and come back) and a **two-player** "someone else takes the arena": Studio gives a
  fresh profile per Play, so the rejoin was simulated with `DataDev "Reload"`.
- One unexplained moment in run C: the win card opened itself ~65 s after it appeared, with no click from me. The
  server did the right thing (one `OpenWin`, funnel 9 once). It did not happen again in a 75 s idle retry, so it was
  most likely a stray harness input (the test tool moves the real cursor, and an injected ButtonA was still
  pending). Note: under the phone preset the tool's clicks land ~47 px left of the target (harness offset, not
  the game).

## Timings (desktop, run C)

| Moment | Time |
|---|---|
| Play → welcome card | ~4.8 s after the server starts (card waits for the loading screen) |
| OPEN → 3-reel opening done | ~10 s (COLLECT) |
| COLLECT → Daily open with pointer | 0.5 s |
| Claim → Daily closes itself, beam on | 1.6 s |
| Standing still → PLAY pointer | 6 s (new), or 20 s while moving around |
| PLAY / pad → first match | 0.2 s on the reserved pad; now instant on any free pad |
| First match, kid does nothing | ~85 s per round (40 s pick timer + 15 s aim + 4 s countdown + ~20 s fight + 6 s round end), ~5.5 min for 3-1 |
| Match end → "YOU WON!" card | same frame |
| Win COLLECT → PLAY pointer (new) | 6 s standing still |
| PLAY → second match | 15 s (normal "Bot joins in 10s" + countdown) |

## Dead time removed (decision 112, Proposed)

One client watcher, `OnboardingController:Keep()` (every 0.5 s, `Balance.Onboarding.IdleNudgeSeconds = 6`), brings
the step's moment back whenever the lobby is **quiet** (no match, menu, opening, and the character not moving):

- Welcome / Win: the claim card comes back (after a menu, a reset, a lost card).
- Daily: Daily Rewards re-opens with its pointer.
- Arena: the beam is rebuilt when missing; PLAY pulses after 6 s standing still (the 20 s pointer stays for kids
  who wander).
- **After the tutorial**: PLAY pulses for an idle player for up to 3 minutes after the win prize, until a match
  starts ([13](13_done_play_nudge.jpg)). This is the pull into the second match (funnel step 11), which had nothing
  before.

## Bigger ideas for the creator (not built)

1. **One more win = a Kiln open.** In run C the player had 250 coins after the first session and a Kiln open
   costs 300 (a match win pays 100), so one more win pays for one. A small Kiln badge filling up next to the coin counter, which pulses
   and points at the Kiln when it is full, would give a clear, picture-only reason to play a third match.
2. **Faster second match for new players.** The second match waits the normal 10 s for a bot plus the countdown
   (15 s total, the longest wait in the session). For a player's first few matches the bot could join in ~3 s.
3. **Long pick timer in round 1 only.** The 40 s tutorial pick timer applies to all four rounds. A kid who has
   picked once doesn't need it again; 25 s from round 2 would cut up to 45 s of waiting from an idle match.
4. **Turn the camera toward the arena** when the beam appears. After Daily closes the camera can face away from the
   arenas ([09](09_arena_beam_camera_away.jpg)), and the beam then trails off behind the player.
5. **Hide PICK ANY on the first match.** The new player's pick screen shows "PICK ANY · FREE" next to their three
   cards; it opens a whole catalogue and is the one thing on that screen that can lead a kid away.

## Files

- `src/server/Data/OnboardingRules.luau`: `FirstMatchSteps` / `isFirstMatch`, `claimBeforePlay` (+ 2 Lune tests).
- `src/server/Services/OnboardingService.luau`: `BeforePlay`, `IsFirstMatch` from the rule, first match from Daily,
  renewal skips queued players, rejoin attribute order.
- `src/server/Services/ArenaService.luau`, `HillService.luau`: `BeforePlay` before queuing; instant bot on any free
  arena for a first-match player.
- `src/client/Controllers/OnboardingController.luau`: modal claim card (`HideClaim`), `PlayReveal` / `RevealDone`
  (replay), `Keep()` watcher, `ready` gate, Kiln preload before the first card.
- `src/shared/Config/Balance.luau`: `Onboarding.IdleNudgeSeconds`, `KeepCheckSeconds`, `ClaimRetrySeconds`,
  `DoneNudgeSeconds`, `ClaimPreloadSeconds`.

## Sources

- Roblox Creator Docs: [Onboarding](https://create.roblox.com/docs/production/game-design/onboarding), [Onboarding techniques](https://create.roblox.com/docs/production/game-design/onboarding-techniques), [Funnel events](https://create.roblox.com/docs/production/analytics/funnel-events) (`LogOnboardingFunnelStepEvent`), [Retention](https://create.roblox.com/docs/production/analytics/retention)
- Nielsen Norman Group, [Children's UX: Usability Issues in Designing for Young People](https://www.nngroup.com/articles/childrens-websites-usability-issues/)
- Apple Developer, [Onboarding for Games](https://developer.apple.com/app-store/onboarding-for-games/)
- GameAnalytics, [2025 Roblox Benchmark Report](https://www.gameanalytics.com/reports/2025-roblox-report) (D1 by session length)
- First-match bots and win margins: the sources in [ONBOARDING.md](../../design/ONBOARDING.md) (PC Gamer on Naraka, GameSpot on PUBG Mobile, the Flinders near-miss study)
- Not used: I couldn't open the GDC Vault (under maintenance) or find a primary teardown of Adopt Me / Pet Simulator / Grow a Garden onboarding. The search results were player guides, so they are not cited.
