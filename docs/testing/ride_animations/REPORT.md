# Rider animations: report (workstream H)

2026-10-19. Creator request: real keyframe animations, uploadable and usable outside Studio, organised in
reusable families with a handle convention for future flyers. Design: [FLYERS_V3.md §5–6](../../art/FLYERS_V3.md).
Decision 96 (Proposed).

## What exists

- **5 families × 5 clips × 2 rigs = 50 Animation assets**, owned by group 11116787, all **Approved**:
  Surf, Sit, Kneel, HandleStand, HandleSit; clips Idle (loop), LeanLeft/LeanRight (loops), Launch, Land.
  Ids: `assets/animations/rider/roblox_assets.json` → `Config/RideFamilies.AnimationIds` (via
  `tools/write_ride_animation_ids.py`).
- **Source:** `src/shared/Config/RideFamilies.luau` (pure data) sampled by `src/shared/RideKeyframes.luau`.
  `lune run tools/build_ride_animations` writes the `.rbxm` KeyframeSequences (`assets/animations/rider/`) and the
  upload list; `tools/opencloud/upload_assets.py` now uploads `.rbxm` as `model/x-rbxm` Animation assets.
  The Lune-written files uploaded and were approved first try. The same sequences also live in Studio at
  `ServerStorage.RideAnimations` (built by `tools/studio/build_ride_animations.luau`) for the Animation Editor.
- **Playback:** `Presentation/RidePose` plays Idle at Action priority, the lean clips at Action2 with weights from
  the flyer's bank, Launch/Land at Action3 on take-off and when the launch rise settles (and when a lobby display
  flyer lands). Handle families lock R15 hands onto the flyer's `GripL`/`GripR` with IKControl (retrying until
  the grips stream in). Other players' riders show their owner's replicated tracks. Bots (anchored R6 presentation
  rigs) and any rider whose tracks are missing or fail to load in 4 s play the same keyframes in code. Feet or seat
  contact is solved every frame either way.

## Verification (Studio Play, under the shared lock)

| Check | Result |
|---|---|
| Lineup: 4 flyers × R15 (avatar copy) and R6 (generated R6 rig) | All 8 in Tracks mode; Idle weight 1, lengths match the clips (2.0–3.2 s); leans blend with bank; rocket R15 has both grip IKs |
| Full bank (0.35 rad) | LeanLeft at weight 1 on all 8, riders tip into the turn (`03_lean_left_full_bank.jpg`) |
| Launch one-shot | Playing on all 8 at 0.43 s, arms thrown up mid-spring (`04_launch_oneshot.jpg`) |
| R6 seated on the cloud | Legs point forward (leg axis along -Z in torso space), seat contact 1.07 |
| Real round, R15 player on the rocket vs bot | HandleStand Idle/Lean tracks on my character; grip IK hands 0.22/0.24 studs from the grips; the R6 bot holds the bar through the code fallback (`06_round_r15_tracks_ik_bot_code.jpg`) |
| Lobby Flyers display | Avatar clones play Sit and Surf tracks (`05_lobby_display_tracks.jpg`) |
| Dismount / round end | No ride tracks or IK left, Animate script re-enabled, root unanchored, no stages left |
| Missing ids (simulated) | Rider falls back to Code mode with the same Surf pose (hip about 20°, height 2.83) |
| Lune | 164/164 (new `RideFamiliesTests`: complete families, seamless loops, one-shots start/end on base, mirrored leans, R6 mapping, flyers → families) |

Shop portraits show flyers without riders, so they are unchanged (checked earlier in the flyer report).

Frames: `01_lineup_idle_r15_r6.jpg`, `02_handle_ik_rocket_r15_r6.jpg`, `03_lean_left_full_bank.jpg`,
`04_launch_oneshot.jpg`, `05_lobby_display_tracks.jpg`, `06_round_r15_tracks_ik_bot_code.jpg`.

## Not covered

- **Moonlantern Carriage:** HandleSit is ready for it; workstream I needs to add `GripL`/`GripR` to the carriage
  and map `lantern_carriage` to HandleSit (asked). Until then it keeps its legacy clip.
- **Multiplayer replication** (another player's rider seen through replicated tracks) was not testable with one
  Studio client; the code handles it (Observe mode, then Code if no ride tracks arrive within 2.5 s).
- **Creator feel review** of the motion (amplitudes are in `RideFamilies`; rebuild + re-upload with the two tools).
