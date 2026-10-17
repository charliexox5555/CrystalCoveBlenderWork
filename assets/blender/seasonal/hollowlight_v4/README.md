# Hollowlight v4: Moonlantern Carriage flyer

October 16, 2026 (Claude). New look for the seasonal flyer; the item id stays `lantern_skiff`, so existing ownership carries over. The v2 `lantern_skiff` model is kept unchanged in Studio.

| File | What |
|---|---|
| `moonlantern_carriage.fbx` | 17 meshes, 7,856 tris: `Hull` (glass crescent sleigh with front scroll), `HullTrim_L/R`, `Hook`, `Seat`, `Backrest`, `Handlebar`, `Footrest`, `TailStar`, `Wing_L/R`, `WingRibs_L/R`, `EnginePod_L/R`, `EngineCore_L/R`. |
| `anchors.json` | Wing roots, lantern hook, exhausts, seat, footrest and grip, in Roblox space at Blender scale. |
| `hollowlight_v4.blend` | Source scene `HollowlightV4_MoonlanternCarriage`. |
| `moonlantern_carriage_review.png` | 768 px review render. |

Built by `tools/blender/build_lantern_carriage.py`, which refuses to overwrite an existing export. Origin is the seat top; the nose points to Blender +Y.

## Upload and install

- Uploaded by Claude through Open Cloud to group 11116787 as Model asset **116060877121665** (moderation: Approved).
- Inserted with the Studio MCP; it arrived at 100× scale and facing +Z.
- The raw insert is archived in `ServerStorage.HollowlightV4Import`.

Installed as `ReplicatedStorage.Assets.Seasonal.Hollowlight.moonlantern_carriage`:
- **Transform:** rotated so the nose points to −Z, normalized, then scaled 1.35× around the seat so it reads next to an avatar. It's 11.7 × 6 × 7.6 studs and the seat top stays at the pivot.
- **Colours:** Stained Glass palette (violet glass hull, gold trim, amber cushions, mint engines).
- **Wings:** `RideMotion=Wing` with `WingPivot` / `WingSide`.
- **Lantern:** the hanging lantern is the installed Hollowlight pumpkin at 0.45×, with `RideMotion=Swing` and `SwingPivot` at the hook.
- **Exhaust:** each pod has wisp and ember emitters (`RideEmitter`), which `RideController` enables only within `RideEmitterDistance`.
- **Pose:** attribute `PoseId=lantern_carriage`.

Save the place to keep the install.
