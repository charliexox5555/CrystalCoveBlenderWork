"""Original lobby art; run through Blender MCP. Never edits existing scenes.

build_lobby_v2() creates fresh scenes, export-ready meshes and manifests.
render_lobby_v2() renders the new scenes, restoring the previously active scene.
Saved island transforms are deliberately a snapshot; verify before Studio import.
"""
import bpy
import bmesh
import json
import math
import os
import hashlib
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(os.environ.get('GLASSCLASH_REPO', 'C:/Users/charl/Documents/CrystalCoveBlenderWork'))
OUT = ROOT / 'assets/blender/map/lobby_v2'
COLORS = {'Stone':'C8BC9C','Brick':'BA7052','Copper':'B87E50','Dark':'26374B',
          'Glow':'FFB958','Inset':'654D46','Wood':'694537','Rail':'855439',
          'Cap':'B98A5C','Cyan':'70B4BC','Violet':'9F8DBF','Gold':'E3BF69',
          'Grass':'7CCB5B','Rock':'9787A0'}
MATS = {}
ASSETS = {}
SCENES = {}
FENCE_DATA = {}


def mat(key):
    if key not in MATS:
        m = bpy.data.materials.new('LV2_' + key)
        m.use_nodes = True
        rgb = [int(COLORS[key][i:i+2],16)/255 for i in (0,2,4)]
        linear = tuple(c/12.92 if c <= .04045 else ((c+.055)/1.055)**2.4 for c in rgb)+(1,)
        m.diffuse_color = linear
        p = m.node_tree.nodes.get('Principled BSDF')
        p.inputs['Base Color'].default_value = linear
        p.inputs['Roughness'].default_value = .82
        p.inputs['Specular IOR Level'].default_value = .18
        if key == 'Glow':
            p.inputs['Emission Color'].default_value = linear
            p.inputs['Emission Strength'].default_value = 2
        MATS[key] = m
    return MATS[key]


def scene(name):
    s = bpy.data.scenes.new('LV2_' + name)
    bpy.context.window.scene = s
    s.unit_settings.system = 'NONE'
    s.unit_settings.scale_length = 1
    SCENES[name] = s
    ASSETS[name] = []
    return s


def finish(o, name, key):
    bpy.ops.object.select_all(action='DESELECT')
    o.name = name.replace('.', '_')
    o['AssetMeshName'] = o.name
    o.data.materials.clear()
    o.data.materials.append(mat(key))
    o['StudioColor'] = COLORS[key]
    o['StudioMaterial'] = 'Neon' if key == 'Glow' else 'SmoothPlastic'
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def mesh(name, verts, faces, key):
    d = bpy.data.meshes.new(name)
    d.from_pydata(verts, [], faces)
    d.update()
    o = bpy.data.objects.new(name, d)
    bpy.context.scene.collection.objects.link(o)
    bm = bmesh.new()
    bm.from_mesh(d)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(d)
    bm.free()
    return finish(o, name, key)


def box(name, size, loc, key, bevel=0):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = o.modifiers.new('Chunky bevel', 'BEVEL')
        mod.width, mod.segments = min(bevel, min(size)*.24), 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(o, name, key)


def column(name, r, h, loc, key, r2=None, sides=10):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=r, radius2=r if r2 is None else r2,
                                   depth=h, location=loc)
    return finish(bpy.context.object, name, key)


def arch_piece(name, r0, r1, a0, a1, depth, y, z, key):
    verts=[]
    for yy in (y-depth/2,y+depth/2):
        for rr,aa in ((r0,a0),(r1,a0),(r1,a1),(r0,a1)):
            verts.append((rr*math.cos(aa),yy,z+rr*math.sin(aa)))
    return mesh(name,verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],key)


def lathe(name, profile, key, sides=12, x=0, y=0):
    verts=[(x+r*math.cos(i*math.tau/sides),y+r*math.sin(i*math.tau/sides),z)
           for r,z in profile for i in range(sides)]
    faces=[]
    for j in range(len(profile)-1):
        for i in range(sides):
            a=j*sides+i;b=j*sides+(i+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces += [tuple(reversed(range(sides))),tuple((len(profile)-1)*sides+i for i in range(sides))]
    return mesh(name,verts,faces,key)


def kiln():
    name='Kiln_Furnace';scene(name);o=[]
    o.append(box('Kiln_Base',(11.8,9.4,.65),(0,-.3,.325),'Stone',.22))
    o.append(box('Kiln_Hearth',(9.4,6.8,.65),(0,.7,.975),'Brick',.15))
    for x in (-3.65,3.65):
        o.append(box('Kiln_Side_' + str(x),(2.05,5.1,4.95),(x,1.15,3.65),'Stone',.18))
        o.append(box('Kiln_CornerBand_' + str(x),(.3,5.25,.42),(x*1.24,1.15,3.2),'Copper',.06))
    o.append(box('Kiln_Back',(7.5,.7,5.4),(0,3.55,3.9),'Stone',.18))
    # Actual open mouth: separate jambs and nine closed wedge bricks, no face across it.
    for x in (-2.75,2.75):
        for j in range(3):
            o.append(box('Kiln_Jamb_%s_%s'%(x,j),(1.15,1.1,.95),(x,-1.72,1.75+j*.96),'Brick',.04))
    for i in range(9):
        o.append(arch_piece('Kiln_Arch_%02d'%i,2.18,3.34,i*math.pi/9+.008,
                            (i+1)*math.pi/9-.008,1.12,-1.72,4.05,'Brick'))
    # Rear of the chamber is recessed 2.3 studs, retaining visible depth in the mouth.
    o.append(box('Kiln_ChamberDark',(4.3,.22,3.8),(0,.7,3.2),'Inset'))
    o.append(column('Kiln_MoltenPool',1.58,.15,(0,-.2,1.43),'Glow',sides=12))
    o.append(box('Kiln_ChamberBackGlow',(3.2,.12,2.2),(0,.52,2.9),'Glow',.3))
    # Faceted dome roof with a rear chimney; these remain matte in Studio.
    o.append(lathe('Kiln_Roof',[(4.65,6.6),(4.7,7.15),(3.8,8.15),(2.4,8.65)],'Stone',12,y=1.05))
    o.append(lathe('Kiln_RoofBand',[(4.72,6.72),(4.72,7.02)],'Copper',12,y=1.05))
    o.append(column('Kiln_Chimney',1.05,3.35,(.8,2.05,10.1),'Brick',sides=8))
    o.append(column('Kiln_ChimneyRim',1.28,.38,(.8,2.05,11.92),'Copper',sides=8))
    o.append(column('Kiln_ChimneyDark',.88,.08,(.8,2.05,12.13),'Inset',sides=8))
    # A real cooling/output shelf with raised lips and an inset circular reveal seat.
    o.append(box('Kiln_CoolingTray',(4.9,3.6,.42),(0,-3.35,1.7),'Copper',.12))
    o.append(box('Kiln_CoolingSurface',(4.3,3.15,.16),(0,-3.45,1.97),'Dark',.06))
    for x in (-2.28,2.28):
        o.append(box('Kiln_TrayLip_'+str(x),(.22,3.5,.38),(x,-3.35,2.05),'Copper',.05))
        o.append(box('Kiln_TrayLeg_'+str(x),(.45,.55,1.45),(x,-4.4,.95),'Dark',.06))
    o.append(column('Kiln_RevealSeat',1.13,.18,(0,-4.02,2.12),'Cyan',sides=12))
    o.append(column('Kiln_RevealSeatInset',.9,.06,(0,-4.02,2.24),'Dark',sides=12))
    # Accessible sign/odds display independent from the hot opening.
    o.append(box('Kiln_DisplayPost',(.42,.65,3.2),(5.4,-2.25,2.0),'Dark',.05))
    o.append(box('Kiln_DisplayFrame',(2.4,.7,2.7),(5.25,-2.25,4.25),'Copper',.12))
    o.append(box('Kiln_DisplaySurface',(2.05,.12,2.33),(5.25,-2.66,4.25),'Dark',.04))
    o.append(box('Kiln_HeaderPlaque',(4.4,.35,.85),(0,-3.75,7.9),'Dark',.12))
    ASSETS[name]=o


def board(metric, accent):
    name='Board_' + metric;scene(name);o=[]
    o.append(box(name+'_Foot',(12.2,3.2,.6),(0,0,.3),'Stone',.18))
    o.append(box(name+'_Step',(11.3,2.6,.36),(0,-.15,.78),'Copper',.1))
    for x in (-5.65,5.65):
        o.append(box(name+'_Column_'+str(x),(.9,1.15,9.5),(x,0,5.7),'Stone',.12))
        o.append(box(name+'_ColumnCap_'+str(x),(1.1,1.35,.4),(x,0,10.45),'Copper',.08))
        o.append(box(name+'_BaseCap_'+str(x),(1.1,1.35,.45),(x,0,1.15),'Copper',.08))
    o.append(box(name+'_Display',(10.2,.38,7.8),(0,-.16,6.15),'Dark',.07))
    for z in (2.08,10.22):
        o.append(box(name+'_Crossbar_'+str(z),(12.1,1.05,.45),(0,0,z),'Copper',.1))
    o.append(box(name+'_Header',(10.1,.48,1.05),(0,-.18,10.95),'Stone',.1))
    o.append(box(name+'_HeaderInset',(9.6,.12,.72),(0,-.48,10.95),'Dark',.05))
    o.append(box(name+'_CrestFoot',(2.3,1.2,.36),(0,0,11.65),'Copper',.08))
    # Abstract matte medallions, original silhouettes for each gameplay metric.
    if metric == 'Trophies':
        o.append(column(name+'_Cup',.65,1.05,(0,0,12.36),accent,r2=1.0,sides=8))
        o.append(column(name+'_Stem',.25,.4,(0,0,11.9),'Copper',sides=8))
    elif metric == 'MatchWins':
        for x,z in ((-.6,12.05),(0,12.5),(.6,12.05)):
            o.append(column(name+'_CrownPoint_'+str(x),.43,.9,(x,0,z),accent,r2=.05,sides=4))
    else:
        for x,z in ((-.65,12.12),(0,12.5),(.65,12.1)):
            o.append(column(name+'_Shard_'+str(x),.39,1.25,(x,0,z),accent,r2=.03,sides=4))
    ASSETS[name]=o


def cross(a,b): return a.x*b.y-a.y*b.x


def offset_polygon(points, distance):
    area=sum(cross(p,points[(i+1)%len(points)]) for i,p in enumerate(points))
    sign=1 if area>0 else -1
    out=[]
    for i,p in enumerate(points):
        u=(p-points[i-1]).normalized();v=(points[(i+1)%len(points)]-p).normalized()
        a=p+Vector((-u.y,u.x))*sign*distance
        b=p+Vector((-v.y,v.x))*sign*distance
        out.append((a+b)/2 if abs(cross(u,v))<1e-6 else a+u*(cross(b-a,v)/cross(u,v)))
    return out


def point_on(points, cumulative, t):
    t %= cumulative[-1]
    for i in range(len(points)):
        if t<=cumulative[i+1]+1e-8:
            return points[i].lerp(points[(i+1)%len(points)],(t-cumulative[i])/(cumulative[i+1]-cumulative[i]))
    return points[0]


def paths_for(data):
    # Input Points use Roblox local (X,Z), so invert Z into Blender Y.
    original=[Vector((x,-z)) for x,z in data['Points']]
    rim=offset_polygon(original,.9)
    cumulative=[0]
    for i,p in enumerate(rim):cumulative.append(cumulative[-1]+(rim[(i+1)%len(rim)]-p).length)
    length=cumulative[-1];cuts=[0,length]
    def gate(p):
        return abs(p.x)<5.5-1e-6 and ((data['NorthGate'] and p.y>data['Size'][1]*.3) or
                                              (data['SouthGate'] and p.y<-data['Size'][1]*.3))
    for i,p in enumerate(rim):
        q=rim[(i+1)%len(rim)]
        for x in (-5.5,5.5):
            if abs(q.x-p.x)>1e-8:
                t=(x-p.x)/(q.x-p.x)
                if 0<t<1:
                    h=p.lerp(q,t)
                    if (data['NorthGate'] and h.y>data['Size'][1]*.3) or (data['SouthGate'] and h.y<-data['Size'][1]*.3):
                        cuts.append(cumulative[i]+(q-p).length*t)
    cuts.sort();arcs=[]
    for a,b in zip(cuts,cuts[1:]):
        if not gate(point_on(rim,cumulative,(a+b)/2)):arcs.append((a,b))
    if len(arcs)>1 and arcs[0][0]==0 and arcs[-1][1]==length:
        first=arcs.pop(0);last=arcs.pop();arcs.append((last[0],first[1]+length))
    paths=[]
    for a,b in arcs:
        # Preserve EVERY source corner in the rail; never cut polygon corners with chords.
        values=[a,b]+[c+k*length for k in (0,1) for c in cumulative[:-1] if a<c+k*length<b]
        values=sorted(set(values))
        paths.append([point_on(rim,cumulative,t) for t in values])
    return original,rim,paths


def rail(name, points, h, key='Rail'):
    # One watertight strip per rail per open arc. Mitered cross sections at bends.
    verts=[]
    for i,p in enumerate(points):
        prev=points[max(0,i-1)];nxt=points[min(len(points)-1,i+1)]
        u=(Vector((p.x-prev.x,p.y-prev.y))).normalized() if i else Vector((nxt.x-p.x,nxt.y-p.y)).normalized()
        v=Vector((nxt.x-p.x,nxt.y-p.y)).normalized() if i<len(points)-1 else u
        nu=Vector((-u.y,u.x));nv=Vector((-v.y,v.x))
        bis=(nu+nv).normalized();width=.3/max(.3,bis.dot(nu))
        for side,dz in ((-1,-.3),(1,-.3),(1,.3),(-1,.3)):
            xy=Vector((p.x,p.y))+bis*width*side
            verts.append((xy.x,xy.y,p.z+h+dz))
    faces=[(3,2,1,0)]
    for i in range(len(points)-1):
        for j in range(4):faces.append((4*i+j,4*i+(j+1)%4,4*(i+1)+(j+1)%4,4*(i+1)+j))
    faces.append(tuple(4*(len(points)-1)+j for j in range(4)))
    return mesh(name,verts,faces,key)


def combine(objects,name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    o=bpy.context.object;o.name=name;o['AssetMeshName']=name
    return o


def fence_asset(name,paths,original=None):
    scene(name);rails=[];posts=[];caps=[];post_points=[]
    for n,path in enumerate(paths):
        p3=[Vector(tuple(p)+(0,)) if len(p)==2 else Vector(p) for p in path]
        for h in (.9,2.1):rails.append(rail(name+'_Rail_%s_%s'%(n,h),p3,h))
        # Uniform arclength posts. Rail corners remain exact independently of post positions.
        lengths=[0]
        for a,b in zip(p3,p3[1:]):lengths.append(lengths[-1]+(b-a).length)
        count=max(1,math.ceil(lengths[-1]/5))
        for j in range(count+1):
            if name.startswith('Fence_Bridge') and j in (0,count):
                continue  # Island gate posts already occupy these exact endpoints.
            d=lengths[-1]*j/count
            k=next((k for k in range(len(p3)-1) if lengths[k+1]>=d-1e-7),len(p3)-2)
            p=p3[k].lerp(p3[k+1],(d-lengths[k])/(lengths[k+1]-lengths[k]))
            posts.append(box(name+'_Post',( .86,.86,2.83),p+Vector((0,0,1.415)),'Wood'))
            caps.append(box(name+'_Cap',(1.02,1.02,.17),p+Vector((0,0,2.915)),'Cap'))
            post_points.append(list(p))
    ASSETS[name]=[combine(rails,name+'_Rails'),combine(posts,name+'_Posts'),combine(caps,name+'_Caps')]
    FENCE_DATA[name]={'Paths':[[list(p) for p in path] for path in paths], 'Posts':post_points,
                      'SourceRim':[list(p) for p in original] if original else None}


def build_fences():
    source=json.loads((ROOT/'assets/blender/map/sky/fence_paths.json').read_text())
    centers=[(0,0,0),(0,55,2),(0,105,4),(0,155,6),(0,206,9)]
    gates={};placements={}
    for (island,data),center in zip(source['Islands'].items(),centers):
        original,rim,paths=paths_for(data);name='Fence_'+island
        fence_asset(name,paths,original);placements[name]=list(center)
        gates[island]={}
        for path in paths:
            for p in (path[0],path[-1]):
                if abs(abs(p.x)-5.5)<1e-5:
                    key='North' if p.y>0 else 'South'
                    gates[island].setdefault(key,{})[int(p.x>0)]=Vector((p.x+center[0],p.y+center[1],center[2]))
    keys=list(source['Islands'])
    for i in range(4):
        a=gates[keys[i]]['North'];b=gates[keys[i+1]]['South']
        origin=(a[0]+a[1]+b[0]+b[1])/4
        paths=[]
        for side in (0,1):
            mid=(a[side]+b[side])/2;mid.x=-4.2 if side==0 else 4.2
            paths.append([p-origin for p in (a[side],mid,b[side])])
        name='Fence_Bridge%d'%(i+1);fence_asset(name,paths);placements[name]=list(origin)
    return placements


def bounds(objects):
    points=[o.matrix_world@v.co for o in objects for v in o.data.vertices]
    lo=[min(p[k] for p in points) for k in range(3)];hi=[max(p[k] for p in points) for k in range(3)]
    return {'Min':lo,'Max':hi,'Size':[b-a for a,b in zip(lo,hi)]}


def text(s,copy,loc,size,rot=(math.pi/2,0,0)):
    d=bpy.data.curves.new('PreviewText','FONT');d.body=copy;d.size=size;d.align_x='CENTER';d.align_y='CENTER'
    d.extrude=0
    o=bpy.data.objects.new('PREVIEW_ONLY_'+copy,d);s.collection.objects.link(o)
    o.location=loc;o.rotation_euler=rot;d.materials.append(mat('Stone'))
    return o


def instance(s,asset,loc=(0,0,0),yaw=0):
    result=[]
    for o in ASSETS[asset]:
        dup=o.copy();s.collection.objects.link(dup)
        dup.matrix_world=Matrix.Translation(Vector(loc))@Matrix.Rotation(yaw,4,'Z')
        result.append(dup)
    return result


def setup_render(s,eye,target,scale,path,w=1400,h=1000):
    s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=True
    s.render.resolution_x=w;s.render.resolution_y=h;s.render.resolution_percentage=100
    s.render.image_settings.file_format='PNG';s.render.filepath=str(path)
    s.world=bpy.data.worlds.new('LV2_SoftSky');s.world.use_nodes=True
    s.world.node_tree.nodes['Background'].inputs[0].default_value=(.50,.67,.82,1)
    s.world.node_tree.nodes['Background'].inputs[1].default_value=.6
    s.view_settings.view_transform='AgX'
    d=bpy.data.cameras.new('LV2_Camera');c=bpy.data.objects.new('LV2_Camera',d);s.collection.objects.link(c)
    c.location=eye;c.rotation_euler=(Vector(target)-c.location).to_track_quat('-Z','Y').to_euler()
    d.type='ORTHO';d.ortho_scale=scale;s.camera=c
    for loc,power,size in (((-20,-30,40),22000,25),((25,12,28),16000,20)):
        d=bpy.data.lights.new('LV2_Softbox','AREA');o=bpy.data.objects.new('LV2_Softbox',d);s.collection.objects.link(o)
        o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
        d.energy=power;d.shape='DISK';d.size=size


def previews(placements):
    for key in ('Kiln_Furnace','Board_MatchWins','Board_Shatters','Board_Trophies'):
        s=SCENES[key]
        setup_render(s,(19,-28,18),(0,0,5),22,OUT/(key+'_preview.png'))
        if key=='Kiln_Furnace':text(s,'THE KILN',(0,-3.95,7.9),.48)
        else:
            metric=key.removeprefix('Board_');label={'MatchWins':'MATCH WINS','Shatters':'SHATTERS','Trophies':'TROPHIES'}[metric]
            text(s,label,(0,-.56,10.95),.62)
            text(s,'Clash to make the board!',(0,-.37,6.2),.45)
    s=scene('Plaza_Preview')
    # Context geometry uses exact source rim, no invented rectangle.
    raw=json.loads((ROOT/'assets/blender/map/sky/fence_paths.json').read_text())['Islands']['Isle_Lobby']
    rim=[(x,-z) for x,z in raw['Points']];n=len(rim)
    verts=[(x,y,z) for z in (-1.4,0) for x,y in rim]
    faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh('PREVIEW_ONLY_Grass',verts,faces,'Grass')
    instance(s,'Fence_Isle_Lobby')
    instance(s,'Kiln_Furnace',(-22,11,.05))
    for metric,x in (('MatchWins',-14),('Shatters',14),('Trophies',28)):
        instance(s,'Board_'+metric,(x,-21,.05),math.pi)
        text(s,{'MatchWins':'MATCH WINS','Shatters':'SHATTERS','Trophies':'TROPHIES'}[metric],
             (x,-20.44,11),.62,rot=(math.pi/2,0,math.pi))
    # Central ten-stud route is indicated only in the preview; no new world collision.
    box('PREVIEW_ONLY_Route',(10,46,.025),(0,1,.025),'Stone')
    setup_render(s,(90,105,112),(0,0,0),120,OUT/'plaza_preview.png',1600,1200)
    detail=scene('Fence_Detail_Preview')
    instance(detail,'Fence_Isle_Lobby')
    ground=next(o for o in s.objects if o.name.startswith('PREVIEW_ONLY_Grass')).copy()
    detail.collection.objects.link(ground)
    setup_render(detail,(65,3,19),(44,12,1),25,OUT/'fence_detail_preview.png',1400,1000)
    s=scene('Fence_Row_Preview')
    for name,loc in placements.items():instance(s,name,loc)
    for island,data in json.loads((ROOT/'assets/blender/map/sky/fence_paths.json').read_text())['Islands'].items():
        bpy.context.window.scene=s
        loc=placements['Fence_'+island];rim=[(x+loc[0],-z+loc[1],loc[2]-.03) for x,z in data['Points']]
        mesh('PREVIEW_ONLY_'+island,rim,[tuple(range(len(rim)))],'Grass')
    setup_render(s,(180,-95,260),(0,100,0),295,OUT/'fence_row_preview.png',1600,1200)
    fit_preview_camera(s)


def fit_preview_camera(s):
    bpy.context.view_layer.update()
    c=s.camera;inv=c.matrix_world.inverted()
    points=[inv@(o.matrix_world@v.co) for o in s.objects if o.type=='MESH' for v in o.data.vertices]
    lo=[min(p[k] for p in points) for k in range(2)];hi=[max(p[k] for p in points) for k in range(2)]
    frame=c.data.view_frame(scene=s)
    width=max(p.x for p in frame)-min(p.x for p in frame)
    height=max(p.y for p in frame)-min(p.y for p in frame)
    c.data.ortho_scale*=max((hi[0]-lo[0])/width,(hi[1]-lo[1])/height)*1.1
    c.location+=c.rotation_euler.to_matrix()@Vector(((hi[0]+lo[0])/2,(hi[1]+lo[1])/2,0))


def build_lobby_v2():
    OUT.mkdir(parents=True,exist_ok=True)
    previous=bpy.context.window.scene
    # Snapshot the open scene before adding anything; do not replace/save its current file.
    bpy.data.libraries.write(str(OUT/'open_scene_before.blend'),{previous},fake_user=True,compress=True)
    helper={};exec(compile((ROOT/'tools/blender/glassclash_blender.py').read_text(), 'glassclash_blender.py','exec'),helper)
    manifest={'Status':'Built and exported; not installed in Studio','Units':'1 Blender unit = 1 stud',
              'Coordinates':'Blender (x,y,z) -> Roblox (x,z,-y)',
              'Snapshot':'Saved verified island transforms from handoff; live place not accessed',
              'FenceSourceSHA256':hashlib.sha256((ROOT/'assets/blender/map/sky/fence_paths.json').read_bytes()).hexdigest(),
              'Assets':{}}
    try:
        kiln();board('MatchWins','Cyan');board('Shatters','Violet');board('Trophies','Gold')
        placements=build_fences()
        placements.update({'Kiln_Furnace':[-22,11,.05],'Board_MatchWins':[-14,-21,.05],
                           'Board_Shatters':[14,-21,.05],'Board_Trophies':[28,-21,.05]})
        for name,objects in ASSETS.items():
            if not objects:continue
            bpy.context.window.scene=SCENES[name]
            fbx=OUT/(name+'.fbx');helper['export_fbx'](objects,str(fbx))
            # Save a clean mesh-only isolated source before preview text/lights.
            bpy.data.libraries.write(str(OUT/(name+'.blend')),{SCENES[name]},fake_user=True,compress=True)
            rows=[]
            for o in objects:
                o.data.calc_loop_triangles()
                rows.append({'Name':o.name,'Triangles':len(o.data.loop_triangles),'Vertices':len(o.data.vertices),
                             'Bounds':bounds([o]),'Color':o['StudioColor'],'Material':o['StudioMaterial']})
            loc=placements[name]
            manifest['Assets'][name]={'Meshes':rows,'Bounds':bounds(objects),'PivotBlender':loc,
                                     'PivotRoblox':[loc[0],loc[2],-loc[1]],
                                     'RobloxYawDegrees':180 if name.startswith('Board_') else 0,
                                     'FBX':fbx.name,'Source':name+'.blend'}
        (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
        (OUT/'fence_geometry.json').write_text(json.dumps(FENCE_DATA,indent=2)+'\n')
        previews(placements)
        scenes=set(SCENES.values())
        bpy.data.libraries.write(str(OUT/'lobby_v2_review.blend'),scenes,fake_user=True,compress=True)
        return {'Assets':len(manifest['Assets']),'Meshes':sum(len(x['Meshes']) for x in manifest['Assets'].values()),
                'Triangles':sum(m['Triangles'] for x in manifest['Assets'].values() for m in x['Meshes']),
                'Output':str(OUT)}
    finally:bpy.context.window.scene=previous


def render_lobby_v2(names=None):
    previous=bpy.context.window.scene;done=[]
    try:
        for name in names or ('Kiln_Furnace','Board_MatchWins','Board_Shatters','Board_Trophies','Plaza_Preview','Fence_Row_Preview','Fence_Detail_Preview'):
            s=SCENES[name];bpy.context.window.scene=s
            bpy.ops.render.render(write_still=True);done.append(s.render.filepath)
    finally:bpy.context.window.scene=previous
    return done
