---
name: blender-pipeline
description: Glass Clash Blender pipeline through the Blender MCP. Use when modelling or editing glassies, shards, map or lobby kit pieces, icons, or rendering VFX textures/flipbooks in Blender, and when exporting FBX/PNG for Roblox Studio.
---

# Blender pipeline for Glass Clash

## Always
- Load the helper first in the connected Blender: `exec(open(r"<repo>/tools/blender/glassclash_blender.py").read())`, then `self_check()`. It has `render_icon(...)`, `export_fbx(...)` (the export settings that import at the right scale) and glassy/stand exporters.
- Follow `docs/art/ART_BIBLE.md`: low-poly flat-shaded world, smooth glossy glassies; **1 Blender unit = 1 stud**; apply transforms before export; colours are set in Studio (Blender materials are previews).
- Content rules: original designs only, kid-friendly, **no alcohol bottle shapes**.

## Glassies
- Body origin at the **hang point**; ≤ 1,500 tris (≤ 3,000 Legendary/Mythic); separate `Details` meshes (caps, lids) share the origin; 12–20 pre-broken shards (Cell Fracture) with inner faces; crack paths via `tools/blender/export_crack_paths.py`; 512×512 icon with the shared camera via `render_icon`.
- Export to `assets/blender/glassies/<id>/` (`<id>_body.fbx`, `_details.fbx`, `_shards.fbx`) and record new glassies in `src/shared/Config/Glassies.luau` / art import config.

## VFX textures and flipbooks (for the `roblox-vfx` skill)
- New scene or collection, **orthographic camera** facing the subject, **Film > Transparent**, emission-only materials (no lighting needed), Eevee or Cycles with few samples.
- Single sprites 256–512 px; flipbooks as a grid (4×4 or 8×8) on a 1024 px sheet: render frames, then tile them with a small script (PIL) into one PNG. Keep shapes bold and readable at small sizes; white or light textures tinted in Roblox via `Color`.
- Save to `assets/vfx/<name>.png` (+ the `.blend` source in `assets/vfx/source/`), list them in `docs/vfx/VFX_LIST.md`.

## Hand-off to Studio
- Importing FBX into Studio is done by the user with **File > Import** (Scale Unit: Studs, Merge Meshes off, Use Imported Pivot, Anchored); images via **Asset Manager > Bulk Import**. Write exact steps and the file list for them, then verify the import through the Roblox Studio MCP.
