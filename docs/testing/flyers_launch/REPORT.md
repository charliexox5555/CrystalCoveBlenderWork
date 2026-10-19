# Launch flyers + no-flyer stand + ride height: report (workstream H)

2026-10-19. Models by workstream F (Cosmetics V2), installed and wired by H. Families: decision 96.

## Installed in Studio (`ReplicatedStorage.Assets.Rideables`, Edit; the place must be saved)

| Flyer | Rarity | Family | Asset | Fit to manifest | Notes |
|---|---|---|---|---|---|
| Paper Jet | Common | Kneel | 115144514705339 | scale 0.01, size err 0.0000 | crease streamers, paper glints |
| Bubble Pod | Uncommon | Sit | 101371211028774 | 0.0000 | sheen trails, bubble wake |
| Honey Hover | Uncommon | Surf | 90127873036573 | 0.0001 | hex trails, honey drops, orbiting bees |
| Dragonfly | Rare | HandleSit | 71158262594750 | 0.0000 | 4 wing shimmer trails, dew sparkles |
| Carousel | Epic | HandleSit | 77529806457590 | 0.0000 | pony `Bob` + `RiderMount = Pony`, spinning canopy, music twinkles; kept out of the Daily Store Robux rotation (no Epic Standard flyer product yet, A to decide) |
| Sunwing | Legendary | Kneel | 95984254159798 | exact | feather-glass wings, sun-ray trails; out of the Daily Store rotation (no product for that band) |
| Starwhale | Mythic | Sit | 118738400073939 | exact | inner galaxy; Body 0.30 → 0.45 and BodyCore 0.35 → 0.65 transparency so the stars read (in F's manifest since f4d47a7); whale-song loop is the licensed APM library track 1841333389; out of the Daily Store rotation |
| (no flyer) | — | Stand | `Assets.RideStand` | — | faint glass hover pad with shimmer; Stand family uploaded (10 assets) |

Catalog entries in `Config/RoundCosmetics` (G committed the "No Flyer" catalog entry).

## Behaviour changes

- **Ride higher:** `Balance.CosmeticPresentation.RideLift` 2.2 → 4.0. In a round the riders float about 4 studs
  above the pad, stay in frame from the selection/arena camera, and the VS boards don't cover them.
- **No flyer:** MatchStage uses `Assets.RideStand` (RideId/PoseId `stand`) instead of skipping, so the avatar
  stands in the air at rider height with the Stand family's still, confident pose. RidePose disables Freefall
  and FallingDown on the local humanoid while staged and restores them on exit (checked: state Running during
  the round, Freefall re-enabled and root unanchored after).
- **Moonlantern Carriage** rides HandleSit with IK on I's `GripL`/`GripR`. HandleSit was retuned (arms inward,
  legs forward-up) and re-uploaded. Workstream I moved the footrest to (0, 0.35, -1.75).
- **Ride models stream atomically** (`MatchStage`: `ModelStreamingMode = Atomic`). With streaming on, the
  carriage's parts arrived over several frames while the client was already posing the take-off, so 14 parts
  (Hull, Footrest, Handlebar, Backrest, engines...) stayed 2.2–2.6 studs above where they belong and the rider
  sat under the crescent. Now every non-animated part matches the template on the client.

## Checks (Studio Play)

- Real round with nothing equipped: `Ride1=stand`, Stand Idle track, feet within 0.05 studs of the pad
  (`ride_animations/07_no_flyer_stand_pad_raised.jpg`).
- Bots on Honey Hover and Bubble Pod in real rounds at the new height (`01_bubble_pod_r6_round_raised.jpg`).
- Lineup of all five launch flyers plus the stand pad, R15 and R6: all 12 riders in Tracks mode with their family
  Idle; R15 hands IK-locked on Dragonfly and Carousel grips (0.35 studs hand centre to grip)
  (`02_lineup_dragonfly_honey_bubble.jpg`, `03_carousel_and_stand_r15_r6.jpg`).
- Carousel mount: rider-to-saddle height varies 0.003 studs while the pony bobs 0.87 studs on the pole.
- Carriage round: HandleSit tracks + 2 IKs (`ride_animations/08_carriage_handlesit_round.jpg`). After the
  atomic-streaming fix: all 23 static parts within 0.05 of the template (only CarriageFX's bending wing tips
  differ), hands 0.24/0.30 studs from GripL/GripR, soles at Y 6.19 against the footrest top at 6.46, so the feet
  sit on the bar, sunk about a quarter stud (`07_carriage_round_atomic.jpg`).
- Sunwing and Starwhale lineup, R15 and R6, Tracks mode (`04_sunwing_starwhale_r15_r6.jpg`,
  `05_sunwing_closeup.jpg`, `06_starwhale_stars_visible.jpg`).
- Lune 164/164.

## Not covered

- Phone presets (Studio MCP can't switch Device Emulator).
- Lobby Flyers display and shop portraits of the seven new flyers were not captured this pass (both clone the
  same templates as the verified four).
