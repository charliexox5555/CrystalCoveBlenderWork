"""Six Commons + three Uncommons. Original toy glass, no branded/alcohol designs.

Load glassclash_blender.py, then call build_collection_glassy(id). Every source scene is
isolated; existing exported manifests are left untouched. All origins are the hang point.
"""
import json
from mathutils import Matrix
from mathutils.bvhtree import BVHTree

WAVE_IDS=("milk_bottle","pickle_jar","glass_cup","ketchup_bottle","water_jug","lemonade_bottle","mason_jar","hot_sauce","crystal_tumbler")
# Closed profiles: round toy containers; cups and jug include inner walls and a solid base.
WAVE_PROFILES={
 "milk_bottle":(2.35,24,[(0,0),(.48,0),(.61,.08),(.65,.22),(.65,1.25),(.61,1.48),(.45,1.73),(.29,1.92),(.29,2.16),(.34,2.2),(0,2.2)]),
 "pickle_jar":(2.05,24,[(0,0),(.65,0),(.8,.08),(.86,.22),(.86,1.38),(.82,1.58),(.75,1.69),(.75,1.82),(0,1.82)]),
 "glass_cup":(1.85,24,[(0,0),(.5,0),(.58,.07),(.6,.24),(.7,1.74),(.7,1.85),(.63,1.85),(.63,1.73),(.53,.23),(.48,.15),(0,.15)]),
 "ketchup_bottle":(2.45,24,[(0,0),(.45,0),(.56,.07),(.6,.2),(.6,1.25),(.55,1.52),(.35,1.8),(.22,1.96),(.22,2.16),(0,2.16)]),
 "water_jug":(2.55,24,[(0,0),(.6,0),(.82,.12),(.9,.48),(.9,1.32),(.8,1.62),(.52,1.98),(.4,2.27),(.46,2.39),(.46,2.55),(.35,2.55),(.32,2.34),(.45,2.0),(.7,1.58),(.79,1.28),(.78,.45),(.58,.2),(0,.2)]),
 "lemonade_bottle":(2.5,24,[(0,0),(.46,0),(.58,.08),(.62,.25),(.62,1.26),(.57,1.5),(.4,1.76),(.25,1.96),(.25,2.28),(0,2.28)]),
 "mason_jar":(2.12,24,[(0,0),(.65,0),(.81,.08),(.86,.2),(.86,.35),(.81,.42),(.81,.55),(.85,.62),(.85,.72),(.81,.79),(.81,1.1),(.85,1.17),(.85,1.27),(.81,1.34),(.81,1.5),(.75,1.7),(.75,1.87),(0,1.87)]),
 "hot_sauce":(2.52,24,[(0,0),(.35,0),(.46,.1),(.5,.25),(.5,1.19),(.45,1.39),(.27,1.6),(.19,1.8),(.19,2.23),(0,2.23)]),
 "crystal_tumbler":(1.95,16,[(0,0),(.55,0),(.7,.1),(.73,.23),(.7,.36),(.66,.43),(.69,1.5),(.75,1.83),(.75,1.95),(.65,1.95),(.6,1.55),(.57,.4),(.5,.27),(0,.27)]),
}


def wave_detail(obj,color,material="SmoothPlastic"):
    obj["studio_color"]=color;obj["studio_material"]=material;obj["asset_role"]="Detail"
    assign_material([obj],preview_solid_material("Wave_"+color,color,metallic=.2 if material=="Metal" else 0,roughness=.24))
    return obj


def wave_sphere(name,at,scale,color):
    bm=bmesh.new();bmesh.ops.create_uvsphere(bm,u_segments=12,v_segments=8,radius=1)
    bmesh.ops.transform(bm,matrix=Matrix.Diagonal((*scale,1)),verts=bm.verts)
    bmesh.ops.translate(bm,verts=bm.verts,vec=at)
    return wave_detail(set_shading(_mesh_object(name,bm),True),color)


def wave_torus(name,centre,rx,rz,tube,color):
    vertices=[];faces=[];major,minor=20,8
    for i in range(major):
        a=i*math.tau/major
        for j in range(minor):
            b=j*math.tau/minor
            vertices.append((centre[0]+(rx+tube*math.cos(b))*math.cos(a),centre[1]+tube*math.sin(b),centre[2]+(rz+tube*math.cos(b))*math.sin(a)))
    for i in range(major):
        for j in range(minor): faces.append((i*minor+j,((i+1)%major)*minor+j,((i+1)%major)*minor+(j+1)%minor,i*minor+(j+1)%minor))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    return wave_detail(set_shading(_link(bpy.data.objects.new(name,mesh)),True),color,"Glass")


def wave_details(gid,hang):
    details=[]
    caps={"milk_bottle":(.34,2.2,2.35,"#6FB6E8"),"pickle_jar":(.87,1.82,2.05,"#78B856"),
          "ketchup_bottle":(.28,2.16,2.45,"#FFD166"),"lemonade_bottle":(.3,2.28,2.5,"#69C474"),
          "mason_jar":(.87,1.87,2.12,"#E8BB57"),"hot_sauce":(.25,2.23,2.52,"#34405D")}
    if gid in caps:
        radius,lo,hi,color=caps[gid]
        cap=lathe("Cap",[(0,lo),(radius*.9,lo),(radius,lo+.035),(radius,hi-.035),(radius*.9,hi),(0,hi)],segments=24,hang_z=hang)
        details.append(wave_detail(cap,color,"Metal" if gid=="mason_jar" else "SmoothPlastic"))
    if gid=="pickle_jar":
        for i,(x,y) in enumerate(((-.34,-.1),(.3,-.1),(0,.32))):
            details.append(wave_sphere(f"Pickle_{i+1}",(x,y,.88-hang),(.19,.2,.6),"#68A944"))
    elif gid=="water_jug":
        details.append(wave_torus("Handle",(-.83,0,1.38-hang),.4,.65,.12,"#BFEFFF"))
    elif gid in ("milk_bottle","ketchup_bottle","hot_sauce"):
        radius={"milk_bottle":.655,"ketchup_bottle":.605,"hot_sauce":.505}[gid]
        low,high=(.58,1.08) if gid!="hot_sauce" else (.45,.95)
        label=lathe("Label",[(radius,low),(radius+.008,low),(radius+.008,high),(radius,high),(radius,low)],segments=24,hang_z=hang)
        details.append(wave_detail(label,"#FFF4D9"))
        if gid=="ketchup_bottle": details.append(wave_sphere("Tomato",(.05,-.61,.82-hang),(.18,.035,.16),"#E85142"))
        elif gid=="hot_sauce": details.append(wave_sphere("Pepper",(.03,-.515,.69-hang),(.09,.03,.2),"#EA6543"))
    elif gid=="lemonade_bottle":
        details.append(wave_sphere("LemonRind",(.1,-.61,.9-hang),(.27,.035,.27),"#F6CA44"))
        details.append(wave_sphere("LemonPulp",(.1,-.646,.9-hang),(.22,.018,.22),"#FFF18A"))
    elif gid in ("glass_cup","crystal_tumbler"):
        radius=.68 if gid=="glass_cup" else .73
        details.append(wave_torus("Rim",(0,0,0),radius,radius,.025,"#D7E9FF"))
        # Torus helper is XZ-oriented; a cup rim must be horizontal at the hang point.
        obj=details[-1]
        transform=Matrix.Rotation(math.pi/2,4,"X")
        for v in obj.data.vertices: v.co=transform@v.co
        for v in obj.data.vertices: v.co.z-=.025
    for obj in details: obj["glassy_id"]=gid
    return details


def wave_cracks(body):
    lines=[(.43,.12,.49,.32),(.49,.32,.39,.48),(.39,.48,.53,.69),(.53,.69,.46,.9),(.49,.32,.64,.25),(.39,.48,.25,.54),
           (.53,.69,.72,.61),(.64,.25,.71,.12),(.25,.54,.18,.74),(.49,.32,.59,.47),(.59,.47,.75,.51),(.46,.9,.29,.8),
           (.53,.69,.63,.84),(.39,.48,.28,.32),(.28,.32,.18,.27),(.59,.47,.66,.36),(.46,.9,.51,.98),(.72,.61,.81,.71)]
    vertices=[body.matrix_world@v.co for v in body.data.vertices]
    tree=BVHTree.FromPolygons(vertices,[list(p.vertices) for p in body.data.polygons])
    lo,hi=_world_bounds([body]);out=[]
    for side in (-1,1):
        for i,(x1,y1,x2,y2) in enumerate(lines):
            points=[]
            for n in range(5):
                t=n/4;x=lo.x+(hi.x-lo.x)*(x1+(x2-x1)*t);z=hi.z-(hi.z-lo.z)*(y1+(y2-y1)*t)
                hit,normal,_,_=tree.ray_cast(Vector((x,side*(max(abs(lo.y),abs(hi.y))+1),z)),Vector((0,-side,0)))
                if hit is not None:
                    hit+=normal*.006;points.append((hit.x,hit.z,-hit.y))
                else: points.append(None)
            for a,b in zip(points,points[1:]):
                if a is not None and b is not None:out.append([round(v,6) for v in (*a,*b,i//6+1)])
    return out


def wave_closed(obj):
    bm=_bm_from_object(obj)
    result={"boundary_edges":sum(e.is_boundary for e in bm.edges),"nonmanifold_edges":sum(not e.is_manifold for e in bm.edges),"volume":round(_volume(bm),6)}
    bm.free();return result


def write_wave_cracks():
    text=["--!strict","-- Generated from the original non-starter body surfaces by build_collection_wave.py.","return {"]
    report={}
    for gid in WAVE_IDS:
        path=repo_path("assets","blender","glassies",gid,"cracks.json")
        if not os.path.exists(path):continue
        rows=json.load(open(path,encoding="utf-8"));report[gid]=len(rows)
        text.append("\t"+gid+" = {")
        text.extend("\t\t{"+", ".join(str(v) for v in row)+"}," for row in rows)
        text.append("\t},")
    text.append("}")
    with open(repo_path("src","shared","Config","CrackPathsExtra.luau"),"w",encoding="utf-8") as f:f.write("\n".join(text)+"\n")
    return report


def wave_cut(bm,co,no,inner):
    """Triangulate the whole cut boundary together, preserving holes in hollow glass."""
    piece=bm.copy()
    bmesh.ops.bisect_plane(piece,geom=piece.verts[:]+piece.edges[:]+piece.faces[:],plane_co=co,plane_no=no,clear_outer=inner,clear_inner=not inner)
    edges=[e for e in piece.edges if e.is_boundary]
    if edges:bmesh.ops.triangle_fill(piece,edges=edges,use_beauty=True)
    bmesh.ops.recalc_face_normals(piece,faces=piece.faces)
    return piece


def build_collection_glassy(gid,repair=False):
    global COLLECTION
    assert gid in WAVE_IDS
    folder=repo_path("assets","blender","glassies",gid);manifest=os.path.join(folder,"manifest.json")
    if os.path.exists(manifest) and not repair:return json.load(open(manifest,encoding="utf-8"))
    previous_scene,previous_collection=bpy.context.window.scene,COLLECTION
    scene=bpy.data.scenes.new("Collection_"+gid);scene.unit_settings.system="NONE";scene.unit_settings.scale_length=1
    bpy.context.window.scene=scene;COLLECTION=scene.name
    try:
        hang,segments,profile=WAVE_PROFILES[gid]
        body=lathe("Body",profile,segments,flat=False,hang_z=hang);body["glassy_id"]=gid
        details=wave_details(gid,hang);shards=make_shards(body,16,seed=sum(map(ord,gid)),cut=wave_cut)
        assert len(shards)==16,"Incomplete fracture"
        checks={"Body":wave_closed(body),**{f"Shard_{i+1:02d}":wave_closed(s) for i,s in enumerate(shards)}}
        assert all(c["nonmanifold_edges"]==0 and c["volume"]>0 for c in checks.values()),checks
        ratio=sum(c["volume"] for name,c in checks.items() if name!="Body")/checks["Body"]["volume"]
        assert abs(ratio-1)<.001,("Fracture volume drift",ratio)
        tris=sum(len(p.vertices)-2 for p in body.data.polygons)
        assert tris<=1500,"Body budget"
        cracks=wave_cracks(body);assert len(cracks)>=72,"Insufficient crack paths"
        out=export_glassy(gid,body,shards,details=details)
        with open(os.path.join(folder,"cracks.json"),"w",encoding="utf-8") as f:json.dump(cracks,f)
        report={"id":gid,"hang_origin":[0,0,0],"body_triangles":tris,"shards":len(shards),"crack_segments":len(cracks),"fracture_volume_ratio":ratio,"checks":checks,
                "details":[{"name":d.name,"color":d["studio_color"],"material":d["studio_material"]} for d in details],"files":out}
        with open(manifest,"w",encoding="utf-8") as f:json.dump(report,f,indent=2)
        for obj in [body,*shards,*details]:obj.name=gid+"_"+obj.name
        write_wave_cracks()
        return report
    finally:
        bpy.context.window.scene=previous_scene;COLLECTION=previous_collection
