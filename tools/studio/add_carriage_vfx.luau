-- Adds the Moonlantern Carriage's ride VFX to the installed template (Edit mode, run once).
-- Everything tagged RideEmitter starts disabled; RideController enables it near the camera.
-- Re-running is refused so the template is never doubled up.
local RS = game:GetService("ReplicatedStorage")
local m = RS.Assets.Seasonal.Hollowlight.moonlantern_carriage
assert(not m:GetAttribute("VfxVersion"), "carriage VFX already installed")
local mint, gold, amber, violet =
	Color3.fromHex("#61EFBD"), Color3.fromHex("#DDA84D"), Color3.fromHex("#FFB347"), Color3.fromHex("#B48CFF")
local sparkle = "rbxasset://textures/particles/sparkles_main.dds"
local glint = "rbxassetid://118014953401567"

local function tag(effect)
	effect:SetAttribute("RideEmitter", true)
	effect.Enabled = false
	return effect
end

local function emitter(parent, name, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.LightEmission, e.LightInfluence, e.Rate = 1, 0, props.Rate
	for key, value in props do
		if key ~= "Rate" then
			e[key] = value
		end
	end
	e.Parent = parent
	return tag(e)
end

local function attachment(parent, name, worldPosition)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = parent
	a.WorldPosition = worldPosition
	return a
end

local hull = m.Hull
local bottom = hull.Position.Y - hull.Size.Y / 2

-- 1. Hover halo: a mint ring breathing under the moon.
local halo = RS.Assets.VFX.Combat.Meshes.Ring:Clone()
halo.Name = "HoverHalo"
halo.Material, halo.Color, halo.Transparency = Enum.Material.Neon, mint, 0.35
halo.Anchored, halo.CanCollide, halo.CanTouch, halo.CanQuery, halo.CastShadow = true, false, false, false, false
halo.Size = halo.Size * (4.2 / math.max(halo.Size.X, halo.Size.Y, halo.Size.Z))
halo.CFrame = CFrame.new(0, bottom - 0.35, 0) * CFrame.Angles(math.pi / 2, 0, 0)
halo:SetAttribute("RideMotion", "Pulse")
halo.Parent = m

-- 2. Falling stardust under the hull.
local dust = attachment(hull, "Stardust", Vector3.new(0, bottom + 0.1, 0))
emitter(dust, "StardustFall", {
	Rate = 16,
	Texture = glint,
	Color = ColorSequence.new(gold, mint),
	Lifetime = NumberRange.new(1.4, 2.2),
	Speed = NumberRange.new(0.3, 0.8),
	SpreadAngle = Vector2.new(60, 60),
	EmissionDirection = Enum.NormalId.Bottom,
	Acceleration = Vector3.new(0, -1.5, 0),
	Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) }),
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.6) }),
})

-- 3. Twinkles popping on the moon's surface.
emitter(hull, "MoonTwinkles", {
	Rate = 12,
	Texture = glint,
	Color = ColorSequence.new(Color3.new(1, 1, 1), violet),
	Lifetime = NumberRange.new(0.45, 0.7),
	Speed = NumberRange.new(0, 0),
	Shape = Enum.ParticleEmitterShape.Box,
	ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	Rotation = NumberRange.new(0, 360),
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.35, 1.4),
		NumberSequenceKeypoint.new(1, 0),
	}),
	ZOffset = 0.5,
})

-- 4. Wingtip ribbons: one trail per wing between its two outer finger tips (moves with the flap).
for side, sign in { L = -1, R = 1 } do
	local wing = m["Wing_" .. side]
	local half = wing.Size / 2
	local tipFront = attachment(wing, "TipFront", wing.Position + Vector3.new(sign * half.X * 0.95, 0, -half.Z * 0.2))
	local tipBack = attachment(wing, "TipBack", wing.Position + Vector3.new(sign * half.X * 0.55, 0, half.Z * 0.9))
	local trail = Instance.new("Trail")
	trail.Name = "WingRibbon"
	trail.Attachment0, trail.Attachment1 = tipFront, tipBack
	trail.Lifetime, trail.LightEmission, trail.FaceCamera = 0.8, 1, false
	trail.Color = ColorSequence.new(mint, violet)
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Parent = wing
	tag(trail)
end

-- 5. Lantern glow: warm flickering light inside the pumpkin.
local light = Instance.new("PointLight")
light.Name = "LanternGlow"
light.Color, light.Range, light.Brightness, light.Shadows = amber, 9, 1.4, false
light:SetAttribute("BaseBrightness", 1.4)
light.Parent = m.LanternBody
tag(light)

-- 6. Soft glowing mist around the moon and embers rising from the lantern.
emitter(hull, "MoonAura", {
	Rate = 5,
	Texture = "rbxasset://textures/particles/smoke_main.dds",
	Color = ColorSequence.new(violet, mint),
	Lifetime = NumberRange.new(1.4, 2),
	Speed = NumberRange.new(0.2, 0.5),
	Shape = Enum.ParticleEmitterShape.Box,
	ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	RotSpeed = NumberRange.new(-20, 20),
	Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 7) }),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	}),
})
emitter(m.LanternBody, "LanternEmbers", {
	Rate = 8,
	Texture = sparkle,
	Color = ColorSequence.new(amber),
	Lifetime = NumberRange.new(0.8, 1.3),
	Speed = NumberRange.new(0.6, 1.2),
	EmissionDirection = Enum.NormalId.Top,
	SpreadAngle = Vector2.new(25, 25),
	Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
})

-- 7. Tail star spins slowly.
m.TailStar:SetAttribute("RideMotion", "Spin")

-- About 90 live particles per ride, and only within RideEmitterDistance of the camera.
m:SetAttribute("VfxVersion", 3)
return string.format("carriage VFX installed; hull bottom y=%.2f", bottom)
