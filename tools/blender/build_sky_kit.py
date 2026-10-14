"""Original Crystal Isles kit. Load glassclash_blender.py first; preserves open scenes.

Call build_sky_piece(id) one at a time, or build_sky_kit(). Exports use studs and Y-up FBX.
Existing exports are returned untouched. Geometry/materials remain separately recolorable.
"""
import json
from mathutils import Matrix

SKY_IDS = ("crystal_single", "crystal_small", "crystal_big", "kiln_crystal", "featured_arch", "cloud_puff", "cloud_long", "cloud_bank")


def sky_crystal(name, radius, height, at=(0, 0, 0), lean=0, sides=6):
    vertices = []
    for z, r, shift in ((0, radius * .72, 0), (height * .7, radius, height * lean * .7), (height, .01, height * lean)):
        vertices.extend((at[0] + math.cos(i * math.tau / sides) * r + shift,
                         at[1] + math.sin(i * math.tau / sides) * r, at[2] + z) for i in range(sides))
    faces = [tuple(reversed(range(sides))), tuple(range(sides * 2, sides * 3))]
    for ring in range(2):
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((ring * sides + i, ring * sides + j, (ring + 1) * sides + j, (ring + 1) * sides + i))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces); mesh.update()
    obj = _link(bpy.data.objects.new(name, mesh))
    return set_shading(obj, False)


def sky_join(objects, name):
    bm = bmesh.new()
    for obj in objects:
        before = set(bm.verts)
        bm.from_mesh(obj.data)
        bmesh.ops.transform(bm, matrix=obj.matrix_world, verts=[v for v in bm.verts if v not in before])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    result = _mesh_object(name, bm)
    # Only the throwaway component objects created by this function are removed.
    for obj in objects: bpy.data.objects.remove(obj, do_unlink=True)
    return set_shading(result, False)


def sky_cloud(gid):
    specs = {
        "cloud_puff": [(0,0,0,4,3,1.8),(-3,0,-.25,2.8,2.5,1.4),(3,.2,-.3,2.6,2.3,1.4),(0,1,1,2.5,2.4,1.9)],
        "cloud_long": [(-5,0,0,4,2.7,1.3),(0,0,.2,4.5,3,1.8),(5,.2,-.2,3.7,2.6,1.2),(-1,.4,1.3,2.8,2.5,1.8)],
        "cloud_bank": [(-6,0,0,4.8,3.2,1.8),(0,0,.2,5,3.8,2),(6,0,0,4.6,3.3,1.7),(-3,1.1,1.7,3.5,3,2.1),(3,1,1.4,3.6,3,2)],
    }
    objects = []
    for i, (x,y,z,sx,sy,sz) in enumerate(specs[gid]):
        bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1)
        bmesh.ops.transform(bm, matrix=Matrix.Diagonal((sx,sy,sz,1)), verts=bm.verts)
        bmesh.ops.translate(bm, verts=bm.verts, vec=(x,y,z))
        objects.append(_mesh_object(f"Lump{i}",bm))
    return sky_join(objects, "Cloud")


def sky_arch():
    centres = [(-11,0),(-10.5,14),(-6,20),(0,22),(6,20),(10.5,14),(11,0)]
    vertices=[]
    for i,(x,z) in enumerate(centres):
        a=Vector(centres[max(0,i-1)]); b=Vector(centres[min(len(centres)-1,i+1)])
        tangent=(b-a).normalized(); normal=Vector((-tangent.y,tangent.x))
        for sign,y in ((-1,-1.6),(1,-1.6),(1,1.6),(-1,1.6)):
            vertices.append((x+normal.x*1.45*sign,y,z+normal.y*1.45*sign))
    faces=[(3,2,1,0),tuple(range(len(vertices)-4,len(vertices)))]
    for i in range(len(centres)-1):
        for j in range(4): faces.append((i*4+j,i*4+(j+1)%4,(i+1)*4+(j+1)%4,(i+1)*4+j))
    mesh=bpy.data.meshes.new("Arch");mesh.from_pydata(vertices,[],faces);mesh.update()
    arch=_link(bpy.data.objects.new("Arch",mesh));set_shading(arch,False)
    gem=sky_crystal("CrownGem",1.6,4,(0,0,22.5),sides=6)
    feet=sky_join([sky_crystal("FootL",2.1,6,(-11,0,0),-.08),sky_crystal("FootR",2.1,6,(11,0,0),.08)],"FootCrystals")
    return [(arch,"#B58CFF"),(gem,"#FFD166"),(feet,"#6FE7FF")]


def build_sky_piece(gid, preview=True):
    global COLLECTION
    assert gid in SKY_IDS
    folder=repo_path("assets","blender","map","sky_kit",gid)
    manifest=os.path.join(folder,"manifest.json")
    if os.path.exists(manifest): return json.load(open(manifest,encoding="utf-8"))
    previous_scene,previous_collection=bpy.context.window.scene,COLLECTION
    scene=bpy.data.scenes.new("SkyKit_"+gid)
    scene.unit_settings.system="NONE";scene.unit_settings.scale_length=1
    bpy.context.window.scene=scene;COLLECTION=scene.name
    try:
        if gid.startswith("cloud_"): colored=[(sky_cloud(gid),"#F4F7FF")]
        elif gid=="featured_arch": colored=sky_arch()
        elif gid=="kiln_crystal":
            colored=[(sky_crystal("KilnCrystal",5.2,18,sides=8),"#6FE7FF"),
                     (sky_join([sky_crystal("C1",1.6,7,(-4,0,0),-.3),sky_crystal("C2",1.4,6,(3.7,.5,0),.3)],"Satellites"),"#B58CFF")]
        else:
            specs={"crystal_single":[(0,0,.65,2.7,0)],"crystal_small":[(0,0,.75,3.3,0),(-.8,0,.45,2,-.25),(.7,.3,.4,1.7,.3)],
                   "crystal_big":[(0,0,1.2,5,0),(-1.1,0,.7,3.5,-.22),(1.1,.2,.65,3,.25),(-.5,-.8,.55,2.5,-.18),(.8,-.7,.5,2.2,.25),(0,1,.55,2.8,0)]}
            colored=[(sky_join([sky_crystal("Part",r,h,(x,y,0),lean) for x,y,r,h,lean in specs[gid]],"Crystal"),"#6FE7FF")]
        objects=[o for o,_ in colored]
        for obj,color in colored:
            assign_material([obj],preview_solid_material("SkyKit_"+color,color,roughness=.85))
            obj["studio_color"]=color;obj["studio_material"]="SmoothPlastic"
            obj["decorative"]=True;obj["cast_shadow"]=not gid.startswith("cloud_")
        lo,hi=_world_bounds(objects)
        report={"id":gid,"units":"1 unit = 1 stud","origin":"base" if not gid.startswith("cloud_") else "centre",
                "dimensions":[round(v,3) for v in hi-lo],"triangles":sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects),
                "parts":[{"name":o.name,"color":c,"material":"SmoothPlastic"} for o,c in colored]}
        report["fbx"]=export_fbx(objects,os.path.join(folder,gid+".fbx"))
        if preview: report["preview"]=render_icon(objects,os.path.join(folder,"preview.png"),samples=16)
        report["blend"]=save_blend_copy(os.path.join(folder,gid+".blend"))
        os.makedirs(folder,exist_ok=True)
        with open(manifest,"w",encoding="utf-8") as f: json.dump(report,f,indent=2)
        for obj in objects: obj.name=gid+"_"+obj.name
        return report
    finally:
        bpy.context.window.scene=previous_scene;COLLECTION=previous_collection


def build_sky_kit(): return [build_sky_piece(gid) for gid in SKY_IDS]
