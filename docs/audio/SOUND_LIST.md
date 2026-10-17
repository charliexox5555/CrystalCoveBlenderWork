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
| Music: lobby, route, battle, tournament final | M2-M4 | Loopable, kid-friendly |

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
