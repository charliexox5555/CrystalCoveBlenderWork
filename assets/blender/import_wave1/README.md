# Wave 1 imports

17 multi-mesh FBX files: nine glassies and eight sky props. Each glassy bundle includes Body, Details and 16 shards; import one file per glassy. Original split files and source `.blend` files remain in their asset folders.

## Glassies first

1. Save a local copy of the place, then stop Play in Studio.
2. Create a Folder named **GlassClashImports** in Workspace.
3. File → 3D Importer / Import 3D. Import these nine files from this folder, one at a time: `Wave1_milk_bottle.fbx`, `Wave1_pickle_jar.fbx`, `Wave1_glass_cup.fbx`, `Wave1_ketchup_bottle.fbx`, `Wave1_water_jug.fbx`, `Wave1_lemonade_bottle.fbx`, `Wave1_mason_jar.fbx`, `Wave1_hot_sauce.fbx`, `Wave1_crystal_tumbler.fbx`.
4. Preserve separate meshes, names and pivots. Use Studs scale where offered. Do not combine meshes or rotate individual imported pieces. Move each imported Model into Workspace.GlassClashImports; its overall position does not matter. Importer scale mismatches are normalized by the installer against measured bounds.
5. Tell Codex the imports are ready, or run the contents of `tools/studio/install_wave1_glassies.luau` in the Command Bar. It clones complete sets into ReplicatedStorage.Assets.Glassies, restores hang pivots/scale, applies untextured Glass/tints and detail materials, and moves raw meshes into ServerStorage.Wave1ImportedSources. Existing assets are skipped. Missing/duplicate meshes are reported and not installed.
6. Check each assembled portrait, aim/swing, cracks and shatter. The Kiln automatically includes only complete installed non-starter sets and shows their actual normalized odds. Importing only some rarities changes the displayed odds accordingly.

Icons are already rendered at `assets/icons/<id>.png` (512×512 transparent). Upload later if desired; the game can use its 3D portraits meanwhile.

## Sky kit

Import the eight other Wave1 FBX files separately, preserving their mesh groups. Materials/colors are in each sky asset's `manifest.json`: SmoothPlastic, no reflection; cyan/violet/gold accents and off-white clouds. Decorative parts: CanCollide/CanTouch/CanQuery false. Clouds also CastShadow false.

Keep these raw prop models in GlassClashImports until Codex places copies around the existing manual decor. The glassy installer ignores them. Kiln crystal is 18 studs tall; the featured arch is about 27 wide × 26.6 high. Clouds are 11–21 studs wide and belong below/outside the islands. Never rerun the old lobby builder to place them.

Export scripts: `build_sky_kit.py`, `build_collection_wave.py`, `export_wave1_bundles.py`, after loading `glassclash_blender.py`. The builders preserve the open Blender scene. Hollow shard caps use triangle fill to preserve cup interiors. No source starter art was changed.
