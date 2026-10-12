# M1 Studio import

These four bundles package the approved saved Blender art without changing it:

- `M1_clash_stand.fbx`: 55 stand meshes.
- `M1_pop.fbx`: Body, 16 shards, red cap, five bubbles (23 meshes).
- `M1_jam.fbx`: Body, 16 shards, gold lid (18 meshes).
- `M1_prism.fbx`: Body and 16 shards (17 meshes).

In the open Glass Clash place, choose **File > Import**, select all four FBX
files, and use these settings:

- Creator: the experience's owner.
- Upload to Roblox, Add to Workspace, Import Only As Model: enabled.
- Scale Unit: Studs. Merge Meshes: disabled.
- Set Pivot to Scene Origin, Use Imported Pivot, Anchored: enabled.

Leave the models in Workspace, without renaming or moving individual meshes.
All glassy components use the same hang-point origin. Intact bodies and their
shards overlap until the Studio setup separates the Shards folder from the
visible assembly. Final colors and materials are assigned in Studio.

`manifest.json` records source names, local bounds, origins and preview colors.
Regenerate through the Blender MCP by loading `glassclash_blender.py`, then
executing `tools/blender/export_import_bundles.py`. It reads the saved approved
`.blend` scenes, exports temporary copies and preserves the open scene.

Import settings reference: https://create.roblox.com/docs/studio/importer
