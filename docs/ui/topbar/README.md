# Top bar buttons (decision 98)

Glass Clash's own buttons live in Roblox's top bar, left side after the chat button, drawn by
**TopbarPlus v3.5.0** so they look and behave like Roblox's core buttons on PC, phone, tablet and console.

| Button | Icon | Opens |
|---|---|---|
| Settings (caption "Settings") | gear | `SettingsScreen`; the button stays highlighted while it is open, a second click closes it |
| Gift (caption "Rewards") | red gift | a Roblox-style dropdown: **Daily Rewards** → `DailyRewardsScreen`, **Playtime Rewards** → `PlaytimeRewardsScreen`, **Codes** → `CodesScreen` (the Quests row is held back until its design is decided; `QuestsScreen` stays in StarterGui) |

- One menu at a time: a top bar screen closes the Shop/Inventory/Rewards windows and the reverse; the lobby HUD hides
  while one is open, like the other menus.
- The gift hides while the player is queued, in a match, watching or on results (and closes its screens). Settings
  stays available everywhere.
- The old combined `RewardsScreen` (Quests / Gifts / Streak / Codes tabs) is untouched for now. The new screens are
  placeholders to design and wire to the existing retention remotes later.

## Notices and layering

- Claimable rewards show as red counts: `TopbarController:SetNotice(rowId, count)` on a dropdown row; TopbarPlus adds them up
  on the gift. RewardsController sets Daily (1 when today's reward is unclaimed) and Playtime (gifts ready).
- `Config/Topbar.DisplayOrder = 25` keeps the top bar and its dropdown above open menus (20).
- `TopbarController:OpenScreen(name)` opens a top bar screen from elsewhere (the lobby rewards board uses it).

## Files

| What | Where |
|---|---|
| Buttons, dropdown rows, captions, target screens | `src/shared/Config/Topbar.luau` |
| Icon image ids | `src/shared/Config/UIAssets.luau` (`topbar/*`) |
| Behaviour | `src/client/Controllers/TopbarController.luau` |
| Placeholder screens builder (Edit, never overwrites) | `tools/studio/build_topbar_screens.luau` |
| TopbarPlus source (vendored, not formatted by StyLua) | `src/shared/Vendor/Icon` → `ReplicatedStorage.Shared.Vendor.Icon` |
| TopbarPlus licence (MPL-2.0 + credit terms) | `docs/third_party/TopbarPlus_LICENSE.txt` |
| Icon uploads | `upload_list.json` / `roblox_assets.json` here |

## Designing the screens

The five screens are ordinary ScreenGuis in **StarterGui**: restyle them freely in Studio and save the place. The
controller only relies on:
- the ScreenGui **name** (as listed in `Config/Topbar`),
- `Enabled` (it toggles it; leave it `false` in StarterGui),
- a `GuiButton` named **`Close`** anywhere inside (it closes the screen and un-highlights the button).

Each placeholder is a Stained Glass window like the other menus (artwork, banner, title and close diamond cloned from
`CollectionScreen.Panel`), an empty `Panel.Content` frame and a "Coming soon" label.

## Adding a button or dropdown row

1. Upload the icon (add it to `upload_list.json`, then `zsh -i -c 'python3 tools/opencloud/upload_assets.py docs/ui/topbar/upload_list.json'`),
   resolve the Decal to an image id in Studio (`InsertService:LoadAsset(id)` → `Decal.Texture`) and add it to `UIAssets`.
2. Add the entry to `Config/Topbar` (`Screen` for a button, or a row in `Items`).
3. Add its screen name to `tools/studio/build_topbar_screens.luau` and run it in Edit, or build the ScreenGui by hand.

## Icons

From gvesster's Free Icon Pack v3.1 (`assets/Free Icon Pack v3.1 (Basic)`, the "1st Outline" style, the same pack as
the HUD coin). Licence allows commercial use; no reselling.

| Key | Source | Decal | Image |
|---|---|---|---|
| topbar/settings | Main/Settings "Settings 1 1st Outline" | 95467054739355 | 91094338327415 |
| topbar/gift | Item/Gift "Red Gift 1st Outline" | 102317660678269 | 110617634126354 |
| topbar/daily | Item/Calendar "Calendar 1st Outline" | 124101145455396 | 109511006465398 |
| topbar/playtime | Item/Clock "Clock 1st Outline" | 71245817743435 | 124806461609711 |
| topbar/codes | Main/Codes "Codes 1st Outline" | 81788574345358 | 104059116086282 |
| topbar/quests | Item/Scroll "Scroll 1st Outline" | 102601502905812 | 76906669013402 |

## TopbarPlus notes

- **Credit (licence condition):** keep `Vendor/Icon/Attribute.lua` unchanged (it prints one credit line in live
  servers), or credit TopbarPlus in the game description.
- It also prints a donation note and, in Studio, a version notice. On Oct 19 that notice wrongly says
  "v3.5.0 -> v3.4.0" because upstream's version place still lists 3.4.0; it is harmless.
- `TextFit` skips the `Topbar*` ScreenGuis: TopbarPlus sizes its labels itself.
- Updating: replace `src/shared/Vendor/Icon` with the new release's `src/`, read the diff for `require(<id>)`,
  `loadstring`, `getfenv` or HTTP calls (AGENTS.md), then play-test the buttons.

## Verified (Oct 19, Studio Play, real clicks)

Both buttons sit on the left after chat; the gift opens the four-row dropdown with icons and labels; Codes opens
its screen and hides the lobby HUD; Settings toggles on a second click and closes with its X; opening Settings
closes the Shop; queuing hides the gift while Settings (and an open Settings screen) stay. Not checked: phone and
console presets (the Device Emulator can't be switched through the MCP).
