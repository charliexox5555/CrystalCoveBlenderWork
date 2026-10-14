-- Run once in Edit after recording the inventory and the user's place backup.
local ss=game:GetService("ServerStorage")
local function folder(name) local f=ss:FindFirstChild(name) or Instance.new("Folder"); f.Name=name; f.Parent=ss; return f end
local kit,unsorted=folder("LegacyKit"),folder("Unsorted")
local old=ss:FindFirstChild("MapBlockoutVisuals")
local saved={}
local specs={
 {"Tree","glass_town","glass_town_tree_",{TreeTrunk=1,TreeCrown=1,TreeCrownLight=1,TreeCrownDark=1}},
 {"Bush","glass_town","glass_town_bush_",{Bush=1}},
 {"Lamp","glass_town","glass_town_lamp_",nil},
 {"Bench","glass_town","glass_town_bench_",{Seat=1,Back=1,BenchFoot=2}},
 {"RepairBench","glass_town","glass_town_repair_bench_",{RepairTop=1,RepairMat=1,RepairLeg=4,ToolHandle=1,ToolHead=1,RepairSignPost=2,RepairSign=1}},
 {"Rock","yard_01","yard_01_rock_",{Rock=1}},
 {"Crate","yard_01","yard_01_crate_",{CrateBottom=1,CrateCorner=4,CrateSlat=12}},
 {"FenceSegment","yard_01","yard_01_fence_",{FencePost=2,FenceRail=2}},
}
if old then
 for _,spec in specs do
  if not kit:FindFirstChild(spec[1]) then
   local model=Instance.new("Model"); model.Name=spec[1]
   for _,p in old[spec[2]]:GetChildren() do
    if p:IsA("BasePart") and p.Name:sub(1,#spec[3])==spec[3] then
     local suffix=p.Name:sub(#spec[3]+1); local base=suffix:gsub("%.%d+$","")
     local n=tonumber(suffix:match("%.(%d+)$")) or 0
     if n < ((spec[4] and spec[4][base]) or (not spec[4] and 1) or 0) then
      local c=p:Clone(); c.Name=suffix; c.Anchored=true
      for _,d in c:GetDescendants() do if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") then d:Destroy() end end
      c.Parent=model
     end
    end
   end
   if #model:GetChildren()>0 then local cf,size=model:GetBoundingBox(); model.WorldPivot=CFrame.new(cf.Position-Vector3.new(0,size.Y/2,0)); model:PivotTo(CFrame.new()); model.Parent=kit; table.insert(saved,{name=model.Name,parts=#model:GetChildren()}) else model:Destroy() end
  end
 end
end
if workspace:FindFirstChild("PlayerReference") then workspace.PlayerReference.Parent=unsorted end
if game.Lighting:FindFirstChild("LightingPreset") then game.Lighting.LightingPreset.Parent=unsorted end
for _,name in {"Map","Baseplate","ClashStand","SpawnLocation"} do local o=workspace:FindFirstChild(name); if o then o:Destroy() end end
for _,name in {"MapImportedSources","MapBlockoutVisuals"} do local o=ss:FindFirstChild(name); if o then o:Destroy() end end
for _,d in game.Lighting:GetChildren() do if d:IsA("Sky") or d:IsA("Atmosphere") or d:IsA("PostEffect") then d:Destroy() end end
workspace.Terrain:Clear()
for _,d in workspace.Terrain:GetChildren() do if d:IsA("Clouds") then d.Enabled=false end end
return game:GetService("HttpService"):JSONEncode({salvaged=saved,unsorted=#unsorted:GetChildren()})
