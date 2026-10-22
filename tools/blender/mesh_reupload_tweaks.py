# Rebuilds one of the three meshes Roblox moderation rejected (docs/testing/mesh_reupload/REPORT.md) with small
# shape tweaks, keeps its exact bounds (so the MeshPart Size/CFrame stay valid) and exports it alone with the
# Glass Clash helper (1 unit = 1 stud, transforms applied, -Z forward / Y up) into assets/blender/mesh_reupload.
#   Blender -b -P tools/blender/mesh_reupload_tweaks.py -- phoenix|crank|ponycore
import bpy, bmesh, sys, json, math, os, mathutils
GCROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),"..",".."))
exec(open(GCROOT+"/tools/blender/glassclash_blender.py").read()); set_repo(GCROOT)
which=sys.argv[sys.argv.index("--")+1]
SRC={"phoenix":("assets/blender/glassies/glass_phoenix/v4/glass_phoenix.blend","Body","glass_phoenix_body"),
     "crank":("assets/blender/round_cosmetics/finishers_v4/finishers_v4.blend","FV4_GumballCrank","fv4_gumball_crank"),
     "ponycore":("assets/blender/round_cosmetics/flyers_v3/carousel/carousel.blend","PonyCore","carousel_ponycore")}
blend,name,stem=SRC[which]
bpy.ops.wm.open_mainfile(filepath=os.path.join(GCROOT,blend))
o=bpy.data.objects[name]
def bounds(me): 
    cs=[v.co for v in me.vertices]; return [min(c[i] for c in cs) for i in range(3)],[max(c[i] for c in cs) for i in range(3)]
mn0,mx0=bounds(o.data); tris0=sum(len(p.vertices)-2 for p in o.data.polygons)
def apply_mod(ob,typ,**kw):
    m=ob.modifiers.new("tmp",typ)
    for k,v in kw.items(): setattr(m,k,v)
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True); bpy.context.view_layer.objects.active=ob
    bpy.ops.object.modifier_move_to_index(modifier="tmp",index=0)
    bpy.ops.object.modifier_apply(modifier="tmp")
notes=[]
if which=="phoenix":
    # The body was two mirrored halves never welded: a slit ran down the middle. Voxel-remesh fuses
    # them into one closed shell, a light smooth eases the neck pinch, decimate returns to ~1000 tris.
    apply_mod(o,"REMESH",mode="VOXEL",voxel_size=0.012,adaptivity=0.0,use_smooth_shade=True)
    apply_mod(o,"SMOOTH",factor=0.5,iterations=4)
    t=sum(len(p.vertices)-2 for p in o.data.polygons)*1.0
    apply_mod(o,"DECIMATE",decimate_type="COLLAPSE",ratio=min(1.0,1000.0/t),use_collapse_triangulate=True)
    for p in o.data.polygons: p.use_smooth=True
    notes=["fused the two unwelded mirror halves (voxel remesh 0.012) so the slit down the middle is gone","light smooth (0.5 x4) to soften the neck pinch","decimated back to ~1000 tris, smooth shaded"]
elif which=="crank":
    bm=bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
    # split into shells
    seen=set(); shells=[]
    for v in bm.verts:
        if v in seen: continue
        st=[v]; s=[]
        while st:
            x=st.pop()
            if x in seen: continue
            seen.add(x); s.append(x); st.extend(e.other_vert(x) for e in x.link_edges)
        shells.append(s)
    def bb(s): return [min(v.co[i] for v in s) for i in range(3)],[max(v.co[i] for v in s) for i in range(3)]
    boxes=[bb(s) for s in shells]
    bmesh.ops.delete(bm,geom=[v for v in bm.verts],context="VERTS")
    def cyl(mn,mx,axis,seg=10,bevel=0.0):
        c=[(mn[i]+mx[i])/2 for i in range(3)]; h=[(mx[i]-mn[i])/2 for i in range(3)]
        a=axis; u,w=[i for i in range(3) if i!=a]
        rings=[]
        prof=[(-1,1-bevel),(-1+bevel*h[u]/h[a] if bevel else -1,1),(1-bevel*h[u]/h[a] if bevel else 1,1),(1,1-bevel)] if bevel else [(-1,1),(1,1)]
        for t,r in prof:
            ring=[]
            for k in range(seg):
                ang=2*math.pi*(k+0.5)/seg; p=[0,0,0]
                p[a]=c[a]+t*h[a]; p[u]=c[u]+math.cos(ang)*h[u]*r; p[w]=c[w]+math.sin(ang)*h[w]*r
                ring.append(bm.verts.new(p))
            rings.append(ring)
        for r1,r2 in zip(rings,rings[1:]):
            for k in range(seg): bm.faces.new([r1[k],r1[(k+1)%seg],r2[(k+1)%seg],r2[k]])
        bm.faces.new(rings[0][::-1]); bm.faces.new(rings[-1])
    for (mn,mx) in boxes:
        ext=[mx[i]-mn[i] for i in range(3)]
        if len([1 for e in ext if e>0])==3 and max(ext)>0.3 and ext[1]<0.15: cyl(mn,mx,1,seg=12,bevel=0.25)   # disc -> chamfered wheel
        elif ext[0]>0.25: cyl(mn,mx,0,seg=4)          # bar stays a square bar
        else: cyl(mn,mx,1,seg=10,bevel=0.2)            # knob -> capped cylinder grip
    bmesh.ops.triangulate(bm,faces=bm.faces[:])
    bm.to_mesh(o.data); bm.free()
    for p in o.data.polygons: p.use_smooth=False
    notes=["disc (flattened ball) -> chamfered 12-sided wheel, same size","arm unchanged (square bar)","egg-shaped knob -> capped 10-sided cylinder grip, same size"]
elif which=="ponycore":
    # A shaft-and-bulb blob read badly on its own. Its convex hull keeps every outer point (same
    # footprint inside the pony) but drops the neck pinch; planar decimate gives crystal facets.
    bm=bmesh.new(); bm.from_mesh(o.data)
    res=bmesh.ops.convex_hull(bm,input=bm.verts[:])
    bmesh.ops.delete(bm,geom=[g for g in res["geom_interior"]+res["geom_unused"] if isinstance(g,bmesh.types.BMVert)],context="VERTS")
    bm.to_mesh(o.data); bm.free()
    apply_mod(o,"DECIMATE",decimate_type="COLLAPSE",ratio=0.4,use_collapse_triangulate=True)
    for p in o.data.polygons: p.use_smooth=False
    notes=["convex hull of the old core (drops the pinched neck, same outer footprint)","decimated to crystal facets, flat shaded"]
# keep the exact old bounds so the MeshPart Size/CFrame stay valid
mn,mx=bounds(o.data)
for v in o.data.vertices:
    v.co=mathutils.Vector([mn0[i]+(v.co[i]-mn[i])*(mx0[i]-mn0[i])/(mx[i]-mn[i]) for i in range(3)])
o.data.update()
mn1,mx1=bounds(o.data)
inside=None
if which=="ponycore":
    pony=bpy.data.objects["Pony"]; dg=bpy.context.evaluated_depsgraph_get()
    from mathutils.bvhtree import BVHTree
    tree=BVHTree.FromObject(pony,dg)
    out=0
    for v in o.data.vertices:
        loc,nor,idx,d=tree.find_nearest(v.co)
        if (v.co-loc).dot(nor)>0: out+=1
    inside={"verts":len(o.data.vertices),"outside_pony":out}
outdir=os.path.join(GCROOT,"assets/blender/mesh_reupload"); os.makedirs(outdir,exist_ok=True)
fbx=export_fbx([o],os.path.join(outdir,stem+".fbx"))
# keep only this object in the saved source copy
for x in list(bpy.data.objects):
    if x!=o: bpy.data.objects.remove(x)
bpy.data.libraries.write(os.path.join(outdir,stem+".blend"),{o},fake_user=True,compress=True)
print("JSON"+json.dumps({"which":which,"name":name,"tris_before":tris0,"tris_after":sum(len(p.vertices)-2 for p in o.data.polygons),
  "bounds_before":[mn0[:] if False else list(mn0),list(mx0)],"bounds_after":[list(mn1),list(mx1)],"fbx":fbx,"notes":notes,"inside":inside}))
