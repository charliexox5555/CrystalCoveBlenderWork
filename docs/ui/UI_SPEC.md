# UI Spec

- **Mockups:** [Figma — Glass Clash UI](https://www.figma.com/design/r3guIIk5deo7vNxLzJN0RZ) (page "Glass Clash UI")
  - Glassies screen (inventory): node `2:268`
  - Battle screen: node `2:657`
  - Style kit (buttons, glassy tiles, icons, colours, fonts): node `2:2`
- **Style rules:** GAME_DESIGN 12.1 ("crisp glass").
- **Tokens in code:** `src/client/UI/Theme.luau`. Keep it in sync with Figma.

The pink "NOTE" labels in Figma are annotations, not UI. The stand, glassies and backgrounds in the mockups are placeholders for the 3D game view.

## Components (build once in `src/client/UI/Components`, reuse everywhere)

| Component | Notes |
|---|---|
| `Panel` | Dark glass gradient, 2 px cyan→violet edge (`UIStroke` + `UIGradient`), radius 20, optional shard header |
| `Button` | Variants Green/Red/Yellow/Blue/Purple, label, press animation, sound |
| `GlassyTile` | Rarity tint + edge, glassy icon, level text, equipped badge, selected glow, Rainbow shimmer |
| `ProgressBar` | HP, XP and stat bars; label inside |
| `Pill` | Tags (type, rarity, level) |
| `CurrencyPill` | Icon + amount + green "+" |
| `Popup` | Big pop-up text (PERFECT!, damage numbers) over the 3D scene |
| `Toast` | Short messages ("Catch it before it shatters!") |

## Screens

| Screen | Milestone | Status |
|---|---|---|
| Battle HUD (HP cards, VS, meter, HOLD, Cork) | M1 | Mockup done |
| Starter pick | M2 | To design |
| Glassies (inventory + details) | M3 | Mockup done |
| Index | M3 | To design |
| Crates (with odds) | M3 | To design |
| Quests | M5 | To design (reference: purple quests image) |
| Shop | M5 | To design (reference: yellow store image) |
| Shatter FX / Fills | M4 | To design |
| Tournament bracket board + Pick the Winner | M4 | To design |
| Loading screen | M5 | Concept in RESOURCES 6 |

## Rules

- Interactive UI in `ScreenInsets = CoreUISafeInsets`. Keep the bottom-left (thumbstick) and bottom-right (jump) corners clear outside battles.
- Scale-based layout + `UIAspectRatioConstraint` + `UISizeConstraint` minimums. Test in the Device Emulator (phone presets) before calling a screen done.
- Gamepad: every button selectable; B / Escape closes the open panel.
