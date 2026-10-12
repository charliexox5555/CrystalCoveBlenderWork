-- Run through Studio MCP in Edit mode after importing the four M1 bundles.
-- Raw imported meshes are preserved in ServerStorage as a backup.
local spec = game:GetService("HttpService"):JSONDecode(
	[==[{"clash_stand":[{"name":"M1_clash_stand_Crossbar","source":"Crossbar","color":"#D99A58","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_PostCapA","source":"PostCapA","color":"#A86A33","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_LegA_Front","source":"LegA_Front","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_FootA_Front","source":"FootA_Front","color":"#A86A33","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_LegA_Back","source":"LegA_Back","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_FootA_Back","source":"FootA_Back","color":"#A86A33","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_PostCapB","source":"PostCapB","color":"#A86A33","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_LegB_Front","source":"LegB_Front","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_FootB_Front","source":"FootB_Front","color":"#A86A33","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_LegB_Back","source":"LegB_Back","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_FootB_Back","source":"FootB_Back","color":"#A86A33","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_HookA","source":"HookA","color":"#B8C2D6","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_HookB","source":"HookB","color":"#B8C2D6","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_PenFloor","source":"PenFloor","color":"#A86A33","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_FloorBoard_01","source":"FloorBoard_01","color":"#D99A58","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_FloorBoard_02","source":"FloorBoard_02","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_FloorBoard_03","source":"FloorBoard_03","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_FloorBoard_04","source":"FloorBoard_04","color":"#D99A58","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_FloorBoard_05","source":"FloorBoard_05","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_FloorBoard_06","source":"FloorBoard_06","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_FloorBoard_07","source":"FloorBoard_07","color":"#D99A58","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_FloorBoard_08","source":"FloorBoard_08","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_FloorBoard_09","source":"FloorBoard_09","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_FloorBoard_10","source":"FloorBoard_10","color":"#D99A58","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_FloorBoard_11","source":"FloorBoard_11","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_FloorBoard_12","source":"FloorBoard_12","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_FloorBoard_13","source":"FloorBoard_13","color":"#D99A58","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_FloorBoard_14","source":"FloorBoard_14","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_FloorBoard_15","source":"FloorBoard_15","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_FloorBoard_16","source":"FloorBoard_16","color":"#D99A58","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_FloorBoard_17","source":"FloorBoard_17","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_PenWall_1","source":"PenWall_1","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_RailCap_1","source":"RailCap_1","color":"#D99A58","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_CornerPost_1","source":"CornerPost_1","color":"#A86A33","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_PenWall_2","source":"PenWall_2","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_RailCap_2","source":"RailCap_2","color":"#D99A58","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_CornerPost_2","source":"CornerPost_2","color":"#A86A33","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_PenWall_3","source":"PenWall_3","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_RailCap_3","source":"RailCap_3","color":"#D99A58","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_CornerPost_3","source":"CornerPost_3","color":"#A86A33","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_PenWall_4","source":"PenWall_4","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_RailCap_4","source":"RailCap_4","color":"#D99A58","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_CornerPost_4","source":"CornerPost_4","color":"#A86A33","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_PenWall_5","source":"PenWall_5","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_RailCap_5","source":"RailCap_5","color":"#D99A58","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_CornerPost_5","source":"CornerPost_5","color":"#A86A33","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_PenWall_6","source":"PenWall_6","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_RailCap_6","source":"RailCap_6","color":"#D99A58","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_CornerPost_6","source":"CornerPost_6","color":"#A86A33","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_PenWall_7","source":"PenWall_7","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_RailCap_7","source":"RailCap_7","color":"#D99A58","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_CornerPost_7","source":"CornerPost_7","color":"#A86A33","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_PenWall_8","source":"PenWall_8","color":"#C98B4E","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_RailCap_8","source":"RailCap_8","color":"#D99A58","material":"SmoothPlastic","role":"Stand"},{"name":"M1_clash_stand_CornerPost_8","source":"CornerPost_8","color":"#A86A33","material":"SmoothPlastic","role":"Stand"}],"pop":[{"name":"M1_pop_Body","source":"Body","color":"#8FE3FF","material":"Glass","role":"Body"},{"name":"M1_pop_Shard_01","source":"Shard_01","color":null,"material":null,"role":"Shard"},{"name":"M1_pop_Shard_02","source":"Shard_02","color":null,"material":null,"role":"Shard"},{"name":"M1_pop_Shard_03","source":"Shard_03","color":null,"material":null,"role":"Shard"},{"name":"M1_pop_Shard_04","source":"Shard_04","color":null,"material":null,"role":"Shard"},{"name":"M1_pop_Shard_05","source":"Shard_05","color":null,"material":null,"role":"Shard"},{"name":"M1_pop_Shard_06","source":"Shard_06","color":null,"material":null,"role":"Shard"},{"name":"M1_pop_Shard_07","source":"Shard_07","color":null,"material":null,"role":"Shard"},{"name":"M1_pop_Shard_08","source":"Shard_08","color":null,"material":null,"role":"Shard"},{"name":"M1_pop_Shard_09","source":"Shard_09","color":null,"material":null,"role":"Shard"},{"name":"M1_pop_Shard_10","source":"Shard_10","color":null,"material":null,"role":"Shard"},{"name":"M1_pop_Shard_11","source":"Shard_11","color":null,"material":null,"role":"Shard"},{"name":"M1_pop_Shard_12","source":"Shard_12","color":null,"material":null,"role":"Shard"},{"name":"M1_pop_Shard_13","source":"Shard_13","color":null,"material":null,"role":"Shard"},{"name":"M1_pop_Shard_14","source":"Shard_14","color":null,"material":null,"role":"Shard"},{"name":"M1_pop_Shard_15","source":"Shard_15","color":null,"material":null,"role":"Shard"},{"name":"M1_pop_Shard_16","source":"Shard_16","color":null,"material":null,"role":"Shard"},{"name":"M1_pop_Cap","source":"Cap","color":"#F33142","material":"SmoothPlastic","role":"Detail"},{"name":"M1_pop_Bubble_01","source":"Bubble_01","color":"#DEFAFF","material":"Glass","role":"Detail"},{"name":"M1_pop_Bubble_02","source":"Bubble_02","color":"#DEFAFF","material":"Glass","role":"Detail"},{"name":"M1_pop_Bubble_03","source":"Bubble_03","color":"#DEFAFF","material":"Glass","role":"Detail"},{"name":"M1_pop_Bubble_04","source":"Bubble_04","color":"#DEFAFF","material":"Glass","role":"Detail"},{"name":"M1_pop_Bubble_05","source":"Bubble_05","color":"#DEFAFF","material":"Glass","role":"Detail"}],"jam":[{"name":"M1_jam_Body","source":"Body","color":"#FF6B8B","material":"Glass","role":"Body"},{"name":"M1_jam_Shard_01","source":"Shard_01","color":null,"material":null,"role":"Shard"},{"name":"M1_jam_Shard_02","source":"Shard_02","color":null,"material":null,"role":"Shard"},{"name":"M1_jam_Shard_03","source":"Shard_03","color":null,"material":null,"role":"Shard"},{"name":"M1_jam_Shard_04","source":"Shard_04","color":null,"material":null,"role":"Shard"},{"name":"M1_jam_Shard_05","source":"Shard_05","color":null,"material":null,"role":"Shard"},{"name":"M1_jam_Shard_06","source":"Shard_06","color":null,"material":null,"role":"Shard"},{"name":"M1_jam_Shard_07","source":"Shard_07","color":null,"material":null,"role":"Shard"},{"name":"M1_jam_Shard_08","source":"Shard_08","color":null,"material":null,"role":"Shard"},{"name":"M1_jam_Shard_09","source":"Shard_09","color":null,"material":null,"role":"Shard"},{"name":"M1_jam_Shard_10","source":"Shard_10","color":null,"material":null,"role":"Shard"},{"name":"M1_jam_Shard_11","source":"Shard_11","color":null,"material":null,"role":"Shard"},{"name":"M1_jam_Shard_12","source":"Shard_12","color":null,"material":null,"role":"Shard"},{"name":"M1_jam_Shard_13","source":"Shard_13","color":null,"material":null,"role":"Shard"},{"name":"M1_jam_Shard_14","source":"Shard_14","color":null,"material":null,"role":"Shard"},{"name":"M1_jam_Shard_15","source":"Shard_15","color":null,"material":null,"role":"Shard"},{"name":"M1_jam_Shard_16","source":"Shard_16","color":null,"material":null,"role":"Shard"},{"name":"M1_jam_Lid","source":"Lid","color":"#E8BB57","material":"Metal","role":"Detail"}],"prism":[{"name":"M1_prism_Body","source":"Body","color":null,"material":null,"role":"Body"},{"name":"M1_prism_Shard_01","source":"Shard_01","color":null,"material":null,"role":"Shard"},{"name":"M1_prism_Shard_02","source":"Shard_02","color":null,"material":null,"role":"Shard"},{"name":"M1_prism_Shard_03","source":"Shard_03","color":null,"material":null,"role":"Shard"},{"name":"M1_prism_Shard_04","source":"Shard_04","color":null,"material":null,"role":"Shard"},{"name":"M1_prism_Shard_05","source":"Shard_05","color":null,"material":null,"role":"Shard"},{"name":"M1_prism_Shard_06","source":"Shard_06","color":null,"material":null,"role":"Shard"},{"name":"M1_prism_Shard_07","source":"Shard_07","color":null,"material":null,"role":"Shard"},{"name":"M1_prism_Shard_08","source":"Shard_08","color":null,"material":null,"role":"Shard"},{"name":"M1_prism_Shard_09","source":"Shard_09","color":null,"material":null,"role":"Shard"},{"name":"M1_prism_Shard_10","source":"Shard_10","color":null,"material":null,"role":"Shard"},{"name":"M1_prism_Shard_11","source":"Shard_11","color":null,"material":null,"role":"Shard"},{"name":"M1_prism_Shard_12","source":"Shard_12","color":null,"material":null,"role":"Shard"},{"name":"M1_prism_Shard_13","source":"Shard_13","color":null,"material":null,"role":"Shard"},{"name":"M1_prism_Shard_14","source":"Shard_14","color":null,"material":null,"role":"Shard"},{"name":"M1_prism_Shard_15","source":"Shard_15","color":null,"material":null,"role":"Shard"},{"name":"M1_prism_Shard_16","source":"Shard_16","color":null,"material":null,"role":"Shard"}]}]==]
)
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local function folder(parent, name)
	local found = parent:FindFirstChild(name)
	if found then
		return found
	end
	local f = Instance.new("Folder")
	f.Name, f.Parent = name, parent
	return f
end
local assets = folder(RS, "Assets")
local glassies = folder(assets, "Glassies")
local backups = folder(SS, "M1ImportedSources")
assert(not assets:FindFirstChild("ClashStand"), "M1 assets already set up; inspect before rerunning")
local report = {}
for _, id in { "clash_stand", "pop", "jam", "prism" } do
	local original = assert(workspace:FindFirstChild("M1_" .. id), "Missing imported " .. id)
	local model = original:Clone()
	local reference = model:FindFirstChild("M1_" .. id .. (id == "clash_stand" and "_Crossbar" or "_Body"), true)
	local expected = id == "clash_stand" and 22 or ({ pop = 2.2, jam = 1.65, prism = 2.52 })[id]
	local factor = expected / (id == "clash_stand" and reference.Size.X or reference.Size.Y)
	model:ScaleTo(model:GetScale() * factor)
	model:PivotTo(CFrame.Angles(0, math.pi, 0))
	model.Name = id == "clash_stand" and "ClashStand" or id
	local shards, details
	if id ~= "clash_stand" then
		shards = folder(model, "Shards")
		details = folder(model, "Details")
	end
	for _, entry in spec[id] do
		local part = assert(model:FindFirstChild(entry.name, true), entry.name)
		part.Name = entry.source
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
		part.CastShadow = id == "clash_stand"
		part.Reflectance = id == "clash_stand" and 0 or 0.08
		part.TextureID = ""
		for _, child in part:GetChildren() do
			if child:IsA("SurfaceAppearance") then
				child:Destroy()
			end
		end
		local tint = entry.color or (id ~= "clash_stand" and require(RS.Shared.Config.Glassies).ById[id].Tint)
		part.Color = Color3.fromHex(tint)
		part.Material = Enum.Material[entry.material or "Glass"]
		part.Transparency = part.Material == Enum.Material.Glass and 0.3 or 0
		-- Every glassy component rotates around the same world hang point.
		if id ~= "clash_stand" then
			part.PivotOffset = part.CFrame:ToObjectSpace(CFrame.identity)
			if entry.role == "Shard" then
				part.Parent = shards
			end
			if entry.role == "Detail" then
				part.Parent = details
			end
		end
		part:SetAttribute("SourceName", entry.source)
	end
	if id == "clash_stand" then
		local bar = model.Crossbar
		for _, hookName in { "HookA", "HookB" } do
			local hook = model[hookName]
			local attachment = Instance.new("Attachment")
			attachment.Name = hookName
			attachment.Position = bar.CFrame:PointToObjectSpace(hook.Position - Vector3.new(0, 0.26, 0))
			attachment.Parent = bar
		end
	else
		assert(#shards:GetChildren() == 16)
		assert(model.Body:GetPivot().Position.Magnitude < 0.001)
	end
	model.WorldPivot = CFrame.identity
	model:SetAttribute("M1Asset", true)
	model.Parent = id == "clash_stand" and assets or glassies
	original.Parent = backups
	report[id] = { CorrectionFactor = factor, Size = tostring(model:GetExtentsSize()) }
end
local stand = assets.ClashStand:Clone()
stand.Name = "ClashStand"
stand:PivotTo(CFrame.new(0, 0.4, 0))
stand.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
stand.Parent = workspace
local base = workspace:FindFirstChild("Baseplate")
if base then
	base.Color = Color3.fromHex("#728A84")
	base.Material = Enum.Material.SmoothPlastic
	base.Size, base.Position = Vector3.new(160, 1, 160), Vector3.new(0, -0.5, 0)
	for _, child in base:GetChildren() do
		if child:IsA("Texture") or child:IsA("Decal") then
			child.Transparency = 1
		end
	end
end
local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation")
if spawn then
	spawn.CFrame = CFrame.new(0, 0.5, 22)
	spawn.Transparency = 1
	for _, child in spawn:GetChildren() do
		if child:IsA("Texture") or child:IsA("Decal") then
			child.Transparency = 1
		end
	end
end
local floor = Instance.new("Part")
floor.Name = "ArenaWalkFloor"
floor.Size, floor.CFrame = Vector3.new(25, 0.5, 25), CFrame.new(0, 0.25, 0)
floor.Anchored, floor.Transparency = true, 1
floor.Parent = stand
local light = Instance.new("SpotLight")
light.Name, light.Face = "ArenaSpot", Enum.NormalId.Bottom
light.Brightness, light.Range, light.Angle = 2, 35, 110
light.Color, light.Shadows = Color3.fromHex("#FFF3DE"), false
light.Parent = stand.Crossbar
local lighting = game:GetService("Lighting")
lighting.LightingStyle = Enum.LightingStyle.Realistic
lighting.PrioritizeLightingQuality = true
lighting.ClockTime, lighting.Brightness = 14, 2
lighting.Ambient = Color3.fromHex("#8C9EB5")
lighting.OutdoorAmbient = Color3.fromHex("#B7CADB")
lighting.EnvironmentDiffuseScale, lighting.EnvironmentSpecularScale = 0.7, 1
local atmosphere = Instance.new("Atmosphere")
atmosphere.Name, atmosphere.Density, atmosphere.Haze = "M1Atmosphere", 0.18, 0.5
atmosphere.Color, atmosphere.Decay = Color3.fromHex("#D5EBFF"), Color3.fromHex("#A7B7CC")
atmosphere.Parent = lighting
local correction = Instance.new("ColorCorrectionEffect")
correction.Name, correction.Saturation, correction.Contrast = "M1Color", 0.08, 0.03
correction.Parent = lighting
local bloom = Instance.new("BloomEffect")
bloom.Name, bloom.Intensity, bloom.Size, bloom.Threshold = "M1Bloom", 0.12, 24, 1.2
bloom.Parent = lighting
return report
