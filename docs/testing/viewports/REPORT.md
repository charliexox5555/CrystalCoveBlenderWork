# Item pictures instead of live viewports: report (Oct 21 2026)

Plan and research: [AUDIT.md](AUDIT.md). Decision 113 (Proposed).

## What changed

**Icons.**
- 76 items rendered in Blender at 1024 px, downscaled to 512 px, and uploaded to group 11116787:
  - 44 glassies (the dormant legacy ones too)
  - 13 flyers (with No Flyer's pad)
  - 13 finisher stills
  - the 6 Kilns / crate machines
- Ids in `src/shared/Config/ItemIcons.luau` (`Small`, `Large`).
- Records: `assets/icons/items/roblox_assets*.json`.

**Same look as the viewports.**
- `tools/studio/dump_portraits.luau` builds every portrait the way the game does (`GlassyPortrait`,
  `CosmeticPortrait`, `ItemPresentation.crate`, finisher stills from `FinisherFX`). It saves the parts (CFrame, size,
  colour, material, transparency) and the portrait's own camera to `assets/icons/items/source/portraits.json`.
- **Meshes come from the repo FBX exports.** Every in-game MeshId (731) is matched to the FBX object it was imported
  from. Studio fingerprints each mesh (EditableMesh triangle count and bounds), and
  `tools/blender/index_fbx_meshes.py` indexes 4,890 FBX meshes. 728 match exactly; 3 that EditableMesh can't open
  match by name and proportions. Map: `assets/icons/items/source/mesh_map.json` (`tools/icons/match_meshes.py`).
- **Render.** `tools/blender/item_icons.py` rebuilds each portrait headless with the shared icon rig (`render_icon`,
  now with an optional camera) and tuned glass / neon materials.
- **Calibration.** Against a Studio capture of the live portraits (`captures/live_viewports_reference.jpg`):
  - Glass reads pale and bright, as under the viewport's bright ambient.
  - The FBX depth axis is mirrored (Glass Dragon's belly plates face front, as in Studio).

**Code.**
- `UI/Components/ItemIcon` mounts the icon into the portrait's slot (same name, layout, constraints and children).
  It picks 512 or 1024 by on-screen size, and offers `silhouette()` for Collection's undiscovered look.
- `GlassyPortrait.new`, `CosmeticPortrait.new`, `ItemPresentation.portrait` and `ItemPresentation.crate` try the
  icon first; `live = true` keeps the viewport. No icon → viewport, so new drops still show.
- Kept live:
  - the Inventory and Collection detail panes
  - the catalog preview pane
  - the single-pull Kiln reveal card
  - the Kiln opening stage
  - the Shop crate machines
- Studio A/B switches: `workspace.ItemIconsOff = true` (everything live again), `workspace.ItemIconsTest = "<id>"`.

## Results

### Side by side (Studio Play, `captures/`)

Each pair is the same screen, same session: `workspace.ItemIconsOff = true` (before) and icons (after).

| Screen | Before | After | Notes |
|---|---|---|---|
| Inventory, desktop | `inventory_before.jpg` | `inventory_after.jpg` | Same angle, tint and size. The detail pane stays live. |
| Inventory, iPhone 17 Pro | `phone_iphone17pro_inventory_before.jpg` | `..._after.jpg` | Crisp at phone size. |
| Shop, Featured | `shop_featured_before.jpg` | `shop_featured_after.jpg` | Cards and bundle slots. Gumball's centre reads brighter in the icon (see below). |
| Shop, Kiln page | `shop_kiln_before.jpg` | `shop_kiln_after.jpg` | Prize carousel; the two Kilns stay live. |
| Kiln 10-pull, mid-spin | `kiln_10pull_reels_before.jpg` | `kiln_10pull_reels_after.jpg` | **Before, most reel tiles were blank while spinning**: each new tile had to build its model. Icons fill every tile. |
| Welcome card | | `welcome_card_after.jpg` | The Coin Kiln as an icon. |
| Calibration | `live_viewports_reference.jpg` | | Large live portraits used to tune the renders. |

### Measured (same session, alternating, creator's Mac)

| Measure | Viewports | Icons |
|---|---|---|
| Inventory open, worst frame (pass 1, placeholder icon) | 129–134 ms | 105–110 ms |
| Inventory open, worst frame (pass 2, real icons; Studio busier) | 181–207 ms | 161–177 ms |
| Shop open, worst frame (pass 1) | 200–211 ms | 156–177 ms |
| Shop open, worst frame (pass 2) | 284–307 ms | 238–252 ms |
| Instances with Inventory open | ~67,850 | ~67,100 |
| Instances with Shop open | ~69,100 | ~67,800 |
| 10-pull reels: worst frame / frames over 20 ms | 105–114 ms / 9 | 75–78 ms / 4–5 |
| 10-pull reels: parts in PlayerGui at peak | 621–661 | 213 |

- **Opening is 12–20% faster on this Mac.** The steady frame barely moves here, because a static viewport costs about
  the same as an image once drawn. On phones the saved build work and parts matter more.
- **`GraphicsTexture` memory didn't change measurably** within one session (176.2 MB either way). The engine keeps
  textures it has loaded.
- **Not measured: a real phone or a fresh session's texture memory.** Worth checking with the Developer Console on a
  phone (Memory → GraphicsTexture).

### Found along the way

**Glass Phoenix's body mesh doesn't load in game.**
- Mesh 89543800857593 reports "Asset is not approved for the requester" in Studio's output. EditableMesh can't read
  it either.
- The icon was rendered from the repo FBX (`glassies/glass_phoenix/v4/glass_phoenix_body.fbx`), so the picture is
  complete. The live model in fights may be missing its body until the asset is approved or re-uploaded.
- Worth checking on the Creator Dashboard.

## Not done / next

- **Creator review of the side-by-sides.** Live viewports that remain and could also become images if preferred:
  - the Shop's crate machines (idle animation)
  - the glassy detail panes (living-glassy idle)
- **Gumball and a few neon-heavy finisher stills render brighter than their viewport.** Roblox draws Neon flat in
  viewports. Lowering `LOOK.neon_emission` in `tools/blender/item_icons.py` and re-rendering those keys would fix it
  (`--keys finishers_gumball ...`, then `tools/icons/make_small.sh` and the uploader; the uploader skips unchanged
  files).
- **New items:**
  1. Run `tools/studio/dump_portraits.luau` (Play, Client) for the new keys.
  2. Fingerprint any new meshes in Edit (`MODE = "fingerprints"`) and run `tools/icons/match_meshes.py`.
  3. Render, upload, resolve the decals (InsertService:LoadAsset → Decal.Texture), then
     `python3 tools/icons/write_config.py assets/icons/items/image_ids.json`.

  Until then the item shows its live viewport.
- **Loading** (with loading-tiers; `Config/LoadTiers`):
  - the welcome card's Coin Kiln icon is Essential
  - glassy icons are Soon
  - the rest of the Small set is Later
  - opening the Shop, Profile or Collection pulls them forward
  - a payload naming an item fetches its icon (`HintItems`)
  - 1024 px icons load only when a big slot shows them
