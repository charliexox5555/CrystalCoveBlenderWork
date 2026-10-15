"""Actual recombined/exploded shard inspection, in isolated imported source copies."""
def render_release_shards(gid):
    folder=repo_path('assets','blender','glassies',gid,VERSION)
    previous=bpy.context.window.scene
    with bpy.data.libraries.load(os.path.join(folder,gid+'.blend'),link=False) as (a,l):l.scenes=a.scenes
    scene=l.scenes[0];bpy.context.window.scene=scene
    try:
        with bpy.context.temp_override(scene=scene,view_layer=scene.view_layers[0]):
            shards=[o for o in scene.objects if o.get('asset_role')=='Shard']
            body=next(o for o in scene.objects if o.get('asset_role')=='Body')
            assert len(shards)==16
            for o in scene.objects:
                if o.type=='MESH':o.hide_render=o not in shards
            colors=['#8EC7DD','#A4D9E7','#81B6D7','#B3E2E2']
            for i,s in enumerate(shards):
                s.hide_set(False);assign_material([s],preview_solid_material('ShardQA_'+str(i%4),colors[i%4],roughness=.35))
            scene.cycles.samples=16;scene.render.resolution_x=scene.render.resolution_y=384
            scene.render.threads_mode='FIXED';scene.render.threads=4
            out=repo_path('docs','art','combat_release',gid+'_shards_recombined.png')
            scene.render.filepath=out;bpy.ops.render.render(write_still=True)
            lo,hi=_world_bounds([body]);centre=(lo+hi)/2
            for s in shards:
                a,b=_world_bounds([s]);direction=(a+b)/2-centre
                s.location+=direction*.22
            scene.camera.data.ortho_scale*=1.3
            exploded=repo_path('docs','art','combat_release',gid+'_shards_exploded.png')
            scene.render.filepath=exploded;bpy.ops.render.render(write_still=True)
            return {'id':gid,'recombined':out,'exploded':exploded,'source_changed':False}
    finally:bpy.context.window.scene=previous
