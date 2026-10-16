"""Original seasonal concept sources. Run with Blender MCP; preserve existing scenes."""
import bpy, math, json, os
from mathutils import Vector, Matrix

ROOT = r"C:/Users/charl/Documents/CrystalCoveBlenderWork"
GLASSCLASH_REPO = ROOT
exec(open(ROOT + "/tools/blender/glassclash_blender.py").read())
OUT = ROOT + "/assets/blender/seasonal/hollowlight_v1"
os.makedirs(OUT, exist_ok=True)
assert not bpy.data.scenes.get("Hollowlight_v1"), "Preserve the existing seasonal source scene"
original_scene = bpy.context.window.scene
scene = bpy.data.scenes.new("Hollowlight_v1")
bpy.context.window.scene = scene
scene.unit_settings.system, scene.unit_settings.scale_length = "METRIC", 1

def material(name, color, metal=0, glow=0, glass=0):
    m = bpy.data.materials.new("HHL_" + name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    n = m.node_tree.nodes.get("Principled BSDF")
    n.inputs["Base Color"].default_value = (*color, 1)
    n.inputs["Metallic"].default_value = metal
    n.inputs["Roughness"].default_value = .17 if glass else .27
    n.inputs["Transmission Weight"].default_value = glass
    n.inputs["Emission Color"].default_value = (*color, 1)
    n.inputs["Emission Strength"].default_value = glow
    return m

orange = material("AmberGlass", (1,.24,.025), glass=.32)
gold = material("AntiqueGold", (.72,.39,.075), metal=.7)
purple = material("MidnightViolet", (.11,.028,.22), metal=.28)
mint = material("WispMint", (.22,1,.65), glow=2)
milk = material("MoonGlass", (.67,.9,1), glass=.35)
groups = {"pumpkin": [], "flyer": [], "finisher": []}

def mesh(name, vertices, faces, mat, group, smooth=True):
    d = bpy.data.meshes.new(name)
    d.from_pydata(vertices, [], faces)
    d.update()
    o = bpy.data.objects.new("HHL_" + name, d)
    scene.collection.objects.link(o)
    o.data.materials.append(mat)
    for p in d.polygons: p.use_smooth = smooth
    groups[group].append(o)
    return o

def tube(name, points, radius, mat, group, sides=8):
    verts, faces = [], []
    points = [Vector(p) for p in points]
    for i, p in enumerate(points):
        tangent = (points[min(i+1,len(points)-1)] - points[max(0,i-1)]).normalized()
        axis = tangent.cross(Vector((0,0,1)))
        if axis.length < .01: axis = tangent.cross(Vector((0,1,0)))
        axis.normalize()
        other = tangent.cross(axis).normalized()
        for j in range(sides):
            a = j*math.tau/sides
            verts.append(tuple(p + radius*(math.cos(a)*axis + math.sin(a)*other)))
    for i in range(len(points)-1):
        for j in range(sides):
            a=i*sides+j; b=i*sides+(j+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces += [tuple(reversed(range(sides))), tuple((len(points)-1)*sides+j for j in range(sides))]
    return mesh(name,verts,faces,mat,group)

def pumpkin(name, center, scale, mat, group):
    verts=[(center[0],center[1],center[2]-.87*scale)]
    n, rings = 48, 11
    for j in range(1,rings+1):
        phi=math.pi*j/(rings+1)
        for i in range(n):
            a=math.tau*i/n
            r=math.sin(phi)*(1+.1*math.cos(a*8))*.95*scale
            verts.append((center[0]+math.cos(a)*r,center[1]+math.sin(a)*r,center[2]-.87*math.cos(phi)*scale))
    top=len(verts); verts.append((center[0],center[1],center[2]+.87*scale))
    faces=[]
    for i in range(n): faces.append((0,1+(i+1)%n,1+i))
    for j in range(rings-1):
        for i in range(n):
            a=1+j*n+i; b=1+j*n+(i+1)%n
            faces.append((a,b,b+n,a+n))
    for i in range(n): faces.append((top,1+(rings-1)*n+i,1+(rings-1)*n+(i+1)%n))
    return mesh(name,verts,faces,mat,group)

def loop(name, radius, z, mat, group, x=0, y=0, thickness=.035):
    return tube(name,[(x+radius*math.cos(i*math.tau/48), y+radius*math.sin(i*math.tau/48), z) for i in range(49)],thickness,mat,group)

# Pumpkin: a bright friendly lantern; all glassy parts share the stem hang origin.
body = pumpkin("Pumpkin_Body", (0,0,-1.05), 1, orange, "pumpkin")
tube("Pumpkin_Stem", [(0,0,-.23),(.04,0,-.1),(.12,.03,.04),(0,0,0)], .12, gold, "pumpkin")
tube("Pumpkin_Curl",[(.12,.03,-.08),(.33,.02,.04),(.43,.01,-.04),(.35,0,-.16)],.035,mint,"pumpkin")
for side in (-1,1):
    points=[(side*.16,-.94,-.91),(side*.55,-.83,-.89),(side*.34,-.94,-.64)]
    mesh("Pumpkin_Eye"+str(side),points,[(0,1,2)],mint,"pumpkin",False)
    tube("Pumpkin_EyeRim"+str(side),points+[points[0]],.025,gold,"pumpkin")
smile=[(-.46,-.88,-1.24),(-.3,-1,-1.42),(0,-1.04,-1.5),(.3,-1,-1.42),(.46,-.88,-1.24)]
tube("Pumpkin_Smile",smile,.055,mint,"pumpkin")
for side in (-1,1):
    leaf=[(0,0,-.26),(side*.45,-.1,-.18),(side*.61,0,-.35),(side*.2,.12,-.38)]
    mesh("Pumpkin_Leaf"+str(side),leaf,[(0,1,2,3)],purple,"pumpkin",False)
    tube("Pumpkin_LeafVein"+str(side),[leaf[0],leaf[2]],.025,gold,"pumpkin")

# Flyer: scalloped midnight wings, glowing veins, a polished moon skiff and lantern engines.
deck = pumpkin("Skiff_Hull", (0,0,0),1,purple,"flyer")
deck.data.transform(Matrix.Diagonal((1.12,1.8,.3,1)))
loop("Skiff_SeatRim",.72,.32,gold,"flyer",thickness=.055)
for side in (-1,1):
    wing=[(side*1,-.7,.05),(side*3.55,-.1,.55),(side*2.85,.5,.35),(side*3.05,1.25,.1),(side*2.2,.91,.05),(side*2.05,1.55,-.05),(side*1.5,1.12,-.02),(side*1,1.3,0)]
    w=mesh("Skiff_Wing"+str(side),wing,[tuple(range(len(wing)))],purple,"flyer",False)
    solid=w.modifiers.new("MembraneThickness","SOLIDIFY");solid.thickness=.07
    bpy.context.view_layer.objects.active=w;w.select_set(True)
    bpy.ops.object.modifier_apply(modifier=solid.name);w.select_set(False)
    tube("Skiff_WingRim"+str(side),wing+[wing[0]],.045,gold,"flyer")
    for k in (1,3,5): tube("Skiff_GlowVein"+str(side)+str(k),[wing[0],wing[k]],.025,mint,"flyer")
    pumpkin("Skiff_Lantern"+str(side),(side*.95,-.6,.39),.32,orange,"flyer")
    loop("Skiff_LanternHalo"+str(side),.36,.48,mint,"flyer",x=side*.95,y=-.6,thickness=.025)
    tube("Skiff_Exhaust"+str(side),[(side*.7,1.25,-.05),(side*.75,1.65,-.2),(side*.8,2.05,-.09),(side*.85,2.5,-.3)],.09,mint,"flyer")
tube("Skiff_NoseCrescent",[(-.55,-1.45,.1),(-.35,-1.8,.38),(0,-1.9,.55),(.35,-1.8,.38),(.55,-1.45,.1)],.10,gold,"flyer")

# Finisher components: lantern core, eclipsing halo, three independent ghost wisps and ribbons.
core = pumpkin("Eclipse_Lantern",(0,0,1.05),.8,orange,"finisher")
loop("Eclipse_Halo",2.1,.12,gold,"finisher",thickness=.06)
loop("Eclipse_InnerHalo",1.8,.18,mint,"finisher",thickness=.025)
for i in range(3):
    angle=i*math.tau/3
    x,y=1.55*math.cos(angle),1.55*math.sin(angle)
    ghost=pumpkin("Eclipse_Wisp"+str(i),(x,y,1.5),.42,milk,"finisher")
    ghost.data.transform(Matrix.Translation((x,y,1.5)) @ Matrix.Diagonal((.85,.85,1.65,1)) @ Matrix.Translation((-x,-y,-1.5)))
    tube("Eclipse_WispTail"+str(i),[(x,y,1.1),(x*.88,y*.88,.7),(x*.7,y*.7,.45)],.13,mint,"finisher")
    for j in (-1,1):
        pumpkin("Eclipse_WispEye"+str(i)+str(j),(x+j*.11,y-.34,1.65),.055,purple,"finisher")
    points=[]
    for j in range(30):
        t=j/29; a=angle+t*math.tau*.75; r=2.1*(1-t*.45)
        points.append((r*math.cos(a),r*math.sin(a),.2+t*2.7))
    tube("Eclipse_Spiral"+str(i),points,.035,mint,"finisher")

def export_sources():
    shard_objects=make_shards(body,pieces=16,seed=441)
    for o in shard_objects: o.hide_render=True
    export_fbx([body], OUT+"/pumpkin_body.fbx")
    export_fbx(shard_objects, OUT+"/pumpkin_shards.fbx")
    export_fbx([o for o in groups["pumpkin"] if o!=body],OUT+"/pumpkin_details.fbx")
    export_fbx(groups["flyer"]+groups["finisher"],OUT+"/HOLLOWLIGHT_COSMETICS_IMPORT.fbx")
    manifest={"status":"art prototype; not installed or sold","baseGlassy":"pop","releaseCount":24,"studsPerUnit":1,"glassyHangPoint":[0,0,0],"shards":len(shard_objects),"groups":{}}
    for name,objects in groups.items():
        manifest["groups"][name]=[{"name":o.name,"triangles":sum(len(p.vertices)-2 for p in o.data.polygons)} for o in objects]
    with open(OUT+"/manifest.json","w") as f: json.dump(manifest,f,indent=2)
    bpy.data.libraries.write(OUT+"/hollowlight_v1.blend",{scene},fake_user=True)
    return manifest

try:
    manifest=export_sources()
finally:
    bpy.context.window.scene=original_scene
result={"scene":scene.name,"objects":{k:len(v) for k,v in groups.items()},"shards":manifest["shards"],"output":OUT,"originalSceneRestored":bpy.context.scene==original_scene}
