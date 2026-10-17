"""Kilnport production kit/layout. Run through Blender MCP; no external assets.

All anchors come from village_layout.py. Art geometry is generated locally in
base-centred kit meshes; assembly reuses those meshes as linked duplicates.
"""
import bpy, bmesh, math, random, os, sys, json, hashlib
from pathlib import Path
from collections import defaultdict
from mathutils import Vector, Matrix
from mathutils.geometry import delaunay_2d_cdt

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/map'))
import village_layout as L
OUT = ROOT / 'assets/blender/map/kilnport'
RENDERS = ROOT / 'docs/art/map_renders'
OUT.mkdir(parents=True, exist_ok=True)
RENDERS.mkdir(parents=True, exist_ok=True)
RNG = random.Random(241)
KIT = {}
VARIANTS = {}
CONVEYORS=[((-315,-248),(-284,-278)),((-165,-279),(-65,-279)),((-42,-264),(38,-264)),((118,-270),(118,-303))]
ANCHORS = []
MATS = {}
PALETTE = {
    'cream':'EAD8B6','trim':'FFF0CD','wood':'AD713F','woodlight':'D6A25A',
    'wooddark':'674630','brick':'AC5540','terra':'BB5F46','blue':'437B9A',
    'greenroof':'4B8870','purple':'7C68AD','stone':'C7B997','rock':'7A8790',
    'rocklight':'A7ADAA','rockdark':'626E7B','grass':'7DA452','grasslight':'91B762',
    'grassdark':'6B954B','pine':'37745B','pine2':'4D9369','leaf':'73A352',
    'leaflight':'98BC62','iron':'374E5C','ironlight':'738894','navy':'233D50',
    'gold':'E5B655','window':'FFD48A','glow':'FF8B39','glass':'76DAE5',
    'glassgreen':'54BCA0','glassamber':'E0AA48','glassblue':'549FD4','glassclear':'C3E8E1',
    'red':'D6765B','white':'F7EBCF','sea':'478EAA','sand':'E1C997',
    'binblue':'548BB6','bingreen':'5FA277','binyellow':'E4B84F','flower':'E6A7BB','lampglass':'FFE1A3',
}
TILES = {'wood':0,'woodlight':1,'brick':2,'stone':3,'terra':4,'blue':5,'greenroof':6,'rock':7,'purple':8,'wooddark':9}

def rgb(h):
    v=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in v)

def atlas():
    import numpy as np
    n=512; a=np.ones((n,n,4),dtype=np.float32)
    rr=random.Random(3)
    for key,idx in TILES.items():
        base=[int(PALETTE[key][i:i+2],16)/255 for i in (0,2,4)]
        ox=(idx%4)*128; oy=(idx//4)*128
        for y in range(128):
            for x in range(128):
                if key in ('brick','stone'):
                    row=y//24; xx=(x+(row%2)*20)%40; yy=y%24
                    mortar=xx<2 or yy<2
                    shade=.78 if mortar else (1+(((x+(row%2)*20)//40*7+row*3)%9-4)*.016)
                    if yy==3 or xx==3: shade+=.07
                elif key in ('terra','blue','greenroof','purple'):
                    row=y//32; xx=(x+(row%2)*16)%32; yy=y%32
                    shade=.70 if yy<2 or xx<2 else 1.02-.13*yy/32
                    if yy==3: shade=1.10
                elif key=='rock':
                    shade=.86 if (y+int(3*math.sin(x/23)))%30<3 else 1+.055*math.sin(y/15)
                else:
                    shade=.72 if x%32<2 else 1+.04*math.sin(y/9+x*.8)+.025*math.sin(y/3+x*.4)
                shade+=rr.uniform(-.012,.012)
                a[oy+y,ox+x,:3]=[min(1,c*shade) for c in base]
    im=bpy.data.images.new('Kilnport_512_Atlas',width=n,height=n)
    im.pixels.foreach_set(a.ravel()); im.filepath_raw=str(OUT/'kilnport_atlas.png'); im.file_format='PNG'; im.save(); im.pack()
    stone=bpy.data.images.new('Kilnport_Cobble_256',width=256,height=256)
    stone.pixels.foreach_set(np.tile(a[0:128,384:512,:],(2,2,1)).ravel());stone.filepath_raw=str(OUT/'kilnport_cobble.png');stone.file_format='PNG';stone.save();stone.pack()
    return im

def materials():
    im=atlas()
    for k,h in PALETTE.items():
        m=bpy.data.materials.new('KP_'+k); m.diffuse_color=(*rgb(h),1); m.use_nodes=True
        p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*rgb(h),1)
        p.inputs['Roughness'].default_value=.86
        p.inputs['Specular IOR Level'].default_value=.22
        if k in TILES:
            tex=m.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=bpy.data.images['Kilnport_Cobble_256'] if k=='stone' else im; tex.interpolation='Linear'
            m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
        if k.startswith('glass'):
            p.inputs['Roughness'].default_value=.18; p.inputs['Metallic'].default_value=.22
            p.inputs['Coat Weight'].default_value=.65
        if k in ('window','glow','glass','lampglass'):
            p.inputs['Emission Color'].default_value=(*rgb(h),1)
            p.inputs['Emission Strength'].default_value={'window':.6,'glow':2.2,'glass':.32,'lampglass':.9}[k]
        if k=='lampglass':p.inputs['Roughness'].default_value=.18;p.inputs['Coat Weight'].default_value=.6
        m['studio_color']=h; m['studio_material']='Neon' if k in ('window','glow') else ('Glass' if k.startswith('glass') else 'SmoothPlastic')
        MATS[k]=m

class Geo:
    def __init__(self): self.parts=defaultdict(lambda:[[],[]])
    def mesh(self,verts,faces,mat):
        if mat=='brick':
            # Keep masonry at a readable scale without extra texture files.
            vv=[];ff=[]
            for face in faces:
                if len(face)!=4:
                    k=len(vv);vv.extend(verts[j] for j in face);ff.append(tuple(range(k,len(vv))));continue
                a,b,c,d=[Vector(verts[j]) for j in face];nu=max(1,math.ceil((b-a).length/8));nv=max(1,math.ceil((d-a).length/8))
                for u in range(nu):
                    for w in range(nv):
                        k=len(vv)
                        for uu,ww in ((u,w),(u+1,w),(u+1,w+1),(u,w+1)):vv.append(tuple(a.lerp(b,uu/nu).lerp(d.lerp(c,uu/nu),ww/nv)))
                        ff.append((k,k+1,k+2,k+3))
            verts,faces=vv,ff
        v,f=self.parts[mat]; n=len(v); v.extend(verts); f.extend([tuple(n+i for i in q) for q in faces])
    def box(self,c,s,mat,rot=0):
        x,y,z=c; w,d,h=[a/2 for a in s]; ca,sa=math.cos(rot),math.sin(rot)
        vs=[(x+xx*ca-yy*sa,y+xx*sa+yy*ca,z+zz) for xx,yy,zz in [(-w,-d,-h),(w,-d,-h),(w,d,-h),(-w,d,-h),(-w,-d,h),(w,-d,h),(w,d,h),(-w,d,h)]]
        self.mesh(vs,[(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)],mat)
    def cyl(self,c,r,h,mat,n=12,rt=None):
        rt=r if rt is None else rt; x,y,z=c
        v=[(x+rr*math.cos(i*math.tau/n),y+rr*math.sin(i*math.tau/n),zz) for rr,zz in ((r,z),(rt,z+h)) for i in range(n)]
        f=[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        self.mesh(v,f,mat)
    def beam(self,a,b,w,d,mat):
        a,b=Vector(a),Vector(b); z=(b-a).normalized(); q=z.to_track_quat('Z','Y').to_matrix(); mid=(a+b)/2
        vs=[tuple(mid+q@Vector((x*w/2,y*d/2,zz*(b-a).length/2))) for x,y,zz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
        self.mesh(vs,[(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)],mat)
    def ico(self,c,s,mat,seed=0,sub=1):
        bm=bmesh.new(); bmesh.ops.create_icosphere(bm,subdivisions=sub,radius=1)
        bm.verts.ensure_lookup_table(); bm.verts.index_update(); rr=random.Random(seed)
        v=[tuple(c[j]+a.co[j]*s[j]*(1+rr.uniform(-.1,.1)) for j in range(3)) for a in bm.verts]
        f=[tuple(a.index for a in p.verts) for p in bm.faces]; bm.free(); self.mesh(v,f,mat)
    def roof(self,w,d,z,h,mat):
        w/=2; d/=2
        self.mesh([(-w,-d,z),(w,-d,z),(w,d,z),(-w,d,z),(-w,0,z+h),(w,0,z+h)],[(0,1,5,4),(3,4,5,2),(0,4,3),(1,2,5),(0,3,2,1)],mat)
    def ring(self,ri,ro,z,h,mat,n=64,start=0,end=math.tau):
        v=[]
        for i in range(n+1):
            a=start+(end-start)*i/n
            v.extend([(r*math.cos(a),r*math.sin(a),zz) for r,zz in ((ri,z),(ro,z),(ri,z+h),(ro,z+h))])
        f=[]
        for i in range(n):
            j=i*4;k=j+4; f.extend([(j+2,j+3,k+3,k+2),(j+1,j,k,k+1),(j,j+2,k+2,k),(j+3,j+1,k+1,k+3)])
        f.extend([(0,1,3,2),(4*n+1,4*n,4*n+2,4*n+3)]); self.mesh(v,f,mat)
    def finish(self,name,col,origin=(0,0,0)):
        obs=[]
        for mat,(v,f) in self.parts.items():
            me=bpy.data.meshes.new(name+'_'+mat); me.from_pydata(v,[],f); me.materials.append(MATS[mat]); me.update()
            uv=me.uv_layers.new(name='Atlas')
            for p in me.polygons:
                coords=[me.vertices[me.loops[i].vertex_index].co for i in p.loop_indices]
                axis=max(range(3),key=lambda j:abs(p.normal[j])); axes=[j for j in range(3) if j!=axis]
                lo=[min(c[j] for c in coords) for j in axes]; hi=[max(c[j] for c in coords) for j in axes]
                idx=TILES.get(mat,15); ox=idx%4;oy=idx//4
                for li,c in zip(p.loop_indices,coords):
                    u=(c[axes[0]]-lo[0])/max(.001,hi[0]-lo[0]); vv=(c[axes[1]]-lo[1])/max(.001,hi[1]-lo[1])
                    if mat=='stone':
                        uv.data[li].uv=((c[axes[0]]+origin[axes[0]])/16,(c[axes[1]]+origin[axes[1]])/16)
                    else:uv.data[li].uv=((ox+.025+.95*u)/4,(oy+.025+.95*vv)/4)
            ob=bpy.data.objects.new(name+'__'+mat,me); col.objects.link(ob); ob.location=origin; ob['kit_id']=name; obs.append(ob)
        return obs

def coll(name,scene=None):
    c=bpy.data.collections.new(name); (scene or bpy.context.scene).collection.children.link(c); return c

def register(name,g):
    c=coll('Kit_'+name,KITSCENE); obs=g.finish(name,c); KIT[name]=obs; return obs

def bottle(g,c,h,mat='glass',r=None,n=12):
    x,y,z=c; r=r or h*.23
    g.cyl((x,y,z),r*.8,h*.06,mat,n,rt=r)
    g.cyl((x,y,z+h*.06),r,h*.53,mat,n)
    g.cyl((x,y,z+h*.59),r,h*.19,mat,n,rt=r*.38)
    g.cyl((x,y,z+h*.78),r*.38,h*.15,mat,n)
    g.cyl((x,y,z+h*.93),r*.47,h*.07,'red',n)

def window(g,x,y,z,w=3,h=4):
    g.box((x,y,z),(w+.65,.6,h+.65),'wooddark'); g.box((x,y-.33,z),(w,.12,h),'window')
    g.box((x,y-.44,z),(.18,.15,h),'wood'); g.box((x,y-.44,z),(w,.15,.18),'wood')
    for s in (-1,1): g.box((x+s*(w/2+.65),y,z),(.85,.5,h+.25),'blue')
    g.box((x,y-.35,z-h/2-.45),(w+1.5,1.1,.45),'trim')

def house(name,w,d,h,roof='terra',wall='cream',shop=False,work=False):
    g=Geo(); g.box((0,0,.65),(w,d,1.3),'stone'); g.box((0,0,(h+1.3)/2),(w,d,h-1.3),wall)
    rh=max(5,d*.45); g.roof(w+2,d+2,h,rh,roof)
    # Exposed gables, heavy fascia and ridge caps.
    for s in (-1,1):
        x=s*(w/2+.35)
        for yy in (-1,1): g.beam((x,yy*(d/2+1),h),(x,0,h+rh),.55,.65,'trim')
        for y in (-d/2,d/2): g.box((s*(w/2-.25),y,h/2),(.55,.6,h),'wood')
    for y in (-d/2-.7,d/2+.7): g.box((0,y,h),(w+2.2,.65,.6),'wooddark')
    g.box((0,0,h+rh+.1),(w+2.4,.9,.7),'wooddark')
    for i in range(max(3,int(w/4))):
        x=-w/2+1+i*(w-2)/max(1,int(w/4)-1)
        g.box((x,0,h+rh+.44),(1.7,1.1,.25),roof)
    # Door is sized for the five-stud avatar, with its threshold on the ground.
    fy=-d/2-.15; g.box((0,fy,4.15),(4.8,.45,8.3),'wooddark'); g.box((0,fy-.25,4),(3.9,.2,7.8),'wood')
    g.box((0,fy-.4,6.2),(2.65,.12,1.6),'window'); g.cyl((1.3,fy-.55,3.6),.18,.3,'gold',8)
    for x in (-w*.31,w*.31): window(g,x,fy,6, min(3.2,w*.18),3.9)
    # Chimney, with a cap and inset soot opening.
    cx=w*.28;cy=d*.20; cz=h+rh*(1-abs(cy)/(d/2+1))
    g.box((cx,cy,cz+2),(2.6,2.6,4),'brick');g.box((cx,cy,cz+4),(3.25,3.25,.65),'trim');g.box((cx,cy,cz+4.35),(1.6,1.6,.1),'navy')
    # Side workshop window and timber infill on the gable.
    for s in (-1,1):
        x=s*(w/2+.1)
        g.box((x,0,h+rh*.27),(.3,3.4,2.4),'wooddark');g.box((x+s*.18,0,h+rh*.27),(.1,2.7,1.8),'window')
    if shop:
        aw=w*.8; az=10.2 if h>13 else 8.8
        for i in range(8):
            g.beam((-aw/2+aw*(i+.5)/8,fy-.5,az),(-aw/2+aw*(i+.5)/8,fy-3.8,az-1.5),aw/8,.16,roof if i%2==0 else 'white')
        for x in (-aw/2,aw/2): g.box((x,fy-3.7,(az-1.5)/2),(.35,.35,az-1.5),'wooddark')
        g.box((0,fy-.3,h-1.6),(w*.74,.5,2.2),'navy')
        g.box((0,fy-.62,h-2.75),(w*.79,.15,.2),'gold')
    if work:
        g.box((w/2+2,-2,2),(4,7,4),'brick');g.box((w/2+2,-5.55,2),(2.8,.15,2.8),'glow')
        g.box((w/2+2,-2,4.3),(4.7,7.5,.6),'rockdark')
    register(name,g)

def props():
    g=Geo();g.cyl((0,0,0),1.1,.6,'stone',8);g.cyl((0,0,.6),.42,8.7,'iron',8)
    for z in (1,7.5,8.5):g.cyl((0,0,z),.65,.25,'gold',8)
    g.ico((0,0,9.8),(1.2,1.2,1.4),'lampglass',2,2);g.cyl((0,0,11),1.5,.5,'iron',8,rt=.4)
    for x,y in ((1.1,0),(-1.1,0),(0,1.1),(0,-1.1)):g.beam((x,y,8.5),(x*.65,y*.65,10.8),.1,.1,'iron')
    register('lamp',g)
    g=Geo()
    for x in (-2.6,2.6):
        for y in (-.7,.7):g.box((x,y,1),(.45,.45,2),'iron')
        g.box((x,.9,2.1),(.4,.4,4.2),'iron')
    for y in (-.8,0,.8):g.box((0,y,2),(6.4,.65,.35),'woodlight')
    for z in (2.8,3.6):g.box((0,1,z),(6.4,.35,.55),'wood')
    register('bench',g)
    g=Geo();g.box((0,0,.65),(5,1.8,1.3),'wood')
    g.box((0,0,1.35),(5.3,2,.2),'woodlight');g.box((0,0,1.48),(4.7,1.4,.12),'wooddark')
    for i in range(7):
        x=-2+i*.67;g.ico((x,0,1.8),(.55,.7,.55),'leaf',i)
        g.ico((x,0,2.22),(.27,.28,.25),'flower' if i%2 else 'gold',i)
    register('flower_box',g)
    for name,s in [('crate',(4,4,3.8)),('pallet',(5,4,.7))]:
        g=Geo();w,d,h=s
        if name=='crate':
            for y in (-d/2+.2,d/2-.2):
                for z in (.5,1.6,2.7,3.6):g.box((0,y,z),(w,.35,.65),'woodlight')
            for x in (-w/2+.2,w/2-.2):
                for z in (.5,1.6,2.7,3.6):g.box((x,0,z),(.35,d,.65),'wood')
            for x in (-1.1,1.1):bottle(g,(x,0,.2),3.3,'glassgreen',.65,n=6)
        else:
            for x in (-1.8,0,1.8):g.box((x,0,.25),(.55,d,.5),'wooddark')
            for y in (-1.6,-.8,0,.8,1.6):g.box((0,y,.6),(w,.65,.2),'woodlight')
        register(name,g)
    g=Geo()
    for i in range(12):
        a=i*math.tau/12;g.box((1.55*math.cos(a),1.55*math.sin(a),2.1),(.9,.3,4.2),'wood',a+math.pi/2)
    for z in (.45,3.6):g.cyl((0,0,z),1.85,.3,'iron',12)
    g.cyl((0,0,4.15),1.65,.18,'woodlight',12);register('barrel',g)
    for key in ('binblue','bingreen','binyellow'):
        g=Geo();g.box((0,0,2.2),(4,4,4.4),key);g.box((0,0,4.55),(4.5,4.5,.3),'iron')
        g.box((0,0,4.73),(2.6,2.2,.08),'navy')
        g.box((0,-2.05,2.4),(2.3,.14,2.3),'white')
        for a in (0,120,240):g.beam((.7*math.cos(math.radians(a)),-2.15,2.4+.7*math.sin(math.radians(a))),(.7*math.cos(math.radians(a+100)),-2.15,2.4+.7*math.sin(math.radians(a+100))),.23,.18,key)
        register(key,g)
    g=Geo()
    for x in (-4,4):g.box((x,0,1.7),(.45,.45,3.4),'wooddark');g.cyl((x,0,3.4),.5,.4,'gold',8,rt=.2)
    for z in (1,2.6):g.box((0,0,z),(8,.35,.4),'wood')
    g.beam((-4,0,.8),(4,0,2.8),.23,.25,'wood');register('railing',g)
    g=Geo();g.box((0,0,1.3),(8,2,2.6),'stone');g.box((0,0,2.75),(8.3,2.3,.3),'trim');register('low_wall',g)
    g=Geo();g.box((0,0,.15),(8,8,.3),'stone');register('cobble_tile',g)
    g=Geo()
    for x in (-4,4):
        for y in (-2.6,2.6):g.box((x,y,4),(.4,.4,8),'wooddark')
    g.box((0,0,2),(8,5,4),'wood');g.box((0,-.2,4.2),(9,6,.4),'woodlight')
    for i in range(8):
        # Real folded canopy with alternating coloured panels.
        x=-5+i*1.25;g.mesh([(x,-4,7.8),(x+1.25,-4,7.8),(x+1.25,0,10),(x,0,10),(x,4,7.8),(x+1.25,4,7.8)],[(0,1,2,3),(3,2,5,4)],'terra' if i%2 else 'white')
        g.box((x+.625,-4,7.45),(1.25,.15,.7),'terra' if i%2 else 'white')
    for i in range(5):bottle(g,(-3+i*1.5,-1,4.4),1.7,'glassblue' if i%2 else 'glassamber',.42)
    register('stall',g)
    # Trees and layered rocks: silhouettes differ, even before colour variants.
    for kind in ('pine','round','bush'):
        g=Geo()
        if kind=='pine':
            g.cyl((0,0,0),.8,10,'wooddark',7,rt=.55)
            for z,r,h,mat in [(4,6.4,10,'pine'),(9,5.1,9,'pine2'),(14,3.6,10,'pine')]:g.cyl((0,0,z),r,h,mat,7,rt=.05)
        elif kind=='round':
            g.cyl((0,0,0),1,10,'wood',7,rt=.65);g.beam((0,0,5),(3,0,10),.6,.6,'wood')
            for c,s,mat in [((0,0,13),(7,6,6),'leaf'),((-4,1,11),(4,4,4),'leaflight'),((3,-2,12),(4.5,4,4.5),'leaf')]:g.ico(c,s,mat,3,2)
        else:
            for i in range(3):g.ico((i*1.8-1.8,0,1.5),(2.6,2,1.8),'leaflight' if i%2 else 'leaf',i)
        register(kind,g)
    for i,size in enumerate((2,4,7)):
        g=Geo();g.ico((0,0,size*.47),(size,size*.8,size*.62),'rock',i,2);register('rock_'+str(i),g)
    for i,size in enumerate((5,10,17)):
        g=Geo();rr=random.Random(i+10)
        material=['glassgreen','glassblue','glassamber'][i]
        levels=[(size,0),(size*.79,size*.34),(size*.44,size*.68),(size*.16,size*.91),(.02,size)]
        vs=[];n=11
        for radius,z in levels:
            for j in range(n):
                a=j*math.tau/n;variation=rr.uniform(.82,1.1)
                vs.append((radius*math.cos(a)*variation+z*.15,radius*math.sin(a)*variation-z*.10,z*(1 if z==0 else rr.uniform(.9,1.1))))
        triangles=[]
        for k in range(4):
            for j in range(n):
                quad=[vs[k*n+j],vs[k*n+(j+1)%n],vs[(k+1)*n+(j+1)%n],vs[(k+1)*n+j]]
                g.mesh(quad,[(0,1,2),(0,2,3)],material);triangles.extend([[quad[t] for t in f] for f in ((0,1,2),(0,2,3))])
        # Overlapping angular fragments follow the mound's actual surface.
        for j in range((18,40,74)[i]):
            a,b,c=[Vector(v) for v in rr.choice(triangles[:66])];u=rr.random();v=rr.random()
            if u+v>1:u=1-u;v=1-v
            p=a+u*(b-a)+v*(c-a);p.z=max(size*.07,p.z)
            sx=rr.uniform(.11,.20)*size
            g.ico(p,(sx,sx*.85,sx*.55),material,j)
        register('cullet_'+str(i),g)
    g=Geo();g.ico((0,0,7),(18,14,10),'rock',2,2);register('cliff_face',g)
    g=Geo();g.ico((0,0,12),(30,30,20),'grassdark',1,2);register('hill',g)
    # Gate spans 22 clear studs.
    g=Geo()
    for y in (-13,13):
        g.box((0,y,8),(4,4,16),'brick');g.box((0,y,16.5),(5,5,1),'stone');g.box((0,y,.5),(5,5,1),'stone')
    g.box((0,0,18),(4,30,3),'wooddark');g.box((-2.1,0,18),(.2,20,2),'gold')
    g.roof(6,32,19.5,3,'greenroof');register('gate',g)
    # Conveyor, rollers, feet, safety edges; scale only length when assembling.
    g=Geo()
    for x in (-3.5,3.5):
        for y in (-7,7):g.box((x,y,2),(.6,.6,4),'iron')
        g.box((x,0,4),(1,18,.9),'binyellow')
    g.box((0,0,3.9),(6,18,.5),'navy')
    for y in range(-8,9,2):g.box((0,y,4.23),(6,.35,.13),'ironlight')
    register('conveyor',g)
    # Crusher footprint / wall envelope is exactly 24 x 18 x 20.
    g=Geo();g.box((0,0,1),(24,18,2),'rockdark')
    for x in (-9,9):
        for y in (-6,6):g.box((x,y,7),(2.4,2.4,12),'iron')
    g.box((0,0,12),(22,16,8),'ironlight');g.box((0,-8.1,11.5),(14,.3,4),'navy')
    for x in range(-6,7,2):g.box((x,-8.4,11.5),(.8,.25,4),'iron')
    g.mesh([(-11,-8,16),(11,-8,16),(11,8,16),(-11,8,16),(-7,-4,20),(7,-4,20),(7,4,20),(-7,4,20)],[(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'binyellow')
    g.box((0,0,16.1),(17,9,.2),'navy');g.box((7,-8.6,6.4),(4,.8,3),'greenroof')
    for x in (6,7,8):g.ico((x,-9.1,6.6),(.22,.15,.22),'window',1)
    register('crusher',g)
    g=Geo()
    for x in (-5,5):
        for y in (-5,5):
            g.box((x,y,17),(.85,.85,34),'iron');g.beam((x,y,2),(-x,y,28),.4,.4,'ironlight')
    g.box((0,0,33),(12,12,2),'wooddark');g.box((0,0,.5),(9,9,1),'woodlight')
    for x in (-3,3):g.beam((x,0,1),(x,0,32),.12,.12,'iron')
    register('lift',g)
    g=Geo()
    for y in range(-29,30,2):g.box((0,y,.5),(12,1.9,1),'wood')
    for x in (-5,5):
        for y in (-27,-9,9,27):g.cyl((x,y,-7),.7,9,'wooddark',8);g.cyl((x,y,2),.85,.3,'woodlight',8)
    register('dock',g)
    g=Geo()
    # Chunky hull, raised bow and contrasting gunwales, open cockpit.
    levels=[(0,2.5,7),(1.7,4,9),(3,4.2,10)]
    vs=[]
    for z,w,d in levels:vs.extend([(-w,-d*.65,z),(0,-d,z),(w,-d*.65,z),(w,d*.65,z),(0,d,z+1),(-w,d*.65,z)])
    fs=[]
    for k in range(2):
        for j in range(6):fs.append((k*6+j,k*6+(j+1)%6,(k+1)*6+(j+1)%6,(k+1)*6+j))
    fs.append(tuple(reversed(range(6))));g.mesh(vs,fs,'blue')
    for j in range(6):g.beam(vs[12+j],vs[12+(j+1)%6],.35,.35,'trim')
    g.box((0,0,1.8),(6,13,.5),'woodlight')
    for y in (-4,3):g.box((0,y,2.6),(7,1.6,.4),'wood')
    g.box((0,1,4),(4.7,4,3),'cream');g.box((0,1,5.7),(5.4,4.5,.4),'terra')
    g.box((0,-1.05,4.6),(3,.13,1.3),'glassblue');register('boat',g)

def furnace():
    g=Geo(); w,d,h=62,38,30
    g.box((0,0,1),(62,38,2),'rockdark')
    # Portal is an actual opening in the facade, with an inset lit firebox.
    g.box((-20,0,16),(22,38,28),'brick');g.box((20,0,16),(22,38,28),'brick')
    g.box((0,5,16),(18,28,28),'brick');g.box((0,-14.1,9),(17,.3,16),'glow')
    g.box((0,-18.6,24),(18,.8,12),'brick')
    g.roof(64,40,30,13,'wooddark')
    for x in (-30,30):
        for y in (-19,19):g.box((x,y,15),(2.4,2,30),'stone')
        g.beam((x,-20,30),(x,0,43),1.2,1,'trim');g.beam((x,20,30),(x,0,43),1.2,1,'trim')
    for y in (-20,20):g.box((0,y,30),(65,1,1.1),'stone')
    # Large voussoirs and vertical jambs frame the fiery mouth.
    for x in (-10,10):g.box((x,-19.8,5.5),(2.5,2.2,11),'stone')
    for i in range(12):
        a=i*math.pi/12;b=(i+1)*math.pi/12
        section=[(8.9*math.cos(a),10+7.1*math.sin(a)),(11.3*math.cos(a),10+9.3*math.sin(a)),(11.3*math.cos(b),10+9.3*math.sin(b)),(8.9*math.cos(b),10+7.1*math.sin(b))]
        vs=[(x,y,z) for y in (-20.9,-18.7) for x,z in section]
        g.mesh(vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'stone')
    for x in (-22,22):
        window(g,x,-19.4,13,7,10)
    g.box((0,-19.9,1),(22,4,2),'rockdark')
    register('furnace_hall',g)
    for i in range(5):
        z=i*26;rb=12-(12-8.5)*z/130;rt=12-(12-8.5)*(z+26)/130
        g=Geo();g.cyl((0,0,0),rb,26,'brick',12,rt=rt)
        g.cyl((0,0,23),rt+.7,3,'rockdark',12)
        g.cyl((0,0,23),rt+.85,.55,'stone',12)
        # Vertical straps and rivets give a strong industrial silhouette.
        for j in range(12):
            a=(j+.5)*math.tau/12
            for zz in (5,16):
                radius=(rb+(rt-rb)*zz/26)*math.cos(math.pi/12)+.08
                g.ico((radius*math.cos(a),radius*math.sin(a),zz),(.17,.17,.17),'gold',1)
        register('chimney_'+str(i),g)
    g=Geo();bottle(g,(0,0,0),30,'glass',10.625)
    # Highlight inlays read from spawn without transparent double surfaces.
    for z,r in ((3,10.8),(16.5,10.8),(25,4.2)):g.cyl((0,0,z),r,.6,'glassclear',12)
    register('tower_bottle',g)
    g=Geo();g.box((0,0,7),(34,1.5,14),'wooddark');g.box((0,-.81,7),(31,.15,11),'navy')
    for x in (-12,12):g.box((x,1.4,7),(1,1.3,10),'iron')
    for x in (-16,16):g.box((x,-.9,7),(.6,.4,14),'gold')
    for z in (.5,13.5):g.box((0,-.9,z),(32,.4,.6),'gold')
    for side in (-1,1):
        for z in (3.1,5.7,8.3,10.9):g.box((side*11,-1.01,z),(4.8,.12,.75),'cream')
        for z in (4.4,9.6):
            g.box((side*6,-1.02,z),(4.4,.12,.55),'glassblue');g.box((side*8,-1.02,z),(.2,.12,2.6),'glassclear')
        g.box((side*2.8,-1.02,7),(3.5,.12,1.2),'gold');g.box((side*4,-1.02,7),(.2,.12,5.2),'glassclear')
    register('bracket_board',g)

def build_kit():
    global KITSCENE
    KITSCENE=bpy.data.scenes.new('Kilnport_Kit');materials()
    for name,w,d,h in [('cottage_small',16,14,11),('cottage_medium',18,16,12),('cottage_large',20,16,13)]:house(name,w,d,h)
    house('workshop',20,16,12,'greenroof',work=True)
    house('shop_front',30,22,16,'terra',shop=True)
    house('halfway_hut',14,12,9,'greenroof','wood',shop=True)
    # Exact blueprint envelopes, without distorting door sizes.
    for b in L.BUILDINGS:
        if b['id'] in ('furnace','crusher'):continue
        roof={'#C2553D':'terra','#3F6FB5':'blue','#3FA874':'greenroof','#7A5CFF':'purple','#8C5A2B':'wooddark'}[b['roof']]
        house('building_'+b['id'],*b['size'],roof,'wood' if b['id'] in ('notice','hut') else 'cream',shop=b['id'] in ('bazaar','studio','repair','starter_hall','hut'),work=b['id']=='house_4')
    props();furnace()
    # Bring in the APPROVED stand, retaining evaluated geometry and proportions.
    with bpy.data.libraries.load(str(ROOT/'assets/blender/map/clash_stand.blend'),link=False) as (src,dst): dst.objects=src.objects
    c=coll('Kit_approved_stand',KITSCENE);obs=[]
    for ob in dst.objects:
        if ob and ob.type=='MESH':
            c.objects.link(ob);obs.append(ob)
    bpy.context.window.scene=KITSCENE
    bpy.context.view_layer.update()
    for ob in obs:
        dg=bpy.context.evaluated_depsgraph_get();ev=ob.evaluated_get(dg)
        me=bpy.data.meshes.new_from_object(ev,depsgraph=dg);me.transform(ob.matrix_world)
        ob.data=me;ob.matrix_world=Matrix.Identity(4);ob.modifiers.clear()
    # All approved pieces share an assembly base origin, not a hanging pivot.
    minz=min(v.co.z for o in obs for v in o.data.vertices)
    for ob in obs:
        ob.data.transform(Matrix.Translation((0,0,-minz)));ob['kit_id']='approved_stand'
    KIT['approved_stand']=obs
    # Kit origins are all at the lowest support plane (dock piles included).
    for key,objects in KIT.items():
        z=min(v.co.z for ob in objects for v in ob.data.vertices)
        if abs(z)>1e-6:
            for ob in objects:ob.data.transform(Matrix.Translation((0,0,-z)))
    KITSCENE.unit_settings.system='NONE';KITSCENE.unit_settings.scale_length=1
    budget={k:sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in v) for k,v in KIT.items()}
    (OUT/'kit_budgets.json').write_text(json.dumps(budget,indent=2))
    bpy.data.libraries.write(str(OUT/'kit_kilnport.blend'),{KITSCENE},fake_user=True)
    return budget

def region(x,y):
    if y < -270:return 'cullet_pit' if x>-25 else 'yard_south'
    if x < -195:return 'yard_west'
    if y>65:return 'village_north'
    if y< -70:return 'village_south'
    return 'village_centre'

def place(key,name,pos,angle=0,scale=(1,1,1),chunk=None,swap=None):
    chunk=chunk or region(*pos[:2]);col=CHUNKS[chunk]
    mat=Matrix.Translation(pos)@Matrix.Rotation(math.radians(angle),4,'Z')@Matrix.Diagonal((*scale,1))
    obs=[]
    for src in KIT[key]:
        ob=bpy.data.objects.new(name+'__'+src.name.split('__')[-1],src.data);col.objects.link(ob);ob.matrix_world=mat@src.matrix_world
        ob['asset']=key;ob['anchor']=name;ob['chunk']=chunk
        if swap:
            for sl in ob.material_slots:
                k=sl.material.name.removeprefix('KP_') if sl.material else ''
                if k in swap:
                    sl.link='OBJECT';sl.material=MATS[swap[k]]
                    if k in TILES and swap[k] in TILES and k!=swap[k]:
                        cache=(src.data.name,swap[k])
                        if cache not in VARIANTS:
                            me=src.data.copy();old,new=TILES[k],TILES[swap[k]]
                            for uv in me.uv_layers.active.data:uv.uv+=Vector(((new%4-old%4)/4,(new//4-old//4)/4))
                            VARIANTS[cache]=me
                        ob.data=VARIANTS[cache]
        obs.append(ob)
    return obs

def direct(g,name,pos=(0,0,0),chunk=None):return g.finish(name,CHUNKS[chunk or region(*pos[:2])],pos)

def text_sign(label,pos,size=1.2,angle=0,chunk=None,mat='cream'):
    # Convert text to geometry for a font-independent FBX.
    cu=bpy.data.curves.new('Sign_'+label,'FONT');cu.body=label;cu.align_x='CENTER';cu.size=size;cu.extrude=.012;cu.resolution_u=2
    ob=bpy.data.objects.new('Sign_'+label,cu);CHUNKS[chunk or region(*pos[:2])].objects.link(ob);ob.location=pos;ob.rotation_euler=(math.pi/2,0,math.radians(angle));ob.data.materials.append(MATS[mat])
    bpy.context.view_layer.objects.active=ob;ob.select_set(True);bpy.ops.object.convert(target='MESH');ob.select_set(False)

def point_inside(p,poly):
    x,y=p; inside=False
    for a,b in zip(poly,poly[1:]+poly[:1]):
        if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:inside=not inside
    return inside

def circle(x,y,r,n=64):return [(x+r*math.cos(i*math.tau/n),y+r*math.sin(i*math.tau/n)) for i in range(n)]
def ribbon(a,b,w):
    a,b=Vector(a),Vector(b);d=(b-a).normalized();n=Vector((-d.y,d.x))*w/2
    return [tuple(a+n),tuple(b+n),tuple(b-n),tuple(a-n)]
def dist_seg(p,a,b):
    p,a,b=Vector(p),Vector(a),Vector(b);d=b-a;t=max(0,min(1,(p-a).dot(d)/d.length_squared));return (p-(a+t*d)).length

def ground():
    # Constrained triangulation makes paths/plazas and lawn a single flush surface.
    # Intersections share vertices: no stacked path discs or coplanar joins.
    polys=[a['points'] for a in L.LAND]; road=[];wild=[]
    for path in L.PATHS:
        pts=path['points'][2:] if path['id']=='route1' else path['points']
        for a,b in zip(pts,pts[1:]):road.append((ribbon(a,b,path['width']),path['z']))
        for x,y in pts[1:-1]:road.append((circle(x,y,path['width']/2,16),path['z']))
    road.append((ribbon((-170,-40),(-175,-40),22),0))
    # Exact gate ramp endpoints and clear width, with clipped plateau surface.
    ramp_poly=ribbon((-175,-40),(-262,-45),22)
    for d in L.DISKS:
        if d['kind']=='plaza':road.append((circle(*d['center'],d['radius']),d['z']))
        elif d['kind']=='wild':wild.append((circle(*d['center'],d['radius']),d['z']))
    # Footpaths tie service thresholds into the primary circulation.
    for b in L.BUILDINGS:
        if b['id'] in ('furnace','crusher','notice'):continue
        x,y=b['center'];a=math.radians(-b['facing']);front=(x+math.sin(a)*(b['size'][1]/2+2),y-math.cos(a)*(b['size'][1]/2+2))
        if y>-190 and x>-195:
            if y<-75: target=(max(-13,min(13,x)),y)
            else:
                v=Vector(front);target=tuple(v.normalized()*70)
            road.append((ribbon(front,target,5),0))
    # Stand spurs and the pit's 2-stud approach ramp get their own surface.
    for sd in L.STANDS:
        x,y=sd['center']
        if sd['kind']=='trainer':
            pts=L.PATHS[5]['points'];target=min(pts,key=lambda p:math.dist(p,(x,y)));road.append((ribbon((x,y),target,7),-20))
    for p,z in road+wild:polys.append(p)
    polys.append(ramp_poly)
    verts=[];edges=[];faces=[]
    for pp in polys:
        k=len(verts);verts.extend(Vector(p) for p in pp);faces.append(list(range(k,len(verts))))
        edges.extend((k+i,k+(i+1)%len(pp)) for i in range(len(pp)))
    # Texture-size grid prevents large stretched cobbles.
    for x in range(-520,225,8):
        for y in range(-480,201,8):
            if any(point_inside((x,y),a['points']) for a in L.LAND):verts.append(Vector((x,y)))
    vo,eo,fo,_,_,_=delaunay_2d_cdt(verts,edges,faces,0,1e-5)
    batches=defaultdict(Geo)
    for f in fo:
        p=[vo[i] for i in f];cx=sum(a.x for a in p)/len(p);cy=sum(a.y for a in p)/len(p)
        lands=[a for a in L.LAND if point_inside((cx,cy),a['points'])]
        if not lands:continue
        land=max(lands,key=lambda a:a['top']);z=land['top']
        patch=math.sin(cx/36)+math.cos(cy/43)+.35*math.sin((cx+cy)/20)
        mat='sand' if land['id']=='beach' else ('grasslight' if patch>1.3 else 'grassdark' if patch<-1.4 else 'grass')
        if any(abs(zz-z)<.1 and point_inside((cx,cy),poly) for poly,zz in road):mat='stone'
        if any(abs(zz-z)<.1 and point_inside((cx,cy),poly) for poly,zz in wild):mat='grasslight'
        vs=[]
        on_ramp=point_inside((cx,cy),ramp_poly)
        for v in p:
            zz=z
            if on_ramp:
                t=((v-Vector((-175,-40))).dot(Vector((-87,-5))))/(87**2+5**2);zz=-20*max(0,min(1,t));mat='stone'
            vs.append((v.x,v.y,zz))
        batches[(int(cx//64),int(cy//64))].mesh(vs,[tuple(range(len(vs)))],mat)
    for (x,y),g in batches.items():direct(g,f'Ground_{x}_{y}',chunk='terrain')
    # Full-height retaining cheeks beneath the sloped ramp eliminate exposed voids.
    a=Vector((-175,-40));b=Vector((-262,-45));d=(b-a).normalized();n=Vector((-d.y,d.x))
    for side in (-1,1):
        aa=a+n*11*side;bb=b+n*11*side;g=Geo()
        g.mesh([(aa.x,aa.y,0),(bb.x,bb.y,-20),(bb.x,bb.y,-20.3),(aa.x,aa.y,-20.3)],[(0,1,2,3)],'rock')
        direct(g,'Ramp_retaining',chunk='terrain')
        tt=(-193-aa.x)/(bb.x-aa.x);cc=aa.lerp(bb,tt)
        g=Geo();g.mesh([(aa.x,aa.y,0),(cc.x,cc.y,0),(cc.x,cc.y,-20*tt)],[(0,1,2)],'rocklight');direct(g,'Ramp_cut_cheek',chunk='terrain')
        for j in range(11):
            t=(j+.5)/11;p=a.lerp(b,t)+n*10.5*side
            z=-20*t;g=Geo();g.cyl((p.x,p.y,z),.28,3,'wooddark',6)
            direct(g,'Ramp_baluster',chunk='yard_west')
        aa=a+n*10.5*side;bb=b+n*10.5*side
        g=Geo();g.beam((aa.x,aa.y,2.8),(bb.x,bb.y,-17.2),.4,.4,'woodlight');direct(g,'Ramp_handrail',chunk='yard_west')
    # Faceted side walls share EXACT top boundary coordinates with the plateau.
    for land in L.LAND:
        pts=land['points'];top=land['top'];bottom=land['bottom']
        for ei,(a,b) in enumerate(zip(pts,pts[1:]+pts[:1])):
            # The two terraces share this boundary. Only expose their height difference.
            internal=land['id']=='plateau' and ei in (0,9)
            if land['id']=='yard_terrace' and ei in (7,8,9):continue
            bot=-20 if internal else bottom
            if land['id']=='beach':bot=-60
            count=max(1,int(math.dist(a,b)/12));g=Geo();rr=random.Random(ei+len(pts)*10)
            ts=[j/count for j in range(count+1)]
            if internal and ei==0:
                aa,bb=Vector(a),Vector(b);edge=bb-aa
                def cross(u,v):return u.x*v.y-u.y*v.x
                for ra,rb in zip(ramp_poly,ramp_poly[1:]+ramp_poly[:1]):
                    ra,rb=Vector(ra),Vector(rb);rv=rb-ra;den=cross(edge,rv)
                    if abs(den)<1e-8:continue
                    t=cross(ra-aa,rv)/den;u=cross(ra-aa,edge)/den
                    if 0<t<1 and 0<=u<=1:ts.append(t)
                ts=sorted(set(ts));count=len(ts)-1
            rings=[]
            for level in range(5):
                r=[]
                for j,t in enumerate(ts):
                    x=a[0]*(1-t)+b[0]*t;y=a[1]*(1-t)+b[1]*t
                    # No top displacement. Lower rock strata flare outward.
                    dx=b[0]-a[0];dy=b[1]-a[1];length=math.hypot(dx,dy);offset=0 if level==0 else (1.5+rr.random()*3)*math.sin(level*math.pi/5)*math.sin(t*math.pi)
                    zz=top+(bot-top)*level/4
                    r.append((x-dy/length*offset,y+dx/length*offset,zz))
                rings.append(r)
            for k in range(4):
                for j in range(count):
                    if internal and ei==0:
                        t=(ts[j]+ts[j+1])/2
                        if point_inside((a[0]*(1-t)+b[0]*t,a[1]*(1-t)+b[1]*t),ramp_poly):continue
                    v=[rings[k][j],rings[k][j+1],rings[k+1][j+1],rings[k+1][j]]
                    g.mesh(v,[(0,1,2),(0,2,3)],['rocklight','rock','rockdark','rock'][k])
            direct(g,f'Cliff_{land["id"]}_{ei}',chunk='cliffs_harbor')
    # A simple preview sea is excluded from exports; Studio Terrain water replaces it.
    g=Geo();g.box((0,0,-61),(20000,20000,2),'sea');g.finish('Preview_Sea',PREVIEW)

def assemble():
    global SCENE,CHUNKS,PREVIEW
    SCENE=bpy.data.scenes.new('Kilnport_Final');bpy.context.window.scene=SCENE
    SCENE.unit_settings.system='NONE';SCENE.unit_settings.scale_length=1
    CHUNKS={k:coll('KP_'+k,SCENE) for k in ['village_centre','village_north','village_south','cliffs_harbor','yard_west','yard_south','cullet_pit','terrain']}
    PREVIEW=coll('Preview_only',SCENE)
    bo=bpy.data.collections.get('Blockout')
    if bo:SCENE.collection.children.link(bo);bo.hide_render=True;bo.hide_viewport=True
    ground()
    for b in L.BUILDINGS:
        x,y=b['center'];z=-20 if y<-190 or x<-195 else 0
        key='furnace_hall' if b['id']=='furnace' else ('crusher' if b['id']=='crusher' else 'building_'+b['id'])
        place(key,b['id'],(x,y,z),-b['facing']);ANCHORS.append({'id':b['id'],'kind':'building','blender':[x,y,z],'facing':b['facing'],'size':b['size']})
        if b['id'] not in ('furnace','crusher','notice'):
            a=math.radians(-b['facing']);d=b['size'][1]
            for xx in (-b['size'][0]*.33,b['size'][0]*.33):
                local=Vector((xx,-d/2-1,0));v=Matrix.Rotation(a,3,'Z')@local+Vector((x,y,z));place('flower_box',b['id']+'_flowers',v,-b['facing'])
        if b['id'] in ('bazaar','studio','repair','starter_hall','hut'):
            label={'bazaar':'BOTTLE BAZAAR','studio':'SPARKLE STUDIO','repair':'GLUE & GLAZE','starter_hall':'STARTER HALL','hut':'HALFWAY HUT'}[b['id']]
            v=Matrix.Rotation(math.radians(-b['facing']),3,'Z')@Vector((0,-b['size'][1]/2-.85,b['size'][2]-2))+Vector((x,y,z))
            text_sign(label,v,size=b['size'][0]/max(12,len(label))*.72,angle=-b['facing'])
    for i in range(5):place('chimney_'+str(i),'Tower_band_'+str(i),(0,132,26*i),chunk='village_north')
    place('tower_bottle','Tower_Bottle',(0,132,130),chunk='village_north')
    place('bracket_board','Bracket',(0,104,14),chunk='village_north')
    for sd in L.STANDS:
        x,y=sd['center'];z=-20 if y<-190 or x<-195 else 0
        if sd['kind']=='boss':z=-18
        s={'arena':1,'boss':1,'pvp':.8,'small':.6,'trainer':.7}[sd['kind']]
        place('approved_stand',sd['id'],(x,y,z),-sd['facing'],(s,s,s))
        ANCHORS.append({'id':sd['id'],'kind':'stand','blender':[x,y,z],'facing':sd['facing'],'scale':s})
    # Two segmented seat rings leave four open, walkable aisles.
    for q in range(4):
        for ri,ro,h in [(20,26,1.2),(26,32,2.4)]:
            g=Geo();g.ring(ri,ro,0,h,'stone',18,math.radians(q*90+9),math.radians(q*90+81));g.ring(ri+.25,ro-.25,h,.16,'woodlight',18,math.radians(q*90+9),math.radians(q*90+81));direct(g,'Arena_seats')
    g=Geo();g.cyl((0,0,-2),34,1.6,'rockdark',64);g.cyl((0,0,-.4),34,.4,'stone',64);direct(g,'Pit_platform',(45,-335,-18))
    # Broad slope arrives flush at the platform, no elevated unsupported floor.
    g=Geo()
    for y in range(-10,10,2):
        x0=-math.sqrt(34**2-y**2);x1=-math.sqrt(34**2-(y+2)**2)
        g.mesh([(-38,y,-2),(x0,y,0),(x1,y+2,0),(-38,y+2,-2)],[(0,1,2,3)],'stone')
    direct(g,'Pit_approach',(45,-335,-18))
    for i,st in enumerate(L.STALLS):
        a=math.radians(st['angle']);pos=(62*math.cos(a),62*math.sin(a),0)
        # Local -Y faces the square, as in the blockout.
        swap={'terra':{'#C2553D':'terra','#3F6FB5':'blue','#3FA874':'greenroof','#FFC93C':'gold'}[st['roof']]}
        place('stall',f'Market_{i+1}',pos,st['angle']-90,swap=swap)
    for i,(x,y) in enumerate(L.LAMPS):place('lamp',f'Lamp_{i+1}',(x,y,-20 if x<-195 else 0))
    # Benches face inward around the square; flower beds soften their backs.
    for a in (0,90,180,270):
        ang=math.radians(a)
        for off in (-11,11):
            x=46*math.cos(ang)-off*math.sin(ang);y=46*math.sin(ang)+off*math.cos(ang)
            place('bench','Square_bench',(x,y,0),a-90)
    for p in L.POINTS:
        x,y=p['pos'];z=-20 if y<-190 or x<-195 else 0
        if p['kind'] in ('gate','gate_locked'):place('gate',p['id'],(x,y,z),0 if p['id']=='kiln_gate' else 60)
        if p['id']=='lift':place('lift','Cullet_lift',(x,y,-20))
        ANCHORS.append({'id':p['id'],'kind':p['kind'],'blender':[x,y,z]})
    g=Geo();g.cyl((0,0,0),9,.6,'stone',12);g.cyl((0,0,.6),7,2.4,'cream',12,rt=6);g.cyl((0,0,3),7,.5,'gold',12)
    bottle(g,(0,0,3.5),9,'glassblue',2.2);direct(g,'Champion_pedestal',(30,-84,0))
    for x in (-30,-44):
        g=Geo();g.box((0,0,7),(10,1,9),'wooddark');g.box((0,-.6,7),(8.8,.2,7.8),'navy')
        for xx in (-4,4):g.box((xx,.2,6),(.5,.5,12),'wood')
        for j in range(4):g.box((.7,-.72,4.5+j*1.5),(5.2,.1,.3),'cream');g.ico((-3,-.8,4.5+j*1.5),(.35,.1,.35),'gold',1)
        direct(g,'Leaders',(x,-84,0))
    # Lift deck connects the exact bottom and top anchors, with supporting piers.
    edge_y=-190-(75+190)*5/280
    count=34;length=edge_y-(-262)
    for j in range(count):
        y=-262+length*(j+.5)/count
        g=Geo();g.box((75,y,-.35),(8,length/count,.7),'woodlight');direct(g,'Lift_bridge',chunk='yard_south')
    for y in (-246,-222,-202):
        for x in (71,79):
            g=Geo();g.box((x,y,-10),(.8,.8,20),'iron');direct(g,'Lift_pier',chunk='yard_south')
    for side in (-1,1):
        for y in range(-251,-194,8):place('railing','Lift_rail',(75+side*4,y,0),90,chunk='yard_south')
    # Dock/boats use the blockout transforms. Stair landing connects to the gate.
    place('dock','Harbor_dock',(195,175,-67),30,chunk='cliffs_harbor')
    for i,(x,y) in enumerate(((220,165),(225,200))):place('boat','Harbor_boat_'+str(i),(x,y,-59.5),30,chunk='cliffs_harbor')
    # Switchback stair descends outside the northeast cliff.
    a=Vector((159,150,0));b=Vector((182,121,-29));c=Vector((210,149,-59))
    g=Geo();g.box((154.9,150,-.6),(8.4,8,1.5),'wood');g.box((182,121,-30),(10,10,2),'wooddark');direct(g,'Harbor_landings',chunk='cliffs_harbor')
    g=Geo();g.box((152+13*math.sin(math.pi/3),150-13*math.cos(math.pi/3),-30),(7,7,60),'rock')
    g.box((182,121,-44.5),(3,3,31),'wooddark');direct(g,'Harbor_foundations',chunk='cliffs_harbor')
    for seg,(aa,bb) in enumerate(((a,b),(b,c))):
        direction=Vector((bb.x-aa.x,bb.y-aa.y,0)).normalized();normal=Vector((-direction.y,direction.x,0))
        for side in (-1,1):
            g=Geo();g.beam(aa+normal*3.2*side+Vector((0,0,-1.4)),bb+normal*3.2*side+Vector((0,0,-1.4)),.65,1.2,'wooddark')
            g.beam(aa+normal*4*side+Vector((0,0,3)),bb+normal*4*side+Vector((0,0,3)),.28,.32,'woodlight')
            for j in range(8):
                p=aa.lerp(bb,j/7)+normal*4*side;g.beam(p,p+Vector((0,0,3)),.3,.3,'wooddark')
            direct(g,'Harbor_stair_rail',chunk='cliffs_harbor')
        for i in range(30):
            t=(i+.5)/30;v=aa.lerp(bb,t);run=Vector((bb.x-aa.x,bb.y-aa.y,0)).length/30
            g=Geo();g.box((0,0,-.6),(8,run+.04,1.2),'stone');o=direct(g,f'Harbor_step_{seg}_{i}',v,'cliffs_harbor');angle=-math.atan2(bb.x-aa.x,bb.y-aa.y)
            for ob in o:ob.rotation_euler.z=angle
    # Railings are inset from the cliff; openings remain at the harbor gate.
    pts=L.LAND[0]['points']
    for ei in range(1,9):
        a=Vector(pts[ei]);b=Vector(pts[(ei+1)%len(pts)]);d=b-a;n=Vector((d.y,-d.x)).normalized();count=int(d.length/8)
        for j in range(count):
            p=a+d*((j+.5)/count)+n*2.0
            if (p-Vector((152,150))).length<17:continue
            place('railing',f'Cliff_rail_{ei}_{j}',(p.x,p.y,0),math.degrees(math.atan2(d.y,d.x)),scale=(d.length/count/8,1,1),chunk='cliffs_harbor')
    scatter()
    dress_village()
    # Conveyor story: ordered work line behind the southern path, feeds crusher.
    for a,b in CONVEYORS:
        d=Vector(b)-Vector(a);n=max(1,round(d.length/18))
        for j in range(n):
            p=Vector(a)+d*((j+.5)/n);place('conveyor',f'Conveyor_{a}_{j}',(p.x,p.y,-20),-math.degrees(math.atan2(d.x,d.y)),(1,d.length/n/18,1))
    for i,(x,y) in enumerate([(-357,-202),(-352,-221),(-317,-195),(-316,-214)]):
        place('pallet','Sorting_pallet',(x,y,-20));place(['binblue','bingreen','binyellow'][i%3],'Sorting_bin',(x,y,-19.3))
    for i,(x,y) in enumerate([(-205,-291),(-193,-295),(-215,-310),(-255,-283)]):
        place('pallet','Crate_pallet',(x,y,-20));place('crate','Bottle_crate',(x,y,-19.3),i*13)
    for x,y in [(-109,40),(87,89),(103,-99),(-82,-145),(-280,-313)]:place('barrel','Workshop_barrel',(x,y,-20 if y<-190 else 0))
    # Ground-level wayfinding, positioned off circulation.
    for label,pos,angle in [('KILNPORT',(0,-174,.02),0),('CULLET YARD',(-224,-61,-19.98),0)]:
        g=Geo();g.box((0,0,3.8),(15,.8,3),'wooddark');g.box((-6,0,2),(.6,.6,4),'wood');g.box((6,0,2),(.6,.6,4),'wood');direct(g,'Wayfinding',pos)
        text_sign(label,(pos[0],pos[1]-.48,pos[2]+3.4),1.2,angle)
    for ob in SCENE.objects:
        if ob.get('anchor','').startswith('Ground_cluster_') and math.dist(tuple(ob.location)[:2],(-224,-61))<10:
            ob.location.y-=20
    return SCENE

def dress_village():
    for ident,label in [('notice','NOTICE BOARD'),('bazaar','CRATE ODDS')]:
        b=next(b for b in L.BUILDINGS if b['id']==ident);x,y=b['center'];a=math.radians(-b['facing']);rot=Matrix.Rotation(a,3,'Z')
        local=(0,-b['size'][1]/2-.65,4) if ident=='notice' else (-11,-b['size'][1]/2-5,0)
        pos=rot@Vector(local)+Vector((x,y,0));g=Geo();g.box((0,0,3.5),(6,.7,7),'wooddark');g.box((0,-.4,3.5),(5.3,.1,6.3),'navy')
        for j in range(4):g.box((0,-.48,1.4+j*1.05),(3.8,.1,.22),'cream')
        if ident=='bazaar':
            for xx in (-2.5,2.5):g.box((xx,.2,1),(.4,.5,2),'wood')
        obs=direct(g,ident+'_noticeboard',pos)
        for ob in obs:ob.rotation_euler.z=a
        at=pos+rot@Vector((0,-.55,5.7));text_sign(label,at,.55,-b['facing'])
    # Small tended gardens, fences and lanterns make each house feel inhabited.
    for b in L.BUILDINGS:
        if not b['id'].startswith('house_'):continue
        x,y=b['center'];w,d,h=b['size'];a=math.radians(-b['facing']);rot=Matrix.Rotation(a,3,'Z')
        def at(v):return rot@Vector(v)+Vector((x,y,0))
        for side in (-1,1):
            for yy in (-d/2,0,d/2):place('railing',b['id']+'_garden_fence',at((side*(w/2+6),yy,0)),-b['facing']+90)
            place('round',b['id']+'_garden_tree',at((side*(w/2+4),d/2+8,0)),-b['facing'],(.56,.56,.65))
            for yy in (0,4):place('bush',b['id']+'_garden_shrub',at((side*(w/2+3),yy,0)),-b['facing'],(.7,.7,.7))
        place('lamp',b['id']+'_door_lamp',at((w/2+3,-d/2-3,0)),scale=(.8,.8,.8))
    # Glazier's work court behind the Furnace; adjacent to the front walkway.
    for x in (-43,43):
        for y in (114,127,140):
            place('pallet','Furnace_delivery_pallet',(x,y,0))
            place('crate','Furnace_bottle_crate',(x,y,.7))
        place('barrel','Furnace_water_barrel',(x,151,0))
    # Raised planted medallions soften the square without covering the stalls.
    for a in (20,160,200,340):
        v=Vector((math.cos(math.radians(a))*87,math.sin(math.radians(a))*87,0))
        g=Geo();g.ring(4.8,5.5,0,.6,'stone',24);g.cyl((0,0,0),4.8,.42,'wooddark',24);direct(g,'Garden_medallion',v)
        place('round','Garden_tree',v,scale=(.5,.5,.6))
        for j in range(5):
            aa=j*math.tau/5;p=v+Vector((3.5*math.cos(aa),3.5*math.sin(aa),.45));place('bush','Garden_bush',p,scale=(.35,.35,.35))
    # Workshop tools and tidy stock clusters remain outside doors and lanes.
    for x,y,a in [(-119,30,0),(87,104,30),(-76,105,-30),(59,-124,60)]:
        place('crate','Shop_stock',(x,y,0),a);place('barrel','Shop_water',(x+4.5,y+1,0))

def safe_prop(x,y,z,r,used):
    lands=[a for a in L.LAND if a['top']==z]
    if not any(all(point_inside((x+math.cos(i*math.pi/4)*r,y+math.sin(i*math.pi/4)*r),a['points']) for i in range(8)) for a in lands):return False
    for path in L.PATHS:
        if abs(path['z']-z)>.1:continue
        if any(dist_seg((x,y),a,b)<path['width']/2+r+2 for a,b in zip(path['points'],path['points'][1:])):return False
    for d in L.DISKS:
        if abs(d['z']-z)<3 and math.dist((x,y),d['center'])<d['radius']+r+2:return False
    for b in L.BUILDINGS:
        if math.dist((x,y),b['center'])<max(b['size'][:2])*.8+r+4:return False
    for s in L.STANDS:
        if math.dist((x,y),s['center'])<17+r:return False
    if z==-20 and any(dist_seg((x,y),a,b)<r+5 for a,b in CONVEYORS):return False
    if any(math.dist((x,y),p)<r+rr+1 for p,rr in used):return False
    return True

def scatter():
    rr=random.Random(7);used=[]
    for si,s in enumerate(L.SCATTER):
        if s['kind'] in ('bin','crate','cullet'):continue
        placed=0
        for j in range(s['count']*30):
            if placed>=s['count']:break
            a=rr.random()*math.tau;r=s['radius']*math.sqrt(rr.random());x=s['center'][0]+math.cos(a)*r;y=s['center'][1]+math.sin(a)*r
            radius=5 if s['kind']=='pine' else 6
            if not safe_prop(x,y,s['z'],radius,used):continue
            sz=rr.uniform(.8,1.2);place(s['kind'],f'Tree_{si}_{placed}',(x,y,s['z']),rr.uniform(0,360),(sz,sz,sz));used.append(((x,y),radius));placed+=1
    # Frame outer edges with a continuous but varied treeline.
    for x in range(-464,-394,22):
        for y in range(-352,96,26):
            xx=x+rr.uniform(-6,6);yy=y+rr.uniform(-5,5)
            if safe_prop(xx,yy,-20,6,used):
                sz=rr.uniform(.9,1.4);place('pine' if rr.random()<.7 else 'round','Boundary_tree',(xx,yy,-20),rr.random()*360,(sz,sz,sz));used.append(((xx,yy),6))
    # Hills use true layout radius/height with a shaped, faceted profile.
    for i,(x,y,r,h) in enumerate(L.HILLS):
        g=Geo();n=14;vs=[]
        for radius,z in ((r,-20),(r*.88,-20+h*.22),(r*.55,-20+h*.65),(r*.16,-20+h)):
            for j in range(n):
                a=j*math.tau/n;v=1 if z==-20 else rr.uniform(.90,1.1);vs.append((x+radius*math.cos(a)*v,y+radius*math.sin(a)*v,z))
        for k in range(3):
            for j in range(n):g.mesh([vs[k*n+j],vs[k*n+(j+1)%n],vs[(k+1)*n+(j+1)%n],vs[(k+1)*n+j]],[(0,1,2),(0,2,3)],'grassdark' if k<2 else 'grass')
        g.mesh(vs[3*n:], [tuple(range(n))], 'grass');direct(g,'Hill_'+str(i),chunk='terrain')
        g=Geo()
        for j in range(n):
            a=j*math.tau/n;b=(j+1)*math.tau/n
            g.mesh([(x+r*math.cos(a),y+r*math.sin(a),-20),(x+r*math.cos(b),y+r*math.sin(b),-20),(x+r*math.cos(b),y+r*math.sin(b),-60),(x+r*math.cos(a),y+r*math.sin(a),-60)],[(0,1,2),(0,2,3)],'rock')
        direct(g,'Hill_foundation_'+str(i),chunk='terrain')
    # Deliberately spaced cullet mountains, with footprint-aware open sectors.
    s=next(s for s in L.SCATTER if s['kind']=='cullet')
    for i,a in enumerate((103,117,131,225,237,250,263,277,291,305,320,334,347,359,12,23)):
        r=52 if a<140 else (46 if a<320 else 51);x=45+r*math.cos(math.radians(a));y=-335+r*math.sin(math.radians(a))
        if math.dist((x,y),(100,-318))<25:continue
        size=.42 if 225<=a<=320 else .52
        swap={'glassamber':['glassgreen','glassamber','glassclear','glassblue'][i%4]}
        place('cullet_2','Cullet_mountain_'+str(i),(x,y,-20),a,(size,size,.66 if i%3 else .85),chunk='cullet_pit',swap=swap)
    # Small rock/bush clusters fill lawns without occupying the public square.
    for i in range(220):
        x=rr.uniform(-390,170);y=rr.uniform(-380,177);z=0 if point_inside((x,y),L.LAND[0]['points']) else -20
        if safe_prop(x,y,z,3,used):
            kind='bush' if i%3 else 'rock_1';place(kind,'Ground_cluster_'+str(i),(x,y,z),rr.random()*360);used.append(((x,y),3))
    # Shore boulders cluster at the foot of the sea-facing cliffs.
    for land in L.LAND[:2]:
        pts=land['points']
        for ei,(a,b) in enumerate(zip(pts,pts[1:]+pts[:1])):
            if land['id']=='plateau' and ei not in range(1,9):continue
            if land['id']=='yard_terrace' and ei not in (10,11,12):continue
            d=Vector(b)-Vector(a);out=Vector((-d.y,d.x)).normalized()
            for j in range(max(1,int(d.length/24))):
                p=Vector(a)+d*((j+.5)/max(1,int(d.length/24)))+out*6
                place('rock_2','Shore_boulder',(p.x,p.y,-60),rr.random()*360,(1.2,1,1),chunk='cliffs_harbor')

SHOTS={
 'spawn':((0,-168,7),(0,60,26),20,(1600,900)),
 'aerial':((330,-560,330),(-60,-110,-10),30,(1600,1000)),
 'yard':((-150,-230,40),(30,-330,-10),24,(1600,900)),
 'cullet_pit':((-56,-371,16),(45,-335,-8),30,(1600,900)),
 'square':((92,-111,74),(0,8,4),38,(1600,1000)),
 'furnace':((113,-13,73),(0,126,74),27,(1200,1400)),
 'cliffs':((320,265,66),(86,132,-16),36,(1600,1000)),
 'ramp':((-300,-109,38),(-210,-39,-10),38,(1600,1000)),
}
def lighting():
    s=SCENE;w=bpy.data.worlds.new('Kilnport_Afternoon');w.use_nodes=True
    bg=w.node_tree.nodes.get('Background');bg.inputs[0].default_value=(.55,.72,.88,1);bg.inputs[1].default_value=.65;s.world=w
    data=bpy.data.lights.new('Kilnport_Sun','SUN');data.energy=2.5;data.color=(1,.85,.66);data.angle=.12
    ob=bpy.data.objects.new('Kilnport_Sun',data);PREVIEW.objects.link(ob);ob.rotation_euler=(math.radians(48),0,math.radians(-115))
    cam=bpy.data.cameras.new('Kilnport_Camera');ob=bpy.data.objects.new('Kilnport_Camera',cam);PREVIEW.objects.link(ob);s.camera=ob;cam.clip_end=6000;cam.clip_start=.1
    s.render.engine='CYCLES';s.cycles.samples=32;s.cycles.use_denoising=True;s.render.image_settings.file_format='PNG'
    s.view_settings.view_transform='AgX';s.view_settings.look='AgX - Medium High Contrast'
    s.render.film_transparent=False
    set_shot('aerial')

def set_shot(name):
    s=bpy.context.scene;loc,target,lens,res=SHOTS[name];s.camera.location=loc;s.camera.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler();s.camera.data.lens=lens
    s.render.resolution_x,s.render.resolution_y=res;s.render.resolution_percentage=100;s.render.filepath=str(RENDERS/(name+'.png'))

def build():
    if bpy.context.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
    budgets=build_kit();assemble();lighting()
    # A browsable kit showroom; all individual origins remain at base centre.
    # Assembly happens first so these authoring-only display offsets never enter it.
    for i,(key,objects) in enumerate(KIT.items()):
        for ob in objects:ob.location=(i%8*76,-(i//8)*76,0)
    bpy.data.libraries.write(str(OUT/'kit_kilnport.blend'),{KITSCENE},fake_user=True)
    (OUT/'anchors.json').write_text(json.dumps(ANCHORS,indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'layout_kilnport.blend'))
    return {'kit_assets':len(KIT),'objects':len(SCENE.objects),'max_kit_triangles':max(budgets.values()),'file':str(OUT/'layout_kilnport.blend')}

if __name__=='__main__':
    if '--' in sys.argv:
        args=sys.argv[sys.argv.index('--')+1:]
        if args and args[0]=='render':
            bpy.context.window.scene=bpy.data.scenes['Kilnport_Final'];set_shot(args[1]);bpy.ops.render.render(write_still=True)
        else:print(build())
    else:print(build())
