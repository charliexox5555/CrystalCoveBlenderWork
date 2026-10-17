-- Edit/MCP only. Installs Crate Machines v2 templates from the uploaded FBX (asset 115123551485957).
-- 1. insert_asset 115123551485957 into ServerStorage as "CrateMachinesV2Raw" (remove any PackageLink).
-- 2. _G.CrateMachinesManifest = HttpService:JSONDecode(<assets/blender/crates_v2/r1/manifest.json>).
-- 3. Run this. Builds ReplicatedStorage.Assets.CrateMachines.{Finishers,Rideables}_{Coins,Marbles}.
-- The older ReplicatedStorage.Assets.Crates capsules are left untouched.
assert(not game:GetService("RunService"):IsRunning(), "Install in Edit")
local CollectionService = game:GetService("CollectionService")
local RS, SS = game.ReplicatedStorage, game.ServerStorage
local Config = require(RS.Shared.Config.CrateMachines)
local manifest = assert(_G.CrateMachinesManifest, "Load manifest.json into _G.CrateMachinesManifest")
assert(not RS.Assets:FindFirstChild("CrateMachines"), "Already installed; bump the revision instead")
local raw = assert(SS:FindFirstChild("CrateMachinesV2Raw"), "Insert the raw FBX model first")
local sources = {}
for _, item in raw:GetDescendants() do
	assert(not item:IsA("LuaSourceContainer"), "Unexpected script in geometry import")
	if item:IsA("MeshPart") then
		sources[item.Name] = item
	end
end
-- Collision/footprint box per machine (studs); the pivot sits at the floor centre, front faces -Z.
local footprint = { Finishers = Vector3.new(3.9, 2.4, 3.5), Rideables = Vector3.new(3.6, 3.1, 3.2) }
local promptPoint = { Finishers = Vector3.new(0, 2.6, -2.2), Rideables = Vector3.new(0, 2.6, -2.1) }
-- FBX import bakes a half-turn about Y into each mesh; undo it around the mesh centre.
local FLIP = CFrame.Angles(0, math.pi, 0)
local folder = Instance.new("Folder")
folder.Name = "CrateMachines"
folder:SetAttribute("Version", Config.Version)
folder:SetAttribute("SourceAsset", Config.AssetId)
local report = {}
for _, category in Config.Categories do
	for _, currency in Config.Currencies do
		local model = Instance.new("Model")
		model.Name = Config.templateName(category, currency)
		local root = Instance.new("Part")
		root.Name, root.Size, root.Transparency = "Root", footprint[category], 1
		root.CFrame = CFrame.new(0, footprint[category].Y / 2, 0)
		root.PivotOffset = CFrame.new(0, -footprint[category].Y / 2, 0)
		root.Anchored, root.CanCollide, root.CanTouch, root.CanQuery, root.CastShadow = true, true, false, true, false
		root.Parent = model
		local prompt = Instance.new("Attachment")
		prompt.Name, prompt.Position, prompt.Parent = "PromptPoint", promptPoint[category] - root.Position, root
		local tris = 0
		for _, d in manifest.meshes do
			if d.machine ~= category or (d.variant and d.variant ~= currency) then
				continue
			end
			local source = assert(sources[d.name], "Missing mesh " .. d.name)
			local size = Vector3.new(unpack(d.size))
			assert((source.Size / 100 - size).Magnitude < 0.01, "Unexpected import scale: " .. d.name)
			local p = source:Clone()
			for _, child in p:GetChildren() do
				child:Destroy()
			end
			p.Name = if d.variant then "TrimEmblem" else d.part
			p.Size, p.CFrame = size, CFrame.new(unpack(d.center)) * FLIP
			p.PivotOffset = CFrame.identity
			p.TextureID = ""
			p.Material = Enum.Material[d.material]
			p.Color = Color3.fromHex(if d.tint then Config.Trim[currency] else d.color)
			p.Transparency = d.transparency or 0
			p.Reflectance = if d.material == "Glass" then 0.12 else 0
			p.DoubleSided = d.material == "Glass"
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
			p.CastShadow = d.material == "SmoothPlastic"
			p:SetAttribute("ImportName", d.name)
			p:SetAttribute("Triangles", d.triangles)
			p:SetAttribute("CurrencyTint", d.tint == true)
			if d.idle then
				p:SetAttribute("Idle", d.idle)
			end
			if d.lid then
				p:SetAttribute("Lid", true)
			end
			if d.spinAxis then
				p:SetAttribute("SpinAxis", Vector3.new(unpack(d.spinAxis)))
			end
			if d.spinSpeed then
				p:SetAttribute("SpinSpeed", d.spinSpeed)
			end
			if d.part == "RevealCore" then
				local launch = Instance.new("Attachment")
				launch.Name, launch.Parent = "LaunchPoint", p
			end
			p.Parent = model
			tris += d.triangles
		end
		model.PrimaryPart = root
		model.WorldPivot = CFrame.identity
		model:SetAttribute("CrateMachineVersion", Config.Version)
		model:SetAttribute("Category", category)
		model:SetAttribute("Currency", currency)
		model:SetAttribute("Triangles", tris)
		CollectionService:AddTag(model, Config.Tag)
		model.Parent = folder
		report[model.Name] = tris
	end
end
folder.Parent = RS.Assets
return report
