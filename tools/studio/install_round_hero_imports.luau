-- Edit/MCP: set _G.RoundHeroImportData to decoded round_hero_import_data.json first.
-- Import ROUND_HEROES_V2_IMPORT.fbx into Workspace, preserving RH2_ names and scale 1.
assert(not game:GetService("RunService"):IsRunning(), "Install in Edit")
local data = assert(_G.RoundHeroImportData, "Load the checked-in import metadata first")
local RS, SS = game.ReplicatedStorage, game.ServerStorage
assert(not SS:FindFirstChild("RoundHeroesBeforeV2"), "Already installed; preserve current art")
assert(not RS.Assets.VFX:FindFirstChild("RoundHeroV2"), "Preserve existing imported VFX")
local sources = {}
for _, d in data do
	local matches = {}
	local pattern = d.import_name:gsub("(%W)", "%%%1")
	for _, part in workspace:GetDescendants() do
		if part:IsA("MeshPart") and (part.Name == d.import_name or part.Name:match("^" .. pattern .. "%.%d+$")) then
			table.insert(matches, part)
		end
	end
	assert(#matches == 1, "Expected one imported mesh: " .. d.import_name)
	assert(matches[1].MeshId ~= "", "Requires an uploaded mesh: " .. d.import_name)
	sources[d.import_name] = matches[1]
end
-- All 32 permanent mesh assets must exist before any live model changes.
local backup = Instance.new("Folder")
backup.Name = "RoundHeroesBeforeV2"
RS.Assets.Rideables:Clone().Parent = backup
RS.Assets.RoundFinishers:Clone().Parent = backup
backup.Parent = SS
local staged = Instance.new("Folder")
staged.Name = "RoundHeroesV2Staging"
local groups = {}
for _, d in data do
	local group = groups[d.group]
	if not group then
		group = Instance.new(if d.group == "vfx" then "Folder" else "Model")
		group.Name, group.Parent = d.group, staged
		groups[d.group] = group
	end
	local p = sources[d.import_name]:Clone()
	for _, child in p:GetChildren() do
		-- Source bundle is geometry only. Preserve the imported original in Workspace.
		child:Destroy()
	end
	p.Name, p.Color, p.Material = d.name, Color3.fromHex(d.color), Enum.Material[d.material]
	p.TextureID = ""
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Size, p.CFrame = Vector3.new(unpack(d.size)), CFrame.new(unpack(d.center))
	if d.ride_motion then
		p:SetAttribute("RideMotion", d.ride_motion)
	end
	if d.wing_side then
		p:SetAttribute("WingSide", d.wing_side)
	end
	if d.wing_pivot then
		local v = d.wing_pivot
		p:SetAttribute("WingPivot", Vector3.new(v[1], v[3], -v[2]) - p.Position)
	end
	p.Parent = group
end
for id, model in groups do
	if id == "vfx" then
		continue
	end
	model.WorldPivot = CFrame.identity
	model:SetAttribute("OriginalGlassClash", true)
	model:SetAttribute("Version", 2)
	model:SetAttribute("BlenderAuthored", true)
	local old = RS.Assets.Rideables:FindFirstChild(id)
	if old then
		old.Parent = backup
	end
	model.Parent = RS.Assets.Rideables
end
groups.vfx.Name, groups.vfx.Parent = "RoundHeroV2", RS.Assets.VFX
-- Replace static finisher portraits with the matching authored mesh vocabulary.
for id, key in
	{ glass_burst = "CrystalShard", party_burst = "ConfettiCurl", brick_boom = "BlastBloom", starfall = "NovaStar" }
do
	local old = RS.Assets.RoundFinishers[id]
	local model = Instance.new("Model")
	model.Name = id
	local p = groups.vfx[key]:Clone()
	p.CFrame = CFrame.identity
	p.Parent = model
	model.WorldPivot = CFrame.identity
	model:SetAttribute("BlenderAuthored", true)
	old.Parent = backup
	model.Parent = RS.Assets.RoundFinishers
end
staged:Destroy()
return { InstalledRides = 4, InstalledVFXMeshes = 5, Originals = backup:GetFullName(), Published = false }
