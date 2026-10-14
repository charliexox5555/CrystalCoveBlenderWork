-- Initial Edit-mode builder; no Rojo script is modified here.
-- Replaces generated arena/bridge/collision/spot folders. Do not rerun over manual edits.
local data=game:GetService("HttpService"):JSONDecode([==[[{"name":"Isle_Lobby","fbx":"Isle_Lobby.fbx","top_size_xy_studs":[96,56],"superellipse_exponent":4,"depth_studs":33,"hanging_chunks":3,"intended_world_position_blender_xyz":[0,0,0],"intended_world_position_roblox_xyz":[0,0,0],"meshes":[{"name":"Isle_Lobby_Grass","triangle_count":160,"local_bounds_blender_xyz_studs":{"min":[-48,-28,-1.4],"max":[48,28,0]},"origin_blender_xyz":[0,0,0],"preview_color":"#7CCB5B","closed_manifold":true,"self_intersections":0,"volume_studs3":6741.9647},{"name":"Isle_Lobby_Dirt","triangle_count":160,"local_bounds_blender_xyz_studs":{"min":[-47.5,-27.5,-3.9],"max":[47.5,27.5,-1.4]},"origin_blender_xyz":[0,0,0],"preview_color":"#9A6B43","closed_manifold":true,"self_intersections":0,"volume_studs3":11468.6041},{"name":"Isle_Lobby_Rock","triangle_count":522,"local_bounds_blender_xyz_studs":{"min":[-53.207043,-32.538181,-33],"max":[46.549999,34.033405,-3.9]},"origin_blender_xyz":[0,0,0],"preview_color":"#9787A0","closed_manifold":true,"self_intersections":0,"volume_studs3":54703.5658}]},{"name":"Isle_Arena1","fbx":"Isle_Arena1.fbx","top_size_xy_studs":[92,46],"superellipse_exponent":4,"depth_studs":30,"hanging_chunks":2,"intended_world_position_blender_xyz":[0,56,2],"intended_world_position_roblox_xyz":[0,2,-56],"meshes":[{"name":"Isle_Arena1_Grass","triangle_count":160,"local_bounds_blender_xyz_studs":{"min":[-46,-23,-1.4],"max":[46,23,0]},"origin_blender_xyz":[0,0,0],"preview_color":"#7CCB5B","closed_manifold":true,"self_intersections":0,"volume_studs3":5327.8756},{"name":"Isle_Arena1_Dirt","triangle_count":160,"local_bounds_blender_xyz_studs":{"min":[-45.5,-22.5,-3.9],"max":[45.5,22.5,-1.4]},"origin_blender_xyz":[0,0,0],"preview_color":"#9A6B43","closed_manifold":true,"self_intersections":0,"volume_studs3":9023.1749},{"name":"Isle_Arena1_Rock","triangle_count":508,"local_bounds_blender_xyz_studs":{"min":[-45.366268,-29.087093,-30],"max":[44.59,30.549835,-3.9]},"origin_blender_xyz":[0,0,0],"preview_color":"#9787A0","closed_manifold":true,"self_intersections":0,"volume_studs3":37438.51}]},{"name":"Isle_Arena2","fbx":"Isle_Arena2.fbx","top_size_xy_studs":[92,46],"superellipse_exponent":4,"depth_studs":34,"hanging_chunks":4,"intended_world_position_blender_xyz":[0,107,4],"intended_world_position_roblox_xyz":[0,4,-107],"meshes":[{"name":"Isle_Arena2_Grass","triangle_count":160,"local_bounds_blender_xyz_studs":{"min":[-46,-23,-1.4],"max":[46,23,0]},"origin_blender_xyz":[0,0,0],"preview_color":"#7CCB5B","closed_manifold":true,"self_intersections":0,"volume_studs3":5375.7005},{"name":"Isle_Arena2_Dirt","triangle_count":160,"local_bounds_blender_xyz_studs":{"min":[-45.5,-22.5,-3.9],"max":[45.5,22.5,-1.4]},"origin_blender_xyz":[0,0,0],"preview_color":"#9A6B43","closed_manifold":true,"self_intersections":0,"volume_studs3":9104.17},{"name":"Isle_Arena2_Rock","triangle_count":536,"local_bounds_blender_xyz_studs":{"min":[-51.964165,-29.725922,-34],"max":[49.970936,28.579342,-3.9]},"origin_blender_xyz":[0,0,0],"preview_color":"#9787A0","closed_manifold":true,"self_intersections":0,"volume_studs3":45297.6958}]},{"name":"Isle_Arena3","fbx":"Isle_Arena3.fbx","top_size_xy_studs":[92,46],"superellipse_exponent":4,"depth_studs":31,"hanging_chunks":3,"intended_world_position_blender_xyz":[0,158,6],"intended_world_position_roblox_xyz":[0,6,-158],"meshes":[{"name":"Isle_Arena3_Grass","triangle_count":160,"local_bounds_blender_xyz_studs":{"min":[-46,-23,-1.4],"max":[46,23,0]},"origin_blender_xyz":[0,0,0],"preview_color":"#7CCB5B","closed_manifold":true,"self_intersections":0,"volume_studs3":5401.0882},{"name":"Isle_Arena3_Dirt","triangle_count":160,"local_bounds_blender_xyz_studs":{"min":[-45.5,-22.5,-3.9],"max":[45.5,22.5,-1.4]},"origin_blender_xyz":[0,0,0],"preview_color":"#9A6B43","closed_manifold":true,"self_intersections":0,"volume_studs3":9147.1664},{"name":"Isle_Arena3_Rock","triangle_count":522,"local_bounds_blender_xyz_studs":{"min":[-44.59,-22.768494,-31],"max":[47.318119,29.921913,-3.9]},"origin_blender_xyz":[0,0,0],"preview_color":"#9787A0","closed_manifold":true,"self_intersections":0,"volume_studs3":37844.0201}]},{"name":"Isle_Featured","fbx":"Isle_Featured.fbx","top_size_xy_studs":[72,48],"superellipse_exponent":3,"depth_studs":32,"hanging_chunks":3,"intended_world_position_blender_xyz":[0,210,9],"intended_world_position_roblox_xyz":[0,9,-210],"meshes":[{"name":"Isle_Featured_Grass","triangle_count":160,"local_bounds_blender_xyz_studs":{"min":[-36,-24,-1.4],"max":[36,24,0]},"origin_blender_xyz":[0,0,0],"preview_color":"#7CCB5B","closed_manifold":true,"self_intersections":0,"volume_studs3":4232.8962},{"name":"Isle_Featured_Dirt","triangle_count":160,"local_bounds_blender_xyz_studs":{"min":[-35.5,-23.5,-3.9],"max":[35.5,23.5,-1.4]},"origin_blender_xyz":[0,0,0],"preview_color":"#9A6B43","closed_manifold":true,"self_intersections":0,"volume_studs3":7153.4764},{"name":"Isle_Featured_Rock","triangle_count":522,"local_bounds_blender_xyz_studs":{"min":[-40.965305,-30.292831,-32],"max":[34.790001,24.135075,-3.9]},"origin_blender_xyz":[0,0,0],"preview_color":"#9787A0","closed_manifold":true,"self_intersections":0,"volume_studs3":32729.0205}]}]]==])
local CollectionService=game:GetService("CollectionService")
-- Four-stud gaps preserve the short-bridge layout and bring pad entry below 14s.
for index,e in data do e.intended_world_position_roblox_xyz[3]+=index-1 end
local function hex(s) return Color3.fromHex(s) end
local function folder(parent,name) local f=parent:FindFirstChild(name) or Instance.new("Folder"); f.Name=name; f.Parent=parent; return f end
local lobby=folder(workspace,"Lobby")
local islands=folder(lobby,"Islands")
local collision=folder(lobby,"Collision")
local bridges=folder(lobby,"Bridges")
local arenas=folder(lobby,"Arenas")
local spots=folder(lobby,"Spots")
-- These four folders contain only output generated by this builder.
for _,f in {collision,bridges,arenas,spots} do f:ClearAllChildren() end
local function part(parent,name,size,cf,color,material)
 local p=Instance.new("Part"); p.Name=name; p.Size=size; p.CFrame=cf; p.Anchored=true
 p.Color=hex(color); p.Material=material or Enum.Material.SmoothPlastic
 p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth; p.Parent=parent
 return p
end
for _,e in data do
 local m=islands:FindFirstChild(e.name) or workspace:FindFirstChild(e.name)
 assert(m and m:IsA("Model"),"Missing imported island "..e.name)
 local a=e.intended_world_position_roblox_xyz; local pos=Vector3.new(a[1],a[2],a[3])
 for _,mesh in e.meshes do
  local p=m:FindFirstChild(mesh.name); assert(p and p:IsA("MeshPart"),mesh.name)
  local b=mesh.local_bounds_blender_xyz_studs; local lo,hi=b.min,b.max
  local centre=Vector3.new((lo[1]+hi[1])/2,(lo[3]+hi[3])/2,-(lo[2]+hi[2])/2)
  p.Size=Vector3.new(hi[1]-lo[1],hi[3]-lo[3],hi[2]-lo[2])
  p.CFrame=CFrame.new(pos+centre); p.PivotOffset=CFrame.new(-centre)
  p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
  p.Material=Enum.Material.SmoothPlastic; p.Color=hex(mesh.preview_color); p.Reflectance=0
  p.TextureID=""; p.CastShadow=mesh.name:match("_Grass$")~=nil
  p:SetAttribute("TriangleCount",mesh.triangle_count)
 end
 m.PrimaryPart=nil; m.WorldPivot=CFrame.new(pos); m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic; m.Parent=islands
 m:SetAttribute("RescuePosition",pos+Vector3.new(0,0,e.name=="Isle_Featured" and 18 or 0))
 local w,h=e.top_size_xy_studs[1],e.top_size_xy_studs[2]
 -- Overlapping strips provide one perfectly level surface with rounded corners.
 -- Cover the visual rim conservatively; the eventual fences define the edge.
 for i=1,13 do
  local dz=h/13; local z=-h/2+(i-.5)*dz
  local q=math.max(0,math.abs(z)-dz/2)/(h/2)
  local width=w*(1-q^e.superellipse_exponent)^(1/e.superellipse_exponent)
  local p=part(collision,e.name.."_Floor"..i,Vector3.new(width,1.4,dz+.06),CFrame.new(pos+Vector3.new(0,-.7,z)),"7CCB5B")
  p.Transparency=1; p.CastShadow=false; p.CanTouch=false; p:SetAttribute("Island",e.name)
 end
 task.wait()
end
local ends={{28,32,0,2},{78,82,2,4},{128,132,4,6},{178,182,6,9}}
for i,e in ends do
 local model=Instance.new("Model"); model.Name="Bridge"..i; model.Parent=bridges; CollectionService:AddTag(model,"PlaceholderBridge")
 local a,b=Vector3.new(0,e[3],-e[1]+2),Vector3.new(0,e[4],-e[2]-2)
 local frame=CFrame.lookAt((a+b)/2,b)
 local length=(b-a).Magnitude
 local deck=part(model,"PlankDeck",Vector3.new(8,.4,length),frame*CFrame.new(0,-.2,0),"C98A4B")
 deck:SetAttribute("PlaceholderBridge",true)
 for _,x in {-4.2,4.2} do
  part(model,"LowRail",Vector3.new(.4,1.4,length),frame*CFrame.new(x,.7,0),"94603A")
 end
 for j=1,8 do local line=part(model,"PlankSeam",Vector3.new(8,.015,.035),frame*CFrame.new(0,.007,length*(j/9-.5)),"94603A"); line.CanCollide=false; line.CanTouch=false; line.CanQuery=false end
end
local template=game.ReplicatedStorage.Assets.ClashStand
local gap=require(game.ReplicatedStorage.Shared.Config.Balance).Motion.HookGap
local bar=template:FindFirstChild("Crossbar"); assert(bar and bar:IsA("BasePart"))
for _,d in template:GetDescendants() do if d:IsA("Attachment") and (d.Name=="HookA" or d.Name=="HookB") then d:Destroy() end end
for i,name in {"HookA","HookB"} do
 local mesh=template:FindFirstChild(name); assert(mesh and mesh:IsA("BasePart"))
 local p=mesh.Position; local x=(i==1 and -1 or 1)*gap/2
 mesh.CFrame=CFrame.new(x,p.Y,p.Z)*mesh.CFrame.Rotation
 local hook=Instance.new("Attachment"); hook.Name=name
 hook.Position=bar.CFrame:PointToObjectSpace(Vector3.new(x,15,0)); hook.Parent=bar
end
local function stand(id,pos,rotation,featured)
 local m=template:Clone(); m.Name="Arena"..id
 for _,d in m:GetDescendants() do
  if d:IsA("BasePart") then d.Anchored=true; d.CanTouch=false; d.CanCollide=true; if d:IsA("MeshPart") then d.CollisionFidelity=Enum.CollisionFidelity.Hull end
  elseif d:IsA("ProximityPrompt") then d:Destroy() end
 end
 m:PivotTo(CFrame.new(pos)*CFrame.Angles(0,rotation,0)); m.Parent=arenas
 m:SetAttribute("ArenaId",id); m:SetAttribute("Featured",featured); CollectionService:AddTag(m,"ArenaStand")
 local axis=(CFrame.Angles(0,rotation,0)).RightVector
 for i,side in {"A","B"} do
  -- A faces the lobby on normal stands; Featured A/B follow its X swing axis.
  local p=pos+axis*(i==1 and -18.5 or 18.5)
  local ground=featured and 9 or pos.Y-.1
  local pad=part(m,"Queue"..side,Vector3.new(.16,6.6,6.6),CFrame.new(p.X,ground+.08,p.Z)*CFrame.Angles(0,0,math.pi/2),"5B6A8C")
  pad.Shape=Enum.PartType.Cylinder; pad.CanCollide=false; pad.CanTouch=false
  pad:SetAttribute("ArenaId",id); pad:SetAttribute("Side",side); CollectionService:AddTag(pad,"QueuePad")
  local disc=part(pad,"Glow",Vector3.new(.035,5.4,5.4),CFrame.new(p.X,ground+.1775,p.Z)*CFrame.Angles(0,0,math.pi/2),i==1 and "4FB8FF" or "FF9F43",Enum.Material.Neon)
  disc.Shape=Enum.PartType.Cylinder; disc.CanCollide=false; disc.CanTouch=false; disc.CanQuery=false
 end
 return m
end
local id=0
for _,e in {{55,2},{105,4},{155,6}} do for _,x in {-24,24} do id+=1; stand(id,Vector3.new(x,e[2]+.1,-e[1]),math.pi/2,false) end end
part(arenas,"FeaturedStageTrim",Vector3.new(30,.6,30),CFrame.new(0,9.3,-206),"FFC94D")
part(arenas,"FeaturedStageTop",Vector3.new(29.4,.04,29.4),CFrame.new(0,9.58,-206),"CFC3AA")
stand(7,Vector3.new(0,9.7,-206),0,true)
local positions={Spawn={0,12},Kiln={-22,-11},Shop={22,-11},Daily={-12.5,12},Codes={12.5,12},Index={38,5},LeaderboardWins={-14,21},LeaderboardStreak={14,21},Champion={0,22.6}}
for name,p in positions do local marker=part(spots,name,Vector3.new(4,.1,4),CFrame.new(p[1],.05,p[2]),"FFFFFF"); marker.Transparency=1; marker.CanCollide=false; marker.CanTouch=false; marker.CanQuery=false; marker:SetAttribute("Spot",name); CollectionService:AddTag(marker,"LobbySpot") end
local oldSpawn=lobby:FindFirstChild("SpawnLocation"); if oldSpawn then oldSpawn:Destroy() end
local spawn=Instance.new("SpawnLocation"); spawn.Name="SpawnLocation"; spawn.Size=Vector3.new(6,.1,6); spawn.CFrame=CFrame.new(0,.05,12); spawn.Anchored=true; spawn.Transparency=1; spawn.CanCollide=false; spawn.Neutral=true; spawn.Duration=0; spawn.Parent=lobby
local lighting=game:GetService("Lighting")
for _,d in lighting:GetChildren() do if d.Name:match("^SkyLobby") then d:Destroy() end end
lighting.ClockTime=16.4; lighting.GeographicLatitude=35; lighting.Brightness=2.6
lighting.Ambient=hex("6E7390"); lighting.OutdoorAmbient=hex("A9B8D6")
lighting.ColorShift_Top=hex("FFD9A8"); lighting.ColorShift_Bottom=hex("2B2F55")
lighting.EnvironmentDiffuseScale=.5; lighting.EnvironmentSpecularScale=.7; lighting.ExposureCompensation=.1
local atmosphere=Instance.new("Atmosphere"); atmosphere.Name="SkyLobbyAtmosphere"; atmosphere.Density=.28; atmosphere.Offset=.15; atmosphere.Color=hex("CFE3FF"); atmosphere.Decay=hex("FFD9B0"); atmosphere.Glare=.25; atmosphere.Haze=1.3; atmosphere.Parent=lighting
local sky=Instance.new("Sky"); sky.Name="SkyLobbySky"; sky.StarCount=0
for _,face in {"Bk","Ft","Lf","Rt"} do sky["Skybox"..face]="rbxassetid://75106760095407" end
sky.SkyboxUp="rbxassetid://139399281474753"; sky.SkyboxDn="rbxassetid://99856451388491"; sky.Parent=lighting
local bloom=Instance.new("BloomEffect"); bloom.Name="SkyLobbyBloom"; bloom.Intensity=.5; bloom.Size=24; bloom.Threshold=1.7; bloom.Parent=lighting
local color=Instance.new("ColorCorrectionEffect"); color.Name="SkyLobbyColor"; color.Saturation=.1; color.Contrast=.05; color.TintColor=hex("FFF6EC"); color.Parent=lighting
local rays=Instance.new("SunRaysEffect"); rays.Name="SkyLobbySunRays"; rays.Intensity=.04; rays.Parent=lighting
workspace.FallenPartsDestroyHeight=-150
return {instances=#lobby:GetDescendants(),sun=tostring(lighting:GetSunDirection()),hookGap=(bar.HookA.WorldPosition-bar.HookB.WorldPosition).Magnitude}

