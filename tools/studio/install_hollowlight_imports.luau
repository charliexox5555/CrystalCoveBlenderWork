-- Edit/MCP only. Load hollowlight_import_data.json into _G.HollowlightImportData first.
assert(not game:GetService("RunService"):IsRunning(), "Install in Edit")
local data = assert(_G.HollowlightImportData, "Load checked-in manifest data")
local RS, SS = game.ReplicatedStorage, game.ServerStorage
local assets = RS.Assets
assert(not SS:FindFirstChild("HollowlightBeforeV2"), "Already installed; preserve current art")
assert(
	not assets:FindFirstChild("Seasonal") or not assets.Seasonal:FindFirstChild("Hollowlight"),
	"Preserve existing seasonal assets"
)
local raw = assert(workspace:FindFirstChild("HOLLOWLIGHT_V2_IMPORT"), "Missing raw import")
local sources, ids, count = {}, {}, 0
for _, item in raw:GetDescendants() do
	assert(not item:IsA("LuaSourceContainer"), "Unexpected script in geometry import")
	if item:IsA("BasePart") then
		assert(item:IsA("MeshPart") and item.MeshId ~= "", "Every component requires an uploaded MeshPart")
		assert(not sources[item.Name], "Duplicate mesh " .. item.Name)
		sources[item.Name] = item
		ids[item.Name] = item.MeshId
		count += 1
	end
end
assert(count == 68 and data.releaseCount == 24, "Expected fixed-roster 68-mesh bundle")
for _, list in data.groups do
	for _, d in list do
		local p = assert(sources[d.name], "Missing mesh " .. d.name)
		local size = Vector3.new(unpack(d.size))
		assert((p.Size / 100 - size).Magnitude < 0.001, "Unexpected import scale: " .. d.name)
		assert(p.CFrame.Rotation:FuzzyEq(CFrame.identity, 0.001), "Unexpected import orientation: " .. d.name)
	end
end
local staged = Instance.new("Folder")
staged.Name = "Hollowlight"
staged:SetAttribute("Version", 2)
staged:SetAttribute("SaleEnabled", false)
staged:SetAttribute("BaseGlassy", "pop")
staged:SetAttribute("ReleaseCount", 24)
local glassy, ride, finisher = Instance.new("Model"), Instance.new("Model"), Instance.new("Model")
glassy.Name, ride.Name, finisher.Name = "pop_hollowlight", "lantern_skiff", "lantern_eclipse"
local details, shards = Instance.new("Folder"), Instance.new("Folder")
details.Name, details.Parent, shards.Name, shards.Parent = "Details", glassy, "Shards", glassy
local fit = assets.Glassies.pop.Body.Size.X / data.groups.pumpkin[1].size[1]
local deck = Vector3.new(0, 0.33, 0)
for group, list in data.groups do
	for _, d in list do
		local p = sources[d.name]:Clone()
		for _, child in p:GetChildren() do
			child:Destroy()
		end
		local scale = if group == "pumpkin" or group == "shards" then fit else 1
		local center = Vector3.new(unpack(d.center)) * scale - (if group == "flyer" then deck else Vector3.zero)
		p.Size = Vector3.new(unpack(d.size)) * scale
		-- Import bakes a half-turn into mesh coordinates; undo it around each mesh center.
		p.CFrame = CFrame.new(center) * CFrame.Angles(0, math.pi, 0)
		p.PivotOffset = p.CFrame:Inverse()
		p.TextureID, p.Color, p.Material = "", Color3.fromHex(d.color), Enum.Material[d.material]
		p.Transparency = if d.material == "Glass" then 0.18 else 0
		p.Reflectance = if d.material == "Glass" then 0.08 else 0
		p.DoubleSided = true
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
		p:SetAttribute("ImportName", d.name)
		p:SetAttribute("Triangles", d.triangles)
		if group == "pumpkin" then
			p.Name = d.name:gsub("HH2_Pumpkin_", "")
			if p.Name == "Stem" or p.Name == "Curl" then
				p.Name = "Cap" .. p.Name
			end
			p.Parent = if p.Name == "Body" then glassy else details
		elseif group == "shards" then
			p.Name, p.Parent = d.name:gsub("HH2_Pumpkin_", ""), shards
		elseif group == "flyer" then
			-- Align the Blender -Y nose to the rider's Roblox -Z direction.
			p.CFrame = CFrame.Angles(0, math.pi, 0) * p.CFrame
			p.PivotOffset = p.CFrame:Inverse()
			p.Name, p.Parent = d.name:gsub("HH2_Skiff_", ""), ride
			if p.Name:find("Wing") or p.Name:find("GlowVein") then
				local side = if d.center[1] < 0 then -1 else 1
				p:SetAttribute("RideMotion", "Wing")
				p:SetAttribute("WingSide", -side)
				local hinge = CFrame.Angles(0, math.pi, 0):VectorToWorldSpace(Vector3.new(side, 0.05, 0) - deck)
				p:SetAttribute("WingPivot", p.CFrame:PointToObjectSpace(hinge))
			elseif p.Name:find("Exhaust") then
				p:SetAttribute("RideMotion", "Exhaust")
			end
		else
			p.Name, p.Parent = d.name:gsub("HH2_Eclipse_", ""), finisher
		end
	end
end
for _, model in { glassy, ride, finisher } do
	model.WorldPivot = CFrame.identity
	model:SetAttribute("BlenderAuthored", true)
	model:SetAttribute("Version", 2)
	model.Parent = staged
end
glassy:SetAttribute("SkinId", "hollowlight")
glassy:SetAttribute("BaseGlassy", "pop")
glassy:SetAttribute("ReleaseVersion", 2)
glassy:SetAttribute("PresentationScale", fit)
ride:SetAttribute("PoseId", "prism_ray")
ride:SetAttribute("SourceForward", -Vector3.zAxis)
ride:SetAttribute("DisplayName", "Lantern Skiff")
finisher:SetAttribute("DisplayName", "Lantern Eclipse")
local kit = assets.VFX.HollowlightPrototype:Clone()
for key, value in
	{
		ConvergeStart = 0.25,
		ReleaseAt = 0.65,
		FadeAt = 0.85,
		ConvergeRadius = 0.35,
		ScatterRadius = 3,
		WispBob = 0.18,
		WispRise = 0.8,
		RingStartScale = 0.35,
		RingEndScale = 3,
		SpiralConvergeScale = 0.75,
		SpiralEndScale = 1.65,
		CoreStartScale = 0.8,
		CoreEndScale = 1.4,
		CoreFadeSpeed = 3,
		ReducedParticleDivisor = 3,
	}
do
	kit:SetAttribute(key, value)
end
kit.Parent = staged
local backup = Instance.new("Folder")
backup.Name, backup.Parent = "HollowlightBeforeV2", SS
local seasonal = assets:FindFirstChild("Seasonal") or Instance.new("Folder")
seasonal.Name, seasonal.Parent = "Seasonal", assets
staged.Parent = seasonal
raw.Parent = backup
_G.HollowlightInstalledMeshIds = ids
return {
	Installed = 68,
	Path = staged:GetFullName(),
	PumpkinFit = fit,
	Originals = raw:GetFullName(),
	SaleEnabled = false,
}
