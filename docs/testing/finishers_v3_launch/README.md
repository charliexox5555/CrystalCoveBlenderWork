# Launch finishers (Cosmetics V2): build and Studio verification (workstream G)

2026-10-19. Design: `docs/design/COSMETICS_V2.md` §4 and `docs/vfx/FINISHERS_V2.md` §6. Seven new finishers:
Frost Pop, Gumball, Honeyburst, Hocus Pop, Petalstorm, Starmane, Emberwing.

## What was built

- **Module kit** (`Presentation/Finishers/Modules`): Flash, Shockwave, ShardBurst (pre-computed floor bounces,
  drag, trails, timed pops), BeamColumn, ParticleField (burst/rain/rise/swirl/orbit), Light and `reveal()`
  MeshReveal curves, on the existing rig (`Kit`).
  - `Kit` adds `AddStep`/`StepModules`, glassy heroes (`GlassyHero`/`PlaceHero`, with pose overrides for wings),
    the FinishersV4 library and texture fallbacks.
  - FinisherFX adds per-show camera `Beats` and `attachShards`, which Emberwing uses to light up the winner's
    shards.
  - Prism Pop's flash and ring now come from the modules, with the same parameters.
- **Hero meshes** (`tools/blender/build_finishers_v4.py`, headless): 17 meshes, 4,698 tris. Asset 120805864098504
  (Approved), installed in `ReplicatedStorage.Assets.VFX.FinishersV4` by `tools/studio/install_finishers_v4.luau`
  (raw insert archived in `ServerStorage.FinishersV4Import`, all parts double-sided).
- **Glassy heroes:** Starmane uses the Glass Unicorn glassy, Emberwing the Glass Phoenix, Hocus Pop the Potion Flask.
- **Textures:** Snow, Petal, Ember, Feather, Heart, Hex (Decals in `finishers_v4/roblox_assets.json`; image ids in
  `Config/FinisherShows.Textures`).
- **Sound:** seven cue sets in `Config/FinisherAudio`, plus five ProSoundEffects sounds:
  - FN_IceCrackle 9125611419, FN_BeeBuzz 9113414107, FN_Ribbit 9113858131, FN_WindSwirl 9114374052;
  - FN_SunChime 9126072453 (the Phoenix set motif, played ×1.0/×1.25/×1.5).

  Hoof clops use the approved wood-block sounds pitched up. No ProSoundEffects horse, crank or fire-crackle sound
  exists, so those beats use bank sounds.
- **Catalog:**
  - Six entries in `RoundCosmetics.Finishers` (Rarity, no Matches).
  - `Assets.RoundFinishers.<id>` portrait models (frozen frames) are installed, so they pass the crate
    `available` gate.
  - Emberwing is in `RoundCosmetics.PendingFinishers`, outside the catalog. It moves in when A adds a Coin Mythic
    weight and a Mythic finisher store tier, which CrateTests and DailyStoreTests require.

## Fixes found while verifying

- Gumball (and earlier Piñata Pop) stored a Highlight in `rig.Outline`, which shadowed the rig's `Outline` method.
  The step errored, so parts kept their transparency but never moved. Renamed to `rig.MachineOutline`.
- The unicorn and phoenix read small next to their effects, so both are now 4.4 studs. Emberwing's column core is
  gold.
- FightFinisher resolves pending shows (Studio QA only) and honours decision 95's `""` = no finisher: the winner
  still flies in and breaks, with no show or burst sound.

## Studio verification (lock slot 16:40–16:49)

Contact sheets in Edit (frozen frames at five beats each): `sheet_*.jpg`. These confirmed the meshes, orientation,
the BOOM-style text and the colours.

Real bot rounds (a server QA helper set the match finisher and left both glassies one hit from shattering; the
client logged each show under the fight root one second in):

| Finisher | Round | FV4 mesh parts | Glassy hero | Visible parts at 1 s | Notes |
|---|---|---|---|---|---|
| Frost Pop | match 3 round 2 | 6 | – | 22 | match 1 round 1 showed an empty rig (the first round's view was rebuilt); fine on re-run and in direct play |
| Gumball | match 1 round 2 | 3 | – | 20 | |
| Honeyburst | match 1 round 3 | 22 | – | 24 | |
| Hocus Pop | match 2 round 1 | 2 | Potion Flask | 15 | |
| Petalstorm | match 2 round 2 | 18 | – | 14 | |
| Starmane | match 2 round 3 | (renamed parts) | Glass Unicorn | 29 | |
| Emberwing | match 3 round 1 | 1 | Glass Phoenix | 24 | sunset grade active during the show and removed after |

After the rounds: no rigs left in fight roots and no grade on the camera.

**Direct play (client, in front of the camera, full detail, colour grade allowed):**

| Show | Max visible parts | Rig parts | Avg frame | p95 frame |
|---|---|---|---|---|
| Frost Pop | 29 | 38 | 16.7 ms | 17.1 ms |
| Gumball | 20 | 54 | 19.4 ms | 17.2 ms |
| Honeyburst | 25 | 46 | 16.7 ms | 17.2 ms |
| Hocus Pop | 16 | 53 | 16.7 ms | 17.1 ms |
| Petalstorm | 15 | 35 | 16.7 ms | 17.2 ms |
| Starmane | 30 | 62 | 16.7 ms | 17.2 ms |
| Emberwing | 36 | 98 | 16.7 ms | 17.2 ms |

Every rig was returned to the pool on time.

**Inventory-style previews** (ViewportFrame, 2D preview cues): every show ended on time (1.73 / 1.93 / 1.93 / 2.13 /
2.16 / 2.38 / 2.93 s for 1.7–2.9 s shows), with 3–7 preview sounds at the peak. Every portrait still builds
(14–30 visible parts).

Lune: 164 passed, 0 failed.

## Not done / follow-ups

- Sound levels for the five new sounds are provisional (not yet AudioAnalyzer-matched like the V2 set), and a
  creator listening pass is still needed.
- Phone: the Studio MCP can't switch Device Emulator presets. Touch devices get 70% particles; unwatched arenas
  and the lobby showcase use the low-detail rig.
- Emberwing joins the catalog after A's crate and store decisions.
- Save the place to keep `Assets.VFX.FinishersV4`, `Assets.RoundFinishers.<new ids>` and the import archive.

## Decision 95: nothing equipped = Basic Shatter (later the same day)

- **Fights:** `FightFinisher` treats `""` as the basic finisher. The winner's glass still rises, flies into the
  loser's avatar and breaks with the plain `Shatter:Break` (its own break and tinkle sounds). There is no
  FinisherFX show, no finisher cue set and no camera push beyond the default.
- **Inventory:** "Basic Shatter" is listed first among owned finishers, always owned, and shows as equipped when
  nothing is. Equipping it sends `""`, and its DEFAULT button can't unequip. It has a short preview show
  (`Finishers/BasicShatter`: a glass bubble wobbles, cracks white and bursts) and a portrait still.
  - "No Flyer" (for H) is the flyer twin; its portrait is empty until H installs a RideStand under
    `Assets.Rideables.no_flyer`.
- **Emberwing** is now in the catalog. A's CrateTests update makes Mythic Marble-only.
- **Studio (lock slot):**
  - A fresh mock profile had `EquippedFinishers = ""`; the match sent `""` and the real round ended with the
    winner flying in and breaking (51 shards seen), with no finisher rig and no grade.
  - `tools/studio/verify_basic_shatter.luau`: 13 checks pass (tile first and owned, equipped badge, status,
    DEFAULT inactive, still built, preview plays, badge moves when Frost Pop is equipped, No Flyer listed and
    equipped). Screenshot: `basic_shatter_inventory.jpg` (the match HUD overlay comes from the QA round).
- Lune 164/164.
