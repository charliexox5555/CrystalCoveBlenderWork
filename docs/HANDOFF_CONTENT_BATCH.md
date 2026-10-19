# Glass Clash: content batch handoff (new glassies, flyers, finishers)

Written Oct 19, 2026, at the end of the release-overhaul session. Use it to start the **next modelling batch** (new glassies, flyers and finishers) in a fresh chat. Other game features are being built in a different chat at the same time, so check `git log` and the newest DEVLOG entries for anything that changed after this was written.

## Where the game is

- **Launch content is complete and installed in Studio** (place "Testing glass game", 129420351303019; the creator saves and publishes).
  - **Glassies:** 36 in the release roster (24 revamped to v4 + 12 Roster V2 launch glassies) plus seasonal Hollowlight.
  - **Finishers:** 12 standard (5 reworked + 7 new) plus Lantern Eclipse.
  - **Flyers:** 11 standard (4 rebuilt + 7 new) plus the Moonlantern Carriage.
  - **Riding:** 60 Animation assets (6 families × 5 clips × R15/R6).
- **Balance:** every glassy is at or inside 45–55% vs the field at equal stats, measured on the real swing (`docs/testing/BALANCE_RELEASE.md`).
- **Tests:** `~/.rokit/bin/lune run tools/run_tests` passes (164 at handoff). It also passes in a Studio Play server.

## Read first (in this order)

1. `AGENTS.md`: rules, workflow, content and safety.
2. `docs/DECISIONS.md` entries 85–95: optional CAST, rarity edge ≈ 55%, launch roster, overnight delegation, no fallbacks, 24 + 24 cosmetics, no starter cosmetics.
3. `docs/design/RELEASE_OVERHAUL_PLAN.md`: workstreams and contracts.
4. **What to build next:**
   - `docs/design/ROSTER_V2.md`: the 14 drop glassies, weeks W1–W4, with kits, model notes and VFX briefs.
   - `docs/design/COSMETICS_V2.md`: the remaining 12 flyers and 11 finishers, with families, finisher module kit and build orders.
5. **How it was built:**
   - `docs/art/ART_BIBLE.md`.
   - `docs/art/GLASSY_REVAMP.md` and `docs/art/launch_glassies/README.md` (v4 glassy bar).
   - `docs/art/FLYERS_V3.md`, especially "Adding a flyer": families, GripL/GripR, RiderMount.
   - `docs/vfx/FINISHERS_V2.md` (module kit).
   - `docs/vfx/POWER_VFX_V2.md` (power VFX tiers and the Ready/cast look).
   - `docs/vfx/HOLLOWLIGHT_PREMIUM.md`.
6. **How it gets in:** `docs/art/IMPORT_RUNBOOK.md` (upload → install → verify).
7. **Balance:** `docs/testing/BALANCE_RELEASE.md` and `tools/release_matrix.sh`.

## Pipeline per new item

**Glassy**
1. Design: kit on the cast contract, from ROSTER_V2.
2. Model with `docs/art/glassy_revamp/tools/build_glassy_v4.py`:
   - Run it headless: `/Applications/Blender.app/Contents/MacOS/Blender -b --python ...`.
   - It writes body, Details with `Pivot_` empties, 16–20 shards and the icon to `assets/blender/glassies/<id>/v4`.
   - Add the item's motion manifest entry, then run `make_import_files.py` for the upload list, release geometry and crack paths.
3. Upload: `zsh -i -c 'python3 tools/opencloud/upload_assets.py <list.json>'`.
4. Install: `tools/blender/glassy_install_chunk.py` → Studio MCP. Dry run, install, verify (sets `MotionVersion` and `Pivot_<Detail>`).
5. Code:
   - Glassy definition in `Config/Glassies`.
   - Kit in `Balance.CombatRelease.Kits`.
   - `ReleaseGeometry`, `ReleaseCrackPaths`, `CombatKitVisuals`.
   - Add the id to `ReleaseRoster`; that puts it in the Kiln.
   - Update the roster-count tests.
6. Balance: tune into 45–55% with `tools/release_matrix.sh 4 equal:bot0.5 "<all ids>" <out> "<new ids>"`.
7. VFX: per-power effects on the PowerFX kit (E's modules), plus sounds.

**Flyer**
1. Model with `tools/blender/build_flyers_launch.py` conventions. Note that `RiderMount` lives in the manifest.
2. Upload, then install with `tools/blender/install_flyers_v3.luau`.
3. Map it to an existing riding family (Stand, Surf, Sit, Kneel, HandleStand, HandleSit). Never author new clips per flyer: handle flyers only need GripL/GripR placed.
4. Add its effects, sound loop and `Config/RoundCosmetics` entry: Rarity, no `Matches` field. It joins crate pools only once installed.

**Finisher**
1. Build it on the reusable module kit (`Presentation/Finishers/*`, FinisherFX) with one or two hero meshes (`tools/blender/build_finishers_v4.py`).
2. Install with `tools/blender/install_finishers_v4.luau`.
3. Add its `Config/FinisherAudio` cue set and its `RoundCosmetics` entry.

**Quality rule (decision 88):** an item ships only at full quality (model, motion, effects, sound, previews). Otherwise it waits.

## Working rules that matter

- **One shared Roblox Studio.** Take `tools/studio_lock.sh acquire <name>` before any Play or Edit work, and `release` after. Keep slots under ~15–20 min. Run tests in a **Play server** (Edit-mode require caching can be stale).
- **Rojo syncs `src/` live** into the shared Studio, so half-finished code shows up for everyone. Keep edits compiling, and don't edit Rojo-managed scripts inside Studio.
- **Blender:** the Blender MCP window is for one session at a time. Parallel modelling runs headless from the CLI.
- **Open Cloud key** (`ROBLOX_ASSETS_KEY`, group 11116787):
  - It loads only via `zsh -i -c`; never print it.
  - `upload_assets.py --check` should say `assets: OK`.
  - The creator's wifi can be slow, and the uploader retries.
- **Tools:**
  - `lune`, `rojo` and `stylua` live in `~/.rokit/bin`, which isn't on PATH.
  - Running `stylua` over a whole folder can reformat other people's files, so format only your own paths.
- **Shared config files** (`Balance`, `RoundCosmetics`, `FinisherAudio`, `RemoteGuard` tests): re-read before each edit, change only your own entries, and commit by exact path. Never use `git add -A`, stash or reset.
- **When Studio stops rendering** (RenderStepped at 0 fps), the display is probably asleep. Running `caffeinate -d -u -t 14400` in the background fixes it.
- **Prices and paid odds are the creator's decisions.** Still open: Robux products for Epic Standard, Legendary and Mythic flyers and Mythic finishers. Until those exist, those items are crate-only, and Mythic cosmetics come from Marble crates only.

## Still open at handoff (creator)

- Save and publish the place (the last flyer installs happened after the most recent save).
- Phone checks and a listening pass on the new sounds. Device presets can't be switched through the MCP.
