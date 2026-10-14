"""Read-only saved-source bundler. Load both helpers/builders before calling export_wave1()."""
import json


def export_wave1():
    folder=repo_path("assets","blender","import_wave1");os.makedirs(folder,exist_ok=True)
    previous=bpy.context.window.scene
    report={};luau=["--!strict","-- Generated import geometry; no gameplay balance values.","return {"]
    try:
        for gid in (*WAVE_IDS,*SKY_IDS):
            glassy=gid in WAVE_IDS
            source=repo_path("assets","blender","glassies",gid,gid+".blend") if glassy else repo_path("assets","blender","map","sky_kit",gid,gid+".blend")
            with bpy.data.libraries.load(source,link=False) as (available,loaded):loaded.scenes=available.scenes
            assert len(loaded.scenes)==1
            scene=loaded.scenes[0];bpy.context.window.scene=scene;objects=list(scene.objects)
            meshes=[o for o in objects if o.type=="MESH"]
            entries=[]
            try:
                with bpy.context.temp_override(scene=scene,view_layer=scene.view_layers[0]):
                    for obj in meshes:
                        name=re.sub(r"\.\d+$","",obj.name)
                        role="Body" if name=="Body" else "Shard" if name.startswith("Shard_") else "Detail" if glassy else "World"
                        obj.name=f"Wave1_{gid}_{name}";obj["source_name"]=name;obj["asset_role"]=role
                        lo,hi=_world_bounds([obj]);centre=(lo+hi)/2;size=hi-lo
                        entries.append({"Name":obj.name,"Source":name,"Role":role,"Center":[centre.x,centre.z,-centre.y],"Size":[size.x,size.z,size.y],
                                        "Color":obj.get("studio_color",glassy_tint(gid)),"Material":obj.get("studio_material","Glass" if glassy else "SmoothPlastic")})
                    if glassy:
                        assert sum(e["Role"]=="Body" for e in entries)==1 and sum(e["Role"]=="Shard" for e in entries)==16
                        assert all(o.location.length<1e-5 for o in meshes)
                    path=os.path.join(folder,f"Wave1_{gid}.fbx");export_fbx(meshes,path)
                    report[gid]={"file":os.path.basename(path),"meshes":entries}
                    if glassy:
                        luau.append(f'\t{gid} = {{')
                        for e in entries:
                            centre=", ".join(f"{v:.7f}" for v in e["Center"]);size=", ".join(f"{v:.7f}" for v in e["Size"])
                            luau.append(f'\t\t{{Name="{e["Name"]}", Source="{e["Source"]}", Role="{e["Role"]}", Center={{{centre}}}, Size={{{size}}}, Color="{e["Color"]}", Material="{e["Material"]}"}},')
                        luau.append("\t},")
            finally:
                bpy.context.window.scene=previous
                for obj in objects:bpy.data.objects.remove(obj,do_unlink=True)
                bpy.data.scenes.remove(scene)
    finally:bpy.context.window.scene=previous
    luau.append("}")
    with open(repo_path("src","shared","Config","ArtImports.luau"),"w",encoding="utf-8") as f:f.write("\n".join(luau)+"\n")
    with open(os.path.join(folder,"manifest.json"),"w",encoding="utf-8") as f:json.dump(report,f,indent=2)
    return {gid:{"file":r["file"],"meshes":len(r["meshes"])} for gid,r in report.items()}
