# Morning handoff — 2026-10-14

Work is continuing through the overnight backlog. This file is updated at each completed step.

## Your actions, in order

1. Publish from Studio after the implementation checks below are complete. Nothing is published automatically.
2. On your real phone, start Arena 1, drag to the gold aim band, lock, watch powers and the final shatter. Repeat a few times and check readability, sound and frame rate.
3. Asset imports and any required IDs will be listed here as they become ready.

## Progress

- F1 implementation and satisfaction pass complete: 60 Hz spherical motion, auto powers, networking/interpolation, aim/LOCK, HUD, cracks and shatter. **55 Lune/Studio tests pass.** Final ten-round watch: no Output errors, including a double KO. See [F1 report](../testing/F1_FIGHT.md) and its four screenshots. Studio reset to the default viewport after the phone test. Real-phone check remains unticked.
- F2–F4, UI-wide pass and Blender exports: pending.

## Calibration for Claude

80 actual-integrator rounds, seeds 101–180: 0 timeouts, 0.461 hits/s (one every 2.17 s), 36.7% pass-bys; encounter interval 1.372 s. Median hit speed 20.67 studs/s (P10 7.22, P90 29.45). ShareA median .499 (P10 .290, P90 .680). Median round 32.56 s (P10 18.69, P90 45.58). Beam landed 32/43 (74.4%), Freeze 34/56 (60.7%); combined 66.7%. Maximum string-radius error .0000015 studs. Raw report: `docs/testing/F1_calibration_draft.json`.

Candidate SimModel: HitInterval=1.37, SpeedAtAmplitude=24.5, SpeedSpread=.67, ShareSpread=.245, MissChance=.367. Applying these caused **2 balance failures**: Jam mirror 45.882 s (max 45); Prism Blade equal-stat win rate 63% (max 62%). Candidate simulator report is `docs/testing/F1_balance.txt`. Baseline SimModel was restored so the repo remains green. **No Fight or Powers values were retuned.** Claude should review the candidate together with RefSpeed≈20.7 and measured aimed-power rates; then re-run tests and simulators.

## Constraints

- Real-phone approval remains yours. No publishing, paid features, new plugins, or unrelated world edits.
- Balance.Fight and Powers are frozen under the overnight instructions. Calibration measurements will be recorded without changing their rules.
