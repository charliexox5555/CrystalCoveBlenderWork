# Combat release production status

Generated from actual package manifests. Blender exports and round-trips do not establish a Roblox import.

| Batch | Glassy | Intact tris | Closed shards | FBX round-trip | Studio import | Live kit |
|---|---|---:|---:|---|---|---|
| A | Pop | 1184 | 16 | Pass | Staged / normalized | Pending |
| A | Jam | 1000 | 16 | Pass | Staged / normalized | Pending |
| A | Prism | 288 | 16 | Pass | Staged / normalized | Pending |
| A | Crescent Axe | 480 | 16 | Pass | Staged / normalized | Pending |
| A | Briar Flask | 764 | 16 | Pass | Staged / normalized | Pending |
| A | Arc Coil | 996 | 16 | Pass | Staged / normalized | Pending |
| B | Milk Bottle | 1096 | 16 | Pass | Staged / normalized | Pending |
| B | Pickle Jar | 680 | 16 | Pass | Staged / normalized | Pending |
| B | Ketchup Bottle | 720 | 16 | Pass | Staged / normalized | Pending |
| B | Glass Cup | 672 | 16 | Pass | Staged / normalized | Pending |
| B | Water Jug | 904 | 16 | Pass | Staged / normalized | Pending |
| B | Lemonade Bottle | 788 | 16 | Pass | Staged / normalized | Pending |
| C | Mason Jar | 1072 | 16 | Pass | Staged / normalized | Pending |
| C | Hot Sauce | 720 | 16 | Pass | Staged / normalized | Pending |
| C | Crystal Tumbler | 500 | 16 | Pass | Staged / normalized | Pending |
| C | Chime | 752 | 16 | Pass | Staged / normalized | Pending |
| C | Hourglass | 824 | 16 | Pass | Staged / normalized | Pending |
| C | Frostglobe | 688 | 16 | Pass | Staged / normalized | Pending |
| D | Prism Blade | 220 | 16 | Pass | Staged / normalized | Pending |
| D | Rocket Pop | 724 | 16 | Pass | Staged / normalized | Pending |
| D | Glass Duck | 1232 | 16 | Pass | Staged / normalized | Pending |
| D | Comet | 556 | 16 | Pass | Staged / normalized | Pending |
| D | Glass Dragon | 1212 | 16 | Pass | Staged / normalized | Pending |
| D | Galaxy Orb | 880 | 16 | Pass | Staged / normalized | Pending |

Exported: **24/24**. Native imported/normalized: **24/24**. Live kits remain pending.

Native VFX follow-up: 24 editable kit template folders, ten shared meshes, six burst templates, four beams and 14 replacement sound cues are saved in `ServerStorage.CombatReleaseStaged.VFX.Combat`; 612 template checks pass. After the creator connected Rojo, first-six rules/client effects were implemented and a native Pop/Axe fight observed. 88 Lune tests pass. [Current checkpoint and creator test](../../testing/combat_release/FIRST_SIX_CHECKPOINT.md). Global signatures remain off; remaining kits/native feel review are pending. New audio is wired into normal playback but has no subjective listening approval.

## Required next gate

Imports are normalized and staged under ServerStorage.CombatReleaseStaged. All 24 native bounds/pivots/part flags and 384 shard origins pass checks; the first six were reviewed at the fixed camera and current sky. The first-six vocabulary is now implemented behind a prototype flag; complete creator/native review, then the remaining 18 kits, asset promotion, real signature calibration and multiplayer/performance checks. Release filtering is staged; installed-art acquisition still uses the original nine-item pool. No inventory migration occurred.

## Previews

[Native batch A](../../testing/combat_release/native_batch_A.png) · [Blender batch A](batch_A.png) · [Batch B](batch_B.png) · [Batch C](batch_C.png) · [Batch D](batch_D.png). Blender sheets include genuine 64px samples; before/after sheets use original saved sources.
