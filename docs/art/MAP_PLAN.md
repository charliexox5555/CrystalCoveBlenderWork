# Map Plan: the lobby (v0.3)

One compact, **linear** lobby: spawn → a walkway lined with **8 arenas** (4 each side) → a **featured arena** at the far end. Everything within ~13 s of walking (16 studs/s). The arenas face the walkway so walking past means watching fights. Built **mostly in Studio from parts**, with a short list of Blender hero pieces.

Four concepts were built and rendered in Blender with the real Clash Stand and glassies, then judged on game flow, looks, thumbnail power, Studio buildability, mobile performance and theme fit. Each folder has the renders, a full `CONCEPT.md` (layout in studs, palette, lighting, Studio vs Blender list, risks) and the `build.py` that made it (`tools/map/concepts/<slug>/`).

| | Concept | Score /60 | One line |
|---|---|---|---|
| 1 | [Toy-Sized Kitchen](concepts/giant_kitchen/CONCEPT.md) (judge's pick) | 49 | Toy-sized on a sunny kitchen counter; arenas on pastel cutting boards along a tea-towel runner |
| 2 | [Glassblower's Boardwalk](concepts/boardwalk/CONCEPT.md) | 44 | Beach plaza and a "Clash Pier" out to sea with a sea-glass bottle lighthouse |
| **3** | **[Crystal Isles](concepts/crystal_isles/CONCEPT.md) (chosen)** | **43** | Floating islands over clouds joined by bridges, crystals underneath |
| 4 | [Kiln Street](concepts/kiln_street/CONCEPT.md) | 36 | Glassblower village street with arenas in courtyards and a furnace chimney |

| Kitchen | Boardwalk |
|---|---|
| ![](concepts/giant_kitchen/aerial.jpg) | ![](concepts/boardwalk/aerial.jpg) |
| **Crystal Isles** | **Kiln Street** |
| ![](concepts/crystal_isles/aerial.jpg) | ![](concepts/kiln_street/aerial.jpg) |

## Chosen: Crystal Isles (user, Oct 13)

The user picked the **sky islands**: clean, easy to navigate, and light on meshes and terrain so the budget goes to the glass fights (DECISIONS 28). Full concept: [concepts/crystal_isles/CONCEPT.md](concepts/crystal_isles/CONCEPT.md).

![](concepts/crystal_isles/aerial.jpg)

**Build plan (L1, prompt: [prompts/02_sky_lobby.md](../prompts/02_sky_lobby.md)):**
1. **Codex + Blender:** 5 island platforms only (lobby 96×56, 3 arena islands 92×46, featured 72×48), each as grass / dirt / rock meshes, flat walkable tops, origin at the top centre. Exported to `assets/blender/map/sky/`.
2. **You:** back up the place, import the 5 FBX files.
3. **Codex + Studio:** clear the old place (keep code, glassies, ClashStand, audio, icons; move old trees/props to `ServerStorage.LegacyKit`), place the islands, invisible collision, placeholder bridges, 7 arena stands (hooks at ±3), tagged queue pads and lobby spots, lighting, a fall-back teleport.
4. **You:** fences, trees, decor. **Later:** crystals, clouds, Kiln, shop, signs (Blender kit list in CONCEPT.md "Pieces").

**Watch-outs from the review:** falling off (fall teleport + fences), the featured pad sits at the ~14 s walk limit (grow with wider islands or a second row, not a 4th arena island), glowing crystals must not compete with the glassies (keep them away from pens, never Glass material), side-by-side pens share effects (keep shard VFX local).

### Other concepts considered

The judge's pick was the Toy-Sized Kitchen (best layout and theme fit, easiest pure-parts build); the boardwalk had the best spawn view. Both write-ups stay in `concepts/` for reference.

## Game-wide finding: glassies are too small at true scale

All four concepts showed it: glassies are ~2.5 studs, hanging ~10 studs up under a 17-stud stand, so they read as specks from the walkway. Fix (DECISIONS 30, Proposed): show glassies **1.75× bigger** in arenas on 7-stud strings, hooks moved from ±1.5 to ±3 on the crossbar (`Balance.Motion`). Codex tunes the exact scale by eye in F1. Floating name + hearts labels above running fights also help spectators.

## Next step

L1 (sky lobby) from `docs/prompts/02_sky_lobby.md`, then F1 (fight prototype) on the placed stands.
