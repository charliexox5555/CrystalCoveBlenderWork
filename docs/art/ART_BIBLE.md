# Art Bible

**One line:** a **low-poly, flat-shaded world** with **smooth, glossy glass heroes**. The contrast is the point: glassies should be the shiniest, most detailed things on screen.

## 1. The world: low-poly, built in Blender

- **Look:** flat shading, faceted surfaces, chunky readable silhouettes, slightly exaggerated proportions, soft rounded bevels only on big shapes. Think toy diorama, not realism.
- **Built mostly in Blender** as a **modular kit** (ground tiles, paths, cliffs, fences, trees, bins, crates, buildings, props), assembled into layouts, then exported in chunks. Studio is used for placement fixes, lighting, gameplay objects and spawn points.
- **Colour:** one shared **palette texture** (256×256, a grid of flat swatches). UV each face onto a swatch. Every map mesh uses the same texture, so it stays cheap and consistent. Each zone gets its own palette row (see Zones config `Palette`).
- **Matte:** environment materials are matte (`SmoothPlastic` or the palette texture, no reflectance), so glass stands out.
- **Budgets (triangles):** small props 50–500, medium props 500–2,000, buildings 1,000–5,000, terrain chunks up to 8,000. Stay under Roblox's per-mesh triangle limit and split big pieces.
- **Collision:** decorative props `CanCollide = false`. Walkable chunks use `CollisionFidelity = Hull` or simple invisible boxes. Never `PreciseConvexDecomposition` on big meshes.
- **Scale:** **1 Blender unit = 1 stud.** A Roblox avatar is about 5 studs tall; doors about 8 studs; paths at least 10 studs wide for crowds.

## 2. Glassies: smooth, glossy, toy-like

- **Shape:** chunky, rounded, instantly readable from far away and on a phone. Fantasy glassies are cute, not scary.
- **Material in Roblox:** `Glass` material, tinted with the glassy's `Tint`, Transparency about 0.25–0.4, a little Reflectance. Some fantasy glassies get an inner glowing core (a smaller Neon part or a `PointLight`). Test on a low-end phone; fall back to `SmoothPlastic` + Transparency if `Glass` looks flat.
- **Smooth shading** (unlike the world). Up to 1,500 tris (3,000 for Legendary/Mythic).
- **Hang point:** the object's **origin** sits where the string attaches (bottle neck, sword hilt, pumpkin stem, top of a creature's head). The swing rotates around it.
- **Shards:** 12–20 pre-broken pieces (up to 30 for Mythic) with the same origin and scale, inside faces included.
- **Evolutions** keep a family resemblance (colour, a shape cue) so kids recognise the line.

## 3. Icons and renders

- 512×512 PNG, transparent background, **same camera and lighting for every glassy** (three-quarter view, slightly from above, soft key light + rim light). The Blender helper sets this up (`render_icon`).
- Marketing renders reuse the same models with the low-poly arena behind them.

## 4. Lighting in Roblox

- `Lighting.Technology = Future`, soft `Atmosphere`, bright sky. Slight `ColorCorrection` saturation boost. `Bloom` low but present so glass glints pop.
- Battle arenas get a soft spotlight on the Clash Stand.

## 5. Naming and files

| Thing | Blender file | Exports | In Roblox |
|---|---|---|---|
| Glassy | `assets/blender/glassies/<id>/<id>.blend` | `<id>_body.fbx`, `<id>_shards.fbx`, `assets/icons/<id>.png` | `ReplicatedStorage.Assets.Glassies.<id>` with `Body` (MeshPart) and `Shards` (Folder of MeshParts) |
| Map kit | `assets/blender/map/kit_<zone>.blend` | `kit_<zone>_<piece>.fbx` | `ServerStorage.MapKit.<zone>` |
| Map layout | `assets/blender/map/layout_<zone>.blend` | `layout_<zone>_chunk<N>.fbx` | `Workspace.Map.<zone>` |
| Clash Stand | `assets/blender/map/clash_stand.blend` | `clash_stand.fbx` | `ReplicatedStorage.Assets.ClashStand` |

- Object names in Blender match Roblox names (`Body`, `Shard_01`...).
- **Apply all transforms** before exporting. FBX, Y-up/forward settings as the Roblox 3D Importer expects; check the first import and note settings in DEVLOG.
