# Classic combat balance — October 29, 2026

Status: baseline and bounded retune verified. Do not treat the historical stand-in balance report as release fairness evidence.

## Scope and method

The creator approved aim-and-release with automatic glassy powers, removing manual CAST/PUSH and the extra arena layer. This audit uses the working tree's `Balance.Arena.Enabled=false` and `Balance.CombatRelease.Cast.ManualEnabled=false`.

- Engine: the same deterministic `src/server/Simulation/Pendulum.luau` integrator used by Studio's FightService.
- Full round robin: every release glassy, Hollowlight, the two Daily Rewards glassies and Sunny.
- Mode: `equal:auto`, preserving each glassy's native type/stats and geometry while setting rarity multipliers to 1; both fighters use the live automatic-power Ready delay.
- Eight rounds per pair with alternating sides and deterministic seeds, four bounded Lune processes. This is a broad screening sample, not evidence of exact 50% fairness for every individual matchup.
- Target: identify clear field-wide outliers. Do not retune a marginal 45–55% miss on this sample alone.
- No physics, damage formula, rarity edge, economy, acquisition or Studio changes belong to this audit.

Reproduce baseline (four concurrent processes, one command per shard):

```powershell
lune run tools/release_matrix 0 4 8 equal:auto docs/testing/classic_balance_2026_10_29/baseline/shard_0.json
lune run tools/release_matrix 1 4 8 equal:auto docs/testing/classic_balance_2026_10_29/baseline/shard_1.json
lune run tools/release_matrix 2 4 8 equal:auto docs/testing/classic_balance_2026_10_29/baseline/shard_2.json
lune run tools/release_matrix 3 4 8 equal:auto docs/testing/classic_balance_2026_10_29/baseline/shard_3.json
lune run tools/release_matrix_report docs/testing/classic_balance_2026_10_29/baseline
```

## Measurement caveats found

1. `FightModel` rolls synthetic contacts and attack `LandChance` instead of resolving attack geometry. Its power rankings are not a substitute for the real pendulum matrix.
2. `tools/pacing_report` and `Calibration.round` currently omit `CastPolicy`. `SignatureRules` retains an immediate-cast path for those older fixtures; live player/bot policies become `auto` and wait `Cast.AutoSeconds` (1.6 seconds). Their pacing samples are therefore not exactly live-style auto samples.
3. `tools/pacing_report` currently prints its timeout percentage using a hard-coded zero expression. The matrix derives timeouts from `Fight.Reason == "Timeout"` and is the valid timeout measurement here.
4. Equal mode means equal rarity/star contribution, not identical silhouettes, types or kit triggers. The installed geometry and kit identities remain the game being tested.
5. A field-wide average can hide hard counters. Eight rounds against one opponent are too few to conclude a specific counter is unfair.

## Results

| Sample | Rounds | Mean fight | Timeouts | Fairness result |
|---|---:|---:|---:|---|
| Full baseline, 8 per pair | 6,240 | 20.9 s | 2.3% | 31/40 in 45–55%; range 42.3–59.0%; n=312 per glassy |
| Hot Sauce/Prism Blade baseline subset | 616 | 26.9 s | 18.7% | Hot Sauce 59.0%, Prism Blade 58.0% |
| Retuned two-kit focus, 16 per pair | 1,232 | 27.4 s | 22.2% | Hot Sauce 49.4%, Prism Blade 53.0%; n=624 each |

One damped step from the existing tuner changed only two kit numbers:

- Hot Sauce `ContactBonus`: **0.507 → 0.389**.
- Prism Blade `Damage`: **0.378 → 0.298**.

The follow-up sample places both in the target band. No other kit number changed in this audit. Baseline lows (Water Jug 42.3%, Whiskers 42.9%, Phoenix/Duck 43.6%, Tumbler 44.2%) were left alone to avoid tuning every marginal miss on n=312 screening samples. A proportion near 50% at n=312 has an illustrative 95% sampling interval of roughly ±5.5 percentage points; the field is structured, so this is not a confidence claim about human play.

The focus benchmark renumbers filtered pairs and therefore changes their deterministic seeds. This is a fresh screening comparison, not a paired-seed causal estimate. **The final full roster matrix has not been rerun**; do not call the final build 40/40 balanced.

The high timeout rate is concentrated in these two kits' matchups even before tuning. Investigate those encounters before further damage nerfs: the full-field baseline timeout rate was only 2.3%. Reducing their power further to fix fairness can make those fights slower. There is no evidence here that adding CAST, PUSH or random arena clutter would improve enjoyment.

An additional live-auto pacing probe (108 release-roster rounds, before the two nerfs) measured mean **22.0 s**, median **21.4 s**, p90 **28.5 s**, **0.478 contacts/s**, **3/108 timeouts**, first contact median **0.47 s** / p90 **0.50 s**. Its event-based quiet-time proxy was **14.5%**, longest quiet median **4.5 s**, p90 **6.7 s**. These are simulation observations, not satisfaction or retention measurements. Studio first-session timing is the stronger check of actual onboarding pacing.

## Artifacts and follow-up

- [Full baseline report](classic_balance_2026_10_29/baseline/report.txt), with four raw `shard_*.json` files beside it.
- [Two-kit focus report](classic_balance_2026_10_29/focus/report.txt), with four raw shards beside it. Its last `2/40` display comes from the report tool's all-roster denominator; only two kits were requested for display.
- [Live-auto pacing sample](classic_balance_2026_10_29/pacing_auto_baseline.json).
- Reproduce focus by changing each matrix command above to `16 equal:auto .../focus/shard_N.json "" hot_sauce,prism_blade`.
- Main agent owns final Studio sync, regression tests, required balance/economy simulator summaries and commit. No Studio edits, economy changes or library additions by this audit.
- Remaining meaningful balance work: a fresh full matrix; then investigate timeout-heavy Hot Sauce/Prism Blade encounters, followed by unfamiliar-player mobile testing. Do not optimize kit win rates at the cost of an unreadably slow core loop.
