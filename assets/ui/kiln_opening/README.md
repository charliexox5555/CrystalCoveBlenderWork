# Kiln opening UI effects

Created with the built-in imagegen tool on 2026-10-15. Original project artwork, transparent PNGs; no external case-opening art was copied.

| File | Roblox ID | Use |
| --- | --- | --- |
| `flame.png` | `92506654265820` | Small flame confined to the UI kiln's chamber. |
| `reveal_burst.png` | `124265483010783` | First reveal experiment, retained with the V1 backup. Replaced after creator feedback by the existing Stained Glass `kiln/glow` texture. |

The final opening uses the native kiln model inside a ViewportFrame, the original flame, existing Stained Glass card art/soft glow, and UI ember particles. Nothing is added to the world. Asset mapping: `src/shared/Config/KilnAssets.luau`.

## Generation prompts (built-in mode)

**flame.png**

> Use case: stylized-concept. Asset type: transparent PNG VFX sprite for a Roblox glass-collecting game's UI kiln-opening animation. Create ONE isolated upright plume of magical molten glass fire, centered, broad flowing flame tongues rising from a small elliptical base, bright creamy yellow core, saturated amber and orange exterior with a few ruby edges, glossy faceted shapes and soft bloom, toy-like premium game UI illustration matching a stained glass jewel theme. Clear readable silhouette, warm beautiful energy, translucent glow fading to fully transparent around perimeter, square composition with generous transparent margins. No kiln, no background, no text, no frame, no bottles, no characters, no sheet or collage. This single sprite will be scaled and layered over a kiln viewport.

**reveal_burst.png** (superseded experiment)

> Use case: stylized-concept. Asset type: one transparent square PNG reveal VFX sprite for Roblox Glass Clash UI. A radiant circular burst of magical glassmaking energy, soft creamy amber glow at its empty center, fine tapered golden rays extending outward and several small glossy faceted diamond shaped sparks in aqua and amber. Rich stained glass jewel game aesthetic, polished toy-like, attractive readable silhouette. Symmetrical broad halo ring, centered in square with fully transparent fading perimeter and large clear margins. No object in center, no kiln, no text, no background, no frame, no characters, no sheet. Used behind upright collectible bottle reward cards as an additive-looking reveal glow.
