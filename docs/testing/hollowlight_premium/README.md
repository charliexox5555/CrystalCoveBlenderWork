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

## Not verified yet (blocked)

The Studio Play client was **not rendering**: `RenderStepped` ran at 0 fps while `Heartbeat` ran at 60. The Studio window was presumably hidden or minimized, and the host was heavily loaded. As a result `screen_capture` timed out, and FightView and the ride motion (both on RenderStepped) never drew. These still need a visible Studio:

1. **Bot round:** Lantern Seeds plant, ripen, Ready, cast and wisps home, plus the Lantern Eclipse on a won round, with screenshots of the gather, the eclipse (shadow and grade) and the ember fall.
2. **Riding the carriage in a round:** take-off burst, moon-dust stream, flame flicker, engine glow, the loop sound near the camera, and the landing when the match ends.
3. **Bundle VIEW stage:** the carriage with CarriageFX through BundleStage, and the eclipse loop. `Showcase.Demo.AfterSeconds` is now 4.3.
4. **Lobby showcase:** the carriage through RideMotion, and the eclipse demo (no grade in the lobby).
5. **Phone presets** (Device Emulator), frame cost with rendering on, and the creator's listening review of the new sounds.

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
