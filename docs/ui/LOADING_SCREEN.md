# Loading screen

The first thing a player sees (ReplicatedFirst, replacing Roblox's default screen). It shows the game in miniature
while the art preloads, then dips into the lobby.

![mockup](../../assets/ui/loading/mockup.png)

## What it shows

- A dim stained-glass rose window, "GLASS CLASH" in gold, the arena swing.
- Two vector glassies on strings (Pop, Jam, Prism, a green flask take turns). A small damped-pendulum simulation
  pulls them back and smashes them together: gold burst, glow, "CLASH!" on strong hits, shards in both colours, a
  little shake. Every third strong hit one glassy shatters and the next one drops onto its string.
- Tapping anywhere swings them again.
- A segmented amber glass bar with the real percent, and a rotating line ("Heating the Kiln...").

Flat images only (no ViewportFrames). Art: `tools/ui/loading_art.py` → `assets/ui/loading/{svg,png}`, uploads in
`assets/ui/loading/roblox_assets.json`, image ids in `src/first/LoadingScreen/Art.luau` (ReplicatedStorage isn't there
yet when it starts, so the ids live next to the script, not in UIAssets).

## What it loads (tiers, decision 111)

`src/first/LoadingScreen/Preload.luau` runs `ContentProvider:PreloadAsync` jobs from one table,
`src/shared/Config/LoadTiers.luau`:

| Tier | When | Workers | What |
|---|---|---|---|
| **Essential** | behind the screen; its jobs are the bar | 6 | fonts, HUD / top bar / icon / button / onboarding / reward / Daily images, the LobbyHUD, Welcome and Daily templates, the Featured stage's Hollowlight models, every part within 150 studs of the spawn (after `RequestStreamAroundAsync`) |
| **Soon** | right after the screen closes | 2 | the player's glassies and equipped cosmetics, the Shop (Kiln screens, cards, tiles, Kilns, crates, machines), the first fight (queue, roll, HUD, results, Clash Stand, billboards, combat VFX, `Audio` and `PowerAudio` sounds), Playtime Rewards, the rest of the streamed lobby |
| **Later** | idle background | 1, 0.05 s apart (0.4 s in a match) | the other glassies, flyers, ride animations, finishers and their textures, VFX, world kit, every other screen and image |

Anything not listed lands in Later, so new art is never forgotten. Item syntax is at the top of `LoadTiers.luau`
(`ui:<prefix>`, `screen:<Name>`, `asset:<Folder>/<Child>`, `images:<Config>`, `sounds:<Config>`, `id:<asset id>`, ...).

**On demand.** Jobs sit in lanes (Urgent > Essential > Soon > Later). When a screen named in `LoadTiers.OnDemand`
opens (a Window or a ScreenGui turning on) or a PlayerGui attribute there turns true (`Queued`, `InMatch`), its
items jump to Urgent. After the screen closes, glassies / flyers / finishers named in `OnboardingReveal`,
`KilnResult`, `RollOffers`, `CosmeticResult` and `StoreResult` payloads jump too; `ProfileController` passes each
`ProfileSnapshot` to `Preload.owned`. Client code can call it through `src/client/LoadGate.luau`:
`LoadGate.loader().want("KilnScreen")`, `.hint(payload)`, `.await(jobs, timeout)`; `LoadGate.afterLoading()` waits
for the screen to close (Music, Shatter, Topbar and the finisher Kit start their own preloads after it).

**Keep warm (decision 120).** Roblox drops a preloaded image that nothing draws, so `LoadTiers.KeepWarm` pictures stay
on screen in `PlayerGui.LoadWarm` (8 px, 99% transparent, behind everything): the item icon sprite sheets always,
and the player's hand while `Queued` / `InMatch`. Small item slots (80 px or less) draw from those sheets
(`Config/ItemIconSheets`).

Images are preloaded as `ImageLabel`s and sounds as `Sound`s: a bare id string reports `Failure` and restarts its
fetch. A job with a real failure runs once more in Later; failures show in the Studio report.

## When it closes

- When the Essential tier is done and `game.Loaded` has fired, but never before `MIN_SECONDS` (2.4 s) and never
  before the clash has been on screen `MIN_SHOW` (1.6 s; the first hit lands at ~1 s).
- **SKIP** appears after `SKIP_AFTER` (10 s) if loading is still going.
- It closes by itself after `MAX_SECONDS` (30 s).

Then it sets the local Player attributes `LoadSeconds` and `ClientLoaded = true` and releases Soon and Later.
`OnboardingController` waits for `ClientLoaded` (45 s cap) before the welcome card. `LoadStage` reads `Background`
until every tier is done, then `Done`. In Studio the Preload module carries `Summary` and `Jobs` attributes (one
row per job: start, seconds, tier, lane, key, targets, failed) for the MCP or the command bar. Studio A/B: the workspace attribute `LoadNoLater = true` skips the Later tier.

Timing in Studio (2026-10-21, `docs/testing/loading/REPORT.md`): closes at 4.7 s (was 10.3 s cached, 18.4 s first
run); Soon is done ~7 s after joining and Later ~35 s.

## Studio check (2026-10-20)

| | |
|---|---|
| ![hit](../testing/loading_screen/clash_hit.jpg) | A strong hit: CLASH!, the gold burst, shards in both colours |
| ![shatter](../testing/loading_screen/after_shatter_skip.jpg) | After a shatter (Prism dropped onto Pop's string); SKIP after 10 s on the first, uncached run |
| ![handoff](../testing/loading_screen/handoff_welcome.jpg) | The dip into the lobby; the welcome card follows |

Timing in Studio then: about 15 s on the first run (downloads), about 9 s once cached (before tiers).

## Files

| File | What |
|---|---|
| `src/first/LoadingScreen/init.client.luau` | The screen, flow and timing |
| `src/first/LoadingScreen/Clash.luau` | The swing show |
| `src/first/LoadingScreen/Preload.luau` | The tiered loader: lanes, on-demand, report |
| `src/shared/Config/LoadTiers.luau` | What loads in which tier, on-demand groups, lane widths |
| `src/client/LoadGate.luau` | Client access: `afterLoading()`, `loader()` |
| `src/first/LoadingScreen/Art.luau` | Image ids, glassy sizes, colours, the rotating lines |
| `default.project.json` | `ReplicatedFirst.LoadingScreen` → `src/first/LoadingScreen` |
