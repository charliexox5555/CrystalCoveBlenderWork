-- Installs the Glass Buddies v5 bundles into ReplicatedStorage.Assets.GlassiesV5 (Edit mode, MCP).
-- Asset ids: assets/blender/glassies_v5/roblox_assets.json. Colours: tools/blender/build_buddies_v5.py.
-- Rerunning replaces only GlassiesV5; Assets.Glassies (live art) is never touched.
local IS = game:GetService("InsertService")
local RS = game:GetService("ReplicatedStorage")
local BUDDIES = {
	pop = { Asset = 89666168724292, Fill = "#1E7BFF", Glass = "#BFE6FF", Top = "#FF3B4E" },
	jam = { Asset = 80478873695989, Fill = "#FF8A1F", Glass = "#FFE7C4", Top = "#FFC93C" },
	prism = { Asset = 104252975578425, Fill = "#8B4DFF", Glass = "#E4D6FF", Top = "#FFE36E" },
	glass_cup = { Asset = 120158899370566, Fill = "#6FE01F", Glass = "#E2FFC9" },
	water_jug = { Asset = 136014486642992, Fill = "#10CFC0", Glass = "#C8FFF7", Top = "#FFFFFF" },
	ketchup_bottle = { Asset = 95459940693266, Fill = "#F2212F", Glass = "#FFD2D2", Top = "#FFD23C" },
}
local FACE_SWAP = CFrame.Angles(0, math.pi, 0) -- FBX brings Blender's -Y front in as -Z; the fight camera sits at +Z
local library = RS.Assets:FindFirstChild("GlassiesV5")
if library then
	library:Destroy()
end
library = Instance.new("Folder")
library.Name = "GlassiesV5"
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
	root.Parent = library
	report[#report + 1] = id .. ":" .. count
	task.wait()
end
library.Parent = RS.Assets
return table.concat(report, " ")
