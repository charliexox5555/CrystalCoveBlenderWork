# Map Plan

Low-poly, built mostly in Blender (see ART_BIBLE). Walk speed is 16 studs/s, so 160 studs ≈ 10 seconds of walking.

## Lobby: "Glass Town" (M4; blockout earlier is fine)

About **320 × 320 studs**. Players should cross it in ~20 seconds.

```
                 [ Exit to Route 1 ]
                        |
   [Crate Shop]     [ Champion Pedestal ]     [Cosmetic Shop]
                        |
   [Leaderboards]  ( OCTAGON ARENA + bracket board )  [Repair Bench]
                        |
   [Codes / Daily]   [ Spawn plaza ]          [Clash Stands x4 for PvP]
```

- **Octagon Arena** (center): wooden octagon pen like the real-life videos, raised crossbar, spectator ring around it, big bracket board facing spawn. Tournament finals happen here.
- **4 extra Clash Stands** near the arena for quarterfinals and PvP.
- **Champion Pedestal** between spawn and the arena so every new player sees the current champion's glassy spinning.
- Sight lines: from spawn you see the arena, the pedestal and the Route 1 gate.

## Zone 1: Recycling Yard (M2)

A **winding path** about 600 studs long from the lobby gate to Rusty's arena.

```
Lobby gate → Kevin → wild patch A → Sam → Cora → Repair Bench → wild patch B → Jo → Bo → Rusty's arena (badge gate to Zone 2)
```

- Each trainer stands next to their own small Clash Stand, slightly off the path, facing it, with a "!" prompt when unbeaten today.
- **Wild patches:** open areas between stacks of bins and crates where wild glassies float and glow (spawns from `Config/Zones`).
- **Rusty's arena:** a bigger stand on a platform of crushed-glass cubes, with conveyor belts and a tall bottle-bank sign. Gate behind it (locked until Zone 2 ships).
- **Kit pieces:** recycling bins (3 colours), bottle crates, glass-bank domes, conveyor belts, chain-link fence, wooden pallets, puddles, low trees, grass tufts, path tiles, cliffs, sign posts.

## Blender workflow for maps

1. **Blockout** the layout with simple boxes in Blender at the right stud scale. Import into Studio and walk it with a character to check sizes and timing.
2. **Kit:** model the kit pieces in `kit_<zone>.blend` using the palette texture.
3. **Layout:** in `layout_<zone>.blend`, place kit pieces as **linked duplicates**; export in chunks (one chunk per area) to keep each mesh under limits and allow streaming.
4. **Import** chunks into `Workspace.Map.<zone>`, add spawn points, trainer markers, wild-spawn regions (invisible parts tagged with CollectionService) and Clash Stand placements in Studio.
