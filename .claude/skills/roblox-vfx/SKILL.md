---
name: roblox-vfx
description: Glass Clash visual-effects playbook for Roblox. Use when adding or improving any effect, game feel or "juice" in this game - hits, cracks, the shatter, powers (Rage, Shield, Freeze, Beam, Slam, Big Swing, Glaze), passives, finishers, Kiln reveal, hearts popping, lobby ambience, UI effects - or when tuning ParticleEmitter, Beam, Trail, Highlight, lights, post-processing, camera shake or hitstop.
---

# Roblox VFX for Glass Clash

The fight is the game, and the shatter is the reward (GAME_DESIGN pillar 1). Effects must make every hit, power and shatter **read instantly on a phone**, look like **glass**, and never hide the glassies.

## Before you start
1. Read `docs/vfx/VFX_LIST.md`, GAME_DESIGN section 9 (game feel checklist) and the latest DEVLOG/handoff.
2. Find the existing effect code first; extend it rather than adding parallel systems:
   - `src/client/Controllers/ShatterController.luau` (cracks, shards, slow-mo, flash, sparkles), `src/shared/Config/CrackPaths*.luau`
   - `src/client/Presentation/` (`CombatEffects`, `ImpactBeat`, `HeroPowers`, `FightFinisher`, `FinisherFX`, `FinisherCamera`, `HollowlightFX`, `FightScene`, `FightView`)
   - Numbers in `src/shared/Config/Balance.luau` (`Balance.Feel`), never inline.
3. Effects are **client-only** and driven by `FightEvents` (Hit, Passive, Power with `Missed`, PerfectRelease, Overtime, Shatter, End), timed to the rendered fight time.

## Art direction
- **Glass, light and colour.** Sparkles, glints, refraction-like streaks, coloured shards. Each power has its own colour and silhouette: Rage red-orange embers, Shield aqua hex bubble, Freeze white-blue frost + brittle sparkle, Beam bright ray (visibly whiffs on a miss), Slam golden shockwave, Big Swing motion trail, Glaze honey shine.
- Palette: the Stained Glass jewel colours in `assets/ui/stained_glass/README.md` (ruby, amber, emerald, aqua, sapphire, amethyst, milk). Glassy tint from `Config/Glassies` `Tint`.
- Kid-friendly: no gore, no blood-like red splats, no scary horror. Shatters are sparkly, not violent.
- Readability first: big shapes, short durations (most effects 0.15–0.6 s), strong contrast against the sky lobby. The glassies stay the focus.

## Toolkit (what to reach for)
- **ParticleEmitter** for sparks, glints, dust, embers, frost. Use `:Emit(n)` for bursts (Rate = 0). Shape with `Size`/`Transparency` NumberSequences, `Squash`, `Drag`, `Acceleration`, `SpreadAngle`, `Speed` ranges, `Rotation`/`RotSpeed`, `LightEmission` (additive glow) and `LightInfluence = 0` for self-lit sparkles, `Brightness`, `ZOffset` to sit in front of glass, `Orientation` (VelocityParallel for streaks), `FlipbookLayout`/`FlipbookMode` for animated textures, `TimeScale` for slow-mo.
- **Beam** between Attachments for rays, shockwave rings, string snaps (`CurveSize`, `TextureSpeed`, `Width0/1`, `FaceCamera`). **Trail** for swing streaks (short `Lifetime`, `WidthScale`).
- **Highlight** for a 1–3 frame white impact flash or power outline (keep few alive at once). **PointLight** pulses on big hits (tween Brightness, then destroy).
- **Neon** or `Glass` MeshParts for crystal bursts; shard MeshParts are pre-fractured (16 per glassy).
- **Post-processing** (client): short tweens on `Bloom`, `ColorCorrection` (TintColor/Contrast/Saturation punch), `DepthOfField` for the side-on slow-mo final blow. Always restore.
- **Camera**: shake scaled by damage (decaying noise on the camera offset, RenderStepped), small FOV punch on smashes, never motion-sick.
- **Hitstop**: pause/slow the *fight presentation clock* (not the server) 60–100 ms on big hits only.
- **Sound** with every effect (clink pitched by `ClinkPitch`, layered shatter, power stingers).

## Textures
- Prefer a small shared set: spark, star glint, soft glow, ring, shard, ember, frost flake, smoke puff. Render them in Blender (see the `blender-pipeline` skill: ortho camera, transparent background, emission shading; flipbooks as 4×4 or 8×8 sheets, 512–1024 px) and save under `assets/vfx/`. Record uploaded IDs in config (`src/shared/Config/`).
- Roblox built-in `rbxasset://textures/particles/*` (sparkles_main, fire_main, smoke_main) are fine for prototypes.

## Performance budget (mobile first)
- Pool and reuse emitters/attachments per arena; never create per frame. Clean up with `Debris` or explicit `:Destroy()`; no leaks across rounds (AGENTS.md).
- Budget per arena: about 150 live particles in normal play, 400 for the final shatter for under 1 s. Up to 7 arenas can run at once; effects of fights the local player isn't watching should be reduced or skipped (distance/visibility check).
- Scale by quality: read `UserGameSettings().SavedQualityLevel` (or a setting) and cut particle counts and lights on low.
- Measure with the MicroProfiler and `Stats` after changes; test on a phone preset in the Device Emulator.

## Loop for every effect
1. Implement in `src/` (Rojo syncs it). Numbers into `Balance.Feel` or a VFX config table.
2. Trigger it in Studio through the MCP (bot-vs-bot fight with a fixed seed, or a dev helper that fires a specific event), watch it, read the Output for errors.
3. Capture a screenshot/clip if the MCP supports it, otherwise ask the user to look, and tune until it reads in under half a second.
4. `lune run tools/run_tests` and `RunAll` in Studio; DEVLOG entry; commit.
