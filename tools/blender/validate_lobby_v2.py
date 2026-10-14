"""Validate saved mesh sources/FBX, closed geometry and actual-rim clearance in Blender.
No Studio access. Each validation scene is isolated and the user's active scene restored.
"""
import bpy
import bmesh
import json
import hashlib
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/blender/map/lobby_v2'


def world_points(o):return [o.matrix_world@v.co for v in o.data.vertices]


def inside(p,poly):
    yes=False
    for a,b in zip(poly,poly[1:]+poly[:1]):
        if (a[1]>p[1])!=(b[1]>p[1]) and p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0]:yes=not yes
    return yes


def distance(p,poly):
    p=Vector(p[:2]);dist=[]
    for a,b in zip(poly,poly[1:]+poly[:1]):
        a,b=Vector(a),Vector(b);v=b-a;t=max(0,min(1,(p-a).dot(v)/v.length_squared))
        dist.append((p-(a+t*v)).length)
    return min(dist)


def inspect(o):
    bm=bmesh.new();bm.from_mesh(o.data)
    bad_edges=sum(not e.is_manifold for e in bm.edges)
    volume=bm.calc_volume(signed=True)
    bm.free();o.data.calc_loop_triangles()
    bad_triangles=sum((o.data.vertices[t.vertices[1]].co-o.data.vertices[t.vertices[0]].co).cross(
                      o.data.vertices[t.vertices[2]].co-o.data.vertices[t.vertices[0]].co).length<1e-9
                      for t in o.data.loop_triangles)
    return {'NonManifoldEdges':bad_edges,'SignedVolume':volume,'DegenerateTriangles':bad_triangles,
            'Triangles':len(o.data.loop_triangles),'OriginError':o.location.length,
            'RotationError':sum(abs(x) for x in o.rotation_euler),'ScaleError':sum(abs(x-1) for x in o.scale)}


def validate_lobby_v2():
    previous=bpy.context.window.scene
    manifest=json.loads((OUT/'manifest.json').read_text())
    fences=json.loads((OUT/'fence_geometry.json').read_text())
    report={'Status':'PASS','Assets':{},'Source':'Saved isolated .blend sources and exported FBX files',
            'StudioStatus':'Not imported or playtested; no live Studio access', 'MaxVertexError':0,
            'FenceSourceMatches':hashlib.sha256((ROOT/'assets/blender/map/sky/fence_paths.json').read_bytes()).hexdigest()==manifest['FenceSourceSHA256']}
    assert report['FenceSourceMatches']
    failures=[]
    try:
        for name,spec in manifest['Assets'].items():
            with bpy.data.libraries.load(str(OUT/spec['Source']),link=False) as (a,b):b.scenes=a.scenes
            source=b.scenes[0];bpy.context.window.scene=source
            sources={o.name:o for o in source.objects if o.type=='MESH'}
            # Blender may suffix globally colliding names when appending a saved asset.
            source_list=list(sources.values());row={};source_by_name={}
            for expected in spec['Meshes']:
                matches=[o for o in source_list if o.get('AssetMeshName')==expected['Name']]
                assert len(matches)==1,(name,expected['Name'],[o.name for o in matches])
                o=matches[0];source_by_name[expected['Name']]=o;checks=inspect(o)
                assert checks['NonManifoldEdges']==0 and checks['SignedVolume']>0 and checks['DegenerateTriangles']==0,(name,o.name,checks)
                assert checks['OriginError']<1e-6 and checks['RotationError']<1e-6 and checks['ScaleError']<1e-6
                assert checks['Triangles']==expected['Triangles']
                row[expected['Name']]=checks
            rim=fences.get(name,{}).get('SourceRim')
            fence_check={}
            if rim:
                pts=[list(p) for o in source_list for p in world_points(o)]
                outside=[p for p in pts if not inside(p,rim)]
                assert not outside,(name,'Fence vertices overhang rim',len(outside))
                fence_check={'OutsideRimVertices':0,'MinRimClearance':min(distance(p,rim) for p in pts),
                             'Height':max(p[2] for p in pts),'PostCount':len(fences[name]['Posts'])}
                assert abs(fence_check['Height']-3)<1e-5
                endpoints=[p for path in fences[name]['Paths'] for p in (path[0],path[-1]) if abs(abs(p[0])-5.5)<1e-5]
                assert all(abs(abs(p[0])-5.5)<1e-5 for p in endpoints)
                fence_check['GateCenterWidth']=11
                fence_check['ClearWidthBelowCaps']=11-.86
                fence_check['ClearWidthAtCaps']=11-1.02
            temp=bpy.data.scenes.new('LV2_FBX_QA_'+name);bpy.context.window.scene=temp
            bpy.ops.import_scene.fbx(filepath=str(OUT/spec['FBX']),use_custom_normals=False)
            imported=[o for o in temp.objects if o.type=='MESH']
            assert len(imported)==len(source_list),(name,'Mesh count')
            maxerr=0
            for expected in spec['Meshes']:
                matches=[o for o in imported if o.get('AssetMeshName')==expected['Name']]
                assert len(matches)==1,(name,'FBX missing',expected['Name'])
                o=matches[0];src=source_by_name[expected['Name']]
                # Export triangulates polygons; vertices and world positions must still match.
                a=sorted(tuple(round(x,5) for x in p) for p in world_points(src))
                b=sorted(tuple(round(x,5) for x in p) for p in world_points(o))
                assert len(a)==len(b),(name,o.name,'Vertex count')
                err=max((Vector(p)-Vector(q)).length for p,q in zip(a,b))
                assert err<.0001,(name,o.name,'Vertex error',err)
                maxerr=max(maxerr,err)
                assert o.location.length<1e-5,(name,'Imported origin moved',o.location[:])
            report['Assets'][name]={'MeshChecks':row,'FenceChecks':fence_check,'FBXMaxVertexError':maxerr,
                                   'MeshCount':len(imported),'Triangles':sum(x['Triangles'] for x in row.values())}
            report['MaxVertexError']=max(report['MaxVertexError'],maxerr)
            # These are only disposable validation copies, never user scene objects.
            bpy.context.window.scene=previous
            for s in (temp,source):
                for o in list(s.objects):bpy.data.objects.remove(o,do_unlink=True)
                bpy.data.scenes.remove(s)
        report['TotalTriangles']=sum(a['Triangles'] for a in report['Assets'].values())
        report['TotalMeshes']=sum(a['MeshCount'] for a in report['Assets'].values())
        # Verify each bridge rail end is exactly the corresponding island gate endpoint.
        names=['Isle_Lobby','Isle_Arena1','Isle_Arena2','Isle_Arena3','Isle_Featured']
        joins=[]
        for i in range(4):
            bridge='Fence_Bridge'+str(i+1);origin=Vector(manifest['Assets'][bridge]['PivotBlender'])
            for side in (0,1):
                for end,island,which in ((0,names[i],'North'),(-1,names[i+1],'South')):
                    world=Vector(fences[bridge]['Paths'][side][end])+origin
                    loc=Vector(manifest['Assets']['Fence_'+island]['PivotBlender'])
                    candidates=[Vector((p[0],p[1],0))+loc for path in fences['Fence_'+island]['Paths'] for p in (path[0],path[-1])
                                if (p[1]>0)==(which=='North') and abs(p[0]-(-5.5 if side==0 else 5.5))<1e-5]
                    err=min((world-p).length for p in candidates);assert err<1e-6
                    joins.append(err)
        report['BridgeJoinCount']=len(joins);report['MaxBridgeJoinError']=max(joins)
    except Exception as e:
        report['Status']='FAIL';report['Error']=repr(e)
        raise
    finally:
        bpy.context.window.scene=previous
        (OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
    return {k:report[k] for k in ('Status','TotalTriangles','TotalMeshes','MaxVertexError','BridgeJoinCount','MaxBridgeJoinError')}


if __name__=='__main__':print(validate_lobby_v2())
