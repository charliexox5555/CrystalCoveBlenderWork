# Flyers v3: test report (workstream H)

2026-10-19. Design: [FLYERS_V3.md](../../art/FLYERS_V3.md). Decision 93 (Proposed).

## Status

| Piece | State |
|---|---|
| Four v3 models (Blender, headless) | Done: `assets/blender/round_cosmetics/flyers_v3/<id>/` |
| FBX round-trip validation | Pass for all four (names, triangle counts, bounds error ≤ 0.00001 studs, no loose or degenerate geometry) |
| Open Cloud upload | Done by A: skyboard 139742118431979, cloud_cushion 80173522623643, rocket_skiff 101000283449232, prism_ray 88678420214260 (all Approved, `roblox_assets.json`) |
| Studio install of v3 meshes | **Installed** in `ReplicatedStorage.Assets.Rideables` (same names); backups `ServerStorage.FlyersBeforeV3` (v2 originals) and `.V2WithEffects`; raw imports in `ServerStorage.FlyersV3Import` |
| Shared ride motion (`Presentation/RideMotion`) | Live on the v3 flyers |
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

## v3 install and verification (Studio, under the shared lock)

- **Install:** `flyer_effects.luau` + `install_flyers_v3.luau` in Edit. The uploads import at 100× and turned 180°;
  the installer's fit found scale 0.01 and the 180° turn for all four. Result vs manifest: every part within
  0.0002 studs in size, model extents within 0.0002, pivot at the contact point (0, 0, 0). Because the turn flips
  the parts' local X/Z axes, the installer now flips the signed motion values (WingSide, FinAngle/FinBank,
  SpinSpeed) so wings, fins and fans move as designed (`AxisFixed` attribute).
- **Rider fit** (`tools/studio/check_flyer_fit.luau`, R15 avatar through the real RidePose solver, flyer space):
  rocket hands were 0.7 studs too wide, so the clip arms changed to {54, -8, 8} with 30° elbows; hands now at
  (±1.05, 2.57, -1.8) on the grips (bar at ±0.96..1.22, 2.58, -1.56). Cloud: seat contact correct, feet resting on
  the front puff, arms changed to {0, 0, ±6} so hands rest on the arm puffs. Skyboard and ray unchanged (feet on
  the grip/saddle, arms out). R6 bots: seated cloud rider faces forward with legs over the front puff.
- **Real rounds:** player-vs-bot with the rocket, then the skyboard, plus bot-vs-bot rounds with the cloud, rocket
  and ray. All v3, effects on near the camera (rocket 11/13, ray 6/8, cloud 4/5; the rest are launch bursts),
  off beyond 70 studs.
- **Bug found and fixed:** with streaming, a ride can arrive before its parts, so near rides had no loop sound.
  RideMotion now creates the sound once a part exists (`EnsureSound`, called from `Collect`). Rechecked in a new
  Play: every near ride's loop plays (0.07–0.09 volume).
- **Lobby display:** my avatar seated on the v3 cloud and standing on the v3 ray with trails; the carriage slot
  is unaffected.
- **Shop/crate portraits** (`CosmeticPortrait`, as used by the shop, inventory and Sky Capsule reveal): all four v3
  models render and frame well. The skyboard showed blank for one frame until its meshes downloaded (first
  use in that session); that is normal asset streaming.
- **Look tweak:** the ray's inner core was lightened (#7B5BD6 → #9C84E8) so the crystal reads lilac, not deep violet.

Screenshots: `10_v3_rocket_r15_round.jpg`, `11_v3_prism_ray_r6_round.jpg`, `12_v3_cloud_r6_round.jpg`,
`13_v3_lobby_display.jpg`, `14_v3_shop_portraits.jpg`, `15_v3_skyboard_r15_arena_view.jpg`.

## Not covered

- **Place save:** the v3 templates live in the open place; the creator must save/publish to keep them.
- **Phone presets:** the Studio MCP can't switch Device Emulator presets (same as workstream B). Effects are culled
  by distance and the per-ride cost is a few microseconds, so phones should be fine; still needs a creator check.
- **Sound mix:** the loops are quiet (0.07–0.10, 6–40 stud rolloff) but were not listened to; creator ear check.
- Lune 154/155: the one failure is BalanceTests (decision 86 star edge) from workstream A's in-progress balance edits,
  not flyer code.
