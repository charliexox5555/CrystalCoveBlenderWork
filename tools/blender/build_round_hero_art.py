"""Original round cosmetics v2. Run after glassclash_blender.py through Blender MCP.
Isolated scene, deck origin at z=0, +Y forward. Originals/open scene preserved.
"""
import json
from math import sin, cos, pi
from mathutils import Vector


def build_round_hero_art():
    out = repo_path('assets', 'blender', 'round_cosmetics', 'hero_v2')
    os.makedirs(out, exist_ok=True)
    assert not os.path.exists(os.path.join(out, 'round_heroes.blend')), 'Preserve existing v2 source'
    previous = bpy.context.window.scene
    scene = bpy.data.scenes.new('RoundHeroes_v2')
    bpy.context.window.scene = scene
    scene.unit_settings.system = 'NONE'
    scene.unit_settings.scale_length = 1
    groups = {}
    palette = {'Coral':'EF8268','Cream':'FFE39A','Ink':'29364E','Glow':'83F0ED',
               'Teal':'61D4DF','Lilac':'B8A4F4','White':'E2ECFF','Rose':'F2B3D9','Gold':'FFE29D'}
    mats = {}
    for name, color in palette.items():
        m = bpy.data.materials.new('HeroV2_'+name)
        m.diffuse_color = tuple(int(color[i:i+2],16)/255 for i in (0,2,4))+(1,)
        m.use_nodes = True
        node = m.node_tree.nodes.get('Principled BSDF')
        node.inputs['Base Color'].default_value=m.diffuse_color
        node.inputs['Roughness'].default_value=.27 if name=='Glow' else .36
        node.inputs['Metallic'].default_value=.15
        mats[name]=m

    def finish(obj, group, name, material, smooth=True, motion=None):
        obj.name='RH2_'+group+'_'+name
        obj.data.materials.clear()
        obj.data.materials.append(mats[material])
        obj['studio_color']='#'+palette[material]
        obj['studio_material']='Neon' if material=='Glow' else 'SmoothPlastic'
        obj['asset_group']=group
        obj['canonical_name']=name
        if motion: obj['ride_motion']=motion
        for p in obj.data.polygons: p.use_smooth=smooth
        groups.setdefault(group,[]).append(obj)
        return obj

    def mesh(group,name,verts,faces,mat,smooth=True,motion=None):
        data=bpy.data.meshes.new('RH2_'+name)
        data.from_pydata(verts,[],faces); data.update()
        obj=bpy.data.objects.new('RH2_'+name,data); scene.collection.objects.link(obj)
        return finish(obj,group,name,mat,smooth,motion)

    def loft(group,name,sections,mat,n=16):
        # y, half-width, half-height, z centre. Closed continuous hull, not primitive stacking.
        v=[(x*cos(j*2*pi/n),y,z+h*sin(j*2*pi/n)) for y,x,h,z in sections for j in range(n)]
        f=[tuple(range(n-1,-1,-1)),tuple((len(sections)-1)*n+j for j in range(n))]
        f += [(i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(len(sections)-1) for j in range(n)]
        return mesh(group,name,v,f,mat)

    def ellipsoid(group,name,position,scale,mat,segments=16,rings=8):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=position)
        obj=bpy.context.object; obj.scale=scale
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        return finish(obj,group,name,mat)

    def ribbon(group,name,points,width,mat,motion=None):
        verts=[]
        for i,p in enumerate(points):
            tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])
            side=Vector((-tangent.y,tangent.x,0)).normalized()*width/2
            verts += [Vector(p)-side,Vector(p)+side]
        faces=[(2*i,2*i+1,2*i+3,2*i+2) for i in range(len(points)-1)]
        obj=mesh(group,name,verts,faces,mat,True,motion)
        mod=obj.modifiers.new('Solid ribbon','SOLIDIFY'); mod.thickness=.055
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bevel=obj.modifiers.new('Soft edges','BEVEL'); bevel.width=.035; bevel.segments=2
        bpy.ops.object.modifier_apply(modifier=bevel.name)
        return obj

    def torus(group,name,position,major,minor,mat,rotation=(0,0,0)):
        bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=8,location=position,rotation=rotation,major_radius=major,minor_radius=minor)
        return finish(bpy.context.object,group,name,mat)

    def combine(group,names,name,mat):
        targets=[o for o in groups[group] if o['canonical_name'] in names]
        bpy.ops.object.select_all(action='DESELECT')
        for o in targets:o.select_set(True)
        bpy.context.view_layer.objects.active=targets[0]
        bpy.ops.object.join()
        result=targets[0]
        groups[group]=[o for o in groups[group] if o not in targets]+[result]
        result.name='RH2_'+group+'_'+name; result['canonical_name']=name
        return result

    # Rocket Skiff: curved coral shell, recessed deck, twin swept nacelles and luminous nozzles.
    g='rocket_skiff'
    loft(g,'Hull',[(-2.6,.75,.2,-.35),(-2.25,1.55,.4,-.4),(-1,1.7,.5,-.5),(1.1,1.55,.46,-.43),(2.6,.8,.25,-.25),(3.3,.08,.06,-.05)],'Coral',24)
    loft(g,'Deck',[(-2.25,.7,.045,.02),(-1.7,1.05,.045,.035),(1.4,.9,.045,.035),(2.4,.25,.03,.08)],'Ink')
    for side in (-1,1):
        pod=loft(g,'Engine'+str(side),[(-2.6,.32,.32,-.48),(-2.2,.58,.55,-.48),(.6,.5,.48,-.45),(1.6,.32,.32,-.38),(2,.05,.05,-.3)],'Cream')
        for v in pod.data.vertices:v.co.x+=side*1.95
        torus(g,'Nozzle'+str(side),(side*1.95,-2.65,-.48),.34,.095,'Ink',(pi/2,0,0))
        torus(g,'NozzleGlow'+str(side),(side*1.95,-2.73,-.48),.28,.065,'Glow',(pi/2,0,0))
        flame=loft(g,'Exhaust'+str(side),[(-3.65,.025,.025,-.48),(-3.1,.2,.2,-.48),(-2.8,.28,.28,-.48)],'Glow')
        for v in flame.data.vertices:v.co.x+=side*1.95
        flame['ride_motion']='Flame'
        ribbon(g,'SweptFin'+str(side),[(side*1.6,-1.4,-.1),(side*2.35,-1.75,.5),(side*2.7,-2.4,.8)],.55,'Coral')
        ribbon(g,'HullPinstripe'+str(side),[(side*.4,2.6,.02),(side*1.2,1.1,.03),(side*1.35,-1,.03),(side*.85,-2.25,.02)],.12,'Cream')
    combine(g,['Engine-1','Engine1'],'Engines','Cream')
    combine(g,['Nozzle-1','Nozzle1'],'Nozzles','Ink')
    combine(g,['NozzleGlow-1','NozzleGlow1'],'EngineGlow','Glow')
    combine(g,['SweptFin-1','SweptFin1'],'SweptFins','Coral')
    combine(g,['HullPinstripe-1','HullPinstripe1'],'HullInlay','Cream')

    # Skyboard: lifted surfboard silhouette, flowing inlay and curved anti-gravity rails.
    g='skyboard'
    loft(g,'Deck',[(-3.4,.1,.07,.45),(-2.9,.9,.14,.18),(-1.8,1.55,.18,-.1),(0,1.65,.2,-.2),(1.8,1.35,.18,-.1),(3,.6,.12,.22),(3.5,.04,.03,.55)],'Teal',24)
    loft(g,'Grip',[(-1.8,.65,.035,.02),(-1,1,.04,.03),(1,1,.04,.03),(2,.45,.03,.08)],'Ink')
    for side in (-1,1):
        ribbon(g,'Rail'+str(side),[(side*.65,-3,.05),(side*1.55,-1.7,-.4),(side*1.7,0,-.55),(side*1.4,1.8,-.35),(side*.4,3.1,.3)],.22,'Cream')
        ribbon(g,'Lift'+str(side),[(side*1.1,-2,-.55),(side*1.6,-1,-.7),(side*1.65,0,-.75),(side*1.4,1.5,-.55)],.1,'Glow')
        ribbon(g,'Inlay'+str(side),[(side*.2,-2.65,.2),(side*.4,-1.7,.09),(side*.35,0,.05),(0,2.7,.27)],.1,'Cream')
    for names,name,mat in [(['Rail-1','Rail1'],'SculptedRails','Cream'),(['Lift-1','Lift1'],'LiftGlow','Glow'),(['Inlay-1','Inlay1'],'DeckInlay','Cream')]:combine(g,names,name,mat)

    # Cloud: one sculpted cushion with soft scalloped outline and flowing rainbow tails.
    g='cloud_cushion'
    for i in range(9):
        a=i/9*2*pi
        ellipsoid(g,'Puff'+str(i),(cos(a)*1.35,sin(a)*1.45,-.65),(1.1,.98,.62),'White')
    ellipsoid(g,'CloudCore',(0,0,-.5),(1.75,1.85,.65),'White')
    cloud=combine(g,['Puff'+str(i) for i in range(9)]+['CloudCore'],'SculptedCloud','White')
    bpy.context.view_layer.objects.active=cloud
    remesh=cloud.modifiers.new('Unified soft cloud','REMESH');remesh.mode='VOXEL';remesh.voxel_size=.14;remesh.use_smooth_shade=True
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    dec=cloud.modifiers.new('Mobile silhouette','DECIMATE');dec.ratio=.28
    bpy.ops.object.modifier_apply(modifier=dec.name)
    loft(g,'Cushion',[(-1,.5,.05,.06),(-.6,1.1,.06,.08),(.7,1.1,.06,.08),(1.1,.4,.04,.08)],'Lilac')
    for i,mat in enumerate(('Rose','Gold','Glow')):
        ribbon(g,'Rainbow'+str(i),[((i-1)*.43+sin(t*pi)*.22,-1.8-t*2.4,-.7-sin(t*pi)*.3) for t in [j/12 for j in range(13)]],.35,mat)

    # Prism Ray: organic, broad swept wings, faceted glass crest and smiling eye forms.
    g='prism_ray'
    loft(g,'Body',[(-2.3,.25,.12,-.3),(-1.2,1,.3,-.35),(0,1.4,.4,-.4),(1.5,1,.32,-.3),(2.25,.35,.12,-.18)],'Lilac',24)
    loft(g,'Saddle',[(-1,.6,.05,.04),(0,.9,.06,.05),(1,.6,.05,.06)],'Cream')
    for side in (-1,1):
        verts=[]
        for i in range(9):
            u=i/8
            for j in range(9):
                v=j/8
                verts.append((side*(.8+u*3.25),(1.5-v*3.8)*(1-.85*u)-u*.9+sin(v*pi)*u*.35,-.35+sin(u*pi)*.5-u*u*.35+sin(v*pi)*.16))
        faces=[(i*9+j,i*9+j+1,(i+1)*9+j+1,(i+1)*9+j) if side<0 else (i*9+j,(i+1)*9+j,(i+1)*9+j+1,i*9+j+1) for i in range(8) for j in range(8)]
        wing=mesh(g,'WingL' if side<0 else 'WingR',verts,faces,'Lilac',True,'Wing')
        wing['wing_side']=side;wing['wing_pivot']=[side*.8,0,-.35]
        mod=wing.modifiers.new('Wing volume','SOLIDIFY');mod.thickness=.12
        bpy.context.view_layer.objects.active=wing;bpy.ops.object.modifier_apply(modifier=mod.name)
        ellipsoid(g,'Eye'+str(side),(side*.55,1.85,-.02),(.13,.19,.12),'Ink')
        light=ribbon(g,'WingInlayL' if side<0 else 'WingInlayR',[(side*(.9+t*2.7),.8-t*1.5,-.15+sin(t*pi)*.48) for t in [j/12 for j in range(13)]],.1,'Glow','Wing')
        light['wing_side']=side;light['wing_pivot']=[side*.8,0,-.35]
    combine(g,['Eye-1','Eye1'],'FriendlyEyes','Ink')
    ribbon(g,'Tail',[(0,-1.8,-.3),(.35,-2.6,-.1),(.2,-3.6,.1),(-.3,-4.5,.45)],.35,'Glow')

    # Shared mesh VFX vocabulary: sculpted explosion, jagged shock crown, crystals and a real star.
    g='vfx'
    verts=[];faces=[];n=48
    for k in range(4):
        for i in range(n):
            a=i/n*2*pi;r=(.7 if k<2 else 1)*(1+.08*sin(a*12))
            z=(.03 if k%2==0 else -.03)+(.18*max(0,sin(a*12)) if k>=2 else 0)
            verts.append((cos(a)*r,sin(a)*r,z))
    for i in range(n):
        j=(i+1)%n
        faces += [(i,j,2*n+j,2*n+i),(n+i,3*n+i,3*n+j,n+j),(i,n+i,n+j,j),(2*n+i,2*n+j,3*n+j,3*n+i)]
    mesh(g,'ShockCrown',verts,faces,'Glow',False)
    for i in range(7):
        a=i/7*2*pi
        ellipsoid(g,'BlastLobe'+str(i),(cos(a)*.55,sin(a)*.55,.15*sin(a*2)),(.6,.65,.65),'Coral',12,6)
    ellipsoid(g,'BlastCore',(0,0,0),(.8,.8,.8),'Coral',16,8)
    combine(g,['BlastLobe'+str(i) for i in range(7)]+['BlastCore'],'BlastBloom','Coral')
    v=[(cos(i/10*2*pi)*(.9 if i%2==0 else .43),sin(i/10*2*pi)*(.9 if i%2==0 else .43),z) for z in (-.12,.12) for i in range(10)]
    f=[tuple(range(9,-1,-1)),tuple(range(10,20))]+[(i,(i+1)%10,(i+1)%10+10,i+10) for i in range(10)]
    star=mesh(g,'NovaStar',v,f,'Gold',False)
    bevel=star.modifiers.new('Toy bevel','BEVEL');bevel.width=.08;bevel.segments=2
    bpy.context.view_layer.objects.active=star;bpy.ops.object.modifier_apply(modifier=bevel.name)
    mesh(g,'CrystalShard',[(0,0,1),(-.28,-.18,.35),(.28,-.18,.35),(.28,.18,.35),(-.28,.18,.35),(-.14,-.1,-.7),(.14,-.1,-.7),(.14,.1,-.7),(-.14,.1,-.7),(0,0,-1)],[(0,1,2),(0,2,3),(0,3,4),(0,4,1),(1,5,6,2),(2,6,7,3),(3,7,8,4),(4,8,5,1),(5,9,6),(6,9,7),(7,9,8),(8,9,5)],'Glow',False)
    ribbon(g,'ConfettiCurl',[(sin(t*pi)*.3,t-.5,sin(t*2*pi)*.2) for t in [j/12 for j in range(13)]],.25,'Rose')
    for obj in groups['vfx']:obj.rotation_euler.x=pi if obj['canonical_name']=='CrystalShard' else pi/2

    # Export each material/motion mesh with its actual bounds and triangles for MCP staging.
    manifest={'version':2,'coordinate_contract':'Blender (x,y,z) -> Roblox (x,z,-y); 1 unit=1 stud; deck z=0','groups':{}}
    try:
        for group,objects in groups.items():
            folder=os.path.join(out,group);os.makedirs(folder,exist_ok=True)
            for obj in objects:
                bm=bmesh.new();bm.from_mesh(obj.data)
                bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
                bm.to_mesh(obj.data);bm.free();obj.data.update()
            export_fbx(objects,os.path.join(folder,group+'.fbx'))
            entries=[]
            for obj in objects:
                bpy.context.view_layer.update();obj.data.calc_loop_triangles()
                verts=[obj.matrix_world@v.co for v in obj.data.vertices]
                mapped=[[round(v.x,5),round(v.z,5),round(-v.y,5)] for v in verts]
                triangles=[[int(i) for i in t.vertices] for t in obj.data.loop_triangles]
                entry={'name':obj['canonical_name'],'color':obj['studio_color'],'material':obj['studio_material'],'vertices':mapped,'triangles':triangles}
                for prop in ('ride_motion','wing_side','wing_pivot'):
                    if prop in obj:entry[prop]=list(obj[prop]) if prop=='wing_pivot' else obj[prop]
                filename=group+'_'+entry['name']+'.json'
                with open(os.path.join(folder,filename),'w',encoding='utf-8') as f:json.dump(entry,f,separators=(',',':'))
                entries.append({'file':filename,'name':entry['name'],'triangles':len(triangles),'vertices':len(mapped)})
            manifest['groups'][group]=entries
        export_fbx([o for objects in groups.values() for o in objects],os.path.join(out,'ROUND_HEROES_V2_IMPORT.fbx'))
        save_blend_copy(os.path.join(out,'round_heroes.blend'))
        with open(os.path.join(out,'manifest.json'),'w',encoding='utf-8') as f:json.dump(manifest,f,indent=2)
    finally:
        bpy.context.window.scene=previous
    return {'source':os.path.join(out,'round_heroes.blend'),'groups':manifest['groups'],'preserved_scene':previous.name}
