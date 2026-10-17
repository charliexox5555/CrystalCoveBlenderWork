# First production playtest checklist

October 17, 2026. Purpose: testers judge the current game mechanics in a live server.

## Already in place (code)

- **Tester Marbles:** `src/shared/Config/Testing.luau` → `TesterMarbles = { Enabled = true, Amount = 10000, Wave = "playtest-1" }`.
  - Every player who joins while it's enabled gets 10,000 Marbles once per wave; rejoining never stacks.
  - Change `Wave` (e.g. "playtest-2") to give everyone another grant in a later round.
  - Set `Enabled = false` to stop granting. Marbles already granted stay in players' saves.
- **Save data:** live servers save to the real DataStore `GlassClash_v2`. Studio uses a mock store, so Studio tests never touch live saves.
- **Dev tools stay out of live servers:** `FightDev`, `MatchDev`, `StoreDev`, `CosmeticDev`, `DataService` dev hooks and the QA harness scripts only exist when running in Studio.
- **Developer products:**
  - 16 daily-store and bundle products, 6 Marble packs and the Hollowlight-only product are created and configured.
  - Studio test purchases have granted correctly; a real purchase is still untested.
- **Animations:** none to publish. Riding poses and other avatar motion are driven by code (`Config/RideAnimations`), not uploaded Animation assets.
- **Audio:** all from Roblox's licensed public libraries (ProSoundEffects SFX, APM music), so no permission grants are needed.
- **3D assets:** the Blender meshes uploaded through Open Cloud belong to group 11116787 and are already installed in the place.

## Creator steps before sending testers

1. **Save** the place in Studio. The map, showcase, crate machines and seasonal art live only in the place file.
2. Make sure the Rojo plugin is connected and synced, so the latest scripts are in the place you publish.
3. **File → Publish to Roblox** (Glass Clash, place 129420351303019).
4. **Access:** choose who can join (Creator Dashboard → the experience → Settings/Permissions): friends, group roles, or a private/test link.
5. **Spot checks in the live game after publishing:**
   - you received 10,000 Marbles on join
   - a full match against a bot
   - one cheap real purchase grants the item (e.g. the smallest Marble pack)
   - open the Shop, Inventory and View Collection
6. After the playtest: set `TesterMarbles.Enabled = false` (or bump `Wave` for the next round), sync and publish.

## Known gaps to tell testers

- Phones held upright: menus are designed for landscape (portrait layouts are parked on the roadmap).
- Gifting is not in yet (post-release).
- The spectator "Stop watching" button has not been tested yet.
