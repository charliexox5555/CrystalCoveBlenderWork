# Glass Clash — 24-glassy release handoff

October 15, 2026. Start here in the next chat. Workspace: `C:/Users/charl/Documents/CrystalCoveBlenderWork`.

Production checkpoint: all 24 source packages and the shared VFX kit are produced in `release_v2` and now imported/normalized in `ServerStorage.CombatReleaseStaged`. Creator imports were 100× oversized with mixed anchoring; all 527 imported parts are corrected and anchored, with raw backups and verified editable RBXM snapshots. First-six fixed-camera art review passes; live kits and client effect proof are pending. Continue from the [current production table](art/combat_release/PROGRESS.md), [native import report](testing/combat_release/IMPORT_NORMALIZATION.md) and [source checks](testing/COMBAT_RELEASE_ASSETS.md); the phases and gates below remain authoritative.

## Current power readability checkpoint

October 16: creator requests much clearer Pop/Jam/Prism/Axe actions, stronger shared impacts and a spinning self-heal for Hourglass. Implemented cap/pressure/recoil, real raised lid/block, aimed lens/white-core ray, corrected actual axe arc/windup/trail and shared impact spokes/rings. Hourglass now heals 7% maximum HP below 65%, twice per round, eight-second cooldown, disabled in overtime. [Changes, native visuals, tests and remaining review](testing/combat_release/POWER_READABILITY_V3.md); updated [current power list](design/POWER_BRAINSTORM_24.md). Decision 65 supersedes its old stored-sand kit. 102 logic tests, 31 focused hero checks, 264 presentation and 179 finish checks pass; 48 real-swing regression rounds have no timeouts. Creator feel and matchup fairness review remain. Native source assets preserved; Studio Edit/unpublished.

## Current selection/finish checkpoint

Creator requested longer selection/aim time, no paid-action confirmation, cleaner animated cards/owned picker, visible low-balance buttons, cosmetic avatar impact, ghost-glass cleanup and reset/zoom/return camera. Implemented; [current controls/evidence/restore guide](testing/combat_release/SELECTION_FINISH_POLISH.md) and [all 24 powers/brainstorm](design/POWER_BRAINSTORM_24.md). Decision 64 supersedes older confirmation/fixed-end-camera notes. Native selection UI snapshot is places/MatchSelection_Polish_v2.rbxm; creator saves the place. No product purchases enabled.

## Current spectacle/camera checkpoint

Creator requested more fun/effects and horizontal arena camera rotation. Implemented full-circle mouse drag/touch swipe/Q-E/right-stick orbit during Fighting, returning Prism Blade, storage retention and stronger bounded mesh/shot/cone/pulse/orbit presentation. See [current controls, checks and review limits](testing/combat_release/SPECTACLE_ORBIT.md). Decision 63 supersedes earlier fixed-direction camera constraints. 99 logic tests, 32 camera checks, 264 presentation checks and a short real fight pass; manual feel/device/fairness review remains.

## Current full-roster checkpoint

All 24 revised models and signatures are now installed and enabled in normal matches; the Coin Kiln pool is all 21 nonstarters. [Full integration/creator test guide](testing/combat_release/FULL_RELEASE.md) supersedes the first-six checkpoint statements below. 97 Lune and Studio tests, 264 all-model Client presentation checks, 48 actual deterministic swing rounds and focused two-client/seven-fight/rejoin/cleanup QA pass. Original live assets are preserved in CombatReleaseBackups; places/CombatRelease_Live_v2.rbxm saves the active native library. No publishing, paid storefront activation, production inventory migration or device-setting changes. Creator feel review, full equal-stat tuning and longer/real-phone performance checks remain; simple stand-in signature balance rates are not approval.

## Historical first-six direction

Creator tested the first-six checkpoint and approved the look, requesting stronger effects, visible numeric glassy health and corrected floating-text stroke fading before the remaining kits. Implemented: glassy-following HP numbers, short fast-swing trails, expanding hit rings/chips, stronger charge/release/block cues, pulsing windups, ray halos and clearer axe slash; both text outline types fade. 88 Lune tests and 46 isolated native Client presentation checks pass. No attack/rule/activation changes; Studio Edit/unpublished. Creator handles live feel review, keeping usage low; remaining 18 kits are next. See the feedback section of the checkpoint below.

Current engineering checkpoint: creator reconnected Rojo; source sync is verified. [First-six implementation](testing/combat_release/FIRST_SIX_CHECKPOINT.md) adds server charge/guard/cast rules, validated turnarounds, bounded rays/sweeps and scene-owned VFX. 88 Lune tests pass; one native Pop/Axe fight was observed, with broader feel/branch coverage left to the creator after their lower-usage request. Global signatures remain disabled; refreshed audio is wired into normal playback. The fixed release filter contains 24 identities, with all 37 definitions/owned legacy data preserved. Remaining 18 kits and full native/balance validation remain pending. [Earlier art evidence](testing/combat_release/VFX_AUDIO_PROTOTYPES.md) and `places/CombatRelease_VFX_Audio_v2.rbxm` preserve the template library.

The creator approved the combat direction and wants most existing models improved in Blender, new Blender models, a good release roster of **exactly 24**, and a researched approach to excellent VFX. Keep release scope simple and stop adding glassies after those 24. This session prepares the plan/prompt; production begins in the new chat.

This handoff takes priority over earlier draft phrases that said “preserve existing bodies unchanged,” “24 candidates,” or “stop after a six-glassy shortlist.” Preserve the identities and IDs of existing glassies, while improving their geometry, proportions and finish. The first six are a production checkpoint; **all 24 are the release target**.

## Read in order

1. `AGENTS.md`, current F5 section in `docs/ROADMAP.md`, latest 2–3 DEVLOG entries and decisions 51–58.
2. This handoff and [fixed roster manifest](design/RELEASE_ROSTER_24.json).
3. [Ability/look briefs](design/COMBAT_ROSTER_V1.md): all 24 names, descriptions, powers, visual effects and tradeoffs.
4. [VFX production workflow](research/COMBAT_VFX_WORKFLOW.md) and [combat research](research/COMBAT_VFX_RESEARCH.md).
5. `docs/art/ART_BIBLE.md` and only needed GAME_DESIGN sections, plus the existing Blender helper.

## Starting state and boundaries

- Baseline work before this handoff: `af98ea7` combat research, `7018d17` persistent match selection. Current branch is `claude/roblox-game-concepts-0x0lnj`; inspect current Git state rather than assuming a clean checkout.
- Lune suite passed 79 tests at the preceding handoff. Re-run at startup/end as appropriate; native combat changes require new Studio checks, not reuse of old test claims.
- Blender MCP was responding on October 15. Read-only inspection showed an unsaved, clean default Scene with Cube/Camera/Light. Reinspect on entry because the creator may have changed it. No Blender objects were modified in this planning session.
- Existing 12 Blender sources are in `assets/blender/glassies/<id>/<id>.blend`; nine everyday models also have `manifest.json`. New 12 sources need building.
- Studio was left in Edit after previous gameplay work; Rojo had been serving. Rediscover the Glass Clash Studio instance and verify sync before editing code. Do not assume transient session/Studio IDs still apply.
- The creator is using the computer. Use Blender/Studio MCP and file/CLI tools; do not take over desktop mouse/keyboard, open modal desktop import dialogs through automation, or change device presets.
- Preserve editable UI, current map, camera, pad avatars, removed overlays, currencies, ownership and match selection. Buttons remain centered anchors. No new paid features, plugins/libraries, copied branded assets or purchases.
- Existing unrelated work includes `docs/HANDOFF_LOBBY_ART_UI.md`, `assets/Free Icon Pack v3.1 (Basic)/`, `assets/blender/map/kilnport/`, `docs/art/map_renders/`, `docs/testing/f1/aim-draft.png` and two Kilnport Blender scripts. Inspect the live diff and stage only this task's work.

## Fixed release roster and Blender briefs

Every existing playable model should receive an actual visual audit and meaningful improvements where needed, not only a new particle emitter. Keep the glassy recognizable: better silhouette, thick readable rim/neck, purposeful bevels, cleaner shading and a few large details. A strong existing part can be retained; “improve” does not mean adding unnecessary polygons.

| # / batch | ID / name | Work | Concrete model direction |
|---|---|---|---|
| 1 / A | `pop` — Pop | Revise | Refine bottle shoulder/base, red cap and three large readable charge bubbles; cyan family stays |
| 2 / A | `jam` — Jam | Revise | Fuller jar, thick lip, cleaner gold lid/ridges; separate lid guard pivot |
| 3 / A | `prism` — Prism | Revise | Cleaner intentional facets, broad bevels, gem stopper/lens face; violet identity stays |
| 4 / A | `crescent_axe` — Crescent Axe | New | Squat lavender flask, crescent stopper, separate chunky axe/handle with pivot |
| 5 / A | `briar_flask` — Briar Flask | New | Emerald teardrop, leaf stopper, rose seed and three broad growing thorns |
| 6 / A | `arc_coil` — Arc Coil | New | Cyan bulb, copper collar, three separated luminous coil segments |
| 7 / B | `milk_bottle` — Milk Bottle | Revise | Soft sturdy shoulders, thick lip, readable milk insert and foam rim |
| 8 / B | `pickle_jar` — Pickle Jar | Revise | Broad jar/lid, two chunky internal pickle forms, clear green silhouette |
| 9 / B | `ketchup_bottle` — Ketchup Bottle | Revise | Distinct tapered food bottle, readable squeeze nozzle, rounded base |
| 10 / B | `glass_cup` — Glass Cup | Revise | Convincing thick rim/base and slight taper; clean inner wall, no needle-thin edges |
| 11 / B | `water_jug` — Water Jug | Revise | Purposeful broad jug/handle profile, thick mouth, simple stylized water insert |
| 12 / B | `lemonade_bottle` — Lemonade Bottle | Revise | Fresh yellow silhouette, lemon-slice cue, thick lip; three pip projectile pieces |
| 13 / C | `mason_jar` — Mason Jar | Revise | Cleaner screw collar, broad base, distinctive jar profile separate from Jam/Pickle |
| 14 / C | `hot_sauce` — Hot Sauce | Revise | Small energetic bottle, clear nozzle/shoulders, three ember details |
| 15 / C | `crystal_tumbler` — Crystal Tumbler | Revise | Bold cut-glass facets, heavy base, a broad readable mirror facet |
| 16 / C | `chime` — Chime | New | Flared bell-bottle silhouette, large pearl clapper; separate ringing detail |
| 17 / C | `hourglass` — Hourglass | New | Chunky symmetrical amber chambers, violet frame, separate sand inserts |
| 18 / C | `frostglobe` — Frostglobe | New | Blue globe/white collar, simple crystal sprout, minimal snow details |
| 19 / D | `prism_blade` — Prism Blade | New existing catalog art | Broad short glass blade and thick hilt; recognizable Prism family |
| 20 / D | `rocket_pop` — Rocket Pop | New existing catalog art | Pop-family bottle with red fins, chunky nozzles, separate booster effects |
| 21 / D | `glass_duck` — Glass Duck | New existing catalog art | Round yellow toy duck, broad beak, simple wings; no detailed creature rig |
| 22 / D | `comet` — Comet | New existing catalog art | Round cyan head, large swept tail wedges, warm star core |
| 23 / D | `glass_dragon` — Glass Dragon | New existing catalog art | Cute snout, broad wings, curled tail; separated jaw/wings, no full rig |
| 24 / D | `galaxy_orb` — Galaxy Orb | New existing catalog art | Violet orb, offset star core, two thick orbit bands; simple interior layers |

Batch arithmetic: A 6 → B 12 → C 18 → D **24**. Twelve current models revised, six catalog models built for the first time, six brand-new concepts built. Do not substitute or add a 25th without a new creator instruction.

## Catalog and saved-data handling

There are currently 31 definitions, including 13 not selected above. Adding six new IDs would make 37 stored definitions; **that must not accidentally become a 37-glassy release UI or acquisition pool**.

- Later integration should use an explicit release-ID allowlist sourced from the manifest. Player-facing release index/completion counts, owned selection eligibility and acquisition use the appropriate release/installed filters consistently.
- Keep the other 13 definitions/source work in a dormant backlog; do not delete IDs, remap inventories or grant replacements automatically.
- Audit actual profile ownership before excluding anything. If a profile owns a dormant item, preserve the data and inspectability; do not silently destroy access or call it one of the 24. Define a visible legacy exception if needed, and report any real migration issue before changing saved data. No production migration is performed by this planning session.
- Existing starter IDs remain `pop`, `jam`, `prism`. Existing rarity assignments stay until balance work. New six rarities are tuning decisions, not a Blender blocker; do not invent new rarity tiers or paid exclusives.
- Only valid installed art enters a live roll/Kiln pool. Coin Kiln odds must be recalculated/disclosed for its actual eligible pool before activating additions. A 24 roster does not mean 24 Kiln outcomes: starter exclusion still applies.
- Existing once-per-match hand uses uniform owned eligible glassies without duplicates. Do not accidentally apply rarity/Kiln weighting to match selection.

Dormant 13: Perfume, Potion Flask, Message in a Bottle, Light Bulb, Honey Bear, Jack-o'-Glass, Crystal Ball, Glass Lollipop, Grizzly Guardian, Starblade, Glass Sword, Glass Unicorn, Crystal Crown.

## Production phases

### Phase 0 — orientation and safe source setup

Pull/read instructions, inspect Git, Blender and Studio state, and verify existing sources. Make versioned new outputs rather than overwriting the only source. Load helper in Blender after inspecting the scene:

```python
GLASSCLASH_REPO = r"C:/Users/charl/Documents/CrystalCoveBlenderWork"
exec(open(GLASSCLASH_REPO + "/tools/blender/glassclash_blender.py").read())
```

Use the helper contract, but author new builders instead of calling old builders and presenting identical old geometry as improved art. Preserve current user's scene and selections; use new collections/scenes and explicit file paths. Inspect actual API/tool capabilities before assuming screenshot, render, import or upload methods exist.

### Phase 1 — style and import proof

Revise Pop/Jam/Prism and build the shared contact/shatter kit, then Crescent Axe/Briar Flask/Arc Coil. Establish one consistent body material preview, bevel language and icon camera. Produce meaningful before/after views at both inspection size and actual UI size.

Round-trip one revised body, shard set, effect mesh and texture sheet early. Import into isolated Studio assets; verify actual glass look, scale, hang point, texture alpha, animation pivot and two-sided visibility. A beautiful Blender-only image is not the completion criterion.

If the MCP cannot import local FBX/PNG files, finish and validate the package and give the creator one concise batch-import list with exact paths/settings. Continue independent modeling/export work while the import is pending. Do not automate the desktop or repeatedly ask the same import question. Record which checks remain blocked; don't mark them passed.

### Phase 2 — shared VFX authoring and preview

Follow [the researched workflow](research/COMBAT_VFX_WORKFLOW.md): procedural reusable meshes, original static textures, two initial flipbooks and native Studio effect timelines. Make an isolated test fixture, then prototype charge/release/contact/tail for the first six.

Use actual server cast facts during later live integration. The preview fixture can use deterministic simulated result inputs but must be labeled a preview. Do not confuse a staged hit demonstration with a verified damage/collision test.

### Phase 3 — complete all 24 assets in batches B, C and D

Carry the established style through every row. Each batch gets source files, intact/detail/shard exports, icon, validation manifest, contact sheet and effect preview assets. Capture the actual result and compare silhouettes at small sizes. The creator can give feedback as work proceeds; a status update is not an automatic approval pause.

No scope growth into extra glassies, alternate skins, evolutions, map decoration, new menus, creature rigging or paid content. Use the simplest effect shapes that sell each approved signature.

### Phase 4 — rules and live VFX integration

The overall direction/signature-based roster is approved; prototype counts/timings/damage remain tunable. Read the ability briefs and implement a small shared vocabulary rather than 24 combat services.

- `FightRules` owns damage, charges, cooldowns, statuses and results. `Pendulum` owns the deterministic swing, contacts and validated turnarounds. Do not add Roblox physics to the swing.
- Make an explicit mapping for each kit's trigger, range/shape and cooldown. Use bounded swept/projectile tests where a visible weapon/shot needs them. Keep inputs, snapshots and server authority intact.
- Avoid a new general-purpose minion/rig/rewind framework. Dragon uses a short budgeted cone; Galaxy uses a brief capped tangent influence. Reflection never reflects reflection; slow effects don't stack into a complete stop.
- Extend `FightScene`/`ShatterController`/`FightFinisher`; keep current winner flight, pad avatars, heart loss, numeric HP and fixed camera.
- Recalculate body collision dimensions/crack paths after revised art. Similar looks do not justify stale crack coordinates or unexpectedly enlarged hitboxes.
- Stage the release allowlist and new content integration after complete assets exist. Do not enable new paid products or the Marble Kiln as a side effect.

Build/validate the first six kits live before multiplying the pattern across the other 18. This is an engineering checkpoint, not permission to stop at six as the final roster.

### Phase 5 — release checks and creator handback

Run tests, required sims, native match/ability/cleanup checks and multiplayer coverage appropriate to the changes. Check every release glassy can be viewed, selected, rendered, cracked and shattered without placeholders. No active release kit should silently fall back to a starter mesh or generic missing effect.

Save sources/exports and recoverable Studio assets. Update progress, decisions, roadmap and DEVLOG; commit and push task-owned files. Leave Studio in Edit. Publishing/real-device review remains a distinct creator step; do not silently publish the production place.

## Asset contract and versioning

- 1 Blender unit = 1 stud; body origin at the string hang point. All detail and shard exports share that coordinate system. Weapon pivots are separately recorded.
- Smooth glossy toy-like heroes, thick rims/bevels, readable silhouettes. Plain colors/materials are assigned in Studio; separate elements stay recolorable.
- Intact body plus details: target ≤1,500 triangles ordinary, ≤3,000 hero. Use 12–20 closed shards per body, with interior faces. Asset-specific exceptions require an explicit measured reason.
- New body geometry requires matching new shards and regenerated crack paths. Check normals, transforms, bounds, closed surfaces and alignment in a recombined shard view.
- Upright centered transparent 512×512 icon with one shared camera/light rig. Do not revive the tilted UI portrait style.
- Versioned output example: `assets/blender/glassies/<id>/release_v2/<id>.blend`, `_body.fbx`, `_details.fbx`, `_shards.fbx`, `manifest.json`. Icons under `assets/icons/release_v2/`. Prior sources remain available. Only promote a verified version to active asset records.
- Shared kit: `assets/blender/vfx/combat_release/` and `assets/vfx/combat_release/`; reusable builders under `tools/blender/`.
- Import manifest records file hashes, mesh names/triangles, bounds, hang point, marker coordinates, texture frame layout, import/upload status and actual Roblox IDs. Never fabricate IDs or mark an export as imported.

## Acceptance checklist

- [ ] Exactly 24 unique release IDs; no dormant catalog leakage into release counts/pools.
- [ ] All 12 current models visually audited/revised; all 12 missing/new models built.
- [ ] All 24 have editable source, valid exports, matching shards, upright icon and import records.
- [ ] Shared VFX kit exists with reusable textures/meshes and actual preview evidence.
- [ ] Every kit shows buildup, main action, accurate contact/miss/block and cleanup.
- [ ] Body/HP/heart visibility and fixed camera preserved; no banners/results restored.
- [ ] Rules/swing tests and required simulators pass; new native results recorded honestly.
- [ ] Forfeit/rematch/watch-stop/late join don't leave effects or replay stale casts.
- [ ] Performance profiled for one focused fight plus background arenas; no device presets changed in this work.
- [ ] Editable backups, docs, task-only commit and push complete; outstanding manual import/device/publish work clearly listed.

## First action for the next chat

Use the [complete execution prompt](prompts/05_combat_release_24.md). Start Phase 0, then produce the first six source models/shared kit and real previews. Keep progress against the 24-row manifest, and carry through the remaining batches/integration within the authorized scope. Ask only when a genuinely missing decision blocks work; do not ask to reconfirm the roster, arena or Blender connection simply because this is a new chat.
