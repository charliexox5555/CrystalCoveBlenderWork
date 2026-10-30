# Private core-loop prototypes — resume checkpoint

**LATEST CREATOR CORRECTION: repeated re-aim is rejected. Seamless constant gameplay is the priority.** The active lab now uses B only: select/launch once, automatic fight, a 1.25-second shatter beat, then the next opponent starts automatically with the previous aim. Bottom-row glassy choices queue the next duel's pick without interrupting the current fight. No repeated RELEASE, PLAY AGAIN, lobby or selection gates. A's pure runner/tests remain only as historical experimental code; do not revive or polish it.

Creator approved these prototypes October 29. **Live v700 stays unchanged. Do not publish the lab.** Approval covers two private combat prototypes and playability evaluation, not a production/progression/map/monetization overhaul.

## Current build

- B only: choose once, launch once, watch the existing pendulum/powers resolve a shatter, then automatically begin the next duel after 1.25 seconds. Optional choices queue for the next duel without interrupting the current one. Current/queued choice is highlighted; short role descriptions explain both fighters.
- A's repeated-clash runner remains historical code, inaccessible from the active lab. Do not resume it.
- Six existing glassies: Pop, Jam, Prism, Glass Cup, Water Jug, Ketchup Bottle. Existing models, powers, cracks, audio and shatter are reused. No newly redesigned six-kit roster yet.
- Isolated 60% HP; production Balance is untouched. No hidden Perfect/gold-band damage bonus. Server validates roster/mode, finite/clamped aim, phase and request rate.
- Private hook spacing is7.5 studs, using the existing per-simulation gap parameter; client strings use the server-reported anchor span. Production stays6. Known Cup/Ketchup stalls now finish around10s; [evidence and limits](../testing/CONTINUOUS_CONTACT_PACING.md).
- Smoothed snapshot playback synchronizes visible motion/HP with damage, block/status and shatter feedback. Reuses existing HUD popups without adding aim controls or power banners. A YOU marker distinguishes mirror fights.
- Manual Studio-only entry points; nothing in Main/Services/Controllers requires the lab. Temporary remotes/sessions, no profiles/rewards/purchases/live analytics. Disposable local stage above lobby. Exit restores camera, movement/touch gate, GUIs and blur/depth-of-field state.

## Launch

New modules are synced into the current open Glass vs Glass Edit place through MCP, **unpublished**. Start Play, then run:

Server:
```lua
require(game.ServerScriptService.Server.Dev.LoopLab).start()
```
Client:
```lua
require(game.Players.LocalPlayer.PlayerScripts.Client.Dev.LoopLab).start()
```

Choose a glassy. Drag/release, use RELEASE, or press Space once. Further duels flow automatically. Use the bottom row to queue another glassy; doing nothing keeps the current one. EXIT LAB restores the normal view. Before Stop Play, get completed reports in Server:
```lua
return game.ServerStorage.LoopLabReport:Invoke()
```

If Studio reopens from live v700, install these source files through MCP first (no Rojo):

| Source | Target |
|---|---|
| src/shared/Config/LoopLab.luau | ReplicatedStorage.Shared.Config.LoopLab |
| src/server/Dev/LoopLab/init.luau | ModuleScript ServerScriptService.Server.Dev.LoopLab |
| src/server/Dev/LoopLab/Session.luau | child ModuleScript LoopLab.Session |
| src/client/Dev/LoopLab.luau | StarterPlayer.StarterPlayerScripts.Client.Dev.LoopLab |
| src/client/Dev/LoopLabFeedback.luau | StarterPlayer.StarterPlayerScripts.Client.Dev.LoopLabFeedback |
| src/client/Dev/LoopLabPlayback.luau | StarterPlayer.StarterPlayerScripts.Client.Dev.LoopLabPlayback |
| src/tests/LoopLabTests.luau | ServerStorage.Tests.LoopLabTests |
| src/tests/RunAll.luau | ServerStorage.Tests.RunAll |

## Verified

- Lune and Studio: **295 passed, 0 failed**. Eight lab tests cover validation, historical state continuity, real-swing resolution, bounds, automatic next-duel/queued-choice continuity, interpolated HP/motion, feedback timing/final-shatter flush, and both original Cup/Ketchup stalls.
- Continuous desktop run completed at least three consecutive duels with one launch each and no new aim/replay prompt. Actual queued Jam click left the current Pop duel running, then Jam entered the next duel automatically. Exit removed the lab UI/scene and restored Custom camera.
- iPhone 13 landscape emulator: actual initial choice/release and queued Jam clicks worked; current Pop stayed unchanged until the next duel. Completed reports contained Pop then Jam, and Jam continued without a release gate. Role text, green queued-choice highlight and separated bottom note were visually checked. Character reset removed the lab GUI/scene and restored Custom camera. Emulator checks are not physical-phone or novice testing.
- Galaxy A06 landscape: initial choice/release and queued switching work. The test tool offsets horizontal mouse coordinates by47px on this preset; an adjusted actual click queued Prism during the current fight. The44px EXIT target now stays fully inside the safe GUI bounds; an actual click removed the lab and restored Custom camera. This is an emulator check, not a physical-phone result.
- Current36-fixture sample: median10.12s/p9017.20s versus baseline12.73s/18.02s; known Cup/Ketchup fixtures9.75s/10.04s. Additional216 fixtures at three launch settings had no timeout or25s+ fight (max22.83s); some contact-gap metrics worsened, so no guarantee for every seed/angle. [Full comparison](../testing/CONTINUOUS_CONTACT_PACING.md). No production tuning/publication.
- Initial A smoke: Pop/Glass Cup, seed291027, **30.45s,5 launches,5 contacts**, rival shatter win. B: Jam/Water Jug, seed291028, **15.55s,1 launch,8 contacts**, player win. Different fixtures before pairing patch: these prove technical completion, not preference or a valid A/B comparison.
- Both modes opened with actual clicks; Space advanced A before timeout. Exit removed GUI/scene and restored Custom camera. Final display has no claim-screen blur and a dark backing for readable glass.
- No new runtime stack traces in initial A/B smoke; old asset203785492 warnings remain. No live publication.

## Continue here, with targeted reads

1. Review the continuous prototype with the creator. Automatic handoff, queued switching and exit/reset smoke checks are complete; do not resume the rejected A comparison.
2. Physical-phone checks. Galaxy A06 queued switching and iPhone13 landscape initial release/switch/reset emulator checks passed; hit targets are at least44px. Lab gamepad navigation remains pending.
3. Review power payoff/choice understanding with a person and inspect remaining quiet stretches. Known Cup/Ketchup stalls are covered by the new geometry/regression; do not re-run the gap search. Observation protocol is in CONTINUOUS_LOOP_REVIEW. Each new duel inherits previous aim; do not add another mandatory control step.
4. Refine only seamless-play blockers, meaningful choice and visible power payoff. No new metagame or cosmetic rebuild.
5. Prepare unfamiliar-player tests of voluntary continued play, switching strategies and understanding outcomes. No unfamiliar-player results exist yet. Never confuse automatic duel3 starting with voluntary replay/engagement.
6. Return findings to creator for direction approval before broader redesign/production rollout.

Use this checkpoint first. Do not repeat the full audit or balance matrix. Broader research already exists in docs/research/CORE_LOOP_RESEARCH_2026_10_29.md.
