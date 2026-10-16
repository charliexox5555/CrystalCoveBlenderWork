"""Refine our Halloween sources into one import bundle; preserve v1 and the user's scene."""
import bpy, bmesh, math, json, os, shutil
from mathutils import Vector, Matrix
from mathutils.geometry import tessellate_polygon

ROOT = r"C:/Users/charl/Documents/CrystalCoveBlenderWork"
GLASSCLASH_REPO = ROOT
exec(open(ROOT + "/tools/blender/glassclash_blender.py").read())
OUT = ROOT + "/assets/blender/seasonal/hollowlight_v2"
assert not bpy.data.scenes.get("Hollowlight_v2"), "Preserve the existing refined scene"
assert not os.path.exists(OUT + "/HOLLOWLIGHT_V2_IMPORT.fbx"), "Preserve the existing release export"
os.makedirs(OUT, exist_ok=True)
old_scene = bpy.context.window.scene
source_scene = bpy.data.scenes["Hollowlight_v1"]
old_manifest = json.load(open(ROOT + "/assets/blender/seasonal/hollowlight_v1/manifest.json"))
scene = bpy.data.scenes.new("Hollowlight_v2")
scene.unit_settings.system, scene.unit_settings.scale_length = "METRIC", 1
groups = {"pumpkin": [], "shards": [], "flyer": [], "finisher": []}
materials = {}

def material_copy(m):
    if m.name not in materials:
        n = m.copy(); n.name = m.name.replace("HHL_", "HH2_")
        p = n.node_tree.nodes.get("Principled BSDF")
        if "WispMint" in m.name:
            n.diffuse_color = (.12,.86,.51,1)
            p.inputs["Base Color"].default_value = n.diffuse_color
            p.inputs["Emission Color"].default_value = n.diffuse_color
            p.inputs["Emission Strength"].default_value = .55
        if "AmberGlass" in m.name:
            p.inputs["Transmission Weight"].default_value = .22
            p.inputs["Roughness"].default_value = .19
        materials[m.name] = n
    return materials[m.name]

def copy_object(old, group, name=None, transform=None):
    o = old.copy(); o.data = old.data.copy(); o.name = name or old.name.replace("HHL_", "HH2_").replace("-1", "_L")
    o.data.transform(old.matrix_world)
    if transform is not None: o.data.transform(transform)
    o.matrix_world = Matrix.Identity(4)
    o.data.materials.clear()
    for m in old.data.materials: o.data.materials.append(material_copy(m))
    if not o.data.materials: o.data.materials.append(material_copy(bpy.data.materials["HHL_AmberGlass"]))
    scene.collection.objects.link(o)
    groups[group].append(o)
    return o

def new_mesh(name, vertices, faces, mat, group, smooth=True):
    d = bpy.data.meshes.new(name)
    d.from_pydata(vertices, [], faces); d.update()
    o = bpy.data.objects.new(name, d); scene.collection.objects.link(o)
    o.data.materials.append(mat)
    for p in d.polygons: p.use_smooth = smooth
    groups[group].append(o)
    return o

def apply_modifier(o, kind, **settings):
    mod = o.modifiers.new("Refinement", kind)
    for key, value in settings.items(): setattr(mod, key, value)
    with bpy.context.temp_override(object=o,active_object=o): bpy.ops.object.modifier_apply(modifier=mod.name)

def project_patch(name, outline, onto, mat, group, offset=.022, subdivide=True):
    flat = [Vector((x,0,z)) for x,z in outline]
    lookup = {tuple(p): i for i,p in enumerate(flat)}
    faces = [tuple(p if isinstance(p,int) else lookup[tuple(p)] for p in tri) for tri in tessellate_polygon([flat])]
    o = new_mesh(name, [tuple(p) for p in flat], faces, mat, group)
    bm = bmesh.new(); bm.from_mesh(o.data)
    if subdivide:
        for iteration in range(6):
            long_edges=[e for e in bm.edges if e.calc_length()>.085]
            if not long_edges:break
            bmesh.ops.subdivide_edges(bm,edges=long_edges,cuts=1,use_grid_fill=True)
            bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bm.to_mesh(o.data); bm.free()
    for v in o.data.vertices:
        hit, pos, normal, index = onto.ray_cast(Vector((v.co.x,-6,v.co.z)), Vector((0,1,0)))
        assert hit, (name,tuple(v.co))
        v.co = pos + Vector((0,-offset,0))
    o.data.update()
    bm = bmesh.new(); bm.from_mesh(o.data); bm.normal_update()
    if sum(f.normal.y for f in bm.faces)>0: bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
    bm.to_mesh(o.data); bm.free()
    apply_modifier(o,"SOLIDIFY",thickness=.006,offset=-1)
    return o

def enlarged(points, factor):
    center = sum((Vector(p) for p in points),Vector((0,0))) / len(points)
    return [tuple(center+(Vector(p)-center)*factor) for p in points]

def grin_outline():
    xs = sorted(set([-.44+i*.88/24 for i in range(25)]+[-.23,-.13,.13,.23]))
    top=[]
    for x in xs:
        z=-1.28+.13*(abs(x)/.44)**1.7
        if x in (-.23,.13): top.extend([(x,z),(x,z-.075)])
        elif x in (-.13,.23): top.extend([(x,z-.075),(x,z)])
        else: top.append((x,z-(.075 if -.23<x<-.13 or .13<x<.23 else 0)))
    bottom=[(x,-1.28+.13*(abs(x)/.44)**1.7-.245*max(0,1-(x/.44)**2)**.65) for x in reversed(xs[1:-1])]
    return top+bottom

def tapered_tube(o, points, radii, sides=8):
    verts=[]; faces=[]; pts=[Vector(p) for p in points]
    for i,p in enumerate(pts):
        t=(pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]).normalized()
        axis=t.cross(Vector((0,0,1)))
        if axis.length<.01: axis=t.cross(Vector((0,1,0)))
        axis.normalize(); other=t.cross(axis).normalized()
        for j in range(sides):
            a=j*math.tau/sides; verts.append(tuple(p+radii[i]*(axis*math.cos(a)+other*math.sin(a))))
    for i in range(len(pts)-1):
        for j in range(sides):
            a=i*sides+j; b=i*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
    faces += [tuple(reversed(range(sides))),tuple((len(pts)-1)*sides+j for j in range(sides))]
    d=bpy.data.meshes.new(o.name+"_Flow");d.from_pydata(verts,[],faces);d.update()
    for m in o.data.materials:d.materials.append(m)
    o.data=d
    for p in d.polygons:p.use_smooth=True

def merge_material_group(objects,name,mat,group,transform):
    verts=[];faces=[]
    for o in objects:
        start=len(verts)
        verts.extend(tuple(transform@v.co) for v in o.data.vertices)
        faces.extend(tuple(start+i for i in p.vertices) for p in o.data.polygons)
    return new_mesh(name,verts,faces,mat,group)

try:
    bpy.context.window.scene=scene
    # Narrow the pumpkin to fit the Pop-sized presentation envelope; shards follow exactly.
    narrow=Matrix.Diagonal((.8,.8,1,1))
    for item in old_manifest["groups"]["pumpkin"]:
        old=bpy.data.objects[item["name"]]
        if "Eye" not in old.name and "Smile" not in old.name:copy_object(old,"pumpkin",transform=narrow)
    known={x["name"] for g in old_manifest["groups"].values() for x in g}
    shards=[o for o in source_scene.objects if o.type=="MESH" and o.name not in known]
    assert len(shards)==16
    for i,o in enumerate(sorted(shards,key=lambda o:o.name),1):
        copy_object(o,"shards",f"HH2_Pumpkin_Shard_{i:02}",narrow).hide_render=True
    body=next(o for o in groups["pumpkin"] if o.name=="HH2_Pumpkin_Body")
    bpy.context.view_layer.update()
    mint=material_copy(bpy.data.materials["HHL_WispMint"])
    dark=bpy.data.materials.new("HH2_CarvedEdge");dark.diffuse_color=(.11,.035,.012,1);dark.use_nodes=True
    dark.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=dark.diffuse_color
    dark.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value=.48
    for side,label in [(-1,"L"),(1,"R")]:
        eye=[(side*.14,-.91),(side*.42,-.89),(side*.275,-.66)]
        project_patch("HH2_Pumpkin_EyeEdge_"+label,enlarged(eye,1.18),body,dark,"pumpkin",.015)
        project_patch("HH2_Pumpkin_Eye_"+label,eye,body,mint,"pumpkin",.024)
    mouth=grin_outline()
    project_patch("HH2_Pumpkin_GrinEdge",enlarged(mouth,1.12),body,dark,"pumpkin",.022)
    project_patch("HH2_Pumpkin_Grin",mouth,body,mint,"pumpkin",.032)
    for o in groups["pumpkin"]:
        if "Leaf" in o.name and "Vein" not in o.name:apply_modifier(o,"SOLIDIFY",thickness=.018,offset=0)
    # More comfortable flat deck and flowing, tapered exhaust, retaining the wing identity.
    for item in old_manifest["groups"]["flyer"]:copy_object(bpy.data.objects[item["name"]],"flyer")
    purple=material_copy(bpy.data.materials["HHL_MidnightViolet"])
    verts=[(.65*math.cos(i*math.tau/32),1.05*math.sin(i*math.tau/32),z) for z in [.29,.33] for i in range(32)]
    faces=[tuple(reversed(range(32))),tuple(32+i for i in range(32))]+[(i,(i+1)%32,32+(i+1)%32,32+i) for i in range(32)]
    deck=new_mesh("HH2_Skiff_DeckInlay",verts,faces,purple,"flyer")
    apply_modifier(deck,"BEVEL",width=.025,segments=2)
    for side in [-1,1]:
        name="HH2_Skiff_Exhaust"+("_L" if side<0 else "1")
        o=next(o for o in groups["flyer"] if o.name==name)
        pts=[(side*(.7+.15*t),1.25+t*1.2,-.10-.15*t+.1*math.sin(t*math.tau)) for t in [i/12 for i in range(13)]]
        tapered_tube(o,pts,[.10*(1-i/13)**1.2+.005 for i in range(13)])
    # Refine the finisher into distinct actors and a coherent miniature of the pumpkin.
    for item in old_manifest["groups"]["finisher"]:
        old=bpy.data.objects[item["name"]]
        if "Lantern" in old.name or "Face" in old.name or "WispEye" in old.name:continue
        copy_object(old,"finisher")
    face_mat=material_copy(bpy.data.materials["HHL_MidnightViolet"])
    for i in range(3):
        ghost=next(o for o in groups["finisher"] if o.name==f"HH2_Eclipse_Wisp{i}")
        x,y=1.55*math.cos(i*math.tau/3),1.55*math.sin(i*math.tau/3)
        faceparts=[]
        for j,(cx,cz,rx,rz) in enumerate([(x-.1,1.53,.035,.05),(x+.1,1.53,.035,.05),(x,1.38,.035,.055)]):
            oval=[(cx+rx*math.cos(a*math.tau/12),cz+rz*math.sin(a*math.tau/12)) for a in range(12)]
            faceparts.append(project_patch(f"HH2_TempGhostFace{i}_{j}",oval,ghost,face_mat,"finisher",.018,False))
        merged=merge_material_group(faceparts,f"HH2_Eclipse_WispFace{i}",face_mat,"finisher",Matrix.Identity(4))
        for o in faceparts:
            groups["finisher"].remove(o);bpy.data.objects.remove(o,do_unlink=True)
        tail=next(o for o in groups["finisher"] if o.name==f"HH2_Eclipse_WispTail{i}")
        pts=[(x+.2*(1-t),y-.06*math.sin(t*math.pi),.9-.5*t) for t in [j/12 for j in range(13)]]
        tapered_tube(tail,pts,[.11*(1-j/13)**1.5+.004 for j in range(13)])
    transform=Matrix.Translation((0,0,1.05))@Matrix.Diagonal((.8,.8,.8,1))@Matrix.Translation((0,0,1.05))
    by_material={}
    for o in groups["pumpkin"]:by_material.setdefault(o.data.materials[0],[]).append(o)
    for mat,objects in by_material.items():
        merge_material_group(objects,"HH2_Eclipse_Core_"+mat.name.replace("HH2_",""),mat,"finisher",transform)
    # Recalculate closed-mesh normals; preserve deliberate hard edges on the wing shells.
    all_objects=[o for g in groups.values() for o in g]
    for o in all_objects:
        bm=bmesh.new();bm.from_mesh(o.data)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.normal_update()
        if all(len(e.link_faces)==2 for e in bm.edges) and bm.calc_volume(signed=True)<0:
            bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
        bm.to_mesh(o.data);bm.free();o.data.update()
    bpy.context.view_layer.update()
    # Metadata is sufficient for scale, color, pivots, grouping and subsequent mesh installation.
    def point(v):return [float(x) for x in v]
    def linear_srgb(x):return 12.92*x if x<=.0031308 else 1.055*x**(1/2.4)-.055
    def info(o):
        coords=[v.co for v in o.data.vertices]
        low=Vector(tuple(min(v[a] for v in coords) for a in range(3)));high=Vector(tuple(max(v[a] for v in coords) for a in range(3)))
        mat=o.data.materials[0]
        rgb=[round(max(0,min(1,linear_srgb(c)))*255) for c in mat.diffuse_color[:3]]
        return {"name":o.name,"vertices":len(coords),"triangles":sum(len(p.vertices)-2 for p in o.data.polygons),"min":point(low),"max":point(high),"origin":[0,0,0],"material":mat.name,"color":"#%02X%02X%02X"%tuple(rgb),"neon":"Mint" in mat.name}
    manifest={"version":2,"status":"ready for creator import; not installed or sold","baseGlassy":"pop","releaseCount":24,"studsPerUnit":1,"coordinateMap":"Roblox=(x,z,-y)","glassyHangPoint":[0,0,0],"sourceForward":[0,-1,0],"flyerDeckZ":.33,"flyerHinges":[[-1,0,.05],[1,0,.05]],"groups":{k:[info(o) for o in g] for k,g in groups.items()}}
    export_fbx(all_objects,OUT+"/HOLLOWLIGHT_V2_IMPORT.fbx")
    json.dump(manifest,open(OUT+"/manifest.json","w"),indent=2)
    save_blend_copy(OUT+"/hollowlight_v2.blend")
    shutil.copyfile(ROOT+"/assets/blender/seasonal/hollowlight_v1/HollowlightVFXPrototype.rbxm",OUT+"/HollowlightVFX.rbxm")
    for k in ["pumpkin","flyer","finisher"]:render_icon(groups[k],OUT+"/"+k+"_icon.png",size=512,samples=32,engine="BLENDER_EEVEE")
    rotation=math.atan(1/1.35)
    for o in groups["pumpkin"]:o.rotation_euler.z=rotation
    render_icon(groups["pumpkin"],OUT+"/pumpkin_front_review.png",size=512,samples=32,engine="BLENDER_EEVEE")
    for o in groups["pumpkin"]:o.rotation_euler.z=0
finally:
    bpy.context.window.scene=old_scene
result={"scene":scene.name,"groups":{k:len(v) for k,v in groups.items()},"triangles":sum(x["triangles"] for g in manifest["groups"].values() for x in g),"output":OUT,"originalSceneRestored":bpy.context.scene==old_scene}
