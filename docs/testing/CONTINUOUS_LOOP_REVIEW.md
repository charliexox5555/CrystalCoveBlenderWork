# Continuous-loop review — private lab, October 29

No publication, saved rewards, new economy, or live-player results. Launch instructions are in [the checkpoint](../design/CORE_LOOP_PROTOTYPES.md).

## What changed in this pass

- Restored existing damage, blocked-damage, powered-clash and status popups. The lab previously passed no HUD to FightScene, silently omitting this feedback. Existing no-announcement-banner policy is preserved; near-pass WHOOSH text is suppressed to avoid repeated non-damage labels.
- Motion and HP now interpolate between snapshots; impact/status/shatter events wait for the drawn fight time. A final snapshot flushes shatter promptly. A new duel clears the old timeline and popups. Added a YOU marker for mirror fights.
- Queued choices still apply only to the following duel. No repeated aiming, replay prompt, result claim, or selection pause was added.

## Baseline pacing sample (before the stage-spacing change)

Reproduce: `lune run tools/loop_lab_report`. Thirty-six deterministic fixtures: each of six glassies versus all six rivals, one fixed seed per rival, default initial aim, isolated 60% HP, existing automatic powers. This is a targeted pacing check, not a balance matrix, device performance benchmark, player preference study, or retention result. Per-glassy win counts are debugging output, not fairness estimates.

| Measure | Median | p90 |
|---|---:|---:|
| Fight simulation time | 12.73 s | 18.02 s |
| First physical contact after launch | 0.51 s | 0.52 s |
| First power release/contact/block | 4.01 s | 7.68 s |

All36 fixtures had a physical contact;34 had a power event before ending. First-power percentiles exclude the two without a power event. Automatic transition is configured at1.25s; initial selection/aim time and network/render delays are excluded from these simulation timings. Runtime reports now separate wall duration, initial setup, simulated fight length and first impact/power times.

**Baseline pacing problem, addressed in the current private stage:** Cup vs Ketchup (seed291029) reached40.01s with4 contacts; the reverse took35.84s/9 contacts. Current7.5-stud hook spacing brings those exact fixtures to9.75s/10.04s with7 contacts each, without a forced finish. [Diagnosis, additional216-fixture check and tradeoffs](CONTINUOUS_CONTACT_PACING.md). Production geometry remains unchanged; some quiet stretches persist.

## Creator review

Try Pop, queue Jam while it fights, then try Prism. Check whether the damage/block/beam payoff explains why you would change glassy, whether the next opponent starts naturally, and whether the brief shatter beat is enough. Revisit the formerly slow Cup/Ketchup fixtures at the current spacing. A shorter fight alone does not establish that the choices are interesting.

## Unfamiliar-player observation

Give only: “Try this glass dueling game. Play however you like; you can stop whenever you want.” Do not explain the powers first or tell the player to stay for three fights. Observe selection, first release, whether they recognize their glassy and the winner, spontaneous switching, requests for help, and when/why they stop.

After they stop, ask what their glassy did, why they would choose another, what was confusing or slow, and whether they wanted another fight. Record their actual words and device. Automatic duel count is not voluntary replay. The private lab has no reward loop; report that limitation rather than inferring return motivation or monetization from it.

Before production adoption: physical-phone tests, unfamiliar-player results, creator direction review, then a separate progression/telemetry proposal. New automatic match starts must not be compared directly to the old voluntary Second Match Started funnel.
