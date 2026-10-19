# Combat feel pass (workstream B), Oct 19

Client presentation only. No damage, rules, balance, server, Remotes, tests, FightHud, FightController or per-power VFX modules changed.

## What changed

| Piece | Where | What it does |
|---|---|---|
| Feel numbers | `src/shared/Config/CombatFeel.luau` (new) | Every number below: tier thresholds, per-tier shapes, sounds, hitstop, camera, wobble, beats, reduced-motion multipliers, mobile budget. |
| Feel driver | `src/client/Presentation/CombatFeel.luau` (new) | One per `FightView`. Classifies hits, holds the render clock, camera kick/shake/FOV, glass reactions, beats, low-HP tension, KO hold, victory, cast hooks. |
| Impact shapes | `Presentation/ImpactBeat.luau` (rewritten) | `Impact.tier()` draws flash core, star spokes, rings, chips, glints and a light pulse from a tier table. Parts and emitters are **pooled per fight** under `LocalFight_*/ImpactPool`. The old `Impact.emit()` call still works for CombatEffects. |
| Render clock + camera | `Presentation/FightView.luau` | Hitstop with proportional catch-up (replaces the old fixed hold), feel camera offset and FOV on top of the orbit/finisher pose, KO hold before the shatter, beats routed from events. |
| Glass wobble | `Presentation/FightScene.luau` | `Pose` multiplies in `f.React` (wobble/jolt around the body centre). With a feel attached, the Hit branch skips the old burst and sound. SMASH!/CRIT! popup moved above the BLOCKED/damage lanes, where they used to overlap. |
| Crack glint | `Controllers/ShatterController.luau` | `GlintCracks()` flashes the surface cracks bright on hits, then back to dark. |
| Preview | `src/client/Dev/CombatFeelPreview.luau`, `tools/studio/preview_combat_feel.luau` | Studio-only: stages any beat slowed down for screenshots. |

### Hit tiers

A **crit** always counts as Crit. Otherwise the tier is set by approach speed (as a multiple of `Balance.Fight.RefSpeed`) or by the bigger damage share. A hit where every point was absorbed counts as **Block**.

| Tier | Trigger | Hitstop | Camera | Look | Sound layers |
|---|---|---|---|---|---|
| Glance | below Solid | none | tiny shake | 4 thin spokes, small ring | light clink (glassy pitch) |
| Solid | ≥0.55× speed or ≥6% HP | 45 ms | small kick | 6 spokes, aqua ring, chips | transient + body clink + glass tail |
| Smash | ≥1.15× speed or ≥16% HP | 75 ms | kick, −2.5° FOV punch | 8 thick spokes, 2 rings, light | transient + heavy clink + scatter tail |
| Crit | any crit | 105 ms | bigger kick, −4° FOV | gold starburst, 2 rings, light | + chime sparkle |
| Block | all damage absorbed | 20 ms | small kick | gold ring, glints | lid "tok" + light clink |

Every layer has pitch jitter. The body layer uses the striker's `ClinkPitch`. The struck glassy wobbles away from the hit (spring, 2–3 wiggles), flashes white (its own Highlight, skipped while a power tint is on) and its cracks glint. The striker recoils slightly and throws glints.

### Hitstop and catch-up

During a hold the render clock runs at 4% speed (a near-freeze). Afterwards the rate is `1 + lag × 6`, capped at 2× and never below the old 1.25. The clock catches up to the interpolation target in about 0.2 s, and `RenderTime` is never set directly, so poses never jump and events never skip. There is no hold during the final slow-mo, because the KO beat owns that moment. Holds are capped at 120 ms.

### Camera

- **Shake:** trauma-based, scaled by trauma² with noise. Mostly positional, with a tiny roll (0.006 rad). Rings down at 2.6 trauma/s.
- **Kick:** a critically damped spring kicks the shot along the on-screen hit direction.
- **Cap:** the combined offset is limited to 0.3 studs.
- **FOV punch:** snaps in, then eases out. Capped at −6°.
- **Pose:** all of these sit on top of the orbit and finisher pose and never change player control or orbit yaw.

### Beats

- **Perfect Release:** gold burst on the glassy, chime. Own side only: −1.5° FOV.
- **Power landed** (CastContact / SignatureContact / beam or freeze): 65 ms hold, shake, kick, wobble and crack glint on the target. For multi-pulse kits, only the first pulse in 0.3 s gets the hold, shake and FOV; later pulses just wobble and glint.
- **Power missed:** small wobble on the caster and a soft falling whoosh, with no shake.
- **Block** (SignatureBlock / blocked CastContact): the attacker bounces off the guard.
- **Comeback:** the HP-fraction leader swaps after the old lead reached at least 12%. Shows a green burst, a "COMEBACK!" popup and a chime, with a 3 s cooldown.
- **Low-HP tension:** participants only, own glassy at 25% HP or less. A slight desaturate/contrast grade and a slow crack shimmer with a very quiet tick. No shake.
- **KO:** the Shatter event is held for 0.18 s (0.10 s with reduced motion). During the hold the loser is washed white and its cracks glint, with a −5° FOV punch, trauma 0.7 and a desaturate grade. Then it releases into the existing shatter, slow-mo and finisher.
- **Round win:** gold rings and glints on the survivor as the finisher starts. A local win plays the success chime.
- **Manual cast** (contract from workstream A, built ahead of the events):
  - `SignatureReady` for your side gives a soft ping and glints.
  - `CastStart { Manual = true }` for your side gives a gold starburst, a 50 ms hold, a −3° FOV punch, a white flash, a "NICE CAST!" popup, a screen-edge tint and a riser + chime.
  - Someone else's manual cast gets a small ring only.
  - Contact-payoff kits send `SignatureArmed { Manual = true }` instead of `CastStart`; that gets the same beat.
  - The Ready ping plays once per `ReadyId`, even if Ready is sent again.
  - `ReadyCancel` clears the Ready state.
  - Duplicate `CastStart`s are ignored by CastId.

### Reduced motion and budget

- **Reduced motion** reuses the existing switch: `UI/Components/Motion.reduced()`, which reads the PlayerGui attribute `ReducedMotion` or Roblox's own Reduced Motion setting. It turns off shake, kicks and FOV punches, halves wobble and grade dips, and multiplies holds by 0.6.
- **Touch-only devices** emit 60% of chips and glints. SavedQualityLevel 1–3 emits 40% and skips lights and white flashes.
- **Fights you are not watching** get only the low-detail impact: at most 4 spokes and 1 ring, no chips or light, and no camera, wobble or sound when muted.
- **Pools are capped** at 4 rings, 12 spokes and 2 flashes per fight. Extras are destroyed, never kept.

## Studio verification (Play, Oct 19)

- **Live bot fights from the spectator/client view.** All ran with no script errors.

  | Fight | Seed | Result |
  |---|---|---|
  | Pop vs Prism | 101 | clean |
  | Jam vs Crescent Axe | 202 | 5 Solid / 6 Smash / 1 Crit, 3 Block, 2 Perfect, 1 power land, 1 power miss, KO hold, 15 hitstops |
  | Milk Bottle vs Pickle Jar | 303 | Commons: 8 Solid / 8 Smash / 4 Crit, KO + Victory |
  | Prism vs Glass Dragon | 404 | run with reduced motion |
  | Jam vs Frostglobe | 505 | live Perfect Release screenshot |
  | Pop vs Briar Flask | 606 | Glance tier seen; 11 power-contact beats, so the 0.3 s gap was added. Run twice, before and after the gap; 0 script errors |
  | Real player-vs-bot matches | — | Started with `MatchDev` "Start"; a client script picked, aimed and pressed CAST through the `CastPower` remote. See the cast check below. |

  - During live fights the FOV dipped to 47.5–48° on crits and came back to 52°.
  - With `ReducedMotion` on, the FOV stayed at 52° the whole fight and holds were 39 ms.
- **Live cast check (player vs bot, A's commit `c147c3b`):**
  - The event log showed `SignatureReady` for both sides, the bot's `CastStart { Manual = true }`, and after my press `SignatureArmed { Manual = true }` on my side (Pop is a contact-armed kit).
  - My press fired the player beat (`FeelManualCastMine`): 50 ms hold, burst, and the "NICE CAST!" popup appeared in PlayerGui. The bot's cast got the small ring.
  - When nobody pressed, Ready was followed by an auto `SignatureArmed { Manual = false }` and no beat, as intended.
  - Three matches, 0 script errors.
- **Leftovers after the match:** no `LocalFight_*` folder, no `FightFeelGrade` or `FightShatterFlash` in Lighting, camera back to Custom at FOV 70. During a fight the pool peaked at 23 children.
- **Frame time:** 68 ms on average during a fight versus 67 ms idle. Studio was throttled to about 15 fps in the background in both cases, so these numbers only show that the pass adds no measurable cost here, not real phone performance.
- **Tests:** Lune `tools/run_tests` 146 passed, 0 failed. Studio RunAll on the Play server: 145 passed, 1 failed. The failure is `BalanceTests` "Mythic vs Common", caused by workstream A's in-progress rarity retune (uncommitted `Balance`/`BalanceTests` edits), not by this client-only pass.

## Screenshots

These are staged with `CombatFeelPreview` at 50–70× slower so the frame can be captured. At real speed each beat lasts 0.25–0.5 s.

- `00_crit_before_tuning.jpg`: the first crit pass. Too pale and hidden behind the glass on bright sky, so the burst was moved toward the camera and given thicker spokes and saturated colours.
- `01_crit_tier.jpg`, `02_solid_tier.jpg`, `03_smash_tier.jpg`: tier separation.
- `04_ko_hold.jpg`: the KO hold (white wash, grade). Brightness was lowered after this shot.
- `05_manual_cast.jpg`: the manual-cast starburst.
- `06_live_perfect_release.jpg`: the real fight camera, both bots landing Perfect Releases.

## What's left

- **Phone Device Emulator preset not run.** The Studio MCP can't switch emulator devices. The Play viewport was 1167×510, a phone-landscape aspect, and the touch-only particle cut was checked by reading the code only. A 2-minute check with an iPhone preset is still needed.
- **Real-speed feel review by the creator.** Tier thresholds, hold lengths and the KO hold are first guesses from the research ranges; tune them in `Config/CombatFeel`.
- **Comeback and tension beats were not seen in a live fight** (bot fights rarely swing). They are covered by the preview and code paths only.
- **Sound mix:** the layers reuse the existing licensed bank. A dedicated glass "tail" sample would make tiers sound more distinct.
