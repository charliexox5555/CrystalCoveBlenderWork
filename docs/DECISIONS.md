# Decisions

Newest at the bottom. Agents: don't reverse an **Accepted** decision without asking the user. Add new ones as **Proposed** until the user agrees.

| # | Date | Decision | Status |
|---|---|---|---|
| 1 | 2026-10-12 | Build the **glass battles** game, not the Halloween horror game. Horror is crowded (Survive the Killer, Forsaken) and has copyright problems; glass battles is unclaimed on Roblox and suits the AI pipeline. | Accepted |
| 2 | 2026-10-12 | Audience: all ages, **mostly kids**. Mobile first. | Accepted |
| 3 | 2026-10-12 | Structure is **Pokémon-like**: own a glassy, NPC trainers, wild catching, badges, plus lobby tournaments. | **Superseded by 22** |
| 4 | 2026-10-12 | Glassies go from **everyday bottles to fantasy glass** (swords, pumpkins, unicorns, dragons) as you progress. ~~Starters evolve at 15 and 35.~~ (no evolution in v0.3; evolved forms are separate collectibles) | Accepted (evolution dropped, see 22) |
| 5 | 2026-10-12 | **Losing never deletes a glassy.** It breaks and is repaired free at a Repair Bench. | **Superseded by 22** (rounds start fresh; nothing breaks for good) |
| 6 | 2026-10-12 | **No alcohol bottles**, no copyrighted characters. | Accepted |
| 7 | 2026-10-12 | Server-authoritative battles; swing is animated, not physics; shards client-only. | Accepted, refined by 23 |
| 8 | 2026-10-12 | Main cosmetic is **Shatter FX** (plays when your glassy wins). | Accepted |
| 9 | 2026-10-12 | UI style is **crisp glass** (dark frosted panels, thin edges, Montserrat), not cartoony. Figma mockups are the reference. | Accepted |
| 10 | 2026-10-12 | Battles are **3D** with a three-quarter camera; the final blow cuts to a side-on slow-mo shot. | Proposed (side-on final shot) |
| 11 | 2026-10-12 | World is **low-poly**, built mostly in **Blender** as a modular kit. Glassies stay glossy and smooth so they pop against it. | Accepted |
| 12 | 2026-10-12 | Code lives in this repo and syncs to Studio with **Rojo**; the world is built in Studio through the Roblox Studio MCP. | Accepted |
| 13 | 2026-10-12 | Working names: game **Glass Clash**, collectibles **glassies**. Both can change. | Proposed |
| 14 | 2026-10-12 | In-game colouring is primarily done in **Studio**. Blender uses untextured preview materials; textures are used only when useful. Separate cap/lid meshes allow independent Studio colours. | Accepted (user directed) |
| 15 | 2026-10-12 | Preserve `Body` + `Shards` and add an optional `Details` folder for separate caps, lids and bubbles, exported as `<id>_details.fbx`. All parts share the glassy's hang-point origin and animate together. | Proposed |
| 16 | 2026-10-12 | On current Studio builds, use `LightingStyle = Realistic` and `PrioritizeLightingQuality = true` for ART_BIBLE's Future lighting intent; `Technology` is legacy and unavailable to the Studio MCP. | Proposed |
| 17 | 2026-10-12 | Continuous curved, anchored pendulum motion on a fixed server cadence; release locks a timing bonus while motion continues. Mobile holds anywhere on the play area, with early holds buffered across rebounds; timing meter centered. User-directed revision; exact arc/recoil tuning remains provisional. | **Superseded by 23** |
| 18 | 2026-10-12 | Generate texture-free crack segments by raycasting the approved Blender meshes, so cracks hug curved surfaces at the three HP thresholds. Keep coloring in Studio. | Proposed |
| 19 | 2026-10-12 | M1 compact HUD skin uses a generated visual reference, native glass panels and viewport portraits from approved meshes. Preserve Montserrat and cyan/violet edges; keep the 3D action clear. Client-only final shards bounce on the floor before cleanup. | Proposed |
| 20 | 2026-10-12 | Bring the map first pass forward at the user's request while M1 phone approval is pending. Build Glass Town and Recycling Yard in Blender; use temporary native-Part proxies from the same manifest for immediate Studio walking checks until local FBX import is available. Keep other M2 gameplay separate and all final colors in Studio. | **Superseded by 22** |
| 21 | 2026-10-12 | Map direction: **glassblower village "Kilnport" on a seaside cliff**, giant glass furnace tower landmark, arena in the village square, golden-afternoon lighting, compact hub with walkable Route 1 (Cullet Yard) and portals (harbor boats) for later zones. Layout data in `tools/map/village_layout.py`; see `docs/art/MAP_BLUEPRINT.md`. Supersedes the first-pass layout. The user will build the map themselves. | **Superseded by 22 and 28** |
| 22 | 2026-10-13 | **Restructure to lobby arena matches** (inspired by Ball VS Ball): simple linear lobby with arena pads, 1v1, **3 hearts** each, every round **roll 3 glassies from your own collection and pick 1**, aim, release, watch. No routes, trainers, catching, levels, evolution or repair. Bots fill empty pads. | Accepted (user directed) |
| 23 | 2026-10-13 | **The fight is an auto-battle**: two glassies on strings swing and bounce off each other (server-simulated pendulum, not Roblox physics) until one shatters. Player input: pick, aim (pull-back angle with a Perfect band), and **one special tap** per round. Passives fire by themselves. | Accepted (user directed) |
| 24 | 2026-10-13 | Split of work: **Claude** does research, design, docs, concepts, pure rules/formulas/economy (`FightRules`, `MatchLogic`, `Formula`, `Config`, simulators). **Codex** builds everything in Studio: swing motion, services, UI, map, and tunes `Balance.Motion` by eye. | Accepted (user directed) |
| 25 | 2026-10-13 | Rerolls: 1 free per match, then **5 / 10 / 20 Marbles**. Research recommends earn-only rerolls (pay-to-win perception); kept because the user asked for paid rerolls, with free Marbles from streaks and the group. Revisit with launch data. | Proposed |
| 26 | 2026-10-13 | **Rarity is mostly flair**: stat multipliers 1.00–1.10 (Mythic beats Common ~80%), stars +2% each. No stronger Robux-only glassies. | Proposed |
| 27 | 2026-10-13 | Names: premium currency **Marbles**, gacha **the Kiln**, hearts are **glass hearts** that pop above the loser's pad (we never throw anything at avatars). | Proposed |
| 28 | 2026-10-13 | Lobby theme: **Toy-Sized Kitchen** (recommended of 4 concepts in `docs/art/MAP_PLAN.md`): arenas on cutting boards along a tea-towel runner on a giant kitchen counter; built mostly in Studio from parts, a small Blender lathe kit for kitchenware. | Proposed (awaiting user pick) |
| 29 | 2026-10-13 | Kiln odds: Common 56.25%, Uncommon 22%, Rare 14%, Epic 6%, Legendary 1.5%, Mythic 0.25%; 300 coins a pull; welcome pull after the first match. Every glassy is less likely than any glassy of a lower rarity. | Proposed |
| 30 | 2026-10-13 | **Glassies show 1.75× bigger in arenas** (`Motion.GlassyScale`), on 7-stud strings from hooks 6 apart, because at true scale they look tiny under the 17-stud stand (found in all 4 map concepts). Move the stand's hooks from ±1.5 to ±3. | Proposed |
