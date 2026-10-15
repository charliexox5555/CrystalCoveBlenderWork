# Release VFX workflow — research and production recipe

October 15, 2026. Recommendation for this project's Blender MCP + Roblox Studio MCP workflow. This is a researched production approach, not a claim that effects have already been built or benchmarked. See [release handoff](../HANDOFF_COMBAT_RELEASE.md) and [24 ability briefs](../design/COMBAT_ROSTER_V1.md).

## Recommendation

Use a **small original mesh/texture kit, assembled and timed in Roblox Studio**, with procedural Blender builders that can be rerun and tuned. Make the primary action with a few readable meshes; use particles for accents, Beams for connections and Trails for motion. Reserve rendered flipbooks for organic bursts that cannot be expressed cleanly with those tools. Layer sound and body reaction into the same timeline.

This is the best starting approach for our available tools because scripts can reliably regenerate shapes, export variants, record parameters, and validate pivots/scale. Native Studio effects remain editable and follow live fighter positions. We avoid making 24 unrelated effect systems or trying to import a Blender simulation as gameplay.

## Verified platform facts and their implications

- Roblox supports transparent PNG particles and animated flipbooks, including 4×4 sheets. Its guidance calls out fill-rate, overlapping particles and memory costs; low-memory clients may disable flipbooks. Therefore, use only a few shared sheets and preserve important attack cues in meshes/static textures. [Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)
- `ParticleEmitter:Emit()` makes a bounded burst; `Clear()` removes existing particles. Prefer explicit bursts and complete pool resets to many continuously running emitters. [ParticleEmitter API](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)
- Beams connect attachments and support widths/curves; Trails expose motion over a controllable lifetime. Use beams for coil rays/tethers and short trails for axe/rocket/slash movement. [Beams](https://create.roblox.com/docs/effects/beams), [Trails](https://create.roblox.com/docs/effects/trails)
- Roblox warns about layered transparency, unnecessary complexity and repeated unique meshes. Shared mesh IDs, local visuals and measured detail reduction fit a game with seven arenas and transparent fighters. [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- The importer exposes scale units, imported pivots, mesh merging and double-sided geometry. Verify these with a small test asset; avoid merging separately recolorable/animated details. Double-sided sheets have a cost. [3D Importer](https://create.roblox.com/docs/studio/importer)
- Roblox's PBR workflow uses maps for surface properties. Rich Blender preview materials do not establish the final Roblox look. Default to the existing tinted Glass body and separate details; consider PBR only where a deliberate surface detail earns its texture cost. [PBR textures](https://create.roblox.com/docs/art/modeling/surface-appearance), [SurfaceAppearance API](https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance)
- Blender MCP's bundled manuals were accessible this session. `manual/render/cycles/render_settings/film.rst` documents rendering transparent backgrounds; `manual/files/import_export/fbx_legacy.rst` documents limitations including animated-fluid export and exporting constraint results rather than the constraints themselves. Treat this as guidance for the bundled exporter, not a promise about every Blender build. Use the existing helper and verify the installed version at production time. Web manual fetches had failed in the previous session; the connected manual search now supplies a local reference.

## 1. Author a reproducible mesh kit

Create `tools/blender/build_combat_release.py` for bodies and `tools/blender/build_combat_vfx.py` for shared effects. Small named builder functions and a parameter table should control proportions, bevel width, segment counts and export paths. Inspect existing scenes before writing anything; build into new scenes/collections and versioned output directories.

Initial mesh pieces:

| Piece | Use | Starting triangle target |
|---|---|---|
| Ring / half ring | Pop burst, Chime, shatter contact | 64–128 |
| Curved slash | Axe/Prism Blade contact direction | 80–200 |
| Shield plate / rim | Jam and duck block | 80–200 |
| Thorn / chip | Briar growth and glass accents | 24–96 |
| Droplet / pip / bead | Food, water, citrus and projectile heads | 32–100 |
| Curved splash / puff sheet | Jug, frost and breath | 32–128 |
| Orbit band / small funnel | Galaxy presentation | 80–240 |

Targets are proposed budgets, not hard engine limits. Keep effect origins useful for animation: axe at handle pivot, thorn at growth base, ring at center, cone sheet at nozzle. No physics collision on cosmetic pieces. Record local marker coordinates so Studio can create real Attachments after import.

## 2. Make original reusable textures

Start with grayscale RGBA textures, tinting them in Studio. Use code-native analytic shapes for simple glints/streaks/rings and Blender renders for organic glass dust or pressure puffs. These are planned production methods; no images are generated in this handoff pass.

For the first Blender-rendered sheets:

1. Make one isolated orthographic VFX render scene with transparent film/background and a fixed camera. Use original geometry/procedural materials; avoid external dependencies.
2. Animate a 16-frame burst with stable framing: fast expansion, brief recognizable peak, then breakup/fade. Render a numbered PNG sequence, keeping useful color/alpha information.
3. Pack frames deterministically into a 4×4 RGBA atlas with gutters. Start at 512×512, testing 1024×1024 only when its extra detail is visible at real fight size.
4. Verify atlas ordering with a numbered debug sheet first. Record the chosen Blender-to-Roblox orientation; do not assume a frame packing convention until the imported animation proves it.
5. Check alpha edges over both the bright sky and a dark card, plus imported mip levels. Fix halos/bleed in the source packing rather than hiding them with excessive glow.
6. Pair the sheet with a static fallback. Charge readiness, projectile heads and real hit contacts must remain legible if animated particles disappear.

Deliver only two initial flipbooks: `glass_dust_4x4` and `pressure_pop_4x4`. Reuse/recolor them first. Add one frost/breath sheet only if later Studio comparisons show a clear benefit. Do not make one flipbook per glassy.

Source images, atlas, generation settings and license/provenance belong together under `assets/vfx/combat_release/`. Blender render post-processing stays out of the game; final effect contrast is tuned in the real arena.

## 3. Assemble four readable layers

| Layer | Job | Implementation |
|---|---|---|
| Charge | Show readiness before release | Three bubbles/coil segments/thorns; subtle sound steps |
| Main action | Show what the ability physically does | Mesh sweep, projectile head, directed Beam or short cone |
| Contact | Confirm actual hit, block or miss | Local glint/ripple/chip burst with server result |
| Tail | Finish cleanly and restore visibility | Brief trail/dust/tinkle, then return objects to pool |

Each kit uses a small editable timeline definition rather than a unique monolithic script. Record windup/release/impact/tail times, colors, meshes, emission counts, scale curves, sound pitch/volume and reduced-detail behavior. Separate gameplay parameters from presentation parameters.

Example Axe starting timeline: 0–0.30 s windup, 0.30–0.44 s sweep, a ≤0.08 s contact flare only if a hit resolves, then a ≤0.25 s tail. These are trial values. The server emits the authoritative cast timing; client animation must not delay gameplay independently or invent a hit at the midpoint of every sweep.

Existing `FightScene`, `ShatterController` and `FightFinisher` remain integration points. Use fight/cast IDs and server time with the current interpolation buffer. Don't aim a cosmetic laser at an opponent after the authoritative cast missed.

## 4. Make a Studio effect test scene early

Use an isolated editable `VFXPreview_CombatRelease` fixture, backed up and separate from the live map. It should preview the approved bodies from the actual fixed fight-camera angle with the current sky/lighting. Don't change device presets or desktop windows.

Useful controls: effect family, glassy, hit/miss/block result, replay seed, normal/slow playback and normal/reduced detail. These are Studio developer controls, not a new player menu. Test a burst alone, on a moving fighter, and simultaneously with the opponent's effect. Capture before/after images or clips using the available MCP tools; do not claim a clip exists if only screenshots were captured.

Evaluate at real screen size, with audio muted, and without bloom-dependent cues. If the action reads only in a close-up Blender render, revise it before multiplying it across the roster.

## 5. Audio and shatter

Reuse approved Clink/Break/Tinkle/Whoosh for prototypes. Final sound identities can come from original recordings or procedural synthesis, normalized and trimmed with clear transient/tail separation. Keep licenses and uploaded IDs recorded. Do not quietly buy a pack or install an audio/VFX plugin.

Shatter has three distinct beats: contact crack, outward prebroken pieces, light falling tinkles. Prebroken body shards must match the final revised body. Rebuild crack paths after geometry changes; old raycast-projected crack coordinates cannot be assumed to fit new geometry.

Keep the camera stable and numeric HP/hearts legible. Limit ordinary hit flash intensity; reserve the strongest moment for a real shatter. Cosmetic avatar fragments do not damage Humanoids or determine hearts/rewards.

## 6. Quality and cost review

Use the provisional budgets in the [roster plan](../design/COMBAT_ROSTER_V1.md), then measure. Focus on screen coverage and transparent layers as well as raw counts. Pool short-lived mesh/attachment pieces only when the resets are reliable; particle and audio cleanup must also run on interruption.

Quality rubric, scored 0–2 each:

1. **Identity:** can you identify the glassy/ability without its name?
2. **Buildup:** can you tell when its signature is about to happen?
3. **Truth:** do its visible range, direction and contact match the gameplay?
4. **Payoff:** do body response, sound and effect timing agree?
5. **Clarity:** can you still see both glassies, cracks and HP?
6. **Cleanup:** does replay/forfeit/round transition leave nothing behind?

Proposed acceptance: at least 10/12 with no zero in Truth, Clarity or Cleanup. This is a production review tool, not a validated player-fun metric. Use [MicroProfiler](https://create.roblox.com/docs/performance-optimization/microprofiler) and later real low-end-device testing before claiming performance readiness.

## What we are choosing not to add for release

No fluid simulation in live Roblox, full creature rigs, custom renderer, runtime mesh fracture, arena-wall rebuild, mandatory VFX plugin, large summoned armies or a unique shader pipeline per glassy. Cute dragons use a few separated jaw/wing pieces animated in Studio; gravity stays a bounded short effect. The fixed 24 roster uses these shared primitives and the current server pendulum.
