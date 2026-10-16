# First-six combat checkpoint

## Creator feedback pass

The creator tested the checkpoint and liked the look, but requested more effects, clearly visible numeric health and a complete floating-text outline fade. This pass adds `123 HP` just beneath each glassy (white, pink at low HP), short fast-swing trails, expanding contact rings/chips, stronger signature charge/release/block bursts, growing pulsing windup rings, ray halos and a clearer axe slash. HP follows snapshot values and disappears when watching stops, on shatter and during the finisher. Both legacy text strokes and authored UIStroke outlines fade with the damage text. Damage, charge cadence, attack volumes and global activation are unchanged.

88 Lune tests and 46 short native Client presentation checks pass. The latter cover the three model pairs, HP visibility/value/low-health styling, charge/windup/ray-halo/miss/lifetime branches, contact rings, watch/shatter/finisher cleanup and actual popup text/outline tween progression. This is an isolated presentation fixture, not a full live-match or performance approval. Reproducible helper: `tools/studio/check_combat_feedback.luau` (Play / Client). Studio returned to Edit; nothing published. Creator reviews the feel using the three existing pair tests below. Remaining 18 kits are the next implementation phase.

## Earlier checkpoint

2026-10-15. The creator reconnected Rojo, then requested lower usage and offered to handle some testing. This checkpoint finishes the current first-six implementation; it does **not** mark the 24-kit release complete.

Implemented in source:

- Pop's third qualifying body contact spends pressure on that clash and increases the legal rebound. Briar grows on three validated turnarounds and spends its next-contact bonus once.
- Jam's second turnaround winds up a two-second, one-contact 40% guard. Ranged damage neither benefits from nor consumes that guard.
- Prism's timed windup and Arc Coil's three-contact windup lock their ray direction at release. Crescent Axe's second turnaround produces a short swept head volume, with relative target motion checked to prevent tunnelling. These attacks resolve once and can miss; their damage never refills body-contact charge.
- FightRules owns HP, charge, mitigation and cast budgets/results. Pendulum supplies 3D turnarounds and geometry. A lethal hit cancels pending offensive casts. Turnarounds reject low-energy jitter, tiny vertical excursions and recent collision reversals.
- Scene-owned client effects use the imported meshes/textures, server release direction/contact points, original animation pivots and revised crack paths. Effect-only axe pieces stay outside intact/shard/portrait meshes. Cast effects/audio have bounded lifetimes and explicit scene/watch cleanup. Winner flight, avatar finisher, camera and heart flow use the existing presentation.
- New sound IDs, measured starts and fades are now wired into ordinary contact/crack/shatter playback. Light/alternate/heavy hits differ; full breaks stay reserved for shattering. Subjective listening remains creator review.
- Six new catalog definitions are stored (37 total, including 13 preserved dormant entries). Explicit release IDs restrict unowned catalog/acquisition to 24/21 nonstarters. Owned dormant entries remain inspectable and are not removed from saved data or owned selection. Current installed live art still yields the existing nine-item Coin pool. No production profile migration or new paid feature.

**Activation:** `Balance.CombatRelease.Enabled = false`. New signatures use the Studio-only prototype route until the first-six checks and later kit expansion are complete. Normal fights retain the old power rules with the refreshed audio. Revised assets are copied to `ReplicatedStorage.Assets.CombatReleasePreview`; the original 12 live models remain available. All 24 canonical staged imports and their snapshots remain preserved.

## Checks performed

- 88 Lune tests pass. Nine new tests cover contact spending, body-only guard mitigation, one-use thorns, misses/replayed results, death during windup, jitter/collision exclusions, bounded 3D geometry, three seeded first-six matchups and release/legacy data boundaries.
- A live native Pop/Crescent Axe prototype started successfully, displayed the revised bodies/cracks and scene-owned signatures, and was observed through about 23.77 simulated seconds. No script error was present in the inspected output. A screenshot is saved beside this report. Final round result, all first-six client branches and multiplayer completion are **not claimed**; Studio had returned to Edit before the final inspection.
- Baseline balance simulator, 120 rounds/matchup: starter mirrors 24.3/36.0/19.4 s, zero timeouts; side A 47%; Pop>Jam 62%, Jam>Prism 64%, Prism>Pop 63%; Perfect vs worst 64%; 52% mirror comebacks, 1.5 lead changes, 2.2 powers/glassy, 31% aimed misses. Equal-stat release field 39–57%. **Global signatures are disabled, so this is legacy-rule baseline coverage, not new-kit balance approval.**
- Economy simulator: 21 eligible nonstarters, 3.7 min/match, four day-one / 96 day-30 pulls; Rare 47 min, Epic 2.1 h, Legendary nine hours; 20% Mythic by day 30. Live installed-art filtering still narrows the actual Coin pool to nine.

## Quick creator test

1. Save the Studio place, start Play and use the Server command context.
2. Run `tools/studio/test_combat_release.luau` with `pair = 1`. After the round/cleanup, change to 2, then 3. These developer fights grant no items or currency.
3. Watch/listen for pressure buildup/pop, a distinct lid block, readable axe motion, three thorns, a charged coil snap, and rays that can visibly miss. Confirm HP stays readable and the existing finisher/heart sequence completes. Stop a fight early and check nothing remains playing.

Stop Play when finished. Report the pair and what felt weak, too loud, unclear or incorrect. No device preset change is needed.

Next engineering work: incorporate creator feedback, finish first-six native coverage, then implement the remaining 18 signatures with the same vocabulary, promote verified assets, update ability copy and enable the release system only after its checks. Full performance/multiplayer/device/publishing coverage remains outstanding.
