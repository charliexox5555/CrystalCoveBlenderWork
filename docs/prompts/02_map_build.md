# Map build prompt for Codex (Kilnport + Cullet Yard)

Paste everything below the line into Codex. Blender open with the Blender MCP running, Studio open, `rojo serve` running.

---

Your task is to turn the rough blockout into a polished, professional-looking Roblox map, built in Blender. Take your time, quality matters more than speed here. Work until it's genuinely ready, then hand over to me for import.

**Read first (in full):** `AGENTS.md`, `docs/art/MAP_BLUEPRINT.md`, `docs/art/ART_BIBLE.md`, `tools/map/village_layout.py`, and the blueprint images `docs/art/blueprint_lobby.png` and `docs/art/blueprint_overview.png`. Run `git pull` first. The `Blockout` collection in my open Blender scene was built by `tools/blender/blockout_village.py` from `village_layout.py`; it's the layout to follow, not the final look. The older first-pass map in `assets/blender/map/first_pass` is superseded: don't reuse its layout.

**What "done" looks like**
- A glassblower village called Kilnport on a seaside cliff, and Route 1 (Cullet Yard) below it, exactly matching the positions, sizes and heights in `village_layout.py` (studs; 1 Blender unit = 1 stud). If you think something in the layout should move, tell me and update `village_layout.py` too, so the blueprint and the map stay identical.
- It should look like a top Roblox game map: a cohesive low-poly, flat-shaded style; chunky, readable silhouettes; real detail and variety; no empty flat areas; no floating, sunken, overlapping or z-fighting pieces; clean edges where paths, plazas, walls and cliffs meet.
- **Landmark:** the Great Furnace hall with its 130-stud chimney and giant glass bottle on top is the hero. It should look impressive from spawn, from the arena and from the yard. Glowing furnace mouth, brick detail, banding, maybe a little smoke-stack trim.
- **Village:** proper cottages and shops with doors, windows, chimneys, awnings, signs and trim (not boxes); cobblestone square with the Octagon Arena and two seat rings; market stalls; lamp posts with glass globes; benches, flower boxes, crates, barrels and fences; cliff railings along the sea edge; a harbor with dock and boats below the north-east cliff.
- **Terrain:** sculpted low-poly cliffs (faceted rock faces in layers, not flat walls) down to the sea, rocky shore, grassy variation, hills and tree lines framing every non-sea edge, and a smooth, walkable ramp from the Kiln Gate down to the yard.
- **Cullet Yard:** sorting lane with colour-coded recycling bins, crates and pallets, conveyor belts leading toward the Crusher, the Halfway Hut, wild areas as inviting open pockets, and the Cullet Pit: Rusty's raised platform ringed by big sparkly mountains of crushed coloured glass, with the entrance and lift side kept open.
- **Clash Stands:** reuse the approved swing-set stand and octagon pen (`assets/blender/map/clash_stand.blend`); place them at every stand position in the layout, facing the right way.

**Colour, materials and textures**
- I want it colourful and polished. Give every piece a deliberate colour from a cohesive palette (warm cream walls, terracotta/blue/green roofs, honey wood, brick-red furnace, rich greens, sea blues, sparkly cullet colours). Keep differently coloured parts as separate objects or material slots so they can also be adjusted in Studio.
- Use textures where they clearly add quality (cobblestones, brick, wood planks, rock strata, roof tiles), as small tiling textures or a shared atlas, low-res and stylized to fit the low-poly look. Keep texture count and sizes small for phones. Note the texture choices in a Proposed decision (this updates DECISIONS #14).
- Glow: furnace mouth, windows, lamp globes and the tower bottle should read as emissive (in Studio: Neon or SurfaceAppearance plus lights).
- Only glassies, lamp globes, the tower bottle and cullet should look glossy; everything else matte.

**Building it**
1. Build a reusable kit first (`assets/blender/map/kilnport/kit_kilnport.blend`): every piece listed in MAP_BLUEPRINT section 5, each within the ART_BIBLE triangle budgets, origin at its base centre.
2. Assemble the layout (`layout_kilnport.blend`) from linked duplicates, snapped to the blockout positions, then hide the Blockout collection.
3. **Review loop. Repeat until it looks great:** render the spawn view, the aerial view, the yard view and the Cullet Pit view (same cameras as `blockout_village.render_previews`) plus close-ups of the square, the furnace, the cliffs and the ramp. Look at each one critically as an art director: alignment, gaps, floating or clipping objects, empty areas, repetition, colour balance, silhouette and composition. Fix the problems, re-render and compare. Save the final renders to `docs/art/map_renders/`.
4. **Export for Studio** in chunks (village centre, village north, village south, cliffs and harbor, yard west, yard south, Cullet Pit, terrain), each under Roblox mesh limits, with transforms applied. Every chunk must import into Studio **at 1 stud = 1 unit with no rescaling and in the right place**: export with a shared world origin, verify the scale and axis settings, and write `assets/blender/map/kilnport/manifest.json` listing every chunk, its file, its world position and its expected bounding box in studs. The previous first pass imported at 6.4× and 8.53× scale; don't repeat that.
5. Write `assets/blender/map/kilnport/README.md` with exact import steps for me (which files, which import settings), then commit and push, and **stop and tell me it's ready to import**.

**After I import the FBX files into Studio** (I'll tell you), use the Studio MCP to:
- check every chunk against `manifest.json` (position, size, rotation) and fix anything off, so nothing is misplaced, floating, gapped or overlapping;
- apply colours and materials, emissive parts with lights, golden-afternoon lighting per MAP_BLUEPRINT section 4, collision (simple invisible colliders for walkable ground, no collision on decor), and the spawn point facing north;
- place the Clash Stands, trainer, wild-area, repair and gate markers from `village_layout.py` as tagged parts for gameplay;
- walk the whole route with a character (no stuck spots, no falling through), check performance on a phone preset in the Device Emulator, and keep the M1 practice battle working;
- run the tests, update ROADMAP and DEVLOG, commit, push, and tell me what to look at.

Keep the content rules from AGENTS.md (kid-friendly, original designs, no Toolbox models without asking me).
