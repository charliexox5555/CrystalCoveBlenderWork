-- Flyer ride effects (docs/art/FLYERS_V3.md section 3), shared by install_flyers_v3.luau (v3 meshes) and
-- flyers_v2_effects.luau (current meshes). Not run alone: hosts prepend this file to their own source.
-- EFFECTS[id](P, A): P = role -> part (Rail, Body, Wing_L, ...), A = attachment name -> Attachment.
-- Everything starts disabled; RideMotion enables RideEmitter effects near the camera and bursts RideLaunch.
local TEX = {
	glint = "rbxassetid://118014953401567",
	streak = "rbxassetid://125001828353860",
	puff = "rbxassetid://95994848531562",
	fleck = "rbxassetid://119749428254490",
	fire = "rbxasset://textures/particles/fire_main.dds",
	sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	droplet = "rbxassetid://118823344389220",
}
local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end
local function seq(points)
	local keys = {}
	for _, p in points do
		table.insert(keys, ColorSequenceKeypoint.new(p[1], Color3.fromHex(p[2])))
	end
	return ColorSequence.new(keys)
end
local function nseq(points)
	local keys = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(keys)
end

local EFFECTS = {}
local function emitter(parent, name, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	for k, v in props do
		if k ~= "Tag" and k ~= "Burst" then
			e[k] = v
		end
	end
	e.Enabled = false
	if props.Burst then
		e:SetAttribute("RideLaunch", true)
		e:SetAttribute("EmitCount", props.Burst)
	else
		e:SetAttribute("RideEmitter", true)
	end
	e.Parent = parent
	return e
end
local function trail(parent, name, a0, a1, props)
	local t = Instance.new("Trail")
	t.Name, t.Attachment0, t.Attachment1 = name, a0, a1
	t.FaceCamera, t.Enabled = true, false
	for k, v in props do
		t[k] = v
	end
	t:SetAttribute("RideEmitter", true)
	t.Parent = parent
	return t
end
local function light(parent, color, brightness, range)
	local l = Instance.new("PointLight")
	l.Color, l.Brightness, l.Range, l.Shadows, l.Enabled = Color3.fromHex(color), brightness, range, false, false
	l:SetAttribute("RideEmitter", true)
	l:SetAttribute("BaseBrightness", brightness)
	l.Parent = parent
	return l
end
local function wake(att, color)
	emitter(att, "WindStreaks", {
		Texture = TEX.streak,
		Color = ColorSequence.new(Color3.fromHex(color)),
		LightEmission = 0.6,
		Transparency = nseq({ { 0, 1 }, { 0.2, 0.55 }, { 1, 1 } }),
		Size = nseq({ { 0, 0.14 }, { 1, 0.08 } }),
		Lifetime = NumberRange.new(0.45, 0.6),
		Rate = 5,
		Speed = NumberRange.new(11, 15),
		EmissionDirection = Enum.NormalId.Back,
		SpreadAngle = Vector2.new(20, 9),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Squash = nseq({ { 0, 1.2 }, { 1, 1.2 } }),
	})
end

-- A second attachment just below `att` so a Trail has height (launch flyers mark one point per trail).
local function pairBelow(att, dy)
	local b = Instance.new("Attachment")
	b.Name = att.Name .. "Low"
	b.Position = att.Position + Vector3.new(0, -(dy or 0.18), 0)
	b.Parent = att.Parent
	return b
end
local function launchBurst(att, color, count)
	emitter(att, "LaunchPuff", {
		Burst = count or 14,
		Texture = TEX.puff,
		Color = ColorSequence.new(Color3.fromHex(color)),
		LightEmission = 0,
		Brightness = 1.3,
		Size = nseq({ { 0, 0.8 }, { 1, 2.4 } }),
		Transparency = nseq({ { 0, 0.35 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.45, 0.7),
		Speed = NumberRange.new(5, 8),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(75, 75),
		Drag = 4,
	})
end

EFFECTS.skyboard = function(P, A)
	local rail = P.Rail
	local props = {
		Color = seq({ { 0, "#9BF6F2" }, { 1, "#FFFFFF" } }),
		Transparency = nseq({ { 0, 0.3 }, { 1, 1 } }),
		Lifetime = 0.35,
		LightEmission = 0.8,
		MinLength = 0.04,
		WidthScale = nseq({ { 0, 1 }, { 1, 0.2 } }),
	}
	trail(rail, "RailTrailR", A.TrailR0, A.TrailR1, props)
	trail(rail, "RailTrailL", A.TrailL0, A.TrailL1, props)
	for _, pod in { A.PodF, A.PodB } do
		emitter(pod, "LiftMotes", {
			Texture = TEX.glint,
			Color = seq({ { 0, "#C9FFFB" }, { 1, "#61D4DF" } }),
			LightEmission = 1,
			Size = nseq({ { 0, 0.32 }, { 1, 0 } }),
			Transparency = nseq({ { 0, 0.1 }, { 1, 0.6 } }),
			Lifetime = NumberRange.new(0.6, 1),
			Rate = 5,
			Speed = NumberRange.new(1.5, 3),
			EmissionDirection = Enum.NormalId.Bottom,
			SpreadAngle = Vector2.new(25, 25),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-90, 90),
		})
	end
	light(A.PodF, "#7FF0EC", 0.9, 7)
	wake(A.Wake, "#E8FFFE")
	emitter(A.Launch, "LaunchPuff", {
		Burst = 14,
		Texture = TEX.puff,
		Color = ColorSequence.new(Color3.fromHex("#E8FFFE")),
		LightEmission = 0.3,
		Size = nseq({ { 0, 0.8 }, { 1, 2.4 } }),
		Transparency = nseq({ { 0, 0.35 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.45, 0.65),
		Speed = NumberRange.new(5, 8),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(75, 75),
		Drag = 4,
	})
	emitter(A.Launch, "LaunchGlints", {
		Burst = 10,
		Texture = TEX.glint,
		Color = ColorSequence.new(Color3.fromHex("#9BF6F2")),
		LightEmission = 1,
		Size = nseq({ { 0, 0.45 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(6, 10),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
	})
end

EFFECTS.cloud_cushion = function(P, A)
	trail(P.RainbowButter, "RainbowWake", A.Trail0, A.Trail1, {
		Color = seq({ { 0, "#F7A8D2" }, { 0.5, "#FFE08A" }, { 1, "#7FE6EA" } }),
		Transparency = nseq({ { 0, 0.25 }, { 1, 1 } }),
		Lifetime = 0.6,
		LightEmission = 0.5,
		MinLength = 0.04,
		WidthScale = nseq({ { 0, 1 }, { 1, 0.4 } }),
	})
	emitter(A.Wisps, "CloudWisps", {
		Texture = TEX.puff,
		Color = ColorSequence.new(Color3.fromHex("#F4F6FF")),
		LightEmission = 0,
		Brightness = 1.3,
		Size = nseq({ { 0, 0.7 }, { 1, 1.7 } }),
		Transparency = nseq({ { 0, 1 }, { 0.25, 0.55 }, { 1, 1 } }),
		Lifetime = NumberRange.new(1.4, 2.2),
		Rate = 4,
		Speed = NumberRange.new(0.6, 1.2),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(35, 35),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-20, 20),
		Drag = 0.6,
	})
	emitter(P.CloudBody, "Twinkles", {
		Texture = TEX.glint,
		Color = seq({ { 0, "#FFE08A" }, { 0.5, "#F7A8D2" }, { 1, "#7FE6EA" } }),
		LightEmission = 1,
		Size = nseq({ { 0, 0 }, { 0.3, 0.32 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Rate = 4,
		Speed = NumberRange.new(0.2, 0.6),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	wake(A.Wake, "#FFFFFF")
	emitter(A.Launch, "LaunchPuff", {
		Burst = 18,
		Texture = TEX.puff,
		Color = ColorSequence.new(Color3.fromHex("#FFFFFF")),
		LightEmission = 0.2,
		Size = nseq({ { 0, 1 }, { 1, 2.8 } }),
		Transparency = nseq({ { 0, 0.3 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.6, 0.9),
		Speed = NumberRange.new(4, 7),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(85, 85),
		Drag = 3,
	})
end

EFFECTS.rocket_skiff = function(P, A)
	for _, side in { "L", "R" } do
		local ex = A["Exhaust_" .. side]
		-- Fully additive fire vanishes against the bright sky and clouds; mostly alpha-blended reads.
		emitter(ex, "FlameCore", {
			Texture = TEX.fire,
			Color = seq({ { 0, "#FFF6D0" }, { 0.4, "#FFC46B" }, { 1, "#FF7A45" } }),
			LightEmission = 0.35,
			Brightness = 4,
			Size = nseq({ { 0, 0.75 }, { 0.5, 0.5 }, { 1, 0.12 } }),
			Transparency = nseq({ { 0, 0.05 }, { 0.6, 0.35 }, { 1, 1 } }),
			Lifetime = NumberRange.new(0.2, 0.3),
			Rate = 36,
			Speed = NumberRange.new(8, 11),
			EmissionDirection = Enum.NormalId.Back,
			SpreadAngle = Vector2.new(6, 6),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-180, 180),
		})
		emitter(ex, "Smoke", {
			Texture = TEX.puff,
			Color = ColorSequence.new(Color3.fromHex("#F6EDE6")),
			LightEmission = 0,
			Brightness = 1.2,
			Size = nseq({ { 0, 0.6 }, { 1, 2 } }),
			Transparency = nseq({ { 0, 0.4 }, { 1, 1 } }),
			Lifetime = NumberRange.new(0.8, 1.2),
			Rate = 6,
			Speed = NumberRange.new(4, 6),
			EmissionDirection = Enum.NormalId.Back,
			SpreadAngle = Vector2.new(12, 12),
			Rotation = NumberRange.new(0, 360),
			Drag = 1.5,
		})
		emitter(ex, "Sparks", {
			Texture = TEX.glint,
			Color = seq({ { 0, "#FFF1B8" }, { 1, "#FF9A55" } }),
			LightEmission = 1,
			Size = nseq({ { 0, 0.22 }, { 1, 0 } }),
			Lifetime = NumberRange.new(0.3, 0.5),
			Rate = 6,
			Speed = NumberRange.new(6, 10),
			EmissionDirection = Enum.NormalId.Back,
			SpreadAngle = Vector2.new(22, 22),
			Acceleration = Vector3.new(0, -8, 0),
		})
		light(ex, "#FFB866", 1.6, 8)
		trail(P["TailFin_" .. side], "FinTrail", A["FinTrail" .. side .. "0"], A["FinTrail" .. side .. "1"], {
			Color = seq({ { 0, "#FFE39A" }, { 1, "#FFFFFF" } }),
			Transparency = nseq({ { 0, 0.4 }, { 1, 1 } }),
			Lifetime = 0.3,
			LightEmission = 0.6,
			MinLength = 0.04,
		})
	end
	wake(A.Wake, "#FFF4E6")
	emitter(A.Launch, "LaunchSmoke", {
		Burst = 16,
		Texture = TEX.puff,
		Color = ColorSequence.new(Color3.fromHex("#FFF0E0")),
		LightEmission = 0.2,
		Size = nseq({ { 0, 1 }, { 1, 3 } }),
		Transparency = nseq({ { 0, 0.35 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(6, 9),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(80, 80),
		Drag = 4,
	})
	emitter(A.Launch, "LaunchSparks", {
		Burst = 14,
		Texture = TEX.glint,
		Color = seq({ { 0, "#FFF1B8" }, { 1, "#FF9A55" } }),
		LightEmission = 1,
		Size = nseq({ { 0, 0.35 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(8, 12),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -12, 0),
		Drag = 2,
	})
end

EFFECTS.prism_ray = function(P, A)
	local prism = seq({
		{ 0, "#FFA8D8" },
		{ 0.25, "#FFE08A" },
		{ 0.5, "#7CE7D5" },
		{ 0.75, "#8FC8FF" },
		{ 1, "#B8A4F4" },
	})
	for _, side in { "L", "R" } do
		trail(P["Wing_" .. side], "PrismTrail", A["WingTip" .. side .. "0"], A["WingTip" .. side .. "1"], {
			Color = prism,
			Transparency = nseq({ { 0, 0.2 }, { 1, 1 } }),
			Lifetime = 0.5,
			LightEmission = 0.8,
			MinLength = 0.03,
			WidthScale = nseq({ { 0, 1 }, { 1, 0.3 } }),
		})
	end
	emitter(P.Body, "PrismGlints", {
		Texture = TEX.glint,
		Color = prism,
		LightEmission = 1,
		Size = nseq({ { 0, 0 }, { 0.25, 0.36 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.6, 1),
		Rate = 6,
		Speed = NumberRange.new(0.4, 1.2),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Rotation = NumberRange.new(0, 360),
	})
	emitter(A.PrismGlow, "PrismSparkle", {
		Texture = TEX.sparkle,
		Color = ColorSequence.new(Color3.fromHex("#B8FFF2")),
		LightEmission = 1,
		Size = nseq({ { 0, 0.4 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.4, 0.7),
		Rate = 4,
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
	})
	light(A.PrismGlow, "#7CE7D5", 1.2, 6)
	wake(A.Wake, "#F0EBFF")
	emitter(A.Launch, "LaunchCrystals", {
		Burst = 22,
		Texture = TEX.fleck,
		Color = prism,
		LightEmission = 0.8,
		Size = nseq({ { 0, 0.3 }, { 1, 0.05 } }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(7, 12),
		SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-300, 300),
		Acceleration = Vector3.new(0, -10, 0),
		Drag = 2,
	})
	emitter(A.Launch, "LaunchGlints", {
		Burst = 14,
		Texture = TEX.glint,
		Color = prism,
		LightEmission = 1,
		Size = nseq({ { 0, 0.55 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(5, 9),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
	})
end

-- Launch flyers (Cosmetics V2, models by workstream F).
EFFECTS.honey_hover = function(P, A)
	for _, key in { "Trail0", "Trail1" } do
		trail(A[key].Parent, "HexTrail", A[key], pairBelow(A[key]), {
			Color = seq({ { 0, "#FFD23F" }, { 1, "#FFF1C9" } }),
			Transparency = nseq({ { 0, 0.3 }, { 1, 1 } }),
			Lifetime = 0.45,
			LightEmission = 0.6,
			MinLength = 0.04,
		})
	end
	for _, key in { "Drip0", "Drip1" } do
		emitter(A[key], "HoneyDrops", {
			Texture = TEX.glint,
			Color = seq({ { 0, "#FFD23F" }, { 1, "#C77A00" } }),
			LightEmission = 0.4,
			Size = nseq({ { 0, 0.28 }, { 1, 0.14 } }),
			Transparency = nseq({ { 0, 0.1 }, { 1, 0.7 } }),
			Lifetime = NumberRange.new(1, 1.4),
			Rate = 3,
			Speed = NumberRange.new(0.2, 0.6),
			EmissionDirection = Enum.NormalId.Bottom,
			SpreadAngle = Vector2.new(10, 10),
			Acceleration = Vector3.new(0, -10, 0),
		})
	end
	light(A.Launch, "#FFC94D", 1.1, 8)
	wake(A.Wake, "#FFF1C9")
	launchBurst(A.Launch, "#FFF1C9")
	emitter(A.Launch, "LaunchGlints", {
		Burst = 12,
		Texture = TEX.glint,
		Color = ColorSequence.new(Color3.fromHex("#FFD23F")),
		LightEmission = 1,
		Size = nseq({ { 0, 0.45 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(6, 10),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
	})
end

EFFECTS.bubble_pod = function(P, A)
	local sheen = seq({ { 0, "#FF9CE0" }, { 0.5, "#FFE58A" }, { 1, "#8FF0FF" } })
	for _, key in { "Trail0", "Trail1" } do
		trail(A[key].Parent, "SheenTrail", A[key], pairBelow(A[key], 0.22), {
			Color = sheen,
			Transparency = nseq({ { 0, 0.35 }, { 1, 1 } }),
			Lifetime = 0.55,
			LightEmission = 0.5,
			MinLength = 0.04,
			WidthScale = nseq({ { 0, 1 }, { 1, 0.3 } }),
		})
	end
	emitter(A.Wake, "BubbleWake", {
		Texture = TEX.droplet,
		Color = sheen,
		LightEmission = 0.3,
		Size = nseq({ { 0, 0.18 }, { 0.2, 0.42 }, { 1, 0.5 } }),
		Transparency = nseq({ { 0, 1 }, { 0.15, 0.35 }, { 0.85, 0.45 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.9, 1.1),
		Rate = 6,
		Speed = NumberRange.new(2, 4),
		EmissionDirection = Enum.NormalId.Back,
		SpreadAngle = Vector2.new(30, 30),
		Drag = 1,
		Acceleration = Vector3.new(0, 1.5, 0),
	})
	wake(A.Wake, "#F4FBFF")
	launchBurst(A.Launch, "#F4FBFF", 12)
	emitter(A.Launch, "LaunchBubbles", {
		Burst = 18,
		Texture = TEX.droplet,
		Color = sheen,
		LightEmission = 0.3,
		Size = nseq({ { 0, 0.3 }, { 1, 0.55 } }),
		Transparency = nseq({ { 0, 0.3 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(4, 7),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 2,
	})
end

EFFECTS.paper_jet = function(P, A)
	for _, key in { "Trail0", "Trail1" } do
		trail(A[key].Parent, "CreaseStreamer", A[key], pairBelow(A[key], 0.12), {
			Color = seq({ { 0, "#FFFFFF" }, { 1, "#BFD8FF" } }),
			Transparency = nseq({ { 0, 0.25 }, { 1, 1 } }),
			Lifetime = 0.5,
			LightEmission = 0.4,
			MinLength = 0.04,
			WidthScale = nseq({ { 0, 1 }, { 1, 0.4 } }),
		})
	end
	emitter(P.Keel, "PaperGlints", {
		Texture = TEX.glint,
		Color = seq({ { 0, "#FFFFFF" }, { 1, "#FFD84D" } }),
		LightEmission = 1,
		Size = nseq({ { 0, 0 }, { 0.3, 0.26 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.5, 0.8),
		Rate = 4,
		Speed = NumberRange.new(0.3, 0.8),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	wake(A.Wake, "#FFFFFF")
	launchBurst(A.Launch, "#FFFFFF")
end

-- No flyer equipped (decision 95): the faint hover pad under a standing rider.
EFFECTS.stand = function(P, A)
	emitter(A.Shimmer, "HoverShimmer", {
		Texture = TEX.glint,
		Color = seq({ { 0, "#DDFBFF" }, { 1, "#9FE3FF" } }),
		LightEmission = 1,
		Size = nseq({ { 0, 0 }, { 0.3, 0.22 }, { 1, 0 } }),
		Transparency = nseq({ { 0, 0.2 }, { 1, 0.8 } }),
		Lifetime = NumberRange.new(0.7, 1.1),
		Rate = 6,
		Speed = NumberRange.new(0.6, 1.2),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(15, 15),
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	light(A.Shimmer, "#9FE3FF", 0.6, 6)
	launchBurst(A.Shimmer, "#E8FFFE", 10)
end
