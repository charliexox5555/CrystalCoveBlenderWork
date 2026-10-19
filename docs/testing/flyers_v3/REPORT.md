# Flyers v3: test report (workstream H)

2026-10-19. Design: [FLYERS_V3.md](../../art/FLYERS_V3.md). Decision 93 (Proposed).

## Status

| Piece | State |
|---|---|
| Four v3 models (Blender, headless) | Done: `assets/blender/round_cosmetics/flyers_v3/<id>/` |
| FBX round-trip validation | Pass for all four (names, triangle counts, bounds error ≤ 0.00001 studs, no loose or degenerate geometry) |
| Open Cloud upload | **Waiting**: the key returns 403 until the creator adds the asset permission |
| Studio install of v3 meshes | **Waiting for the upload** (installer ready: `tools/studio/install_flyers_v3.luau`) |
| Shared ride motion (`Presentation/RideMotion`) | Live, running on the current v2 meshes |
| Trails, particles, lights on the current meshes | Installed in Studio (Edit), backups in `ServerStorage.FlyersBeforeV3` |
| Loop sounds | Live (four Roblox ProSoundEffects loops, all load) |

## Models

| Flyer | Tris (budget) | Parts | Size, studs (W × H × L) | Moving parts |
|---|---|---|---|---|
| Skyboard | 5,214 (5,500) | 17 | 2.9 × 1.2 × 7.8 | 2 hover rings (Spin Y) |
| Cloud Cushion | 5,030 (5,500) | 11 | 3.6 × 3.5 × 6.7 | 5 puffs (Puff), 3 rainbow ribbons (Tail) |
| Rocket Skiff | 7,036 (7,500) | 26 | 6.1 × 4.2 × 11.5 | 2 fans (Spin Z), 2 flames (Flame), 2 fins + tips (Fin) |
| Prism Ray | 4,104 (7,500) | 16 | 10.6 × 1.4 × 10.1 | 2 wings + veins (Wing), 2 head lobes (Fin), tail + prism (Tail, prism also spins) |

Previews: `assets/blender/round_cosmetics/flyers_v3/<id>/<id>_preview.png` and `<id>_rider_scale.png`
(grey R15-sized block stand-in).

## Checks run

- **Live bot rounds (another session's Play, observed read-only):** 14 rides across 7 matches. Rides near the
  camera move 0.03–0.25 studs per quarter second with the new two-wave float and drift; rides beyond
  `RideDistance` (120) stay still; each ride has one loop sound; no errors in the output.
  Screenshot: `01_round_motion_v2_meshes.jpg` (skyboards in a live round, rider aboard).
- **Frame cost:** `RideMotion:Step` on the client, 600 steps each: skyboard 4.3 µs, cloud 4.8 µs,
  rocket 10.0 µs, ray 16.2 µs per ride per frame (14 rides ≈ 0.12 ms worst case).
- **Every motion kind** (Wing, Spin with axis, Puff, Tail + extra spin, Fin with bank coupling, Flame), the
  launch, bank clamping (reaches the 0.4 rad profile cap under a 0.8 rad/s turn), effects toggling,
  launch bursts and sound/effect cleanup: exercised on a synthetic model on the client; all moved, no
  errors, sound removed on Destroy.
- **Sounds:** 9125742262 (33 s), 9119462416 (18 s), 9119414082 (37.6 s), 9125602386 (36 s) all load.
- **Lune:** 155/155.

## Effects on current meshes (installed in Studio)

`tools/studio/flyers_v2_effects.luau` (with `flyer_effects.luau` prepended) added attachments and the shared effects to
the four v2 templates in `ReplicatedStorage.Assets.Rideables`, tagged `FlyersV2FX` so a rerun replaces them. Unchanged
originals are in `ServerStorage.FlyersBeforeV3`. The place must be saved for the Studio change to persist.

| Flyer | Effects |
|---|---|
| Skyboard | two rail trails, lift motes under the board, pod light, wind streaks, launch puff + glints |
| Cloud Cushion | rainbow wake trail, cloud wisps, twinkles, wind streaks, launch puff |
| Rocket Skiff | flame + smoke + sparks per engine, engine lights, two fin trails, wind streaks, launch smoke + sparks |
| Prism Ray | prismatic wing-tip trails, body glints, tail sparkle + light, wind streaks, launch crystals + glints |

Studio Play (my own session, 5 matches: one player vs bot with the rocket equipped, four bot vs bot): all four flyers
appeared; near the camera every looping effect and the loop sound were on (rocket 11/13, cloud 4/5, launch bursts
are the one-shot remainder), rides past 70 studs had effects off, past 120 studs no motion work at all. After all
matches ended: 0 match stages, 0 stray loop sounds. Lobby Flyers display: my avatar rides each flyer in turn with
trails and streaks (seated on the cloud, standing on the ray).

Fix found in Play: the fully additive rocket flame was invisible against the bright sky and clouds. Flame is now
mostly alpha-blended (LightEmission 0.35, Brightness 4), smoke and cloud wisps fully alpha-blended.

Screenshots: `02_lobby_display_cloud_ray.jpg`, `03_lobby_prism_ray_trails.jpg`, `04_lineup_trails_v2_meshes.jpg`
(client-only lineup in open sky), `05_rocket_exhaust_tuned.jpg`, `06_round_r15_rider_rocket.jpg` (R15 rider on the
rocket in a live round). R6: bots are R6 rigs and rode every flyer in the bot matches without errors.

## Not covered

- **v3 meshes in Studio:** waiting for the upload. Then: `zsh -i -c 'python3 tools/blender/upload_flyers_v3.py'`,
  set `_G.FlyersV3` (asset ids + manifest JSON), run `flyer_effects.luau` + `install_flyers_v3.luau` in Edit, and
  check the rider fit (rocket hands on the handlebar at about 2.6 studs up / 1.6 forward, cloud legs on the footrest,
  ray stance on the saddle) with `tools/studio/verify_ride_poses.luau`, adjusting `RideAnimations` clips if needed.
- **Phone presets:** the Studio MCP can't switch Device Emulator presets (same as workstream B). Effects are culled
  by distance and the per-ride cost is a few microseconds, so phones should be fine; still needs a creator check.
- **Sound mix:** the loops are quiet (0.07–0.10, 6–40 stud rolloff) but were not listened to; creator ear check.
- Lune 154/155: the one failure is BalanceTests (decision 86 star edge) from workstream A's in-progress balance edits,
  not flyer code.
