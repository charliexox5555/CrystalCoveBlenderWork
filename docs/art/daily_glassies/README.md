# Daily Rewards glassies (decision 115)

Whiskers (Day 2, Epic) and Midnight (Day 7, Legendary), built headless with the Roster V2 launch builder as a library, so they share the shelf's v4 glass, face language, motion tags, rig4 icon camera, fracture and checks.

- Builder: [tools/build_daily.py](tools/build_daily.py) (`preview`, `build`, `validate`, `sheet`, same as `build_launch.py`).
- Outputs: `assets/blender/glassies/<id>/v4/` (body/details/shards/bundle FBX, `.blend`, icon, `cracks.json`, `manifest.json`); previews in `previews/`.
- Studio data: `python3 docs/art/daily_glassies/tools/collect_daily.py` writes [motion_manifest.json](motion_manifest.json) (read by `tools/gen_glassy_motion.luau`) and `daily_import_data.json`, and prints the ReleaseGeometry rows.
- Upload: `zsh -i -c 'python3 tools/opencloud/upload_assets.py docs/art/daily_glassies/upload_list_v4.json'` (Record: [roblox_assets.json](roblox_assets.json)); install with `tools/studio/glassy_install_chunk.py --set daily` (IMPORT_RUNBOOK.md).
- Item pictures: `assets/icons/items/source/portraits.json` marks their mesh parts `mirrorX` (the icon renderer mirrored the asymmetric crescent; checked against a Studio capture).
- XP reward icon: [tools/xp_icon.py](tools/xp_icon.py) → `assets/icons/reward/xp.png` (UIAssets `icon/xp`).
- Midnight is a nod to the creator's studio, Midnights Studio: a sleepy crescent moon in a nightcap, no logo.
