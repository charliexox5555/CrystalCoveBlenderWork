# New-chat execution prompt — Glass Clash release art and combat

Work in `C:/Users/charl/Documents/CrystalCoveBlenderWork`.

We are preparing Glass Clash for release. I approved the combat roster/direction and want better Blender models and satisfying, readable fight effects. **The release roster is exactly 24 glassies. Keep it there.** Improve the existing 12 models while retaining their names/IDs/identity, and build the other 12. Keep implementation simple and use shared effect components.

Read `AGENTS.md` first, pull the latest repo, then read:

1. `docs/HANDOFF_COMBAT_RELEASE.md` — current authority, scope, batches, implementation sequence and acceptance criteria.
2. `docs/design/RELEASE_ROSTER_24.json` — exact 24 IDs and four production batches.
3. `docs/design/COMBAT_ROSTER_V1.md` — names, descriptions, looks, abilities, effect sequences and tradeoffs. Later handoff overrides earlier shortlist/unchanged-body language.
4. `docs/research/COMBAT_VFX_WORKFLOW.md` and `docs/research/COMBAT_VFX_RESEARCH.md` — researched VFX method and source limits.
5. Current F5 roadmap, latest 2–3 DEVLOG entries, decisions 51–58, art bible and needed game-design/code sections.

Blender MCP is connected. Reinspect the scene and save state before modifying it; the previous read-only check found an untouched unsaved default scene. Use the existing Blender helper and new reproducible builders, versioned sources and isolated collections. Preserve the current scene and original source assets. Do not rebuild identical old geometry and call it an improvement.

The four batches are:

- **A:** Pop, Jam, Prism, Crescent Axe, Briar Flask, Arc Coil.
- **B:** Milk Bottle, Pickle Jar, Ketchup Bottle, Glass Cup, Water Jug, Lemonade Bottle.
- **C:** Mason Jar, Hot Sauce, Crystal Tumbler, Chime, Hourglass, Frostglobe.
- **D:** Prism Blade, Rocket Pop, Glass Duck, Comet, Glass Dragon, Galaxy Orb.

Begin actual production after orientation; do not finish the turn with another plan alone. Start with improved Pop/Jam/Prism, the shared contact/shatter kit, and the three new batch-A glassies. Produce genuine before/after previews and an early import proof. Use that style consistently through B–D. First-six reviews are checkpoints; six is not the final target.

For every glassy, deliver an editable `.blend`, body/detail/shard FBXs, 12–20 closed aligned shards, an upright centered 512×512 transparent icon and a validation/import manifest. Ordinary intact models target 1,500 triangles; hero models target 3,000. Origins stay at the hang points, 1 unit = 1 stud, separate parts remain recolorable in Studio. New geometry needs new matching shards and regenerated crack paths. Keep old sources recoverable.

For VFX, make a small original reusable mesh/texture kit in Blender and assemble effects in Studio with short bursts, Beams, Trails, mesh animation, sound and consistent charge → action → contact → tail timing. Start with two shared flipbooks, not 24. Use the actual fixed fight camera and current sky/lighting for evaluation. Preserve fighter/HP visibility, show genuine hits/misses/blocks and reset all effects on interruption. Use existing approved audio for prototypes; don't buy assets or install plugins/libraries without asking.

Keep hanging-glassy fights; **use swing turnarounds, not new arena walls**. Powers remain automatic. Preserve fixed camera, grounded pad avatars, numeric HP, winner flight/heart sequence, no power banners/results overlays, and the match hand that rolls once per match with equal odds/no duplicates. No new input buttons or device preset changes.

After the first six asset/effect prototypes work, implement the shared trigger/rules foundations and verify them live before expanding to all 24 kits. `FightRules` owns damage/status/charges, `Pendulum` owns server motion/contacts/turnarounds, clients render effects through the existing presentation modules. Keep server authority and no Roblox physics for the swing. Do not introduce a new renderer, full creature rigs, runtime fracture, live fluid simulation or a minion framework. Counts/damage/cooldowns are tunable; record meaningful design changes.

Use an explicit release allowlist so adding six definitions to the existing 31 does not expose 37 release glassies. Keep dormant definitions and saved ownership recoverable; inspect real data before any exclusion/migration. No deletion/remapping of inventories. New rarities/acquisition mapping must be set deliberately during balance integration, with current Coin Kiln odds shown for the actual eligible pool. Do not change match-hand odds to rarity weighting or activate Marble Kiln/packs/other paid features.

I am using my computer. Use Blender MCP, Studio MCP, file tools and CLI. **Do not take over desktop mouse/keyboard or change device settings.** If local FBX/texture import is not supported by the available MCP, finish validated packages and give me a concise batch-import list; continue independent work instead of repeatedly requesting the same action. Clearly distinguish exported, imported, uploaded and playtested states.

Work through the handoff phases, keep a progress table, and show concise updates with actual previews. Continue routine authorized work without reconfirming settled decisions. Run relevant tests/simulators/native checks; record only checks actually performed. Preserve unrelated working files and stage only task changes. Save editable backups, update docs/DEVLOG/roadmap, commit and push. Leave Studio in Edit at handback; do not silently publish the production place. The creator handles the separate real-device/publishing review.
