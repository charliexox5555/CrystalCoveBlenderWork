"""Glass Town / Recycling Yard first environment pass, authored in Blender.

Run through Blender MCP after setting GLASSCLASH_REPO. Preserves every existing
scene. Sources use linked kit meshes; exports merge by colour within small chunks.
No textures, imported libraries, or third-party assets. Studio owns final colours.
"""
import json
import math
import os
import random
from collections import defaultdict

import bpy
from mathutils import Matrix, Vector

ROOT = GLASSCLASH_REPO
OUT = os.path.join(ROOT, "assets", "blender", "map", "first_pass")
os.makedirs(OUT, exist_ok=True)
exec(open(os.path.join(ROOT, "tools", "blender", "glassclash_blender.py"), encoding="utf-8").read())

PALETTE = {
    "grass": "#85AA69", "grass_light": "#A7BD7A", "grass_dark": "#527C58",
    "leaf": "#6D965E", "leaf_light": "#A0BC70", "leaf_dark": "#4F7657",
    "cliff": "#69766B", "rock": "#9BA697", "path": "#DBCFAE",
    "paver": "#E7DEC8", "wood": "#BD9161", "wood_dark": "#795C43",
    "roof": "#4F7D85", "wall": "#F0E5CC", "blue": "#69AEC1",
    "green": "#79AB83", "yellow": "#E4BD66", "metal": "#61797B",
    "dark": "#344F59", "window": "#B5DDE1", "glass_cube": "#88C0AD",
}
MATS = {}
for key, color in PALETTE.items():
    m = bpy.data.materials.new("MapPreview_" + key)
    m.diffuse_color = (*hex_to_rgb(color), 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = m.diffuse_color
    bsdf.inputs["Roughness"].default_value = .88
    MATS[key] = m

def scene(name):
    s = bpy.data.scenes.new(name)
    bpy.context.window.scene = s
    s.unit_settings.system, s.unit_settings.scale_length = "NONE", 1
    return s

def collection(name):
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c

def move_to(obj, col):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    col.objects.link(obj)
    return obj

def tag(obj, color, shape="Box", collision=False):
    obj.data.materials.append(MATS[color])
    obj["map_color"], obj["proxy_shape"], obj["map_collision"] = color, shape, collision
    for p in obj.data.polygons:
        p.use_smooth = False
    return obj

def box(name, pos, size, color, col, angle=0, collision=False):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    o = move_to(bpy.context.object, col)
    o.name = name
    # Bake dimensions into geometry, retain location/rotation for linked instances.
    for v in o.data.vertices:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    o.rotation_euler.z = angle
    return tag(o, color, "Box", collision)

def cylinder(name, pos, radius, depth, color, col, vertices=8, collision=False):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=pos)
    o = move_to(bpy.context.object, col)
    o.name = name
    return tag(o, color, "Cylinder", collision)

def ico(name, pos, size, color, col):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=pos)
    o = move_to(bpy.context.object, col)
    o.name = name
    for v in o.data.vertices:
        v.co.x *= size[0] / 2
        v.co.y *= size[1] / 2
        v.co.z *= size[2] / 2
    return tag(o, color, "Ball")

kit_scene = scene("GC_MapKit_FirstPass")
KIT = {}
def start(name):
    c = collection("Kit_" + name)
    KIT[name] = c
    return c

for color in ("blue", "green", "yellow"):
    c = start("bin_" + color)
    box("BinBody", (0, 0, 2.3), (3.6, 3.2, 4.3), color, c)
    box("BinLid", (0, 0, 4.55), (3.9, 3.5, .5), "dark", c)
    box("LidSlot", (0, -.75, 4.84), (2.1, .5, .08), "metal", c)
    box("Handle", (0, 1.75, 4.05), (2.2, .32, .35), "metal", c)
    for x in (-1.35, 1.35):
        wheel = cylinder("Wheel", (x, 1.25, .55), .5, .35, "dark", c)
        wheel.rotation_euler.y = math.pi / 2
    # Simple three-slash sorting symbol, original geometry rather than a decal.
    for x in (-.7, 0, .7):
        box("SortMark", (x, -1.63, 2.55), (.3, .08, 1.05), "wall", c, -.35)

c = start("crate")
for x in (-2.6, 2.6):
    for y in (-2.1, 2.1):
        box("CrateCorner", (x, y, 1.65), (.45, .45, 3.3), "wood_dark", c)
for z in (.5, 1.6, 2.7):
    for y in (-2.2, 2.2):
        box("CrateSlat", (0, y, z), (5.6, .35, .7), "wood", c)
    for x in (-2.7, 2.7):
        box("CrateSlat", (x, 0, z), (.35, 4.6, .7), "wood", c)
box("CrateBottom", (0, 0, .15), (5.6, 4.6, .3), "wood_dark", c)

c = start("pallet")
for x in (-2.3, 0, 2.3):
    box("PalletRunner", (x, 0, .35), (.6, 5.5, .7), "wood_dark", c)
for y in (-2.3, -1.15, 0, 1.15, 2.3):
    box("PalletPlank", (0, y, .85), (6.2, .85, .3), "wood", c)

c = start("bottle_bank")
cylinder("BankBase", (0, 0, .65), 4.5, 1.3, "dark", c, 12)
cylinder("BankBody", (0, 0, 3.7), 4.1, 5, "green", c, 12)
bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=4.1, radius2=2.2, depth=2, location=(0, 0, 7.2))
o = move_to(bpy.context.object, c); o.name = "BankDome"; tag(o, "green", "Ball")
for x in (-1.5, 1.5):
    box("BankOpening", (x, -4.02, 4.8), (1.65, .25, 1.5), "dark", c)
box("BankLabel", (0, -4.18, 2.9), (3.6, .2, .7), "wall", c)

c = start("conveyor")
box("BeltFrame", (0, 0, 2.9), (5.8, 17, .8), "metal", c)
box("Belt", (0, 0, 3.36), (4.6, 16, .18), "dark", c)
for y in (-6, 6):
    for x in (-2.1, 2.1):
        box("ConveyorLeg", (x, y, 1.35), (.6, .6, 2.7), "metal", c)
for y in range(-7, 8, 2):
    box("BeltRib", (0, y, 3.5), (4.55, .2, .18), "rock", c)
for x in (-2.7, 2.7):
    box("ConveyorRail", (x, 0, 3.85), (.25, 17, .35), "yellow", c)

c = start("tree")
cylinder("TreeTrunk", (0, 0, 4), .85, 8, "wood_dark", c)
ico("TreeCrown", (0, 0, 10), (13, 11, 11), "leaf", c)
ico("TreeCrownLight", (-3, -1, 11), (9, 9, 8), "leaf_light", c)
ico("TreeCrownDark", (3, 1.8, 9), (8, 8, 8), "leaf_dark", c)
c = start("rock")
ico("Rock", (0, 0, 1.4), (6, 4.5, 3.4), "rock", c)
c = start("bush")
ico("Bush", (0, 0, 1.9), (8, 6, 4.3), "grass_dark", c)
c = start("grass_tuft")
verts = [(-.8, 0, 0), (0, 0, 2), (.35, 0, 0), (0, -.8, 0), (0, .2, 1.6), (0, .6, 0)]
mesh = bpy.data.meshes.new("TuftMesh"); mesh.from_pydata(verts, [], [(0, 1, 2), (3, 4, 5)])
o = bpy.data.objects.new("Tuft", mesh); c.objects.link(o); tag(o, "grass_light")

c = start("fence")
for x in (-5, 5):
    box("FencePost", (x, 0, 2.4), (.65, .65, 4.8), "wood_dark", c)
for z in (1.6, 3.5):
    box("FenceRail", (0, 0, z), (10.5, .35, .4), "wood", c)
c = start("bench")
box("Seat", (0, 0, 2.2), (8, 2.3, .5), "wood", c)
box("Back", (0, .85, 3.8), (8, .35, 1.6), "wood", c)
for x in (-2.8, 2.8):
    box("BenchFoot", (x, 0, 1), (.7, 2, 2), "metal", c)
c = start("lamp")
cylinder("LampPost", (0, 0, 7), .3, 14, "metal", c)
box("LampHead", (0, 0, 14), (2, 2, .7), "yellow", c)
box("LampCap", (0, 0, 14.5), (2.5, 2.5, .35), "dark", c)
c = start("repair_bench")
box("RepairTop", (0, 0, 3.5), (10, 5.5, .7), "wood", c)
box("RepairMat", (0, -.2, 3.92), (6, 3.4, .12), "green", c)
for x in (-3.8, 3.8):
    box("RepairLeg", (x, 0, 1.6), (.7, 4.2, 3.2), "wood_dark", c)
box("ToolHandle", (3.5, 0, 4.1), (.35, 2, .3), "wood_dark", c)
box("ToolHead", (3.5, .8, 4.35), (1.5, .7, .7), "metal", c)
for x in (-4.5, 4.5):
    box("RepairSignPost", (x, 2.5, 5), (.4, .4, 10), "wood_dark", c)
box("RepairSign", (0, 2.5, 9), (9.5, .5, 2.7), "green", c)

c = start("shop")
box("ShopShell", (0, 0, 6.5), (28, 20, 13), "wall", c)
box("Door", (0, -10.1, 4.5), (6, .25, 9), "wood_dark", c)
for x in (-9, 9):
    box("Window", (x, -10.2, 6), (6, .25, 5), "window", c)
    box("Sill", (x, -10.5, 3.3), (6.8, .8, .45), "wood", c)
for x in (-14.1, 14.1):
    box("WallTrim", (x, 0, 6.5), (.5, 20.5, 13), "wood", c)
# Closed pitched roof mesh; shape stays editable in the kit source.
v = [(-16,-12,13),(16,-12,13),(16,12,13),(-16,12,13),(-16,0,19),(16,0,19)]
f = [(0,3,2,1),(0,1,5,4),(4,5,2,3),(0,4,3),(1,2,5)]
mesh=bpy.data.meshes.new("PitchedRoof"); mesh.from_pydata(v,[],f)
o=bpy.data.objects.new("Roof",mesh); c.objects.link(o); tag(o,"roof")
box("ShopSign", (0,-11,11), (19,.7,2.5), "dark", c)

# Keep kit previews spread out, but reset to local origins for the saved library.
bpy.context.view_layer.update()
save_blend_copy(os.path.join(OUT, "kit_recycling_yard.blend"))

layout = scene("GC_GlassTown_RecyclingYard_FirstPass")
CHUNKS = {}
def chunk(name):
    c = collection(name); CHUNKS[name] = c; return c

def place(kind, pos, col, angle=0, scale=1):
    transform = Matrix.Translation(pos) @ Matrix.Rotation(angle, 4, "Z") @ Matrix.Scale(scale,4)
    for source in KIT[kind].objects:
        o = source.copy()  # linked mesh: revisions to kit data propagate to instances
        col.objects.link(o)
        o.name = col.name + "_" + kind + "_" + source.name
        o.matrix_world = transform @ source.matrix_world
        o["kit_piece"] = kind

MARKERS = []
def marker(kind, name, pos, **attrs):
    MARKERS.append(dict(kind=kind, name=name, position=[pos[0],pos[2],-pos[1]], **attrs))

town = chunk("glass_town")
box("TownGround", (0,0,-3.25), (320,320,6.5), "grass", town, collision=True)
cylinder("PlazaOuter", (0,0,.08), 62, .16, "path", town, 16, True)
cylinder("PlazaInner", (0,0,.18), 45, .15, "paver", town, 16, True)
box("SpawnWalk", (0,-102,.12), (24,116,.24), "path", town, collision=True)
box("GateWalk", (0,105,.12), (24,110,.24), "path", town, collision=True)
for x in (-98,98):
    box("ShopWalk", (x/2,0,.12), (98,18,.24), "path", town, collision=True)
marker("Spawn", "GlassTownSpawn", (0,-122,1))
marker("Stand", "practice", (0,0,.4), active=True)
for x,y in [(-62,-48),(62,-48),(-62,48),(62,48)]:
    cylinder("PvpPad",(x,y,.12),19,.24,"path",town,8,True)
    marker("Stand","pvp_"+str(len(MARKERS)),(x,y,.4),active=False)

# Champion sight line stays open: low podium between spawn and central arena.
cylinder("ChampionBase", (0,-61,1), 7, 2, "wood_dark", town, 8)
cylinder("ChampionTop", (0,-61,2.4), 5.8, .8, "yellow", town, 8)
marker("Label", "CHAMPION", (0,-61,5.5), subtitle="Future champion display")
for x,y,label,rot in [(-108,10,"CRATE SHOP",-math.pi/2),(108,10,"COSMETICS",math.pi/2)]:
    place("shop",(x,y,0),town,rot)
    marker("Label",label,(x,y,22),subtitle="Planned shop")
place("repair_bench",(94,-58,0),town,math.pi/2)
marker("Label","REPAIR",(94,-58,12),subtitle="Planned repair stop")
for x,y,label in [(-100,-62,"DAILY / CODES"),(-100,67,"LEADERBOARDS")]:
    box("BoardLeg",(x-7,y,5),(.6,.6,10),"wood_dark",town)
    box("BoardLeg",(x+7,y,5),(.6,.6,10),"wood_dark",town)
    box("Board",(x,y,9),(16,1,7),"dark",town)
    marker("Label",label,(x,y-1,9),subtitle="Planned board")
box("BracketBoard",(0,37,8),(23,1,11),"dark",town)
for x in (-10,10): box("BracketPost",(x,37,5),(.7,.7,10),"wood_dark",town)
marker("Label","GLASS CLASH",(0,36.3,10),subtitle="Tournament bracket · future")
for x in (-15,15):
    box("GatePost",(x,154,8),(2,2,16),"wood_dark",town)
    cylinder("GateCap",(x,154,16.5),1.5,1,"yellow",town)
box("YardGateSign",(0,154,14),(29,1,4),"green",town)
marker("Label","RECYCLING YARD",(0,153.3,14),subtitle="Route 1")

rng=random.Random(231)
for x in (-137,137):
    for y in range(-132,148,32):
        place("tree",(x+rng.uniform(-5,5),y,0),town,scale=rng.uniform(.9,1.4))
        if y%3: place("bush",(x*.9,y+10,0),town,scale=1.2)
for x in (-28,28):
    for y in (-125,-88,90,124): place("lamp",(x,y,0),town)
for x,y,a in [(-38,-83,0),(38,-83,0),(-40,85,math.pi),(40,85,math.pi)]: place("bench",(x,y,0),town,a)
for x in (-123,-111,-99): place("bin_"+("blue" if x==-123 else "green" if x==-111 else "yellow"),(x,40,0),town)

# A 575-stud winding centre line + final approach is about 600 studs / 38 sec.
PATH=[(0,160),(-42,205),(-42,250),(38,295),(48,345),(-32,395),(-42,445),(25,495),(25,545),(0,585),(0,610)]
DIST=[0]
for a,b in zip(PATH,PATH[1:]): DIST.append(DIST[-1]+math.dist(a,b))
def path_at(d):
    for i in range(len(PATH)-1):
        if d<=DIST[i+1]:
            a,b=Vector(PATH[i]),Vector(PATH[i+1]); t=(d-DIST[i])/(DIST[i+1]-DIST[i]); direction=(b-a).normalized()
            return a.lerp(b,t),Vector((-direction.y,direction.x))
    return Vector(PATH[-1]),Vector((-1,0))

areas=[]
for i in range(6):
    c=chunk("yard_"+str(i+1).zfill(2)); areas.append(c)
    # Exact shared edges avoid coplanar overlap artifacts in both renderers.
    box("YardGround",(0,199+i*78,-3.25),(240,78,6.5),"grass",c,collision=True)
for i,(a,b) in enumerate(zip(PATH,PATH[1:])):
    a,b=Vector(a),Vector(b); m=(a+b)/2; d=b-a
    c=areas[min(5,int((m.y-160)/78))]
    box("Path",(m.x,m.y,.12),(18,d.length+1,.24),"path",c,-math.atan2(d.x,d.y),True)
    cylinder("PathJoin",(*a,.14),9,.28,"path",c,12,True)
    for side in (-1,1):
        n=Vector((-d.y,d.x)).normalized()*10*side
        box("PathCurb",(m.x+n.x,m.y+n.y,.25),(1,d.length-3,.5),"paver",c,-math.atan2(d.x,d.y))

stops=[("kevin",65,-1),("wild_a",120,1),("sam",193,-1),("cora",258,1),("repair",315,-1),("wild_b",380,1),("jo",445,-1),("bo",510,1)]
for name,d,side in stops:
    p,n=path_at(d); center=p+n*side*34
    c=areas[min(5,int((p.y-160)/78))]
    radius=26 if name.startswith("wild") else 22
    cylinder("Clearing_"+name,(*center,.1),radius,.2,"grass_light" if name.startswith("wild") else "path",c,12,True)
    connector=(center-p).normalized(); mid=(center+p)/2
    box("ClearingPath_"+name,(*mid,.15),(14,34,.3),"path",c,-math.atan2(connector.x,connector.y),True)
    if name.startswith("wild"):
        marker("WildRegion",name,(*center,2),zone="recycling_yard",size=[40,4,40])
        marker("Label","WILD GLASSIES",(*center,10),subtitle="Future spawn area")
        for a in range(6):
            theta=a*math.tau/6
            place("crate",(center.x+math.cos(theta)*23,center.y+math.sin(theta)*23,0),c,theta)
        place("bottle_bank",(center.x+24,center.y+7,0),c)
    elif name=="repair":
        place("repair_bench",(*center,0),c)
        marker("Repair", "YardRepair",(*center,1),zone="recycling_yard")
        marker("Label","REPAIR BENCH",(*center,12),subtitle="Free repairs · planned")
        place("bench",(center.x+12,center.y+4,0),c,math.pi/2)
    else:
        marker("Stand",name,(*center,.4),active=False)
        marker("Trainer",name,(center.x+17,center.y,1),zone="recycling_yard")
        marker("Label",name.upper(),(center.x+17,center.y,9),subtitle="Trainer placement")
        place("pallet",(center.x-17,center.y+16,0),c)
        place("crate",(center.x-17,center.y+16,1),c)

boss=chunk("yard_rusty")
box("RustyGround",(0,651,-3.25),(240,46,6.5),"grass",boss,collision=True)
cylinder("RustyPlatform",(0,610,.35),29,.7,"glass_cube",boss,8,True)
marker("Stand","rusty",(0,610,1.1),active=False)
marker("Trainer","rusty",(20,610,1),zone="recycling_yard",boss=True)
marker("Label","RUSTY'S ARENA",(0,642,20),subtitle="Shelf Champion")
for x in (-32,32):
    place("conveyor",(x,614,0),boss)
    for y in (604,614,624): place("crate",(x,y,3.7),boss)
for x in (-16,16): box("BossSignPost",(x,642,10),(1,1,20),"wood_dark",boss)
box("BossSign",(0,642,18),(35,1,6),"green",boss)
for x in (-12,12): box("FutureGatePost",(x,665,7),(1.5,1.5,14),"metal",boss)
box("FutureGate",(0,665,5),(23,1,10),"metal",boss,collision=True)
marker("Label","NEXT ZONE",(0,664,9),subtitle="Coming later")

# Deliberate edge dressing leaves path and arenas clear; no random collision traps.
for c in areas+[boss]:
    y=197+areas.index(c)*78 if c in areas else 628
    for side in (-1,1):
        for offset in (-28,0,28):
            x=side*rng.uniform(89,113)
            place("tree",(x,y+offset,0),c,scale=rng.uniform(.95,1.6))
            place("rock",(x-side*7,y+offset+10,0),c,scale=rng.uniform(.8,1.7))
        for offset in (-27,-16,0,16,27):
            place("fence",(side*117,y+offset,0),c,math.pi/2)
        for j in range(5):
            place("grass_tuft",(side*rng.uniform(65,100),y+rng.uniform(-33,33),0),c,scale=rng.uniform(.7,1.5))
    for j in range(3):
        place("bin_"+["blue","green","yellow"][j],(-78+j*5,y+22,0),c)
    place("pallet",(75,y-23,0),c)
    place("crate",(75,y-23,1),c)

# Approved stand is a preview dependency only; reuse Studio's approved template.
stand_path=os.path.join(ROOT,"assets","blender","map","clash_stand.blend")
with bpy.data.libraries.load(stand_path,link=False) as (source,target):
    target.scenes=[source.scenes[0]]
stand_source=target.scenes[0]
# Loaded scenes have unevaluated identity world matrices until their graph updates.
bpy.context.window.scene=stand_source
bpy.context.view_layer.update()
bpy.context.window.scene=layout
stands=collection("ApprovedStandPreview")
for m in MARKERS:
    if m["kind"]!="Stand": continue
    x,z,ny=m["position"]; y=-ny
    for src in stand_source.objects:
        if src.type!="MESH": continue
        o=src.copy(); stands.objects.link(o)
        o.matrix_world=Matrix.Translation((x,y,z)) @ src.matrix_world

bpy.context.view_layer.update()
# Studio walk-test proxies retain authoring transforms; they are explicitly temporary.
proxy=[]
for cname,c in CHUNKS.items():
    for o in c.objects:
        if o.type!="MESH": continue
        loc,rot,scale=o.matrix_world.decompose()
        corners=[Vector(v) for v in o.bound_box]
        lo=Vector(tuple(min(v[k] for v in corners) for k in range(3)))
        hi=Vector(tuple(max(v[k] for v in corners) for k in range(3)))
        center=o.matrix_world @ ((lo+hi)/2)
        size=hi-lo
        proxy.append(dict(name=o.name,chunk=cname,color=PALETTE[o["map_color"]],
            shape=o.get("proxy_shape","Box"),position=[center.x,center.z,-center.y],
            size=[abs(size.x*scale.x),abs(size.z*scale.z),abs(size.y*scale.y)],
            yaw=rot.to_euler().z,collision=bool(o.get("map_collision",False))))

world=bpy.data.worlds.new("MapPreviewWorld"); layout.world=world; world.use_nodes=True
world.node_tree.nodes["Background"].inputs[0].default_value=(.55,.68,.82,1)
world.node_tree.nodes["Background"].inputs[1].default_value=.65
ld=bpy.data.lights.new("MapSun","SUN"); ld.energy=2.4; ld.angle=.22
sun=bpy.data.objects.new("MapSun",ld); layout.collection.objects.link(sun); sun.rotation_euler=(.45,-.5,-.4)
camdata=bpy.data.cameras.new("MapOverviewCamera"); cam=bpy.data.objects.new("MapOverviewCamera",camdata); layout.collection.objects.link(cam)
layout.camera=cam; camdata.type="ORTHO"; camdata.ortho_scale=910; camdata.clip_end=5000
cam.location=(610,-490,850); target=Vector((0,230,0)); cam.rotation_euler=(target-Vector(cam.location)).to_track_quat("-Z","Y").to_euler()
layout.render.engine="CYCLES"; layout.cycles.samples=24
layout.render.resolution_x=1600; layout.render.resolution_y=1200; layout.render.resolution_percentage=100
layout.view_settings.view_transform="Standard"
save_blend_copy(os.path.join(OUT,"layout_recycling_yard.blend"))

EXPORTS=[]
def export_chunk(cname):
    c=CHUNKS[cname]
    groups=defaultdict(list)
    for o in c.objects:
        if o.type=="MESH": groups[o["map_color"]].append(o)
    temp=bpy.data.collections.new("Export_"+cname); layout.collection.children.link(temp)
    meshes=[]
    for key,objects in groups.items():
        verts=[]; faces=[]
        for o in objects:
            offset=len(verts); verts.extend([o.matrix_world @ v.co for v in o.data.vertices])
            faces.extend([tuple(offset+i for i in p.vertices) for p in o.data.polygons])
        mesh=bpy.data.meshes.new(cname+"_"+key); mesh.from_pydata(verts,[],faces); mesh.update()
        obj=bpy.data.objects.new(cname+"_"+key,mesh); temp.objects.link(obj); tag(obj,key)
        mesh.calc_loop_triangles()
        assert len(mesh.loop_triangles)<8000,(obj.name,len(mesh.loop_triangles))
        meshes.append(obj)
    # Geometry is already baked in world coordinates; transform_apply is unnecessary.
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes: o.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0]
    path=os.path.join(OUT,"layout_"+cname+".fbx")
    bpy.ops.export_scene.fbx(filepath=path,use_selection=True,object_types={"MESH"},
        apply_unit_scale=True,axis_forward="-Z",axis_up="Y",bake_space_transform=True,
        use_triangles=True,mesh_smooth_type="FACE",add_leaf_bones=False,use_custom_props=True)
    parts=[]
    for o in meshes:
        lo=Vector(tuple(min(v.co[k] for v in o.data.vertices) for k in range(3)))
        hi=Vector(tuple(max(v.co[k] for v in o.data.vertices) for k in range(3)))
        center=(lo+hi)/2; size=hi-lo
        parts.append(dict(name=o.name,color=PALETTE[o["map_color"]],
            position=[center.x,center.z,-center.y],size=[size.x,size.z,size.y]))
    EXPORTS.append(dict(chunk=cname,file=os.path.basename(path),meshes=len(meshes),parts=parts,
        triangles=sum(len(o.data.loop_triangles) for o in meshes)))
    # Export scratch data is ours; keep it out of the saved editable layout.
    for o in meshes: bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.collections.remove(temp)

for cname in CHUNKS: export_chunk(cname)
manifest=dict(version=1,units="1 Blender unit = 1 stud",routeLength=DIST[-1],pathWidth=18,
    path=[[x,.4,-y] for x,y in PATH],markers=MARKERS,proxies=proxy,exports=EXPORTS,
    note="FBX visual import pending. Native Parts are temporary layout/walking proxies; no gameplay trainers or shops yet.")
with open(os.path.join(OUT,"manifest.json"),"w",encoding="utf-8") as f: json.dump(manifest,f,separators=(",",":"))
result={"pathLength":DIST[-1],"kitPieces":len(KIT),"sourceObjects":len(proxy),"chunks":EXPORTS,"markers":len(MARKERS),"folder":OUT}
