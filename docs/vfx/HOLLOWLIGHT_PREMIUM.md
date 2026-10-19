# Hollowlight premium pass (workstream I)

Oct 19 2026. The creator approved the Hollowlight concepts and asked for more "wow", the most premium feel in the game and special sound effects (decision 89). This pass keeps every approved concept, id, price, ownership and rule. **Presentation and audio only:** Lantern Seeds rules and `Balance.CombatRelease.Kits.hollowlight` are untouched.

| Piece | Code | Numbers | Art |
|---|---|---|---|
| Lantern Eclipse finisher | `Presentation/HollowlightFX.luau` | `Balance.CosmeticPresentation.Eclipse` | `Assets.Seasonal.Hollowlight.lantern_eclipse`, `EclipseMoon` (v3) |
| Lantern Seeds power | `Presentation/LanternSeeds.luau` | `Balance.CombatVFX.LanternSeeds` | the eclipse ghost wisps, reused small |
| Moonlantern Carriage flyer | `Presentation/CarriageFX.luau` (new), hooked from `RideController`, `BundleStage`, `ShowcaseController` | `Config/HollowlightAudio` (ride), `Balance.CosmeticPresentation.Carriage` | `hollowlight_v5` (new Blender revision) |
| Sound | `Config/FinisherAudio` (lantern_eclipse), `Config/HollowlightAudio` (new: seeds, ride) | `Config/Audio` + `AudioCues` (Hollowlight section) | Creator Store, free licensed library only |

## 1. Research (short)

- **Premium tiers sell layered extras, not just a skin.** In Valorant's tiers, "Premium" is the first tier with custom audio, VFX and a finisher, and the top tiers add more elaborate VFX and several finishers ([Eneba skins guide](https://www.eneba.com/hub/?p=16404), [GameRiv Exclusive list](https://gameriv.com/valorant-exclusive-edition-skins-full-list-of-skins/)). Takeaway: the top set is a **family** with a shared sound and colour motif across every item.
- **Roblox seasonal cosmetics are event-themed sets.** Blade Ball's Halloween events sold a themed crate with named explosions (Crypt Burst, Banshee Wail) and a Haunted Merchant set ([Sportskeeda](https://www.sportskeeda.com/roblox-news/blade-ball-battle-royale-update-spooky-showdown-haunted-merchant), [Pocket Gamer](https://www.pocketgamer.com/roblox/haunted-harvester-in-blade-ball/)). BedWars sells Halloween final-kill effects in its event shop ([Sportskeeda BedWars 2024 shop](https://www.sportskeeda.com/roblox-news/bedwars-halloween-event-2024-shop-all-purchasables-price-list)). Takeaway: the kill moment is the showcase, and the theme carries across the item set.
- **Timing sells the effect.** Set timing early, use a clear anticipation before the blast and let the follow-through resolve ([VFX Apprentice, timing in VFX](https://www.vfxapprentice.com/blog/the-soul-of-effects-what-is-timing-in-vfx)). As a rough guide, anticipation runs at 30–50% of the main action ([animation principles playbook](https://playbooks.com/skills/dylantarre/animation-principles/anticipation-payoff)).
- **Mobile budget.** Keep particle rates low and use `Emit` sparingly; `Emit` bypasses Roblox's quality-level scaling, so scale counts by quality yourself ([Roblox particle emitter docs](https://create.roblox.com/docs/effects/particle-emitters), [DevForum performance thread](https://devforum.roblox.com/t/performance-considerations-improvements-and-optimizations-when-making-a-game/817499)).

What the rest of the game sets as the bar: POWER_VFX_V2 tiers (Hero = bloom, ground ring, unique mesh, Ready orbiters) and the standard finishers being rebuilt by workstream G. Hollowlight must sit visibly above both. It does that through **length and staging** (a 3.2 s show with a real hush), **a world change** (moon shadow and a grade), **a choir** (more actors) and **its own sound motif**.

## 2. The Hollowlight sound motif

One idea runs through all three items: **the Lantern Chime**, a glass bell rung as a rising minor triad (pitch ×1.0, ×1.19, ×1.5 on `LanternBell`). It's spooky but friendly and reads as "Hollowlight" anywhere you hear it:
- Seeds: each planted seed rings the next note (seed 1, 2, 3 climb the triad), and the bloom plays the whole arpeggio.
- Eclipse: the gather rings the triad as the ghosts arrive.
- Carriage: take-off rings the triad up, and landing rings it down.

Supporting layers (all checked in Studio; ids and trims in §6): a rising musical-saw sting (spooky-quirky), a soft vocal "choir" pad, a howling-wind shadow sweep, a deep boom for the eclipse hit, the glass break, a falling-shimmer ember tail, and a sparkle bed plus soft hum for the ride loop.

## 3. Lantern Eclipse v2 (3.2 s from impact)

Before → after: the 2.2 s show with 3 ghosts and a small release becomes a 3.2 s show with a real gather, a hero moment that changes the world, a hush and an ember finale.

| t (s) | Beat | Picture | Sound |
|---|---|---|---|
| 0.00–0.30 | **Ignite** | Impact spark. The pumpkin lantern pops in with squash and stretch, and the **glow core** (orange neon heart and PointLight) lights up. | Lantern Chime note 1 (and the existing impact layer) |
| 0.30–1.00 | **Gather** (bigger anticipation) | **Five** ghosts swoop in on a wide spiral (low detail: two). An ember swirl is sucked into the lantern. The ground halo spreads. The glow core brightens. | Saw riser, chime notes 2 and 3 as the ghosts land, ghost whoo |
| 1.00–1.55 | **Eclipse (hero moment)** | The glass crescent moon slides across the lantern. Its **shadow sweeps across the arena floor** (a dark violet disc gliding under the lantern). The viewed screen **grades to moonlight** (cooler and darker), while the lantern core stays hot orange. The ghosts circle tight and **sing in a wave**: mouths open, bob in turn, beams bind them to the lantern. | Shadow-sweep whoosh, choir pad swells |
| 1.55–1.70 | **Hush** | Everything pulls in 10%, the light dims, the ghosts freeze. A beat of near silence. | (gap) |
| 1.70 | **Release** | White flash, the grade flips to a warm flash, shock crown plus ring, light pop and camera kick. The lantern **shatters into orange glass**: Hollowlight's real shards, lit and tinted alternately. The ghosts burst upward with trails and stars fly out. | **Deep eclipse boom**, glass break, magic poof |
| 1.70–3.20 | **Ember fall and exit** | Glowing embers drift down like leaves and wink out. The shards tumble and fade, the ghosts spiral away up, and the moon rises and dissolves. The grade eases back by 2.5 s and the last glint pops at 2.9 s. Nothing lingers after 3.2 s. | Falling-shimmer ember tail, glass twinkle |

- **Readability:** the lantern hangs above the recipient, the shadow is translucent and passes in 0.55 s, and the grade is at most −0.12 brightness for about 1 s, viewed fight only.
- **Low detail** (fights you aren't watching, low quality): two ghosts, no shadow, no grade, no light, half the shards and embers, no trails or beams.
- **Camera:** `CameraHoldSeconds` 2.6 and `KickAt` 1.7 (RoundCosmetics Hollowlight entry).
- **Exit:** the grade has a single owner with a reference count and is restored on destroy, even mid-show.

## 4. Lantern Seeds v2

These layers sit on top of workstream E's shared Ready/cast language (POWER_VFX_V2 §3), which is unchanged. `Kits.hollowlight` keeps `Skip` for kit moments and asks E's states for the **Hero** presentation tier (Ready orbiters, ground ring, bloom). Rarity stays Epic.

| Moment | Before | After |
|---|---|---|
| **Plant** (every clash) | An orange ball pops on, light clink | The seed pops with a 3-glint spark and a mint flame flicker on top, and gets a short orbit trail. **Chime note n** for seed n. |
| **Orbit** | Balls orbit the foe | Seeds orbit with trails and a gentle bob. At 3 seeds they **ripen**: they pulse together, glow brighter and spin a little faster. |
| **Ready** (player side, new) | Shared halo only | Plus the pumpkin's face flickers like a candle, two small mint wisps orbit Hollowlight, and a soft chime triad plays once |
| **Cast flourish** (manual) | Shared flourish | Plus a ring of six tiny ghost heads puffs out of Hollowlight, and a ghost whoo with the arpeggio |
| **Bloom** | Seeds flare | Seeds flare and spin up, then each pops as a little star blossom when its wisp leaves |
| **Wisp home** | Mint ball with a trail | A **tiny ghost** (the eclipse wisp mesh: head, face and tail) arcs home with a trail. Each landing rings a chime note, and the last landing makes the lantern puff (`HollowlightFX.pressure`) with a soft poof and the face glow. |
| **Seed knocked loose** | Glass dust and a clink | Unchanged look; the clink becomes a low chime |

Budget: up to 6 pooled seed parts, 3 pooled ghost wisps (3 parts each), one PointLight, and emitters only through `effects:Burst`. Every part is pooled per fighter and hidden on reset.

## 5. Moonlantern Carriage v5

- **Model polish** (Blender, headless, `hollowlight_v5`):
  - A smoother glass hull: about 1.6× the loft samples and sections, and auto-smooth normals.
  - A mint glow inlay along the hull.
  - Gold star studs on the trim.
  - Neon violet wing edges and separate **wing tips** that flex with a lag.
  - A three-link lantern chain.
  - Hull, seat, wings and engines keep their names, so existing `RideMotion` data and poses still apply.
- **Animation** (`CarriageFX`, carriage only):
  - The wing tips follow the down-stroke with a lag.
  - The lantern's inner flame flickers.
  - The chain swings with the lantern.
  - The engine cores pulse.
  - The tail star twinkles.
- **Magic trail:** a moon-dust stream (pale gold sparkles drifting down) and ghost wisps streaming from the stern, plus ribbon trails at the wing tips. These run only near the camera, like the existing `RideEmitter` effects.
- **Take-off:**
  - A ring of moon dust and wisps bursts from under the hull.
  - The lantern flares, the hull glows briefly and a quick lift settles into the bob.
  - Sound: a whoosh with the chime rising.
- **Landing** (when the ride is removed):
  - The carriage sinks, the lantern puffs into wisps and moon dust falls in a ring.
  - Sound: the chime falling and a soft poof.
- **Ride loop:** a quiet 3D sparkle bed and a soft wisp-engine hum, near the camera only, which fade in at take-off and out at landing.

## 6. Audio bank (new Hollowlight cues)

All are free Creator Store assets from Roblox's licensed libraries (ProSoundEffects and APM Music), like the approved bank. They were loaded and measured in Studio with a silent AudioPlayer→AudioAnalyzer wire (length, onset, peak RMS). Levels are matched to the approved bank's measured peaks.

| Key | Asset | Source name | Length | Use |
|---|---|---|---|---|
| (existing) LanternBell | 9126073001 | Synth Sparkle Tone High Pitch Bell Tone Ding 4 (PSE) | 1.16 s | The Lantern Chime motif (pitched triad) |
| HL_SawRise | [1839909531](https://create.roblox.com/store/asset/1839909531) | Musical Saw Sting (a) (APM, Juice Music "Twisted Tales": "quirky mysterious") | 5.0 s | Eclipse gather riser |
| HL_Choir | [9039578446](https://create.roblox.com/store/asset/9039578446) | Hope Is in the Air (sting b) (APM, Juice Music "Vocal Textures": "beautifully inspiring vocal texture") | 9.6 s | Ghost choir pad, pitched down |
| HL_ShadowSweep | [9120697823](https://create.roblox.com/store/asset/9120697823) | Whoosh By Howling Wind Light Rumbling 1 (PSE) | 6.6 s | Moon-shadow sweep |
| HL_EclipseBoom | [9125401238](https://create.roblox.com/store/asset/9125401238) | Boom Impact Deep Distant Thumping Hits Booming 4 (PSE) | 3.0 s | Deep eclipse hit |
| HL_EmberFall | [9116418291](https://create.roblox.com/store/asset/9116418291) | Magic Tone Falling Shimmer Flanged 2 (PSE) | 6.3 s | Ember tail |
| HL_Twinkle | [9116395089](https://create.roblox.com/store/asset/9116395089) | Magic Glows Soft Clusters Of Chiming Hits 4 (PSE) | 2.5 s | Last glint, wisp landings |
| HL_TakeOff | [9125442175](https://create.roblox.com/store/asset/9125442175) | Cloth Whooshes Fast Whooshes Rumbling Pass Bys 9 (PSE) | 2.4 s | Carriage take-off and landing whoosh |
| HL_RideSparkle | [9125986205](https://create.roblox.com/store/asset/9125986205) | Sparkle Tone Constant High End Shimmer Sparkle 1 (PSE) | 18 s | Ride loop bed |
| HL_RideHum | [9126203855](https://create.roblox.com/store/asset/9126203855) | Wave Tone Constant Clean Hum Random Pitch Bend 14 (PSE) | 4.7 s | Ride loop wisp-engine hum |

Reused approved cues: GhostWhoo, SafetyGlass, MagicPoof, RisingWhoosh, ChimeCluster.

Rejected: the Pocket Ghost stings (APM, no description, can't be confirmed kid-friendly without listening), "Dream Weirdness" (PSE Ghosts: screeching), user-uploaded fire and ghost sounds (unknown licence), and the gong crash (harsh).

**Listening review by the creator is still needed**, as for every bank so far.

## 7. Hooks agreed with other workstreams

- **E (power VFX):** `Kits.hollowlight.Tier = "Hero"` and the `kit.Tier` check in `FX:Tier`. Everything else lives in LanternSeeds.
- **G (finishers):** FinisherFX/FightFinisher/FinisherCamera are unchanged. HollowlightFX owns its grade. FinisherAudio keeps its cue format.
- **H (flyers):** RideController calls `CarriageFX` for rides whose model has `CarriageFX=true`: attach, step after the RideMotion pass, and detach plays the landing.

## 8. Verification

See [docs/testing/hollowlight_premium/README.md](../testing/hollowlight_premium/README.md).
