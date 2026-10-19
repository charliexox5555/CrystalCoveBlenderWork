# Release overhaul plan (Oct 18 → launch Fri Oct 23 / Sat Oct 24)

Goal: fights that are fair, readable and exciting, with a small skill layer kids can ignore. Order: balance → powers/VFX → game feel → glassy revamp/roster → test and polish. Research: [COMBAT_OVERHAUL_RESEARCH](../research/COMBAT_OVERHAUL_RESEARCH.md).

## Audit (Oct 18)

- **Rarity isn't the stat problem; powers are.** Rarity multipliers are 1.00–1.10, but equal-stat power win rates range from **21% to 83%** (FightModel; real swing: Prism Blade 65.5%). Top: Prism Blade (Epic), Glass Dragon (Mythic), Water Jug, Briar Flask, Chime. Bottom: Pickle Jar, Glass Duck, Hot Sauce, Mason Jar. Target band: 45–55%.
- **Stars are a big hidden edge:** 5★ vs 0★ wins 82% (+2% stats per star, squared through Power × HP).
- **No player skill during the fight** (decision 33): input is only the pick and the aim. Perfect vs worst aim: 58%.
- **The simulator stand-in drifts from the real swing.** The real `Pendulum` runs in Lune (~1.2 s a round), so balance is now measured on the real swing (`tools/release_matrix`, sharded across cores).
- Roster: 24 release + Hollowlight; 13 dormant definitions have no models.

## Creator decisions (Oct 18)

1. **Powers stay automatic, with an optional cast.** When a power is ready, a big CAST button lights up. Tap it to fire at a moment you choose. Ignore it and the power fires by itself after a short window. Young players can ignore it; good timing gives a modest edge (target: a smart caster beats an auto-only player 55–62%).
2. **Rarity edge ≈ 55%** at equal skill. Rarity buys more complex, flashier powers and presentation, not numbers. Stars capped at about +5% total.
3. **Roster:** about 36 at launch (24 polished + ~12 new at full quality), then 3–4 a week to 50.

## Cast system contract (shared by all workstreams)

- Kits keep their triggers (contact, turnaround, timer, threshold, received, heavy). When a trigger would start a cast for a **player** side, the signature becomes **Ready** instead. Event `SignatureReady { Side, Kit, ReadyId, AutoAt }`.
- Client sends remote `CastPower()` (no arguments; rate-limited; validated: in a fight, own side, Ready). The server starts the cast on its next tick.
- At `AutoAt` (`Balance.CombatRelease.Cast.AutoSeconds` after Ready) the server casts automatically. Events: `CastStart` gains `Manual = true|false`; `SignatureReady` may be followed by `ReadyCancel { Side, ReadyId }` (round end, KO).
- Contact-armed kits use the same flow: Ready → (tap or auto) → armed → next contact pays off.
- Bots cast with a per-bot skill profile (reaction delay + "good moment" read); some bots never press.
- Client hint: the button pulses harder when the glassies are closing in (client-only, from snapshots).

## Workstreams

| # | Workstream | Owner | Files it owns | Depends on |
|---|---|---|---|---|
| A | Balance + cast system: real-swing matrix tool, kit retune, rarity/star curve, cast rules, server remote, bots, CAST button, tests | this session | `src/shared/*` (rules, Balance, Glassies, Powers, Remotes), `src/server/*`, `src/tests/*`, `tools/*.luau`, `UI/Screens/FightHud`, `Controllers/FightController` | — |
| B | Combat feel and impact juice: hitstop, camera kick, hit tiers, layered impact audio, crit/KO/victory beats, readability, mobile budget | session | `Presentation/ImpactBeat`, `CombatEffects`, `FightView`, `FightOrbit`, `FightHealth`, `ShatterController`, `Config/Audio`, `Config/AudioCues` | — (reads A's events) |
| C | Existing glassy model revamp in Blender: materials, silhouettes, moving `Details` parts for idle motion | session | `assets/blender/glassies/**` new versioned folders, Blender only | — |
| D | Roster expansion design: 12 launch + 14 drop glassies with kits on the cast contract | session | `docs/design/ROSTER_V2.md` | creator approval before Blender |
| E | Power VFX upgrade to Pumpkin-finisher quality, tiered by rarity, plus Ready/cast states | starts after A's retune lands | `Presentation/HeroPowers`, `SignaturePresentation`, `SignatureAccent`, `Config/CombatKitVisuals`, Studio VFX templates | A |
| F | New glassies: Blender models → import → kits → balance | C's session after D is approved; kits by A | — | C, D |
| G | Final test and polish: multiplayer, phones, performance, exploits | this session | — | all |

**Shared Studio rules:** one Studio and one Rojo (this checkout) serve everyone. Before Play, check `get_studio_state`; if Play is running and not yours, wait. Stop Play when done. Run tests in a Play server. Commit only your own files by exact path; never `git add -A`, stash, reset or switch branches.

## Schedule

| Day | Work |
|---|---|
| Sun 18 – Mon 19 | A: matrix tool, retune, rarity/stars, cast rules and server. B, C, D start. |
| Tue 20 | A: CAST button, bots, Studio verification. D approved → F modelling. E starts. |
| Wed 21 | E/B continue; C models imported; F models. |
| Thu 22 | F imports + kits + balance; integration; multiplayer/performance. |
| Fri 23 | Release candidate, fixes, creator playtest and publish. |

**After launch:** drops to 50, finisher and flyer upgrades (creator's next request), ranked/trophy matchmaking.
