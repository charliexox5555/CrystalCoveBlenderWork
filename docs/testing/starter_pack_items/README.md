# Starter Pack items: the Daybreak set (decision 117)

**Creator approved (Oct 21):** after seeing the renders and captures, the creator kept all three as built, choosing them over the offered alternatives (sun-catcher or lighthouse glassy; Rise & Shine or First Light finisher; a smaller kite or a sunrise balloon).

October 21, 2026 · built by the starter-pack-items session while the creator was away. The 49 R$ pack itself (price,
Marbles, screen, receipts) is the monetization session's (decision 116); this report covers its three exclusive items.

Creator brief: *"add a starterpack ... 49 robux. But make it worth while with exclusive items maybe exclusive glass and
finisher maybe add in a flyer ... Make it balanced but also feel like a good deal."*

## The set

A dawn / first-light set: rose, peach, gold and lilac glass. Something new players start with, so it opens the day.

| Item | Id | Rarity | What it is |
|---|---|---|---|
| **Sunny** (glassy) | `sunny_rooster` | Epic, Heavy | A plump glass rooster with a dawn-gradient tail (rose → coral → amber → gold → lilac), a rose comb and wattle, a gold beak and feet, a glowing sun charm on its chest and an amber "sunrise" inner layer. Passive name *Early Bird*; power **Wake-Up Call**. |
| **Daybreak** (finisher) | `daybreak` | Epic | A timed show: dusk falls and Sunny hops in (gather), crows on the impact while a glass sun bursts up behind the foe with a fan of rays (peak), the foe breaks into dawn glass (release), then morning motes rise as the sun climbs and Sunny bows and hops off (linger). |
| **Dawn Kite** (flyer) | `dawn_kite` | Epic, HandleStand | A glass kiteboard: the rider stands on the board and holds a gold control bar; an arched five-cell canopy (lilac, rose, gold, rose, lilac) with a glowing sun pulls it, trailing ribbon streamers. |

All three are Epic: the free Daily calendar already gives an Epic on Day 2 (Whiskers), so a Rare in a paid pack would
read as worse. Names are 10 characters or fewer.

## Not pay-to-win

- Sunny has the same base stats as every Heavy (Power 20, HP 112, Swing 6) and the normal Epic multiplier.
- Real-swing matrix, 8 rounds per pair against all 39 other kits (`tools/release_matrix.sh 8 <mode> "" <out> sunny_rooster`):

  | Mode | Sunny's win rate |
  |---|---|
  | equal stats, cast at once | **51.0%** |
  | equal stats, bots cast (skill 0.5) | 52.9% |
  | real rarity multipliers | 51.9% |
  | real rarity, bots cast | 52.2% |

  All inside the decision 86 band (45–55%). First pass (Damage 0.9, Interval 8) measured 39.7%, so I raised the crow
  to Damage 1.5 with Interval 7 and First 5.
- EconomySim payer report: the 49 R$ "Starter" persona's HP edge over a free player is 0.1% at day 7, 0.0% at day 30.
- The flyer and finisher are cosmetic only.

## Wake-Up Call (Sunny's power)

`Balance.CombatRelease.Kits.sunny_rooster`: a **timer** power (first at 5 s, then every 7 s ± 0.8). Sunny crows a
**volley of three little suns** in a fan (Arc 0.55, Range 6.5, Damage 1.5 shared across the three). Each sun that lands
**dazzles** the foe: a short slow (×0.8 for 1 s, 2.5 s immunity), the same generic Slow rule Whiskers and Honey Bear use.
No new fight rules.

Presentation (PowerFX, decision 90 Epic tier): a two-stage windup where Sunny leans back and puffs up while a little sun
rises behind its head; three spinning sun-stars with gold trails and three expanding sound rings on the beat
(short, short, long, "cock-a-doodle-doo"); a white flash, sun spokes and glints on a hit; three little suns circling
the dazzled foe's head. Sounds (`Config/PowerAudio`): a rising slide whistle on the puff, a toy crow (three slide-whistle
notes over a bright bell) on the release, and a chime on a dazzle. The licensed library has no rooster crow, and a real
crow would be loud, so the crow is a toy, like Whiskers' slide whistle.

## Captures (Studio Play, fresh mock profile)

Test grants: `ServerStorage.CosmeticDev:Invoke("PreviewStarterPack", player)` (new, Studio + mock only) and `Equip`;
onboarding skipped with `OnboardingDev` `Step` `Done`; a real bot match through `MatchDev` `Start`, picking Sunny with
the `PickGlassy` remote. Sunny won 3–2 against Bubble Bot.

| # | File | What it shows |
|---|---|---|
| 01 | `01_render_sunny_34.png` | Blender render of Sunny (v4 glass, 1,498 / 1,500 tris, 18 shards). |
| 02 | `02_render_dawn_kite_rider.png` | Blender render of the Dawn Kite with an R15-sized stand-in on the board (5,422 / 7,500 tris). |
| 03 | `03_roll_card_sunny.jpg` | Sunny's roll card: Heavy, Epic, Wake-Up Call. |
| 04 | `04_starter_pack_screen.jpg` | Monetization's Starter Pack screen (opened by itself) showing the three items live. |
| 05 | `05_aim_on_dawn_kite.jpg` | Aiming in the match: the player rides the Dawn Kite (hands on the bar) and Sunny hangs pulled back. |
| 06 | `06_fight_wake_up_call_dazzle.jpg` | Wake-Up Call landing on Pickle Jar: SLOWED (dazzled), −20, the sunrise light. |
| 07 | `07_daybreak_finisher_match_win.jpg` | Daybreak in the winning round: Sunny beside the bot's pad, the glass sun bursting with rays, the ground rings. |
| 08 | `08_daybreak_still.jpg` | The Daybreak still (frozen at `StillAt`), baked into `Assets.RoundFinishers.daybreak`. |
| 09 | `09_dawn_kite_lobby_display.jpg` | The Dawn Kite on the lobby Flyers display with the player's avatar. |
| 10–12 | `10_icon_sunny.png`, `11_icon_daybreak.png`, `12_icon_dawn_kite.png` | Item pictures (512 px) from the decision 113 pipeline. |

Checks: Lune 259/259 (new `StarterPackItemTests`, 5 tests). Studio RunAll on the Play server 258/259 before the icons
existed; the one failure was the pending icon entry, which now passes in Lune. No script errors from the new items in
the Play console (the "not approved" mesh warnings are the existing Glass Phoenix issue).

## What changed

- **Art:** `docs/art/starter_pack/tools/build_starter.py` (Sunny, on the launch builder) and `build_dawn_kite.py` (on the
  launch flyer builder). Outputs: `assets/blender/glassies/sunny_rooster/v4/`, `assets/blender/round_cosmetics/flyers_v3/dawn_kite/`.
  Uploaded to group 11116787 (`docs/art/starter_pack/roblox_assets.json`): Sunny 75390126341675, Dawn Kite 137770082572265.
- **Studio (lives in the place):** `ReplicatedStorage.Assets.Glassies.sunny_rooster` (install verify Ok),
  `Assets.Rideables.dawn_kite` (flyer installer + `flyer_effects.dawn_kite`: dawn ribbons off the board tail and kite
  tips, sun motes and light, wake, launch puff; raw import in `ServerStorage.FlyersV3Import`), `Assets.RoundFinishers.daybreak`
  (the still; equipping checks it exists).
- **Config:** `Glassies` (`StarterPackIds`, `isStarterPack`, always shown in the Collection), `Balance` kit,
  `CombatKitVisuals`, `PowerAudio`, `ReleaseGeometry`, `ReleaseCrackPaths`, `GlassyMotion` (generated), `RoundCosmetics.StarterPack`
  (+ `isStarterPack`, outside crates, bot loadouts and the daily store), `FinisherShows.daybreak`, `FinisherAudio.daybreak`,
  `Audio.FN_SlideWhistle` (+ an `AudioCues` trim), `RideFamilies` (HandleStand), `RideAnimations.Motion.dawn_kite` (loop:
  ProSoundEffects "Cape Flap Parachute Movement 2", 9113716666), `ItemIcons`, `LoadTiers` (Soon: the two cosmetic
  pictures and the glassy and flyer models; the glassy picture is already Soon with all glassy pictures).
- **Code:** `Presentation/Finishers/Daybreak.luau`, `PowerFX/Kits.sunny_rooster`, `RewardGrant` accepts the glassy,
  Inventory label "STARTER PACK • OWNED", catalog status "STARTER PACK EXCLUSIVE" / "IN THE STARTER PACK".

## For the creator

- **Save / publish the place**: the Sunny model, the Dawn Kite template and the Daybreak still live in it.
- Feel check: the toy crow sound, the dazzle suns, and the kite canopy size (it is big on the lobby display).
- The Sunny picture is a front view (the in-game portrait framing), so its tail hides behind the body; the 3/4 render
  shows it.
