"""Shared original mesh kit and two Blender-rendered 4x4 flipbooks.

Load glassclash_blender.py + build_combat_release.py first. Grayscale textures are
tinted in Studio. Atlas order is top-left -> right -> next row; native proof pending.
"""
import numpy as np

def build_combat_vfx():
    global COLLECTION
    folder=repo_path('assets','blender','vfx','combat_release');texdir=repo_path('assets','vfx','combat_release')
    os.makedirs(folder,exist_ok=True);os.makedirs(texdir,exist_ok=True)
    if os.path.exists(os.path.join(folder,'manifest.json')):return {'status':'existing kit preserved'}
    previous,oldcol=bpy.context.window.scene,COLLECTION
    scene=bpy.data.scenes.new('CombatReleaseVFX');bpy.context.window.scene=scene;COLLECTION=scene.name
    try:
        with bpy.context.temp_override(scene=scene,view_layer=scene.view_layers[0]):
            kit=[rring('Ring',(0,0,0),.8,.055,'#FFFFFF',axis='Y',steps=24),
                 rring('HalfRing',(0,0,0),.8,.055,'#FFFFFF',axis='Y',arc=math.pi,steps=12),
                 rpoly('CurvedSlash',[(-.9,-.30),(-.50,.21),(.10,.48),(.80,.35),(.30,.27),(-.20,.04),(-.60,-.35)],.05,'#FFFFFF',bevel=.01),
                 rpoly('GuardPlate',[(-.48,-.40),(-.60,.15),(-.35,.55),(.35,.55),(.60,.15),(.48,-.40),(0,-.62)],.12,'#FFFFFF',bevel=.04),
                 rpoly('Thorn',[(0,0),(.26,.18),(.16,.76),(-.16,.18)],.16,'#FFFFFF',bevel=.025),
                 rpoly('CrystalChip',[(-.13,0),(.15,-.05),(.25,.34),(.02,.55),(-.20,.30)],.14,'#FFFFFF',bevel=.01),
                 rsphere('Droplet',(0,0,.28),(.19,.19,.28),'#FFFFFF',segments=10,rings=6),
                 rsphere('BubbleDome',(0,0,0),(.50,.20,.50),'#FFFFFF',segments=12,rings=8),
                 rpoly('SplashSheet',[(-.70,0),(-.80,.26),(-.49,.17),(-.35,.70),(-.10,.25),(.23,.89),(.36,.27),(.76,.50),(.63,0)],.035,'#FFFFFF',bevel=.01),
                 rpoly('PuffSheet',[(-.60,0),(-.76,.32),(-.56,.60),(-.17,.69),(.14,.85),(.57,.64),(.79,.28),(.60,0)],.025,'#FFFFFF',bevel=.01)]
            for o in kit:o['source_name']=o.name;o['asset_role']='VFX';o['animation_pivot']=[0.0,0.0,0.0]
            meshfiles={}
            for o in kit:
                meshfiles[o.name]=export_fbx([o],os.path.join(folder,o.name+'.fbx'))
            bundle=export_fbx(kit,os.path.join(folder,'combat_vfx_bundle.fbx'))
            blend=save_blend_copy(os.path.join(folder,'combat_vfx.blend'))
            # Original analytic grayscale masks. Transparent padding, no baked color.
            texturefiles={}
            yy,xx=np.mgrid[0:256,0:256];x=(xx-127.5)/110;y=(yy-127.5)/110;r=np.sqrt(x*x+y*y)
            masks={
              'glass_glint':np.maximum(np.exp(-((x/.055)**2+(y/.65)**2)),np.exp(-((x/.65)**2+(y/.055)**2)))*np.clip(1-r,0,1),
              'directional_streak':np.exp(-((y/.07)**2))*np.clip(1-abs(x),0,1)**.6,
              'soft_puff':np.clip(1-r*r,0,1)**2,
              'shard_fleck':((abs(x)*.6+abs(y)<.55)&(abs(x)<.30)).astype(float)*np.clip((.8-r)*5,0,1),
              'electricity_strip':np.exp(-((y-.11*np.sin(x*16)-.05*np.sin(x*39))/.035)**2)*np.clip((1-abs(x))*6,0,1),
              'droplet_mask':np.clip(1-((x/(.32+.20*(1-y)))**2+(y/.8)**2),0,1)**.35,
            }
            for name,alpha in masks.items():
                pixels=np.ones((256,256,4),dtype=np.float32);pixels[:,:,3]=alpha
                img=bpy.data.images.new(name,256,256,alpha=True);img.pixels.foreach_set(pixels.ravel())
                path=os.path.join(texdir,name+'.png');img.filepath_raw=path;img.file_format='PNG';img.save();texturefiles[name]=path
            report={'provenance':'Original procedural geometry, analytic masks and Blender-rendered flipbooks; no external artwork','mesh_bundle':bundle,'blend':blend,'meshes':[{'name':o['source_name'],'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),'pivot':[0,0,0],'file':meshfiles[o.name]} for o in kit],'textures':texturefiles,'flipbooks':{},'status':{'exported':True,'studio_imported':False,'uploaded':False,'playtested':False},'roblox_ids':{}}
            # Separate camera-facing emissive geometry scene for actual frame renders.
            render_scene=bpy.data.scenes.new('CombatReleaseFlipbooks');bpy.context.window.scene=render_scene;COLLECTION=render_scene.name
            with bpy.context.temp_override(scene=render_scene,view_layer=render_scene.view_layers[0]):
                render_scene.render.engine='CYCLES';render_scene.cycles.samples=4
                render_scene.render.threads_mode='FIXED';render_scene.render.threads=4
                render_scene.render.resolution_x=render_scene.render.resolution_y=128;render_scene.render.resolution_percentage=100
                render_scene.render.film_transparent=True;render_scene.render.image_settings.file_format='PNG';render_scene.render.image_settings.color_mode='RGBA'
                render_scene.view_settings.view_transform='Standard'
                cd=bpy.data.cameras.new('FlipbookCamera');cd.type='ORTHO';cd.ortho_scale=2.6
                camera=bpy.data.objects.new('FlipbookCamera',cd);render_scene.collection.objects.link(camera);camera.location=(0,-5,0);camera.rotation_euler=(math.pi/2,0,0);render_scene.camera=camera
                mat=bpy.data.materials.new('VFXWhiteEmission');mat.use_nodes=True;nodes=mat.node_tree.nodes;nodes.clear()
                em=nodes.new('ShaderNodeEmission');em.inputs['Color'].default_value=(1,1,1,1);em.inputs['Strength'].default_value=1
                out=nodes.new('ShaderNodeOutputMaterial');mat.node_tree.links.new(em.outputs[0],out.inputs[0])
                rng=random.Random(10524)
                for family in ('glass_dust_4x4','pressure_pop_4x4'):
                    framesdir=os.path.join(texdir,'frames',family);os.makedirs(framesdir,exist_ok=True)
                    parts=[];seeds=[]
                    count=22 if family=='glass_dust_4x4' else 12
                    if family=='pressure_pop_4x4':
                        ring=rring('PressureRing',(0,0,0),1,.025,'#FFFFFF',axis='Y',steps=32);assign_material([ring],mat);parts.append(ring);seeds.append(None)
                    for j in range(count):
                        angle=rng.random()*math.tau;speed=rng.uniform(.45,1.0);width=rng.uniform(.018,.045)
                        p=rpoly('BurstFleck',[(-width,-width),(width,-width),(width*.3,width*2),(-width*.4,width)],.005,'#FFFFFF',bevel=0)
                        assign_material([p],mat);parts.append(p);seeds.append((angle,speed,width))
                    atlas=np.zeros((512,512,4),dtype=np.float32)
                    for frame in range(16):
                        t=frame/15
                        for p,seed in zip(parts,seeds):
                            if seed is None:p.scale=(.12+t*.9,)*3
                            else:
                                a,s,w=seed;dist=.08+(t**.65)*s
                                p.location=(math.cos(a)*dist,0,math.sin(a)*dist-.18*t*t)
                                p.scale=(max(.02,1-t*.85),)*3;p.rotation_euler.y=t*3+a
                        render_scene.render.filepath=os.path.join(framesdir,f'{frame:02d}.png');bpy.ops.render.render(write_still=True)
                        # Reload the written frame: Render Result pixels may be empty headless.
                        img=bpy.data.images.load(render_scene.render.filepath,check_existing=False)
                        pixels=np.array(img.pixels[:],dtype=np.float32).reshape((128,128,4));pixels[:,:,3]*=(1-t)**.55
                        pixels[:3,:,3]=0;pixels[-3:,:,3]=0;pixels[:,:3,3]=0;pixels[:,-3:,3]=0
                        row,col=divmod(frame,4);atlas[(3-row)*128:(4-row)*128,col*128:(col+1)*128]=pixels
                        # Save faded, padded frame as the canonical source too.
                        img.pixels.foreach_set(pixels.ravel());img.filepath_raw=render_scene.render.filepath;img.save()
                    im=bpy.data.images.new(family,512,512,alpha=True);im.pixels.foreach_set(atlas.ravel());path=os.path.join(texdir,family+'.png');im.filepath_raw=path;im.file_format='PNG';im.save()
                    report['flipbooks'][family]={'file':path,'frames':16,'layout':'4x4 top-left row-major','frame_size':128,'gutter_pixels':3,'duration_seconds':.48 if family=='glass_dust_4x4' else .32,'static_fallback':'shard_fleck' if family=='glass_dust_4x4' else 'glass_glint','native_order_verified':False}
                    for p in parts:p.hide_render=True
                save_blend_copy(os.path.join(folder,'flipbook_source.blend'))
            allpaths=[bundle,blend,*meshfiles.values(),*texturefiles.values(),*[v['file'] for v in report['flipbooks'].values()]]
            report['sha256']={os.path.relpath(p,REPO):hashlib.sha256(open(p,'rb').read()).hexdigest() for p in allpaths}
            json.dump(report,open(os.path.join(folder,'manifest.json'),'w'),indent=2)
            return {'meshes':len(kit),'textures':len(texturefiles),'flipbooks':len(report['flipbooks']),'manifest':os.path.join(folder,'manifest.json')}
    finally:bpy.context.window.scene=previous;COLLECTION=oldcol

def build_vfx_animation_source():
    """Editable keyframes corresponding to the already-rendered source-frame equations.

    Adds an animation source without changing or reuploading accepted atlas pixels.
    Toggle the family collections to inspect either 16-frame burst.
    """
    global COLLECTION
    previous,oldcol=bpy.context.window.scene,COLLECTION
    scene=bpy.data.scenes.new('CombatFlipbookEditable');bpy.context.window.scene=scene;COLLECTION=scene.name
    try:
        with bpy.context.temp_override(scene=scene,view_layer=scene.view_layers[0]):
            scene.frame_start=1;scene.frame_end=16
            scene.render.engine='CYCLES';scene.cycles.samples=4;scene.render.threads_mode='FIXED';scene.render.threads=4
            scene.render.resolution_x=scene.render.resolution_y=128;scene.render.resolution_percentage=100;scene.render.film_transparent=True
            scene.render.image_settings.color_mode='RGBA';scene.view_settings.view_transform='Standard'
            cd=bpy.data.cameras.new('FlipbookCamera');cd.type='ORTHO';cd.ortho_scale=2.6
            camera=bpy.data.objects.new('FlipbookCamera',cd);scene.collection.objects.link(camera);camera.location=(0,-5,0);camera.rotation_euler=(math.pi/2,0,0);scene.camera=camera
            rng=random.Random(10524)
            for family in ('glass_dust_4x4','pressure_pop_4x4'):
                col=bpy.data.collections.new(family);scene.collection.children.link(col)
                mat=bpy.data.materials.new(family+'_AnimatedAlpha');mat.use_nodes=True;nodes=mat.node_tree.nodes;nodes.clear()
                em=nodes.new('ShaderNodeEmission');em.inputs['Color'].default_value=(1,1,1,1)
                tr=nodes.new('ShaderNodeBsdfTransparent');mix=nodes.new('ShaderNodeMixShader');out=nodes.new('ShaderNodeOutputMaterial')
                mat.node_tree.links.new(tr.outputs[0],mix.inputs[1]);mat.node_tree.links.new(em.outputs[0],mix.inputs[2]);mat.node_tree.links.new(mix.outputs[0],out.inputs[0])
                parts=[];seeds=[]
                if family=='pressure_pop_4x4':parts.append(rring('PressureRingEditable',(0,0,0),1,.025,'#FFFFFF',axis='Y',steps=32));seeds.append(None)
                for j in range(22 if family=='glass_dust_4x4' else 12):
                    a=rng.random()*math.tau;s=rng.uniform(.45,1);w=rng.uniform(.018,.045)
                    parts.append(rpoly('FleckEditable',[(-w,-w),(w,-w),(w*.3,w*2),(-w*.4,w)],.005,'#FFFFFF',bevel=0));seeds.append((a,s,w))
                for p in parts:
                    for old in list(p.users_collection):old.objects.unlink(p)
                    col.objects.link(p);assign_material([p],mat)
                for frame in range(16):
                    t=frame/15
                    for p,seed in zip(parts,seeds):
                        if seed is None:p.scale=(.12+t*.9,)*3
                        else:
                            a,s,w=seed;dist=.08+(t**.65)*s;p.location=(math.cos(a)*dist,0,math.sin(a)*dist-.18*t*t);p.scale=(max(.02,1-t*.85),)*3;p.rotation_euler.y=t*3+a
                        for prop in ('location','scale','rotation_euler'):p.keyframe_insert(data_path=prop,frame=frame+1)
                    mix.inputs[0].default_value=(1-t)**.55;mix.inputs[0].keyframe_insert(data_path='default_value',frame=frame+1)
                col.hide_render=family!='pressure_pop_4x4'
                col.hide_viewport=family!='pressure_pop_4x4'
            scene.frame_set(1)
            path=repo_path('assets','blender','vfx','combat_release','flipbook_animated.blend');save_blend_copy(path)
            manifest=repo_path('assets','blender','vfx','combat_release','manifest.json');report=json.load(open(manifest))
            report['animated_source']={'file':path,'frames':[1,16],'default_family':'pressure_pop_4x4','families_are_toggleable_collections':True,'matches_rendered_motion_equations':True,'atlas_pixels_changed':False}
            report['sha256'][os.path.relpath(path,REPO)]=hashlib.sha256(open(path,'rb').read()).hexdigest();json.dump(report,open(manifest,'w'),indent=2)
            return report['animated_source']
    finally:bpy.context.window.scene=previous;COLLECTION=oldcol
