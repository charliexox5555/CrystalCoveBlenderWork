# Finishers V2: Studio verification (workstream G)

2026-10-19, Studio "Testing glass game" (place 129420351303019), shared with other sessions. Design:
`docs/vfx/FINISHERS_V2.md`. Decision 91.

## Real bot rounds (Studio Play, client view)

A server-side QA helper (a temporary Script injected through the MCP; nothing committed under `src/`) set the
match's finisher (`entry.Cosmetics.Finishers`) and left both glassies one hit from shattering, so each round ended
on a real KO, flight and impact. The client logged every `Finisher_*` rig that appeared under the fight root.

| Finisher | Rounds seen | Result |
|---|---|---|
| Fizz Bloom (`bubble_bloom`) | match 1 rounds 1, 2 (bot won) | Played under `LocalFight_*`, no errors |
| Supernova (`starfall`) | match 1 rounds 3, 4 | Played, no errors. Peak frame: `fight_supernova_peak_v1.jpg` |
| Ka-Block (`brick_boom`) | match 1 round 5 | Played, no errors. Frame: `fight_kablock_gather_v1.jpg` |
| Piñata Pop (`party_burst`) | lock slot: match 1 rounds 2, 5 | Played, no errors, 0 rigs left in the fight root afterwards |
| Prism Pop (`glass_burst`) | lock slot: match 2 round 1 | Played, no errors, 0 rigs left afterwards, no colour grade left on the camera |

## Show timing, cost and cleanup (client, full detail, desktop)

Each show was played in the world in front of the camera with the colour grade allowed. Measurements are from the
client Heartbeat while it played.

| Show | Parts in rig | Max visible parts | Avg frame | p95 frame | Pooled at end | Grade left behind |
|---|---|---|---|---|---|---|
| Prism Pop | 28 | 20 | 16.8 ms | 18.3 ms | yes | no |
| Piñata Pop | 52 | 27 | 17.7 ms | 18.5 ms | yes | no |
| Fizz Bloom | 44 | 15 | 16.7 ms | 18.6 ms | yes (ends at 2.12-2.13 s for a 2.1 s show) | no |
| Ka-Block | 47 | 17 | 20.7 ms | 26.5 ms | yes | no |
| Supernova | 87 | 24 | 17.3 ms | 21.3 ms | yes | no |

The Studio machine was heavily loaded by other sessions' Blender renders and simulations, so frame times are an
upper bound. After all five shows, the QA folder had 0 children and no `FinisherGrade` remained on the camera.

## Tuning after the first look

- Supernova: the warm grade and flash washed out the frame at the peak, so peak brightness went from 0.12 to 0.06,
  contrast from 0.12 to 0.08 and flash size from 7 to 5.5.
- Ka-Block: the KA-BLOCK! sign was small and sat on the bot's name tag (sign size 4.2 to 5.6, height 3.4 to 5.2).
  The glass blocks read pale against the sky, so they now use saturated SmoothPlastic tints.

## Inventory/shop previews and portraits (Play, client)

`tools/studio/verify_finisher_previews.luau` runs each show the way `CosmeticCatalog` does: a WorldModel in a
ViewportFrame, camera-facing, with the 2D preview cues. It then builds the portrait still through `FinisherStill`.

| Show | Preview ended (loop granularity 0.05 s) | Show length | Peak preview sounds | Still built |
|---|---|---|---|---|
| Prism Pop | 1.99 s | 1.70 s | 4 | yes (26 instances) |
| Piñata Pop | 2.02 s | 1.90 s | 4 | yes (35) |
| Fizz Bloom | 2.12 s | 2.10 s | 3 | yes (41) |
| Ka-Block | 2.02 s | 2.00 s | 6 | yes (43) |
| Supernova | 2.69 s | 2.40 s | 4 | yes (38) |

The inventory preview now waits `FinisherFX.duration(id) + 0.4` s before restoring the still. The cores and peaks
fit the portrait's 9.5-stud fit radius. Pieces flying away (gems, facets, shooting stars) leave the frame while they
fade, which is intended.

Contact sheets (Edit, frozen frames built by the real shows, `tools/studio/finisher_contact_sheet.luau`):
`sheet_prism_pinata.jpg` (rows: Prism Pop, Piñata Pop), `sheet_fizz_kablock_supernova.jpg` and
`sheet_kablock_closeup.jpg` (KA-BLOCK! sign and the BOOM row read correctly). Particles and trails don't appear
in frozen frames.

## Sound levels (Play, client, AudioAnalyzer with no output device, so nothing is heard)

`tools/studio/measure_finisher_sounds.luau`. Peak RMS compared against approved bank sounds, then trims set in
`AudioCues`:

| Sound | Length | Peak RMS | Audible until | Trim now |
|---|---|---|---|---|
| FN_MagicBurst 9116385087 | 2.27 s | 0.172 | ~1.4 s | Seconds 1.8, Fade 0.45, Volume 0.36 |
| FN_GlowSwell 9116393976 | 1.69 s | 0.118 (peak at 0.93 s) | ~1.4 s | Seconds 1.4, Volume 0.35 |
| FN_PunchyPoof 9125640290 | 1.04 s | 0.070 | ~1.05 s | Volume 0.75 (matches MagicPoof 0.132 at 0.45) |
| FN_GlassPing 9126073644 | 0.69 s | 0.138 | ~0.3 s | Seconds 0.6, Volume 0.3 |
| (bank) MagicPoof | 1.16 s | 0.132 | | |
| (bank) SoftBoom | 2.96 s | 0.297 | | |

Every cue lands within 1.5 s of its phase (`RoundCosmeticTests`), exactly one impact cue per finisher, and the
8-voice cap and 20-70 stud rolloff are unchanged. A creator listening pass is still needed; the analyzer only
matches levels.

## Phone

The Studio MCP can't switch Device Emulator presets (also noted by workstream B), so no phone-preset run. What
covers phones in code: touch-only devices emit 70% of the particles (`FinisherShows.MobileParticles`), unwatched
arenas and the lobby showcase use the low-detail rig (about half the actors, 40% of the particles, no trails,
beams, lights, Highlights or grade), and the shows are world-space, so the HUD layout is untouched. Creator
check on a real phone is still pending.

## Meshes waiting for upload

Open Cloud asset uploads return 403 "User not authenticated" for `ROBLOX_ASSETS_KEY` (universe and developer
product calls still work). Until the creator restores the key's asset scope, every show uses its fallback mesh.

| Mesh (FV3_*) | Tris | Used by | Fallback today |
|---|---|---|---|
| PrismFacet | 18 | Prism Pop shell | Combat `GuardPlate` |
| PrismSliver | 24 | Prism Pop slivers | `CrystalShard` |
| PinataPoint | 44 | Piñata star points | Combat `Thorn` |
| PinataCore | 60 | Piñata core | native cylinder |
| CandyGem | 72 | Piñata gems | Combat `Droplet` |
| FizzCrown, FizzDrops | 336, 280 | Fizz Bloom splash crown | Combat `SplashSheet` (drops skipped) |
| ToyBlock | 156 | Ka-Block tower and letters | native block |
| BlockLetterB/O/M | 820, 576, 356 | Ka-Block BOOM letters | SurfaceGui text on the block |
| BurstSign | 188 | Ka-Block sign | native plate on a `ShockCrown` |
| StarCore | 32 | Supernova core | `NovaStar` |
| StarHaloBand, StarHaloGems | 384, 112 | Supernova halo | Combat `Ring` (gems skipped) |
| NovaRay | 8 | Supernova rays | `CrystalShard` |

Textures waiting for upload: StarGlint, SoftGlow, Streak, Bubble, Confetti4x4 (`textures/`). Their ids go in
`Config/FinisherShows.Textures`; until then emitters use the combat texture bank.

To install after the key is fixed: upload `assets/blender/round_cosmetics/finishers_v3/finishers_v3.fbx` as a Model
to group 11116787, insert it, normalise the importer's scale, and put the MeshParts (names `FV3_*`) in
`ReplicatedStorage.Assets.VFX.FinishersV3`. `Kit.template` picks them up with no code change.
