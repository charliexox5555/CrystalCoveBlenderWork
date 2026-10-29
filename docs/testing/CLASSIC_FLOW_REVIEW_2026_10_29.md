# Classic combat flow review — October 29, 2026

Scope: static review of the current working-tree onboarding, replay, match orchestration, analytics and aim controls. Main agent owns Studio playtests and integration. This report does not claim measured retention improvement or independent phone verification.

## Findings acted on

### Day 1 collection could silently fail under the remote rate limit

The initial `OnboardingService:FinishWelcome` implementation called `RetentionService:Request("Daily")` and advanced to Arena whenever the onboarding step remained Daily. The shared claim limiter can reject that request without granting anything. Advancing in that case loses the intended Day 1 reward and can undermine the Day 2 return goal.

Implemented in **RetentionService only**, as assigned by the main agent:

- A private `claim` helper shares the existing Rules.claim → sync → Profile:Save → result-toast path.
- `Request` retains its remote limiter and kind validation. The normal Daily onboarding callback runs after the grant/save request.
- `CompleteWelcomeDaily(player)` is a trusted server method with no remote-selectable bypass argument. It requires the Daily onboarding step, returns true immediately for an already claimed current UTC day, otherwise claims through the same helper and checks the calendar state.
- Calendar duplicate protection remains in `RetentionRules.claimDaily`; no reward amounts, odds, day boundaries or pure rules changed.

Main integration contract: call `CompleteWelcomeDaily`, then advance through `OnboardingService:DailyClaimed` only on true. The latter preserves the legacy funnel event and transition. `Profile:Save` uses the game's established save-request path; this is not a synchronous external persistence acknowledgment.

### Replay now needs a gamepad dismiss action

The updated replay UI pushes a GamepadNav menu with `First = PlayAgainButton`, but the initial implementation has no Close callback. It can therefore trap a controller user on replay until they press it or the 30-second timeout expires. Main agent notified to wire B/back to Controller:Hide, preserving access to inventory and the Kiln.

### A reset after the final authoritative shatter must not rewrite the outcome

Existing behavior: `MatchService:Forfeit` sets `Forfeited` before calling `Runner:Forfeit`, while `Runner:Forfeit` returns if `Match.Over` is already true. A reset/disconnect during the final 4.5-second presentation can therefore retroactively mark an already resolved match as forfeited, suppress XP/progression and classify it as early-ended in the new analytics.

Main agent notified to treat `Match.Over` as settled before recording a new forfeit. Reset during an unresolved fight must still count as an early ending.

## UX corrections recommended

- **First PvP loss copy:** first-time players receive the completion prize after a played-through PvP loss, but the existing claim/reveal says YOU WON. Prefer FIRST CLASH COMPLETE / YOUR FIRST CLASH REWARD. The bot introductory match is assisted; a real-player match is not.
- **Reconnect loading:** a saved ReplayGlassy can activate the new replay prompt before ClientLoaded. Gate replay on loader completion, just as onboarding gates its first card, to avoid premature gamepad menu ownership.
- **Portrait return copy:** the first draft's 67-character Whiskers return sentence is a single line in 70% viewport width. At narrow portrait sizes it is likely too long even at the small-font floor. Prefer `TOMORROW: FREE EPIC WHISKERS`. The enough-coins message can be `KILN OPEN READY!`.
- **Explain the match-length transition:** bot introduction uses one heart; first-ever PvP and normal matches retain three. Keep the compact heart display readable and avoid claiming every newcomer receives a one-round match.
- **Protect the new-glassy promise:** the first prize is seeded into the next hand as an owned FirstOffer. It remains a choice and the normal free pick-any remains available; this makes the reward actionable without inventing an economy grant.

## Analytics assessment

The new `ClassicMatchV1` recurring funnel avoids the legacy win-vs-completion ambiguity:

1. Server match start.
2. First fight starts.
3. First authoritative shatter resolves.
4. Natural match completion.

The helper only accepts the next step per player/entry; later rounds do not duplicate previous steps. This is significant because Roblox backfills omitted earlier funnel steps if a later step is emitted. Early termination must never emit step 4. Server `entry.Id` ties repeated matches to separate traversals, with Bot / IntroBot / PvP and First / Returning segments.

`ClassicMatchDurationV1` uses an entry-local dedupe map, so Died, CharacterRemoving and PlayerRemoving must not produce three ending events for one match. The first observed reason wins. Separate reset/disconnect/forfeit/opponent-left labels are useful, but Studio console traces are code-path validation only; live dashboard verification is still required.

The old onboarding funnel is retained for comparison. Its historical First Match Won and backfilled Daily steps should not be interpreted as a clean natural-completion denominator. No cohort dates, published-build window, acquisition source or retention screenshots were supplied in this session.

## Earliest-loop pacing

Configured idle upper bounds for the new bot introduction, excluding load/reveal/travel: 4-second solo queue + 8-second selection + 6-second aim + 2-second countdown + a fight + 4.5-second result presentation. Picking and releasing early advance setup immediately. With the main agent's initial 21.6-second real-swing average, that is about 46 seconds from queue to result; this is a rough composition of configuration and simulation, **not a measured human median**.

The large improvement is removal of three additional introductory rounds and the calendar modal. A readable physical fight and an immediate use for the first unlock matter more than adding new combat buttons to fill quiet time. Natural player observation should verify that children understand the gold band, release gesture, shattered opponent and next prize without narration.

## Verification and handoff

- RetentionService formatting: `stylua src/server/Services/RetentionService.luau` passed.
- No new pure math or reward logic was added, so no mirrored unit test was introduced. Existing calendar duplicate/day-rollover tests cover Rules.claimDaily; main agent owns the integrated Studio checks.
- Recommended integration cases: unrelated claim consumes the limiter just before welcome COLLECT; duplicate trusted completion; rejoin on Daily after today's reward was claimed; reset during first fight; reset during final finisher; reconnect with saved first-win glassy; controller B on replay; phone landscape and portrait text fit.
- This agent changed only RetentionService and this report. No Studio mutation, commit, publishing or external message was performed.
