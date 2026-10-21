# Loading baseline (before tiers)

2026-10-21, Studio Play in "Testing glass game" (Mac, server and client in one process), the loading screen as it
was: one `Preload.jobs()` list of everything, 4 `PreloadAsync` workers, started after `game.Loaded`, closes when
everything is done (3.2 s minimum, SKIP after 10 s, auto-close at 30 s). Timings came from a temporary per-job
timer in `Preload.run` (removed again).

## What it loaded

| Group | Jobs | Contents |
|---|---|---|
| UIAssets | 7 | 168 image ids, batches of 24 |
| StarterGui | 22 | every screen template (KilnScreen alone: 1,876 instances, 330 viewport meshes, 207 images) |
| Assets.Glassies | 37 | 1,368 instances, 1,010 MeshParts |
| Assets.Rideables | 11 | 186 MeshParts, 73 emitters |
| Assets.RoundFinishers / VFX / Seasonal | 12 / 5 / 1 | finisher rigs, combat and finisher VFX (14 sounds), Hollowlight |
| Crates, CrateMachines, Kilns, RideStand, UI, WorldKit | 3 / 4 / 2 / 2 / 1 / 8 | shop machines, stand, billboard, world kit |
| Workspace | 12 | whatever had streamed in (Lobby folder: 1,766 instances) |

Not loaded at all: any sound in `Config/Audio`, `PowerAudio`, `Music` (controllers preload those themselves at
start, at the same time as the screen), ride animations, `FinisherShows` textures.

## Timings

| Run | `game.Loaded` | Preload | Screen closed | Notes |
|---|---|---|---|---|
| 1st Play of the session | 4.02 s | 13.69 s | **18.40 s** | VFX folders 3.0-3.3 s each (sounds), glassies 0.25-0.78 s each |
| 2nd Play (cached) | 2.63 s | 6.80 s | **10.30 s** | glassies 0.18-0.50 s each |

Studio keeps a disk cache across sessions, and other sessions had already played this place, so neither run is a
true cold start. The tester's ~12 s on a gaming PC sits between the two; the earlier LOADING_SCREEN check noted
15 s first / 9 s cached on 2026-10-20, before more glassies, flyers and finishers were added.

Where the time went (2nd run, job seconds summed per group, 4 in flight):

| Group | Jobs | Sum | Window |
|---|---|---|---|
| Glassies | 37 | 14.4 s | 1.5-5.2 s |
| Rideables | 11 | 4.4 s | 4.9-6.4 s |
| StarterGui | 22 | 2.1 s | 0.2-1.1 s |
| UIAssets | 7 | 1.9 s | 0.0-0.6 s |
| WorldKit | 8 | 1.2 s | 1.0-1.4 s |
| CrateMachines | 4 | 0.9 s | 6.3-6.7 s |
| VFX | 5 | 0.8 s | 1.3-1.5 s |
| Workspace | 12 | 0.7 s | 6.5-6.8 s |

So ~80% of the wait was models the first minute never shows (37 glassies, 11 flyers, 12 finishers), and the screen
could not start until `game.Loaded` (2.6-4 s in Studio).

`ContentProvider.RequestQueueSize` stayed at 50-180 for the whole screen. Memory by tag did not move per job
(Studio's texture memory is already ~130 MB from the editor), so bytes per job could not be measured this way.

## What "not loaded" was

Checked right after the screen closed (visible ImageLabels in PlayerGui, fetch status of every config asset id, a
screenshot of the first view):

1. **SKIP at 10 s.** With 10-18 s of loading, SKIP shows before loading ends. A tester who saw "~12 s" most likely
   pressed it (or the cached run just finished); either way everything after that point loaded behind a live
   lobby: glassies, flyers and finishers popped in as they were first shown.
2. **Sounds were never part of the screen.** `ShatterController`, `MusicController` and `PowerFX` preload their
   sounds on their own, in parallel with the screen. A first hit, power or music bed could still be loading.
3. **Bare id strings don't preload.** `ContentProvider:PreloadAsync({ "rbxassetid://..." })` reports `Failure`
   right away and puts the asset back to `Loading`, even for a good image (it showed later). So the old UIAssets
   batches were not really waited for, the loading screen's own art could start blank, and `Finishers/Kit` judged
   every uploaded finisher texture "failed" and swapped all 10 for their fallbacks (fetch status: 10 of 11
   `Failure`). The top bar Settings icon also reads `Failure` while it displays fine: same cause.
4. **Ride animations and 35 flyer-family assets** had fetch status `None` after the screen: never requested.
5. **Three meshes never load** (`Failure` on every try): `Glassies.glass_phoenix.Body`
   (rbxassetid://89543800857593), `Rideables.carousel.PonyCore` (73989584659034) and the gumball crank
   (107144503993935, in `RoundFinishers.gumball` and `VFX.FinishersV4`). Art follow-up, not a loading bug.
6. **Streaming**: StreamingEnabled is on; the old screen preloaded only what had streamed in by then.

Not a problem: the HUD, top bar, welcome card (its Kiln viewport) and lobby around the spawn were all on screen and
loaded at the moment the screen closed in both runs.
