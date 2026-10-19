# Hollowlight premium pass: verification (workstream I)

Oct 19 2026. Plan and beats are in [docs/vfx/HOLLOWLIGHT_PREMIUM.md](../../vfx/HOLLOWLIGHT_PREMIUM.md). Code commit: 0c0ebc4.

## Status

| Check | Result |
|---|---|
| Lune `tools/run_tests` | 154/155. The finisher cue test now allows the longer show. The one failure is `BalanceTests` "5 stars vs 0" (0.467 vs ≥0.48); that's balance (workstream A), not presentation. |
| StyLua | Clean on all files touched |
| Eclipse v2 in Play, headless step-through (both detail levels) | Runs with no errors. Visible parts peak at 49 (full) and 22 (low). The root destroys itself at Duration + linger, and nothing is left in the test folder. |
| Moonlight grade | Brightness −0.12 and saturation −0.18 at 1.3 s, warm flash +0.10 at 1.72 s, back to 0 at 2.6 s. It's only created for `LocalFight_*` and the bundle stage. It's removed by the root's Destroying event, which is deferred: 0 left 0.1 s after the fight folder is destroyed. |
| Lantern Seeds v2 with a mock fight (plant ×3, Ready, manual bloom, 3 wisps home) | Runs with no errors. 45 pooled parts per Hollowlight fighter, at most 28 visible. Ready shows the 2 orbit wisps, the warm light and the candle-flicker face. The ghost puff shows 27 parts and the homing ghosts 10. After `reset` nothing is visible. 9 sound cues fired. |
| CarriageFX on a clone with the extras installed | Finds 1 flame, 2 glows, 1 twinkle, 2 loops and both take-off bursts. The take-off lift goes −2.40 → −0.28 → +0.12 overshoot → 0 over 0.9 s. The loops are removed on Land. |
| Carriage extras in Edit | Installed on `Assets.Seasonal.Hollowlight.moonlantern_carriage` (7 instances). The backup is `ServerStorage.HollowlightCarriageBeforeExtras`. **Save the place to keep them.** |
| Real match in Play | The player owned the Studio test Hollowlight set and equipped Lantern Eclipse and the carriage. A player-vs-bot match picked Hollowlight (Pick Any) in rounds 1 and 2. The server staged `Ride1: lantern_skiff, CarriageFX=true`. |
| Frame cost | A steady Eclipse step costs 0.13–0.20 ms (median at 0.5, 1.3, 1.8 and 2.6 s; p90 ≤ 0.29 ms). In a 60 fps step-through, 9–14 steps per show took 25–260 ms. Plain allocation loops, `Emit`, trail, beam and light toggles were all cheap (0.5 ms at most), so the spikes are still unexplained. The client wasn't rendering at the time (see below), so **re-measure with a visible viewport** before launch. |

## On-screen verification in Play (Oct 19, Studio lock slot)

The display had been going to sleep, which is why the viewport stopped rendering earlier. A fixed it. The host was still at a load average of about 80 on 8 cores, from other sessions' Lune simulations, so the client ran at about 1 fps (frames of 1.2–4.4 s).

Real match: player against Bottle Bot in arena 1, with Hollowlight picked every round, Lantern Eclipse equipped, and the Moonlantern Carriage as the ride.

- **Watcher log (client):**
  - The carriage appeared and its sparkle loop played (volume 0.043, fading in).
  - Seeds planted 1 → 2 → 3, each with a flame and a shell.
  - Ready: 2 orbit wisps and the ready light came on, and the HUD showed **CAST!**.
  - The **real Lantern Eclipse played** on a won round, with the grade on at the start and off at the end.
- **Rounds:** the player won rounds 1 and 3, and the bot won the match 1–2 on hearts. No leftovers or grade after the match.
- **Not caught by the watcher:** the homing ghosts, blossoms and the manual-cast ghost puff. They last 0.3–0.6 s, which falls between frames at 1 fps, and the bot round used auto-casts. The mock step-through above covers them.

Beat captures: a show built in the live fight folder and stepped by hand to each beat, so the grade applies.

| File | What it shows |
|---|---|
| `01_round_carriage_and_hollowlight.jpg` | Round start: the player on the Moonlantern Carriage (glass crescent, lantern, wing ribbon) with Hollowlight on the stand |
| `02_eclipse_gather_and_live_ready.jpg` | Gather: lantern, spirals, the moon arriving and ghosts swooping in. Meanwhile the live round shows Hollowlight Ready (**CAST!**) and a planted seed. |
| `03_eclipse_peak_grade_choir.jpg` | Eclipse: the whole screen grades to moonlight, the five-ghost choir circles the moon-covered lantern, and binding beams show |
| `04_moon_shadow_tuned.jpg` | The moon shadow after tuning (radius 10, transparency 0.3, colour #120826, 0.25 studs above the floor). The first values (8 / 0.5) were barely visible under the pad ring and fence. |
| `05_eclipse_release.jpg` | Release: warm flash grade, gold shock crown and ring |
| `06_eclipse_ember_fall.jpg` | Ember fall: orange glass falling like leaves, the moon rising and the ghosts scattering |
| `07_bundle_view_eclipse_and_carriage.jpg` | Bundle VIEW stage: the Eclipse loop beside the carriage with its rider (BundleStage plus CarriageFX) |
| `08_lobby_showcase_carriage.jpg` | Lobby showcase: the carriage with a copied rider inside the stained-glass stage (RideMotion plus CarriageFX). The showcase Eclipse demo runs with no grade, as intended. |

Still open:
- **Phone presets:** the Device Emulator can't be driven through the MCP. Needs a manual check.
- **Frame cost with a normally loaded host:** steady Eclipse steps cost 0.13–0.2 ms, but the 1 fps client made live frame timing meaningless.
- **Readability:** the ghosts read pale against a bright sky. They're fine under the grade, but a little faint before the eclipse.
- **Creator review:** listening to the new sounds, and overall feel.

## How to repeat

- **Set up (Play, Server):**
  - `ServerStorage.CosmeticDev:Invoke("PreviewHollowlight", player)`
  - `Equip` Finishers `lantern_eclipse` and Rideables `lantern_skiff` before starting the match.
  - `ServerStorage.MatchDev:Invoke("Start", 3, player, nil)`
- **Every round** in the `Rolling` phase:
  - `SelectionTest Hold 20`
  - `SelectionAttempt PickAny "hollowlight"`. The cost is 0 the first time, then 6, 9, 12.
  - `SelectionTest Hold 0.3`
- **Headless step-throughs:** `HollowlightFX.create(folder, pos, low, CFrame.new())`, then `state:Step(t)` for t from 0 to 5.
- **Grade path:** parent the show to a folder named `LocalFight_*`.

## Waiting for upload

- `assets/blender/seasonal/hollowlight_v5/moonlantern_carriage_v5.fbx` (18,616 tris; review render `moonlantern_carriage_v5_review.png`).
- Open Cloud returns 403 until the creator adds asset permission to the key.
- Install steps are in HOLLOWLIGHT_PREMIUM §7b.
