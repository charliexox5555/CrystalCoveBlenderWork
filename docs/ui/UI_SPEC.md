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
| Battle HUD (HP cards, VS, centered meter, screen-wide hold) | M1 | Implemented; real-phone approval pending |
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

## M1 refinement

User requested screen-wide holding and a centered timing bar, then authorized an image-led HUD polish. Visual reference and its exact generation prompt are in `assets/concepts/ui/m1_battle_hud_reference.png` and `m1_battle_hud_prompt.txt` (built-in image_gen). The live HUD uses native Roblox components: compact dark glass cards, viewport portraits from the approved meshes, type glyphs, thin HP rails with delayed damage trails, a white diamond-tipped needle and a full-width fading caption backdrop. Theme.Battle derives its compact skin from the existing Theme palette; Montserrat and the cyan/violet edge remain. The generated scene is illustrative and does not replace the approved Blender models.

Mobile holds anywhere on the play area; mouse / Space and gamepad A / R2 remain supported. Holding during rebound is buffered into the next timing window. The final shatter's physical fragments are client-only and bounce against the arena floor before fading. Real-phone feel and audio approval remain pending.
