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
  legs forward-up) and re-uploaded. The v5 footrest is beyond a default R15 leg's reach (asked I to move it).

## Checks (Studio Play)

- Real round with nothing equipped: `Ride1=stand`, Stand Idle track, feet within 0.05 studs of the pad
  (`ride_animations/07_no_flyer_stand_pad_raised.jpg`).
- Bots on Honey Hover and Bubble Pod in real rounds at the new height (`01_bubble_pod_r6_round_raised.jpg`).
- Lineup of all five launch flyers plus the stand pad, R15 and R6: all 12 riders in Tracks mode with their family
  Idle; R15 hands IK-locked on Dragonfly and Carousel grips (0.35 studs hand centre to grip)
  (`02_lineup_dragonfly_honey_bubble.jpg`, `03_carousel_and_stand_r15_r6.jpg`).
- Carousel mount: rider-to-saddle height varies 0.003 studs while the pony bobs 0.87 studs on the pole.
- Carriage round: HandleSit tracks + 2 IKs (`ride_animations/08_carriage_handlesit_round.jpg`).
- Lune 164/164.

## Not covered

- Sunwing and Starwhale (built by F, not uploaded yet).
- Phone presets (Studio MCP can't switch Device Emulator).
- Lobby Flyers display and shop portraits of the five new flyers were not captured this pass (both clone the
  same templates as the verified four).
