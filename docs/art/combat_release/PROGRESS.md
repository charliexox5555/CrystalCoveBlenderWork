# Combat release production status

Generated from actual package manifests. Blender exports and round-trips do not establish a Roblox import.

| Batch | Glassy | Intact tris | Closed shards | FBX round-trip | Studio import | Live kit |
|---|---|---:|---:|---|---|---|
| A | Pop | 1184 | 16 | Pass | Live / normalized | Enabled; creator review |
| A | Jam | 1000 | 16 | Pass | Live / normalized | Enabled; creator review |
| A | Prism | 288 | 16 | Pass | Live / normalized | Enabled; creator review |
| A | Crescent Axe | 480 | 16 | Pass | Live / normalized | Enabled; creator review |
| A | Briar Flask | 764 | 16 | Pass | Live / normalized | Enabled; creator review |
| A | Arc Coil | 996 | 16 | Pass | Live / normalized | Enabled; creator review |
| B | Milk Bottle | 1096 | 16 | Pass | Live / normalized | Enabled; creator review |
| B | Pickle Jar | 680 | 16 | Pass | Live / normalized | Enabled; creator review |
| B | Ketchup Bottle | 720 | 16 | Pass | Live / normalized | Enabled; creator review |
| B | Glass Cup | 672 | 16 | Pass | Live / normalized | Enabled; creator review |
| B | Water Jug | 904 | 16 | Pass | Live / normalized | Enabled; creator review |
| B | Lemonade Bottle | 788 | 16 | Pass | Live / normalized | Enabled; creator review |
| C | Mason Jar | 1072 | 16 | Pass | Live / normalized | Enabled; creator review |
| C | Hot Sauce | 720 | 16 | Pass | Live / normalized | Enabled; creator review |
| C | Crystal Tumbler | 500 | 16 | Pass | Live / normalized | Enabled; creator review |
| C | Chime | 752 | 16 | Pass | Live / normalized | Enabled; creator review |
| C | Hourglass | 824 | 16 | Pass | Live / normalized | Enabled; creator review |
| C | Frostglobe | 688 | 16 | Pass | Live / normalized | Enabled; creator review |
| D | Prism Blade | 220 | 16 | Pass | Live / normalized | Enabled; creator review |
| D | Rocket Pop | 724 | 16 | Pass | Live / normalized | Enabled; creator review |
| D | Glass Duck | 1232 | 16 | Pass | Live / normalized | Enabled; creator review |
| D | Comet | 556 | 16 | Pass | Live / normalized | Enabled; creator review |
| D | Glass Dragon | 1212 | 16 | Pass | Live / normalized | Enabled; creator review |
| D | Galaxy Orb | 880 | 16 | Pass | Live / normalized | Enabled; creator review |

Exported: **24/24**. Native imported/normalized/live: **24/24**. Signature kits enabled: **24/24**. Original sources and the previous live library are preserved.

[Full integration and creator test guide](../../testing/combat_release/FULL_RELEASE.md): 97 Lune/Studio tests, 264 native Client presentation checks, 48 real deterministic swing rounds and a successful two-client/seven-fight/rejoin/cleanup check. Coin Kiln includes all 21 nonstarters. Numeric HP, fixed camera, pad avatars and baseline finishers remain. Current native art sheet and recoverable live RBXM are linked in the report.

## Remaining creator review

All kits are integrated; subjective visual/audio intensity, actual equal-stat balance tuning, longer performance coverage, phone checks and publishing remain. The simple encounter-based balance stand-in does not model release geometry faithfully; do not treat its rates as final signature balance approval. No ownership migration or paid storefront activation occurred.

## Previews

[Native batch A](../../testing/combat_release/native_batch_A.png) · [Blender batch A](batch_A.png) · [Batch B](batch_B.png) · [Batch C](batch_C.png) · [Batch D](batch_D.png). Blender sheets include genuine 64px samples; before/after sheets use original saved sources.
