# Crate Machines v2 — Burst Dome (Finishers) and Cloud Globe (Flyers) — 2026-10-16

The creator asked for cooler Finisher/Flyer crates made in Blender (vibe reference: glass gumball machines and a projector with a light cone; nothing copied). Six concepts were rendered (`assets/blender/crates_v2/concepts/`); the creator picked **Sky Dome** (re-themed purple as the Finisher **Burst Dome**) and **Cloud Globe** for Flyers. Coin and Marble versions share a design: currency trim colour (gold `#FFD98A` / blue `#93BCFF`) and a front emblem (coin with star / marble in a ring).

## Files

- Builder: `tools/blender/build_crate_machines_v2.py` (concepts + `build_final(out_dir)`; refuses to overwrite a revision).
- Revision r1: `assets/blender/crates_v2/r1/` — `CRATE_MACHINES_V2.fbx`, `manifest.json` (per-mesh Roblox centre/size/colour/material/animation metadata), `crate_machines_v2.blend`, `review_coins.png`, `review_marbles.png`.
- Uploaded Model asset **115123551485957** (group 11116787). Raw insert archived as `ServerStorage.CrateMachinesV2Raw`.
- Installer: `tools/studio/install_crate_machines_v2.luau` → `ReplicatedStorage.Assets.CrateMachines.{Finishers,Rideables}_{Coins,Marbles}`.
- Config: `src/shared/Config/CrateMachines.luau` (timings, idle speeds, lobby effect numbers).
- Animator: `src/client/Presentation/CrateMachine.luau`; lobby ambience: `src/client/Controllers/CrateMachineController.luau`.

Triangles: Burst Dome 2,740, Cloud Globe 3,692 (per template, one emblem each).

## Template contract (for the lobby/map and future machines)

- `Model`, `PrimaryPart = Root` (invisible collision footprint box). Pivot = floor centre, **front faces -Z**.
- `Root.PromptPoint` attachment: where a ProximityPrompt goes. `RevealCore.LaunchPoint` attachment: where prizes come from.
- Attributes: `CrateMachineVersion = 2`, `Category`, `Currency`, `Triangles`; CollectionService tag `CrateMachine`.
- Part names: `Body*` matte (SmoothPlastic), `Trim*` currency-tinted (`CurrencyTint = true`), `GlassChamber` (Glass), `RevealCore` (neon heart), `RevealLid` + other `Lid = true` parts (move together when opening), `Spin*`/`Neon*` detail.
- Per-part motion attributes: `Idle` = `Spin` | `Orbit` (around RevealCore) | `Swirl` (around GlassChamber) | `Bob` | `Blink` | `Crank`; optional `SpinAxis` (Vector3) and `SpinSpeed` (rad/s).

## Behaviour

- Shop previews and the opening stage clone the machine into their ViewportFrame (`ItemPresentation.crate` prefers `CrateMachines` and falls back to the old `Crates` capsules) and idle-animate it: swirling contents/shards, spinning core and propeller, blinking lamps, bobbing glider.
- Opening (Finishers/Flyers only; Glassies unchanged): reels → **anticipation** 1.5 s (crank winds, contents spin up to 8×, core grows and heats to white, machine trembles) → **opening** 0.45 s (lid lifts 1.2 studs and spins, propeller races, core flash; the viewport frames headroom so the lid stays in view) → reward cards launch from the core as before. Title reads BURST DOME / CLOUD GLOBE. Purchase, quotes, odds and rewards are untouched.
- Placed machines in Workspace (tagged) animate only within 90 studs of the local player and get one pooled PointLight + sparkle emitter each (client-only, returned to the pool when far).

## Verification (2026-10-17)

- `tools/studio/verify_crate_machines_v2.luau` (Play client, no purchases): **46/46** — all four category/currency openings use the right machine and title, core grows during anticipation, lid stays shut until release then opens and stays inside the viewport frame, first card launches from RevealCore (<3 px), pose resets on destroy, no leaked audio; `Item.crate` preview idles; the two showcase machines in Workspace get their pooled light.
- Studio `RunAll` passed; Lune **134 passed, 0 failed**. Existing Glassy Kiln path unchanged.
- Screens checked in Play: Burst Dome charging, Cloud Globe lid popped. Creator feel and phone review remain.

## Preview framing and kilns (2026-10-17, creator follow-up)

- `src/client/Presentation/CrateFraming.luau` frames machines and kilns front-on (12° down, 30° FOV), centred, filling 92% of the tighter axis, refitting on resize; the opening stage adds lid headroom. Settings: `Config/CrateMachines.Framing`.
- `ReplicatedStorage.Assets.Kilns.{Coins,Marbles}` are read-only copies of the creator's lobby kilns (`tools/studio/install_kiln_previews.luau`); the Marble Kiln preview/opening now use the creator's recoloured Marble Kiln. `Assets.Crates.Glassies` remains as fallback.
- Checks: 16 framing cases (centre within 2%, fill 92%) and 24 opening checks over all categories/currencies. Before/after screens in `docs/testing/crate_framing/`.
