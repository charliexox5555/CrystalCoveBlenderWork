# Flyers v3: test report (workstream H)

2026-10-19. Design: [FLYERS_V3.md](../../art/FLYERS_V3.md). Decision 91 (Proposed).

## Status

| Piece | State |
|---|---|
| Four v3 models (Blender, headless) | Done: `assets/blender/round_cosmetics/flyers_v3/<id>/` |
| FBX round-trip validation | Pass for all four (names, triangle counts, bounds error ≤ 0.00001 studs, no loose or degenerate geometry) |
| Open Cloud upload | **Waiting**: the key returns 403 until the creator adds the asset permission |
| Studio install of v3 meshes | **Waiting for the upload** (installer ready: `tools/studio/install_flyers_v3.luau`) |
| Shared ride motion (`Presentation/RideMotion`) | Live, running on the current v2 meshes |
| Trails, particles, lights on the current meshes | See "Effects on current meshes" below |
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
