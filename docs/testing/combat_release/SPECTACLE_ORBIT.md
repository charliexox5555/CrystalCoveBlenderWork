# Combat spectacle and horizontal orbit

October 15, 2026. Creator requested stronger combat moments and horizontal camera rotation. All 24 release kits remain active. Source changes sync through Rojo; the native model/VFX library is unchanged, so the existing live RBXM snapshot remains valid.

## Controls

During Fighting, drag with the left mouse button, swipe with one finger, hold Q/E, or move the right gamepad stick to circle the arena. The camera stays centered at its existing height, distance and FOV. A screen-width swipe spans a full circle. UI-consumed input is ignored; a second finger cannot steal or end an active drag. Focus loss clears held input.

Pull-back aiming keeps its current drag. The final blow freezes orbit at the current angle for the finishing sequence. Exiting/ending a view disconnects the orbit handlers and restores the ordinary camera through the existing lifecycle. Each new round starts at the usual outward angle. Participants and Watch spectators use the same controls; nearby unselected fights do not take input.

## Combat changes

- Prism Blade throws a visible returning crescent. Each leg can hit once; both share the existing 0.65 power damage budget. Travel lasts 1.05 seconds, with a 0.4-stud core radius. Server collision and client animation use the same normalized path; large steps split at the turnaround. Replay, expiry and death cancellation still go through FightRules.
- Hourglass sand and Comet stars now survive a turnaround refused by cooldown, instead of silently losing their stored charge.
- Windups gather six chips into two intersecting rings; releases and confirmed impacts expand short mesh accents. Contact powers retain their pressure/thorn/block identities. Distant low-detail fighters skip these accents. Meshes are destroyed after their bounded lifetime or scene cancellation.
- Traveling shots have rotating halos and trails. Flat crescents/halos face the viewer so rotating the camera cannot make them disappear edge-on. Splash/frost/breath cones have moving 3D droplets/crystals and clearer translucent sheets. Chime has three orthogonal pulse rings; Galaxy has four collapsing orbiting stars. Attack colors are more saturated than the pale glass bodies for contrast against the sky.
- Numeric HP, complete popup-outline fading, grounded avatars, winner flight and heart flow remain integrated.

## Verification

99 Lune and native Studio logic tests pass, including both returning legs across a large apex-crossing step, one shared damage budget/replay rejection and retained storage through cooldown. All 24 deterministic swing regression rounds settle with fixed strings.

32 native camera checks exercise real orbit handlers using synthetic input values, without desktop input: four quadrants, constant height/radius/focus, mouse/touch ownership, UI/aim/inactive gates, keyboard, stick deadzone, focus cancellation, final-blow freeze and connection cleanup. 264 native presentation checks pass across all 24 live models, cracks, shards and signature timelines; maximum isolated fixture descendants 92. A fresh-VM accent expiry check removes all eight accent meshes.

One actual Blade/Dragon desktop fight ended by shatter at 42.78 simulated seconds. The live observer accepted five orbit angles (0/90/180/270/360 degrees) at the same height/radius and ended with zero remaining views or observed runtime errors. Its observation window received nine releases and 21 contact results; it began after setup, so these are not full-round counts. Thirty render samples: 0.38 ms mean, 1.32 ms maximum controller work, approximately 60 FPS. This is one desktop view, not seven-view/phone performance approval. Two malformed inspection commands were corrected before the observer; they were tool-probe errors, not game failures. Later stale Play/Edit module-cache probes were rerun successfully in a fresh Play VM; final native logic and presentation checks pass.

48 actual deterministic swing report: 29.48 seconds average, 609 body contacts, 0.4304 body hits/second, zero timeouts; maximum string-length error 0.00000143 studs. This is regression coverage, not equal-stat fairness approval. Stand-in balance remains substantially skewed and lacks real travel/apex geometry. Required balance/economy reports are saved alongside the native observation and swing report.

Evidence: [native checks](spectacle_native.json), [actual swings](spectacle_swings.json), [balance diagnostic](spectacle_balance.txt), [economy](spectacle_economy.txt), [frozen power poses](power_beats.jpg). The image is an art fixture, not a live action capture.

## Creator review

Start Play and use a normal match, or the Server Command Bar:

```lua
game.ServerStorage.FightDev:Invoke("BotVsBot", "prism_blade", "glass_dragon", 6163, true)
```

Review the orbit sensitivity, crescent return, and readability of HP versus the brighter effects. Then try Water/Frost, Chime/Galaxy and contact-heavy pairs. Real touch/gamepad feel and broader fairness/performance remain manual review items. No device settings, publishing, currency prices or saved ownership changed.

Reproduction helpers: `tools/studio/check_fight_orbit.luau`, `verify_full_release_client.luau`, `preview_power_beats.luau` (frozen art poses, auto-cleans after 15 seconds). These run in Play/Client. Studio-only `FightClientDev:Invoke("Orbit", radians)` supports automated camera checks; it is not a network remote or production control.
