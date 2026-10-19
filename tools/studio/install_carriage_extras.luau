-- Moonlantern Carriage premium extras (workstream I, docs/vfx/HOLLOWLIGHT_PREMIUM.md section 5).
-- Run in Studio **Edit** (command bar or MCP run_code). It works on the installed
-- ReplicatedStorage.Assets.Seasonal.Hollowlight.moonlantern_carriage, or on _G.HL_CarriageTarget if set (tests).
-- It backs up the model once to ServerStorage.HollowlightCarriageBeforeExtras, then adds:
--   CarriageFX = true; CarriageMotion Glow (engine cores), Twinkle (tail star), Flame (new LanternFlame)
--   MoonDustStream + StreamWisps at the stern (RideEmitter: near the camera only)
--   TakeOffDust + TakeOffWisps bursts (CarriageBurst; CarriageFX fires them on take-off and landing)
-- Idempotent: anything it made before is replaced. Ids, ownership and the v4 meshes are unchanged.
local RS = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local model = _G.HL_CarriageTarget or RS.Assets.Seasonal.Hollowlight.moonlantern_carriage
if not _G.HL_CarriageTarget and not ServerStorage:FindFirstChild("HollowlightCarriageBeforeExtras") then
	local backup = model:Clone()
	backup.Name = "HollowlightCarriageBeforeExtras"
	backup.Parent = ServerStorage
end

local MADE = "HollowlightExtra"
for _, d in model:GetDescendants() do
	if d:GetAttribute(MADE) then
		d:Destroy()
	end
end

local pivot = model:GetPivot()
local function find(name)
	return model:FindFirstChild(name, true)
end
local function mark(obj)
	obj:SetAttribute(MADE, true)
	return obj
end
local function socket(parent, name, localPos)
	local a = mark(Instance.new("Attachment"))
	a.Name = name
	a.Parent = parent
	a.WorldCFrame = pivot * CFrame.new(localPos)
	return a
end
local function seq(...)
	local keys = {}
	local values = { ... }
	for i = 1, #values, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(values[i], values[i + 1]))
	end
	return NumberSequence.new(keys)
end
local function colors(a, b)
	return ColorSequence.new(Color3.fromHex(a), Color3.fromHex(b))
end
local function emitter(parent, name, props)
	local e = mark(Instance.new("ParticleEmitter"))
	e.Name = name
	e.LightEmission, e.LightInfluence = 1, 0
	for k, v in props do
		e[k] = v
	end
	e.Parent = parent
	return e
end

model:SetAttribute("CarriageFX", true)

-- Breathing glows and twinkles on existing parts.
for _, n in { "EngineCore_L", "EngineCore_R" } do
	local p = find(n)
	if p then
		p:SetAttribute("CarriageMotion", "Glow")
	end
end
local tail = find("TailStar")
if tail then
	tail:SetAttribute("CarriageMotion", "Twinkle")
end

-- A flickering flame inside the glass pumpkin; it swings with the lantern.
local body = find("LanternBody")
if body then
	local flame = mark(Instance.new("Part"))
	flame.Name, flame.Shape, flame.Material = "LanternFlame", Enum.PartType.Ball, Enum.Material.Neon
	flame.Color, flame.Transparency, flame.Size = Color3.fromHex("#FFD27A"), 0.12, Vector3.one * body.Size.X * 0.42
	flame.Anchored, flame.CanCollide, flame.CanTouch, flame.CanQuery, flame.CastShadow = true, false, false, false, false
	flame.CFrame = body.CFrame * CFrame.new(0, -body.Size.Y * 0.05, 0)
	flame:SetAttribute("RideMotion", "Swing")
	-- Same hinge as the pumpkin (the pumpkin's SwingPivot is in its own space; the flame shares its rotation).
	local hinge = body.CFrame:PointToWorldSpace(body:GetAttribute("SwingPivot") or Vector3.zero)
	flame:SetAttribute("SwingPivot", flame.CFrame:PointToObjectSpace(hinge))
	flame:SetAttribute("CarriageMotion", "Flame")
	flame.Parent = model
	local light = body:FindFirstChild("LanternGlow")
	if light then
		light:SetAttribute("BaseBrightness", 1.8)
	end
end

-- Magic trail: moon dust and wisps streaming off the stern (Back = +Z = behind the carriage).
local hull = find("Hull")
if hull then
	local stern = socket(hull, "SternStream", Vector3.new(0, 0.2, 2.4))
	emitter(stern, "MoonDustStream", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = colors("#FFF1C2", "#9CFFD8"),
		Rate = 18,
		Lifetime = NumberRange.new(1.2, 1.8),
		Speed = NumberRange.new(3, 5),
		EmissionDirection = Enum.NormalId.Back,
		SpreadAngle = Vector2.new(18, 18),
		Acceleration = Vector3.new(0, -1.2, 0),
		Drag = 0.6,
		Size = seq(0, 0.28, 0.6, 0.18, 1, 0),
		Transparency = seq(0, 0.1, 0.7, 0.35, 1, 1),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
	}):SetAttribute("RideEmitter", true)
	emitter(stern, "StreamWisps", {
		Texture = "rbxassetid://118014953401567",
		Color = colors("#9CFFD8", "#C79BFF"),
		Rate = 3,
		Lifetime = NumberRange.new(1, 1.4),
		Speed = NumberRange.new(2, 3),
		EmissionDirection = Enum.NormalId.Back,
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, 0.6, 0),
		Size = seq(0, 0.5, 0.5, 0.7, 1, 0),
		Transparency = seq(0, 0.3, 0.6, 0.45, 1, 1),
	}):SetAttribute("RideEmitter", true)

	-- Take-off / landing bursts under the hull (fired by CarriageFX, never on a rate).
	local under = socket(hull, "TakeOffSocket", Vector3.new(0, -1.3, 0))
	emitter(under, "TakeOffDust", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = colors("#FFE7A6", "#FFB347"),
		Enabled = false,
		Rate = 0,
		Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(7, 11),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -3, 0),
		Drag = 2.5,
		Size = seq(0, 0.35, 1, 0),
		Transparency = seq(0, 0, 0.8, 0.3, 1, 1),
	}):SetAttribute("CarriageBurst", "TakeOffDust")
	emitter(under, "TakeOffWisps", {
		Texture = "rbxassetid://118014953401567",
		Color = colors("#9CFFD8", "#FFFFFF"),
		Enabled = false,
		Rate = 0,
		Lifetime = NumberRange.new(0.9, 1.3),
		Speed = NumberRange.new(3, 5),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 3, 0),
		Size = seq(0, 0.6, 0.5, 0.9, 1, 0),
		Transparency = seq(0, 0.2, 1, 1),
	}):SetAttribute("CarriageBurst", "TakeOffWisps")
end

return "carriage extras installed on " .. model:GetFullName()
