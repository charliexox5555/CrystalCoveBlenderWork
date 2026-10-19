# Finishers V2: five premium standard finishers

Workstream G, 2026-10-19 (decision 89 delegation). Owner files: `Presentation/FinisherFX`, `Presentation/Finishers/*`,
`FightFinisher`, `FinisherCamera`, `FinisherAudio`, `Config/FinisherShows`, the five standard entries in
`Config/RoundCosmetics` and `Config/FinisherAudio`, `UI/Components/FinisherStill`. Lantern Eclipse (seasonal,
workstream I) is untouched and stays the seasonal Legendary.

Ids, prices, crate odds, rarities, ownership and purchase flows do not change. Only display names, descriptions and
the presentation change.

## 1. Research: what makes a finisher feel premium

Sources are short and practitioner-level. No studio has published its own finisher design rules, so the principles
below come from those sources plus the house bar set by Lantern Eclipse (decision 74).

1. **Status you can see.** Blade Ball sells explosions and kill effects as pure cosmetics that other players watch
   when you win. Their value comes from being seen, being rare and showing effort, not from power
   ([dungeonpath Blade Ball cosmetics guide](https://dungeonpath.com/posts/blade-ball/trails-and-cosmetics-guide/),
   [Gfinity: Rainbow Explosion](https://www.gfinityesports.com/omg/blade-ball-rainbow-explosion),
   [GameSkinny trading values](https://www.gameskinny.com/tips/blade-ball-trading-values/)). So our finisher has to read
   from across an arena and from a spectator's camera, not only up close.
2. **Spectacle scales with rarity.** Blade Ball splits explosions into Rare, Legendary and Limited tiers, and the
   higher tiers carry more elaborate, more colourful effects
   ([Gfinity](https://www.gfinityesports.com/omg/blade-ball-rainbow-explosion)). Fortnite's tiers work the same way:
   Common/Uncommon are simple, and Epic/Legendary add animation, special effects and reactive elements
   ([Fortnite Wiki: Rarity](https://fortnite-archive.fandom.com/wiki/Rarity)). A player should be able to guess the
   tier from the effect alone.
3. **Wind-up, climax, fall-off.** An effect needs a wind-up that tells you something is coming, a single clear pop,
   and a fall-off where intensity drops away gradually. Peak intensity does not need to mean more emitters. Tune the
   timing on simple blocks first ([VFX Apprentice: timing](https://www.vfxapprentice.com/blog/the-soul-of-effects-what-is-timing-in-vfx)).
4. **Sync to the event, not a timer.** Effects drifting a few frames from the contact feel disconnected. Hit-stop and
   secondary action (shake, particle burst) amplify the moment without changing gameplay
   ([MCO: animation polish and game feel](https://mocaponline.com/blogs/mocap-news/animation-polish-game-feel-guide)).
   **For us: the peak lands exactly when the winner's glassy hits the loser.** The gather plays during the winner's
   flight, so there's no extra wait.
5. **Names are part of the item.** Short, punchy, kid-readable names that describe the payoff (Blade Ball's
   "Rainbow Explosion"). Our phone tiles clip near 11 characters ("Pocket Nova" was slightly over, DEVLOG
   2026-10-17), so every new name is 10 characters or fewer.

House rules on top of the research: glass first (refraction, rainbow facets, sparkle, tinted glass), kid-friendly (no
violence, sparkly not scary), the foe's avatar stays readable, original art only, mobile budgets.

## 2. Shared structure

Every show is one timeline in seconds from show start, driven by a single Heartbeat clock (the HollowlightFX
pattern):

| Beat | What happens | Typical length |
|---|---|---|
| **Gather** | Anticipation: pieces fly in, something swells, light dims or pulses | 0.40–0.60 s |
| **Peak** | One frame of maximum contrast: flash, shock ring, light, sound impact, camera kick | instant |
| **Release** | The signature payoff flies out | 0.5–0.9 s |
| **Linger** | Slow, quieter tail: glitter, drifting pieces, a final small pop | 0.6–1.0 s |

- **Fight timing:** `FightFinisher` starts the show `PeakAt` seconds before the winner's impact (the flight takes
  0.65 s, and every `PeakAt` is shorter). The peak is the impact. Lantern Eclipse keeps its own start (impact).
- **Preview timing:** inventory/shop previews and the lobby showcase play the same show from t = 0.
- **Still:** `FinisherStill` builds the same actors and freezes them at `StillAt` (just after the peak), so icons,
  portraits and cards always match the real effect.
- **Pooling:** each show builds its actors once and reuses them from a small per-finisher pool (2 rigs per
  finisher and detail level). A rig the caller destroys is simply dropped.
- **Low detail** (unwatched arenas, lobby showcase, low graphics): about half the actors and particles, and no
  trails, beams, lights, Highlights or post-processing.
- **Budgets per show (full detail):** at most 60 parts, about 250 live particles at the peak, at most 1 light,
  1 Highlight, and 1 ColorCorrection for 0.3 s. Low detail: at most 25 parts and about 80 particles.
- **Camera:** every peak adds a small shake through the fight's `CombatFeel` (reduced motion respected). Epic and
  Legendary add an FOV punch. Hold and kick timings are per finisher (`CameraHoldSeconds`, `KickAt`).
- **Post-processing:** Legendary only. A ColorCorrection dims slightly through the gather, then gives a bright, warm
  peak for 0.25 s and is gone by 0.6 s. Never in previews, never with reduced motion, never in low detail.

### Rarity ladder (existing tiers, unchanged)

| Tier | Finisher | Length | Layers added at this tier |
|---|---|---|---|
| Common | Prism Pop | 1.7 s | hero mesh set, flash, ring, 2 particle layers |
| Uncommon | Piñata Pop | 1.9 s | + squash-and-stretch hero, streamer trails, comic outline |
| Rare | Fizz Bloom | 2.1 s | + point light, bubble chain reaction in the linger |
| Epic | Ka-Block | 2.3 s | + bigger shake and FOV punch, comic sign, a payoff pose (blocks spell BOOM) |
| Legendary | Supernova | 2.4 s | + post-processing grade, beams, star trails, implosion hush, double shock |

## 3. Per-finisher designs

Colours are hex. Times are from show start; **P** marks the peak.

### Prism Pop (`glass_burst`, Common, free starter). Was "Crystal Pop"

*"A crystal shell snaps shut around your foe and pops into rainbow glass."*

- **Concept:** a faceted geode-like prism shell assembles out of thin air around the foe, glows, and bursts into
  rainbow-tinted glass facets, like light splitting through a prism.
- **Colours:** ice `#7EDFF2`, white `#FFFFFF`, rainbow facet tints (6 hues at 0.35 saturation).
- **Storyboard:**
  - 0.00–0.40 Gather: 12 shell facets streak in from about 6 studs out on curved paths and snap into a shell
    (radius 2.6) with a slight overshoot. Glint particles sparkle on the seams. The shell edges brighten.
  - 0.40 **P**: a white flash ball, a ShockCrown ring and a glint burst. The facets blow outward, spinning.
  - 0.40–0.90 Release: 6 thin rainbow prism slivers fan out and fade. The facets arc out under light gravity.
  - 0.90–1.70 Linger: glitter rains down, and the facets shrink and fade.
- **Layers:** Blender `PrismFacet` set (12 pieces of one shell), `PrismSliver`; particles StarGlint (burst) and
  Glitter (linger); flash ball; ring. Camera: small shake.
- **Sound:** Rise MagicRiser (charge); Fly RisingWhoosh; Burst: ChargeGlass at 0.05 (shell forming),
  **SafetyGlass at P** (impact), ShatterScatter at 0.55, ChimeCluster at 0.75 (glitter tail).

### Piñata Pop (`party_burst`, Uncommon). Was "Party Pop"

*"A stained-glass piñata drops in, wiggles, and bursts into confetti and candy gems."*

- **Concept:** a five-point stained-glass piñata star drops in on a ribbon, squashes, wiggles, cracks, and bursts.
- **Colours:** pink `#F9ADDA`, butter `#FFE790`, plus a rainbow of confetti.
- **Storyboard:**
  - 0.00–0.25 Drop: the star falls from 6 studs above with stretch, then squashes on arrival.
  - 0.25–0.50 Wiggle: it shakes faster and faster with growing tilt. Its rim pulses white and sparks fly.
  - 0.50 **P**: the 5 points and the core fly apart, a confetti cannon fires (60 flipbook confetti), and a ring and
    flash go off.
  - 0.50–1.10 Release: 10 candy gems and 8 confetti curls arc up and out. 4 gems trail streamer ribbons.
  - 1.10–1.90 Linger: confetti flutters down with drag and spin, and the pieces fade.
- **Layers:** Blender `PinataPoint` (×5), `PinataCore`, `CandyGem`; reused `ConfettiCurl`; particles Confetti
  (flipbook) and StarGlint; Trails; one Highlight outline on the piñata for a comic read.
- **Sound:** Rise PartyHorn; Fly RisingWhoosh; Burst: Boing at 0.22 (landing), CapRattle at 0.35 (wiggle),
  **MagicPoof at P**, BubblePop at P+0.02, PartyHorn at 0.62, CapRattle at 1.15 (confetti patter).

### Fizz Bloom (`bubble_bloom`, Rare). Was "Bubble Bloom"

*"A giant soda-fizz bubble swells, pops, and blooms into a bouquet of bubbles that pop in a chain."*

- **Concept:** soda-bottle fizz. Bubbles stream up, a giant shimmering bubble swells around the foe and wobbles,
  pops in a splash crown, then a flower of bubbles blooms out and pops one after another.
- **Colours:** mint `#80E8DA`, periwinkle `#A9BBFF`, and an iridescent cycle (mint, lilac, peach).
- **Storyboard:**
  - 0.00–0.55 Gather: fizz particles rise. The big bubble (ForceField material, animated shimmer) swells to radius
    3.2 with jelly wobble, and 6 small bubbles orbit inward and get swallowed.
  - 0.55 **P**: the bubble pops. The `FizzCrown` splash erupts upward, a ring and droplets fly, and a point light
    flashes mint.
  - 0.55–1.20 Release: 12 bubbles bloom out in two petal rings (a flower seen from the camera) and bob.
  - 1.20–2.10 Linger: the bloom bubbles pop in a ripple from inside to outside, 90 ms apart. Each pop is a mini
    ring plus a glint.
- **Layers:** Blender `FizzCrown`; native spheres (ForceField and Glass); particles Fizz (rising bubbles), Droplets,
  StarGlint; PointLight. Camera: small shake.
- **Sound:** Rise Bubbles; Fly RisingWhoosh (high); Burst: Bubbles at 0.05 (swell), **SplashBloom at P**, BubblePop
  ×4 at 1.22, 1.32, 1.42, 1.52, Bubbles at 1.3 (tail).

### Ka-Block (`brick_boom`, Epic). Was "Block Boom"

*"Glass toy blocks stack into a tower, go KA-BLOCK!, and land spelling BOOM."*

- **Concept:** cartoon toybox. Glass alphabet blocks rain down and stack around the foe, a comic burst sign pops
  "KA-BLOCK!", and the tower blows apart in a golden puff. Four letter blocks bounce to a stop in a row facing the
  camera, spelling **B O O M**, then pop into sparkles.
- **Colours:** tangerine `#FFAE62`, lemon `#FFF2A0`, glass block tints (sky, mint, pink, lemon).
- **Storyboard:**
  - 0.00–0.55 Gather: 8 blocks drop in staggered (50 ms) and land in a 2-high ring with squash. The tower trembles.
  - 0.55 **P**: BlastBloom puff, ShockCrown, a spark burst and a gold light. The comic sign pops in with overshoot.
    Bigger shake and FOV punch.
  - 0.55–1.40 Release: the ring blocks tumble out on arcs. The 4 letter blocks arc to a row 2.5 studs in front of
    the foe (toward the camera) and bounce twice.
  - 1.40–2.30 Linger: BOOM wobbles, then each letter pops into sparkles left to right. The sign shrinks away.
- **Layers:** Blender `ToyBlock` (rounded glass cube), `BlockLetterB/O/M` (inset letters), `BurstSign` (comic
  starburst plate) with SurfaceGui text; reused BlastBloom and ShockCrown; particles Sparks and StarGlint;
  PointLight; one Highlight outline on the BOOM row.
- **Sound:** Rise ToyBlockA, ToyBlockB; Fly RisingWhoosh (low); Burst: ToyBlockA at 0.12, ToyBlockB at 0.27,
  ToyBlockA at 0.42 (stacking), **SoftBoom at P**, MagicPoof at P+0.01, Boing at 1.18 (letters land), ToyBlockB at
  1.3, ChimeCluster at 1.75 (letters pop).

### Supernova (`starfall`, Legendary). Was "Pocket Nova"

*"Stars spiral into a glass star core, everything goes quiet, then it explodes into a rainbow supernova."*

- **Concept:** a tiny glass galaxy collapses into a star core, a hush, then a stained-glass supernova with light
  rays, double shockwaves and a shower of shooting stars.
- **Colours:** violet `#A995FF`, rose `#FFAFE9`, gold core `#FFE9A8`, white peak.
- **Storyboard:**
  - 0.00–0.50 Gather: the screen dims slightly (Legendary grade). 5 NovaStars spiral inward with trails, a
    stained-glass `StarHalo` ring spins up, beams link each star to the `StarCore` gem, and the core pulses faster.
  - 0.50–0.62 Hush: the stars are swallowed, the core shrinks, the halo tightens, and it goes silent.
  - 0.62 **P**: a white-gold flash, 8 neon `NovaRay` blades fan out, a vertical and a horizontal ShockCrown, a
    bright warm grade, a light at full, an FOV punch and shake.
  - 0.62–1.40 Release: 10 shooting stars arc out with rainbow trails. The rays retract, and the halo expands and
    fades.
  - 1.40–2.40 Linger: stardust drifts, and a last little star twinkles in the centre and pops at 2.2.
- **Layers:** Blender `StarCore`, `StarHalo`, `NovaRay`; reused NovaStar and ShockCrown; particles Stardust
  (flipbook), StarGlint; Beams; Trails; PointLight; ColorCorrection.
- **Sound:** Rise CosmicRiser; Fly RisingWhoosh; Burst: ChargeGlass at 0.0, MagicRiser at 0.1 (spiral), **MagicPoof
  at P**, SoftBoom at P+0.01 (low weight), FallingShimmer at 0.8 (shooting stars), ChimeCluster at 1.3, Twinkle at
  2.15.

## 4. Assets

- Blender source: `assets/blender/round_cosmetics/finishers_v3/` (built headless by
  `tools/blender/build_finishers_v3.py`), FBX uploaded through Open Cloud to group 11116787 and installed at
  `ReplicatedStorage.Assets.VFX.FinishersV3`. Each show falls back to native parts if a mesh is missing.
- Textures (rendered in the same script): StarGlint, Glitter, Confetti 4×4 flipbook, Fizz bubble, Stardust. Their
  IDs go in `Config/FinisherShows.Textures`; missing IDs fall back to the existing combat texture bank.
- Sounds: the approved finisher bank, plus two free ProSoundEffects additions (Boing, Twinkle), recorded in
  `docs/audio/SOUND_LIST.md`.

## 5. Verification plan

Run each finisher in a real bot round and in the Inventory preview, check a phone viewport (844×390), confirm no
leftover instances after each show and after the match, and record frame cost. Results:
`docs/testing/finishers_v2/README.md`.
