# Private stage contact pacing — October 29

## Change and diagnosis

The private lab now uses **7.5-stud hook spacing**, passed to the existing deterministic Pendulum constructor. Packets carry the actual spacing; the client renders explicit matching hook positions. Production `Balance.Motion.HookGap` remains6, and the production integrator/rules/power stats are unchanged. No forced damage, collision teleport, new ability, re-aim, timer cut-off or claim gate was added.

At six studs, Cup/Ketchup seed291029 had no damaging contact after13.2s and timed out at40.01s. After15s its closest sampled approach was2.609 studs, outside the2.450-stud collision radius; at that point the bodies also had opposite sideways offsets. The reverse fixture had an18.22s contact drought. These are geometric near misses during the real swing, not a missing UI callback. Changing spacing changes encounter timing and avoids these particular locks.

We screened the known cases at4.5/5/5.5/6/6.5/7/7.5 studs and the default-aim roster sample at5/6/7/7.5/8. Narrowing to5 fixed those two examples but created three timeouts elsewhere. Seven studs removed the original timeout but produced new25s+ fights at edge aims. Selected7.5 for the private build after checking additional seeds and aims. This is empirical tuning of six glassies, not a general mathematical guarantee or a full production balance pass.

## Original cases, same seed and default aim

| Fixture | Six studs | 7.5 studs | Longest contact gap, before → after |
|---|---:|---:|---:|
| Cup vs Ketchup,291029 |40.01s, timeout,4 contacts |9.75s, DoubleKO resolution,7 contacts |26.83s →1.73s |
| Ketchup vs Cup,291027 |35.84s, DoubleKO resolution,9 contacts |10.04s, shatter,7 contacts |18.22s →3.09s |

The existing DoubleKO rule leaves the winner at1HP and shatters the loser; it is not a new draw mechanic. Studio actual clicked launches reproduced9.75s/10.04s simulation durations, one launch each. Wall durations also include initial setup. The next duel began automatically; queued Jam switching worked on Galaxy A06 landscape. Rendered anchor span measured7.5 studs and framing was visually checked on desktop/Galaxy emulation.

## Wider checks and tradeoffs

Original36 default-aim fixtures: fight median12.73s →10.12s; p9018.02s →17.20s; timeouts1 →0. First contact median0.51s →0.54s; first power median4.01s →4.21s among fixtures with a power event (34/36 before,35/36 after).

Additional sample: six glassies ×six rivals ×two new seed offsets(6,12) =72 per launch setting,216 per spacing. All other settings unchanged.

| Aim/yaw | Six-stud median / p90 / max | 7.5-stud median / p90 / max |
|---|---|---|
|0.35 /−0.60 |16.50 /20.37 /23.48s |13.08 /17.27 /22.01s |
|0.80 /0 |13.03 /18.44 /40.01s |10.95 /17.72 /21.99s |
|1.25 /0.60 |13.13 /18.59 /23.84s |13.02 /17.14 /22.83s |

Six studs had one timeout and two25s+ fights in this216-fixture sample. At7.5 there were none; the maximum was22.83s. **Not every metric improved:** default-aim p90 of the longest contact gap increased4.85s →6.74s, although its median fell4.76s →3.05s. Some launches still have a noticeable quiet stretch. These samples do not establish roster fairness, voluntary engagement, retention, or behavior at every possible angle/seed. Physical-phone and unfamiliar-player review remain necessary.

## Reproduce without a new audit

```text
lune run tools/loop_lab_contact_probe
lune run tools/loop_lab_report 6
lune run tools/loop_lab_report 7.5
lune run tools/loop_lab_holdout 6
lune run tools/loop_lab_holdout 7.5
```

Probe scripts change hooks only on disposable simulations; they do not mutate production config. Lab test suite contains the two original stall fixtures as a regression. Lune and Studio: **295 passed,0 failed**.

For an actual Studio Cup291029 test, in a fresh Play session set the runtime-only `require(game.ReplicatedStorage.Shared.Config.LoopLab).Seed=291028` before starting the lab server, then choose Cup and release. For Ketchup291027, use the normal seed/default fresh Play session and choose Ketchup. Stop Play clears the override; do not edit the saved seed/source to reproduce it.

Private only. Keep published build unchanged; production adoption needs creator direction review and a broader balance/playability check.
