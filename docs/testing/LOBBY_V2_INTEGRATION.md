# Lobby v2 — native placement and fence alignment

2026-10-14. Creator imported all 13 FBX bundles and authorized placement after Claude handed Studio back. **Creator approved the corrected fence alignment: “looks good on my end.”** Studio stays in Edit mode; gameplay testing and publishing are explicitly left to the creator.

## Installed

- 119 imported meshes normalized from the Blender manifest. Most raw props arrived at 100×; fence assemblies were additionally clamped to 2,048 studs. Restored measured sizes, common origins, matte colors and baked mesh orientation. Raw imports remain intact in ServerStorage.
- Furnace under `Workspace.Lobby.GlassClashProps.Kiln.VisualsV2`, including cooling tray, separate information sign and physical header. Existing `Interaction.OpenKiln` prompt and `KilnTitle` retained. Added a reveal-seat attachment as an integration anchor; no new world reveal animation or economy feature implemented. Two simple invisible colliders protect the body/tray.
- Three leaderboard frames under the existing `Leaderboard_MatchWins`, `Leaderboard_Shatters`, `Leaderboard_Trophies` roots. Existing live `Entries` labels retained on invisible display carriers; existing Titles moved to editable header SurfaceGuis. Metrics/services unchanged.
- Corrected perimeter/bridge visuals under `Workspace.Lobby.FenceVisualsV2`, with matching invisible safety walls under `Workspace.Lobby.Fences`. Islands, collision floors, bridge decks, seven stands, fourteen pads, Claude's paths/lighting and StarterGui templates were not moved or rebuilt.

## What went wrong and the correction

The old island MeshParts have identity CFrames but their **native vertices** are rotated 180° relative to the Blender/source rim. Their overall dimensions are unchanged, so a bounds check did not catch the mismatch. The first native fence check also used the source polygon instead of the actual grass mesh. It incorrectly appeared to pass. The creator correctly identified overhanging/misaligned fences.

Read all five native grass meshes with EditableMesh and measured their 40 top-rim points. This found **4,746 original fence vertices outside the actual grass outlines** across the five islands. Rotated the perimeter geometry about each island's unchanged top-center. The three arena islands retain two gates; Lobby/Featured needed their single gate moved to the proper side. Native GeometryService cuts reopen those entrances, matching native rails close the obsolete gaps, and gate posts use the existing dimensions/colors. GeometryService bakes input colors; output color stays white to prevent double tint.

Rebuilt the four bridge handrails from the measured gate endpoints. Middle posts now sit at X ±3.45 on the actual eight-stud decks rather than outside their edges at ±4.2. Replaced the old sampled safety walls with **211 segments** following the corrected paths; the old 232-collider fence set remains archived. Static center-route raycast is clear.

## Verification and limits

- Reviewed Studio overhead, bridge/ground-level and Featured views. Creator independently approved the visible result.
- Checked 19,597 vertices of the preserved native perimeter inputs after correction against the actual grass rims: **zero outside**. Boolean cuts only remove geometry from those inputs. Added native gate-part corners: **zero outside**. Raw result: [alignment.json](lobby_v2/alignment.json).
- 211 invisible safety segments remain anchored/collidable/queryable; central lane raycast passes.
- Lune: **76 passed, 0 failed**. Studio pure RunAll returned true during placement. No Balance/Glassies/Powers values changed.
- **No play-mode changes or gameplay testing.** Kiln pulls/reveal, live leaderboard updates, pad/bridge traversal and phone usability are creator checks. Generated HUD/Inventory/Store images remain concepts; this work does not install those menus.

## Backups and reproduction

`ServerStorage.Unsorted.LobbyV2Backup` contains `LobbyBefore`, `RawImports`, `ReplacedVisuals` and `FenceAlignmentBefore`. The last folder preserves both the initial placed mesh fences and the old safety/visual fence folder. Older `OriginalPerimeterFences` and `PreviousKiln` archives remain intact. Nothing was deleted from those backups.

Fresh-place reproduction: `tools/studio/install_lobby_v2.luau`, then `tools/studio/correct_lobby_v2_fences.luau`. Do not rerun over current edited work. Recorded imported mesh IDs and final part transforms: [studio_assets.json](../../assets/blender/map/lobby_v2/studio_assets.json). Actual native outlines: [live_island_rims.json](../../assets/blender/map/lobby_v2/live_island_rims.json). The correction's end-island geometry operations and native bridge rails are Studio adjustments; the original FBXs retain their original source gate layout.

The place must be saved in Studio to retain world/SurfaceGui changes. This session did not publish it.
