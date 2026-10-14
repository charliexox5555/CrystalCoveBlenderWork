# F1 prompt for Codex: fight prototype (erratic 3D swing, auto powers)

Paste everything below the line into Codex (repo open, Studio open with Rojo connected, Studio MCP on). Suggested setting: your strongest model at **high** effort. This is the most important milestone: the fight *is* the game.

---

The sky lobby is done (thanks!). Now the heart of the game: **the fight**. Read this whole message before you start.

**What the fight is now (DECISIONS 22–34):** two glassies hang from a Clash Stand. Each player picked their glassy and aimed the pull-back (how far + which way). 3-2-1, both let go, and then **nobody touches anything**: the glassies swing **wildly in 3D**, smash into each other, sometimes whoosh past and come back, spin on their strings and wobble, and their **powers fire by themselves at random moments**, until one **shatters**. Like Ball VS Ball, **luck and suspense** are the point: a strong glassy usually wins but sometimes gets unlucky, a power that fires at the right moment turns the round around, an aimed power can miss. There is **no special button** any more.

**Read first:** `git pull`, then `AGENTS.md`, `docs/GAME_DESIGN.md` sections 1–3, 9 and 14, `docs/DECISIONS.md` 22–34, `docs/ROADMAP.md` (F1), `docs/ui/UI_SPEC.md` sections 4–6, and the code in `src/shared/FightRules.luau`, `src/shared/Config/Balance.luau` (`Motion`, `Fight`, `SimModel`, `Feel`), `src/shared/Config/Powers.luau`, `src/shared/Remotes.luau`. Run `lune run tools/run_tests` (should be `0 failed`).

**Reuse:** `ShatterController`, `CrackPaths`, `Theme`, the UI components. The old 2D meter battle is in git history if you want pieces (string `Beam`s, camera, portraits): `git show 8119b7b:src/client/Controllers/BattleController.luau`, `git show 8119b7b:src/client/UI/Screens/BattleHud.luau`.

**Division of work (DECISIONS 24):** Claude wrote the rules (`FightRules`, `MatchLogic`, `Formula`, `Config`) and the simulators. **You own the motion and everything in Studio.** You can see it, so tune it by eye until it's fun to watch. Don't re-implement damage, powers or KO rules in services: call `FightRules`. If a rule needs to change, change the pure module, keep the tests passing and note it in DEVLOG.

## Goal of F1

On **Arena 1** in the sky lobby: aim → 3-2-1 → an erratic, readable 3D fight with powers going off → a great shatter. It must look and feel great on a phone. No queue/match flow, data or rewards yet (that's F2); a test prompt starts the fight.

## 1. The swing (server, `src/server/Services/FightService.luau` + helpers)

Our own deterministic simulation on the server at 60 Hz with sub-steps; **not Roblox physics**. Read the hook positions from the stand's `HookA` / `HookB` attachments (DECISIONS 31); the stand's orientation defines its "plane" (the line between the hooks + up). Starting values are in `Balance.Motion` (new 3D section). A suggested model; change anything that looks better:

- **3D pendulum per glassy:** position on a sphere of radius `StringLength` around its hook. Integrate velocity with gravity + forces, then project back onto the sphere (normalize, remove radial velocity). Stable and simple.
- **Keeps swinging:** drive energy toward a target height = `FightRules.targetAmplitude(Swing) × FightRules.swingMultiplier(fight, side)` by pushing along the current velocity. Frozen (`FightRules.isFrozen`): no drive and extra drag (`FrozenDamping`).
- **Erratic but readable:** a weak pull back toward the stand's plane (`OutOfPlaneDamping`) so they mostly swing *at* each other, plus random sideways nudges (`WanderStrength`, every `WanderIntervalMin–Max` s, from a seeded RNG). Result: they sometimes clash head-on, sometimes clip, sometimes **pass each other** and come back.
- **Bounce:** sphere–sphere contact (radius `Glassy.Radius × GlassyScale`). Push the overlap apart, normal impulse with `Restitution` and `MassByType`, scaled by `FightRules.knockbackMultiplier(fight, side)` (Slam). Add a tangential friction impulse (`HitFriction`) so off-centre hits **deflect sideways** (`HitDeflect`).
- **Spin and tumble (looks matter):** glancing hits spin the glass around its string (`SpinFromHit`, capped `MaxSpin`); the string winds up and unwinds (`TwistStiffness`, `TwistDamping`). Big hits tilt the body (`TumbleFromHit`), which wobbles back to hanging straight (`TumbleDamping`). Simulate these on the server and send them in the snapshot so everyone sees the same thing.
- **Hits:** every contact with approach speed ≥ `MinHitSpeed`, at least `HitCooldown` after the last → `FightRules.hit(fight, approachSpeed, shareA, x, y)`, where shareA = how much of the approach came from side 1 moving into the hit (0..1). Call `FightRules.tick(fight, dt)` every step; stop when `fight.Over`.
- **Aim:** each glassy starts pulled back `Aim` radians away from the other, turned sideways by `AimYaw`, at rest; both released together.
- **Aimed powers can miss:** pass `PowerLands = function(side, powerId) ... end` to `FightRules.new`. Suggested: Beam/Freeze land if the other glass is within a few studs and roughly in front of the firing glass at that moment (start with ~7 studs and a 120° cone; add `Motion.PowerLandDistance` etc. if you need numbers). Aim for roughly 60–70% landing.
- **Scale:** glassies, details, shards and crack paths shown at `GlassyScale` (1.75×) on `StringLength` 7 strings from hooks 6 apart. Tune by eye from the walkway and the fight camera.
- **Feel targets:** a real hit roughly every 1.5–2 s, a mix of big smashes, glancing taps and near-miss pass-bys; swings you can't quite predict but can always follow; never stuck touching, never wrapping over the bar, no jitter. Round length 15–45 s.

## 2. Calibrate the rules to your swing

The balance simulator uses a stand-in for your swing (`src/tests/FightModel.luau`, `Balance.SimModel`). Once the swing looks right:
1. Run **20+ bot-vs-bot rounds** and log: hits per second, share of swing-throughs that pass without a hit, approach speeds (median / spread), shareA spread, and how often Beam/Freeze land.
2. Set `Fight.RefSpeed` to about the median approach speed of a normal hit. Update `Balance.SimModel` (`HitInterval`, `MissChance`, `SpeedAtAmplitude` so `SpeedAtAmplitude / RefSpeed` matches, `SpeedSpread`, `ShareSpread`) and the `LandChance` of beam/freeze in `Powers.luau` to what you measured.
3. Run `lune run tools/run_tests` and `lune run tools/balance_sim`. If BalanceTests fail after calibration, report the numbers to me (Claude retunes `Balance.Fight` / powers); don't hack the tests.

## 3. Networking

- `FightSnapshot` (UnreliableRemoteEvent, `Feel.SnapshotRate` 20 Hz): fight time; per glassy its position relative to its hook (3 numbers), velocity (3), twist angle + twist speed, tilt (2); plus `FightRules.snapshot(fight)` (HP, power glow, shield/frozen/rage flags). Keep it compact.
- `FightEvents` (reliable): `FightRules.drainEvents(fight)` each step that has events (Hit, Passive, Power (may have `Missed`), PerfectRelease, Overtime, Shatter, End), with fight time so effects line up with the motion.
- Clients render `Feel.InterpolationDelay` behind and interpolate (Hermite with velocities). Effects play when rendered time reaches the event time.
- Client → server: only `SetAim(aim, yaw)` during Aim. Validate type, finiteness, phase and side (`FightRules.clampAim` / `clampYaw`), rate-limit with `Balance.Match.AimRateSeconds`. `UseSpecial` no longer exists.

## 4. Client (`FightController` + UI)

- Anchored glassy models (`ReplicatedStorage.Assets.Glassies.<id>`: Body, Details, Shards) moved with CFrames: position from the interpolated swing, orientation = hang along the string + twist + tilt. String `Beam`s from the hooks.
- Camera: 3/4 view framing both glassies during the fight (follow the action a little, never lose either glass); side-on slow-mo on the final blow (ShatterController).
- **Aim screen** (UI_SPEC 4): drag to pull back: distance = how far (gold Perfect band), direction = which way (± `AimYawMax`); ghost path of the first swing; LOCK button; "PERFECT!" sparkle.
- **Fight HUD** (UI_SPEC 5): HP bars with damage trail and crack icons, VS, hearts placeholder, a glow ring per portrait that fills as the next power nears (`powerProgress`), **big power banners** in the glassy's tint when a power fires ("HOT STREAK!"), "MISSED!" in grey for whiffed aimed powers, popups for damage, CRIT!, SMASH!, WHOOSH (near-miss pass-by), passive names. **No buttons.**
- Effects per power: Rage (red-hot glow + embers), Shield bubble, Freeze frost (+ brittle sparkle), Beam ray (visibly missing when it misses), Slam glow + big knockback, Big Swing trail, Glaze shine. Readable on a phone, short.
- Cracks at `Feel.CrackThresholds` via `CrackPaths`, clink (`ClinkPitch`), hitstop only on big hits, camera shake by damage, haptics. GAME_DESIGN 9 is the checklist.

## 5. Test harness

- A ProximityPrompt on Arena 1's stand: **"Fight a bot"** → aim screen → you vs a bot (random starter, bot aim via `FightRules.botAim` + random yaw, sweet spot from `FightRules.rollSweetSpot`).
- Dev-only `run_code` helpers: bot vs bot with any two glassy ids and a seed (replayable), and the calibration logger from step 2.
- After a fight ends, return to idle; no leaks across fights (Debris / `:Destroy()`, disconnect connections). Other arenas stay idle for now.

## Done when

- [ ] Walk up to Arena 1, start a fight, aim, release and watch an erratic, readable 3D fight with spins, pass-bys, powers firing by themselves (some missing) and a great shatter, on a phone preset and on my real phone after publishing.
- [ ] 20+ bot-vs-bot rounds without errors; calibration numbers in `Balance.SimModel` / `Powers.luau`; tests pass in Lune and in Studio; balance_sim summary in DEVLOG.
- [ ] Every passive and power is visible when it happens.
- [ ] ROADMAP F1 ticked, DEVLOG entry, new decisions as Proposed, committed and pushed.

Then stop and tell me exactly what to test on my phone, what you tuned, and two or three short clips/screenshots of good moments (a big smash, a pass-by, a power that missed).
