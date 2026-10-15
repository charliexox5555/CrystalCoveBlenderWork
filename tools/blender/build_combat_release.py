"""Original release-v2 production. Load the existing helper, then this file in Blender.

build_release_asset(id) never overwrites an existing package. Each asset lives in its
own scene. Source geometry, preview rig, fracture and import metadata are saved.
"""
import hashlib
import json
from mathutils import Matrix
from mathutils.bvhtree import BVHTree

RELEASE = json.load(open(repo_path('docs','design','RELEASE_ROSTER_24.json'), encoding='utf-8'))
ROWS = {r['id']: r for r in RELEASE['roster']}
VERSION = 'release_v2'
# New profiles deliberately change shoulders, foot, rim and body proportions.
# Radius / height; caps, weapon pieces and charge details are separate meshes.
PROFILES = {
 'pop': (2.55,20,[(0,0),(.45,0),(.60,.07),(.65,.20),(.64,.34),(.60,.42),(.60,1.36),(.58,1.50),(.49,1.68),(.31,1.88),(.245,2.04),(.245,2.25),(.30,2.29),(.30,2.35),(0,2.35)]),
 'jam': (2.05,24,[(0,0),(.67,0),(.85,.08),(.94,.24),(.95,.42),(.95,1.26),(.91,1.46),(.79,1.60),(.79,1.69),(.90,1.72),(.90,1.80),(0,1.80)]),
 'prism': (2.60,8,[(0,0),(.48,0),(.66,.12),(.81,.40),(.81,1.18),(.72,1.34),(.42,1.58),(.24,1.75),(.24,1.91),(.31,1.96),(0,1.96)]),
 'crescent_axe':(2.40,16,[(0,0),(.52,0),(.77,.13),(.89,.43),(.85,1.08),(.65,1.39),(.30,1.61),(.27,1.90),(.36,1.96),(0,1.96)]),
 'briar_flask':(2.65,20,[(0,0),(.35,.03),(.60,.21),(.79,.56),(.80,.82),(.69,1.20),(.48,1.56),(.24,1.91),(.21,2.18),(.28,2.23),(0,2.23)]),
 'arc_coil':(2.30,20,[(0,0),(.49,0),(.70,.13),(.87,.43),(.91,.78),(.83,1.12),(.61,1.41),(.33,1.57),(.30,1.88),(0,1.88)]),
 'milk_bottle':(2.48,20,[(0,0),(.47,0),(.62,.08),(.68,.24),(.68,1.27),(.65,1.48),(.54,1.68),(.37,1.85),(.30,2.01),(.30,2.20),(.37,2.23),(.37,2.30),(0,2.30)]),
 'pickle_jar':(2.20,20,[(0,0),(.63,0),(.84,.09),(.93,.28),(.93,1.40),(.87,1.61),(.79,1.73),(.79,1.87),(0,1.87)]),
 'ketchup_bottle':(2.62,20,[(0,0),(.43,0),(.59,.08),(.65,.24),(.61,.84),(.53,1.42),(.41,1.70),(.24,1.94),(.21,2.15),(0,2.15)]),
 'glass_cup':(1.95,24,[(0,0),(.50,0),(.60,.06),(.63,.22),(.74,1.78),(.75,1.90),(.72,1.95),(.63,1.95),(.61,1.84),(.52,.29),(.46,.20),(0,.20)]),
 'water_jug':(2.65,20,[(0,0),(.60,0),(.84,.13),(.96,.46),(.95,1.25),(.85,1.57),(.59,1.91),(.40,2.25),(.47,2.36),(.49,2.57),(.45,2.65),(.33,2.65),(.31,2.38),(.46,1.99),(.74,1.53),(.82,1.23),(.81,.48),(.57,.23),(0,.23)]),
 'lemonade_bottle':(2.60,20,[(0,0),(.45,0),(.60,.08),(.66,.25),(.65,1.18),(.60,1.43),(.45,1.69),(.29,1.94),(.25,2.15),(.25,2.37),(0,2.37)]),
 'mason_jar':(2.25,20,[(0,0),(.62,0),(.83,.08),(.91,.24),(.88,.39),(.85,.46),(.85,1.36),(.89,1.44),(.85,1.54),(.76,1.75),(.76,1.96),(0,1.96)]),
 'hot_sauce':(2.66,20,[(0,0),(.33,0),(.47,.09),(.53,.25),(.51,1.17),(.45,1.40),(.28,1.65),(.19,1.86),(.19,2.34),(0,2.34)]),
 'crystal_tumbler':(2.05,12,[(0,0),(.56,0),(.74,.13),(.77,.29),(.69,.43),(.70,1.58),(.79,1.90),(.79,2.05),(.66,2.05),(.60,1.65),(.56,.39),(.48,.25),(0,.25)]),
 'chime':(2.50,20,[(0,0),(.91,0),(.99,.11),(.94,.26),(.73,.55),(.61,1.20),(.49,1.61),(.29,1.91),(.25,2.30),(0,2.30)]),
 'hourglass':(2.65,20,[(0,.15),(.68,.15),(.75,.29),(.66,.62),(.43,.92),(.19,1.22),(.17,1.36),(.39,1.68),(.66,2.05),(.75,2.34),(.68,2.49),(0,2.49)]),
 'frostglobe':(2.40,20,[(0,.25),(.48,.25),(.73,.42),(.91,.75),(.95,1.10),(.88,1.49),(.66,1.82),(.34,2.05),(0,2.13)]),
 'rocket_pop':(2.70,20,[(0,0),(.40,0),(.55,.12),(.61,.30),(.61,1.34),(.53,1.61),(.31,1.93),(.24,2.16),(.30,2.24),(.30,2.49),(0,2.49)]),
 'glass_duck':(2.40,20,[(0,.10),(.48,.10),(.77,.30),(.93,.62),(.89,.94),(.65,1.17),(.37,1.35),(.47,1.49),(.54,1.72),(.48,2.02),(.26,2.28),(0,2.40)]),
 'comet':(2.45,20,[(0,.10),(.43,.10),(.70,.31),(.84,.68),(.82,1.08),(.63,1.42),(.38,1.64),(.25,1.82),(.15,2.05),(0,2.45)]),
 'glass_dragon':(3.00,20,[(0,0),(.32,.04),(.60,.22),(.69,.59),(.64,.97),(.42,1.23),(.32,1.51),(.46,1.71),(.65,1.95),(.69,2.28),(.55,2.63),(.28,2.88),(0,3.00)]),
 'galaxy_orb':(2.40,20,[(0,0),(.37,.06),(.67,.27),(.88,.63),(.96,1.08),(.90,1.53),(.69,1.91),(.38,2.18),(0,2.27)]),
}
TINTS={'crescent_axe':'#B69BFF','briar_flask':'#35CB97','arc_coil':'#6BE9FF','chime':'#80E7DE','hourglass':'#F8C16B','frostglobe':'#9ECFFF'}

def rmaterial(obj, color, material='Glass', role='Detail'):
    obj['studio_color']=color; obj['studio_material']=material; obj['asset_role']=role
    obj['studio_transparency']=.28 if material=='Glass' else 0
    mat=glossy_preview_material('Release_'+color,color) if material=='Glass' else preview_solid_material('ReleaseSolid_'+color,color,roughness=.24,metallic=.35 if material=='Metal' else 0)
    if material=='Glass':
        node=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        _set_input(node,'Transmission Weight',.85 if role in ('Body','Shard') else .52)
        _set_input(node,'Roughness',.07 if role in ('Body','Shard') else .12)
        _set_input(node,'Alpha',.72 if role in ('Body','Shard') else 1.0)
    assign_material([obj],mat)
    return obj

def rsphere(name, at, scale, color, material='Glass', segments=12, rings=8):
    bm=bmesh.new(); bmesh.ops.create_uvsphere(bm,u_segments=segments,v_segments=rings,radius=1)
    bmesh.ops.transform(bm,matrix=Matrix.Diagonal((*scale,1)),verts=bm.verts)
    bmesh.ops.translate(bm,verts=bm.verts,vec=at)
    return rmaterial(set_shading(_mesh_object(name,bm),True),color,material)

def rlathe(name, profile, hang, color, segments=20, material='Glass'):
    return rmaterial(lathe(name,profile,segments=segments,hang_z=hang),color,material)

def rring(name, centre, radius, tube, color, axis='Z', arc=math.tau, steps=20):
    vs=[]; fs=[]; minor=4
    closed=abs(arc-math.tau)<.001
    for i in range(steps if closed else steps+1):
        a=i*arc/steps
        for j in range(minor):
            b=j*math.tau/minor
            p=Vector(((radius+tube*math.cos(b))*math.cos(a),(radius+tube*math.cos(b))*math.sin(a),tube*math.sin(b)))
            if axis=='Y': p=Matrix.Rotation(math.pi/2,3,'X')@p
            vs.append(tuple(p+Vector(centre)))
    for i in range(steps):
        for j in range(minor):fs.append((i*minor+j,((i+1)%(steps if closed else steps+1))*minor+j,((i+1)%(steps if closed else steps+1))*minor+(j+1)%minor,i*minor+(j+1)%minor))
    if not closed:fs.extend([tuple(reversed(range(minor))),tuple(steps*minor+j for j in range(minor))])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],fs);mesh.update()
    return rmaterial(set_shading(_link(bpy.data.objects.new(name,mesh)),True),color)

def rpoly(name, points, depth, color, y=0, material='Glass', bevel=.03):
    # Closed extruded XZ silhouette. Bevel gives a large intentional highlight.
    n=len(points);vs=[(x,y+d,z) for d in (-depth/2,depth/2) for x,z in points]
    fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],fs);mesh.update()
    obj=_link(bpy.data.objects.new(name,mesh));bm=_bm_from_object(obj)
    bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
    if bevel:bmesh.ops.bevel(bm,geom=list(bm.edges),offset=bevel,segments=1,affect='EDGES')
    bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
    return rmaterial(obj,color,material)

def release_details(gid,h):
    ds=[]; tint=TINTS.get(gid,glassy_tint(gid)); white='#EAFBFF'; gold='#F5C860'
    caps={'pop':(.32,2.35,2.55,'#ED5367'),'jam':(.98,1.80,2.05,gold),'milk_bottle':(.37,2.30,2.48,'#8DCFFF'),'pickle_jar':(.96,1.87,2.20,'#76B867'),'ketchup_bottle':(.28,2.15,2.38,'#F8D76D'),'lemonade_bottle':(.30,2.37,2.60,'#6CD381'),'mason_jar':(.90,1.96,2.25,gold),'hot_sauce':(.25,2.34,2.66,'#354865'),'arc_coil':(.39,1.88,2.18,'#D99561'),'rocket_pop':(.32,2.49,2.70,'#ED5367')}
    if gid in caps:
        r,a,b,c=caps[gid];ds.append(rlathe('Cap',[(0,a),(r*.87,a),(r,a+.04),(r,b-.04),(r*.87,b),(0,b)],h,c,20,'Metal' if gid in ('jam','mason_jar','arc_coil') else 'SmoothPlastic'))
        if gid in ('jam','mason_jar'):
            ds.append(rring('LidRidge',(0,0,(a+b)/2-h),r+.012,.035,gold,steps=24))
            ds[-2]['animation_pivot']=[0,0,(a+b)/2-h]
    if gid=='pop':
        for i,(x,z,r) in enumerate(((-.23,.66,.18),(.19,1.02,.22),(-.10,1.37,.17))):ds.append(rsphere('ChargeBubble_'+str(i+1),(x,-.49,z-h),(r,.12,r),white))
    elif gid=='jam':
        ds.append(rsphere('JamInsert',(0,0,.68-h),(.73,.73,.51),'#F28FAE'))
    elif gid=='prism':
        ds.append(rlathe('GemStopper',[(0,1.94),(.20,1.94),(.40,2.12),(.43,2.24),(.24,2.50),(0,2.60)],h,'#D7BBFF',8))
        ds.append(rsphere('RayLens',(0,-.78,.92-h),(.28,.065,.30),'#B9F4FF',segments=8,rings=6))
    elif gid=='crescent_axe':
        ds.append(rring('CrescentStopper',(0,0,2.15-h),.22,.09,'#E2DBFF',axis='Y',arc=math.pi*1.5,steps=12))
        ds.append(rpoly('AxeHandle',[(.88,-1.9),(1.04,-1.9),(1.04,-.60),(.88,-.60)],.18,'#9BCDEB',bevel=.025))
        ds.append(rpoly('AxeHead',[(.94,-.74),(1.20,-.45),(1.57,-.39),(1.75,-.57),(1.61,-.95),(1.27,-1.20),(.95,-1.03)],.23,'#D2CBFF',bevel=.07))
        for obj in ds[1:]:obj['animation_pivot']=[.96,0,-1.70];obj['effect_only']=True
    elif gid=='briar_flask':
        ds.append(rpoly('LeafStopper',[(-.09,2.20-h),(-.30,2.44-h),(-.18,2.60-h),(.14,2.65-h),(.20,2.40-h),(.08,2.21-h)],.18,'#8EEDB2'))
        ds.append(rsphere('RoseSeed',(0,-.70,.80-h),(.24,.10,.30),'#F18EBB'))
        for i in range(3):
            thorn=rpoly('Thorn_'+str(i+1),[(.63,-1.58),(.67,-1.32),(1.08,-.93),(.98,-1.51),(.83,-1.68)],.20,'#A0F7CC')
            rot=Matrix.Rotation(i*math.tau/3,3,'Z')
            for v in thorn.data.vertices:v.co=rot@v.co
            thorn['animation_pivot']=list(rot@Vector((.64,0,-1.5))); ds.append(thorn)
    elif gid=='arc_coil':
        for i in range(3):ds.append(rring('CoilSegment_'+str(i+1),(0,0,.72+i*.27-h),.94-i*.065,.07,'#BBFAFF',arc=5.3,steps=14))
        ds.append(rsphere('Terminal',(0,0,2.24-h),(.16,.16,.13),white))
    elif gid=='milk_bottle':
        ds.append(rlathe('MilkInsert',[(0,.19),(.52,.19),(.55,1.34),(.47,1.53),(0,1.53)],h,'#FFF6DD',16,'SmoothPlastic'))
        ds.append(rring('FoamRim',(0,0,2.15-h),.32,.075,white))
        for i in range(3):ds.append(rsphere('FoamBubble_'+str(i+1),((i-1)*.17,-.25,2.19-h),(.09,.08,.09),white,segments=8,rings=6))
    elif gid=='pickle_jar':
        for i in range(2):ds.append(rsphere('Pickle_'+str(i+1),((i-.5)*.62,-.21,.92-h),(.24,.24,.66),'#71B545',segments=10,rings=7))
    elif gid=='ketchup_bottle':
        ds.append(rlathe('SqueezeNozzle',[(0,2.36),(.15,2.36),(.13,2.54),(.07,2.62),(0,2.62)],h,'#F8D76D',12,'SmoothPlastic'))
        ds.append(rsphere('TomatoBadge',(0,-.60,.82-h),(.28,.045,.23),'#EE7964','SmoothPlastic'))
    elif gid in ('glass_cup','crystal_tumbler'):
        ds.append(rring('ThickRim',(0,0,-.05),.69 if gid=='glass_cup' else .72,.055,white,steps=24))
        if gid=='crystal_tumbler':ds.append(rpoly('MirrorFacet',[(-.27,-1.54),(.27,-1.54),(.32,-.45),(-.32,-.45)],.045,'#C4E9FF',y=-.66,bevel=.02))
    elif gid=='water_jug':
        ds.append(rring('Handle',(-.88,0,1.30-h),.49,.14,'#BDEBFF',axis='Y',steps=16))
        # Elliptical handle follows jug shoulder instead of a circular wire.
        for v in ds[-1].data.vertices:v.co.z=(v.co.z-(1.30-h))*1.35+(1.30-h)
        ds.append(rlathe('WaterInsert',[(0,.26),(.67,.26),(.79,.52),(.79,1.12),(0,1.12)],h,'#51BFF2',16))
    elif gid=='lemonade_bottle':
        ds.append(rsphere('LemonRind',(.12,-.60,1.24-h),(.32,.06,.32),'#EABF3D','SmoothPlastic'))
        ds.append(rsphere('LemonPulp',(.12,-.66,1.24-h),(.25,.025,.25),'#FFF0A2','SmoothPlastic',segments=10,rings=6))
    elif gid=='mason_jar':
        for i in range(2):ds.append(rring('StressBand_'+str(i+1),(0,0,.57+i*.62-h),.86,.035,'#C3F9ED'))
    elif gid=='hot_sauce':
        for i in range(3):ds.append(rsphere('Ember_'+str(i+1),((i-1)*.23,-.46,.86-h),(.09,.055,.12),'#FFBD62','SmoothPlastic',segments=8,rings=6))
    elif gid=='chime':
        ds.append(rsphere('Clapper',(0,-.29,.30-h),(.24,.24,.29),'#F8E6B0'))
        ds.append(rring('BellRim',(0,0,.12-h),.94,.075,'#C5FFF5',steps=24))
        ds.append(rlathe('Crown',[(0,2.29),(.23,2.29),(.27,2.39),(.18,2.50),(0,2.50)],h,'#C5FFF5',12))
    elif gid=='hourglass':
        for z in (.02,2.49):ds.append(rlathe('FrameCap',[(0,z),(.76,z),(.82,z+.05),(.82,z+.11),(.75,z+.16),(0,z+.16)],h,'#AD91DC',16))
        for x in (-.73,.73):ds.append(rmaterial(chamfer_box('FramePost',(.13,.18,2.32),(x,.12,1.33-h),.025),'#AD91DC'))
        ds.append(rlathe('SandInsert',[(0,.30),(.56,.30),(.38,.67),(0,.92)],h,'#F6D36E',12,'SmoothPlastic'))
        ds.append(rlathe('SandStream',[(0,.90),(.035,.90),(.035,1.82),(0,1.82)],h,'#F6D36E',8,'SmoothPlastic'))
    elif gid=='frostglobe':
        ds.append(rlathe('SnowCollar',[(0,0),(.72,0),(.80,.10),(.78,.24),(.66,.31),(0,.31)],h,white,20,'SmoothPlastic'))
        ds.append(rpoly('CrystalSprout',[(-.37,.47-h),(-.23,1.13-h),(-.08,.83-h),(0,1.52-h),(.19,1.05-h),(.32,1.21-h),(.38,.47-h)],.22,'#C8F7FF'))
        ds.append(rsphere('HangPearl',(0,0,2.28-h),(.13,.13,.12),white))
    elif gid=='rocket_pop':
        for i in range(3):
            fin=rpoly('RocketFin_'+str(i+1),[(.45,-2.35),(.95,-2.55),(.88,-1.91),(.50,-1.55)],.16,'#ED5367',material='SmoothPlastic',bevel=.04)
            rot=Matrix.Rotation(i*math.tau/3,3,'Z')
            for v in fin.data.vertices:v.co=rot@v.co
            ds.append(fin)
        ds.append(rlathe('BoosterNozzle',[(0,0),(.38,0),(.40,.14),(.27,.25),(0,.25)],h,'#C0D9EF',12,'Metal'))
    elif gid=='glass_duck':
        ds.append(rsphere('Beak',(0,-.52,1.76-h),(.42,.34,.15),'#FFBB58','SmoothPlastic'))
        for x in (-.23,.23):ds.append(rsphere('Eye',(x,-.45,2.04-h),(.06,.045,.075),'#344566','SmoothPlastic',segments=8,rings=6))
        for x in (-.76,.76):ds.append(rsphere('Wing',(x,0,.77-h),(.15,.39,.31),'#FFE49A'))
        ds.append(rsphere('CrownBubble',(0,0,2.40-h),(.15,.15,.15),white))
    elif gid=='comet':
        ds.append(rpoly('Tail',[(-.33,-1.16),(-1.10,-.60),(-.80,-.52),(-1.35,.04),(-.39,-.37),(.14,-.85)],.21,'#B9EBFF',bevel=.04))
        ds.append(rsphere('StarCore',(0,-.68,.78-h),(.26,.08,.26),'#FFD57D'))
    elif gid=='glass_dragon':
        ds.append(rsphere('Snout',(0,-.55,2.12-h),(.46,.48,.27),'#89E6BC'))
        for x in (-.28,.28):ds.append(rsphere('Eye',(x,-.58,2.51-h),(.07,.055,.09),'#304B5C','SmoothPlastic',segments=8,rings=6))
        for side in (-1,1):
            pts=[(side*x,z) for x,z in ((.46,-1.65),(1.16,-1.34),(1.47,-.64),(1.10,-.89),(.92,-.57),(.70,-1.03),(.38,-.97))]
            wing=rpoly('Wing',pts,.16,'#67D5AA',y=.12,bevel=.035);wing['animation_pivot']=[side*.43,.12,-1.5];ds.append(wing)
        ds.append(rring('CurledTail',(0,.45,.48-h),.43,.18,'#76DFB3',axis='Y',arc=5.4,steps=14))
        ds.append(rsphere('Jaw',(0,-.57,1.91-h),(.38,.36,.12),'#C8F8D9'))
        ds[-1]['animation_pivot']=[0,-.28,1.97-h]
    elif gid=='galaxy_orb':
        ds.append(rlathe('HangCrown',[(0,2.24),(.14,2.24),(.14,2.40),(0,2.40)],h,'#BBA7F6',12))
        ds.append(rsphere('OffsetStarCore',(.26,-.35,1.20-h),(.30,.22,.30),'#FFE8A9'))
        for i in range(2):
            band=rring('OrbitBand_'+str(i+1),(0,0,1.12-h),1.12,.085,'#BBA7F6',steps=24)
            centre=Vector((0,0,1.12-h));rot=Matrix.Rotation((.5 if i==0 else -.6),3,'X')
            for v in band.data.vertices:v.co=rot@(v.co-centre)+centre
            ds.append(band)
    elif gid=='prism_blade':
        ds.append(rpoly('Crossguard',[(-.64,-.46),(-.61,-.25),(.61,-.25),(.64,-.46),(.27,-.53),(-.27,-.53)],.24,'#A7DAF6',bevel=.05))
        ds.append(rlathe('Hilt',[(0,2.50),(.14,2.50),(.14,2.90),(.21,2.95),(0,3.05)],3.05,'#A7DAF6',12))
    for d in ds:d['glassy_id']=gid;d['source_name']=d.name
    return ds

def rclosed(obj):
    bm=_bm_from_object(obj);result={'boundary_edges':sum(e.is_boundary for e in bm.edges),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),'volume':_volume(bm)};bm.free();return result

def rcut(bm,co,no,inner):
    piece=bm.copy();bmesh.ops.bisect_plane(piece,geom=piece.verts[:]+piece.edges[:]+piece.faces[:],plane_co=co,plane_no=no,clear_outer=inner,clear_inner=not inner)
    edges=[e for e in piece.edges if e.is_boundary]
    if edges:bmesh.ops.triangle_fill(piece,edges=edges,use_beauty=True)
    # Plane cuts through a vertex can leave a loose edge after cap triangulation.
    # Those wires have no surface/volume and must not escape to a shard export.
    wires=[e for e in piece.edges if not e.link_faces]
    if wires:bmesh.ops.delete(piece,geom=wires,context='EDGES')
    bmesh.ops.recalc_face_normals(piece,faces=piece.faces);return piece

def rcracks(body):
    tree=BVHTree.FromPolygons([v.co for v in body.data.vertices],[list(p.vertices) for p in body.data.polygons]);lo,hi=_world_bounds([body]);rows=[]
    # Branching paths reprojected to each revised surface, in Roblox hang space.
    lines=[(.43,.16,.49,.32),(.49,.32,.39,.48),(.39,.48,.53,.69),(.53,.69,.46,.90),(.49,.32,.65,.25),(.39,.48,.25,.54),(.53,.69,.72,.61),(.65,.25,.71,.12),(.25,.54,.18,.74),(.49,.32,.59,.47),(.59,.47,.75,.51),(.46,.90,.29,.80),(.53,.69,.63,.84),(.39,.48,.28,.32),(.28,.32,.18,.27),(.59,.47,.66,.36),(.46,.90,.51,.98),(.72,.61,.81,.71)]
    for side in (-1,1):
        for i,(x1,z1,x2,z2) in enumerate(lines):
            points=[]
            for j in range(5):
                t=j/4;x=lo.x+(hi.x-lo.x)*(x1+(x2-x1)*t);z=hi.z-(hi.z-lo.z)*(z1+(z2-z1)*t)
                p,n,_,_=tree.ray_cast(Vector((x,side*(max(abs(lo.y),abs(hi.y))+1),z)),Vector((0,-side,0)))
                if p is not None:p+=n*.006;points.append([p.x,p.z,-p.y])
                else:points.append(None)
            for a,b in zip(points,points[1:]):
                if a is not None and b is not None:rows.append([round(v,6) for v in (*a,*b,i//6+1)])
    return rows

def release_rig(scene,objects,size=512):
    lo,hi=_world_bounds(objects);centre=(lo+hi)/2
    data=bpy.data.cameras.new('ReleaseIconCamera');data.type='ORTHO'
    data.ortho_scale=max(hi.z-lo.z,(hi.x-lo.x)*1.1)*1.24
    cam=bpy.data.objects.new('ReleaseIconCamera',data);scene.collection.objects.link(cam)
    direction=Vector((0,-1,.13)).normalized();cam.location=centre+direction*12
    cam.rotation_euler=(-direction).to_track_quat('-Z','Y').to_euler();scene.camera=cam
    for name,energy,offset,light_size in [('Key',420,(-3,-4,4),4),('Rim',600,(3,2,3),3),('Fill',210,(4,-2,1),4)]:
        ld=bpy.data.lights.new('Release'+name,'AREA');ld.energy=energy;ld.shape='DISK';ld.size=light_size
        ob=bpy.data.objects.new('Release'+name,ld);scene.collection.objects.link(ob);ob.location=centre+Vector(offset);ob.rotation_euler=(centre-ob.location).to_track_quat('-Z','Y').to_euler()
    world=bpy.data.worlds.new('ReleasePreviewWorld');world.use_nodes=True
    world.node_tree.nodes['Background'].inputs['Color'].default_value=(.23,.30,.43,1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value=.65;scene.world=world
    scene.render.engine='CYCLES';scene.cycles.samples=64;scene.cycles.use_denoising=True
    scene.cycles.max_bounces=6;scene.cycles.transmission_bounces=4;scene.cycles.transparent_max_bounces=6
    scene.render.threads_mode='FIXED';scene.render.threads=4
    scene.render.resolution_x=scene.render.resolution_y=size;scene.render.resolution_percentage=100
    scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
    scene.view_settings.view_transform='AgX'

def raudit_old(gid):
    path=repo_path('assets','blender','glassies',gid,gid+'.blend')
    if not os.path.exists(path):return None
    out=repo_path('assets','icons',VERSION,'before',gid+'.png');os.makedirs(os.path.dirname(out),exist_ok=True)
    previous=bpy.context.window.scene
    with bpy.data.libraries.load(path,link=False) as (avail,loaded):loaded.scenes=avail.scenes
    scene=loaded.scenes[0];bpy.context.window.scene=scene
    try:
        objs=[o for o in scene.objects if o.type=='MESH' and 'Shard' not in o.name]
        for o in scene.objects:o.hide_render=o not in objs
        with bpy.context.temp_override(scene=scene,view_layer=scene.view_layers[0]):
            release_rig(scene,objs);scene.render.filepath=out;bpy.ops.render.render(write_still=True)
        body=next(o for o in objs if o.name.split('.')[0]=='Body')
        return {'source':path,'sha256':hashlib.sha256(open(path,'rb').read()).hexdigest(),'preview':out,'body_triangles':sum(len(p.vertices)-2 for p in body.data.polygons)}
    finally:bpy.context.window.scene=previous

def build_release_asset(gid,repair=False):
    global COLLECTION
    assert gid in ROWS
    folder=repo_path('assets','blender','glassies',gid,VERSION);manifest=os.path.join(folder,'manifest.json')
    if os.path.exists(manifest):
        if not repair:return {'id':gid,'status':'existing package preserved'}
        import shutil
        backup=folder+'_review01';i=1
        while os.path.exists(backup):i+=1;backup=folder+f'_review{i:02d}'
        shutil.copytree(folder,backup)
    os.makedirs(folder,exist_ok=True)
    previous,oldcol=bpy.context.window.scene,COLLECTION
    old=raudit_old(gid)
    scene=bpy.data.scenes.new('ReleaseV2_'+gid);scene.unit_settings.system='NONE';scene.unit_settings.scale_length=1
    bpy.context.window.scene=scene;COLLECTION=scene.name
    try:
        with bpy.context.temp_override(scene=scene,view_layer=scene.view_layers[0]):
            if gid=='prism_blade':
                h=3.05;body=rpoly('Body',[(-.10,-.48),(-.36,-.73),(-.34,-2.38),(0,-3.05),(.34,-2.38),(.36,-.73),(.10,-.48)],.30,glassy_tint(gid),bevel=.065)
            else:
                h,segments,profile=PROFILES[gid];body=lathe('Body',profile,segments=segments,flat=gid in ('prism','crystal_tumbler'),hang_z=h)
                rmaterial(body,TINTS.get(gid,glassy_tint(gid)),role='Body')
            rmaterial(body,TINTS.get(gid,glassy_tint(gid)),role='Body')
            body['glassy_id']=gid;body['asset_role']='Body';body['source_name']='Body'
            details=release_details(gid,h)
            tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in [body,*details])
            budget=3000 if ROWS[gid]['batch']=='D' else 1500
            assert tris<=budget,(gid,'intact budget',tris,budget)
            for attempt in range(8):
                shards=make_shards(body,16,seed=2026+sum(map(ord,gid))+attempt*7919,cut=rcut,min_volume_ratio=.008)
                if len(shards)==16 and all(rclosed(s)['nonmanifold_edges']==0 for s in shards):break
                for s in shards:bpy.data.objects.remove(s,do_unlink=True)
            else:raise AssertionError((gid,'No valid fracture seed'))
            assert len(shards)==16
            checks={o.name:rclosed(o) for o in [body,*shards]}
            assert all(c['nonmanifold_edges']==0 and c['volume']>1e-7 for c in checks.values()),checks
            ratio=sum(rclosed(o)['volume'] for o in shards)/rclosed(body)['volume'];assert abs(ratio-1)<.001,ratio
            for i,s in enumerate(shards):
                s['source_name']=f'Shard_{i+1:02d}';s['asset_role']='Shard';s.hide_render=True;rmaterial(s,body['studio_color'],role='Shard')
            cracks=rcracks(body);assert len(cracks)>20
            paths={}
            for role,obs in [('body',[body]),('details',details),('shards',shards),('bundle',[body,*details,*shards])]:
                path=os.path.join(folder,gid+'_'+role+'.fbx');paths[role]=export_fbx(obs,path)
            icon=repo_path('assets','icons',VERSION,gid+'.png');os.makedirs(os.path.dirname(icon),exist_ok=True)
            release_rig(scene,[body,*details]);scene.render.filepath=icon;bpy.ops.render.render(write_still=True);paths['icon']=icon
            for s in shards:s.hide_set(True)
            paths['blend']=save_blend_copy(os.path.join(folder,gid+'.blend'))
            crackpath=os.path.join(folder,'cracks.json');json.dump(cracks,open(crackpath,'w'),indent=2);paths['cracks']=crackpath
            entries=[]
            for o in [body,*details,*shards]:
                lo,hi=_world_bounds([o]);entries.append({'name':o.name,'source_name':o['source_name'],'role':o['asset_role'],'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),'bounds_blender':[list(lo),list(hi)],'origin':[0,0,0],'color':o['studio_color'],'material':o['studio_material'],'animation_pivot':list(o.get('animation_pivot',[0,0,0])),'effect_only':o.get('effect_only',False)})
            report={'id':gid,'batch':ROWS[gid]['batch'],'version':VERSION,'status':{'exported':True,'blender_validated':True,'studio_imported':False,'uploaded':False,'playtested':False},'units':'1 Blender unit = 1 stud','axis_conversion':'Blender (x,y,z) -> Roblox (x,z,-y)','hang_origin':[0,0,0],'intact_triangles':tris,'triangle_budget':budget,'shard_count':len(shards),'fracture_volume_ratio':ratio,'checks':checks,'crack_segments':len(cracks),'meshes':entries,'files':paths,'hashes':{k:hashlib.sha256(open(p,'rb').read()).hexdigest() for k,p in paths.items()},'before':old,'roblox_ids':{},'remaining_checks':['Roblox FBX import scale/orientation/pivot','Glass material and alpha against live sky','new collision dimensions/live cracks','six-kit live gameplay proof']}
            json.dump(report,open(manifest,'w'),indent=2)
            return {'id':gid,'triangles':tris,'shards':len(shards),'volume_ratio':round(ratio,8),'icon':icon}
    finally:bpy.context.window.scene=previous;COLLECTION=oldcol

def refine_release_preview(gid):
    """Material-only visual revision; preserve first editable source, re-export faithfully."""
    import shutil
    folder=repo_path('assets','blender','glassies',gid,VERSION);path=os.path.join(folder,'manifest.json')
    report=json.load(open(path));source=report['files']['blend']
    backup=os.path.join(folder,gid+'_appearance_before.blend')
    if not os.path.exists(backup):shutil.copy2(source,backup)
    previous=bpy.context.window.scene
    with bpy.data.libraries.load(source,link=False) as (a,l):l.scenes=a.scenes
    scene=l.scenes[0];bpy.context.window.scene=scene
    try:
        with bpy.context.temp_override(scene=scene,view_layer=scene.view_layers[0]):
            meshes=[o for o in scene.objects if o.type=='MESH']
            body=next(o for o in meshes if o.get('asset_role')=='Body')
            for mat in body.data.materials:
                node=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
                _set_input(node,'Transmission Weight',.85);_set_input(node,'Roughness',.07);_set_input(node,'Alpha',.72)
            scene.cycles.samples=64;scene.render.threads_mode='FIXED';scene.render.threads=4
            scene.cycles.max_bounces=6;scene.cycles.transmission_bounces=4;scene.cycles.transparent_max_bounces=6
            scene.render.filepath=report['files']['icon'];bpy.ops.render.render(write_still=True)
            groups={'body':[body],'details':[o for o in meshes if o.get('asset_role')=='Detail'],'shards':[o for o in meshes if o.get('asset_role')=='Shard'],'bundle':meshes}
            for role,obs in groups.items():export_fbx(obs,report['files'][role])
            save_blend_copy(source)
            report['hashes']={k:hashlib.sha256(open(p,'rb').read()).hexdigest() for k,p in report['files'].items()}
            for entry in report['meshes']:entry['name']=next(o.name for o in meshes if o.get('source_name')==entry['source_name'])
            report['preview_material']={'transmission':.85,'roughness':.07,'alpha':.72,'samples':64,'roblox_material_parity_verified':False}
            report.pop('fbx_roundtrip',None)
            json.dump(report,open(path,'w'),indent=2)
            return {'id':gid,'preview_refined':True}
    finally:bpy.context.window.scene=previous
