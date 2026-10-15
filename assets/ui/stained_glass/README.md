# Stained Glass UI kit (UI v0.5)

Theme: every UI piece is **cut glass held by dark lead lines**: jewel-coloured mosaic borders, faceted gem buttons, chamfered (cut) corners, never rounded corners. Matches the Figma page **"UI v0.5 — Stained Glass"** and the screen references in [docs/ui/v05](../../../docs/ui/v05).

- `png/` transparent PNGs at **2×** (upload these to Roblox). `svg/` editable sources.
- **No text or icons are baked into any glass piece.** Buttons, plaques, tabs and panels are plain glass; put text (TextLabels) and icons (`icon/*` ImageLabels) on top in Studio.
- Regenerate or tweak: `npm i @resvg/resvg-js && node tools/ui/stained_glass.mjs` (all shapes and colours are in that file).

## Palette

| Name | Main / light / dark |
|---|---|
| Lead (outlines, text stroke) | `#1F1830` |
| Smoke (dark panes) | `#261D3B`, `#332854`, viewport `#3B2F5E` |
| Ruby | `#E23A55` / `#FF8EA0` / `#9E1D38` |
| Amber | `#F5A524` / `#FFD98A` / `#B26E0B` |
| Emerald | `#22B573` / `#86EDB8` / `#11703F` |
| Aqua | `#1FC2D3` / `#9BF3F8` / `#0F7C88` |
| Sapphire | `#2E6BE6` / `#93BCFF` / `#1A409C` |
| Amethyst | `#8B4FE0` / `#CDAAFF` / `#57299F` |
| Milk glass | `#EEE7D9` / `#FFFFFF` / `#B9AE99` |

Rarity colours: Common milk, Uncommon emerald, Rare sapphire, Epic amethyst, Legendary amber, Mythic = all colours. Types: Fizzy aqua, Heavy amber, Sharp amethyst. Categories: Glassies aqua, Flyers ruby, Finishers amethyst, Kiln amber, Marbles aqua.

## Fonts (both in Roblox's font library)

- **Denk One**: titles, buttons, names over the 3D scene. `Font.new("rbxasset://fonts/families/DenkOne.json")`. White fill + lead `UIStroke` (Thickness ≈ 12% of text size, LineJoinMode Round).
- **Nunito** Black/ExtraBold: body text, numbers, labels on milk glass (lead-coloured text, no stroke). `Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy)`.

## How to use each piece (pixel values are in the 2× PNG)

| Asset | Size (PNG) | Roblox use |
|---|---|---|
| `button/gem_<colour>` | 600×172 | ImageButton, `ScaleType = Slice`, `SliceCenter = Rect(80, 24, 520, 148)` |
| `button/gem_play` | 1040×260 | `Slice`, `Rect(110, 40, 930, 220)` |
| `banner/power_<colour>` | 1200×220 | `Slice`, `Rect(100, 40, 1100, 180)` (power banners) |
| `tab/tab_<colour>_active` / `_idle` | 480×140 | `Slice`, `Rect(70, 24, 410, 116)` |
| `hud/hex_<colour>` | 300×340 | `Fit`, `UIAspectRatioConstraint` 0.882 (Shop = amber, Inventory = sapphire); icon ImageLabel on top, label on `hud/label_plaque` underneath |
| `icon/shop`, `icon/inventory`, `icon/close_x`, `icon/coin`, `icon/marble` | 128 / 128 / 80 / 148 / 148 | separate ImageLabels, `Fit` |
| `hud/label_plaque`, `tile/name_plaque` | 300×88 / 352×88 | `Slice`, `Rect(40, 10, 260, 78)` / `Rect(40, 10, 312, 78)` |
| `hud/currency_plaque` | 460×116 | `Slice`, `Rect(40, 20, 420, 96)`; `icon/coin` or `icon/marble` overlaps the left end |
| `icon/heart_full`, `icon/heart_broken` | 96×96 | `Fit` |
| `button/close_diamond` | 160×160 | `Fit`, with `icon/close_x` on top |
| `tag/tag_<colour>` | 300×80 | `Slice`, `Rect(40, 10, 260, 70)` (type / rarity tags) |
| `tile/tile_<rarity>` | 400×480 | `Fit`, aspect 0.833; ViewportFrame inside, name plaque at the bottom |
| `tile/selected_outline`, `card/selected_outline` | 432×512 / 960×1280 | `Fit`, shown on the selected tile/card |
| `card/card_<rarity>` | 920×1240 | `Fit`, aspect 0.742 (Choose your glassy) |
| `panel/window_inventory` | 3120×1760 | `Fit`, aspect **1.773** (Inventory panel) |
| `panel/window_shop` | 3400×1880 | `Fit`, aspect **1.809** (Shop panel) |
| `panel/title_<colour>` | 760×192 | `Fit`, title banner over the panel's top-left band |
| `panel/pane_dark`, `panel/pane_viewport` | 800×600 / 800×400 | `Slice`, `Rect(60, 60, 740, 540)` / `Rect(48, 40, 752, 360)` (info pane, model frame) |
| `panel/odds_row_<rarity>` | 856×124 | `Slice`, `Rect(110, 20, 830, 104)` |
| `bar/stat_track`, `bar/stat_fill_<colour>` | 600×48 | `Slice`, `Rect(24, 0, 576, 48)`; fill width = stat / max (Scale) |
| `kiln/hero_window`, `kiln/glow` | 2160×760 / 660×600 | `Fit` |
