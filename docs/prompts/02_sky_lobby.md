# L1 prompt for Codex: sky lobby (floating islands)

Two parts with a stop in between. **Part A** needs Blender open with the Blender MCP. **Part B** needs Studio open with the Studio MCP and Rojo connected. Suggested setting: your strongest model, **high** effort for Part A (modelling), medium for Part B.

What you (the user) do in between is in the box after Part A.

---

## Part A: model the floating islands in Blender

Paste everything from here to "STOP" into Codex.

---

We're building the lobby for Glass Clash. I picked the **Crystal Isles** concept: a chain of floating grassy islands above the clouds, joined by short bridges, with arena stands on them. This task is **only the island platforms** (grass top, dirt band, rock underside). Nothing else: no crystals, fences, trees, bridges, signs or props. I'll add those later, and you'll place everything in Studio in Part B.

**Read first:** `git pull`, then `AGENTS.md`, `docs/art/MAP_PLAN.md`, `docs/art/concepts/crystal_isles/CONCEPT.md` (layout table and palette) and look at `docs/art/concepts/crystal_isles/aerial.jpg`, `spawn.jpg`, `arena.jpg`. The concept was rendered by `tools/map/concepts/crystal_isles/build.py`; its `island()` function (superellipse top, jittered rim, rock cone underneath) is a good starting point. Reuse its shape ideas but build clean, export-ready meshes. Load the helper: `exec(open("<repo>/tools/blender/glassclash_blender.py").read())`.

**Islands to make (studs, 1 Blender unit = 1 stud):**

| Island | Top size (X × Y) | Notes |
|---|---|---|
| `Isle_Lobby` | 96 × 56 | Spawn, Kiln, shop, leaderboards later |
| `Isle_Arena1`, `Isle_Arena2`, `Isle_Arena3` | 92 × 46 each | Two arena stands each. Make 3 visibly different variants (rim shape and rock underside), not copies |
| `Isle_Featured` | 72 × 48 | Rounder (superellipse exponent ~3), the "final" island |

**Each island = 3 separate meshes** (so I can colour them in Studio, DECISIONS 14):
1. `<Isle>_Grass`: the walkable top. **Perfectly flat top at Z = 0** across the whole usable area (stands and players stand on it), rounded-rectangle outline (superellipse, exponent ~4) with a gently irregular rim, about 1.4 thick, with a slight lip/overhang (~0.5) over the dirt.
2. `<Isle>_Dirt`: a 2–3 stud band under the grass, following the rim, slightly inset.
3. `<Isle>_Rock`: the floating rock underside: chunky, faceted low-poly layers that narrow downward into an uneven point, roughly 25–35 deep, with a few stepped ledges and 2–4 smaller hanging rock chunks. Flat-shaded. Can be split into `_Rock` and `_RockDark` if two tones read better.

**Style:** low-poly, flat-shaded, chunky, toy-like (ART_BIBLE). Palette preview colours from CONCEPT.md (grass `#7CCB5B`, side `#5DA845`, dirt `#9A6B43`, rock `#9787A0` / `#6E6180`); final colours are set in Studio. Matte only.

**Technical:**
- Origin of all 3 meshes of an island = **centre of the grass top surface** (X/Y centre, Z = 0), so islands drop into Studio at the right height.
- Apply all transforms. Clean normals, no n-gons with holes, no internal faces. **≤ 5,000 triangles per mesh** (well under Roblox's limit).
- Export **one FBX per island** to `assets/blender/map/sky/<Isle>.fbx` with the helper's `export_fbx` settings (the same ones that imported the glassies at the right scale). Save the source to `assets/blender/map/sky/sky_islands.blend`.
- Write `assets/blender/map/sky/manifest.json`: per island, each mesh's name, triangle count, local bounds in studs, and the island's intended world position from the layout table in Part B.
- Render a quick preview of all 5 islands laid out in the row (`assets/blender/map/sky/preview.jpg`) and look at it critically: the grass tops must read as flat walkable platforms, the undersides as chunky floating rock, all 5 as one family but not identical. Fix and re-render until it looks good.
- Write `assets/blender/map/sky/README.md` with my import steps (below), commit and push.

**Then STOP** and tell me the files are ready to import. Don't touch Studio yet.

STOP

---

> **You, between Part A and Part B**
> 1. **Back up the current place first:** File > Publish to Roblox (version history keeps it), and/or File > Save to File As… `places/pre_sky_backup.rbxl`.
> 2. File > Import, select the 5 FBX files in `assets/blender/map/sky/`. Settings like the glassies: Upload to Roblox, Add to Workspace, Import Only As Model, **Scale Unit: Studs**, Merge Meshes **off**, Use Imported Pivot, Anchored **on**.
> 3. Leave the 5 models in Workspace where they land and tell Codex "islands imported, backup done".

---

## Part B: clean the place and lay out the lobby in Studio

Paste everything below into Codex after the import.

---

The 5 sky islands from `assets/blender/map/sky/` are imported into Workspace and I've backed up the place. Now: **clear the old place, then lay out the sky lobby.** Read `assets/blender/map/sky/manifest.json`, `docs/art/concepts/crystal_isles/CONCEPT.md` (layout, lighting) and `docs/DECISIONS.md` 22–30 first.

### 1. Clean out the old place (keep only essentials)

The game was restructured (no more Glass Town, Recycling Yard, trainers or meter battle). First **list everything** in Workspace, ReplicatedStorage, ServerStorage, StarterGui, StarterPlayer, Lighting and SoundService, and sort it into keep / move / delete. Put the list in your report. Then:

**Keep (don't touch):**
- Rojo-synced code: `ReplicatedStorage.Shared`, `ServerScriptService.Server`, `StarterPlayer.StarterPlayerScripts.Client`, `ServerStorage.Tests` (Rojo owns these).
- `ReplicatedStorage.Assets`: glassies (pop, jam, prism with Body / Details / Shards), the **ClashStand** template, audio templates, and anything else art I imported (e.g. the icon pack).
- The 5 new islands. `Camera`, `Terrain` (but clear any old terrain with `Terrain:Clear()`).

**Move, don't delete:** reusable props from the old map that I might use again (**trees**, rocks, fences, lamps, benches, crates). Put one clean copy of each kind in `ServerStorage.LegacyKit` (tidy names, anchored, no scripts).

**Delete:** the old map (`Workspace.Map`, Glass Town, Recycling Yard, proxies, collision boxes, markers, the old practice stand), `ServerStorage.MapImportedSources`, `ServerStorage.MapBlockoutVisuals`, any old blockout leftovers, the hidden Baseplate, leftover HUD/ScreenGuis or prompts created by the removed M1 scripts, and old Lighting effects you'll replace in step 4. Never delete a script that Rojo manages; if something unknown looks important, move it to `ServerStorage.Unsorted` and tell me instead of deleting.

### 2. Place the islands

Use the layout from CONCEPT.md (concept Y = Roblox −Z, i.e. the row runs away from spawn along −Z; concept Z = Roblox Y). Positions are island top-centre:

| Island | Position (X, Y, Z) |
|---|---|
| Isle_Lobby | (0, 0, 0) |
| Isle_Arena1 | (0, 2, −56) |
| Isle_Arena2 | (0, 4, −107) |
| Isle_Arena3 | (0, 6, −158) |
| Isle_Featured | (0, 9, −210) |

Adjust spacing if the real meshes need it: keep **~5-stud gaps** between islands, everything within ~14 s walk from spawn to the featured pads. Put them in `Workspace.Lobby.Islands`. Set colours/materials per the palette (Grass material or SmoothPlastic for grass, Slate/SmoothPlastic for rock; matte). Meshes: `CanCollide` off, `CastShadow` on for grass, off for rock undersides.

**Collision:** add simple invisible anchored Parts matching each flat grass top (a few blocks per island to follow the rounded rim) in `Workspace.Lobby.Collision`. Players should never fall through or snag.

**Bridges (placeholders):** simple plank bridges from Parts across each gap, 8 wide, gentle ramp for the height steps, with low side rails. Tag them `PlaceholderBridge` so I can swap in nicer ones later.

### 3. Place the arenas

- 3 arena islands × 2 stands = arenas 1–6, plus the featured stand = 7 stands. Use the `ReplicatedStorage.Assets.ClashStand` template.
- Arena stands at X = ±24 on each arena island, **rotated 90°** so the glassies swing along the row and people on the middle walkway see the swing side-on (CONCEPT.md). A ~19-stud viewing walkway stays clear down the middle.
- Featured: one stand centred on the featured island on a low gold-trim stage (0.6 high). **Keep it the same size as the others** (don't scale it ×1.15; the fight code needs identical hook spacing everywhere).
- **Hooks (DECISIONS 30):** glassies will show 1.75× bigger in arenas, so the hooks must be `Balance.Motion.HookGap` (6) apart. On the template, make sure there are two Attachments `HookA` and `HookB` on the crossbar at ±3 from the centre (move the hook meshes there too). All stand copies inherit it.
- **Queue pads:** for each stand, two pads (cylinder, radius ~3.3, Neon disc on top: A blue `#4FB8FF` facing the lobby side, B orange `#FF9F43`) 18.5 studs from the stand centre along its swing axis. Keep a clear 4-stud lane next to each bridge head.
- **Tags and attributes for game code later** (CollectionService):
  - each stand: tag `ArenaStand`, attributes `ArenaId` (1–7), `Featured` (bool)
  - each pad: tag `QueuePad`, attributes `ArenaId`, `Side` ("A"/"B")
  - Model names `Arena1` … `Arena7` under `Workspace.Lobby.Arenas`
- **Lobby spots** (invisible, anchored, non-colliding 4×4 marker parts, tag `LobbySpot`, attribute `Spot`): `Spawn` (0, ~, 12 toward the back of the lobby island, facing the arenas), `Kiln` (left, where the concept's crate crystal is), `Shop` (right), `Daily`, `Codes`, `Index`, `LeaderboardWins`, `LeaderboardStreak`, `Champion`. Plus a real `SpawnLocation` at the Spawn spot, facing −Z (toward the arenas).

### 4. Lighting and sky

Apply CONCEPT.md "Roblox lighting" (golden afternoon above the clouds): ClockTime ~16.4 with the sun **behind spawn**, Atmosphere, a soft gradient Sky, Bloom low, ColorCorrection, SunRays subtle. Turn off built-in Clouds. `Workspace.FallenPartsDestroyHeight = -150`.

### 5. Falling off

Kids will jump off. Add a small server module `src/server/Services/FallService.luau` (Rojo, not Studio-only): when a character falls below Y = −40, teleport them back on top of the island they fell from (nearest island centre, or spawn), with no death. Keep it tiny, clean up connections on character removal, no remotes.

### 6. Check and report

- Walk the whole row with a character: spawn → every pad → featured pads, back again. No falling through, no snagging on bridges, gaps or rims. Measure spawn → featured pad walking time (target ≤ 14 s).
- Device Emulator on a phone preset: frame rate fine, nothing blocking the view down the row from spawn.
- Instance count for `Workspace.Lobby` and total triangles.
- Run `lune run tools/run_tests` and `require(game.ServerStorage.Tests.RunAll)()`.
- Screenshots: spawn view, aerial, one arena island. Tell me what you changed from the layout and why.
- Update `docs/ROADMAP.md` (L1), add a DEVLOG entry, note any new decisions as Proposed, commit and push. Remind me to **File > Publish to Roblox** (the MCP can't publish).

Don't build crystals, fences, trees, signs, shops or game systems in this task. I'll do fences and decor, and we'll start the game systems after I've checked the layout.
