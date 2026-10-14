# SimModel calibration review — 2026-10-14 (Claude)

**Result:** the F1 candidate's two failures were **model artifacts, not game problems**. Measured directly on the real server swing (the same `Pendulum` integrator the live game runs), Jam mirrors last 33–35 s (target 15–45 s) and Prism Blade wins 55% at equal stats (target 38–62%). The stand-in `FightModel` was wrong because it treated every glassy's pass-by rate as the same. A size- and slow-aware model, fitted to real-swing data, now matches the game much better, and all 76 tests pass honestly. **No Fight, Powers, rarity or economy value changed.**

## What was wrong

`FightModel` (used by the balance tests and `balance_sim`) used one flat `MissChance` for every pair. On the real swing, pass-bys depend strongly on the glassies:

- **Size:** pass-by share falls from ~0.58 for the slimmest glassies (radius 0.5) to ~0.20 for the widest (radius 1.0). Wide jars like Jam collide on most encounters.
- **Slowed swings:** Sticky glassies (Honey Bear 0.03, Pickle Jar 0.05, Ketchup 0.13) and Freeze glassies hang close together and rarely pass each other.
- The encounter interval itself is fairly constant (1.24–1.40 s; Sticky slightly longer).

Raw per-glassy data: [real_mirrors_by_glassy.json](calibration/real_mirrors_by_glassy.json) (31 mirrors × 30 rounds).

So the flat model under-counted Jam's hits and stretched its rounds (baseline 44 s, candidate 46 s, real 33–35 s), and it mis-rated small Sharp glassies like Prism Blade.

## The change (test/simulator model only)

`FightModel` now computes the pass-by chance from the pair's collision radii and how much their swings are currently slowed (only when `Balance.SimModel.MissAtRadius` is set; otherwise the old flat behaviour remains). The parameters come from a fit to the real swing ([sweep](calibration/simmodel_fit_sweep.json), `tools/calibration_sweep.luau`), not from the tests:

| SimModel | Before | After |
|---|---|---|
| HitInterval | 1.2 | 1.3 (measured 1.24–1.40 s) |
| SpeedAtAmplitude | 22 | 27 |
| SpeedSpread | 0.55 | 0.67 |
| ShareSpread | 0.35 | 0.245 |
| MissChance (flat) | 0.30 | 0.367 (fallback only) |
| MissAtRadius / MissPerRadius / MissSlowExponent | — | 0.6 / 0.38 / 2 |

Fit quality against the real swing (mean error over 31 mirrors; starter cross-matchup win rates):

| Model | Round length | Hits per round | Starter win rates |
|---|---|---|---|
| Old baseline | 16.5% | 31.7% | 5.8 pt |
| F1 candidate | 16.3% | 9.5% | 5.8 pt |
| **Adopted fit** | **~11–12%** | **~6–7%** | **~3–7 pt** |

Part of the remaining error is sampling noise (20–30 rounds per target).

## Direct real-swing checks of the test claims

| Claim | Real swing | Fitted model | Old candidate |
|---|---|---|---|
| Jam mirror round length (15–45 s) | 32.9–34.9 s | 36.3 s | 45.9 s ✗ |
| Pop / Prism / Milk / Dragon mirrors | 21.6 / 15.9–17.9 / 30.7–32.4 / 23.0–24.6 s | 24.0 / 19.5 / 32.7 / 23.3 s | — |
| Prism Blade equal-stat win rate (38–62%) | **55.2%** (600 rounds) | 56% | 63% ✗ |
| Glass Sword (model's strongest) | 56.7% (480 rounds) | 59% | — |
| Rocket Pop (model's weakest) | 39.4% (480 rounds) | 41% | — |
| Starter triangle pop>jam / jam>prism / prism>pop | 64% / 75% / 54% | 63% / 67% / 62% | — |

Evidence: [real_vs_model_matchups.json](calibration/real_vs_model_matchups.json), [Prism Blade](calibration/real_fairness_prism_blade.json), [Glass Sword](calibration/real_fairness_glass_sword.json), [Rocket Pop](calibration/real_fairness_rocket_pop.json). Simulator reports with the fitted model: [balance](calibration/balance_fitted.txt), [economy](calibration/economy_fitted.txt).

## Balance notes for the creator (not changed — need your approval)

- **Rocket Pop is near the fairness floor** (real 39.4%, model 41%). The Momentum passive is the weakest in the field (model: momentum 44%, sticky 44%). Rocket Pop, Hot Sauce and Glass Lollipop (Momentum) and the three Sticky glassies trail; Sharp glassies lead (54% as a type). Everything is still inside 38–62%. If you want a tighter spread, a small Momentum buff (e.g. +5% per hit instead of +4%) would be the first lever to try. That is a Powers change, so I have not made it.
- Rocket Pop has no installed art yet, so this has no effect on current play.
- Economy is unchanged: ~3.7 min matches, 4 pulls on day 1 / 96 by day 30, first Rare 47 min / Epic 2.1 h / Legendary 9 h (full-catalog projection; the live Kiln still has only the nine installed glassies).

## Reproduce

```
lune run tools/calibration_by_glassy 30 > byglassy.json
lune run tools/calibration_compare 80 > compare.json
lune run tools/calibration_sweep byglassy.json compare.json 20
lune run tools/calibration_fairness prism_blade 20
lune run tools/run_tests          # 76 passed
lune run tools/balance_sim
lune run tools/economy_sim
```

To revert to the old flat model, remove `MissAtRadius` from `Balance.SimModel` and restore the "Before" column.
