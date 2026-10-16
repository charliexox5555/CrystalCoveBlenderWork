"""Refine our new ghost silhouettes/mesh budgets; retain earlier source mesh datablocks."""
import bpy, math, json, os, shutil
from mathutils import Vector
ROOT=r"C:/Users/charl/Documents/CrystalCoveBlenderWork"
OUT=ROOT+"/assets/blender/seasonal/hollowlight_v1"
GLASSCLASH_REPO=ROOT
exec(open(ROOT+"/tools/blender/glassclash_blender.py").read())
old=bpy.context.window.scene
scene=bpy.data.scenes["Hollowlight_v1"]
manifest=json.load(open(OUT+"/manifest.json"))
assert not manifest.get("revision"), "Preserve the already-refined artist source and first pass"
shutil.copyfile(OUT+"/hollowlight_v1.blend",OUT+"/hollowlight_first_pass.blend")
def replace(o,vertices,faces):
    previous=o.data
    previous.use_fake_user=True
    d=bpy.data.meshes.new(o.name+"_Refined")
    d.from_pydata(vertices,[],faces);d.update()
    for m in previous.materials:d.materials.append(m)
    for p in d.polygons:p.use_smooth=True
    o.data=d
def octa(center,r):
    c=Vector(center)
    vertices=[tuple(c+Vector(v)*r) for v in [(1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1),(0,0,-1)]]
    return vertices,[(0,2,4),(2,1,4),(1,3,4),(3,0,4),(2,0,5),(1,2,5),(3,1,5),(0,3,5)]
try:
    bpy.context.window.scene=scene
    for i in range(3):
        angle=i*math.tau/3;x,y=1.55*math.cos(angle),1.55*math.sin(angle)
        vertices=[];faces=[];n=24
        profile=[(.04,.10),(.14,.16),(.28,.25),(.45,.34),(.67,.38),(.87,.34),(1.04,.22),(1.12,.04)]
        for z,r in profile:
            t=z/1.12;dx=.2*(1-t)**2
            for j in range(n):
                a=j*math.tau/n
                vertices.append((x+dx+r*math.cos(a),y+r*math.sin(a),.72+z))
        for k in range(len(profile)-1):
            for j in range(n):
                a=k*n+j;b=k*n+(j+1)%n
                faces.append((a,b,b+n,a+n))
        faces+=[tuple(reversed(range(n))),tuple((len(profile)-1)*n+j for j in range(n))]
        replace(bpy.data.objects["HHL_Eclipse_Wisp"+str(i)],vertices,faces)
        for j in (-1,1):
            o=bpy.data.objects["HHL_Eclipse_WispEye"+str(i)+str(j)]
            replace(o,*octa((x+j*.11,y-.355,1.55),.055))
    # Add a visible lantern face to the finisher core.
    mint=bpy.data.materials["HHL_WispMint"]
    for side in (-1,1):
        d=bpy.data.meshes.new("EclipseFace")
        d.from_pydata([(side*.12,-.77,1.19),(side*.43,-.68,1.18),(side*.28,-.77,1.4)],[],[(0,1,2)])
        o=bpy.data.objects.new("HHL_Eclipse_Face"+str(side),d);scene.collection.objects.link(o);d.materials.append(mint)
        manifest["groups"]["finisher"].append({"name":o.name})
    groups={k:[bpy.data.objects[x["name"]] for x in v] for k,v in manifest["groups"].items()}
    for name,objects in groups.items():
        manifest["groups"][name]=[{"name":o.name,"triangles":sum(len(p.vertices)-2 for p in o.data.polygons),"dimensions":list(o.dimensions)} for o in objects]
    manifest["revision"]="Refined ghost silhouettes and reduced eye geometry; first source retained"
    export_fbx(groups["flyer"]+groups["finisher"],OUT+"/HOLLOWLIGHT_COSMETICS_IMPORT.fbx")
    with open(OUT+"/manifest.json","w") as f:json.dump(manifest,f,indent=2)
    bpy.data.libraries.write(OUT+"/hollowlight_v1.blend",{scene},fake_user=True)
    render_icon(groups["finisher"],OUT+"/finisher_icon.png",size=512,samples=24,engine="BLENDER_EEVEE")
finally:
    bpy.context.window.scene=old
result={"finisherTriangles":sum(x["triangles"] for x in manifest["groups"]["finisher"]),"originalSceneRestored":True}
