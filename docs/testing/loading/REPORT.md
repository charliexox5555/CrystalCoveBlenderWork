# Loading report (tiers, decision 111)

2026-10-21, Studio Play in "Testing glass game", same machine as [BASELINE.md](BASELINE.md). Read the
before numbers and the research there. Numbers come from the loader's own Studio report (`Summary` / `Jobs`
attributes on `ReplicatedFirst.LoadingScreen.Preload`), read through the Studio MCP.

## Result

| | Before | After |
|---|---|---|
| Loading screen closes (`LoadSeconds`) | 18.4 s first run, 10.3 s cached | **4.5-4.95 s** (5 runs: 4.91, 4.73, 4.50, 4.81, 4.95) |
| What it waited for | everything: 168 images, 22 screens, ~120 models, the lobby | Essential: 27 jobs (fonts, 71 images, 3 screens, 2 Featured models, 1,654 parts near the spawn) |
| Essential done | n/a | 3.2-3.9 s after the script starts |
| Soon tier (50 jobs) done | n/a | ~7.0-7.5 s |
| Later tier (85 jobs) done | n/a | ~31-36 s |
| Images, sounds, animations really preloaded | images reported Failure, sounds and anims not covered | every target is an Instance; real failures only (below) |

All runs were cached in the Studio sense (the disk cache already held the assets; BASELINE explains why a true cold
start can't be forced in Studio). On a cached run the essential images take ~2.4 s, mostly waiting on the first fetch
round trip. The ~4 s target holds on a fast connection. On a cold join the Essential tier is ~70 small images plus
the parts around the spawn, about a tenth of what the old screen waited for.

Of the 4.5-4.95 s, 2.4 s is the minimum show (`MIN_SECONDS`), and Essential usually finishes after that. Then
~0.5-0.9 s is the close: the bar settles, "Let's clash!" holds 0.35 s, and the veil dips 0.25 s.

## Was anything missing when first needed?

- **At close:** every visible ImageLabel in PlayerGui was loaded, except three top-bar dropdown icons that sit inside
  a closed dropdown. Those are in the Essential tier and loaded; the label only reports `IsLoaded` once it renders.
  The HUD, top bar, welcome card (with its Kiln viewport) and the lobby around the spawn were all there.
- **Shop and first fight:** in Soon, done ~2.5 s after the screen closes, faster than anyone can walk to a Kiln or a
  pad and through a queue.
- **Opening a screen early (on demand):** enabling `CollectionScreen` mid-Later moved `screen:CollectionScreen` and
  `screen:GlassyDetailScreen` to the Urgent lane, and they started at once (normally ~34 s in).
- **Welcome opens:** firing `OpenWelcome` returned `pickle_jar, glass_top, frostglobe`. `pickle_jar` was still
  queued in Later; it jumped to Urgent and started as soon as the payload arrived (0.11 s after the request), during the Kiln opening and before
  the cards show. The other two were already done.
- **The player's own glassies** jump to Soon from `ProfileController` (`Preload.owned`).

## Smoothness

Frame times read from the client while Soon and Later ran (19 s) vs. 19 s after everything finished:

| | Frames | Mean | Worst | Over 33 ms |
|---|---|---|---|---|
| Background tiers running | 1,130 | 17.2 ms | 106 ms | 14 |
| Nothing loading (control) | 1,037 | 18.3 ms | 111 ms | 49 |

No added hitching from the background tiers; Studio noise (server in the same process) dominates both.

## Memory cost of "everything loaded"

Client memory by tag, ~30 s after joining, same actions (open the Inventory, open the welcome Kilns):

| | GraphicsTexture | GraphicsMeshParts | Animation | Sounds |
|---|---|---|---|---|
| All tiers (Later done) | 148-152 MB | 37 MB | 35 MB | 38 MB |
| Later switched off (`workspace.LoadNoLater`, Studio only) | 128 MB | 20 MB | 30 MB | 38 MB |

So the Later tier costs about **+24 MB texture and +17 MB mesh memory** (~40 MB). That buys the creator's "nothing
pops later". The engine lowers texture quality by itself on low-memory devices (Creator Docs, Improve performance).
If phones struggle, the knob is `LoadTiers.Tiers.Later`: drop `asset:Glassies` / `asset:Rideables` from it, and they
still load on demand from payloads and screens. Music is not preloaded during the screen (Docs: load audio as needed).

## Real failures the loader now reports

Bare-string preloads used to hide these. They fail on every try (the job retries once):

| Asset | Used by | Output says |
|---|---|---|
| rbxassetid://89543800857593 | `Glassies.glass_phoenix.Body` (MeshId) | "Asset is not approved for the requester" |
| rbxassetid://73989584659034 | `Rideables.carousel.PonyCore` | same |
| rbxassetid://107144503993935 | gumball crank (`RoundFinishers.gumball`, `VFX.FinishersV4`) | same |
| rbxassetid://203785492 | not in the place or `src` (likely a Roblox core asset) | "Asset type does not match requested type" |

The first three are mesh uploads still under review, rejected, or owned by an account the place can't use. In a
live game those parts may be invisible: the Phoenix's glass body, the carousel's pony, the gumball machine's crank.
Art follow-up (re-upload under group 11116787, then swap the MeshIds).

## Also fixed on the way

- **Finisher textures:** `Presentation/Finishers/Kit` preloaded its 11 uploaded textures as bare strings, saw
  `Failure`, and switched every emitter to its fallback. It now preloads ImageLabels, so the approved finisher
  textures show (Starfall glints, Ember, Petal, Confetti, ...). Visible change; worth a look in the next finisher check.
- **Loading-screen art:** also preloaded as strings, so the show could start on blanks. Now ImageLabels.
- **Startup competition:** `MusicController` (7 beds, the biggest downloads), `ShatterController`, `TopbarController`
  and the finisher Kit now start their own preloads after `ClientLoaded` (`src/client/LoadGate.luau`).

## Not done / follow-ups

- **ReplicatedStorage is heavy.** Everything in it replicates before `game.Loaded` (Creator Docs: "Keep
  ReplicatedStorage lean"). `Assets.CombatReleasePreview` (684 instances, 508 meshes, review-only and never shown)
  goes to every client; moving it to ServerStorage is an easy win. Moving the glassy and flyer models out and
  sending them on demand is the bigger version; it changes how every presenter finds its models.
- **PlayerGui templates:** ~5.8k template instances are cloned into PlayerGui at spawn (perf report). Building
  screens on first open (Docs: "Load UI panels when first needed") would cut join work further.
- **A real phone and a live server.** Studio boots the server in the same process; a live join skips that but adds
  real download time. Check `LoadSeconds` on a phone after publishing (it is a Player attribute, so an analytics
  event could log it later).
- **Viewport-to-images** will add its icons through `images:ItemIcons/...` and `HintItems` (agreed with that
  session); the Shop's on-demand group gets the shop-pool icons.

---

# Follow-up 2026-10-22: pictures missing on the first roll (decision 120)

The creator, on a phone: "the first roll I could not [see] any of the pictures until a little bit."

## What was missing, measured

Studio Play, logging every ImageLabel from the moment it is visible to the moment it reports `IsLoaded`:

| Run | Screen | Pictures | Late | Glassy pictures |
|---|---|---|---|---|
| Fresh Studio process (closest to cold), desktop | welcome Kiln reels | 199 | 178 | **0.70-0.80 s** blank (56 px reel cells showing 512 px pictures) |
| Second Play, desktop | welcome Kiln reels | 181 | 153 | 0.16-0.21 s |

Two causes:

1. **Order.** The welcome card's OPEN comes about 1 s after the loading screen closes, but the glassy pictures were
   8th in the Soon tier, behind the 282-image Shop template. Opening the reveal pulled them to the front, but 45
   pictures at 512 px still took 0.76 s.
2. **Preloaded is not ready.** A picture that was preloaded but never drawn took **0.23 s (14 frames)** to show on
   the phone preset, about 40 s after its preload. `PreloadAsync` downloads a picture; it is decoded and kept only
   once something draws it. Phones decode slower and evict sooner.

The pick-screen cards are about 122 px on a 1167x479 window and about 86 px on the Galaxy A06 preset, so they use the
512 px picture. That makes them subject to cause 2.

## Proven practice

| Source | Says | Taken |
|---|---|---|
| [DevForum: ContentProvider doesn't preload ImageLabels](https://devforum.roblox.com/t/contentprovider-doesnt-preload-imagelabels/4039525) (Roblox staff LuigiBurger, 2025-11 to 2026-02) | Preloaded but invisible ImageLabels "are treated as unused and garbage-collected", which cancels the preload. It can't be fixed for now because it conflicts with memory conservation. Pass Instances, not ids. Community workarounds: keep them visible (CanvasGroup at transparency 1, or parent to PlayerGui). | `Preload.keepWarm`: chosen pictures stay parented and drawn (8 px, 99% transparent, behind every GUI). |
| [DevForum: PreloadAsync doesn't preload images (regression thread)](https://devforum.roblox.com/t/contentproviderpreloadasync-does-not-preload-image-or-texture-assets-in-either-assetid-form-or-instance-form-appears-to-be-a-regression/1637450) | Images "don't appear to load when not .Visible or when .ImageTransparency is 1"; 0.999 transparency loads them. | Holder labels are visible at 0.99. |
| [Creator Docs: Improve performance, textures](https://create.roblox.com/docs/performance-optimization/improve) | Memory follows pixel count. Most images need at most 512 px; minor ones should be under 256. Sprite sheets (`ImageRectOffset` / `ImageRectSize`) for many small UI images. | Small slots use 128 px cells from two sprite sheets. |
| [ImageLabel reference](https://robloxapi.github.io/ref-temp/class/ImageLabel.html) | Packing many small icons into one image "can make your experience's image assets load much quicker". | Two downloads instead of 81. |

## What changed

- **Sprite sheets** (`tools/icons/make_sheets.py` in Blender, `tools/icons/write_sheets_config.py`,
  `Config/ItemIconSheets`):
  - two sheets of 128 px cells (2 px margin): glassies (47, 1024x768) and flyers + finishers + machines (34, 1024x640)
  - 0.7 MB for every item, against 7.6 MB for the 512 px set
  - `ItemIcon` shows the sheet cell when the slot is 80 px or smaller: Kiln reels 37-63 px, pick-any tiles 76 px,
    reward cells
  - bigger slots keep the 512 / 1024 px pictures
- **Essential tier:** `images:ItemIconSheets` (two images, run in parallel).
- **Keep warm** (`LoadTiers.KeepWarm`):
  - the sheets, always
  - while `Queued` or `InMatch`: the hand, meaning owned glassies' pictures (up to 16) and the Pop / Jam / Prism loan hand
  - a 3 s linger, so Queued -> InMatch never drops them
- **Preload order:**
  - `owned` now preloads each owned glassy's picture along with its model
  - the loan hand's pictures lead the Soon tier
- **Studio A/B switches:** `workspace.ItemIconSheetsOff`, `workspace.LoadNoWarm`.

## After (Galaxy A06 preset, 705x338)

| Check | Result |
|---|---|
| Loading screen | `LoadSeconds` 5.71. Essential done at 4.89 s; the sheet job took 0.06 s, in parallel, and never on the critical path (the Daily template and the spawn area were). |
| Welcome reels | all 54 glassy pictures come from the sheet (37 px cells). They report loaded in 0.06-0.15 s, the same as the reveal's own frames and glows (up to 0.27 s); it was 0.70-0.80 s. A held sheet on a fresh label: **1 frame**. |
| Hand during the queue | `Queued = true` fills the holder: 2 sheets + 3 welcome glassies + Pop / Jam / Prism = 8. A held 512 px hand picture shows in 1-2 frames, against 14 frames for a preloaded one that wasn't held. After the queue it drops back to the 2 sheets. |
| Memory | the sheets hold about 5.6 MB of texture (RGBA); a full hand adds up to 16 x 1 MB while queued or in a match |

Not covered:
- A true cold start on a real phone. Studio keeps a disk cache, and the welcome reveal can't be clicked through with
  the device preset on (MCP clicks don't land), so the full first match was not played on the preset.
- The 1024 px Large pictures on big PC cards are still loaded when shown. On a 1080p screen the pick cards pass 220 px
  and use them.
