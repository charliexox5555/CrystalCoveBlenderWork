# Leaderboards v3 (decision 101, Proposed)

Three stained-glass window boards for the lobby: stone towers with glass spires, a lead pointed-arch frame ringed with
coloured glass panes, a rose window with the board's emblem, a ribbon banner (title) and a dark screen (rows).

| Board | Slot (from the plaza) | Stat | Accent | Emblem | Model asset |
|---|---|---|---|---|---|
| `WeeklySpend` | Left | Robux spent this week (Monday 00:00 UTC reset) | aqua | hourglass | 75146423913018 |
| `Wins` | Middle (1.1x) | Total match wins | amber | crown | 135528913828465 |
| `AllTimeSpend` | Right | Robux spent all time | amethyst | gem | 89593505453712 |

Files: `<Id>.blend` (isolated, editable source), `<Id>.fbx`, `<Id>_preview.png`, `manifest.json` (mesh centres, sizes,
Studio colours/materials, Screen and Title rectangles), `upload_list.json` / `roblox_assets.json` (Open Cloud).

## Changing a board later
- **Different stat or text:** edit `src/shared/Config/Leaderboards.luau` (Title, Subtitle, Stat, Format, Empty). No
  re-install needed; LeaderboardService rewrites the texts.
- **Different look:** edit `tools/blender/build_leaderboards_v3.py` (or open the `.blend`), then in Blender MCP run
  `build_all()`, upload with `zsh -i -c 'python3 tools/opencloud/upload_assets.py assets/blender/map/leaderboards_v3/upload_list.json'`,
  run `python3 tools/studio/gen_leaderboards_v3.py` and execute `tools/studio/install_leaderboards_v3.luau` in Studio
  Edit (it rebuilds only the v3 boards at the recorded spots; the old v2 boards stay in
  `ServerStorage.LeaderboardsV2Backup`).
- **UI tweaks:** the SurfaceGuis are editable in the place (`Leaderboard_<Id>.Screen.Display`, `.TitlePlate.Header`);
  rows are clones of `Display.Root.Rows.RowTemplate` (heights from the Rows frame's `TopHeight` / `RowHeight`).
