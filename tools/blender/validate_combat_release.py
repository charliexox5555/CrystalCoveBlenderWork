"""Run in Blender after loading the release builder. Actual FBX round-trip checks.

This deliberately does not claim a Roblox import. Original sources are hash-checked.
"""
def validate_release_fbx(gid):
    folder=repo_path('assets','blender','glassies',gid,VERSION)
    path=os.path.join(folder,'manifest.json');report=json.load(open(path))
    previous=bpy.context.window.scene;scene=bpy.data.scenes.new('FBXValidation_'+gid)
    bpy.context.window.scene=scene
    try:
        with bpy.context.temp_override(scene=scene,view_layer=scene.view_layers[0]):
            bpy.ops.import_scene.fbx(filepath=report['files']['bundle'],use_custom_props=True)
            meshes=[o for o in scene.objects if o.type=='MESH']
            assert len(meshes)==len(report['meshes']),(gid,'mesh count',len(meshes),len(report['meshes']))
            errors=[];checks=[]
            for entry in report['meshes']:
                obj=next(o for o in meshes if o.get('source_name')==entry['source_name'])
                lo,hi=_world_bounds([obj]);targetlo,targethi=map(Vector,entry['bounds_blender'])
                delta=max((lo-targetlo).length,(hi-targethi).length)
                assert delta<1e-4,(gid,entry['source_name'],'bounds',delta)
                assert obj.location.length<1e-5,(gid,'origin',list(obj.location))
                check=rclosed(obj)
                if entry['role'] in ('Body','Shard'):assert check['nonmanifold_edges']==0,check
                checks.append({'name':entry['source_name'],'bounds_error':delta,'nonmanifold_edges':check['nonmanifold_edges']})
            for key,p in report['files'].items():assert hashlib.sha256(open(p,'rb').read()).hexdigest()==report['hashes'][key],(gid,key,'hash changed')
            if report['before']:assert hashlib.sha256(open(report['before']['source'],'rb').read()).hexdigest()==report['before']['sha256'],(gid,'original changed')
            # Recombined shard bounds are the intact body bounds in the same coordinates.
            body=next(o for o in meshes if o.get('asset_role')=='Body');shards=[o for o in meshes if o.get('asset_role')=='Shard']
            a,b=_world_bounds([body]);c,d=_world_bounds(shards)
            assert max((a-c).length,(b-d).length)<1e-4
            proof={'passed':True,'application':'Blender '+bpy.app.version_string,'format':'FBX bundle round-trip','mesh_count':len(meshes),'shard_count':len(shards),'checks':checks,'roblox_import':False}
            report['fbx_roundtrip']=proof
            json.dump(report,open(path,'w'),indent=2)
            return {'id':gid,'passed':True,'meshes':len(meshes),'shards':len(shards)}
    finally:
        bpy.context.window.scene=previous
        # Only this validator's temporary imported copies are discarded.
        for o in list(scene.objects):bpy.data.objects.remove(o,do_unlink=True)
        bpy.data.scenes.remove(scene)

def validate_vfx_fbx():
    folder=repo_path('assets','blender','vfx','combat_release');path=os.path.join(folder,'manifest.json');report=json.load(open(path))
    with bpy.data.libraries.load(report['blend'],link=False) as (a,l):l.scenes=a.scenes
    source_scene=l.scenes[0]
    expected={o.get('source_name',o.name):(_world_bounds([o]),rclosed(o)['volume']*abs(o.matrix_world.determinant())) for o in source_scene.objects if o.type=='MESH'}
    previous=bpy.context.window.scene;scene=bpy.data.scenes.new('VFXRoundtrip');bpy.context.window.scene=scene
    try:
        with bpy.context.temp_override(scene=scene,view_layer=scene.view_layers[0]):
            bpy.ops.import_scene.fbx(filepath=report['mesh_bundle'],use_custom_props=True)
            meshes=[o for o in scene.objects if o.type=='MESH'];assert len(meshes)==10
            checks=[]
            for o in meshes:
                assert o.location.length<1e-5
                check=rclosed(o);assert check['nonmanifold_edges']==0 and check['volume']>1e-7,(o.name,check)
                name=o.get('source_name',o.name);(lo,hi),sourcevol=expected[name]
                a,b=_world_bounds([o]);delta=max((a-lo).length,(b-hi).length);assert delta<1e-4,(name,delta)
                worldvol=check.pop('volume')*abs(o.matrix_world.determinant())
                assert abs(worldvol/sourcevol-1)<.001,(name,worldvol,sourcevol)
                checks.append({'name':name,'volume_world':worldvol,'bounds_error':delta,**check})
            report['fbx_roundtrip']={'passed':True,'meshes':10,'roblox_import':False,'geometry_checks':checks}
            json.dump(report,open(path,'w'),indent=2)
            return report['fbx_roundtrip']
    finally:
        bpy.context.window.scene=previous
        for o in list(scene.objects):bpy.data.objects.remove(o,do_unlink=True)
        bpy.data.scenes.remove(scene)
        for o in list(source_scene.objects):bpy.data.objects.remove(o,do_unlink=True)
        bpy.data.scenes.remove(source_scene)
