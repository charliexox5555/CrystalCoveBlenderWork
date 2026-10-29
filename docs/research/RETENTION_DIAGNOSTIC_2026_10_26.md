# Retention diagnostic — October 26, 2026

Status: diagnostic complete; revamp remains Proposed. No gameplay, config, scene, paid offer or campaign changes.

Full creator report: [Glass_vs_Glass_Diagnostic_Masterplan.md](https://chatgpt.com/library?file_id=libfile_b5744e95e65881918e2659e220f6475a&account_id=personal).

## Evidence

- Supplied funnel: 826 Joined; 666 First Match Started; 639 First Fight Started; 610 First Round Finished; 394 First Match Won; 336 Win Prize Collected; 187 Second Match Started; 123 Second Match Finished.
- First-round-to-next-milestone conversion 64.59% (216 missing); prize-to-second-start 55.65% (149 missing); second-start-to-finish 65.78% (64 missing). Joined-to-second-finish 14.89%.
- Funnel dates/build mix unknown. Do not assume every user experienced decisions 124/125.
- Creator reports approximately 5-minute sessions, near-zero D1 and no revenue; those graphs/denominators were not independently supplied.
- Inspected Glass vs Glass Studio place 129420351303019, reported version 691. Fresh mock profile through first-match prize; PLAY AGAIN shown and a real click queued successfully. Studio returned to Edit.
- Desktop fight view: glassies small relative to frame/environment and PUSH. Test camera/readability before adding effects.
- Tutorial RollSeconds=40 is passed into MatchRunner and reused every round. Picks/aims advance early when ready. Four full-timer tutorial rounds at illustrative 18.4-second fights take about 304 seconds, only ~24% fighting. This is not a measured median.
- Powers already auto-fire after Ready; AutoCast=false shows manual CAST UI. PUSH is separate.
- Existing retention: levels, daily-exclusive Whiskers/Midnight, first-match pull, gifts, replay. First playtime gift is 10 minutes; EconomyModel assumes 40-minute daily sessions. Fresh first-win flow left 300 coins, enough for the 300-coin Kiln.

## Analytics caveats

1. First Match Won explicitly tracks wins, but prize events can backfill after a completed PvP loss; older first-PvP progression had a fixed bug. Not a clean completion/winner count.
2. Second Match Finished can count an in-game forfeit. Separate normal finish, cancel, disconnect, reset and error.
3. Joined is emitted after profile readiness; compare against platform plays/client-ready events.
4. Preserve the old funnel. Version a recurring new-session funnel and stable build/experiment/device/bot-PvP dimensions.

## Proposed next work (decision 126)

- Fast one-round introduction, a loan/default hand, one release gesture.
- Automatic-power presentation; no CAST/PUSH or modifier taxonomy in the intro test.
- Tighter camera, compact HP/hearts, readable cracks and final shatter.
- Single primary reward-to-next-match CTA and short progress goal; avoid duplicate PLAY.
- Present existing Day 2 Whiskers as a specific return promise.
- Audit live offer exposure, eligibility/prices and receipts before adding monetization.
- Keep saved Close Call as provisional ad control; compare one physical-smash challenger with qualified outcomes.
- Observe unfamiliar mobile players, then controlled two-variant rollout. Accepted decisions remain unchanged until creator selection. No deletion or new paid feature.

## Verification

- Lune RunAll: 280 passed, 0 failed. Studio Play RunAll: 280 passed, 0 failed.
- tools/pacing_report 1: 36 simulated rounds; mean 18.2 s, median 17.0, p90 27.1; 0.56 contacts/s, 1.89 events/s, modeled dead air 0%; 8.3 glints and 10.2 pushes/round across both sides. Not a satisfaction measure.
- Studio asset-type warnings for rbxassetid://203785492; literal not found in src. Inspect scene assets separately; no retention-cause claim.
- Documentation only: no Balance/Glassies/Powers change or simulator rerun requirement.
- Git pull failed on .git/FETCH_HEAD permissions; remote verification failed on GitHub DNS. Commit/push blocked.

## Primary sources

- https://create.roblox.com/docs/production/analytics/funnel-events
- https://create.roblox.com/docs/production/analytics/retention
- https://create.roblox.com/docs/production/publishing/thumbnails
- https://create.roblox.com/docs/discovery
- https://create.roblox.com/docs/production/monetization/paid-random-items
- https://create.roblox.com/docs/production/analytics/monetization
- https://www.roblox.com/games/96510596525082/Ball-VS-Ball

