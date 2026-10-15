# Codex prompt: build the Stained Glass UI templates in StarterGui

Paste everything below the line into Codex (Studio open, Rojo connected, Studio MCP on).

**You (the creator) first:** upload the images so Codex can use them:
1. `git pull`. In Studio: **View → Asset Manager → Bulk Import**, select every PNG in `assets/ui/stained_glass/png/` (all subfolders).
2. Tell Codex "UI images uploaded". Codex reads the new asset IDs from the Asset Manager / `Images` folder and records them.

---

The UI has a new, approved theme: **Stained Glass** (DECISIONS 49). Build it as **editable ScreenGui templates in StarterGui** so I can look at them and restyle things myself. **Don't do the multi-device scaling/formatting pass yet**; I'll give the go for that after I've edited the templates. Do use Scale and aspect ratios from the start.

**Read first:** `git pull`; `docs/ui/UI_SPEC.md` (v0.4 layout notes at the top still apply, the theme is now v0.5); `docs/ui/EDITING_UI.md`; `assets/ui/stained_glass/README.md` (palette, fonts, every asset with its size and SliceCenter); the screen references `docs/ui/v05/01_lobby_hud.png`, `02_inventory.png`, `03_shop.png`, `04_choose_glassy.png`, `05_fight_hud.png` and the kit `00_kit.png`. The Figma page "UI v0.5 — Stained Glass" in the Glass Clash UI file is the source if anything is unclear.

## Rules

- **Images:** I've bulk-imported `assets/ui/stained_glass/png/`. Find the uploaded IDs and write them to `src/shared/Config/UIAssets.luau` (`[assetPath] = "rbxassetid://..."`, e.g. `["button/gem_emerald"]`). If an image is missing, use a Frame in the right colour from the palette as a placeholder, name it the same, and list it in your report.
- **Look:** no `UICorner` anywhere (the theme has cut corners, not rounded ones). Shapes come from the images. Text: **Denk One** for titles/buttons/names (white + lead `UIStroke`), **Nunito** Black/ExtraBold for body and numbers (lead-coloured text on milk-glass plaques). Use the exact palette in the README.
- **Layout:** every size and position in **Scale** (no Offset except tiny nudges), `AnchorPoint` set sensibly, `UIAspectRatioConstraint` on every panel, gem, hex, tile, card and icon (aspect = PNG width / height), `UISizeConstraint` minimums on tappable things, `ScreenInsets = CoreUISafeInsets`. 9-slice images use `ScaleType = Slice` with the README's `SliceCenter`. Lists use `UIGridLayout` / `UIListLayout` + `UIPadding` with Scale values.
- **Names:** clear, stable names for everything (e.g. `ShopButton`, `CoinsAmount`, `GlassyGrid`, `InfoName`, `PullOne`) so I can find and restyle them, and so code can bind to them.
- **Keep the game working:** the current templates and controllers (`LobbyController`, `MatchController`, `MatchScreens`, `LobbyHud`, Kiln/Collection screens) must keep working. Back up the current StarterGui templates to `ServerStorage.UIBackup_v04` first. Then restyle the existing templates in place, **keeping every name/binding the controllers use** (read the controllers and EDITING_UI.md), or add new names and update the bindings in `src/`. Run a quick play test: lobby, open/close Inventory and Shop, a bot match through Choose → Fight → Results.
- Glassy pictures are **ViewportFrames** of the real models (reuse `src/client/UI/Components/GlassyPortrait.luau`).
- No new third-party code, no Toolbox assets, no paid features (Marbles tab and paid items stay disabled / "coming soon").

## Screens (match the references)

1. **Lobby HUD** (`01_lobby_hud.png`): `hex_shop` and `hex_inventory` buttons stacked on the left with their milk label plaques; Coins and Marbles plaques directly under them (display-only, `Active = false`); the big `gem_play` PLAY button bottom-centre with "joins the nearest free arena" above it. Top-right stays empty (player list).
2. **Inventory** (`02_inventory.png`): `window_inventory` panel (aspect 1.773) centred over a dim backdrop; `title_sapphire` banner "INVENTORY" over the top-left band; `close` diamond top-right; tabs Glassies (aqua, active), Flyers (ruby), Finishers (amethyst) as `tab_*` gems; left: scrolling grid of `tile_<rarity>` tiles (ViewportFrame + `name_plaque`), `selected_outline` on the selected tile; right: `pane_dark` info pane with name, type + rarity `tag_*`, stars, `pane_viewport` model, Passive, Power ("fires on its own") and Power/HP/Swing `stat_track` + `stat_fill_*` bars. No levels, sort, search or Equip.
3. **Shop** (`03_shop.png`): same shell, larger (`window_shop`, aspect 1.809, `title_amber` "SHOP"), currency plaques in the header, tabs The Kiln (amber, active), Flyers, Finishers, Marbles; left: `kiln/hero_window` with `kiln/glow` + Kiln model ViewportFrame, "THE KILN", text, **PULL ×1 · 300** (`gem_amber`) and **PULL ×10 · 2,700** (`gem_emerald`), then "IN THE KILN NOW" row of tiles; right: odds pane with six `odds_row_<rarity>` rows (rarity + exact %). Odds are always visible next to the pull buttons.
4. **Choose your glassy** (`04_choose_glassy.png`): title "CHOOSE YOUR GLASSY · <timer>", both players' names + `heart_full` / `heart_broken` in the top corners, three `card_<rarity>` cards (name, model ViewportFrame, type + rarity tags, one-line power), `selected_outline` on the picked card, **REROLL · FREE** (`gem_sapphire`), hint text at the bottom.
5. **Fight HUD** (`05_fight_hud.png`): a **BillboardGui template** above each player (name in Denk One, 3 hearts, glassy tag in its type colour), a power banner (`banner/power_<glassy tint>`) top-centre for ~2 s when a power fires, and damage numbers. Nothing else on screen during the fight.

## Done when

- [ ] All five screens exist as editable templates in StarterGui (fight billboard template in ReplicatedStorage or StarterGui, your call), using the images, fonts and palette, Scale-only, with aspect-ratio constraints.
- [ ] The game still plays end to end; old templates backed up in `ServerStorage.UIBackup_v04`.
- [ ] `UIAssets.luau` filled in; tests pass (`lune run tools/run_tests` and `RunAll` in Studio).
- [ ] Screenshots of each screen in `docs/testing/UI_V05.md` with a list of every template and its main element names; ROADMAP/DEVLOG updated; committed and pushed.

Then stop and tell me what to look at. I'll restyle and give the go for device scaling.
