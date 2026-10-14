-- Edit mode, after manual FBX import into Workspace.GlassClashImports.
-- Only exact Wave1 mesh names are read. Existing installed glassies are never replaced.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before installing imports")
local RS, SS = game:GetService("ReplicatedStorage"), game:GetService("ServerStorage")
local Manifest = require(RS.Shared.Config.ArtImports)
local root = workspace:FindFirstChild("GlassClashImports")
if not root then
	return { Pending = "Import the Wave1 FBX files into Workspace.GlassClashImports first" }
end
local library = RS.Assets.Glassies
local backup = SS:FindFirstChild("Wave1ImportedSources") or Instance.new("Folder")
backup.Name, backup.Parent = "Wave1ImportedSources", SS
local installed, pending = {}, {}
local function vector(values)
	return Vector3.new(values[1], values[2], values[3])
end
for id, entries in Manifest do
	if library:FindFirstChild(id) then
		continue
	end
	local sources, complete = {}, true
	for _, e in entries do
		local matches = {}
		for _, part in root:GetDescendants() do
			if part:IsA("MeshPart") and part.Name == e.Name then
				table.insert(matches, part)
			end
		end
		if #matches ~= 1 then
			complete = false
			break
		end
		for _, child in matches[1]:GetDescendants() do
			assert(not child:IsA("LuaSourceContainer"), "Unexpected script in FBX import")
		end
		sources[e.Name] = matches[1]
	end
	if not complete then
		table.insert(pending, id)
		continue
	end
	local model = Instance.new("Model")
	model.Name = id
	model.WorldPivot = CFrame.identity
	local shards, details = Instance.new("Folder"), Instance.new("Folder")
	shards.Name, shards.Parent = "Shards", model
	details.Name, details.Parent = "Details", model
	local body
	for _, e in entries do
		local source = sources[e.Name]
		local part = source:Clone()
		part.Name = e.Source
		part.Size = vector(e.Size)
		-- FBX importer owns the mesh-axis rotation; the measured source owns scale/centres.
		-- Do not rotate individual raw import meshes before this installer.
		part.CFrame = CFrame.new(vector(e.Center)) * source.CFrame.Rotation
		part.PivotOffset = part.CFrame:Inverse()
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
		part.CastShadow = false
		part.Material = Enum.Material[e.Material]
		part.Color = Color3.fromHex(e.Color)
		part.Transparency = if e.Material == "Glass" then 0.3 else 0
		part.Reflectance = if e.Material == "Glass" then 0.15 else 0
		part.Parent = if e.Role == "Shard" then shards elseif e.Role == "Detail" then details else model
		if e.Role == "Body" then
			body = part
		end
	end
	assert(body and #shards:GetChildren() == 16, "Incomplete glassy")
	model.PrimaryPart = body
	model:SetAttribute("ImportedWave", 1)
	model.Parent = library
	local saved = Instance.new("Folder")
	saved.Name, saved.Parent = id, backup
	for _, source in sources do
		source.Parent = saved
	end
	table.insert(installed, id)
end
return {
	Installed = installed,
	Pending = pending,
	Backup = backup:GetFullName(),
	Next = "Inspect assembled portraits and play-test before publishing",
}
