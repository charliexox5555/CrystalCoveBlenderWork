-- Edit mode (Studio MCP execute_luau), with the Studio lock held. Installs the launch finisher hero meshes (Cosmetics V2)
-- (assets/blender/round_cosmetics/finishers_v4, Open Cloud asset 120805864098504) into
-- ReplicatedStorage.Assets.VFX.FinishersV4, where Presentation/Finishers/Kit finds them by name. The raw insert is
-- archived in ServerStorage.FinishersV4Import and any earlier FinishersV4 folder is moved to
-- ServerStorage.FinishersV4Backup_<time>. Sizes come from manifest.json (the importer may scale by 100).
-- Also resolves the six texture Decals to image ids and returns them for Config/FinisherShows.Textures.
local InsertService = game:GetService("InsertService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local MODEL = 120805864098504
local SIZES = {
	FV4_IceSlab = Vector3.new(1.0, 1.0, 0.29),
	FV4_GlassSnowflake = Vector3.new(2.14, 1.8721, 0.0866),
	FV4_GumballBase = Vector3.new(1.32, 0.7, 1.32),
	FV4_GumballLid = Vector3.new(0.26, 0.18, 0.085),
	FV4_GumballCrank = Vector3.new(0.54, 0.32, 0.25),
	FV4_HoneyHex = Vector3.new(0.985, 0.866, 0.4),
	FV4_BeeBody = Vector3.new(1.02, 0.6, 0.585),
	FV4_BeeStripes = Vector3.new(0.34, 0.61, 0.61),
	FV4_BeeWings = Vector3.new(0.3043, 0.52, 0.36),
	FV4_FrogBody = Vector3.new(1.48, 0.94, 0.9363),
	FV4_FrogCrown = Vector3.new(0.486, 0.31, 0.4825),
	FV4_FlowerStem = Vector3.new(0.42, 1.6, 0.1),
	FV4_FlowerBud = Vector3.new(0.44, 0.44, 0.44),
	FV4_FlowerBloom = Vector3.new(1.2, 1.0592, 0.1764),
	FV4_RainbowArc = Vector3.new(2.0, 1.0, 0.08),
	FV4_SunFeatherPlate = Vector3.new(0.374, 1.2, 0.07),
	FV4_RuneRing = Vector3.new(2.0, 2.0, 0.125),
}
-- Everything in this set is thin or open (plates, petals, wings), so all of it renders both sides.
local DOUBLE = setmetatable({}, {
	__index = function()
		return true
	end,
})
local DECALS = {
	Snow = 86729256648467,
	Petal = 89881978562324,
	Ember = 111718672601067,
	Feather = 79748678383270,
	Heart = 140455465309274,
	Hex = 136299597964686,
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
local archive = SS:FindFirstChild("FinishersV4Import")
if archive then
	archive:Destroy()
end
raw.Name = "FinishersV4Import"
raw.Parent = SS

local vfx = RS.Assets.VFX
local old = vfx:FindFirstChild("FinishersV4")
if old then
	old.Name = "FinishersV4Backup_" .. os.time()
	old.Parent = SS
end
local folder = Instance.new("Folder")
folder.Name = "FinishersV4"
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
local lines = { string.format("installed %d meshes; missing: %s", found, table.concat(missing, ", ")) }
for key, image in images do
	table.insert(lines, key .. " = " .. tostring(image))
end
return table.concat(lines, "\n")
