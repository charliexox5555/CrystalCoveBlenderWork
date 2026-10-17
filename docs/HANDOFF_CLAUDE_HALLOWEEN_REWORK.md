# Claude handoff — pumpkin glassy and Halloween quality rework

Creator correction, October 16, 2026. **This handoff overrides the earlier pumpkin-as-Pop-skin direction.** Codex is handing off, not implementing this correction in the current session. Game code and Studio still contain the previous skin implementation.

## Latest user direction

1. **The pumpkin is a standalone glassy, not a skin. Remove the Skins tab.** Develop its own distinctive powers; do not retain Pop's mechanics under a pumpkin name.
2. Improve the VFX substantially. The current flyer does not feel cool enough to justify a Robux purchase.
3. Make the finisher substantially cooler. **Every finisher we have added needs appropriate sound effects**, not only the Halloween one.
4. Claude should take over this work with access to the same folder. The creator authorizes delegating simple, clearly scoped tasks to other Claude agents in future when useful. Keep delegation and total usage modest; no recurring tasks.

The user wants playful, professional, satisfying spectacle made from **Blender-authored geometry plus Roblox VFX**, with good motion and readable anticipation/impact/payoff. Passing technical tests does not establish that the art or effects meet that standard. The last playtest explicitly rejected the current quality.

## Start here and constraints

Workspace: `C:/Users/charl/Documents/CrystalCoveBlenderWork`.

Read AGENTS.md, current ROADMAP milestone and last DEVLOG entries first, then this handoff. Latest implementation commit before this documentation handoff: **050d887**; preceding imports/VFX: **dbbc8b6**; refined Blender exports: **0e8aabb**. Branch currently `claude/roblox-game-concepts-0x0lnj`, remote `https://github.com/charliexox5555/CrystalCoveBlenderWork.git`. Pull and inspect status before working.

A concurrent setup-only commit **8544f21** adds `.claude/skills/roblox-vfx/SKILL.md`, `.claude/skills/blender-pipeline/SKILL.md`, `.mcp.json` and `docs/prompts/05_claude_local_setup.md`; it was merged without modifying those files. These are environment references. Use already-working connections where possible; do not blindly reinstall add-ons/plugins, run installation commands or change settings. Verify compatibility with the actual connected Blender/Studio tools. The focused correction/prompt in this handoff takes precedence over the older broad-audit starter prompt.

- The creator explicitly transfers this implementation to Claude; the old AGENTS division assigning Studio implementation to Codex is not a reason to refuse the transfer. Follow the remaining repository practices and applicable permissions.
- **Do not touch the map, terrain, arenas, global lighting, or creator's unrelated assets/UI.** The creator owns map work.
- Use MCP/file tools. No desktop takeover, device/security settings changes, publishing, paid products/sales activation, or new schedules. Existing overnight automation was paused at the user's request.
- Verify Rojo serving and its Studio plugin connected **before source-code edits**. Never edit Rojo-managed scripts directly in Studio. Edit `src/` files.
- Confirm connected Studio by its name/place: **Glass Clash**, place **129420351303019**. Cookie Inc is another open place; do not modify it. Last Glass Clash MCP ID was `0b25074b-32ac-4284-9583-469bf1bc802b`; discover again rather than assuming IDs persist.
- Preserve original meshes/scenes/imports and saved ownership. Kid-friendly/original art, no copyrighted characters or gore. No stronger Robux-only glassies: the pumpkin needs a distinct, balanced kit rather than a paid advantage.
- The creator has hit usage limits repeatedly and can perform subjective tests. Use focused checks and short review clips/renders; avoid repeated broad suites or unnecessary agents.

Unrelated dirty work present at handoff—do not stage, overwrite, reset or stash it:

```
docs/HANDOFF_LOBBY_ART_UI.md
assets/Free Icon Pack v3.1 (Basic)/
assets/blender/map/kilnport/
docs/art/map_renders/
docs/testing/f1/aim-draft.png
tools/blender/build_kilnport.py
tools/blender/export_kilnport.py
```

## What exists now

**The current art really is Blender-authored, but the design/presentation needs improvement.** Start from it or build a new version while preserving it. The creator already imported all **68 meshes** successfully; do not ask them to reimport unchanged assets.

- Source package: `assets/blender/seasonal/hollowlight_v2/README.md`, `hollowlight_v2.blend`, `manifest.json`, `roblox_meshes.json`, three icons and front pumpkin review. Earlier `hollowlight_v1` and intermediate mesh datablocks are preserved.
- Installed library: `ReplicatedStorage.Assets.Seasonal.Hollowlight` contains `pop_hollowlight` (13 body/detail meshes + 16 shards), `lantern_skiff` (20 meshes), `lantern_eclipse` (19 meshes) and `HollowlightPrototype` (editable native VFX kit).
- Raw import preserved intact: `ServerStorage.HollowlightBeforeV2.HOLLOWLIGHT_V2_IMPORT`.
- Native recovery: `places/Hollowlight_v2.rbxm`, 273265 bytes, SHA256 `e84e6525e2d1994da2d2af88b8a4bc636a7cd4885f9c799a26ddd0e5908c581d`; script-free round trip 157 descendants. Restoring art does not restore runtime code; that comes from Rojo.
- Import was 100× and facing reversed. Installer normalized geometry from the manifest, applied native colors/materials/common pivots, fit pumpkin width to Pop, and oriented skiff nose to Roblox −Z with deck top y=0. **A standalone pumpkin should be sized for its own intended combat envelope**, not blindly preserve the old Pop fit.
- Pumpkin grin was refined into a surface-fitting filled crescent with two small teeth/dark rim; 16 closed shards follow the body. Do not regress this into a floating tube smile.
- Current flyer: flat violet bat-like wing/skiff silhouette, gold edges, two pumpkin lantern pods, mint veins/exhaust. Ten wing/rim/vein pieces share hinges. It currently reuses the original `prism_ray` glider pose through `PoseId`; it has no distinct premium riding animation yet.
- Current finisher: pumpkin core, three friendly ghosts/faces/tails, two rings, three spirals; actors converge, rings expand, lantern fades. Full detail: 19 mesh actors, 36 particles, two beams; reduced: ten actors, twelve particles, no beams. These are baseline budgets, not a reason to keep a dull design.

Blender scripts: `tools/blender/build_hollowlight_bundle.py`, `refine_hollowlight_v1.py`, `finalize_hollowlight_v2.py`, `validate_hollowlight_v2.py`; helper `tools/blender/glassclash_blender.py`. Finalizer refuses overwriting an existing scene/export. Create a preserved new revision for redesigned art. Export only genuinely new/revised geometry and give the creator one clear import package when ready.

## Code to revise rather than blindly revert

The previous pass implemented working persistence/validation but used the now-rejected skin abstraction:

| Area | Relevant files |
|---|---|
| Seasonal definitions and skin ownership | `src/shared/Config/RoundCosmetics.luau`, `src/shared/RoundCosmeticRules.luau`, `src/server/Data/ProfileSchema.luau` |
| Inventory tab/catalog/portraits | `src/client/UI/Screens/InventoryScreen.luau`, `CosmeticCatalog.luau`; `src/client/UI/Components/CosmeticPortrait.luau`, `GlassyPortrait.luau` |
| Equip and source resolution | `src/server/Services/CosmeticService.luau`, `src/server/Util/AssetCatalog.luau` |
| Frozen match cosmetics/skin descriptions | `src/server/Services/MatchService.luau`, `FightService.luau`, `src/client/UI/Screens/MatchSelection.luau`, `src/client/Presentation/FightScene.luau` |
| Halloween effects and finish dispatch | `src/client/Presentation/HollowlightFX.luau`, `FinisherFX.luau`, `FightFinisher.luau`, `HeroPowers.luau` |
| Ride staging, motion, pose | `src/server/Util/MatchStage.luau`, `src/client/Controllers/RideController.luau`, `src/client/Presentation/RidePose.luau`, `src/shared/Config/RideAnimations.luau` |
| Standalone glassies/powers/rules | `src/shared/Config/Glassies.luau`, `Powers.luau`, `Balance.luau`, `FightRules.luau`; server simulation/signature modules; client signature presentation modules |
| Audio | `src/shared/Config/Audio.luau`, `AudioCues.luau`, `src/client/Presentation/FightFinisher.luau`, `src/client/Controllers/ShatterController.luau` and existing combat audio/effects modules |

Remove the runtime-created **Skins tab** and retire pumpkin-specific `setup.Skin="hollowlight"` paths once the standalone glassy works. Preserve generic inventory fixes, source-resolution helpers, frozen equipment, avatar/ride cleanup and unrelated UI. Do not remove the real Pop glassy or alter its powers to make room.

Existing profile fields include `Cosmetics.Skins`, `Counts.Skins.hollowlight`, `EquippedSkins`. Plan an **idempotent migration** into the new pumpkin's `Glassies` ownership for any legitimate existing owner, preserving other data and not granting it to everybody. Current test grants are mock-only; real purchases were never activated. Handle unequipped/zero-count/malformed/legacy data and repeated loads. Update the Studio test command and fixtures to the new ID/ownership model.

Earlier decisions 58/69/70 constrained 24 glassies and made pumpkin a Pop skin. The latest user direction supersedes the skin choice and explicitly requests a new glassy. **Do not use the old count constraint to turn it back into a skin.** Preserve the existing 24 and define the new seasonal glassy's release/collection eligibility deliberately; a seasonal addition outside the ordinary 24-item pool is a reasonable proposal, not an already-approved formula. Do not silently replace a current glassy or accidentally expose all dormant definitions. Record the revised scope in DECISIONS/roster docs as needed.

## Design and production work

1. Develop a recognizable pumpkin kit: clear trigger, buildup, distinctive action, payoff, counterplay and limits. Briefly present a few strong ideas if useful, choose/iterate a coherent direction, then implement through authoritative rules/config and client presentation. **Power ideas are not selected yet.** Consider original lantern/seed/wisp themes, but avoid merely recoloring Pop's pressure burst or opaque area spam.
2. Redesign the flyer so its silhouette, modeled detail and motion sell the fantasy from normal gameplay distance. Consider a sculpted lantern carriage, crescent craft or lively pumpkin-powered mount; these are starting ideas, not mandates. Build meaningful geometry and animation, flowing VFX/exhaust, and a deliberate riding pose with feet/seat contact. Keep the avatar visible and restore animation/position on exit.
3. Rework Lantern Eclipse into a coordinated short show: distinct anticipation, supernatural movement, a strong release/explosion-like payoff and an attractive dispersal. Blend Blender shapes, beams, particles and animated pieces. Keep the recipient readable; no damaging Explosion instance, avatar disappearance or physics debris spam.
4. Give **all current finishers** matching audio cues, appropriately timed and volume-limited. Current IDs: `glass_burst` (Crystal Pop), `party_burst` (Party Pop), `bubble_bloom` (Bubble Bloom), `brick_boom` (Block Boom), `starfall` (Pocket Nova), `lantern_eclipse` (Lantern Eclipse). They currently declare generic bank sounds (`ShatterScatter`, `BubblePop`, `WaterSlap`, `ClinkHeavy`, `ChargeGlass`, `ChargeGlass`). `FightFinisher` plays an impact sound; a `Sound` field alone does not provide custom charge/movement/impact/tail sound design or inventory-preview audio. Inspect actual playback and improve it. Preview, repeated playback, cancellation, distance and concurrent arenas need cleanup/mixing limits.
5. Research quality Roblox VFX/audio techniques and usable original/licensed resources where useful. Existing official-reference links and initial direction are in `docs/design/DAILY_STORE_AND_HOLLOWLIGHT.md`; its **skin-only and same-Pop-power paragraphs are historical**, superseded here. Prefer original assets and free attributable audio candidates; do not buy packs, add plugins or activate products without authorization.

## Verification and completion

Previous baseline: **114 Lune tests**, 30 mock server equipment checks, 27 UI checks, one live release/sync check, 257 earlier art checks. These prove the old implementation worked mechanically; they do **not** approve its quality or remain valid unchanged after the new design.

Useful fixtures: `tools/studio/verify_hollowlight_import.luau`, `verify_hollowlight_equipment_server.luau`, `verify_hollowlight_inventory.luau`, `verify_hollowlight_round.luau`; previous report `docs/testing/HOLLOWLIGHT_EQUIPMENT.md`. Native service tests need a temporary native QA Script context to share live services' require cache; MCP direct service requires use a separate cache. Remove fixtures afterward. Let deferred UI tab events settle before targeting newly created buttons.

Run relevant tests and, for Balance/Glassies/Powers changes, **both simulators** as AGENTS requires. Check roster filtering, ownership migration, matching UI, match freeze/late join, actual powers, riding/restoration, shatter/finisher/audio cleanup. Review at normal arena camera and in inventory, including reduced detail. Prioritize a short creator quality review before building too much around an unapproved concept.

Deliver a playable/reviewable rework, any new Blender import package with exact instructions, a concise current-powers explanation and a test command. Update docs and commit/push only your changes. Leave Studio Edit, keep originals and the map intact. Storefront/real product IDs/prices/dates/receipts and the separate daily shop remain deferred unless the creator explicitly changes that scope.
