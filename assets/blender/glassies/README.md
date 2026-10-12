# Glassy Blender files

One folder per glassy, named by its config Id (`src/shared/Config/Glassies.luau`):

```
assets/blender/glassies/<id>/
  <id>.blend          source
  <id>_body.fbx       body, origin at the hang point
  <id>_shards.fbx     12-20 pre-broken pieces, same origin
```

Rules: ART_BIBLE section 2. Use `tools/blender/glassclash_blender.py` (build, shards, icon, export). Install Git LFS before committing .blend/.fbx.
