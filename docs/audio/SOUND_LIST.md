# Sound list

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
