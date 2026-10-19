# Release balance report (Oct 19, 2026)

Measured on the **real swing** (`src/server/Simulation/Pendulum.luau`), not the FightModel stand-in, with `tools/release_matrix.sh` (all pairs, sides swapped, moderate-skill bots casting through the CAST system). Each glassy's number is its win rate against the whole field at **equal stats** (rarity multipliers off). Sample: 144 rounds per glassy (±4%).

## Results

| Check | Target | Result |
|---|---|---|
| Every glassy vs the field (37: 24 release + Hollowlight + 12 launch) | 45–55% | 37/37 at or inside (45.8–55.6%) after pass 6 (Piggy Bank 53%, Cookie Jar 50% on a 216-round recheck) |
| Before this week (24 release kits) | — | 29–81% (Briar Flask 81%, Water Jug 80%, Glass Dragon 76%; Pickle Jar 29%) |
| Mythic vs Common at equal kit strength | ≈55% | HP-only rarity curve, Mythic +3% HP (decision 86) |
| 5 stars vs 0 | ≈55% | 54.8% (+0.6% HP per star) |
| Timed CAST vs auto-only, same glassy | 55–62% | 59.5% |
| Press CAST as soon as it lights vs ignore it | ≥ 50% | 52.3% |
| Round length / timeouts | 15–45 s / < 5% | ~28 s / 0% |

Hollowlight (paid seasonal) sits at 50.7%: no paid advantage.

## Notable fixes found by the matrix

- **Zones predicted in a straight line**: Crystal Ball's star landed 3%. Zones now predict with free pendulum motion (`Pendulum.predictCenter`), ~77% land, damage cut to match.
- **CAST hint ignored string twist**: timed Arc Coil rays fired while the string spun them off target (42% landed vs 81% auto). `CastTiming` now reads twist and spin for ray, cone, breath and sweep.
- **Once-a-round low-HP powers were weak**: Milk Bottle, Hot Sauce and Glass Duck now have two or three thresholds.
- **Piggy Bank was capped by its savings limit**, not damage: StoreCap 0.12 → 0.2.

## Re-run

```
tools/release_matrix.sh 4 equal:bot0.5            # all release glassies (+ Hollowlight)
tools/release_matrix.sh 24 mirror:smart:auto      # timed CAST edge
tools/release_matrix.sh 24 stars5:bot0.5          # 5-star edge
```
Pass a comma list of ids as the 3rd argument and focus ids as the 5th to check only some glassies.
