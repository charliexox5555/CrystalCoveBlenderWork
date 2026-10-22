# Daily and Playtime rewards v2: Studio verification (decision 115)

October 21, 2026 · Studio "Testing glass game", Play (1 client, fresh mock profile), dev hooks `ServerStorage.RetentionDev` (`Calendar`, `Advance`, `Inspect`) and `OnboardingDev` (`Step` = Done).

| # | What | Result |
|---|---|---|
| 01 | Join with today's Daily reward ready, onboarding done | Daily Rewards **opened by itself** (about 1 s after the loading screen). Day 2 shows Whiskers, Day 7 shows Midnight, the coin days show 100/150. |
| 02 | Claim Day 2, then Day 7 (real clicks on CLAIM) | Coins 0 → 100 → 475. The profile snapshot shows `whiskers` owned (Count 1). The calendar reads 7/7. |
| 03 | Playtime: `Advance` 10 then 45 minutes | Each reached gift **collected itself**: small toasts at the top left ([coin] +75, +100, +125, [XP] +200, each with the playtime clock), coins burst out of the toast into the wallet. Coins 100 → 400. |
| 04 | XP gift | The 45-minute gift's 200 XP took the profile from Lv 1 to **Lv 2** (snapshot `Level = 2, Total = 200`). |
| 05 | Whiskers' Yarn Toss (PowerVFX preview) | Butt-wiggle windup, glass yarn ball with spinning yarn loops and a thin trail, pink/gold tangle loops wrapped round the struck glassy while it is slowed. |
| 06–08 | Midnight's Lullaby | Rocking windup with gathering stars; violet/gold rings with star notes; **"z z Z"** floats over the sleepy foe; the next clash pops a gold star burst and clears the Zzz. |
| 09 | Installed models | Both v4 models at `ReplicatedStorage.Assets.Glassies` (verify: Ok). The crescent and the kitty match their Blender builds. |
| 10–11 | Item pictures | Rendered with the shared icon pipeline from the in-game portrait framing. |

Sound: the new `PW_MusicBox` (ProSoundEffects 9117042092, "Music Box Swan Lake Single Notes 3") loads, `TimeLength` 2.42 s.

Lune 238/238. Studio RunAll on the Play server: 238/238.

Notes:
- The Rojo Studio plugin was disconnected this evening (the server wasn't running). I restarted `rojo serve` and pushed this work's files into Studio as exact diffs, after checking Studio held the parent commit. Re-connect Rojo in Studio before the next session's work.
- Studio installs (models, icons) live in the place file. **Save / publish the place** to keep the two models.
- The 1024 px Midnight picture was still in moderation; the 512 px one is used meanwhile (`Config/ItemIcons` falls back to Small).
