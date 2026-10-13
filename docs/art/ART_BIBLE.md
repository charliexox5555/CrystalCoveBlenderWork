# Art Bible

**One line:** a **low-poly, flat-shaded world** with **smooth, glossy glass heroes**. The contrast is the point: glassies should be the shiniest, most detailed things on screen.

## 1. The world: low-poly lobby, built mostly in Studio

- **Look:** flat shading, faceted surfaces, chunky readable silhouettes, slightly exaggerated proportions, soft rounded bevels only on big shapes. Think toy diorama, not realism.
- **v0.3 lobby:** one compact, linear lobby (spawn → path lined with arena stands → Champion Arena). **Build most of it in Studio** from Parts, Wedges and simple unions (fast to iterate, easy to recolor). Use **Blender only for hero pieces** that need shapes Parts can't do well (the Kiln, a big landmark, the Clash Stand, a few organic props). See MAP_PLAN for the chosen concept and its piece list.
- **Colour:** primarily set mesh `Color` and `Material` in **Studio**, as directed by the user. Keep differently coloured elements as separate meshes. Blender materials are for icon/preview rendering. Use textures only when they add useful detail; the shared 256×256 palette remains available for textured kit pieces (see Zones config `Palette`). Do not bake plain colours into textures.
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
- **Separate details:** Pop's cap/bubbles and Jam's lid export in `<id>_details.fbx`, with the same hang-point origin as Body. Apply their colours/materials in Studio; the Blender file contains untextured preview materials. Keep the core `Body` + `Shards` contract; optional `Details` is proposed for import.
- **Related glassies** (Pop → Rocket Pop, Jam → Honey Bear, Prism → Prism Blade) keep a family resemblance (colour, a shape cue) so kids see the link, even though they are separate collectibles now.

## 3. Icons and renders

- 512×512 PNG, transparent background, **same camera and lighting for every glassy** (three-quarter view, slightly from above, soft key light + rim light). The Blender helper sets this up (`render_icon`).
- Marketing renders reuse the same models with the low-poly arena behind them.

## 4. Lighting in Roblox

- `Lighting.Technology = Future`, soft `Atmosphere`, bright sky. Slight `ColorCorrection` saturation boost. `Bloom` low but present so glass glints pop.
- Every arena gets a soft spotlight on its Clash Stand so fights read from the path.

## 5. Naming and files

| Thing | Blender file | Exports | In Roblox |
|---|---|---|---|
| Glassy | `assets/blender/glassies/<id>/<id>.blend` | `<id>_body.fbx`, `<id>_shards.fbx`, `assets/icons/<id>.png` | `ReplicatedStorage.Assets.Glassies.<id>` with `Body` (MeshPart) and `Shards` (Folder of MeshParts) |
| Lobby hero pieces | `assets/blender/map/lobby/<piece>.blend` | `<piece>.fbx` | `Workspace.Lobby` (placed in Studio) |
| Clash Stand | `assets/blender/map/clash_stand.blend` | `clash_stand.fbx` | `ReplicatedStorage.Assets.ClashStand` |

- Object names in Blender match Roblox names (`Body`, `Shard_01`...).
- **Apply all transforms** before exporting. FBX, Y-up/forward settings as the Roblox 3D Importer expects; check the first import and note settings in DEVLOG.
