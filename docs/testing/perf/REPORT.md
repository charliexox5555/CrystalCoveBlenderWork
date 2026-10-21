# Optimization pass: report (Oct 21 2026)

Baseline and method: [BASELINE.md](BASELINE.md). All numbers are from Studio Play on the creator's Mac with one
player and 7 live bot fights (`MatchDev "AllBots"`). Studio throttles to 15 fps when its window is in the
background, which inflates per-frame script times from the sampling profiler; the before/after pairs below were
always taken back to back at the same frame rate, from the same fixed camera, with the Studio switch
`workspace:SetAttribute("PerfNoCull", true)` standing in for the old code (it turns every cull and rate tier
off).

## What was slow

1. **Flyers in matches** (~2.3 ms/frame at 60 fps): every flyer within 120 studs moved itself (`PivotTo`), its rider
   (`PivotTo`) and solved the rider's pose every frame, on screen or not.
2. **Lobby showcase displays** (~1.3 ms/frame): the same ride work for the display flyers and their riders.
3. **Bystander fights** (~1.2 ms/frame): every nearby fight rendered every frame, including ones behind the
   camera.
4. **Two memory leaks**: UI text-fit state and finisher rigs were never freed (see below).
5. Small per-frame waste: attribute reads and string matching per animated part, a hex-colour parse per fighter,
   seven throwaway tables per rider per frame.

The server is not a bottleneck: FightService.Step costs 0.36 ms per frame for 7 fights, MatchService 0.005 ms,
ArenaService 0.016 ms; one player receives ~27 kbps (fight snapshots 15 KB/s, fight events 10 KB/s while 7 fights
are in range). No server changes were needed.

## What changed

| Change | Where | Effect |
|---|---|---|
| Off-screen culling (view cone widened to the screen diagonal + a radius) | `Presentation/ViewCull` (new), `RideController`, `ShowcaseController` `Ride:Step`, `RidePose` (`Culled`) | Off-screen rides, displays and rider poses skip their frame; motion is time-driven, so they are exactly right when seen again |
| Rate tiers | `RideController`, `ShowcaseController` (rides > 45 studs: every 2nd frame); `FightController` (bystander fights > 55 studs: every 2nd frame, off screen: every 4th) | Skipped time is carried into the next update, so swings, events and finishers stay on time. Your fight and watched fights render every frame |
| TextFit leak | `UI/Components/TextFit` | Per-label state is dropped on `Destroying` (Luau weak keys are not ephemerons: checked in Lune, 1000 of 1000 entries survived) |
| FinisherFX leak | `Presentation/FinisherFX` | The show-root -> rig map is cleared on release and on destroy |
| Per-frame caching | `RideMotion` (part attributes, rider mount), `CombatEffects` / `SignaturePresentation` (detail part names), `FightScene` (tints), `RidePose:Solve` (numeric loops) | Same output, less work |

Tuning lives in `Balance.Feel.Bystander*` and `Balance.CosmeticPresentation.RideCullRadius / RideHalfRateDistance`
(presentation only).

## Numbers (client scripts per frame, 7 fights)

| Camera | Before | After |
|---|---|---|
| Bystander on the path, looking at arenas 3-6 | 13.1-13.9 ms | 6.0-6.7 ms (-53%) |
| Same spot, looking back at the spawn | 11.5-14.2 ms | 5.9-6.7 ms (-51%) |
| Same spot looking back, 60 fps run | - | 2.6 ms |

(Both pairs were measured at 15 fps, which inflates the sampling profiler's per-frame numbers; the ratio is the
reliable part. Before = `PerfNoCull`, which also includes the caching wins, so the true before is a little worse.)

## Bystander tier (creator: everyone on the map sees what's going on)

| What | Watching / your fight | Bystander (on screen, within 120 studs) |
|---|---|---|
| Swing, hits, cracks, HP | full | full, every 2nd frame beyond 55 studs |
| Powers | full PowerFX tier | PowerFX low tier (fewer particles, no lights, bloom or camera) |
| Status badges (marked, slowed) | yes | yes (new) |
| Fast-swing trails | yes | yes (new) |
| Finisher | full show at the losing rider, avatar flash, camera beats, sound | low show at the losing rider (new: it used to aim at the pad), no flash, camera or sound |
| Flyers and riders | animated, effects within 70 studs | same; every 2nd frame beyond 45 studs; skipped off screen |
| Hide Others' Cosmetics | - | other players' finisher shows become the plain glass break, their flyer effects stay off |

Finisher tiers measured (peak visible parts / lights): Emberwing 30 / 0 low vs 36 / 1 full, Starfall 16 / 0 vs
25 / 1, Glass Burst 11 / 0 vs 20 / 0.

## Memory over many rounds (after the leak fixes)

Seven bot fights kept running, a bystander camera, about 20 round views built and destroyed in 3 minutes:

| Time | Client Luau heap | Instances | PlayerGui |
|---|---|---|---|
| +15 s | 14.8 MB | 70,627 | 5,786 |
| +65 s | 15.4 MB | 70,346 | 5,786 |
| +126 s | 15.6 MB | 70,545 | 5,786 |
| +191 s | 15.9 MB | 70,301 | 5,786 |

Instances and PlayerGui stay flat. The heap creeps ~0.35 MB a minute (incremental GC; worth a 20-minute soak
before launch). Before the fix, every destroyed label and finisher rig stayed referenced for the whole session.

## Captures

From a bystander spot on the path between arenas 3 and 4, after the change: the glassies, a power's rings at
arena 3, beams and badges further back, flyers with their trails and riders. A live finisher could not be caught
on a screenshot (the MCP capture lands more than 3 s after the call, longer than any show), so the finisher tier
comparison above is by counting what each tier renders.

## Still worth doing later

- PlayerGui keeps ~5,800 instances (1,000+ text labels) of mostly disabled screen templates; TextFit binds all of
  them. Binding only when a screen first enables would save memory and connections.
- ShowcaseController rides cost ~1 ms/frame while in view (riders solve their pose every frame); a shared pose
  cache per family would help if the lobby grows.
- Moving flyer models with `BulkMoveTo` instead of `PivotTo` (needs care: GetPivot users and streaming).
