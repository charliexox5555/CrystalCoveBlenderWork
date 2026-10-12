# Glass Town + Recycling Yard — first map pass

Blender sources: `kit_recycling_yard.blend` (16 reusable collections) and
`layout_recycling_yard.blend` (linked kit meshes, approved stand previews).
Preview materials are untextured. Final colors and materials belong in Studio.

This is a spatial blockout with a starter environment kit, not a finished map.
Trainers, shops, repairs, wild spawns and tournaments are placement markers only.
The central M1 practice stand remains playable.

## Already in Studio

`Workspace.Map.GlassTown` and `RecyclingYard` contain temporary native-Part
proxies generated from the Blender transforms. Trees and roofs are approximate
until the FBX visuals are imported. The existing practice stand is preserved;
ten other placements reuse its approved model. Spawn is now at `(0, 0.5, 122)`.
The original baseplate is preserved, hidden and non-colliding, with its previous
properties stored in attributes. The original spawn position is also stored.

`tools/studio/setup_map_blockout.luau` returns a setup function. An MCP runner
reads `manifest.json` and calls it in Edit mode: `begin`, one `chunk` call per
export with that chunk's proxies, then `finish` with markers and route metadata.
The script refuses to overwrite an existing Map. It does not edit any synced code.

## Import handoff

1. Stop Play. In Studio, use **File > Import** and select these eight files:
   `layout_glass_town.fbx`, `layout_yard_01.fbx` through `layout_yard_06.fbx`,
   and `layout_yard_rusty.fbx` from this folder.
2. Keep separate meshes and import each file as a Model into Workspace. Use
   Studs units if offered. Do not replace the existing Map or ClashStand.
   Leave the imported models separate so Codex can inspect and normalize them.
   They may appear oversized, as with the starter imports; the manifest records
   exact stud bounds and centers for every mesh.
3. Tell Codex the imports are ready. Next work is to verify orientation and
   scale, assign mesh colors/SmoothPlastic, organize the eight visual chunks,
   hide temporary visuals while retaining simple collision boxes, and walk-test
   again. Keep the imported visuals non-colliding; avoid expensive precise mesh
   collision. The files contain no scripts or baked color textures.
4. After the review, **File > Publish to Roblox** saves the world. The connected
   MCP cannot import local FBX files or publish the Edit datamodel.

The approved Clash Stand is deliberately excluded from these FBXs; Studio
already owns that template and its placement instances.

## Verification

- Town: 320 × 320 studs; spawn-to-route walk measured **17.63 seconds**.
- Route: **600.43 studs**, 18-stud-wide path; character walk **37.48 seconds**.
- Six trainer markers, two wild regions, one route repair marker.
- 305 route ground raycasts passed; no missing ground or stuck MoveTo segment.
- Eight exports round-tripped through Blender: **128 meshes / 24,296 triangles**.
  Maximum bounds error below 0.000062 studs; each exported mesh under 8,000 tris.
- Practice battle starts in the new plaza; reset restores normal camera,
  movement, HUD cleanup and the town spawn. Studio Output clean.
- `validation.json` contains measurements. Detailed meshes still need their
  first actual Studio import and a phone performance check.
