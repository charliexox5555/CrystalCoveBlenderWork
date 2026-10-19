# Launch glassies (Roster V2, workstream F)

Blender models for the 12 approved launch glassies ([ROSTER_V2](../../design/ROSTER_V2.md) §4, build order §7), built headless so the revamp session keeps the Blender MCP window.

- **Builder:** [tools/build_launch.py](tools/build_launch.py). It loads `tools/blender/glassclash_blender.py` and the revamp's `docs/art/glassy_revamp/tools/build_glassy_v4.py` (which loads v3). Builds use the same primitives, motion tags, `glass4` materials, weighted normals and `rig4` icon rig as the v4 shelf, so icons match the other 24. If v4 fails to load, it falls back to v3.
- **Run** (from the repo root):
  `B=/Applications/Blender.app/Contents/MacOS/Blender; T=docs/art/launch_glassies/tools/build_launch.py`
  - `$B -b --factory-startup --python $T -- preview <id> [--samples 32] --out <dir>` for a quick look (exports nothing)
  - `$B -b --factory-startup --python $T -- build <id> [--force]` for FBX + shards + icon + .blend + manifest (96 samples)
  - `$B -b --factory-startup --python $T -- validate <id>` for the FBX round-trip in a fresh process
  - `$B -b --factory-startup --python $T -- sheet "Title" out.png <id> ...` for a labelled sheet
  - `python3 docs/art/launch_glassies/tools/collect_launch.py` to rebuild the Studio-facing JSON
- **Outputs per glassy:** `assets/blender/glassies/<id>/v1/` holds `<id>_body/details/shards/bundle.fbx`, `<id>.blend` (with `Pivot_<Detail>` empties), `<id>_icon.png` (512², shared rig), `cracks.json` and `manifest.json`. 3/4 previews are in `previews/`.
- **For Studio:** [motion_manifest.json](motion_manifest.json) (parts, pivots, axes, idle/hit motion in Roblox coordinates; v3 schema plus `follows` and the `drip` idle) and [launch_import_data.json](launch_import_data.json) (`assets` in the `v3_import_data.json` shape, plus `release_geometry` {Radius, Center} measured from each Body for `Config/ReleaseGeometry.luau`).
- **Rules held by the builder:** origin = hang point, 1 unit = 1 stud, front = -Y; intact tris ≤ 1,500 (3,000 Legendary/Mythic); shards 16 (Common–Rare), 18 (Epic), 20 (Legendary/Mythic), closed, volume ratio 1 ± 0.001; Body radius within 0.03 of the ROSTER_V2 target.

Batch sheets: `batch_<n>_sheet.png`.
