# Flyers v3: premium rebuild of the four standard flyers

Workstream H, 2026-10-19 (decision 89 scope; design calls recorded as decision 90, Proposed).
Replaces the v2 Blender flyers (`assets/blender/round_cosmetics/hero_v2`, decision 67) for
`skyboard`, `cloud_cushion`, `rocket_skiff` and `prism_ray`. Ids, prices, odds, unlock matches and
ownership are unchanged. The Moonlantern Carriage (`lantern_skiff`) belongs to workstream I and only
shares the motion code.

Sources: `tools/blender/build_flyers_v3.py` → `assets/blender/round_cosmetics/flyers_v3/`.
Install: `tools/studio/install_flyers_v3.luau`. Motion: `Presentation/RideMotion` (shared by
`RideController`, `ShowcaseController` and the bundle stage), tuning in `Config/RideAnimations.Motion`.

## 1. What makes a rideable read as premium

From the rideables that set the bar on Roblox (Adopt Me and Pet Simulator hoverboards, Jailbreak and
Bloxburg vehicles) and outside it (Fortnite gliders and hoverboards, Sky's capes, Mario Kart gliders):

1. **One clear silhouette at 60 studs and on a phone.** One big idea per flyer (board, cloud, rocket,
   ray), exaggerated proportions, no thin noise. Detail lives inside the silhouette.
2. **Layered materials.** A glossy hero material (here: tinted glass over a darker inner core), a
   trim material (pearl or gold) that outlines the shape, and a little emissive light (Neon) that
   draws the eye. The v2 flyers were one flat colour per mesh with no layering, so they read as
   plastic.
3. **Bevels everywhere.** Every edge is rounded or chamfered so it catches a highlight; nothing is a
   flat slab with a hard 90° edge.
4. **Secondary motion.** The body bobs on two overlapping waves (never a pure sine), leans with
   acceleration, banks into turns, and its parts move a beat later (fins, tails, wings, puffs,
   fans). This overlap is what separates "animated" from "alive".
5. **An arrival and a departure.** A short launch (rise with overshoot, burst of particles) and a
   soft settle make the flyer feel like a vehicle rather than a prop that pops in.
6. **A constant but quiet VFX signature.** One trail or wake that says what the flyer is (rainbow
   for the cloud, flames for the rocket, prismatic ribbons for the ray), low particle rates, culled
   by distance.
7. **A subtle sound loop.** Very quiet, 3D, short rolloff, so you only hear your own flyer and the
   one next to you.
8. **Rarity shows in complexity.** Common = clean shape + one glow; Epic = moving wings, light veins,
   prismatic trail. Never more effects than the glassy fight can tolerate.

## 2. Shared rules

- **Scale and contact:** 1 Blender unit = 1 stud. Model origin (WorldPivot) is the rider's contact
  point: the deck top under the feet for standing flyers, the seat top under the hips for seated
  ones. `RidePose` solves the feet (or LowerTorso) onto that point, so R15 and R6 both land on it.
  Nose is Blender +Y = Roblox −Z (the model's LookVector).
- **Attachments:** each flyer has `RiderFeet` or `RiderSeat` on its main part, plus named effect
  attachments (`Trail0/1`, `Exhaust_L/R`, `Wake`, `Launch`).
- **Materials (set in Studio; Blender materials are previews):** hero shell `Glass`, transparency
  0.25–0.35, Reflectance 0.1; inner core `Glass`/`SmoothPlastic` darker tint; trim `SmoothPlastic`
  pearl or gold; lights `Neon`. Colours from `Config/RoundCosmetics`.
- **Budgets:** Common and Uncommon ≤ 5,500 tris, Rare and Epic ≤ 7,500 (the Legendary carriage is
  7.9k). Each mesh stays far below Roblox's per-mesh limit. Each moving part is its own mesh with its pivot recorded in `manifest.json`.
- **Effects** are tagged `RideEmitter` (on near the camera only). Launch bursts are tagged
  `RideLaunch` with an `EmitCount`. Each flyer has one `RideLoop` sound, 3D, volume ≤ 0.12, rolloff
  6–40 studs, only played near the camera.

## 3. The flyers

### Skyboard (Common) — keeps its name
- **Silhouette:** a surf-style hoverboard, 7.6 × 2.7 studs. Pointed nose and a rounded squash tail,
  a gentle rocker (nose and tail kick up), a thick bevelled rail.
- **Materials:** aqua glass deck over a deeper aqua core (you see colour depth through the glass);
  pearl rail band; frosted navy grip pad with grooves; a gold stringer down the middle; Neon aqua
  nose gem.
- **Moving parts:** two hover pods under the deck, each a glass disc with a Neon ring that spins
  (`Spin`, Y axis, opposite directions); three small glass tail fins.
- **Signature:** two thin aqua→white `Trail`s from the tail rails, soft sparkle motes falling from
  the pods, wind streaks streaming backward past the rails.
- **Rider pose:** relaxed surf crouch, arms out for balance (existing clip, slightly deeper knees).
- **Sound:** a soft airy hover hum.

### Cloud Cushion (Uncommon) — keeps its name
- **Silhouette:** a plump cumulus armchair, 5.2 × 4.6 studs: a puffy base, a tall back puff, two arm
  puffs and a low footrest puff in front. Seat recess at the origin.
- **Materials:** frosted cloud glass (white with a lavender cast, low transparency so it reads as
  soft), a lavender tufted cushion with gold buttons, a little glass rainbow arc tucked behind the
  back puff.
- **Moving parts:** five underside puffs breathe out of phase (`Puff`); the rainbow arc sways like a
  tail (`Tail`).
- **Signature:** three ribbon trails (pink, butter, aqua) from under the back, soft cloud wisps
  drifting down, a few twinkling stars.
- **Rider pose:** seated, legs forward to the footrest, arms resting on the arm puffs.
- **Sound:** a gentle breezy whoosh, slow.

### Rocket Skiff (Rare) — keeps its name
- **Silhouette:** a retro hover-scooter, 8.2 × 5.6 studs: a long coral glass hull with a pointed nose
  cone, a raised steering column with a T handlebar at the front, twin engine nacelles slung on
  short pylons, and two swept tail fins with gold tips.
- **Materials:** coral glass hull over a darker coral core, a white racing stripe, a navy deck
  plate, gold intake rings, pearl handlebar grips, Neon cores glowing inside the glass nacelles,
  a Neon dashboard gem.
- **Moving parts:** intake fans spinning in each nacelle (`Spin`, Z axis), flickering flame cones
  (`Flame`), fins trimming slightly with the bank (`Fin`).
- **Signature:** layered exhaust (white-hot core flame, orange flame, soft smoke puffs, sparks),
  two short `Trail`s from the fin tips, a heat shimmer launch burst.
- **Rider pose:** standing pilot, knees bent, both hands on the handlebar.
- **Sound:** a low warm engine rumble with a slight flutter.

### Prism Ray (Epic) — keeps its name
- **Silhouette:** a friendly crystal manta ray, 10.4 wingspan × 7.6 studs: a gem-cut faceted body,
  broad swept wings with curled tips, two little cephalic fins at the front, a long whip tail
  ending in a spinning prism.
- **Materials:** lilac crystal glass with bevelled facets over a deeper violet core; mint Neon light
  veins along each wing; pearl saddle with a gold rim; big friendly eyes.
- **Moving parts:** wings flap from shoulder hinges with a quick down-stroke and the veins follow
  (`Wing`), the tail waves with lag (`Tail`), the tail prism spins (`Spin`), the front fins
  flutter (`Fin`).
- **Signature:** prismatic rainbow `Trail`s from both wing tips, rainbow glints shedding from the
  body, a crystal sparkle burst on launch.
- **Rider pose:** wide surf stance on the saddle, arms out like wings.
- **Sound:** a soft crystalline shimmer with a slow wing whoosh.

## 4. Motion (all flyers)

`Presentation/RideMotion` replaces three copies of the old bob code:
- **Float:** two overlapping bob waves plus slow lateral drift; each flyer has its own amplitude and
  rate (`RideAnimations.Motion.<id>`), so the board feels light and the rocket feels heavy.
- **Bank and lean:** banking follows the flyer's yaw rate and sideways velocity (turns in the lobby
  display, drift in matches); nose pitch follows forward acceleration and vertical speed.
- **Launch and settle:** when a ride appears it rises 1.6 studs from below with an overshoot, fires
  its `RideLaunch` bursts, then settles; the lobby display's swap uses the same launch.
- **Parts:** `Wing`, `Swing`, `Spin` (now with `SpinAxis`/`SpinSpeed`), `Pulse`, `Flame`, and new
  `Puff`, `Tail` and `Fin` kinds. Defaults keep the carriage exactly as before.
- **Sound:** `RideLoop` sounds play only while the ride is near the camera and fade in on launch.
- **Cost:** everything is distance-gated (`RideDistance`, `RideEmitterDistance`); per-frame work is
  one PivotTo per ride plus moving parts, no allocations per frame.

## 5. Rider animations (families)

Riders play real Animation assets (owned by group 11116787, R15 and R6), organised in **families** so the planned
~24 flyers share a few well-made sets instead of one-off poses (decision 96).

| Family | Style | Contact | Flyers |
|---|---|---|---|
| Surf | standing balance crouch, arms out | feet | Skyboard, Prism Ray |
| Sit | seated, legs forward, hands on the arm rests | seat | Cloud Cushion |
| Kneel | one knee down, hands forward (low craft) | feet + shins | (for coming low flyers) |
| HandleStand | standing, both hands on a handlebar | feet | Rocket Skiff |
| HandleSit | seated, both hands on a handlebar | seat | Moonlantern Carriage (workstream I) |

Every family has five clips: **Idle** (loop with breathing, weight shifts, head and arm follow-through),
**LeanLeft / LeanRight** (loops, blended in by the flyer's bank; Right is the mirror of Left), **Launch** and
**Land** (one-shots at take-off and when the launch rise settles, and when a lobby display flyer lands).

- Source of truth: `src/shared/Config/RideFamilies.luau` (angles per channel: base pose, offsets, looping waves,
  smoothed keys). `src/shared/RideKeyframes.luau` samples it.
- Assets: `tools/studio/build_ride_animations.luau` turns every family/clip into KeyframeSequences for R15 and R6
  (`ServerStorage.RideAnimations`), which are serialized and uploaded with `tools/opencloud/upload_assets.py`
  (Type `Animation`). Ids go to `RideFamilies.AnimationIds[family][clip][rig]`.
- Playback (`Presentation/RidePose`): the local player and lobby display avatars play the tracks through their
  Animator (Idle at Action priority, leans at Action2 with bank weights, one-shots at Action3). Other players see
  the owner's replicated tracks. Bots (anchored R6 presentation rigs) and any rig whose tracks are missing or fail
  to load within 4 s play the **same keyframes in code**, so nothing ever T-poses. The rig is solved every frame so
  feet or the seat stay on the deck.
- Handle families lock the hands with IKControl onto the flyer's `GripL` / `GripR` attachments (R15 with tracks);
  the authored hands already sit on the standard grip layout, so R6 and code fallback still look right.

## 6. Adding a flyer

The checklist for every new flyer (the launch batch follows it; `tools/blender/build_flyers_launch.py` is F's
builder on top of `build_flyers_v3.py`).

1. **Pick a family** that matches how the rider stands or sits: Surf (SS), Sit (SC), Kneel (KC), HandleStand (HS)
   or HandleSit (HC). Only add a new family when none fits; a new family needs all five clips uploaded for R15
   and R6 (`lune run tools/build_ride_animations <Family>`, then the uploader and
   `tools/write_ride_animation_ids.py`).
2. **Scale:** 1 Blender unit = 1 stud. The default R15 rider is about 5 studs tall, hips about 2.5 above the
   feet, shoulders about 2 studs across. Standing decks are about 2.6–3.5 wide; seats about 1.8 wide. Keep each
   mesh well under 10k triangles and the flyer within the rarity budget (§2).
3. **Origin and axes:** origin = the rider contact point, nose = Blender +Y (Roblox -Z). Standing families: the
   deck top under the feet. Seated families: the seat top under the hips; legs rest about 1.0–1.5 studs forward
   and 0.7–1.0 down (Sit), or on a footrest about 2.0–2.4 forward (HandleSit). Kneel: the keel top; knees land
   about 0.7 forward and shins about 1.3 back.
4. **Attachments** (names are the contract; the installer reads them from `manifest.json`):
   - `RiderFeet` (standing and kneeling families) or `RiderSeat` (seated families) at the origin.
   - Handle families: `GripL` (rider's left, -X) and `GripR` (+X) where the hands hold. Put them on the family's
     standard layout (`RideFamilies.StandardGrips`, rider space): HandleStand (-/+0.96, 2.58, -1.56), HandleSit
     (-/+0.62, 1.46, -1.74). Grips can differ a little; IK locks R15 hands on.
   - Effects: `Trail0`/`Trail1` (a trail is drawn from each point down by about 0.2 studs), `Wake` (wind
     streaks fly backward from it), `Launch` (under the flyer, take-off burst). Optional extras like `Drip0`.
5. **Moving parts** are separate meshes with `RideMotion` attributes in the manifest's `Motion`:
   Wing, Spin (`SpinAxis`, `SpinSpeed`), Pulse, Puff (`PuffPhase`), Flame, Tail (`MotionPivot`, `TailAngle`,
   `TailLag`), Fin (`MotionPivot`, `FinAxis`, `FinAngle`, `FinHz`, `FinPhase`, `FinBank`) and Bob (`BobAmp`,
   `BobHz`, `BobPhase`: a vertical slide). If the rider sits on a moving part (a carousel pony), set the model
   attribute `RiderMount` to that part's name and put the grips on it; the rider follows its motion.
6. **Register:** `RideFamilies.Flyers` (`id = { Family = "..." }`), a motion profile in `RideAnimations.Motion`
   (float, drift, bank, launch and a quiet ProSoundEffects loop), an entry in `Config/RoundCosmetics.Rideables`
   (Id, Name ≤ 12 characters, Rarity, Color, Accent, Description; no Matches) and an effects function in
   `tools/studio/flyer_effects.luau` (trail colours, particles, launch burst). Add the main part to the installer's
   `MAIN` table, or `"Main"` in the manifest.
7. **Upload and install:** upload the FBX (Open Cloud, group 11116787), then in Studio Edit run
   `flyer_effects.luau` + `install_flyers_v3.luau` with `_G.FlyersV3[id] = { AssetId, Manifest }`. It fits the
   import (scale and turn), sets materials and motion signs, adds attachments and effects, and keeps backups.
   Crate pools pick the flyer up once its template is installed.
8. **Check:** `tools/studio/check_flyer_fit.luau` (feet or seat contact, hands on grips), then a real round,
   the lobby Flyers display and the shop portrait, with R15 and R6 riders.
