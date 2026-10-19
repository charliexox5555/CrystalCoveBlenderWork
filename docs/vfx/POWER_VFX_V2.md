# Power VFX v2: every signature at finisher quality

Workstream E, Oct 19 2026. Covers the 24 release kits, the shared Ready / cast / armed states, and a reusable kit for the launch powers coming in ROSTER_V2. The quality bar is the Hollowlight **Lantern Eclipse** finisher (`HollowlightFX.luau`): one clock, staged beats (gather → hush → release → dispersal), eased motion with overshoot, unique mesh actors, a ground halo, a flash plus a light, and a shock ring.

Code: `src/client/Presentation/PowerFX/` (engine, states, kits, launch kit), hooked from `HeroPowers` (`Hero.state`, `Hero.start`, `Hero.motion`) and `SignaturePresentation.status`. Numbers: `src/shared/Config/PowerVFX.luau`. Per-kit identity (signature colour, accent, tier): `src/shared/Config/CombatKitVisuals.luau`. Preview: `src/client/Dev/PowerVFXPreview.luau` (run `tools/studio/preview_power_vfx.luau` in Play / Client).

**Status (Oct 19):**
- All 24 kits, the shared Ready, cast and armed states, and the launch-power builders are implemented.
- Verified in Studio Play through the preview harness and through live bot matches with cast policies.
- Report, before/after captures and cost numbers: [docs/testing/power_vfx/](../testing/power_vfx/README.md).
- Still open: creator feel review, a real phone Device Emulator pass, and sounds (workstream B).

**Colour rules learned in Studio:**
- Neon turns pale colours white, so signature colours are saturated mid-tones.
- Ready, cast and armed states use the accent colour when the signature colour is pale (white Prism, cream Milk, silver Tumbler).
- Coloured beams use low light emission; only white cores glow fully.
- Rings and sheets lie in the camera plane, or lean toward it, because the fixed side camera sees direction-facing shapes edge-on.

## 1. Audit (before), Oct 19

Every kit was staged in Studio Play through `PowerVFXPreview`, which plays the kit's real event sequence through the real `CombatEffects` pipeline. Captures are in `docs/testing/power_vfx/before/`. Scores run 0–2: **A**nticipation, **R**elease, **I**mpact, **Rd** readability at the default camera, **Rr** rarity feel.

| Kit | Rarity | A | R | I | Rd | Rr | What we saw |
|---|---|---|---|---|---|---|---|
| Pop | Starter | 0 | 1 | 1 | 1 | 1 | Cap pop is cute; the payoff is two thin rings. Nothing shows while armed. |
| Jam | Starter | 1 | 1 | 0 | 1 | 1 | The lid becomes a flat opaque disc. No rim or glow, and the block has no "bonk". |
| Prism | Starter | 0 | 1 | 0 | 0 | 1 | The ray is about 7 px wide at the default camera, with three tiny rainbow rings. No charge-up or impact flare. |
| Crescent Axe | Rare | 1 | 1 | 0 | 0 | 0 | Small axe and slash. No arc or trail weight. |
| Briar Flask | Rare | 0 | 0 | 1 | 1 | 0 | Generic pressure ring plus chips. No thorn bloom. |
| Arc Coil | Rare | 0 | 1 | 0 | 1 | 0 | A straight pale beam; it does not read as electricity. |
| Milk Bottle | Common | 0 | 0 | 0 | 0 | 0 | A small ring behind the body. The colour clamp turns white into **pink**. |
| Pickle Jar | Common | 0 | 0 | 0 | 0 | 0 | A 1 px white tether and a white half ring. |
| Ketchup | Common | 0 | 0 | 1 | 0 | 0 | A tiny mark droplet; the pop is the generic ring. |
| Glass Cup | Common | 0 | 0 | — | 0 | 0 | A half ring and accent chips. Nothing shows the boost. |
| Water Jug | Common | 0 | 1 | 0 | 1 | 0 | A stiff camera-facing splash card. |
| Lemonade | Common | 0 | 0 | 0 | 0 | 0 | Pale pips are **invisible** against the bright sky. |
| Mason Jar | Uncommon | 0 | 0 | 1 | 0 | 0 | Nothing shows while armed. |
| Hot Sauce | Uncommon | 0 | 0 | — | 0 | 0 | Flames are hidden under the body. |
| Crystal Tumbler | Uncommon | 0 | 1 | 0 | 1 | 0 | A small cyan disc on the body. |
| Chime | Uncommon | 1 | 1 | 0 | 1 | 0 | Gyroscope rings that don't read as a sound wave. |
| Hourglass | Rare | 1 | 1 | 0 | 0 | 0 | The clock ticks hide behind the body. |
| Frostglobe | Rare | 0 | 1 | 0 | 1 | 0 | A flat cyan card. |
| Rocket Pop | Epic | 0 | 0 | — | 0 | 0 | No visible flame or boost. |
| Prism Blade | Epic | 0 | 1 | 0 | 0 | 0 | The crescent is a thin halo. |
| Glass Duck | Epic | 0 | 0 | 0 | 0 | 0 | A small opaque gold disc (the shared guard colour). |
| Comet | Legendary | 0 | 0 | 0 | 0 | 0 | The echo star is a small chip, and the throw has no tail. |
| Glass Dragon | Mythic | 0 | 1 | 0 | 1 | 0 | A flat translucent card over the foe. |
| Galaxy Orb | Mythic | 1 | 1 | 0 | 1 | 1 | Neon rings around itself. |

**Common causes:**
- The default camera sits 33 studs away (FOV 52), so a glassy is about 100 px tall on a 1080p screen and about 40 px on a phone. Shapes under 0.5 studs disappear.
- Pale neon washes out against the bright sky lobby.
- There are no lights, no anticipation beats and no Ready state.
- Most kits share the same generic ring and accent chips.

## 2. Rarity tiers of presentation

| Tier | Kits | Layers |
|---|---|---|
| **Crisp** (Starter, Common, Uncommon) | Pop, Jam, Prism, Milk, Pickle, Ketchup, Cup, Jug, Lemonade, Mason, Hot Sauce, Tumbler, Chime | 2–3 layers: a body cue (wiggle/glow), one bold main shape, and an impact (flash + spokes + glints). Short (≤0.45 s), high contrast, no lights. |
| **Rare** | Axe, Briar, Arc Coil, Hourglass, Frostglobe | Crisp, plus a **distinct secondary motion** (orbiting chips, flung shards, a crackle, a rewinding hand) and a PointLight flash on release. |
| **Epic** | Rocket Pop, Prism Blade, Glass Duck | Rare, plus **two-stage anticipation** (gather, then a tight "hush" just before release) and light that builds during the windup. |
| **Legendary / Mythic** | Comet, Glass Dragon, Galaxy Orb | Epic, plus a **hero moment**: a brief light bloom (ColorCorrection, viewed fight only), a ground ring projected onto the arena floor, a unique mesh (NovaStar, ShockCrown, BlastBloom from `RoundHeroV2`), the Ready aura with orbiting stars, and a sound-layer cue for workstream B. |

Readability guards:
- Every main shape is at least 0.9 studs thick at the default camera.
- Every shape has a white or near-white core over a saturated colour, so it reads on both sky and stand.
- Nothing covers the glassies for longer than 0.15 s.
- Hero bloom is at most +0.12 brightness for 0.3 s. It is skipped with reduced motion, on low detail, and for fights you aren't watching.

## 3. Ready, cast and armed states (shared, every kit)

Split with workstream B (agreed Oct 19): B owns the screen layer (hitstop, shake, FOV, glassy white flash, "NICE CAST!" popup, HUD edge, every sound). E owns the world VFX on the glassy.

- **Ready** (`SignatureReady` until `CastStart`, `SignatureArmed` or `ReadyCancel`), the same look on every kit and tinted per kit:
  - A camera-facing halo ring behind the glassy, plus a kit-coloured outline (Highlight, viewed fight only).
  - The pulse quickens from 1.6 Hz to 4 Hz as `AutoAt` approaches.
  - In the last 0.6 s the halo tightens onto the body, as a "now or never" cue.
  - Rare and up add 3 orbiting glints. Epic adds a rising sparkle. Legendary and Mythic add 5 orbiting stars and a ground ring.
- **Manual cast** (`CastStart.Manual` / `SignatureArmed.Manual`): a kit-coloured flourish on the glassy (white flash core, 8 crystal spokes, ShockCrown ring, light pop). The other side's manual cast plays at 0.6 scale. **Auto cast** gets a plain thin ring and a few glints, so a manual cast always looks better than an auto cast.
- **Armed** (contact-payoff kits Pop, Pickle, Ketchup, Briar, Mason):
  - A charged band orbits the body, with a steady kit-coloured outline and crackle glints.
  - It flickers through its last 0.6 s.
  - It ends on the payoff (`SignatureContact`, Slow/Mark status), on `ArmedFade` (fizzles downward into dust) or at `Seconds`. Briar and Mason never get `ArmedFade`, so their armed look times out locally.

## 4. Per-kit direction

Signature colour is the power's colour. It is not the glassy tint clamped to saturation (that clamp made Milk pink).

| Kit | Colour | Motion idea | Layers | What reads from the default camera |
|---|---|---|---|---|
| **Pop** | aqua #39D2FF, cap red | Armed: the cap rattles and fizz rises. Payoff: the cap rockets off with spin. | flash + aqua ShockCrown 6 studs + 8 bubble domes popping outward | A big aqua pop ring and bubbles flying out |
| **Jam** | gold #FFC23D, jam pink | The lid unscrews, lifts and swings in front as a shield with a glowing rim | gold rim ring + shimmer sweep while up; on block: white bonk flash, gold ring, sparks, lid recoil | A gold lid-shield, then a gold "bonk" ring |
| **Prism** | white core, rainbow | Rainbow motes spiral into the lens (gather), then a thick white beam with a rainbow sheath. The beam thins out instead of just fading. | muzzle flash, 0.5-stud core + rainbow halo, impact NovaStar + rainbow spokes; a miss scatters at range | A thick white-rainbow beam and a star at the hit |
| **Crescent Axe** | lavender #B48CFF, steel blue head | The axe rises with a glint along the edge, then a full-arc crescent slash | big arc mesh sized to the sweep, wide trail, flung chips, light | A purple crescent the size of the swing |
| **Briar Flask** | green #2FD38E, bud pink #FF7AC8 | Armed: thorns ring the flask and slowly turn. Payoff: thorns burst out and a blossom opens. | thorn crown, 8 thorn spokes, pink blossom (NovaStar), petals, light | A green spiky crown, then a pink-green burst |
| **Arc Coil** | electric cyan #4FE8FF, white | Coil segments light up in sequence with crackle around the body, then a jagged bolt | 3-segment lightning (re-jittered each frame), white core, halo, spark burst, flickering light | A zig-zag bolt that flickers |
| **Milk Bottle** | cream white #FFF6E0, cap blue #6FB7FF | Foam bubbles bloom around the bottle and a seal ring tightens on the neck | foam domes, tightening ring, "+" glints | White foam puff and a blue ring |
| **Pickle Jar** | pickle green #7FD65A | Armed: brine bubbles. Payoff: a green splash and a thick wavy brine tether with drips. | splash, 0.35-stud wavy beam (animated CurveSize), slowed foe drips | A green rope between them |
| **Ketchup** | tomato orange-red #FF6A3D (cartoon, never blood-like) | Armed glow; a glossy tomato badge orbits the marked foe; a cartoon splat star on the pop | badge + ring, NovaStar splat, confetti dots | An orange target badge, then a star splat |
| **Glass Cup** | clear blue #6FD3FF | The rim ring lights and spins; speed streaks while boosted | spinning rim ring, trail on, clang ring at the boosted clash | A spinning bright rim |
| **Water Jug** | water blue #2FA8FF, white foam | The water level sloshes up, then a splash wave flows out along the cone | 2 curling splash sheets along the direction, droplet meshes in arcs, splash crown on hit | A blue wave that travels |
| **Lemonade** | lemon #FFD21F, rind green #6CC93A | Fizz rises, then three lemon-slice pips with bright trails | saturated pips + white core + trails, zest burst | Three yellow pips with streaks |
| **Mason Jar** | steel blue #5FB4FF, gold lid | Armed: the lid screws tight and the threads glow. Payoff: a heavy thunk. | thread glow band, thick gold shock ring, chips | A glowing lid band, then a fat ring |
| **Hot Sauce** | red #FF4A2A, flame #FFC24B | A flame aura rises off the bottle for the whole boost | fire particles (rate-limited), heat ring at the base, embers, warm light | A flickering flame aura |
| **Crystal Tumbler** | silver #E6F2FF, rainbow glints | A faceted mirror plate faces the foe with a sheen sweep | plate + hex rim, sheen bar, catch flash | A shining plate on the facing side |
| **Chime** | teal #2FD8D0 | The clapper swings and the bell shivers, then three concentric sound rings | 3 staggered thick rings (camera-facing), notes (glints) | Expanding teal sound waves |
| **Hourglass** | sand #F3BC70, heal green #45F09A | A clock face in front with a hand sweeping backwards (rewind) and sand flowing up | clock ring + ticks + hand, rising sand, green heal burst + rings | A rewinding clock, then green rings |
| **Frostglobe** | ice #8FD8FF, white | Snow swirls inside the globe, then a frosty gust | snow particles in the cone, 2 flowing puff sheets, ice shards on the foe, frost crown while slowed | A white-blue gust and ice spikes |
| **Rocket Pop** | aqua body, flame #FF8A2B → #FFD34E | Two-stage: the fins rattle with sputter puffs, then ignition | flame jets (scaled thorns + fire particles), exhaust trail, flickering light | Big booster flames |
| **Prism Blade** | ice #7FE0FF, white edge | Two-stage: a glint slides down the blade, then the crescent forms and grows | 2.4-stud crescent spinning out and back with a wide trail, X-slash on hit | A spinning crescent boomerang |
| **Glass Duck** | sunny #FFD83A, bubble #BFF3FF | Two-stage: a bubble swells from the bill, then wraps the duck | 1.6× body bubble with an iridescent rim; on block it wobbles and pops (ring + droplets) | A big bubble around the duck |
| **Comet** ★ | ice #B8F1FF, star gold #FFE07A | The echo star hovers and sparkles where it was planted. Two-stage: it shrinks, then flares and flies home with a long tail. | NovaStar actor, long gradient trail, star-burst impact, ShockCrown, ground ring, bloom | A gold star with a comet tail |
| **Glass Dragon** ★ | mint #5FF0C0, sparkle white, pale gold | ≥0.5 s anticipation in two stages: (1) the dragon rears back, wings flare and sparkle motes are drawn into the mouth while a mouth light builds; (2) hush, a tight ring at the mouth. Release: 3 pulses of crystal breath. | breath particles + crystal chips along the cone, flowing sheets, ShockCrown at the mouth, ground ring, bloom, frost bursts per pulse | A glittering mint breath cone |
| **Galaxy Orb** ★ | violet #7A5CFF, star #FFE8A9, magenta | Two-stage: the inner band spins up and stars gather, then a vortex opens | spinning accretion disc (ShockCrown) + spiral arms, a dark-violet core with a bright rim, stars spiralling in, violet light, ground ring, bloom | A swirling purple vortex |

## 5. Launch-power kit (ROSTER_V2 §3–4)

These are reusable building blocks in `PowerFX/LaunchKit.luau`, ready to wire once A adds the rules and C/F import the models:

| Builder | For | Look |
|---|---|---|
| `zone(fx, side, spec)` | Bubble Wand, Honey Bear, Crystal Ball | A floating actor (bubble dome with iridescent rim, a glossy honey blob, or a rune disc), plus a **ground ring and drop shadow** raycast onto the arena floor so depth reads from the straight-on camera. Optional `Delay` telegraph (a ring that fills before it goes live) and a pop on hit. |
| `strike(fx, spec)` | Crystal Ball | A star falls from above onto the rune with a trail, then a star-burst ring. |
| `drain(fx, fromSide, toSide, spec)` | Light Bulb | A charge-steal beam from the foe to the bulb, carrying the foe's colour. Motes travel along it, then the bulb flares. |
| `brew(fx, side, color)` | Potion Flask (Cycle) | A brew-coloured swirl around the flask that shows the next brew. |
| `roar(fx, side, spec)` | Grizzly Guardian riposte | A gold block ring, then a roar shockwave (BlastBloom and ShockCrown) and a ground ring. |
| `dash(fx, side, dir, spec)` | Glass Unicorn | A rainbow trail along the dash with hoof-spark stars, and a guard-shatter mesh burst on a pierced guard. |
| `rebirth(fx, side, spec)` | Glass Phoenix | Light cracks the body, the wings flare and an ember swirl gathers (0.45 s). Then a fire-glass ring pulse, a heal shimmer, a ground ring and bloom. |

Event fields needed from A (requested): zone `CastRelease { Point, Range, Delay, Duration, Kind }` and `CastContact` / `SignatureStatus { Kind = "ZoneEnd" }`; drain `SignatureStatus { Kind = "Drain", Target, Amount }`; `SignatureReady.Next` / `Charge.Next` for Cycle; riposte `CastStart { Riposte = true }`; dash `CastRelease { Direction, PierceGuard }` and `CastContact { Pierced = true }`; rebirth `CastStart { Rebirth = true }`.

## 6. Performance and cleanup

- **One clock:** every effect steps from the fight render time (`Effects.Time`). Hitstop, slow-mo and the preview freeze all apply automatically, and nothing runs its own RenderStepped.
- **Pooled:**
  - Mesh actors come from a per-fight pool folder (`PowerFXPool`, attribute `Pooled`).
  - Particles come from one pooled emitter socket per texture; each burst moves the socket and calls `Emit`. There are no per-effect emitters.
  - Up to 3 pooled PointLights.
  - Outlines are one Highlight per fighter, enabled only while Ready or armed and only in the viewed fight.
- **Low detail** (`f.LowDetail`, fights you aren't watching, or quality level 1–3, or touch-only devices): about half the pieces, no lights, no Highlights, no bloom, no particles over 6 per burst.
- **Budgets:** about 60 live particles per kit moment (mobile caps emitters at 100/s), at most 24 mesh actors per effect, and one hero bloom at a time.
- **Cleanup:** effects stop when their side breaks or finishes, when the scene stops being viewed, on `ReadyCancel` and on round end. `Effects:Destroy()` removes the pool. Leftover checks are in `docs/testing/power_vfx/README.md`.

## 7. Sound cues for workstream B

Moments where a dedicated sound layer would help:
- Ready loop start (soft shimmer) and the last-0.6 s tighten (rising tick).
- The manual flourish (B already plays it).
- Prism gather (rising glass hum).
- Arc Coil crackle loop.
- Dragon inhale, then the breath roar.
- Galaxy vortex whoosh.
- Comet launch and its star chime.
- Rocket ignition.
- Duck bubble pop.
- Jam lid bonk.
- The launch kit: zone pop, drain zap, roar, rainbow dash and rebirth flare.

In code these are marked `-- SFX:` next to the beat.
