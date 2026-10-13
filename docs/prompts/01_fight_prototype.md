# F1 prompt for Codex: fight prototype

Paste everything below the line into Codex (repo open, Studio open with Rojo connected, Studio MCP on). Suggested setting: your strongest model at **high** effort; this is the most important milestone.

---

The game has been restructured. Read this whole message before you start.

**What changed (Oct 13):** Glass Clash is no longer a Pokémon-style game with a timing meter. It's now simple **lobby arena matches** (like Ball VS Ball, in our own form): 1v1 on a Clash Stand, each round both players roll 3 glassies from their own collection and pick 1, aim the pull-back, let go, and **watch** the two glassies swing on their strings and smash into each other until one shatters. Passive powers fire by themselves; each player can tap their **special** once per round. 3 hearts each; lose a round, lose a heart.

**Read first:** `git pull`, then `AGENTS.md` (updated), `docs/art/MAP_PLAN.md` (for scale only; the lobby comes in F2), `docs/GAME_DESIGN.md` sections 1–3, 9 and 14, `docs/DECISIONS.md` 22–29, `docs/ROADMAP.md` (milestone F1), `docs/ui/UI_SPEC.md` sections 4–6, and the code in `src/shared/FightRules.luau`, `src/shared/Config/Balance.luau` (`Motion`, `Fight`, `Feel`), `src/shared/Config/Powers.luau`, `src/shared/Remotes.luau`. Run `lune run tools/run_tests` (should be `0 failed`).

**Removed:** `BattleService`, `BattleController`, `BattleHud`, `BattleLogic`, the meter, trainers, zones, the M1/map Studio scripts. They are in git history; reuse what's useful (string `Beam`s, fighter setup, camera, portraits): `git show 8119b7b:src/client/Controllers/BattleController.luau`, `git show 8119b7b:src/client/UI/Screens/BattleHud.luau`. `ShatterController`, `CrackPaths`, `Theme` and the UI components stay. Clean up anything in the place that the deleted scripts created and is no longer needed (old prompts, old HUD instances, etc.), but keep the imported stand and glassy assets.

**Division of work (DECISIONS 24):** Claude wrote the rules (`FightRules`, `MatchLogic`, `Formula`, `Config`) and the simulators. **You own the motion and everything in Studio**: you can see it, so tune it by eye. Don't re-implement damage, powers or KO rules in services: call `FightRules`. If a rule needs to change, change it in the pure module, keep the tests passing, and note it in DEVLOG.

## Goal of F1

One Clash Stand in the place, two glassies (any of pop/jam/prism; more later), the full round: **aim → 3-2-1 → swing and smash with powers → special tap → shatter**. It must look and feel great on a phone. No lobby, queue, data or rewards yet.

## 1. The swing (server, `FightService`)

Simulate the swing yourself on the server, deterministically, at 60 Hz with a few sub-steps. Not Roblox physics. A suggested model (change it if something looks better):

- 2D in the stand's plane: x along the crossbar, y up. Each glassy is a pendulum on a hook at x = ∓`HookGap`/2, string `StringLength`, angle θ from straight down. Position = hook + L·(sin θ, −cos θ).
- θ'' = −(g/L)·sin θ − drag·θ' + drive. **Drive** keeps each glassy swinging toward its target height: target amplitude = `FightRules.targetAmplitude(Swing)` × `FightRules.swingMultiplier(fight, side)`; pump energy in the direction of motion when below it (e.g. drive = k·(E_target − E)/E_target·θ'). When `FightRules.isFrozen(fight, side)`, no drive and extra drag (`Motion.FrozenDamping`).
- **Collision:** circles of `Glassy.Radius`. On contact, push the overlap apart and apply an impulse along the contact normal with `Restitution`, using each pendulum's lever (tangent · normal) and `MassByType` (heavier pushes harder). Multiply the bounce of a side by `FightRules.knockbackMultiplier(fight, side)` (Slam).
- Every contact with approach speed ≥ `MinHitSpeed` and at least `HitCooldown` after the last hit → `FightRules.hit(fight, approachSpeed, shareA, x, y)`, where shareA = how much of the approach came from side 1 moving into the hit (0..1).
- Call `FightRules.tick(fight, dt)` every step. Stop when `fight.Over`.
- **Aim:** each side starts pulled back to its aim angle (away from the other) with θ' = 0, released together. A bigger pull-back gives a faster first swing.
- **Feel targets:** a hit roughly every 1–1.5 s, a mix of big smashes and glancing taps, never stuck touching, never spinning over the bar, no jitter. Round length ~15–45 s.
- **Scale (DECISIONS 30):** arenas show glassies `Motion.GlassyScale` (1.75×) bigger, on `StringLength` 7 strings from hooks `HookGap` 6 apart. Move the stand's HookA/HookB to ±3 on the crossbar in Studio (they're at ±1.5 now) and scale the glassy models, details, shards and crack paths by GlassyScale. Collision radius = `Glassy.Radius × GlassyScale`. Tune the scale by eye from the walkway; keep the glassies clearly the star.
- **Hit speed calibration:** damage uses speed / `Fight.RefSpeed`. After measuring, set `Fight.RefSpeed` to about the median approach speed of a normal hit, and `SimModel.SpeedAtAmplitude` so `SpeedAtAmplitude / RefSpeed` matches what you measured (it's 1.1 now). That keeps per-hit damage and round lengths as tuned.
- **Measure and report:** log hits per second and the average/min/max approach speed over 20 bot-vs-bot rounds; put the numbers in `Balance.SimModel` (`HitInterval`, `SpeedAtAmplitude`, `SpeedSpread`, `ShareSpread`), run `lune run tools/run_tests` and `lune run tools/balance_sim`, and tell me if anything in BalanceTests fails (then ask Claude/me before retuning `Balance.Fight`).

## 2. Networking

- Server → clients: `FightSnapshot` (UnreliableRemoteEvent, `Feel.SnapshotRate` 20 Hz): time, θ and θ' for both, HP, charge, shield/frozen flags (`FightRules.snapshot`). `FightEvents` (reliable): `FightRules.drainEvents(fight)` each step that has events (Hit, Passive, Special, SpecialReady, PerfectRelease, Overtime, Shatter, End), with the fight time so clients can line effects up with the motion.
- Clients render `Feel.InterpolationDelay` behind and interpolate between snapshots (use θ' for smooth Hermite interpolation). Hit effects play when the rendered time reaches the event time.
- Client → server: `SetAim` (number) during Aim, `UseSpecial` during Fighting. Validate type, finiteness, phase and the player's side; rate-limit with `Balance.Match.AimRateSeconds` / `UseSpecialRateSeconds`.

## 3. Client (`FightController` + UI)

- Anchored glassy models (`ReplicatedStorage.Assets.Glassies.<id>`: Body, Details, Shards) moved with CFrames from the interpolated angles, hanging from their hang-point origin. String `Beam`s to the stand hooks. A little body twist/wobble on hits (presentation only).
- Camera: 3/4 view of the whole stand during the fight; side-on slow-mo on the final blow (existing ShatterController sequence).
- **Aim screen** (UI_SPEC 4): drag your glassy back along its arc, ghost arc, gold Perfect band, LOCK button. Show "PERFECT!" when locked inside it.
- **Fight HUD** (UI_SPEC 5): HP bars with damage trail and crack icons, VS, SPECIAL button with charge ring (glows and shows the special's name when ready; "USED" after), popups for damage, CRIT!, SMASH! (speed above ~`Fight.RefSpeed`), passive names, special banners, status icons with timers.
- Effects per special: Shield bubble, Freeze frost, Beam ray, Slam glow + big knockback, Big Swing trail, Glaze shine. Keep them readable on a phone and short.
- Crack stages at `Feel.CrackThresholds` with `CrackPaths`, impact clink (`ClinkPitch`), hitstop only on big hits, camera shake by damage, haptics. GAME_DESIGN 9 is the checklist.

## 4. Test harness in the place

- A **ProximityPrompt** on the stand: "Fight a bot" → you vs a bot (random starter, `AutoSpecial`, bot aim via `FightRules.botAim`), with a random sweet spot from `FightRules.rollSweetSpot`.
- A dev-only `run_code` helper to start **bot vs bot** with any two glassy ids, and to print the measurements from step 1.
- After a fight ends, return to idle so you can fight again; no leaks across fights (Debris / `:Destroy()`, disconnect connections).

## Done when

- [ ] I can walk up, start a fight, aim, release, watch, tap my special at the right time, and see a great shatter, on a phone preset in the Device Emulator and on my real phone after publishing.
- [ ] Bot vs bot runs 20 rounds without errors; measured hit rate and speeds are in `Balance.SimModel`; tests pass in Lune and in Studio.
- [ ] Every special and passive is visible when it happens (popup or effect).
- [ ] ROADMAP F1 items ticked, a DEVLOG entry (with the balance_sim summary), decisions noted as Proposed, committed and pushed.

Then stop and tell me exactly what to test on my phone and what you tuned.
