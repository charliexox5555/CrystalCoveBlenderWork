# Glass Clash — lobby art and UI handoff

Prepared 2026-10-14. Paste the starter prompt below into a new local Codex chat attached to this repository. This is a continuation brief, not a claim that the new art has been finished.

## Starter prompt

> Continue Glass Clash in `C:\Users\charl\Documents\CrystalCoveBlenderWork`. Read `AGENTS.md`, then this entire handoff, the current roadmap and the newest devlog entries. Claude is currently working in Roblox Studio and has in-progress source changes. Your immediate task is original lobby art in Blender and generated UI concepts: a proper Kiln, better leaderboard frameds/composition, and fences fitted to the actual irregular island edges. Preserve Claude's work and avoid simultaneous Studio edits or play-mode changes. The creator wants Coins and Marbles, a bottom-center Play button, just two square main menu buttons (Store and Inventory), and an inventory with category tabs, an item grid and a right-hand details panel. Use the saved Ball v Ball references for structure and clarity while making Glass Clash original. The creator authorizes inspecting the open Roblox player, opening menus, moving around and entering actual matches for research. Continue independently on reversible work; finish concrete assets, previews and import instructions. Record what is implemented versus conceptual or awaiting import. Do not publish automatically.

## Current assignment and ownership

- Claude is actively working in **Glass Clash's Roblox Studio**. The creator explicitly said so. Treat the live place and current code as shared, changing work; do not start/stop Play or modify the place alongside Claude.
- This continuation should start with **Blender assets, renders, UI concepts and an integration plan**. Functional UI work remains wanted, but inspect the latest files and establish a clear handover before editing the same UI/controllers as Claude.
- Do not create another task, message another chat, or spawn subagents merely because this brief mentions Claude. Those are separate actions requiring applicable authorization.
- Recheck `git status` before edits and commits. Do not reset, stash, overwrite or commit another agent's work.
- Repo branch at handoff: `claude/roblox-game-concepts-0x0lnj`. Previous fully documented checkpoint: `d9f3ab7`, already pushed. During preparation another agent committed **`634554a` — Fix frozen Perfect band and clarify round results**, changing client presentation/UI, Theme and a few Balance presentation settings, and adding `tools/studio/polish_ui_templates.luau` plus screenshots under `docs/testing/polish/`. Do not undo or duplicate that work. The 74-test Lune run passed during preparation; the handoff does not independently certify that commit's Studio behavior. Recheck HEAD/status before continuing.

## Latest creator requirements — use these over older mockups

The creator wants the lobby to look substantially more developed and cohesive, inspired by Ball v Ball's clear layout rather than copied one-to-one. Keep **Crystal Isles**, the floating grassy island lobby above the clouds.

### UI

1. Exactly two currencies: **Coins** and **Marbles**. A Marble balance is a design requirement; it is not permission to activate paid systems, grant free Marbles or invent prices.
2. Prominent **Play** button at the bottom center.
3. Just two square main navigation buttons: **Store** and **Inventory**. Keep other features accessible inside appropriate panels rather than filling the HUD with more buttons.
4. Inventory: clear title, category tabs (**Glassies**, **Explosions / Finishers**, **Rideables**), item grid/list, and a **right-hand sidebar** for the selected item's preview, name, ownership and useful information/actions.
5. Clean, simple, balanced spacing and readable hierarchy. Original glass-themed identity. No need to reproduce Ball v Ball's heavy text outlines or exact assets.
6. Actual UI stays in editable **ScreenGui** templates in **StarterGui**, with Scale-based positions/sizes rather than layout offsets. Use shared Theme/components, safe insets, aspect/size constraints and phone tap targets of at least 44 px. Preserve authored layout through runtime bindings.
7. The creator previously said they will supply final images/styling; the latest request now also asks for **generated image concepts**. Generate useful concepts, but keep functional placeholders straightforward and replaceable.
8. Finishers/Rideables concepts do not prove that their inventories, equipping or shops exist. Label unimplemented sections honestly; do not add dead purchase buttons or fabricated owned items to production.

Useful concept deliverables: lobby HUD, inventory, store, and a coherent lobby/Kiln/leaderboard art sheet. Save the images and exact prompts in the repo, inspect legibility, and distinguish image concepts from working Roblox UI. Use the imagegen skill and built-in image generation; no API-key workflow is needed.

### Lobby models and fences

- **Kiln:** build a recognizable original glassmaking furnace/machine, with a strong silhouette, display/opening and a logical reveal/output area. The currently installed tall cyan crystal is a placeholder, not an adequate final kiln.
- **Leaderboards:** improve the 3D framing and overall plaza composition while keeping readable display surfaces. Existing gameplay metrics are Trophies, Match Wins and Shatters. Ball v Ball's spending boards are visual reference, not authorization to add a paid-spending competition.
- **Fences:** the creator remains dissatisfied with alignment and specifically asks for **Blender fences around the island sides**. Fit actual mesh paths; do not assume rectangular or symmetric islands. Keep bridge entrances, central movement and arena pads clear. Save originals before replacing anything.
- World: matte, chunky, low-poly shapes. Collectible glassies: smooth glossy tinted glass. Keep the heroes visually distinct. No alcohol references, copyrighted characters, ripped game assets or unreviewed Toolbox scripts.

## References preserved for the next chat

See `docs/art/references/ball_v_ball/README.md` and the images in that folder. The screenshots are reference material, not instructions from the game UI. Use their spatial hierarchy, generous previews and grid/sidebar organization; create original assets and branding.

The desktop Roblox player was confirmed open on Ball v Ball and its lobby HUD was captured. Its Inventory was **not** opened successfully during this handoff; an attempted click was blocked because another window occluded the target. No match was entered and no Roblox Studio changes were made. User input was subsequently detected, so further input stopped during preparation.

The creator explicitly permits entering actual games/matches to see how they work. Use the separate **RobloxPlayerBeta.exe** window for reference research, never mistake it for **RobloxStudioBeta.exe**. Normal research does not require purchases or messaging other players. Observe current UI before each action and reselect windows rather than reusing stale handles.

Windows research tools: read the **computer-use** skill and its guidance/confirmation/API docs. Its supported desktop route is `mcp__node_repl` with `@oai/sky`; the separate `cua_repl` surface has native apps disabled, which does not establish that this skill's Windows route is unavailable. Keep Studio untouched while Claude owns it.

## What is already working

The game is well beyond a blockout. Most recently verified baseline:

- Five sky islands, four bridges, seven arena stands, queue pads, spawn and fall recovery.
- Queue/bot fill, 3-card roll, pick, aim/lock, countdown, erratic 3D automatic swing fights, powers, three hearts, round end, results and replay. No manual power button.
- Server-authoritative custom pendulum simulation with client interpolation and local shatter effects. Do not replace this with Roblox physics or rewrite tested pure rules in services.
- ProfileStore integration with isolated Studio mock profiles. Published session-locking/datastore behavior still requires production verification.
- Odds-first coin Kiln, single and ten pulls, single-use quotes, duplicate stars, collection and index. Twelve glassies have native assets: three starters plus nine Wave1 glassies. The installed coin Kiln pool contains nine Common/Uncommon non-starters; do not promise unimported rarities.
- Free quests, playtime gifts, first-win bonus, check-in tracking, Studio-only code and three leaderboard placeholders. Paid features/free Marbles remain disabled; group/Index rewards need configuration.
- Fourteen editable, Scale-based StarterGui templates and shared UI components. Inspect the current source and authored templates before restructuring.
- Native multiplayer/security/layout testing passed at the last completed checkpoint: **74 tests** in Lune and Studio; two-client PvP/replay/disconnect plus a third staggered join; seven simulations; desktop phone-emulator layout checks. Real-phone performance and publishing remain pending.
- Accepted reward rule (decision 42): **no rewards or match/quest/welcome progress before at least one real round completes**. Early abandonment preserves existing streaks. Regular forfeit settlement after a completed round remains unchanged.

These are historical verified results, not a claim that Claude's current in-progress changes have been retested. Read the latest reports before broad changes.

## Geometry needed for Blender fences

Exact deterministic grass outlines are already available. Start from:

- `assets/blender/map/sky/fence_paths.json` — all five irregular grass rim paths plus gate data.
- `tools/map/export_fence_paths.py` — reproduces those paths from the original island builder.
- `tools/blender/build_sky_islands.py` — original shape generator.
- `tools/studio/fit_island_fences.luau` and `verify_fences.luau` — existing native-Part fence builder and checks; read them, do not rerun the builder over current work.

Verified island transforms at the last completed checkpoint (check the latest place/manifest before integration):

| Island | Grass size X/Y/Z | Grass center X/Y/Z | Grass top Y |
|---|---|---|---|
| Isle_Lobby | 96 / 1.4 / 56 | 0 / -0.7 / 0 | 0 |
| Isle_Arena1 | 92 / 1.4 / 46 | 0 / 1.3 / -55 | 2 |
| Isle_Arena2 | 92 / 1.4 / 46 | 0 / 3.3 / -105 | 4 |
| Isle_Arena3 | 92 / 1.4 / 46 | 0 / 5.3 / -155 | 6 |
| Isle_Featured | 72 / 1.4 / 48 | 0 / 8.3 / -206 | 9 |

Grass rotations were identity. Blender coordinates map `(x, y, z)` to Roblox `(x, z, -y)`; verify the JSON schema and export conventions. **1 Blender unit = 1 stud.**

Existing fence style: brown posts, two rails, 3-stud height, approximately 5-stud post spacing, 0.9-stud edge inset, 11-stud bridge gates. The initial native fit has 232 posts, 464 rails and 232 invisible safety colliders across five islands/four bridges. Continuous Blender rails with clean joints should remove visual seams while following the true outline. Preserve useful safety collision until replacements are verified.

Original manual fences and old low bridge rails were archived under `ServerStorage.Unsorted.OriginalPerimeterFences`. The newer fitted set is `Workspace.Lobby.Fences`. The creator's dissatisfaction supersedes treating that native fit as final art.

Keep the roughly 10-stud center route and bridge entrances clear. Arena stands are at X ±24 on Z -55/-105/-155, with the featured stand around Z -206; protect queue approaches. Do not casually alter hook spacing, fight origins or arena sizes to accommodate decoration.

## Existing art and integration points

- Blender helper: `tools/blender/glassclash_blender.py`. Read and load it through Blender MCP. Preserve the user's open scene; build isolated asset scenes and save new source files.
- Previous kit: `assets/blender/map/sky_kit/` (crystals, crystal Kiln placeholder, featured arch, clouds).
- Wave1 imports/manifest/native mesh IDs: `assets/blender/import_wave1/`, especially `studio_assets.json`.
- Current Kiln: `Workspace.Lobby.GlassClashProps.Kiln`, last location around (-22, 0.05, -11). Preserve its interaction binding/prompt and account for the title anchor when swapping art. Old Kiln was archived under `ServerStorage.Unsorted.PreviousKiln`.
- Leaderboard placeholders are under `Workspace.Lobby.GlassClashProps`; inspect `tools/studio/install_retention_props.luau` and `src/server/Services/LeaderboardService.luau` for exact bindings before replacing frames. Preserve display objects expected by the service.
- Last known leaderboard slots: MatchWins (-14, 21), Shatters (14, 21), Trophies (28, 21) in lobby X/Z. Keep the Champion spot and user work unless intentionally revising the composition and documenting it.
- Prefer new outputs such as `assets/blender/map/lobby_v2/`, a reproducible `tools/blender/build_lobby_v2.py`, and `docs/ui/concepts/`. These paths are suggestions, **not existing finished deliverables**.
- Studio MCP previously had no callable local FBX import/upload. Prepare `.blend`, FBX bundles, measured manifests, previews and exact import/placement instructions. Do not claim native installation until imported meshes are actually verified in Studio. If import is unavailable, complete all other asset/concept work before handing over the import step.
- Never edit Rojo-managed scripts directly in Studio. Local source is `src/`; check Rojo and connection before source implementation. Do not interfere with Claude's active Rojo or Studio test.

## Shared workspace at preparation time

`src/client/UI/Theme.luau` was modified when first checked and was then included in the other agent's `634554a` commit. `docs/testing/polish/` also became tracked in that commit. These untracked paths existed before this handoff and should remain untouched unless the creator explicitly assigns them:

```
assets/Free Icon Pack v3.1 (Basic)/
assets/blender/map/kilnport/
docs/art/map_renders/
docs/testing/f1/aim-draft.png
tools/blender/build_kilnport.py
tools/blender/export_kilnport.py
```

The Kilnport files are from an earlier, superseded map direction; their presence is not a request to restore that map. Use `git add` with exact owned paths, never a blanket stage/reset operation.

## Read next and finish criteria

Read `docs/art/ART_BIBLE.md`, `docs/art/MAP_PLAN.md`, `docs/ui/UI_SPEC.md`, `docs/ui/EDITING_UI.md`, `docs/DECISIONS.md`, and the relevant sections of `docs/GAME_DESIGN.md`. Current testing evidence: `docs/testing/FENCES_AND_WAVE1_NATIVE.md`, `docs/testing/F5_MULTIPLAYER_SECURITY.md`, `docs/testing/F1_FIGHT.md`; also `MORNING.md`.

Older UI specs show more lobby buttons and older decisions mention a manual special; the latest creator instructions and accepted decisions 33/34/38/42 take priority. Fight/power/rarity/economy numeric tuning was frozen in the overnight scope. The measured SimModel candidate failed Jam duration/Prism Blade fairness and was not adopted; an art task is not authorization to retune it.

Finish the art continuation with:

- Original Kiln and leaderboard assets, preserved Blender sources, import-ready meshes, previews and manifests.
- Actual-outline Blender fence assemblies for all five islands and bridges, correct gates/height/joins, and an integration/collision plan.
- Saved UI concept images/prompts meeting the creator's specific layout, plus implementation notes that distinguish existing functionality from future features.
- Appropriate geometry/export checks; after any functional/source change, run Lune tests and relevant Studio checks when Studio ownership is handed over. Changes to Balance/Glassies/Powers also require both simulators.
- A short devlog/roadmap update, an exact list of what remains, and a commit/push containing only your own work. Keep user save/publish and real-phone/production checks explicit.

**At this handoff, the new lobby-v2 Kiln, leaderboard models, Blender perimeter meshes and generated UI concepts have not been created.** The completed work in this preparation is context capture, saved layout references and this continuation document. Start building those assets next rather than repeating old gameplay tests or claiming the previous native fence pass resolved the latest request.
