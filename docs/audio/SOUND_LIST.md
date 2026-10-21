# Sound list

Current follow-up: the creator requested replacement combat sounds on 2026-10-15. A 14-cue bank is saved in `ServerStorage.CombatReleaseStaged.VFX.Combat.Audio`; exact IDs/provenance and measured starts/fades are in `assets/vfx/combat_release/native_library.json`. All 14 load on the client. `Config/Audio` and `AudioCues` now wire the new contact/shatter bank into playback; the old approved IDs remain recorded below and in Git. Listening review is pending. See [current checkpoint](../testing/combat_release/FIRST_SIX_CHECKPOINT.md).

| Sound | Priority | Notes |
|---|---|---|
| Clink (3-4 variants) | M1 | Pitch per glassy (`ClinkPitch`) |
| Crack layer | M1 | Plays when a new crack stage appears |
| Shatter (layered: break + tinkle of falling shards) | M1 | The most important sound in the game |
| Whoosh (swing) | M1 | Short, pitch varies with swing power |
| PERFECT! sting | M1 | Bright chime |
| UI click / open / close | M2 | Soft glass taps |
| Repair (reverse shatter) | M2 | Shatter reversed + sparkle |
| Evolution | M2 | Build-up, crack, burst |
| Cork throw, wobble, catch / escape | M3 | |
| Crate open (shatter reveal), rarity stings | M3 | |
| Tournament start, final, champion fanfare | M4 | |
| Music: lobby, route, battle, tournament final | M2-M4 | Loopable, kid-friendly. Lobby playlist, Fight, Overtime and stings since 2026-10-21 (see Background music below) |

Record real glass clinks if you can (safely, with care); they'll be unique. Otherwise use licensed Creator Store audio and list the IDs here.

## Approved M1 placeholders

User approved these four free ProSoundEffects Creator Store audio assets on 2026-10-12. Roblox's [audio asset documentation](https://create.roblox.com/docs/audio/assets) describes its licensed professional sound library as free to use in Roblox experiences. Config: `src/shared/Config/Audio.luau`.

| Use | Asset ID / source | Duration verified in Studio |
|---|---|---|
| Clink, pitch per glassy | [9114596112](https://create.roblox.com/store/asset/9114596112) | 0.466 s |
| New crack stage (short layer) + final break | [9114590269](https://create.roblox.com/store/asset/9114590269) | 2.048 s |
| Falling shard tinkle | [9114592117](https://create.roblox.com/store/asset/9114592117) | 2.517 s |
| Swing whoosh | [9125805579](https://create.roblox.com/store/asset/9125805579) | 1.141 s |

Preload parented Sound instances; raw URL preloads did not fetch these as audio. All four instances report IsLoaded=true in the current place. Final sound quality and device volume still need a real-phone listening check. No extra Creator Store asset is authorized by this list.

## Finisher sound bank (approved 2026-10-16)

Creator approved these 15 ProSoundEffects Creator Store sounds (Roblox's licensed library) for finisher sound design. All load in Studio; lengths measured there. Names are the keys in `src/shared/Config/Audio.luau`; trims in `AudioCues.luau`; per-finisher timelines in `Config/FinisherAudio.luau`.

| Name | Asset ID | Source name | Length | Used by |
|---|---|---|---|---|
| MagicRiser | [9125646918](https://create.roblox.com/store/asset/9125646918) | Magic Whooshes Pass Bys Metallic Shimmering 7 | 1.82 s | Crystal Pop |
| CosmicRiser | [9125646721](https://create.roblox.com/store/asset/9125646721) | Magic Whooshes Pass Bys Metallic Shimmering 5 | 3.08 s | Pocket Nova |
| RisingWhoosh | [9125805579](https://create.roblox.com/store/asset/9125805579) | Rising Whoosh Hissing Build Up Ascending Swoosh 2 | 1.14 s | all (launch) |
| SafetyGlass | [9118763987](https://create.roblox.com/store/asset/9118763987) | Safety Glass 2 | 2.87 s | Crystal Pop |
| ChimeCluster | [9116394876](https://create.roblox.com/store/asset/9116394876) | Magic Glows Soft Clusters Of Chiming Hits 2 | 2.01 s | Crystal Pop, Nova, Eclipse |
| PartyHorn | [9117240379](https://create.roblox.com/store/asset/9117240379) | Party Horn 4 | 2.72 s | Party Pop |
| MagicPoof | [9116406610](https://create.roblox.com/store/asset/9116406610) | Magic Poofs Thumpy Wheezy Exhale 1 | 1.16 s | Party Pop, Nova, Eclipse |
| Bubbles | [9125409840](https://create.roblox.com/store/asset/9125409840) | Bubbles Small Underwater Above Water Quality 5 | 1.45 s | Bubble Bloom |
| SplashBloom | [9125703162](https://create.roblox.com/store/asset/9125703162) | Mud Puddle Splash Shallow Water Impacts Hits 19 | 0.81 s | Bubble Bloom |
| ToyBlockA | [9120917438](https://create.roblox.com/store/asset/9120917438) | Wood Impacts Soft Impacts On Temple Blocks 1 | 0.49 s | Block Boom |
| ToyBlockB | [9120917813](https://create.roblox.com/store/asset/9120917813) | Wood Impacts Soft Impacts On Temple Blocks 6 | 0.50 s | Block Boom |
| SoftBoom | [9125404320](https://create.roblox.com/store/asset/9125404320) | Boom Impact Deep Distant Thumping Hits Booming 36 | 2.96 s | Block Boom |
| FallingShimmer | [9116418035](https://create.roblox.com/store/asset/9116418035) | Magic Tone Falling Shimmer Flanged 3 | 3.29 s | Pocket Nova |
| LanternBell | [9126073001](https://create.roblox.com/store/asset/9126073001) | Synth Sparkle Tone High Pitch Bell Tone Ding 4 | 1.16 s | Lantern Eclipse |
| GhostWhoo | [9113080188](https://create.roblox.com/store/asset/9113080188) | Airy Pass By Fast Breathing Rush Of Air 4 | 2.39 s | Lantern Eclipse |

No ProSoundEffects confetti popper was found; Party Pop layers the horn, MagicPoof, BubblePop and CapRattle instead. Search: Studio MCP `search_asset`, Creator Store, creator "ProSoundEffects" only.

## Background music (music plan 2026-10-21, decision 109)

Replaces the 2026-10-16 rotation (Rainbow Garden lobby loop, the 30 s "I know that you like it" match loop, Positive Pre School Program for panels/results). All IDs loaded in Studio (IsLoaded=true, no permission or moderation error) on 2026-10-21; lengths are the measured `TimeLength`. Numbers and IDs live in `src/shared/Config/Music.luau` only.

| Slot | Asset ID | Name | Length | Publisher | Plays when | Loop / gain |
|---|---|---|---|---|---|---|
| Lobby A | [78720640408712](https://create.roblox.com/store/asset/78720640408712) | Gravity Well | 240.0 s | DistrokidOfficial (creator pick) | Lobby and lobby panels; alternates with B, random start per join | Crossfade, 0.22 |
| Lobby B | [109260416655887](https://create.roblox.com/store/asset/109260416655887) | Fractal Tide | 239.1 s | DistrokidOfficial (creator pick) | Same | Crossfade, 0.22 |
| Fight | [9042709616](https://create.roblox.com/store/asset/9042709616) | I know that you like it no vocals | 202.0 s | APMOfficial (Invasion From Mars, "Festival Nights") | Rolling, aiming, countdown, fight, spectating | Crossfade, 0.26 |
| Overtime | [9042708952](https://create.roblox.com/store/asset/9042708952) | Heavy Artillery main | 154.9 s | APMOfficial (same album: funky bass into dubstep drops, distorted guitar) | Overtime, or a round where either side is on its last heart (so every Crown Hill round) | Crossfade, 0.24 |
| Tension sting | [103121809098519](https://create.roblox.com/store/asset/103121809098519) | Abiter_Leave | 3.0 s | ARABIC_GOKU1 (user upload, creator pick) | Ends on the release: starts 3 s before `ReleaseAt` (1 s into the 4 s countdown) | One shot, 0.32 |
| Winner | [127039883737564](https://create.roblox.com/store/asset/127039883737564) | winner! | 1.6 s | 4nrxyk (user upload, creator pick) | `MatchResult` with `Won` | One shot, 0.40 |
| Loser | [1844442622](https://create.roblox.com/store/asset/1844442622) | Loser | 1.3 s | APMOfficial | `MatchResult` without `Won` (no sting on a no-contest) | One shot, 0.38 |

The Fight track is the full 202 s no-vocals version of the 30 s cue the creator liked. Overtime alternates if Heavy Artillery is too much: [9042713825](https://create.roblox.com/store/asset/9042713825) "Do you need Me no vocals" (183.9 s, long builds and dance drops) and [9042713847](https://create.roblox.com/store/asset/9042713847) "Do you need Me no melodies" (183.8 s); both from the same APM album, both load. **Licensing note:** the tension sting and winner jingle are ordinary user uploads, not Roblox-licensed library audio; keep them only if the creator is confident they are cleared for use, otherwise swap to an APM sting.

How it plays (`Controllers/MusicController.luau`): beds are cloned from preloaded templates in `MusicMaster/MusicTemplates`, so a track can crossfade into its own next play or the next playlist track. Every long track is "Crossfade": the next play starts 3 s before the end and the two overlap, so hard cuts and ring-outs at the end never show (how each track ends was not checked by ear). Context switches fade (1.5 s in, 1.2 s out) after a 0.6 s settle delay. Overtime: the bed crossfades to Overtime when the `Overtime` FightEvent fires or a round starts with a side on its last heart, and back to Fight only at a new round where neither holds. On `MatchResult` the bed fades out under the win/lose sting, stays silent 0.8 s after it, then lobby music fades in. Ducks: beds dip to 35% for ~2.4 s on the shatter and the Kiln reveal (`PlayerGui.MusicDuckAt`), and to 40% for each sting's length. Stings play in `MusicMaster` beside the duck group, so the Music slider and mute control everything. Listening and mix review by the creator are pending.

## Power sounds (workstream E, 2026-10-20)

Ten free ProSoundEffects Creator Store sounds (Roblox's licensed library) for the v2 signature powers, chosen under the overnight delegation (decision 89). Ids, trims and per-power cues live in `src/shared/Config/PowerAudio.luau`, not in Config/Audio. The cues also reuse approved bank keys (ChimeCluster, LanternBell, SoftBoom, MagicRiser, CosmicRiser, RisingWhoosh, FallingShimmer, Bubbles, BubblePop). Cap: 6 power voices per client. Fights you aren't watching play only the first layer, at 0.6x volume. Load and length checks: `docs/testing/power_vfx/README.md`.

| Key | Asset ID | Source name | Used by |
|---|---|---|---|
| PW_FizzPop | [9117848644](https://create.roblox.com/store/asset/9117848644) | Pops Mouth Popping Multiple Versions 7 | Pop payoff, zone pop |
| PW_LidBonk | [9113911944](https://create.roblox.com/store/asset/9113911944) | Cooking Pot 26 (stainless lid) | Jam block |
| PW_MagicSwirl | [9116408879](https://create.roblox.com/store/asset/9116408879) | Magic Swirling Tone 1 | Prism gather, Galaxy vortex |
| PW_StarExit | [9125635285](https://create.roblox.com/store/asset/9125635285) | Magical Exit Sparkling Pass Bys Clinking Chimes 3 | Comet launch, Unicorn dash |
| PW_Crackle | [9114246605](https://create.roblox.com/store/asset/9114246605) | Electricity Static 7 | Arc Coil windup and bolt, Light Bulb drain |
| PW_AirRush | [9114374049](https://create.roblox.com/store/asset/9114374049) | Fast Pass By Airy Whooshes Windy 8 | Dragon inhale and breath |
| PW_Roar | [9117733732](https://create.roblox.com/store/asset/9117733732) | Polar Bear 1 (first roar, pitched up 1.25) | Grizzly riposte (under SoftBoom) |
| PW_FireBurst | [9114444008](https://create.roblox.com/store/asset/9114444008) | Fire Whoosh 3 | Rocket ignition, Phoenix rebirth |
| PW_FireLick | [9114446852](https://create.roblox.com/store/asset/9114446852) | Fire Whoosh 15 | Hot Sauce |
| PW_SlideUp | [9119198150](https://create.roblox.com/store/asset/9119198150) | Slide Whistle 6 | Glass Top spin |

Creator listening review pending. Watch the roar in particular (kid-friendly level).

## Finishers V2 additions (workstream G, 2026-10-19)

Four free ProSoundEffects Creator Store sounds (Roblox's licensed library) for the five standard finishers (decision 91). Keys are in `Config/Audio`, trims in `AudioCues` and per-finisher timelines in `Config/FinisherAudio`. Searched with Studio MCP `search_asset` (verified creators, ProSoundEffects only). No ProSoundEffects boing or popper exists, so toy blocks and cap rattles cover those beats.

| Key | Asset ID | Source name | Length | Used by |
|---|---|---|---|---|
| FN_MagicBurst | [9116385087](https://create.roblox.com/store/asset/9116385087) | Magic Burst 5 (big beefy impact, glowing decay) | 2.3 s | Supernova peak |
| FN_GlowSwell | [9116393976](https://create.roblox.com/store/asset/9116393976) | Magic Glow Short Pulsing Bursts 9 (humming swell) | 1.8 s | Supernova and Fizz Bloom gather |
| FN_PunchyPoof | [9125640290](https://create.roblox.com/store/asset/9125640290) | Magic Poofs Short Breathy Bursts Wheezy Punchy 2 | 1.5 s | Piñata Pop burst, Ka-Block |
| FN_GlassPing | [9126073644](https://create.roblox.com/store/asset/9126073644) | Synth Sparkle Tone High Pitch Tone Burst Ding 5 (glassy) | 0.7 s | Prism Pop lock, Fizz Bloom and Ka-Block pops, Supernova twinkle |

Creator listening review pending.

