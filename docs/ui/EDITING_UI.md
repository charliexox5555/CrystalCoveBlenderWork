# Editing the placeholder UI

## Stained Glass v0.5 — current templates

See [the v0.5 report and element map](../testing/UI_V05.md) for the five new layouts and screenshots. Inventory is `CollectionScreen`; Shop is `KilnScreen`; Choose is `RollScreen`. Fight billboard styling lives in `ReplicatedStorage.Assets.UI.FightBillboard`. Enable one template in Edit, change it, then disable it again. Source templates default disabled; the runtime enables the right one.

Labels/icons are separate from the glass artwork. Keep `Artwork`, `Label`, named bindings and `Templates` folders. Pointed pieces use **Fit + their PNG aspect** after the creator-approved clipping correction; stretch panes/stat bars keep Slice. Do not change pointed pieces back to Slice. Milk-label boxes are inset to the light interior. `FitSingleLine` labels fit the FontFace at runtime using their text box and `UITextSizeConstraint.MaxTextSize`; body copy remains wrapped. Native model portraits include caps/handles and padding.

Original templates: `ServerStorage.UIBackup_v04`. Portable backups: `places/UIBackup_v04.rbxm` and `places/UI_v05.rbxm`. Save the place in Studio. Device formatting is deliberately deferred until after the creator's edits. The earlier notes below describe legacy/auxiliary screens.


The creator owns final UI artwork and styling. Ball v Ball screenshots supplied on October 14 are layout references, not a request to copy its graphics, names, economy or features. Codex owns responsive layout and functionality.

## In Studio

1. Stop Play before editing. Expand **StarterGui**. There are 13 ScreenGui templates: LobbyHUD, QueuePanel, RollScreen, RollInfoScreen, ResultsScreen, CollectionScreen, IndexScreen, GlassyDetailScreen, KilnScreen, KilnRevealScreen, FightHud, RoundEnd and MatchNotice.
2. **RewardsScreen** is the 14th template (Quests/Gifts/Streak/Codes). Enable the screen you want to edit; disable it again when finished. The controllers enable the right screen during play. The templates default to disabled so unrelated screens do not cover each other.
3. Edit frames, colors and artwork in the template. **Keep the existing names and Templates folders** so the code can bind controls. All layout Position/Size/CanvasSize values use Scale with zero Offset. Minimum tap-target constraints remain for usability; fonts and strokes have ordinary pixel sizes.
4. A ViewportFrame's **Icon** ImageLabel is an artwork slot. Set its Image to your uploaded icon. When Image is empty, the code shows the glassy's 3D portrait. The IMAGE label is an editor placeholder and hides during play.
5. CollectionScreen/IndexScreen `Panel.Content.Grid.Templates.GlassyTile` styles every generated tile. ResultsScreen `Results.History.Templates.RoundPortrait` styles round icons. KilnScreen `Panel.Content.Odds.Templates.OddsRow` styles every odds row. FightHud `Templates.Popup` styles damage popups. Grid placement, progress fills and projected damage positions are driven by game state.
6. Save the place locally before closing Studio. Publishing remains a manual milestone action.

The controllers clone or reuse the templates, update text/models/game state and connect controls. Existing authored geometry is preserved. Dynamic lists clone their prototype. Rojo manages the code in `src/client`, while the editable ScreenGui instances live in the place alongside the world.

`tools/studio/install_ui_templates.luau` reproduces the initial templates in a fresh place. **It refuses to run if a template already exists**, protecting manual edits. Do not rerun it to reskin the game.

## Verification

- Studio audit: all 14 templates have zero Position/Size/CanvasSize offsets. The F5 pass checks 39 layout states across A06, iPhone and iPad, including the new RewardsScreen.
- Only the lobby HUD enables at startup. Collection → match closes the panel; fight controls remain locked; Results suppresses the lobby until dismissed.
- A binding check preserved a custom authored Size while updating its Text.
- Lune and Studio: 71 tests pass. Final artwork, real-phone usability and gamepad checks remain with the creator.

## Elements added in the 2026-10-14 polish pass

These exist in the templates so you can restyle them; the code only drives their state:

- **FightHud.Side1/Side2.SideStripe**: side colour bar (A blue `#4FB8FF`, B orange `#FF9F43`, matching the pads).
- **FightHud.StopWatching**: shown only while spectating a fight via the stand's Watch prompt. Keep the name; it is bottom-anchored so its 44 px minimum stays on short phones.
- **RoundEnd.Round / RoundEnd.Hearts**: round result banner ("YOU WIN ROUND 2!") and both players' hearts. Hidden until the shatter renders.
- **FightHud.Side*.Name** now reads "OWNER • GLASSY" ("YOU • JAM", "FROST BOT • JAM").
- The Perfect band's horizontal position/width is game state (this round's sweet spot); its height and colour stay yours.

Created at runtime (not templates): the in-world YOU ▼ marker (BillboardGui over your glassy), arena status signs, and Watch prompts. Originals of all templates before this pass are in **ServerStorage.UIBackups.Polish_2026_10_14**. `tools/studio/polish_ui_templates.luau` only moves controls still at their original placeholder geometry.
