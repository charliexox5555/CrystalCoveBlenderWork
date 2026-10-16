# Hollowlight — first Blender prototypes

Original Halloween set, 2026-10-16. **Prototype art; not installed, sold or added to the 24-glassy roster.**

- `pumpkin_icon.png`: Hollowlight Pop, a seasonal Pop appearance. Body origin is the stem hang point at `(0,0,0)`; 1 unit = 1 stud. `pumpkin_body.fbx`, `pumpkin_details.fbx`, `pumpkin_shards.fbx` contain the separate body/details and 16 closed shards.
- `flyer_icon.png`: Lantern Skiff, a violet winged skiff with gold rims, mint veins/exhaust and amber lantern pods.
- `finisher_icon.png`: Lantern Eclipse, with a pumpkin core, three friendly wisps and independent rings/ribbons.
- `HOLLOWLIGHT_COSMETICS_IMPORT.fbx`: 39 separate flyer/finisher meshes, 11,574 triangles. Names begin `HHL_`; preserve them during import. Material colors are previews; assign native Studio colors/materials after import. Thin wing/face surfaces need appropriate double-sided rendering.
- `HollowlightVFXPrototype.rbxm`: editable native kit using our original textures, also saved at `ReplicatedStorage.Assets.VFX.HollowlightPrototype`. Four disabled burst emitters (36 particles total), two disabled curved ribbons and phase attributes. Script-free round trip verified; no world placement or gameplay activation. Import the model into the VFX asset folder when restoring it.
- `hollowlight_v1.blend`: current editable scene, with previous replaced ghost mesh datablocks preserved. `hollowlight_first_pass.blend` retains the earlier source. `manifest.json` identifies exported groups; `validation.json` records closed body, positive volume and FBX round-trip counts.

Build using `tools/blender/build_hollowlight_bundle.py`, then `tools/blender/refine_hollowlight_v1.py` through Blender MCP. Builders preserve existing scenes; they should not overwrite a creator-edited source scene. Shared icon-camera/light helper renders at 512px. Source refinement reuses the original objects and retains their earlier mesh data.

These previews show static shapes, not final real-time VFX. Final skin framing must fit Pop's existing gameplay proxy; source art does not change damage or stats. No Studio/map placement, product IDs, sale dates or purchase activation is included. See [design/VFX research and queue](../../../../docs/design/DAILY_STORE_AND_HOLLOWLIGHT.md).
