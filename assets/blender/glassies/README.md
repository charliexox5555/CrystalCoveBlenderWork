# Glassy Blender files

One folder per glassy, named by its config Id (`src/shared/Config/Glassies.luau`):

```
assets/blender/glassies/<id>/
  <id>.blend          source
  <id>_body.fbx       body, origin at the hang point
  <id>_shards.fbx     12-20 pre-broken pieces, same origin
  <id>_details.fbx    optional separate cap/lid/bubble meshes, same origin
```

Rules: ART_BIBLE section 2. Use `tools/blender/glassclash_blender.py` (build, shards, icon, export). Install Git LFS before committing .blend/.fbx.

Set final in-game colours/materials in Studio. Blender materials preview the icons only.
Pop has a red `Cap` and five internal `Bubble_*` meshes; Jam has a gold `Lid`.
Body and its 16 shards contain glass only. Assembly tops are the hang points, including
the separate cap/lid; all mesh origins coincide there. Prism is unchanged and approved.
