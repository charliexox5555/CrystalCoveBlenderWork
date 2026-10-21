# ViewportFrame audit (Oct 21 2026)

A playtester said the 3D item previews in menus cost a lot and that loading all of them isn't good. The creator asked
for high-quality PNGs that look good up close wherever a live 3D view isn't needed, and for the approach to be backed
by research and measurement rather than guesses. This file has the research (1), the inventory of every viewport (2),
the Studio measurements (3) and the plan per use (4). Results after the swap are in [REPORT.md](REPORT.md).

## 1. Research: is pre-rendering the proven approach?

### What a ViewportFrame costs

- **Each viewport is its own render.** It is a separate camera render into an off-screen texture, then drawn as an
  image. A reply in the official ViewportFrame release thread puts it this way: "It's similar to an ImageLabel if
  it's static. Updating ViewportFrame is more expensive and requires switching render targets"
  ([ViewportFrame Release](https://devforum.roblox.com/t/viewportframe-release/206476)).
- **Fixed lighting and lowest-quality glass.** The same release post lists the limits we see in our portraits:
  - fixed lighting (`Ambient`, `LightColor`, `LightDirection` only)
  - no shadows or post effects
  - Neon and Glass "rendered on lowest quality"
  - particles, beams and lights don't render (the reason `FinisherStill` exists)
  - the camera render target is capped at 1024x1024
  - anti-aliased item edges show an outline
- **No official count limit, but the community consensus is clear.** Roblox docs list ViewportFrames for "3D models
  of items in an inventory menu" ([Viewport frames guide](https://create.roblox.com/docs/ui/viewport-frames)) and give
  no performance limit. DevForum reports:
  - FPS drops with as few as ~10–25 inventory viewports
  - hidden or closed viewports still cost frames
  - spinning many items is costly
  - answers converge on "ImageLabels for anything static; cap live viewports; create them only when shown"
  - Sources: [How much do ViewPort Frames affect performance?](https://devforum.roblox.com/t/how-much-do-viewport-frames-affect-performance/376225),
    [How to fix Lag with ViewportFrames](https://devforum.roblox.com/t/how-to-fix-lag-with-viewportframes/3112260),
    [How to optimize viewport frames?](https://devforum.roblox.com/t/how-to-optimize-viewport-frames/2718794),
    [Laggy viewport frames problem](https://devforum.roblox.com/t/laggy-viewport-frames-problem/4015112),
    [Render Images in Bulk](https://devforum.roblox.com/t/render-images-in-bulk/3166471)
- **Our viewports are the expensive kind.** Many hold moving parts, and a moving viewport re-renders every frame:
  - living glassies (lid wobble, fish swim)
  - crate machines with a RenderStepped idle loop
  - Kiln reels that rebuild a WorldModel each time a tile scrolls in
  - Each viewport also holds a full clone of the item's parts (5–40 instances).

### How collectors show hundreds of items

- **Pre-rendered icons.** Large-inventory games use pre-rendered icons; live viewports appear only for the one item
  being inspected.
- **Bulk-rendering pipelines exist for this.** The open-source [modelrender](https://github.com/OttoHatt/modelrender)
  pipeline (Blender render, downscale, upload, JSON of ids) exists because "ViewportFrames aren't a scalable
  solution".
- **DevForum advice agrees.** Threads on pet icons recommend bulk Blender renders with one shared lighting setup
  ([Pet Icons/Renders](https://devforum.roblox.com/t/pet-iconsrenders/267302),
  [Getting pictures of models](https://devforum.roblox.com/t/getting-pictures-of-models/264570)).
- **Caveat:** no public source confirms the exact pipeline of a specific top game. This is the consistent community
  practice, not a published spec.

### Image memory and size

- **Memory follows pixel count, not file size.** Roblox's
  [Improve performance](https://create.roblox.com/docs/performance-optimization/improve) guide says graphics memory
  depends on the number of pixels:
  - a 1024x1024 texture uses 4x the memory of a 512x512 one
  - images are transcoded to a fixed format, so file compression doesn't help
- **512 is enough unless an image fills a lot of the screen.** The same guide says to limit pixels: "Unless an image
  is occupying a large amount of physical space on the screen, it usually needs at most 512x512 pixels."
- **Textures stream in.** The engine starts with lower-quality textures and ramps up "based on available device
  memory, distance from the camera, amount of screen-space that the texture takes up".
- **Upload cap.** Roblox texture maps top out at 1024x1024
  ([Texture specifications](https://create.roblox.com/docs/art/modeling/texture-specifications)). 1024 is the most a
  hero image can usefully be.
- **Upload each image once and reuse the id.** The guide warns that duplicate uploads load the same content twice.
- **Sprite sheets.** The guide suggests sheets with `ImageRectOffset`/`ImageRectSize` "to load many smaller UI
  images as a single image". A sheet helps when many small images always show together (fewer requests and draw
  calls). It hurts when only some are on screen, because the whole sheet's pixels load for one tile.
  - Our grids show a player's own items, a different subset each time.
  - Our icons are 512, the size the guide gives for most UI, so 4 per 1024 sheet at most.
  - So single images, measured below. A sheet stays an option if draw calls show up.

### Alternatives considered

- **`EditableImage`:**
  - can draw pixels at runtime, but can't render 3D
  - Roblox calls editable assets "currently expensive for memory usage", with strict client budgets
    ([EditableImage](https://create.roblox.com/docs/reference/engine/classes/EditableImage))
  - Not useful here.
- **`CaptureService`:**
  - takes full-screen user screenshots and video for the player's gallery
    ([CaptureService](https://create.roblox.com/docs/reference/engine/classes/CaptureService))
  - can't capture a single ViewportFrame or bake icons
  - Not useful here.
- **Fewer or cheaper viewports (pagination, freeze cameras, fewer parts):**
  - helps, but still pays a render target per item
  - still shows Roblox's lowest-quality glass, which is the opposite of "look good up close"

### Conclusion

**Use a mix.**

- **Pre-rendered images for everything static and repeated:** grids, tiles, carousels, reel tiles, reward cells,
  cards and portraits.
  - 512 px for tiles.
  - 1024 px only where one image fills a large part of the screen (roll cards, Featured cards, the 10-pull reveal
    cards on tablets), switched by on-screen size.
- **One live viewport where motion is the point**, created when shown and destroyed when closed:
  - the item detail pane (living-glassy idle, effect preview, turn preview)
  - the single-pull Kiln hero reveal
  - the Kiln opening machine

Render the images in Blender through the shared icon rig, with the game's own portrait camera. They match the
viewports' angle and tint, with real glass shading instead of the viewport's lowest-quality glass.

## 2. Inventory

All live viewports are built by three helpers: `GlassyPortrait.new`, `CosmeticPortrait.new` (finishers show a
frozen frame from `FinisherStill`) and `ItemPresentation.crate` (Kilns and crate machines). The other listed modules
only move, fade or frame those viewports: `MatchKit`/`Motion` (tween property lists), `KilnFire` (heat scale on the
Kiln stage), `CrateFraming`/`CrateMachine` (camera fit and idle loop), `PrizeCard` (holds a portrait). `BundleStage`
is a 3D stage in the world, not a viewport.

| Screen | What | On screen at once | Moves? |
|---|---|---|---|
| Inventory, Glassies tab | tile portraits | 36–38 (every owned and unowned glassy) | living glassies idle (lid wobble, fish swim) |
| Inventory, Glassies tab | detail pane (`InfoPortrait`) | 1 | living idle |
| Inventory, Finishers / Flyers tabs (`CosmeticCatalog`) | tile portraits | 12–13 | no |
| Inventory, Finishers / Flyers tabs (`CosmeticCatalog`) | detail pane | 1 | yes: effect preview, turn preview |
| Collection | tile portraits | ~44 (unowned as dark silhouettes) | living idle |
| Collection | detail | 1 | living idle |
| Profile (Glassies / Finishers / Flyers) | tile portraits | up to the whole category | living idle |
| Shop, Featured | 4 daily cards | 4 | no (cards bob as a whole) |
| Shop, Featured | bundle showcase slots | 3 | no |
| Shop, Kiln / crate pages | machine portraits | 2 per page | yes: idle loop every frame |
| Shop, Kiln / crate pages | prize carousel | 5–7 visible (cache grows to the pool size) | no |
| Shop, Kiln / crate pages | View All pool grid | whole pool (~36) | no |
| Kiln opening | Kiln/machine stage | 1 | yes: heat, lid, fire |
| Kiln opening | reels (1, 3 or 10 reels) | 10-pull: 10 reels × ~5 tiles | yes: the tile ring rebuilds a model each time a new item scrolls in |
| Kiln opening | reveal cards | 1, 3 or 10 | single card: the hero moment |
| Match selection | roll cards | 3 | no |
| Match selection | Pick Any grid | all owned | no |
| Match selection | Pick Any confirm | 1 | no |
| Results | round history | up to 2 × rounds | no |
| Daily / Playtime rewards | pull cells (machine) | 1–2 per screen, every pull cell built | yes: machine idle loop |
| Welcome card | Kiln | 1 | no |
| Bundle preview | item tiles | 3–4 | no (the stage is in the world) |

On top of what is shown, the lobby keeps **122 ViewportFrames with 807 parts** in PlayerGui at idle. These are
template and prebuilt screens, plus disabled screens that keep their viewports.

## 3. Measurements (Studio Play, creator's Mac, Oct 21)

Method:
- Studio Play, onboarding skipped, all 36 release glassies granted.
- Screens opened through `UIAuditDev`.
- Engine `Stats` (render CPU/GPU, instances, memory tags); frame times from RenderStepped.
- A/B in the same session through the new Studio switch `workspace.ItemIconsOff` (viewports) versus
  `workspace.ItemIconsTest` (one placeholder image for every item, so the icon path is exercised before real icons
  exist). Three alternating repeats.

| Measure | Viewports | Icons | Change |
|---|---|---|---|
| Inventory open: worst frame | 129–134 ms | 105–110 ms | −19% |
| Shop (Kiln) open: worst frame | 200–211 ms | 156–177 ms | −20% |
| Instances with Inventory open | ~68,000 | ~67,150 | −850 |
| Instances with Shop open | ~69,300 | ~67,900 | −1,400 |
| 10-pull reels: worst frame | 105–114 ms | 75–78 ms | −30% |
| 10-pull reels: frames over 20 ms | 9 | 4–5 | about half |
| 10-pull reels: viewports shown at peak | 83 | 33 (stage, reveal) | |
| 10-pull reels: parts in PlayerGui at peak | 621–661 | 213 | −67% |

What the A/B showed:
- **Steady cost of static viewports is near zero on this Mac.** Hiding all 38 inventory viewports didn't change render
  CPU (10.2 vs 10.7 ms). This matches the release-thread note that a static viewport costs about the same as an
  ImageLabel.
- **Render CPU is not usable for comparing screens.** It jumps between ~5 and ~15 ms with lobby activity, whatever
  the UI shows.
- **The cost is in building and animating them.** Every portrait clones the item's parts on open, which makes the
  open hitches above. Animated viewports (reels, machine idle loops, living glassies) re-render every frame.
- **This Mac is a best case.** Phones have far less GPU and memory headroom. The open hitches and part counts are the
  numbers that will grow there.
- **Not measured: per-viewport render-target memory.** Engine memory tags don't break it out.

## 4. Plan per use

**Images (512 px; 1024 px swapped in when the slot is bigger than 220 px on screen):**
- Inventory, Collection and Profile tiles (Collection silhouettes tint the icon dark)
- the `CosmeticCatalog` tiles
- Featured cards and the bundle showcase slots
- the prize carousel and View All
- every reel tile
- 10-pull and 3-pull reveal cards
- roll cards, Pick Any and its confirm
- results history
- Daily / Playtime pull cells and the welcome card (machine icons)
- bundle preview tiles

**Live 3D kept (one at a time, built when shown, destroyed when its screen closes):**
- the Inventory and Collection glassy detail panes (living-glassy idle)
- the catalog detail pane (effect and turn previews)
- the single-pull Kiln reveal card
- the Kiln opening stage
- the Shop's crate machines (2 per page, idle animation is their point; images ready if the creator prefers them)

**Fallback.** An item without an icon in `Config/ItemIcons` keeps its live viewport, so new drops still show.

**Images: how they are made.**
- `tools/studio/dump_portraits.luau` builds each portrait the way the game does and exports its parts, colours,
  materials, camera and meshes.
- `tools/blender/item_icons.py` rebuilds them in Blender and renders them headless with the shared icon rig
  (`render_icon`: key, rim and fill lights, transparent background, Standard view transform). It uses the portrait's
  own camera: same angle and framing (glassies front-on at FOV 30, flyers and finishers three-quarter at FOV 35),
  same colours.
- 1024 masters, 512 downscales. Uploaded once through Open Cloud; ids in `Config/ItemIcons`.

**Code.**
- `Components/ItemIcon` mounts an ImageLabel in the portrait's slot (same layout, constraints and children).
  `GlassyPortrait.new`, `CosmeticPortrait.new` and `ItemPresentation.portrait/crate` try it first; `live = true`
  skips it.
- Reels keep spinning: only `Image` changes when a new item scrolls in.
- Rarity glows, the landing pop, dimming, pop-ins and the Featured bob keep working because they act on the portrait
  object, whatever its class.

**Checks after the swap** (REPORT.md):
- the same A/B with real icons
- GraphicsTexture memory with real icons, since 512 px images cost more texture memory than a small viewport's
  render target
- before/after captures per screen, desktop and a phone preset
