"""World-origin FBX packaging and independent round-trip validation.

Run in the saved layout via Blender MCP. Decorative source instances stay linked;
only temporary export meshes have geometry transforms baked into their vertices.
"""
import bpy, bmesh, json, math, hashlib, sys
from pathlib import Path
from collections import defaultdict
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/blender/map/kilnport'
sys.path.insert(0,str(ROOT/'tools/map'))
import village_layout as L

def bbox(points):
    lo=[min(p[j] for p in points) for j in range(3)];hi=[max(p[j] for p in points) for j in range(3)]
    return {'min':lo,'max':hi,'size':[hi[j]-lo[j] for j in range(3)],'center':[(hi[j]+lo[j])/2 for j in range(3)]}

def rbx(p):return [p[0],p[2],-p[1]]

def audit_layout():
    scene=bpy.data.scenes['Kilnport_Final'];bpy.context.window.scene=scene;bpy.context.view_layer.update()
    anchors=json.loads((OUT/'anchors.json').read_text());fail=[]
    for item in anchors:
        candidates=[o for o in scene.objects if o.get('anchor')==item['id']]
        if item['kind'] in ('building','stand'):
            if not candidates:fail.append('Missing '+item['id']);continue
            if any((o.matrix_world.translation-Vector(item['blender'])).length>1e-5 for o in candidates):fail.append('Anchor mismatch '+item['id'])
    # Compare library geometry of approved stand to the actual assembled arena.
    arena=[o for o in scene.objects if o.get('anchor')=='arena']
    stand_bounds=bbox([o.matrix_world@v.co for o in arena for v in o.data.vertices])
    assert abs(stand_bounds['size'][2]-17.8)<.001,stand_bounds
    # Downward ground probes at centre + avatar-width offsets for the whole route.
    vs=[];fs=[]
    for o in bpy.data.collections['KP_terrain'].objects:
        if o.type!='MESH' or not o.name.startswith('Ground_'):continue
        k=len(vs);vs.extend(o.matrix_world@v.co for v in o.data.vertices);fs.extend([tuple(k+j for j in p.vertices) for p in o.data.polygons])
    tree=BVHTree.FromPolygons(vs,fs,all_triangles=False)
    probes=[]
    for path in L.PATHS:
        pts=path['points']
        if path['id']=='route1':pts=[pts[0],pts[2]]+pts[3:]
        for a,b in zip(pts,pts[1:]):
            aa,bb=Vector(a),Vector(b);d=bb-aa;n=Vector((-d.y,d.x)).normalized();steps=math.ceil(d.length/2)
            for j in range(steps+1):
                t=j/steps
                for offset in (-2,0,2):
                    p=aa.lerp(bb,t)+n*offset
                    expected=path['z']
                    if path['id']=='route1':
                        ramp_a=Vector((-175,-40));ramp_d=Vector((-87,-5));rt=(p-ramp_a).dot(ramp_d)/ramp_d.length_squared
                        side=abs((p-ramp_a).x*ramp_d.y-(p-ramp_a).y*ramp_d.x)/ramp_d.length
                        if -1e-5<=rt<=1+1e-5 and side<=11:expected=-20*max(0,min(1,rt))
                    hit=tree.ray_cast(Vector((p.x,p.y,200)),Vector((0,0,-1)))
                    error=None if hit[0] is None else abs(hit[0].z-expected)
                    if error is None or error>.08:fail.append({'path':path['id'],'point':list(p),'expected':expected,'actual':None if hit[0] is None else hit[0].z})
                    probes.append(error)
    report={'layout_sha256':hashlib.sha256((ROOT/'tools/map/village_layout.py').read_bytes()).hexdigest(),'anchor_count':len(anchors),'approved_stand_bounds':stand_bounds,'ground_probes':len(probes),'max_ground_height_error':max(e for e in probes if e is not None),'failures':fail}
    (OUT/'layout_validation.json').write_text(json.dumps(report,indent=2))
    return report

def export():
    original=bpy.context.window.scene
    scene=bpy.data.scenes.new('Kilnport_Export');scene.unit_settings.system='NONE';scene.unit_settings.scale_length=1
    bpy.context.window.scene=scene
    manifest={'version':1,'coordinate_contract':{'units':'stud','blender_unit_per_stud':1,'blender_to_roblox':'(X,Y,Z) -> (X,Z,-Y)','shared_origin_blender':[0,0,0],'shared_origin_roblox':[0,0,0]},
        'export_settings':{'global_scale':1,'apply_unit_scale':True,'apply_scale_options':'FBX_SCALE_UNITS','axis_forward':'-Z','axis_up':'Y','bake_space_transform':True},
        'import_settings':{'Scale Unit':'Stud','Scale':1,'Insert Using Scene Position':True,'Set Pivot to Scene Origin':True,'Import Only as Model':True,'World Up':'Top','World Forward':'Front','Merge Meshes':False},
        'preview_only':['sea (replace with Studio Terrain water at Roblox Y=-60)','lighting','camera','Blockout'],
        'textures':['kilnport_atlas.png','kilnport_cobble.png'],'chunks':[]}
    stats=[]
    for chunk in ('village_centre','village_north','village_south','cliffs_harbor','yard_west','yard_south','cullet_pit','terrain'):
        src=list(bpy.data.collections['KP_'+chunk].objects)
        bins=defaultdict(list)
        for o in src:
            if o.type!='MESH':continue
            # Spatial/material groups reduce draw calls without making giant meshes.
            center=sum((o.matrix_world@Vector(v) for v in o.bound_box),Vector())/8
            material=o.material_slots[0].material if o.material_slots else None
            bins[(material.name if material else 'None',int(center.x//96),int(center.y//96))].append(o)
        outobs=[];entries=[]
        for (matname,tx,ty),objects in sorted(bins.items()):
            groups=[];pending=[];tris=0
            for o in objects:
                count=sum(len(p.vertices)-2 for p in o.data.polygons)
                if pending and tris+count>6000:groups.append(pending);pending=[];tris=0
                assert count<8000,(o.name,count)
                pending.append(o);tris+=count
            if pending:groups.append(pending)
            for batch,items in enumerate(groups):
                verts=[];faces=[];uvs=[]
                for o in items:
                    k=len(verts);verts.extend(o.matrix_world@v.co for v in o.data.vertices)
                    for p in o.data.polygons:
                        faces.append(tuple(k+j for j in p.vertices))
                        layer=o.data.uv_layers.active
                        uvs.append([tuple(layer.data[i].uv) if layer else (0,0) for i in p.loop_indices])
                name=f'KP_{chunk}_{matname}_{tx}_{ty}_{batch}'
                me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
                mat=bpy.data.materials.get(matname)
                if mat:me.materials.append(mat)
                layer=me.uv_layers.new(name='UVMap')
                for p,uv in zip(me.polygons,uvs):
                    for li,val in zip(p.loop_indices,uv):layer.data[li].uv=val
                # Triangulate deterministically now, before FBX conversion.
                bm=bmesh.new();bm.from_mesh(me);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
                ob=bpy.data.objects.new(name,me);scene.collection.objects.link(ob);outobs.append(ob)
                bounds=bbox([rbx(v.co) for v in me.vertices]);assert max(bounds['size'])<1024,(name,bounds)
                entry={'name':name,'roblox_bounds':bounds,'triangles':len(me.polygons),'vertices':len(me.vertices),'world_origin':[0,0,0],
                    'source_objects':[o.name for o in items],'material':matname,'studio_color':mat.get('studio_color') if mat else None,'studio_material':mat.get('studio_material','SmoothPlastic') if mat else 'SmoothPlastic'}
                entries.append(entry)
        bpy.ops.object.select_all(action='DESELECT')
        for ob in outobs:ob.select_set(True)
        bpy.context.view_layer.objects.active=outobs[0]
        fn='KP_'+chunk+'.fbx'
        bpy.ops.export_scene.fbx(filepath=str(OUT/fn),use_selection=True,object_types={'MESH'},global_scale=1,apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',axis_forward='-Z',axis_up='Y',bake_space_transform=True,use_mesh_modifiers=True,use_triangles=True,add_leaf_bones=False,bake_anim=False,path_mode='COPY',embed_textures=True)
        points=[rbx(v.co) for o in outobs for v in o.data.vertices]
        manifest['chunks'].append({'id':chunk,'file':fn,'world_position':[0,0,0],'world_rotation_degrees':[0,0,0],'expected_bounding_box_studs':bbox(points),'mesh_count':len(entries),'triangles':sum(e['triangles'] for e in entries),'meshes':entries})
        stats.append((chunk,len(entries),sum(e['triangles'] for e in entries)))
        for ob in outobs:bpy.data.objects.remove(ob,do_unlink=True)
    bpy.context.window.scene=original;bpy.data.scenes.remove(scene)
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
    return stats

def verify():
    # Import files into an isolated scene and compare exact mesh names and bounds.
    manifest=json.loads((OUT/'manifest.json').read_text());original=bpy.context.window.scene
    sc=bpy.data.scenes.new('Kilnport_Roundtrip');bpy.context.window.scene=sc;results=[]
    for chunk in manifest['chunks']:
        bpy.ops.import_scene.fbx(filepath=str(OUT/chunk['file']),global_scale=1,use_custom_normals=True)
        bpy.context.view_layer.update();objects=[o for o in sc.objects if o.type=='MESH'];lookup={o.name:o for o in objects};errors=[]
        for expected in chunk['meshes']:
            ob=lookup.get(expected['name']);assert ob is not None,expected['name']
            pts=[rbx(ob.matrix_world@v.co) for v in ob.data.vertices];actual=bbox(pts)
            errors.append(max(abs(actual[k][j]-expected['roblox_bounds'][k][j]) for k in ('min','max') for j in range(3)))
        assert len(objects)==chunk['mesh_count']
        err=max(errors);assert err<.001,(chunk['id'],err)
        results.append({'chunk':chunk['id'],'meshes':len(objects),'max_bounds_error_studs':err,'sha256':hashlib.sha256((OUT/chunk['file']).read_bytes()).hexdigest()})
        for ob in list(sc.objects):bpy.data.objects.remove(ob,do_unlink=True)
    bpy.context.window.scene=original;bpy.data.scenes.remove(sc)
    (OUT/'export_validation.json').write_text(json.dumps({'passed':True,'roundtrip':results,'note':'Blender FBX round-trip plus raw FBX unit/axis audit; Studio asset upload/import is the next user step.'},indent=2))
    return results

def verify_raw_fbx():
    """Read the serialized numbers, independently of Blender's FBX importer."""
    from io_scene_fbx import parse_fbx
    manifest=json.loads((OUT/'manifest.json').read_text());report=[]
    for chunk in manifest['chunks']:
        root,version=parse_fbx.parse(str(OUT/chunk['file']))
        settings=next(e for e in root.elems if e.id==b'GlobalSettings')
        props=next(e for e in settings.elems if e.id==b'Properties70')
        values={p.props[0].decode():p.props[4] for p in props.elems}
        assert values['UnitScaleFactor']==100 and values['UpAxis']==1 and values['CoordAxis']==0
        objects=next(e for e in root.elems if e.id==b'Objects');points=[];models=0
        for e in objects.elems:
            if e.id==b'Geometry':
                coords=next(a for a in e.elems if a.id==b'Vertices').props[0]
                points.extend(zip(coords[0::3],coords[1::3],coords[2::3]))
            elif e.id==b'Model':
                models+=1
                pp=next(p for p in e.elems if p.id==b'Properties70')
                props={p.props[0]:list(p.props[4:]) for p in pp.elems}
                assert props.get(b'Lcl Scaling',[1,1,1])==[1,1,1]
                for key in (b'Lcl Translation',b'Lcl Rotation'):
                    assert max(abs(x) for x in props.get(key,[0,0,0]))<1e-6
        actual=bbox(list(points));expected=chunk['expected_bounding_box_studs']
        error=max(abs(actual[k][j]-expected[k][j]) for k in ('min','max') for j in range(3))
        assert error<.001,(chunk['id'],actual,expected)
        report.append({'chunk':chunk['id'],'fbx_version':version,'models':models,'raw_vertices_in_studs':True,'raw_bounds_error':error,'node_transforms':'identity','unit_metadata_cm':100})
    (OUT/'raw_fbx_validation.json').write_text(json.dumps({'passed':True,'note':'Raw vertex values already use studs. Select Stud, not From File or meters, in Studio. FBX unit metadata is retained separately with FBX_SCALE_UNITS.','chunks':report},indent=2))
    return report

if __name__=='__main__':
    print(audit_layout());print(export());print(verify());print(verify_raw_fbx())
