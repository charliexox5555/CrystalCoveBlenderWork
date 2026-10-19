-- Edit mode (Studio MCP execute_luau), with the Studio lock held. Installs the Finishers V2 Blender meshes
-- (assets/blender/round_cosmetics/finishers_v3, Open Cloud asset 100127262224695) into
-- ReplicatedStorage.Assets.VFX.FinishersV3, where Presentation/Finishers/Kit finds them by name. The raw insert is
-- archived in ServerStorage.FinishersV3Import and any earlier FinishersV3 folder is moved to
-- ServerStorage.FinishersV3Backup_<time>. Sizes come from manifest.json (the importer may scale by 100).
-- Also resolves the five texture Decals to image ids and returns them for Config/FinisherShows.Textures.
local InsertService = game:GetService("InsertService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local MODEL = 100127262224695
local SIZES = {
	FV3_PrismFacet = Vector3.new(1.9021, 1.809, 0.44),
	FV3_PrismSliver = Vector3.new(2.0, 0.24, 0.2078),
	FV3_PinataPoint = Vector3.new(0.9315, 1.1471, 0.6375),
	FV3_PinataCore = Vector3.new(1.4651, 1.3934, 1.18),
	FV3_CandyGem = Vector3.new(2.0, 0.72, 0.72),
	FV3_FizzCrown = Vector3.new(2.306, 1.031, 2.2482),
	FV3_FizzDrops = Vector3.new(2.481, 0.18, 2.4149),
	FV3_ToyBlock = Vector3.new(0.9466, 0.9466, 0.9466),
	FV3_BlockLetterB = Vector3.new(0.4081, 0.5832, 0.144),
	FV3_BlockLetterO = Vector3.new(0.6259, 0.5988, 0.144),
	FV3_BlockLetterM = Vector3.new(0.5455, 0.5832, 0.144),
	FV3_BurstSign = Vector3.new(2.0519, 1.9735, 0.14),
	FV3_StarCore = Vector3.new(2.0, 2.0, 1.4),
	FV3_StarHaloBand = Vector3.new(2.0, 2.0, 0.08),
	FV3_StarHaloGems = Vector3.new(2.26, 2.26, 0.15),
	FV3_NovaRay = Vector3.new(2.0, 0.32, 0.08),
}
local DOUBLE = {
	FV3_BlockLetterB = true,
	FV3_BlockLetterO = true,
	FV3_BlockLetterM = true,
	FV3_BurstSign = true,
	FV3_StarHaloBand = true,
	FV3_StarHaloGems = true,
	FV3_NovaRay = true,
	FV3_PrismFacet = true,
	FV3_FizzCrown = true,
}
local DECALS = {
	StarGlint = 139579539577297,
	SoftGlow = 80352675328595,
	Streak = 125255282401568,
	Bubble = 90847992301906,
	Confetti = 118322061883783,
}

local function load(id)
	for attempt = 1, 6 do
		local ok, result = pcall(InsertService.LoadAsset, InsertService, id)
		if ok then
			return result
		end
		task.wait(attempt * 2)
	end
	error("could not load asset " .. id)
end

local raw = load(MODEL)
local archive = SS:FindFirstChild("FinishersV3Import")
if archive then
	archive:Destroy()
end
raw.Name = "FinishersV3Import"
raw.Parent = SS

local vfx = RS.Assets.VFX
local old = vfx:FindFirstChild("FinishersV3")
if old then
	old.Name = "FinishersV3Backup_" .. os.time()
	old.Parent = SS
end
local folder = Instance.new("Folder")
folder.Name = "FinishersV3"
local found, missing = 0, {}
for name, size in SIZES do
	local source
	for _, d in raw:GetDescendants() do
		if d:IsA("MeshPart") and (d.Name == name or d.Name == name:sub(5)) then
			source = d
			break
		end
	end
	if not source then
		table.insert(missing, name)
		continue
	end
	local p = source:Clone()
	for _, child in p:GetChildren() do
		child:Destroy()
	end
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new()
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = Color3.new(1, 1, 1)
	p.TextureID = ""
	-- Flat pieces and font glyphs import with some faces wound inward; render both sides.
	p.DoubleSided = DOUBLE[name] == true
	p.Parent = folder
	found += 1
end
folder.Parent = vfx

local images = {}
for key, id in DECALS do
	local ok, model = pcall(load, id)
	local decal = ok and model:FindFirstChildWhichIsA("Decal", true)
	images[key] = decal and decal.Texture or ("failed: " .. tostring(model))
	if ok then
		model:Destroy()
	end
end
local lines = { string.format("installed %d/16 meshes; missing: %s", found, table.concat(missing, ", ")) }
for key, image in images do
	table.insert(lines, key .. " = " .. tostring(image))
end
return table.concat(lines, "\n")
