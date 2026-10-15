# Combat abilities and effects research

Prepared October 15, 2026. Scope: research and a proposed production plan, before Blender or gameplay changes. Companion: [roster and production plan](../design/COMBAT_ROSTER_V1.md).

## Findings we can use

### Make the cause and payoff visible

Riot's retrospective directly connects exciting autobattler spells with anticipation, understandable impact and spectator enjoyment. It also describes clutter from summons, invisible damage and attacks with imperceptible travel time. Our application: show a glassy charging, its attack traveling, the contact and the recovery. Give each glassy one recognizable signature rather than several disconnected effects. These are our design choices, informed by the retrospective. [TFT: Rise of the Elements Learnings](https://teamfighttactics.leagueoflegends.com/en-gb/news/dev/dev-tft-rise-of-the-elements-learnings/)

The same retrospective favors soft counters and warns about overwhelming disables. For Glass Clash, suggest temporary mitigation, brief slows and conditional attacks; avoid permanent immunity, repeated hard freezing and unlimited summons. Keep swing movement alive so rounds remain interesting to watch. These are proposals, not claims that another game's balance transfers directly. [TFT developer retrospective](https://teamfighttactics.leagueoflegends.com/en-gb/news/dev/dev-tft-rise-of-the-elements-learnings/)

### Give the most important event the clearest read

Riot's clarity guidance prioritizes recognizable silhouettes, meaningful audio/visual communication, hierarchy and controlled noise. The appearance of an attack should match its gameplay significance and coverage. Our application: an axe has a visible sweep, spikes have a visible reach, shields show a facing plate, and an aimed shot visibly misses when it misses. Color is supported by shape and sound. Glassy bodies and HP remain readable beneath effects. [Clarity in League](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/)

Their VFX update process ranks inaccurate indicators and gameplay readability ahead of thematic embellishment. It also separates focused VFX improvements from model/gameplay overhauls. Our application: improve shared hits and shattering first, then prototype a small ability batch before expanding the roster. [Behind the Scenes of VFX Updates](https://www.leagueoflegends.com/en-us/news/dev/dev-behind-the-scenes-of-vfx-updates/)

The official GDC listing for Martin Jonasson and Petri Purho's *Juice It or Lose It* describes demonstrating small changes that make a simple game more satisfying. We reviewed the listing; this is not a claim to have watched the full talk or audited its source code. Our proposed experiment is to compare identical fights before/after changes to recoil, sound, impact timing and debris. [GDC session](https://www.gdcvault.com/play/1016487/juice-it-or-lose)

### Build effects in Roblox from reusable original assets

Roblox ParticleEmitters support burst images and animated flipbooks. Its documentation warns that many unique flipbooks consume memory and can be disabled on memory-constrained devices. Our application: a small shared texture set, short bursts and an ordinary mesh/static-texture fallback for every important gameplay cue. Avoid unique animated sheets for every glassy. [Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)

Beams render textures between attachments with adjustable width and curves. Use them for electrical arcs, a short sticky connection and directed rays. Their geometry is presentation; the server separately resolves attacks. [Beams](https://create.roblox.com/docs/effects/beams)

Trails follow attachment movement and have controllable lifetime and transparency. Use short trails to reveal weapon arcs and powered motion, rather than leaving the whole fight covered in ribbons. [Trails](https://create.roblox.com/docs/effects/trails)

Roblox identifies overlapping transparencies, particle/property costs and expensive scene complexity as performance concerns. Its guidance supports creating effect visuals locally when the server only needs gameplay positions/outcomes. Our application: local effect pools, shared assets, short lifetimes, distance-based detail and limits on translucent layers. This matters especially because our fighters are already transparent glass. [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)

The 3D Importer accepts model assets, with configurable geometry/import behavior. We'll export body/detail/shard meshes, then assemble effects and assign game materials in Studio. Do not assume a Blender shader, simulated fluid or compositing setup becomes a runtime Roblox effect. [Roblox 3D Importer](https://create.roblox.com/docs/studio/importer)

Use MicroProfiler to measure the real runtime once the prototype exists; performance targets in the plan are provisional, not measured results. [MicroProfiler](https://create.roblox.com/docs/performance-optimization/microprofiler)

## Existing game audit

These findings come from this repository, not web claims:

- The game has 31 catalog definitions and 12 playable models: Pop, Jam, Prism and nine everyday glassies. Existing IDs, ownership and art must be preserved.
- `FightRules` currently supplies nine passives and seven timed bursts. Many glassies reuse the same mechanical power under different names. A signature-by-trigger system will require actual rules work, not only a VFX reskin.
- `Pendulum` already provides deterministic 3D motion, collisions, twist, tumble and a direction/range check for aimed powers. It has no combat wall-bounce event. The creator explicitly confirmed keeping this arena and using swing turnarounds.
- `FightScene` currently uses generic sparkles, simple rays, shield bubbles and trails. `ShatterController` already uses prebuilt shards, crack paths and hit feedback; `FightFinisher` already supplies the cosmetic winner flight/avatar impact. Extend these foundations rather than building parallel fight systems.
- Four approved placeholder audio assets exist: Clink, Break, Tinkle and Whoosh. Distinct ability audio still needs original recordings/synthesis or cleared licensed sources; pitching those four is useful for prototypes, not a complete final sound library.
- Fixed fight camera, grounded queue-pad avatars, no power banners/results overlays, upright UI portraits and retained match hands are creator-approved constraints.

## Reference limits

The official [Blade Ball listing](https://www.roblox.com/games/13772394625/Blade-Ball) was checked as context. Its public page is insufficient to verify individual ability timings or internal systems; none are presented here as researched specifications. We are using the creator's desired spectacle as a direction and proposing original glass-themed kits.

The earlier local [Ball VS Ball brief](BALL_VS_BALL.md) explicitly labels its claims unverified. Do not treat its individual powers, statistics or monetization claims as evidence for this plan. No competitor scripts, art, source-code resources or third-party plugins were imported.

Blender manual FBX pages failed to load through the research tool. Export recommendations therefore follow the existing working repo helper and Roblox's importer documentation, rather than claiming newly verified Blender-version behavior. Shader/flipbook export must be checked in the first import proof.

## Recommendation

Build one polished collision/shatter example and a six-glassy prototype: Pop, Jam, Prism, Crescent Axe, Briar Flask and Arc Coil. That exercises six different things to watch: pressure buildup, a visible block, aimed fire, a physical-looking sweep, growing spikes and stored electricity. Expand only once these remain readable together and feel satisfying in real fights.
