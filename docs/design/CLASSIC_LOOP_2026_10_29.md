# Glass vs Glass: classic loop

Creator-approved direction, October 29: aiming and automatic glassy powers; remove CAST, PUSH and the arena event layer from active play. Implementation is an initial retention rebuild, not evidence of a retention lift.

## Diagnosis and priorities

The supplied funnel has 826 Joined, 666 first matches started (80.6%), 336 first-prize collections, 187 second starts (55.7% of prize collectors) and 123 second finishes (14.9% of Joined). The largest clearly interpretable transition loss is prize to replay. First Match Won mixes winning with progression/backfilled events; older second-finish tracking accepted forfeits. Dates, build mix, acquisition source and D1 denominator are unknown. Approximately four-minute sessions, zero retention and no purchases are creator reports, not independently verified dashboard cohorts.

The previous design added controls and modifiers to address quiet combat, but activity is not the same as an understandable or enjoyable duel. Priorities are a quick first shatter, visible glassy identity, a useful unlock and a reason to try another match. Retain the existing map and stained-glass UI while testing these changes. Research and monetization audit: [research](../research/CORE_LOOP_RESEARCH_2026_10_29.md).

## Implemented loop

1. Open the existing three free welcome glassies. Collecting them secures the existing Day 1 calendar reward without another modal; duplicate/reconnect claims remain idempotent.
2. PLAY still prefers real players. If nobody joins, the assisted Rookie Bot introduction ends after one shatter; PvP and subsequent normal matches keep three hearts.
3. Pick a glassy; drag and release to lock aim, or use keyboard/controller and LOCK. Timeouts safely choose/aim. First tutorial pick is eight seconds; the override cannot extend every later round. Normal setup is shorter and preserves previous choices.
4. Unique signature powers fire automatically. No manual CAST, PUSH, glints, Heat UI, random twists, bumpers or Last Glass bonuses. Existing feature code remains recoverable but is inactive and stale remote inputs are rejected server-side.
5. Watch the larger combat view, stable screen HP/hearts, readable glassy names, cracks and shatter. Keep the approved effects and original roster.
6. Claim the first-clash reward. The next hand includes that owned glassy as its first/default card, alongside two other owned choices. This does not spend the existing free pick-any. The offer survives reconnects/aborts until a naturally finished subsequent match.
7. One primary PLAY AGAIN prompt shows the new glassy, coins toward the next Kiln open, and the existing Day 2 Epic Whiskers return goal. Controller B dismisses it. PLAY/hint do not duplicate it. The existing Starter popup waits until the new-unlock match is finished; manual offers remain accessible. Paid Daily Glassy is labeled separately from free Daily Rewards.

## Measurement

Keep legacy onboarding step numbers for historical continuity. New server-owned `ClassicMatchV1`, one session ID per match:

| Step | Meaning |
|---|---|
| 1 | Match started |
| 2 | First fight started |
| 3 | First actual shatter resolved |
| 4 | Natural match completion |

Steps are deduplicated and contiguous. Reset/disconnect/forfeit never fill step 4. `ClassicMatchDurationV1` records seconds with mode (IntroBot/Bot/PvP), first/returning and termination reason. `MatchLeft<Phase>` and `PlayAgain` remain. A reset after the authoritative final shatter cannot retroactively forfeit that settled result. Studio prints diagnostics; production analytics require published servers.

## Validation and next decisions

Automated rules and Studio checks are necessary, but do not measure fun. See the [integration report](../testing/CLASSIC_INTEGRATION_2026_10_29.md) and [balance report](../testing/CLASSIC_BALANCE_2026_10_29.md).

Before increasing acquisition spend, observe unfamiliar phone players: can they explain the pick/release, distinguish their glassy's power, identify who won, and voluntarily try the new prize? Suggested internal targets, not industry benchmarks: first smash within 60 seconds of a cold join; prize-to-replay above 65% versus this cohort's 55.7%; natural second completion above the correctly measured new baseline. Segment bot/PvP and acquisition source; evaluate comparable cohorts after the new published version, then D1 after cohorts mature. Do not compare an assisted one-round win directly with full PvP duration.

Next experiments: clearer visible power payoffs, a faster repeat-round choice, and first-session unlock pacing. Rebuild navigation only if players cannot find PLAY/arenas. Review pending external purchases before advertising Store-tab products. No new paid feature, currency reset, paid odds change, copied competitor art, or popularity claim is part of this pass.
