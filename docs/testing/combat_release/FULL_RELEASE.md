# Full 24-glassy combat integration

All 24 release models and signatures are installed and enabled in normal matches. The Coin Kiln has the 21 nonstarters. No publishing, paid storefront activation or production inventory migration occurred.

Latest update: [stronger power presentation and horizontal camera orbit](SPECTACLE_ORBIT.md). During Fighting, drag/swipe, Q/E or right stick rotates around the arena. Prism Blade now returns its crescent; earlier fixed-camera statements below describe the initial integration checkpoint.

## Try it

Save the Studio place, start Play, and paste `tools/studio/grant_combat_test_inventory.luau` into the **Server Command Bar**. It unlocks missing release glassies without adding duplicates and adds 10,000 test Marbles. It requires the isolated Studio mock profile; live accounts are unaffected.

Use a normal pad match and Pick Any to try your collection. The earlier three prototype-pair commands still work, but are no longer required to enable signatures. For a quick watched matchup, change these two IDs:

```lua
game.ServerStorage.FightDev:Invoke("BotVsBot", "glass_dragon", "galaxy_orb", 2026, true)
```

Run one developer matchup at a time. Stop Play when finished. Pick Any/reroll counters and costs remain unchanged; Marble Kiln/storefront purchases remain disabled.

## Kits

| Glassy | Main action |
|---|---|
| Pop | Three-contact pressure pop |
| Jam | Turnaround lid guard; one body contact |
| Prism | Locked narrow ray |
| Crescent Axe | Charged swept axe; bounded wait for a reachable encounter |
| Briar Flask | Three growing thorns; next-contact burst |
| Arc Coil | Three-contact charge and electrical shot |
| Milk Bottle | One delayed repair below half HP |
| Pickle Jar | Brief brine slow and visible tether |
| Ketchup Bottle | One food-colored blob; pops on the next clash |
| Glass Cup | Brief drive boost and empowered rim clash |
| Water Jug | Stores two received clashes; turnaround splash cone |
| Lemonade Bottle | Three traveling pips with one shared damage budget |
| Mason Jar | Heavy received hit arms one expiring counter |
| Hot Sauce | One low-health heat/drive window |
| Crystal Tumbler | Partial directional catch and bounded return shot; contact fallback |
| Chime | Traveling expanding pulse shell |
| Hourglass | Capped stored damage; frame flip and sand shot |
| Frostglobe | Short frost cone with nonstacking slow |
| Prism Blade | Out-and-back crescent; one shared damage budget |
| Rocket Pop | Capped tangent booster impulse and next-clash payoff |
| Glass Duck | One low-health bubble guard |
| Comet | One star at the contact position; fires at the next turnaround |
| Glass Dragon | Three locked breath pulses sharing one damage budget |
| Galaxy Orb | Short central well, capped tangent influence and closing pulse |

Charge details, windup rings, shots/trails, splash/frost sheets, brine tether, tomato blob, mirror, echo star, booster flames and orbit bands use the original native VFX library. Numeric HP follows the glassies; low HP adds sparse stress dust. Existing impact, crack, shatter, winner flight, avatar impact, hearts and popup outline fades remain. Inventory, collection, Pick Any and hand cards describe the new signatures. No mid-fight controls, banners or camera changes were added.

## Evidence and limits

- **97 Lune and 97 Studio tests pass.** Release suites cover every identity, deterministic swing settlement, stored/threshold effects, misses/replay rejection, reflection exclusion, shared pulse budgets, death cancellation, bounded cone/fan geometry and mid-cast bootstrap data. The previous damage/power/balance tests explicitly preserve legacy-mode regression coverage.
- **264 native Client checks** cover all 24 live models, portraits, cracks, shards, effect timelines and owned cleanup. This is a staged presentation fixture, not subjective approval of every effect at normal speed. Reproduce with `tools/studio/verify_full_release_client.luau` in Play / Client.
- **48 real deterministic swing rounds:** every release kit participates; latest results are in [release_swing_report.json](release_swing_report.json). No timeouts; mean around 29–30 seconds; maximum string-length error below 0.000002 studs. This small sample is not an equal-stat fairness approval. Signature tracking/range and axe anticipation were adjusted from actual geometry rather than guaranteed hits.
- **Two native clients, seven simultaneous fights:** a Dragon/Lemonade round completed; both clients received release/contact facts, rejoined with an active cast bootstrap, and ended with zero errors, fight roots or views. [Result](multiplayer_release.json). Twelve measured render frames per client: focused-view means 0.42/0.85 ms; total seven-view means 1.34/2.15 ms. The short desktop sample and one client's frame stall do not establish low-end-phone performance.
- Required [balance](standin_balance.txt) and [economy](release_economy.txt) simulators were run. The old encounter stand-in cannot model actual attack range, moving targets, apex geometry or well forces; its new-signature field rates diverge substantially from the actual swing and are **not a balance approval**. Final equal-stat matchup tuning, longer performance coverage and real-phone review remain. Economy reports 21 nonstarters, 4/96 day-one/day-30 pulls and 12/18 uniques at day seven/day 30; prices/odds/multipliers were not changed.

The first multiplayer fixture revealed a developer-test collision with the real auto-queue; the fixture now reserves its arenas. It also exposed missing-name handling in the selection UI, which now has safe owner-label fallbacks. The successful rerun above supersedes those failed fixture runs.

## Recoverable assets

- Live: `ReplicatedStorage.Assets.Glassies` (24), `ReplicatedStorage.Assets.VFX.Combat`.
- Previous live assets: `ServerStorage.CombatReleaseBackups.LiveBeforeFullRelease_20261015`. Original Blender sources, raw imports and canonical staged models are preserved.
- [CombatRelease_Live_v2.rbxm](../../../places/CombatRelease_Live_v2.rbxm): 910,340 bytes; SHA-256 `bda86c905c3614094363ab6d944049780b54b1a28afc0643c4876491765ecd18`. Contains the `Glassies` and `Combat` folders beneath `GlassClash_CombatRelease_v2`. Restore those folders to the live targets above; source scripts sync through Rojo.
- Reproducible promotion: `tools/studio/promote_combat_release.luau`; refuses to overwrite the original backup. Original staged/VFX RBXM snapshots remain available.

[Native all-24 art sheet](all_24_native.jpg) shows the installed bodies at full charge against the current sky. It is an isolated art review with staged charge state, not an arena screenshot or effect timing proof.

Studio is left in Edit. Save the place to retain native assets; publishing and hands-on feel/device review remain with the creator.
