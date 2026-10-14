# F1 fight prototype

Arena 1 runs a server-stepped spherical pendulum at 60 Hz with three substeps. The hooks determine its coordinate frame. Gravity, energy drive, reciprocal phase guidance, seeded lateral wander, contact impulses, string twist and body tumble are independent of Roblox physics. FightRules owns damage, auto powers and the winner.

Snapshots are sent at 20 Hz; clients use velocity-based Hermite interpolation and play reliable events at rendered fight time. The final snapshot also travels with reliable events. Aiming accepts only finite numbers from the participant, during Aim, at the configured rate. Lock commits the aim. Opponent aim is hidden until Countdown.

The presentation includes scaled starter meshes/details/shards/cracks, strings, ghost arc, gold Perfect band, charge rings, HP trails, power/status banners, near-miss whooshes, contact sparks, layered clinks, big-hit hitstop, damage shake, haptics, a side-on final cut, slowed shards and a heart pop. Stand supports fade locally when they obscure a glassy. All per-fight instances are destroyed on return to idle.

## Replay and calibration in Studio Play / Server

```lua
local dev = game.ServerStorage.FightDev -- exists only in Studio
dev:Invoke("BotVsBot", "pop", "prism", 101, true) -- final argument enables the test camera/HUD
dev:Invoke("Calibrate", 40, 100) -- same integrator, accelerated, yields every three rounds
dev:Invoke("Inspect")
dev:Invoke("Cancel")
dev:Invoke("Watch") -- ten live rounds, covering every power and passive family
dev:Invoke("WatchReport")
```

The command execution environment has a separate module cache; use this runtime BindableFunction to reach the active server. Nothing is exposed to clients. Non-starter debug IDs use tinted starter proxies until their art is imported. Actual collection rolls will be limited to installed assets.

Offline: `lune run tools/fight_calibration 80 100`.

## Measurements and balance handoff

Lune 80 rounds: 0 timeouts; median 32.56 s (P10 18.69, P90 45.58); 0.461 hits/s; 36.7% pass-bys; hit speed median 20.67 (P10 7.22, P90 29.45); shareA median .499 (P10 .290, P90 .680). Aimed powers landed 66/99 overall: Beam 32/43, Freeze 34/56. Maximum string error <.000002 studs.

Studio 40 rounds: 0 timeouts; median 31.55 s (P10 18.38, P90 46.51); .467 hits/s; 36.2% pass-bys; speed median 20.45 (P10 6.92, P90 29.79); shareA median .499 (P10 .293, P90 .685). Float arithmetic differs slightly between Lune and Studio, so replays are deterministic within the same runtime rather than bit-identical across runtimes.

Candidate SimModel: HitInterval 1.37, SpeedAtAmplitude 24.5, SpeedSpread .67, ShareSpread .245, MissChance .367. Two balance tests fail with it: Jam mirrors 45.882 s, Prism Blade equal-stat win rate 63%. The passing baseline SimModel is retained; raw measurements and candidate/baseline simulator reports are preserved. Balance.Fight and Powers were not retuned under the overnight instructions.

## Verification

- Lune and Studio: 55 passed, 0 failed, including seeded replay, constrained motion/contact and freeze regression checks.
- iPhone 17 Pro landscape: aim and fight visible; interactive UI uses CoreUISafeInsets; LOCK minimum 80×44; local support fading keeps both glassies readable.
- Live ten-round watch, seeds 401–410: 13.93–43.57 s, every round ended by shatter, one double KO, zero final Output errors. Raw results: `F1_live_watch.json`. Earlier crack-stage initialization and duplicate-popup bugs were fixed before the final watch.
- Native drag/LOCK input advanced Aim → Countdown. NaN and malformed inputs left the phase in Aim. Cancel returned to the normal camera with no local fight folder or HUD.
- Screenshots: [big smash](f1/big-smash.jpg), [pass-by](f1/pass-by.jpg), [missed aimed power](f1/power-missed.jpg), [final blow](f1/shatter.jpg).
- Publishing and real-phone verification remain pending for the user.
