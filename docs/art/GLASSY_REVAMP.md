# Glassy revamp (v3) — workstream C

Revamp of the 24 release glassies in Blender: cleaner silhouettes, better glass, more toy appeal, and separately moving `Details` parts that Studio animates for idle motion and hit reactions. Plan: [RELEASE_OVERHAUL_PLAN](../design/RELEASE_OVERHAUL_PLAN.md) workstream C. Art rules: [ART_BIBLE](ART_BIBLE.md).

- **Sources:** `assets/blender/glassies/<id>/v3/` (new folder; `release_v2/` and older files are untouched).
- **Build script:** [glassy_revamp/tools/build_glassy_v3.py](glassy_revamp/tools/build_glassy_v3.py) (loads the shared helper and the release_v2 builder, then builds one glassy per call).
- **Motion manifest for Studio:** [glassy_revamp/motion_manifest.json](glassy_revamp/motion_manifest.json) (all glassies) and `assets/blender/glassies/<id>/v3/manifest.json` (per glassy, same schema as release_v2 plus `motion` and `pivot`).
- **Import steps:** [glassy_revamp/IMPORT_V3.md](glassy_revamp/IMPORT_V3.md).
- **Before/after sheets:** `docs/art/glassy_revamp/batch_<n>_before_after.png`.

## 1. Audit (release_v2, Oct 18)

Ranked by how much work each needs. "Gap" compares the presentation to the rarity a player paid or pulled for.

| # | Glassy | Rarity | Silhouette | Glass / tint | Detail and toy appeal | What can move |
|---|---|---|---|---|---|---|
| 1 | Glass Dragon | Mythic | Bowling pin from a 20-segment lathe; wings are flat cut-outs; no horns, feet or real tail | Single flat mint; no core | Lowest gap-to-rarity in the set: reads as a Common with a face | wings, jaw, tail, eyes, breath core |
| 2 | Glass Duck | Epic | Lathed "snowman" duck: head sits straight on top, no tail, wings are blobs | Muddy olive tint | Cute face but generic | wings, tail, head tuft, crown bubble, eyes |
| 3 | Comet | Legendary | Lumpy teardrop; tail is one flat cardboard polygon | Pale, dull; core is a flat disc | Legendary with almost no detail | layered tail fins, star core, sparkles |
| 4 | Prism Blade | Epic | Flat slab sword, tiny on screen | Single flat blue | No gem, glow or edge treatment | gems, orbiting prism shards |
| 5 | Galaxy Orb | Mythic | Lumpy 20-segment sphere; chunky rings | Good purple; plain bead core, no galaxy | Idea is right, execution is plain | rings (with moons), galaxy swirl, stardust |
| 6 | Rocket Pop | Epic | Pop with flat sticker fins | Same as Pop | No flame, porthole or rocket read | fins, flame, fizz, cap |
| 7 | Crescent Axe | Rare | Plain flask; hook stopper reads as a "?" | Lavender OK | Identity only visible during its power | crescent stopper, emblem |
| 8 | Briar Flask | Rare | Flask with paper-flat thorns | Good green | Rose seed is a flat disc | thorns (kit), leaves, bud |
| 9 | Frostglobe | Rare | Good dome; inner crystal is a flat cut-out | Good | Inside is empty; no snow | snow swirl, crystal, pearl |
| 10 | Water Jug | Common | Lumpy handle, chunky spout | Good blue | Water insert is a flat slab | water (slosh), cap |
| 11 | Glass Cup | Common | Clean but the plainest object in the game | Clear | Nothing to look at | straw, rim |
| 12 | Arc Coil | Rare | Good read; coils float off the body | Good | Terminal is a plain ball | coils (kit), sparks, terminal |
| 13 | Hot Sauce | Uncommon | Good bottle; embers are tiny dots | Good red | Needs a pepper cue | chili charm, embers |
| 14 | Chime | Uncommon | Lumpy bell from a 20-segment lathe | Good teal | Clapper hidden | clapper (kit), ribbon |
| 15 | Hourglass | Rare | Strong read | Good | Frame posts thin; no top sand | frame (kit), sand, stream |
| 16 | Ketchup Bottle | Common | Good | Good | Badge floats; nozzle tiny | flip cap, nozzle |
| 17 | Lemonade Bottle | Common | Good | Olive-ish tint | Lemon badge OK | lemon slice, cap |
| 18 | Pop | Starter | Good | Good | Bubbles good | cap, bubbles (kit), fizz |
| 19 | Crystal Tumbler | Uncommon | Good cut glass | Good | Empty | ice cube |
| 20 | Mason Jar | Uncommon | Good | Good | Bands good | lid, fireflies |
| 21 | Pickle Jar | Common | Good | Good | Pickles are smooth capsules | pickles |
| 22 | Jam | Starter | Good | Good | Plain lid | cloth cover, lid, jam |
| 23 | Milk Bottle | Common | Good | Good | Good | foil cap, milk (slosh) |
| 24 | Prism | Starter | Good, approved | Good | Lens fine | stopper, sparkle |

Common problems across the set: 20-segment lathes show faceting on curved glass; every body has smooth shading across hard rims (blotchy highlights); flat extruded polygons for wings, tails and blades; almost nothing moves at rest.

## 2. Shared v3 rules

**Keep:** id, hang-point origin (0,0,0), body height and width within ±5% of release_v2 (fight geometry and `Radius` depend on it; any change is listed in §5), Body + Shards glass only, every detail name the client already drives (see §4).

**Upgrade everywhere**
- Round bodies: 24–32 lathe segments, smooth profiles with crisp rims (sharp edges by angle, so FBX carries split normals and highlights stay clean).
- Volumes instead of flat cut-outs: wings, tails, blades and fins are bevelled, tapered solids.
- Organic bodies (Duck, Dragon) are built from overlapping volumes, voxel-remeshed into one closed mesh and decimated to budget.
- Inner layers: liquids, cores and fillings are separate inner meshes so the glass reads as glass.
- Toy proportions: chunkier caps, bigger features, rounded ends.

**Tier the elaborateness by rarity**

| Tier | Moving parts | Extras |
|---|---|---|
| Starter / Common | 1–2 simple (cap wobble, liquid slosh, one charm) | Clean single-tint glass, one inner fill |
| Uncommon | 2–3 | One small character prop (ice cube, charm, fireflies) |
| Rare | 3–5 | One emissive accent (glow seed, spark, crystal) |
| Epic | 4–7 | Emissive core, a layered glass element, orbiting or flickering bits |
| Legendary / Mythic | 6–10 | Emissive core + layered glass + several animated systems (wings + jaw + tail, rings + moons + swirl) |

**Budgets:** intact (Body + Details) ≤ 1,500 tris, ≤ 3,000 for Legendary/Mythic. Shards: 16 (Starter–Rare), 18 (Epic), 20 (Legendary/Mythic), closed, volume ratio 1 ± 0.001.

## 3. Motion vocabulary (what Studio implements)

Every animated detail has a pivot: an empty named `Pivot_<Detail>` in the .blend (position = pivot, local Z = motion axis), and the same pivot and axis in the manifest in both Blender and Roblox coordinates (`roblox = (x, z, -y)`, the convention the release_v2 normaliser uses). Distances are in studs at model scale 1; multiply by `GlassyScale`. Angles are degrees, times seconds.

**Idle** (`motion.idle.type`)
- `sway` — rotate about the axis by `amp_deg * sin(2π t / period_s + phase)`.
- `spin` — rotate about the axis at `deg_per_s`.
- `bob` — translate along the axis by `amp_studs * sin(...)`.
- `pulse` — scale about the pivot by `1 + amp * sin(...)`; for Neon parts also lerp brightness/transparency.
- `slosh` — liquids. Rotate about the axis by `-gain * swingAngularVelocity`, clamped to `max_deg`, through a spring (`freq_hz`, `damping`). Keeps liquid roughly level as the glassy swings.
- `flicker` — random scale jitter `amp` at `rate_hz` (flames, sparks).
- `blink` — scale along the axis to 0.1 for `dur_s` every `interval_s` (± 40% random). Eyes.

**Hit reaction** (`motion.hit.type`, on any received or dealt contact; scale by hit tier from workstream B)
- `kick` — rotate about the axis by `deg` (sign from the hit side) and spring back (`freq_hz`, `damping`).
- `hop` — translate along the axis by `studs` and spring back.
- `squash` — scale along the axis by `factor` and spring back.
- `flare` — like `kick` but always opens outward (wings).
- `flash` — Neon/brighten for `dur_s`.
- `spin_boost` — add `deg_per_s` decaying over `dur_s`.

Parts with no motion are `static`. Low-detail mode: run only the first moving part listed per glassy (marked `lod_keep`).

## 4. Names the client already drives (kept in v3)

`ChargeBubble_n` (Pop), `CoilSegment_n` (Arc Coil), `Thorn_n` (Briar Flask, pivot-scaled), `RayLens` (Prism), `Cap` (Pop rattle), `StressBand_n`, `Ember_n`, `LemonPulp`, `StarCore`, `CrystalSprout` (glow on charge), `WaterInsert`, `SandInsert` (scaled by charge), `FoamBubble_n`, `FrameCap*`/`FramePost*` (Hourglass flip), `OrbitBand_n` (spun about their own centre), `Wing*`, `Jaw`, `Clapper` (rocked about `AnimationPivot`). New parts use names that do not collide with these patterns (for example the duck's wings are still `Wing_L/R` on purpose so the existing charge flap works).

## 5. Per-glassy briefs

Order of work: Mythic/Legendary/Epic, starters, Rare, Uncommon, Common. Collision: `Radius` comes from `Glassies.luau`; v3 bodies keep release_v2 body bounds unless noted in the results table (§6).

### Batch 1 — Epic and up

**Glass Dragon (Mythic).** *"A baby dragon who sneezes glitter and thinks it's terrifying."*
- Visual: one chubby remeshed body (big round head, pinched neck, pear belly, stubby feet), soft belly plate in pale glass, two swept horns, three back spines, eyes with shine dots, a proper muzzle with nostrils, membrane wings with three scalloped fingers, curled tail with a spade tip, a Neon breath core glowing through the chest.
- Moving parts: `Wing_L/R` (idle `sway` 14° at 1.4 s, mirrored; hit `flare` 28°), `Jaw` (idle `sway` 4° at 2.6 s; hit `kick` 18° = a little roar), `Tail` (idle `sway` 12° about vertical at 1.9 s; hit `kick` 20°), `BreathCore` (idle `pulse` 0.08 at 1.6 s; hit `flash`), `Eye_L/R` (`blink`), `Horn_L/R` static, `BellyPlate`, `Spines`, `Muzzle` static.

**Galaxy Orb (Mythic).** *"A pocket universe that hums to itself."*
- Visual: perfect 32-segment orb with a short neck, star-tipped crown, a Neon spiral galaxy disc inside (layered: tinted inner glass shell around it), a bright core star, scattered Neon stardust, two thin orbit bands, each carrying two moons.
- Moving parts: `OrbitBand_1/2` (kept names; idle `spin` 40/-55 °/s around their tilted axes; hit `spin_boost` 240 °/s), `GalaxySwirl` (idle `spin` 25 °/s; hit `flash`), `StarCore` (idle `pulse` 0.1 at 1.2 s; also the client's charge glow), `Stardust` (idle `spin` -12 °/s), `HangCrown` (hit `kick` 10°).

**Comet (Legendary).** *"Always in a hurry, even when hanging still."*
- Visual: smooth teardrop head (round bottom, pulled up into the tail), chunky five-point Neon star core, three tapered layered tail fins (large to small, different tints) streaming up and back, three tiny four-point sparkles.
- Moving parts: `TailFin_1..3` (idle `sway` 8° at 1.1 s, phase-staggered so the tail ripples; hit `kick` 16°), `StarCore` (kept; idle `pulse`; hit `flash`), `Sparkle_1..3` (idle `spin` around the head at 60–90 °/s; hit `spin_boost`).

**Prism Blade (Epic).** *"Prism's brave older sibling. Polishes itself between rounds."*
- Visual: faceted sword blade with a raised centre ridge and bevelled edges (not a slab), a rainbow inner sliver of layered glass, winged crossguard with a Neon gem, wrapped hilt rings, pommel gem, two little prism shards orbiting the blade.
- Moving parts: `PrismShard_1/2` (idle `spin` around the blade axis 70 °/s plus `bob`; hit `spin_boost`), `GuardGem` (idle `pulse`; hit `flash`), `PommelGem` (hit `flash`), `Crossguard`, `Hilt` (kept, static), `RainbowCore` static glow.

**Rocket Pop (Epic).** *"Pop grew fins and found a launch pad."*
- Visual: Pop's bottle with rocket shoulders, a porthole ring, bigger swept and bevelled fins, a metal booster nozzle, a Neon booster flame, inner fizz bubbles, a red cap with crimp.
- Moving parts: `BoosterFlame` (idle `flicker` 0.12 at 14 Hz; hit `squash` 1.5), `Fizz_1..3` (idle `bob` 0.06 at 0.9–1.3 s), `Cap` (hit `hop` 0.08), `RocketFin_1..3` (kept names; hit `kick` 6°), `Porthole` static.

**Glass Duck (Epic).** *"Quack. Clink. Quack. Unbothered."*
- Visual: one remeshed duck body (round breast, head forward over it, perky tail), sunny yellow glass instead of olive, chunky orange beak, eyes with shine, wing volumes, a head-tuft curl, the crown bubble kept as its charm, a Neon heart core behind the chest (Epic glow).
- Moving parts: `Wing_L/R` (idle `sway` 6° at 1.8 s; hit `flare` 30°), `TailFeather` (idle `sway` 10° at 1.2 s), `HeadTuft` (hit `kick` 25°), `CrownBubble` (idle `bob` 0.05 at 1.5 s), `Eye_L/R` (`blink`), `HeartCore` (idle `pulse`).

### Batch 2 — starters and first Rares

**Pop (Starter).** *"Small bottle, big dreams, bigger burps."* Smoother 24-segment bottle with a belt band, crimped crown cap, soda fill. Moving: `Cap` (kept; hit `hop`), `ChargeBubble_1..3` (kept; client-lit), `SodaFill` (`slosh`).

**Jam (Starter).** *"Grandma's toughest jar."* Gold lid with a gingham cloth cover and tie band, jam fill with two strawberry chunks. Moving: `ClothCover` (idle `sway` 3°; hit `hop`), `JamInsert` (kept; `slosh`), `Cap` (kept, static), `LidRidge` (kept).

**Prism (Starter).** *"A perfume bottle that thinks it's a gemstone."* Crisper octagonal facets with chamfered shoulders, taller diamond stopper, front lens kept. Moving: `GemStopper` (idle `sway` 3°; hit `kick` 12°), `RayLens` (kept; client-lit), `Sparkle` (idle `spin` around the stopper).

**Crescent Axe (Rare).** *"A night-watch flask that dreams of being a knight's axe."* Squat flask with silver-blue shoulders, a proper crescent-moon stopper, a glowing crescent emblem on the front. `AxeHandle`/`AxeHead` kept effect-only for the kit. Moving: `CrescentStopper` (idle `sway` 5°; hit `kick` 15°), `CrescentEmblem` (idle `pulse`).

**Briar Flask (Rare).** *"Prickly outside, rosy inside."* Flask wrapped in a glass vine with two leaves, real 3D thorns (kept names and pivots), a rose bud inside that glows. Moving: `Thorn_1..3` (client-grown), `Leaf_1/2` (idle `sway` 6°), `LeafStopper` (hit `kick` 12°), `RoseSeed` (idle `pulse`).

**Arc Coil (Rare).** *"Static-cling champion."* Copper cap, three coils (kept), a glowing terminal with two zig-zag sparks. Moving: `CoilSegment_1..3` (client-lit), `Spark_1/2` (idle `flicker` + `spin`), `Terminal` (idle `pulse`).

### Batch 3 — remaining Rares and Uncommons

**Hourglass (Rare).** *"Patient. Very, very patient."* Turned frame caps with knobs, thicker posts, sand in both chambers, a thin falling stream. Moving: frame flip (kept names, client), `SandInsert` (kept), `SandTop` (idle `pulse` small), `SandStream` (idle `flicker`).

**Frostglobe (Rare).** *"A snow day you can carry."* Dome with snowy base, a faceted glowing crystal tree inside, a swirl of snowflakes, pearl hang knob. Moving: `SnowSwirl` (idle `spin` 30 °/s; hit `spin_boost`), `CrystalSprout` (kept; glow), `HangPearl` (hit `kick`).

**Mason Jar (Uncommon).** *"Screw-top tough, with a jar full of fireflies."* Threaded neck, gold lid, stress bands (kept), two Neon fireflies. Moving: `Firefly_1/2` (idle `bob` + slow orbit), `Cap` (hit `kick` 8° about vertical, the quarter turn).

**Hot Sauce (Uncommon).** *"Small bottle, big kick."* Slim bottle with a flame-shaped label band, embers (kept), a chili charm hanging from the neck. Moving: `ChiliCharm` (idle `sway` 10°; hit `kick` 25°), `Ember_1..3` (client glow).

**Crystal Tumbler (Uncommon).** *"Heavy-bottomed, razor-rimmed, ice cold."* 12 deep cut facets, thick base, rim kept, a floating glass ice cube. Moving: `IceCube` (idle `bob` + slow `spin`; hit `hop`), `MirrorFacet` kept.

**Chime (Uncommon).** *"Rings the start of every round, whether you asked or not."* Smooth 28-segment bell, flared rim, visible clapper, ribbon bow at the crown. Moving: `Clapper` (kept; idle `sway` 6°; hit `kick` 30°), `Ribbon` (idle `sway` 5°).

### Batch 4 — Commons (simple and clean)

**Milk Bottle.** *"Fresh from the doorstep, extra creamy."* Foil cap, milk fill, foam kept. Moving: `Cap` (hit `hop`), `MilkInsert` (`slosh`).
**Pickle Jar.** *"Briny, stubborn and surprisingly strong."* Bumpy pickles that float. Moving: `Pickle_1/2` (idle `bob` + small `sway`).
**Ketchup Bottle.** *"Takes a while to get going."* Squeeze-bottle shape, hinged flip cap. Moving: `FlipCap` (hit `kick` 35°, pops open then shuts).
**Glass Cup.** *"Thin rim, sharp clink, bendy straw."* Clean cup, bendy straw. Moving: `Straw` (idle `sway` 4°; hit `kick` 15°).
**Water Jug.** *"Big, round and full of splash."* Smoother jug and handle, water fill. Moving: `WaterInsert` (kept; `slosh` + client charge scale).
**Lemonade Bottle.** *"Zesty and bubbly."* Brighter lemon tint, lemon slice on the neck. Moving: `LemonSlice` (idle `sway` 4°; hit `kick` 14°), `LemonPulp` (client glow).

## 6. Results

Filled in per batch as glassies finish (tris, shards, body bounds vs release_v2, radius notes, round-trip). See §7.

## 7. Status

| Batch | Glassies | State |
|---|---|---|
| 1 | Dragon, Galaxy Orb, Comet, Prism Blade, Rocket Pop, Duck | in progress |
| 2 | Pop, Jam, Prism, Crescent Axe, Briar Flask, Arc Coil | pending |
| 3 | Hourglass, Frostglobe, Mason Jar, Hot Sauce, Crystal Tumbler, Chime | pending |
| 4 | Milk, Pickle, Ketchup, Glass Cup, Water Jug, Lemonade | pending |
