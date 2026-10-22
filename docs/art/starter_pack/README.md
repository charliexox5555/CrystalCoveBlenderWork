# Starter Pack items: the Daybreak set (decision 117)

Sunny (glassy, Epic), Daybreak (finisher, Epic) and Dawn Kite (flyer, Epic), only from the 49 R$ Starter Pack.
Report with renders and Studio captures: [docs/testing/starter_pack_items/README.md](../../testing/starter_pack_items/README.md).

- Sunny: [tools/build_starter.py](tools/build_starter.py) on the Roster V2 launch builder (`preview`, `build`, `validate`).
  Outputs `assets/blender/glassies/sunny_rooster/v4/`; previews in `previews/`. Studio data:
  `python3 docs/art/starter_pack/tools/collect_starter.py` (motion manifest for `tools/gen_glassy_motion.luau`, geometry rows).
  Install: `tools/studio/glassy_install_chunk.py --mode install --set starter`.
- Dawn Kite: [tools/build_dawn_kite.py](tools/build_dawn_kite.py) on `tools/blender/build_flyers_launch.py` (HandleStand,
  standard grips). Outputs `assets/blender/round_cosmetics/flyers_v3/dawn_kite/`. Install: `flyer_effects.luau` +
  `install_flyers_v3.luau` (FLYERS_V3.md §6).
- Daybreak: no mesh of its own; the show (`src/client/Presentation/Finishers/Daybreak.luau`) uses the installed Sunny model
  as its hero plus native parts and shared VFX meshes. Its still lives in `Assets.RoundFinishers.daybreak`.
- Uploads: `upload_list_glassy.json`, `upload_list_flyer.json` → [roblox_assets.json](roblox_assets.json) (group 11116787).
- Palette: peach #FF9E7A, rose #FF5D7E, coral #FF8A5C, amber #FFB547, gold #FFD45C, lilac #C7A6FF, sun #FFF1B0.
