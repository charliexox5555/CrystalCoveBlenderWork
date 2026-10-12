# M1 — Feel prototype (task brief for Codex)

**Goal:** one Clash Stand, two glassies, the power meter, cracks and a **great shatter**, playable in Studio and on a phone. Nothing beyond this milestone.

Read first: AGENTS.md, GAME_DESIGN sections 3 (battle), 8 (feel checklist), 12.3 (battle screen), 13 (technical plan), ART_BIBLE, UI_SPEC, and the Battle screen in Figma.

Work in this order. After each step: play-test in Studio through the MCP, read the Output for errors, fix them, run `lune run tools/run_tests`, commit.

## Step 1 — Art (Blender MCP)

1. Load the helper in Blender: `exec(open(r"<repo>/tools/blender/glassclash_blender.py").read())`, then run `self_check()`.
2. **Clash Stand + arena:** `export_clash_stand()` builds and exports a low-poly starting point (two posts, crossbar, two hooks, octagon pen floor and low wall). Improve it if you can, keeping the style in ART_BIBLE. Export to `assets/blender/map/`.
3. **Starters:** `build_all_starters()` builds, fractures (16 shards), renders icons and exports `pop`, `jam` and `prism` in one go (tested in Blender 5.2, about 20 s). The v0 shapes are simple lathe shapes; improve them (chunky, toy-like, readable on a phone) with `build_starter(gid)`, `make_shards(body, 16)` and `export_glassy(gid, body, shards)`.
4. Save each `.blend` under `assets/blender/glassies/<id>/` and the icons under `assets/icons/`.

## Step 2 — Import (Studio MCP)

1. Import the stand into `ReplicatedStorage.Assets.ClashStand` and place one copy in `Workspace` on a simple floor. Add `Attachment`s named `HookA` and `HookB` at the hooks.
2. Import each starter into `ReplicatedStorage.Assets.Glassies.<id>`: `Body` (MeshPart, `Glass` material, tint from `Config/Glassies`, Transparency ~0.3) and `Shards` (Folder of MeshParts, same material). Body pivot = hang point. Keep `Anchored = true`, `CanCollide = false`.
3. Lighting per ART_BIBLE 4.

## Step 3 — Server

1. `src/shared/Remotes.luau`: creates (server) or waits for (client) a `Remotes` folder in ReplicatedStorage with these RemoteEvents: `BattleStarted`, `ClashStarted`, `ReleaseSwing`, `ClashResolved`, `BattleEnded`. One place defines all names.
2. `src/server/Services/BattleService.luau` (follow the service pattern in `src/server/Main.server.luau`):
   - A `ProximityPrompt` on the stand starts a test battle: player's `pop` (level 10) vs an NPC `jam` (level 10, skill 0.35).
   - Loop per clash: fire `ClashStarted` with the server time; accept **one** `ReleaseSwing(battleId, clashIndex, elapsed)` per clash; judge it with `Formula.validateRelease` + `Formula.zoneFromRelease`; time out after `Balance.Meter.MaxHoldTime` → Weak. NPC action from `BattleLogic.npcChooser`.
   - Resolve with `BattleLogic.resolveClash` using a server `Random` (`function() return rng:NextNumber() end`).
   - Fire `ClashResolved` with damage, crits, HP, zones and winner; wait for the swing + bounce time (`Balance.Battle`) before the next clash.
   - Validate every argument type, reject wrong battle ids or clash indexes, and rate-limit `ReleaseSwing`.
3. Keep battle state per player; clean up on leave.

## Step 4 — Client

1. `src/client/Controllers/BattleController.luau`:
   - **3/4 camera** for clashes (slightly above and behind the player's glassy), tween in when the battle starts.
   - Clone both glassies' `Body` onto the hooks; draw strings with `Beam`s between the hook attachment and the glassy.
   - **Pendulum with CFrame (user revision):** swing continuously on a curved arc, contact at the server impact time, hitstop and spring rebound into the next clash. Holding / releasing locks a timing bonus without stopping motion. No swing physics.
   - Input: touch and hold anywhere on the play area (mobile); `ContextActionService` for Space / left mouse (PC), ButtonA / ButtonR2 (console). Center the timing bar. Send `ReleaseSwing` with elapsed meter time.
2. **Battle HUD** in `src/client/UI/Screens/BattleHud.luau`, built from `Theme` (create the `Panel`, `Button`, `ProgressBar`, `Pill` components as you need them): HP cards with name, level and type pill; VS badge; clash counter; power meter with zones from `Formula.meterBounds(swing)` and a needle from `Formula.needlePosition`; screen-wide hold feedback. Match the Figma Battle screen.
3. **Cracks** at 75 / 50 / 25 % HP (overlay decals or a crack-shell mesh; pick what reads on mobile).
4. `src/client/Controllers/ShatterController.luau`, per GAME_DESIGN 8:
   - every impact: hitstop 60–100 ms, clink (pitch from `ClinkPitch`), camera shake by damage, damage number + PERFECT!/CRIT! pop-ups, haptics;
   - final blow: slow-mo 0.3× for ~1 s with a **cut to a side-on shot**, white flash, swap Body for Shards with outward velocity and spin (client-only, `Debris` after 3 s, cap ~150 shards), sparkles, layered shatter sound, "SHATTERED!" banner.
5. Placeholder sounds: pick licensed sounds from the Creator Store (check they're allowed) and list their IDs in `docs/audio/SOUND_LIST.md`.

## Done when

- [x] Walk up to the stand, press the prompt, and play a full battle against the NPC, start to finish, with no errors in Output.
- [x] Timing the release changes the result (PERFECT hits visibly harder).
- [x] Cracks show at the right HP; the final shatter looks and sounds great.
- [x] Works in the Device Emulator on phone presets (hold anywhere; centered bar and readable text).
- [x] `lune run tools/run_tests` and `require(game.ServerStorage.Tests.RunAll)()` both pass.
- [ ] ROADMAP ticked, DEVLOG entry written, committed and pushed, place published.

Then **stop** and tell the user what to test on their phone.

Verification: Galaxy A06 landscape and iPhone 17 Pro landscape/portrait; real emulated Touch input completed a five-clash Pop victory. Fixed-RNG damage: Weak 24, Perfect 44. Both suites report 28 passed, 0 failed; 14 remote-validation checks pass. Audio Sound instances load all four approved clips. Final publication requires Studio File > Publish to Roblox because the MCP Edit context cannot call SavePlaceAsync.
