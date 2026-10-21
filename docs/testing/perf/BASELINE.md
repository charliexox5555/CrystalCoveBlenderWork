# Performance baseline (optimization pass, Oct 21 2026)

Measured in Studio Play (one player, mock profiles) on the creator's Mac. Studio caps frames at 60 fps, so
frame time alone hides work: the numbers below are the engine's own per-frame costs (`Stats`), the script
profiler (`ScriptProfilerService`, sampled at 1 kHz) and the two Studio-only probes added for this pass:

- client: `PlayerScripts.PerfProbeDev:Invoke("Sample", seconds)` (frames, remote traffic per remote, memory,
  instance and live-effect counts), `PlayerScripts.FightClientDev:Invoke("Profile", seconds)` (fight render ms
  by kind)
- server: `ServerStorage.PerfProbeServerDev:Invoke("Sample", seconds)` (time inside the per-frame service
  methods, profile syncs, send kbps)

## Lobby, idle (onboarding skipped, no matches)

| Measure | Value |
|---|---|
| Client render CPU / GPU per frame | 8.4 ms / 12.1 ms |
| Client physics step | 4.6 ms (227 moving primitives: the character and the two showcase avatars) |
| Draw calls / triangles | 305 / 122,649 |
| Instances (client) | 68,447 (workspace 4,460; PlayerGui 5,710 incl. 1,022 text labels in mostly disabled templates) |
| Live effects | 26 particle emitters, 11 beams/trails, 28 lights on |
| Client scripts (all) | ~0.2 ms per second (script profiler): showcase displays, rides, crate machines; negligible |
| Luau heap (client) | ~18.6 MB |
| Server per-frame services | ArenaService.Step 0.016 ms, HillService.Step 0.002 ms |
| Network to the client | ProfileSnapshot every 5 s (2.4 KB each, ~0.3 KB/s) |

## Seven live bot fights (MatchDev "AllBots"), player standing between arenas 3 and 4

| Measure | Value |
|---|---|
| Server FightService.Step | 0.357 ms per frame (422 calls/s = 7 fights x 60 Hz) |
| Server FightService.Send | 0.045 ms per frame (143 sends/s) |
| Server MatchService.Dispatch | 0.005 ms per frame |
| Server send to one player | 26.7 kbps |

Client numbers with fights: pending (the first run had FightController failing to start because of an
in-progress input change in another session; rerun below).

## Static findings (code review)

- **Memory leak, every UI rebuild:** `UI/Components/TextFit` keeps per-label state in a weak-keyed table whose
  values hold closures that reference the label. Luau weak keys are not ephemerons (checked in Lune: 1000 of
  1000 such entries survive), so every label ever built stays alive: the fight HUD each round, menus, toasts,
  popups.
- **Memory leak, finishers:** `Presentation/FinisherFX` maps show root -> rig in a weak table (`live`) that is
  never cleared; the rig references its root, so every destroyed rig stays alive.
- Profile snapshots (whole profile) go out every 5 s per player for the playtime clock; open Collection
  detail panels refresh on each.
