# Rejected meshes: re-upload (Oct 22)

Three meshes owned by group 11116787 came back from Roblox moderation as `Rejected`. Rejected meshes render invisible in game and print "Asset is not approved for the requester". The creator chose to re-upload them ("I would reupload the meshes that need to be reuploaded"). Each one was rebuilt with small shape changes and uploaded **once**. All three new meshes are **Approved**, and every MeshPart that used an old mesh now uses the new one.

**Creator: save/publish the place.** The new MeshIds live in the place, not in `src/`.

## Old → new ids

| What | Old mesh (Rejected) | New mesh (Approved) | New Model asset (Open Cloud upload) | MeshParts updated |
|---|---|---|---|---|
| Glass Phoenix body | 89543800857593 | **136258092046043** | 102305428953672 | `ReplicatedStorage.Assets.Glassies.glass_phoenix.Body`, `ServerStorage.GlassyV4Import.glass_phoenix.Body` |
| Gumball finisher crank | 107144503993935 | **74273603014636** | 95292147980589 | `ReplicatedStorage.Assets.VFX.FinishersV4.FV4_GumballCrank`, `ReplicatedStorage.Assets.RoundFinishers.gumball.Finisher_gumball.GumballMachine.GumballCrank`, `ServerStorage.FinishersV4Import.GlassClash Finishers v4.FV4_GumballCrank` |
| Carousel pony core | 73989584659034 | **104157165128911** | 103439823201618 | `ReplicatedStorage.Assets.Rideables.carousel.PonyCore`, `ServerStorage.FlyersV3Import.carousel.PonyCore` |

Moderation was read from Open Cloud (`GET assets/v1/assets/{id}?readMask=moderationResult`) at upload time and again at 04:05 CDT: all six new assets were `Approved`, and the three old meshes were still `Rejected`.

A full scan of the place after the swap found no MeshPart, SpecialMesh or string attribute still pointing at an old id.

## Research: why harmless meshes get rejected, and how to re-upload

What Roblox says:
- **Every uploaded mesh is auto-reviewed.** "Content such as images, meshes, audio files, and video files that creators upload … automatically goes through a multi-step review process" ([Content Moderation on Roblox](https://en.help.roblox.com/hc/en-us/articles/21416271342868)).
  - Roblox doesn't say how meshes are judged.
  - Its newer system "evaluates an entire scene — including avatars, text, and 3D objects" ([Safety Snapshot, Mar 2026](https://about.roblox.com/newsroom/2026/03/safety-snapshot-march)).
- **The same or a similar file gets blocked again.** "Roblox also has systems in place to prevent the re-upload of content previously removed. This includes technology that reviews for content that is the same or similar" (same page). So re-sending the identical file would most likely be rejected again.
- **Repeat violations escalate.** Roblox considers "a user's historical behavior … repeated violations … may increase the severity of consequences" (same page). That is why each mesh got exactly one new attempt, with a real change, and there will be no third try.
- **Appeals.** An appeal goes through Violations & Appeals, or the Support form if the violation isn't listed there ([Appeal Your Content or Account Moderation](https://en.help.roblox.com/hc/en-us/articles/360000245263)).
  - It must be filed within 30 days.
  - Each moderation is reviewed only once.
  - A content appeal needs the username, a reason, the asset id and a link.
- **Models and meshes are moderated separately.** An Open Cloud FBX upload becomes a Model containing MeshParts ([Open Cloud assets usage](https://create.roblox.com/docs/cloud/guides/usage-assets)).
  - The Model and its meshes have separate moderation states.
  - The finishers v4 Model (120805864098504) is `Approved`, yet its crank mesh was `Rejected`.
  - So mesh ids, not Model ids, are what must be checked.

Community reports (anecdotal, not policy):
- **False positives are common.** Automated pre-screening of uploads gives false positives; creators report harmless textures rejected repeatedly ([Home Alone Anomalies thread](https://devforum.roblox.com/t/home-alone-anomalies-character-texture-moderation-issues/4830388)) and inconsistent appeal results ([Moderation issue with my public assets](https://devforum.roblox.com/t/moderation-issue-with-my-public-assets/4065299)).
- **Re-uploading doesn't fix players who already loaded the broken mesh.** For them it can take a client cache clear ([invisible MeshParts thread](https://devforum.roblox.com/t/meshparts-render-invisible-for-a-subset-of-players-collision-intact-persists-across-rejoins-until-the-client-asset-cache-is-cleared/4730088)). New ids avoid this, because nobody has the new ones cached.

What the meshes looked like on their own (`captures/*_before.png`):
- Each one, taken out of its model, is a **"shaft plus rounded bulb" silhouette**:
  - **PonyCore:** a sausage with a ball on the end.
  - **Crank:** a rod ending in an egg-shaped knob, joined to a ball.
  - **Phoenix body:** a bulbous body and a ball head, with a slit down the middle.
- In the game they read as a pony's glowing core, a crank and a bird, but a reviewer that sees each mesh alone sees only these blobs.
- Roblox doesn't publish its mesh rules, so this is an inference, not a confirmed cause. The fix targets it anyway: keep the look in context, remove the suggestive read in isolation.

How to keep this from looking like evasion:
- Only the three rejected meshes were re-uploaded, each once, from the same group, under plain, accurate names and descriptions ("Glass Phoenix body", "Gumball machine crank", "Carousel pony crystal core").
- Each re-upload is a genuinely edited mesh (below), not the same file with a trivial hash change. The content never violated anything; the edits fix what a shape filter could misread.

**Appeal advice:**
1. The game no longer needs the old meshes.
2. Still, check **Violations & Appeals** (roblox.com/report-appeals) on the account that owns group 11116787.
3. If any of the three rejections are listed there, appeal them within 30 days of the rejection. Use the asset ids above and a reason like "harmless game part (a pony's inner core / a gumball machine crank / a glass bird's body) in a kids' game, not sexual content". The point is to clear them from the account's history.
4. If they aren't listed, there's nothing to appeal.

## What changed in the geometry

Script: `tools/blender/mesh_reupload_tweaks.py` (headless Blender 5.2.2; it loads `tools/blender/glassclash_blender.py` and uses its `export_fbx`).
- Sources: the original `.blend` files.
- Outputs:
  - `assets/blender/mesh_reupload/*.fbx`: each mesh exported alone, at 1 unit = 1 stud, transforms applied, -Z forward / Y up.
  - `*.blend`: the edited object.

Every mesh keeps its exact bounding box (refit to the old min/max), its object name and its material slot. Re-imported in Blender, the new FBX files match the old ones:
- the same node rotation (90° X) and 0.01 scale
- the same bounds
- in Studio, the same `MeshSize`: 125.82 × 107.47 × 162.09, 54 × 32 × 25, and 108.18 × 127.98 × 273.63

So each MeshPart kept its `Size` and `CFrame` with no stretching.

| Mesh | Change | Triangles |
|---|---|---|
| Phoenix body | The body was two mirrored halves that had never been welded, which left a slit down the middle. Voxel remesh (0.012) fuses them into one closed shell. A light smooth (0.5 × 4) eases the neck pinch. Decimated back to the old count, smooth shaded. Same silhouette, so the 20 shards and the crack paths still match. | 1000 → 1000 |
| Gumball crank | The flattened ball became a chamfered 12-sided wheel. The square arm is unchanged. The egg-shaped knob became a capped 10-sided cylinder grip. Flat shaded, so it reads as a toy part. | 132 → 260 |
| Pony core | Replaced by the convex hull of the old core, which keeps every outer point and drops the pinched neck. Decimated to crystal facets, flat shaded. Checked inside the glass pony: 0 of 40 vertices poke out. Through the glass it reads as a faceted pink crystal heart. | 300 → 93 |

Before/after sheets (front, side, top, 3/4, back, under): `captures/phoenix_before.png` / `phoenix_after.png`, `crank_*`, `ponycore_*`.

The original `.blend` files (`glassies/glass_phoenix/v4/`, `round_cosmetics/finishers_v4/`, `round_cosmetics/flyers_v3/carousel/`) still hold the old shapes. Re-exporting from them would bring the old meshes back. Use `assets/blender/mesh_reupload/` for these three parts.

## Studio

- **Apply, in Edit:** the lock was held as `mesh-reupload`.
  - Each new Model was inserted with `InsertService:LoadAsset`.
  - `MeshPart:ApplyMesh` was run on all 7 MeshParts, inside one ChangeHistory recording.
  - These properties were saved before and compared after: Size, CFrame, PivotOffset, Material, MaterialVariant, Color, Transparency, Reflectance, CastShadow, CanCollide, CanQuery, CanTouch, Anchored, Massless, CollisionGroup, RenderFidelity, CollisionFidelity, TextureID, Name, attributes and children. Nothing changed.
  - None of these parts has a SurfaceAppearance or children.
  - The temporary `ServerStorage.MeshReuploadImport` folder was removed.
- **Play, one client:**
  - Phoenix body in a fight: shows (`FightDev` BotVsBot glass_phoenix vs pop), `captures/play_phoenix_fight.jpg`.
  - Gumball finisher crank in its show: shows (the real `FinisherFX` show frozen at 0.9 s), `captures/play_gumball_show.jpg`.
  - Carousel pony while ridden in a match: shows, with the core visible through the glass, `captures/play_carousel_ridden.jpg`.
  - Carousel on the lobby Flyers display: shows, `captures/play_carousel_lobby_display.jpg`.
  - Output: no "Asset is not approved" lines. The only asset error was the old `rbxassetid://203785492` "asset type does not match", which isn't one of these three.

## Item pictures (decision 113)

Not re-rendered. None of the three pictures visibly changes:
- In `finishers_gumball.png` the crank is hidden behind the machine.
- In `rideables_carousel.png` the core doesn't show through the white pony.
- In `glassies_glass_phoenix.png` the body silhouette is unchanged and the slit was never visible.

`assets/icons/items/source/mesh_map.json` now maps the three new mesh ids to the new FBX files, so the next icon run finds them.

## Follow-ups

- **Creator: save/publish the place.**
- **Re-check in about a day.** The old meshes were probably flagged after first passing, since the finishers Model showed `Approved` when it was uploaded on Oct 19. To check, open 136258092046043, 74273603014636 and 104157165128911 on the Creator Dashboard (group 11116787 > Development Items > Meshes), or read them with the Open Cloud GET above. If one turns `Rejected`, don't upload it a third time; appeal instead.
- If any of the three rejections appear in Violations & Appeals, appeal them (see above).
