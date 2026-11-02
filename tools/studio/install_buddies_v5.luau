-- Installs the Glass Buddies v5 bundles into ReplicatedStorage.Assets.Glassies (Edit mode, MCP).
-- Asset ids: assets/blender/glassies_v5/roblox_assets.json. Colours: tools/blender/build_buddies_v5.py.
-- What it replaces goes to ServerStorage.GlassiesBeforeV5, so an older model is never lost.
local IS = game:GetService("InsertService")
local RS = game:GetService("ReplicatedStorage")
local BUDDIES = {
	pop = { Asset = 89666168724292, Fill = "#1E7BFF", Glass = "#BFE6FF", Top = "#FF3B4E" },
	jam = { Asset = 80478873695989, Fill = "#FF8A1F", Glass = "#FFE7C4", Top = "#FFC93C" },
	prism = { Asset = 104252975578425, Fill = "#8B4DFF", Glass = "#E4D6FF", Top = "#FFE36E" },
	glass_cup = { Asset = 120158899370566, Fill = "#6FE01F", Glass = "#E2FFC9" },
	water_jug = { Asset = 136014486642992, Fill = "#10CFC0", Glass = "#C8FFF7", Top = "#FFFFFF" },
	ketchup_bottle = { Asset = 95459940693266, Fill = "#F2212F", Glass = "#FFD2D2", Top = "#FFD23C" },
	milk_bottle = { Asset = 82843203997134, Fill = "#F6EFDF", Glass = "#FFFFFF", Top = "#4FA8F0" },
	pickle_jar = { Asset = 120701254461667, Fill = "#58A92C", Glass = "#E4F7CC", Top = "#E9E2C8" },
	lemonade_bottle = { Asset = 70492197805450, Fill = "#FFD21F", Glass = "#FFF6C9", Top = "#46C24A" },
	mason_jar = { Asset = 98257169784668, Fill = "#1F4F86", Glass = "#D5E8FF", Top = "#C9CED6" },
	crystal_tumbler = { Asset = 100712345524610, Fill = "#7FDFFF", Glass = "#EAFBFF" },
	hot_sauce = { Asset = 83629797085280, Fill = "#E8390E", Glass = "#FFD9C9", Top = "#2FAE3C" },
}
local FACE_SWAP = CFrame.Angles(0, math.pi, 0) -- FBX brings Blender's -Y front in as -Z; the fight camera sits at +Z
local library = RS.Assets.Glassies
local backup = game.ServerStorage:FindFirstChild("GlassiesBeforeV5") or Instance.new("Folder")
backup.Name, backup.Parent = "GlassiesBeforeV5", game.ServerStorage
local report = {}
for id, spec in BUDDIES do
	local ok, loaded = pcall(IS.LoadAsset, IS, spec.Asset)
	assert(ok, tostring(loaded))
	local root = Instance.new("Folder")
	root.Name = id
	root:SetAttribute("BuddyVersion", 5)
	root:SetAttribute("Fill", spec.Fill)
	local details, shards = Instance.new("Folder"), Instance.new("Folder")
	details.Name, shards.Name = "Details", "Shards"
	details.Parent, shards.Parent = root, root
	local count = 0
	for _, part in loaded:GetDescendants() do
		if not part:IsA("MeshPart") then
			continue
		end
		count += 1
		if part.Name == "Lid" then
			part.Name = "Cap" -- HeroPowers throws the part named Cap as Jam's shield, so v5 Jam's own lid does that job
		end
		part.Size *= 0.01
		part.CFrame = FACE_SWAP * CFrame.new(part.Position * 0.01)
		part.PivotOffset = part.CFrame:Inverse() -- pivot = hang point = model-space origin
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.new(1, 1, 1)
		if part.Name == "Body" then
			part.Material, part.Transparency = Enum.Material.Glass, 0.55
			part.Color, part.Reflectance = Color3.fromHex(spec.Glass), 0.08
			part.Parent = root
		elseif part.Name:find("^Shard_") then
			part.Material, part.Transparency = Enum.Material.Glass, 0.15
			part.Color = Color3.fromHex(spec.Fill)
			part.Parent = shards
		else
			if part.Name == "Fill" then
				part.Color = Color3.fromHex(spec.Fill)
			elseif part.Name == "Cap" or part.Name == "Stopper" then
				part.Color = Color3.fromHex(spec.Top or spec.Fill)
			elseif part.Name == "Rim" or part.Name == "Handle" then
				part.Material, part.Transparency = Enum.Material.Glass, 0.4
				part.Color = Color3.fromHex(spec.Glass)
			elseif part.Name == "Fizz" then
				part.Color = Color3.fromHex("#EAF8FF")
			elseif part.Name:find("^Face") then
				part.Transparency = if part.Name == "FaceIdle" then 0 else 1
				part:SetAttribute("BuddyFace", string.sub(part.Name, 5))
			end
			part.Parent = details
		end
	end
	loaded:Destroy()
	local old = library:FindFirstChild(id)
	if old then
		if old:GetAttribute("BuddyVersion") then
			old:Destroy()
		else
			old.Parent = backup
		end
	end
	root.Parent = library
	report[#report + 1] = id .. ":" .. count
	task.wait()
end
return table.concat(report, " ")
