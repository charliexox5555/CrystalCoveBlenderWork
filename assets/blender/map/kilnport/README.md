# Kilnport + Cullet Yard — import handoff

Ready for the **user's Studio import**. The open Blender file is `layout_kilnport.blend`.
The original open scene is preserved in `blockout_reference.blend`; its Blockout collection is hidden in the final layout. The superseded first-pass map was not changed.

## Files to import

Import these eight FBX files from this folder, one at a time:

1. `KP_terrain.fbx`
2. `KP_cliffs_harbor.fbx`
3. `KP_village_centre.fbx`
4. `KP_village_north.fbx`
5. `KP_village_south.fbx`
6. `KP_yard_west.fbx`
7. `KP_yard_south.fbx`
8. `KP_cullet_pit.fbx`

Keep `kilnport_atlas.png` and `kilnport_cobble.png` beside the files. Both images are also embedded in each FBX that uses them. Import the complete models, preserving their separate meshes and materials.

## Exact Studio settings

Open **File > Import** and choose the first FBX. In the import preview, use:

| Setting | Value |
|---|---|
| Import Only as Model | On |
| Upload to Roblox | On; choose the owner of the Glass Clash experience |
| Insert Using Scene Position | **On** |
| Set Pivot to Scene Origin | **On** |
| Scale Unit | **Stud** |
| Scale / custom scale factor | **1** |
| World Up | **Top** |
| World Forward | **Front** |
| Merge Meshes | Off, if displayed |
| Import textures | On |

Use these same settings for every file. Do not choose **From File**, meters, centimeters, or an automatic fit/resize option. Do not center individual chunks, drag them to the camera, or scale their models after import. Every exported node has identity transforms and every vertex is already expressed in stud-sized world coordinates.

These settings follow Roblox's [Blender import/export guidance](https://create.roblox.com/docs/art/blender) and the [Importer reference](https://create.roblox.com/docs/studio/importer). The axis conversion is already baked into these FBXs: **Blender (X,Y,Z) → Roblox (X,Z,-Y)**. No extra 90° rotation is needed.

All eight **model pivots belong at Roblox `(0, 0, 0)`**, with rotation `(0, 0, 0)` and scale `1`. Their geometry is intentionally offset from that shared pivot. Their bounding-box centres are different from their pivots: do not set model Position to the bounding-box centre.

### Quick size check in the import preview

Expected overall model dimensions, in Roblox **X / Y / Z** studs:

| Chunk | X | Y (height) | Z |
|---|---:|---:|---:|
| Village centre | 351.316 | 26.670 | 143.060 |
| Village north | 349.322 | 160.000 | 103.799 |
| Village south | 361.634 | 45.449 | 207.947 |
| Cliffs + harbor | 723.527 | 70.800 | 689.328 |
| Yard west | 303.528 | 33.209 | 432.229 |
| Yard south | 552.649 | 33.344 | 205.107 |
| Cullet Pit | 139.826 | 22.500 | 125.598 |
| Terrain | 750.000 | 130.000 | 696.245 |

The north chunk includes the entire **130-stud chimney + 30-stud bottle**. Village ground is Y=0; yard ground Y=-20. The approved main stand remains 17.8 studs high. The terrain's height also includes the western hills and their rock foundations. Exact per-mesh and per-chunk minima, maxima, centres and sizes are in `manifest.json`.

After importing all eight, leave them in Workspace and tell Codex that the import is complete. The old map can visually overlap the new map until the next integration pass; keep the imports grouped and do not delete the old map to make space.

## What is included

- A 57-asset reusable kit in `kit_kilnport.blend`, laid out in a showroom grid. Each individual asset's origin is at its base centre. The approved Clash Stand is included unchanged in shape.
- A layout assembled with shared mesh data: detailed shops/cottages, striped stalls, garden lots, plaza seats, lamps, furnace and glass bottle, layered coastal cliffs, ramps, harbor stairs/boats, yard machinery, recycling bins and glass mounds.
- Two small original textures: a 512×512 detail atlas for timber/brick/roof/rock, and a 256×256 repeating cobble tile. Matte environment surfaces remain separate from glossy glass and emissive parts. Colours and material names are recorded in the manifest.
- Eight final renders in `docs/art/map_renders/`, plus an art-review record.
- Eight chunks, 799 meshes, **181,222 triangles total**; largest exported mesh **4,704 triangles**. No mesh exceeds the 8,000-triangle terrain budget. Geometry is grouped by material and spatial area for import.

The layout data is unchanged. The final build follows its documented facing convention (`90° = west`, `-90° = east`). The blockout helper used the opposite sign; this was corrected in final art so shop doors actually face the square. Each anchor and original facing value is recorded in `anchors.json`.

## Validation completed

- All building and stand anchors match `village_layout.py`.
- 1,782 ground probes along all defined paths, at their centres and ±2-stud avatar-width offsets: no missing hits; maximum height error 0.000033 studs.
- All eight FBXs re-imported into a fresh Blender scene: every mesh found, maximum bounding-box error **0.0000382 studs**.
- Independent raw FBX parsing confirms exact stud-sized vertex bounds, the X/Z/-Y axis mapping, and identity node transforms. FBX unit metadata is 100 cm and kept separately with **FBX Unit Scale**; explicitly choosing **Stud** is what makes raw units equal studs in Studio.
- Lune and existing Studio tests: **28 passed, 0 failed**. No gameplay source or existing Studio map was modified.

This validates the files before upload. Actual Studio import, collisions, phone performance and character traversal will be checked after your import, as requested.

## Next integration pass

Codex will compare imported sizes/positions/rotations to the manifest, organize the new map while preserving the old one, set colours/materials/Neon lights, add golden-afternoon lighting and sea water, and create simple collision geometry and gameplay markers. The huge Blender preview sea, preview lights/camera and hidden Blockout are intentionally excluded from FBX. Sea water belongs at Roblox Y=-60.

For textured meshes, keep the imported albedo image and use white tint unless deliberately recolouring it; the atlas already contains its colour. For plain meshes, apply the manifest's hex colour. `window` and `glow` are Neon candidates; `lampglass`, the tower bottle and cullet get glossy/glowing treatment. These are still art meshes: trainer interactions, repair, lift travel and gates await their gameplay implementations.

The integration pass also includes a full character route walk, phone-preset checks, M1 practice-battle regression and publication handoff.

## Rebuilding

Run `tools/blender/build_kilnport.py` in a clean copy of `blockout_reference.blend` through Blender MCP. It loads `tools/map/village_layout.py`, creates the kit/layout and saves both files. Load `tools/blender/glassclash_blender.py` first per repository workflow.

Run `tools/blender/export_kilnport.py` in the saved final scene to perform layout probes, export all chunks, re-import them and inspect their raw FBX data. Render individual shots with Blender background mode and `tools/blender/build_kilnport.py -- render <shot>`; shot names are `spawn`, `aerial`, `yard`, `cullet_pit`, `square`, `furnace`, `cliffs`, `ramp`.
