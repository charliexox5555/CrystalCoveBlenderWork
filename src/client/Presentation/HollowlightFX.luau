-- Lantern Eclipse finisher v2: original Blender actors + native particles, client-only and cosmetic.
-- Beats (Balance.CosmeticPresentation.Eclipse, docs/vfx/HOLLOWLIGHT_PREMIUM.md section 3):
-- ignite -> gather (five-ghost choir spirals in) -> eclipse (moon slides across, its shadow sweeps the floor,
-- the viewed screen grades to moonlight, the choir sings) -> hush -> release (boom, shatter) -> ember fall.
-- The lantern hangs above the recipient so they stay readable; no damage, avatar hiding or physics.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local E = require(RS.Shared.Config.Balance).CosmeticPresentation.Eclipse
local FX = {}

local TAU = math.pi * 2

-- Small wisp puff from the editable kit; Lantern Seeds uses it when its wisps land.
function FX.pressure(parent, position)
	local seasonal = RS.Assets:FindFirstChild("Seasonal")
	local source = seasonal and seasonal:FindFirstChild("Hollowlight")
	if not source then
		return
	end
	local socket = source.HollowlightPrototype.Origin:Clone()
	socket.CFrame, socket.Parent = CFrame.new(position), parent
	local lifetime = 0
	for _, obj in socket:GetDescendants() do
		if obj:IsA("ParticleEmitter") then
			obj.Enabled = false
			if obj.Name == "ChargeWisps" or obj.Name == "LanternPressure" then
				obj:Emit(obj:GetAttribute("BurstCount"))
				lifetime = math.max(lifetime, obj.Lifetime.Max)
			end
		elseif obj:IsA("Beam") then
			obj.Enabled = false
		end
	end
	game:GetService("Debris"):AddItem(socket, lifetime)
	return socket
end

local function clamp01(x)
	return math.clamp(x, 0, 1)
end
local function smooth(x)
	x = clamp01(x)
	return x * x * (3 - 2 * x)
end
local function easeIn(x)
	x = clamp01(x)
	return x * x * x
end
local function easeOut(x)
	x = clamp01(x)
	return 1 - (1 - x) ^ 3
end
-- Back ease-out: 0 -> ~10% overshoot -> 1, for pop-ins.
local function pop(x)
	x = clamp01(x)
	return 1 + 2.70158 * (x - 1) ^ 3 + 1.70158 * (x - 1) ^ 2
end

local function still(p)
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	return p
end

local function actor(root, template, name)
	local p = still(template:Clone())
	p.Name = name or template.Name
	p.Parent = root
	return p
end

local function ball(root, name, color, size)
	local p = still(Instance.new("Part"))
	p.Name, p.Shape, p.Material = name, Enum.PartType.Ball, Enum.Material.Neon
	p.Color, p.Size, p.Transparency = color, Vector3.one * size, 1
	p.Parent = root
	return p
end

-- Floor under the lantern: skip anything that belongs to a character (avatars and bots stand on it).
local function floorY(origin, exclude)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local skip = table.clone(exclude)
	for _ = 1, 6 do
		params.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(origin + Vector3.yAxis * 2, Vector3.yAxis * -40, params)
		if not hit then
			break
		end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChildOfClass("Humanoid") then
			table.insert(skip, model)
		else
			return hit.Position.Y
		end
	end
	return origin.Y - 3
end

-- The grade is only for a show the player is really watching: the viewed fight or the bundle preview stage.
local function wantsGrade(parent, lowDetail)
	if lowDetail then
		return false
	end
	return parent.Name:match("^LocalFight_") ~= nil
		or parent.Name == "BundlePreviewStage"
		or parent:FindFirstAncestor("BundlePreviewStage") ~= nil
end

local function emberEmitter(parent, template, count)
	local e = if template then template:Clone() else Instance.new("ParticleEmitter")
	e.Name, e.Enabled, e.Rate = "EclipseEmbers", false, 0
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex(E.EmberHot)),
		ColorSequenceKeypoint.new(0.35, Color3.fromHex(E.EmberColor)),
		ColorSequenceKeypoint.new(1, Color3.fromHex(E.EmberCool)),
	})
	e.LightEmission, e.LightInfluence, e.Brightness = 1, 0, 2
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.32),
		NumberSequenceKeypoint.new(0.6, 0.22),
		NumberSequenceKeypoint.new(1, 0),
	})
	-- A little flicker on the way down, then they wink out.
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.45, 0.15),
		NumberSequenceKeypoint.new(0.55, 0.45),
		NumberSequenceKeypoint.new(0.65, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(1.0, 1.5)
	e.Speed = NumberRange.new(5, 11)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -6, 0)
	e.Drag = 2.2
	e.Rotation, e.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-200, 200)
	e.ZOffset = 0.5
	e:SetAttribute("BurstCount", count)
	e.Parent = parent
	return e
end

-- Builds every actor up front (pooled for the show's lifetime), then animates them from one clock.
function FX.create(parent, origin, lowDetail, orientation)
	local seasonal = RS.Assets:FindFirstChild("Seasonal")
	local source = seasonal and seasonal:FindFirstChild("Hollowlight")
	if not source then
		return nil
	end
	local art = source.lantern_eclipse
	local root = Instance.new("Folder")
	root.Name = "Finisher_lantern_eclipse"
	root:SetAttribute("CosmeticOnly", true)
	-- Face the camera's heading but stay upright.
	local look = (orientation or workspace.CurrentCamera.CFrame).LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	local basis = CFrame.lookAt(origin, origin + flat)
	local lanternAt = basis * CFrame.new(0, E.LanternHeight, 0)
	local state = { Root = root, Stopped = false, Ghosts = {}, Core = {}, Shards = {}, Stars = {}, Emitters = {} }

	-- Lantern core: the five Core_* parts, kept relative to the amber body, plus a neon glow heart.
	local body = art.Core_AmberGlass
	for _, p in art:GetChildren() do
		if p:IsA("BasePart") and p.Name:match("^Core_") then
			local copy = actor(root, p)
			table.insert(state.Core, {
				Part = copy,
				Offset = body.CFrame:ToObjectSpace(p.CFrame),
				Size = p.Size,
				Alpha = p.Transparency,
			})
		end
	end
	state.Heart = ball(root, "EclipseGlowCore", Color3.fromHex(E.CoreColor), E.CoreSize)

	-- The choir: ghost groups (head + face + tail) cloned from the three authored wisps.
	local ghosts = if lowDetail then E.LowGhosts else E.Ghosts
	for i = 0, ghosts - 1 do
		local k = i % 3
		local head = art["Wisp" .. k]
		local group = { Parts = {}, Phase = i * TAU / ghosts, Index = i }
		for _, name in { "Wisp", "WispFace", "WispTail" } do
			local p = art[name .. k]
			local copy = actor(root, p, name .. i)
			table.insert(group.Parts, {
				Part = copy,
				Offset = head.CFrame:ToObjectSpace(p.CFrame),
				Size = p.Size,
				Alpha = p.Transparency,
				Face = name == "WispFace",
			})
			if name == "Wisp" then
				group.Head = copy
			end
		end
		if not lowDetail then
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Position, a1.Position = Vector3.new(0, 0.35, 0), Vector3.new(0, -0.35, 0)
			a0.Parent, a1.Parent = group.Head, group.Head
			local trail = Instance.new("Trail")
			trail.Attachment0, trail.Attachment1 = a0, a1
			trail.Lifetime, trail.LightEmission, trail.FaceCamera = 0.35, 1, true
			trail.Color = ColorSequence.new(Color3.fromHex("#61EFBD"), Color3.fromHex("#D6F3FF"))
			trail.Transparency = NumberSequence.new(0.2, 1)
			trail.WidthScale = NumberSequence.new(1, 0.2)
			trail.Parent = group.Head
			group.Trail = trail
		end
		table.insert(state.Ghosts, group)
	end

	-- Ground halos and lantern spirals.
	state.Halo = { Part = actor(root, art.Halo), Size = art.Halo.Size }
	state.InnerHalo = { Part = actor(root, art.InnerHalo), Size = art.InnerHalo.Size }
	state.Spirals = {}
	for i = 0, if lowDetail then 0 else 2 do
		local p = art["Spiral" .. i]
		table.insert(state.Spirals, {
			Part = actor(root, p),
			Offset = body.CFrame:ToObjectSpace(p.CFrame),
			Size = p.Size,
		})
	end

	-- Crescent moon (hollowlight_v3); a neon half ring stands in until the mesh is installed.
	local moonSource = source:FindFirstChild("EclipseMoon")
	state.Moon = {}
	if moonSource then
		for _, p in moonSource:GetChildren() do
			if p:IsA("BasePart") then
				local copy = actor(root, p)
				table.insert(state.Moon, {
					Part = copy,
					Offset = moonSource:GetPivot():ToObjectSpace(p.CFrame),
					Size = p.Size,
					Alpha = p.Transparency,
					Rim = p.Name:find("Rim") ~= nil,
				})
			end
		end
	else
		local ring = actor(root, RS.Assets.VFX.Combat.Meshes.HalfRing, "EclipseMoonFallback")
		ring.Material, ring.Color = Enum.Material.Neon, Color3.fromHex(E.MoonColor)
		ring.Size *= 3.4 / math.max(ring.Size.X, ring.Size.Y, ring.Size.Z)
		table.insert(
			state.Moon,
			{ Part = ring, Offset = CFrame.Angles(0, 0, math.pi / 2), Size = ring.Size, Alpha = 0 }
		)
	end

	-- Moon shadow: three stacked discs (core + two softer rings) fake a soft-edged shadow on the floor.
	state.Shadow = {}
	if not lowDetail then
		local exclude = { root, parent }
		local ground = floorY(origin, exclude)
		state.ShadowY = ground + 0.25 -- above pad rings and grass
		for i, scale in { 0.62, 0.82, 1 } do
			local disc = still(Instance.new("Part"))
			disc.Name, disc.Shape, disc.Material =
				"MoonShadow" .. i, Enum.PartType.Cylinder, Enum.Material.SmoothPlastic
			disc.Color, disc.Transparency = Color3.fromHex(E.ShadowColor), 1
			disc.Size = Vector3.new(0.04 + i * 0.01, E.ShadowRadius * 2 * scale, E.ShadowRadius * 2 * scale)
			disc.Parent = root
			table.insert(state.Shadow, { Part = disc, Alpha = E.ShadowTransparency + (i - 1) * 0.18 })
		end
	end

	-- Moonlight grade on the viewed screen (restored on destroy).
	if wantsGrade(parent, lowDetail) then
		local grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "HollowlightEclipseGrade"
		grade.Enabled = true
		grade.Parent = Lighting
		state.Grade = grade
	end

	-- Release actors.
	local flash = still(Instance.new("Part"))
	flash.Name, flash.Shape, flash.Material = "EclipseFlash", Enum.PartType.Ball, Enum.Material.Neon
	flash.Color, flash.Transparency, flash.Size = Color3.new(1, 1, 1), 1, Vector3.one * 0.1
	flash.CFrame, flash.Parent = lanternAt, root
	state.Flash = flash
	if not lowDetail then
		local light = Instance.new("PointLight")
		light.Range, light.Brightness, light.Color = E.LightRange, 0, Color3.fromHex(E.LightColor)
		light.Shadows = false
		light.Parent = flash
		state.Light = light
	end
	local hero = RS.Assets.VFX:FindFirstChild("RoundHeroV2")
	local shockSource = (hero and hero:FindFirstChild("ShockCrown")) or RS.Assets.VFX.Combat.Meshes.Ring
	state.Shock = actor(root, shockSource, "EclipseShock")
	state.Shock.Material, state.Shock.Color, state.Shock.Transparency =
		Enum.Material.Neon, Color3.fromHex(E.RimColor), 1
	state.ShockSize = state.Shock.Size / math.max(state.Shock.Size.X, state.Shock.Size.Z)
	state.Ring = actor(root, RS.Assets.VFX.Combat.Meshes.Ring, "EclipseRing")
	state.Ring.Material, state.Ring.Color, state.Ring.Transparency = Enum.Material.Neon, Color3.fromHex("#61EFBD"), 1
	state.RingSize = state.Ring.Size / math.max(state.Ring.Size.X, state.Ring.Size.Y, state.Ring.Size.Z)

	-- The lantern breaks into Hollowlight's real pre-fractured shards.
	local glassy = RS.Assets.Glassies:FindFirstChild("hollowlight")
	if glassy then
		local center = glassy.Body.Position
		local scale = body.Size.X * E.LanternScale / glassy.Body.Size.X * E.ShardScale
		local random = Random.new(7)
		for index, template in glassy.Shards:GetChildren() do
			if lowDetail and index % 2 == 0 then
				continue
			end
			local shard = actor(root, template, "LanternShard")
			shard.Size = template.Size * scale
			-- Alternate lit amber and tinted glass so the pieces read as lantern light, not rind.
			local glow = index % 2 == 1
			shard.Color = Color3.fromHex(if glow then E.ShardGlowColor else E.ShardColor)
			shard.Material = if glow then Enum.Material.Neon else Enum.Material.Glass
			shard.Transparency = 1
			shard:SetAttribute("RestTransparency", if glow then 0.1 else 0.2)
			local offset = (template.Position - center) * scale
			local direction = if offset.Magnitude > 0.01 then offset.Unit else Vector3.yAxis
			table.insert(state.Shards, {
				Part = shard,
				Offset = offset,
				Rotation = template.CFrame.Rotation,
				Velocity = direction * E.ShardSpeed * random:NextNumber(0.7, 1.2) + Vector3.yAxis * E.ShardLift,
				Spin = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-1, 1), random:NextNumber(-1, 1))
					* E.ShardSpin,
			})
		end
	end
	if hero and hero:FindFirstChild("NovaStar") then
		for i = 1, if lowDetail then 0 else E.Stars do
			local star = actor(root, hero.NovaStar, "EclipseStar")
			star.Material, star.Color, star.Transparency = Enum.Material.Neon, Color3.fromHex(E.RimColor), 1
			star.Size *= 0.7 / math.max(star.Size.X, star.Size.Y, star.Size.Z)
			local angle = i / E.Stars * TAU
			table.insert(state.Stars, {
				Part = star,
				Size = star.Size,
				Direction = basis:VectorToWorldSpace(Vector3.new(math.cos(angle), math.sin(angle), 0)),
			})
		end
		-- The last glint: one bright star pops where the lantern was, then the stage is clear.
		local glint = actor(root, hero.NovaStar, "EclipseGlint")
		glint.Material, glint.Color, glint.Transparency = Enum.Material.Neon, Color3.fromHex(E.EmberHot), 1
		glint.Size *= 1.1 / math.max(glint.Size.X, glint.Size.Y, glint.Size.Z)
		state.Glint = { Part = glint, Size = glint.Size }
	end

	-- Native particle kit at the lantern; emitters fire on beats, beams bind lantern to ghosts.
	local kit = source.HollowlightPrototype:Clone()
	kit.Origin.CFrame = lanternAt
	kit.Parent = root
	local linger, divisor = 0, kit:GetAttribute("ReducedParticleDivisor") or 2
	local beats = {
		ChargeWisps = { 0.05, E.EclipseAt, E.ReleaseAt + 0.15 },
		LanternPressure = { E.ReleaseAt },
		AmberGlassGlints = { E.ReleaseAt },
		VioletDust = { E.ReleaseAt + 0.05 },
	}
	state.Beams = {}
	local glintTemplate
	for _, obj in kit:GetDescendants() do
		if obj:IsA("ParticleEmitter") then
			obj.Enabled = false
			linger = math.max(linger, obj.Lifetime.Max)
			if obj.Name == "AmberGlassGlints" then
				glintTemplate = obj
			end
			for _, at in beats[obj.Name] or { obj:GetAttribute("PhaseStart") or E.ReleaseAt } do
				table.insert(state.Emitters, { Emitter = obj, At = at })
			end
		elseif obj:IsA("Beam") then
			obj.Enabled = false
			table.insert(state.Beams, obj)
		end
	end
	-- One binding beam per singer: clone the authored ribbon for the extra ghosts.
	if not lowDetail and state.Beams[1] then
		while #state.Beams < #state.Ghosts do
			local beam = state.Beams[1]:Clone()
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Parent, a1.Parent = flash, flash
			beam.Attachment0, beam.Attachment1 = a0, a1
			beam.Parent = flash
			table.insert(state.Beams, beam)
		end
	end
	-- Embers: sucked into the lantern during the gather, then a falling shower on release.
	local embers = emberEmitter(flash, glintTemplate, E.Embers)
	table.insert(state.Emitters, { Emitter = embers, At = E.ReleaseAt })
	linger = math.max(linger, embers.Lifetime.Max)
	if not lowDetail then
		local swirlHost = still(Instance.new("Part"))
		swirlHost.Name, swirlHost.Transparency = "EclipseSwirl", 1
		swirlHost.Size = Vector3.one * E.SwirlRadius * 2
		swirlHost.CFrame, swirlHost.Parent = lanternAt, root
		local swirl = emberEmitter(swirlHost, glintTemplate, 0)
		swirl.Name = "EclipseSwirl"
		swirl.Shape, swirl.ShapeStyle, swirl.ShapeInOut =
			Enum.ParticleEmitterShape.Sphere,
			Enum.ParticleEmitterShapeStyle.Surface,
			Enum.ParticleEmitterShapeInOut.Inward
		swirl.Speed, swirl.Lifetime = NumberRange.new(6, 8), NumberRange.new(0.5, 0.65)
		swirl.Acceleration, swirl.Drag = Vector3.zero, 0
		swirl.Rate = E.SwirlRate
		state.Swirl = swirl
	end
	state.Lifetime = E.Duration + linger

	function state:Destroy()
		if self.Stopped then
			return
		end
		self.Stopped = true
		if self.Connection then
			self.Connection:Disconnect()
		end
		if self.Grade then
			self.Grade:Destroy()
		end
		self.Root:Destroy()
	end

	function state:Step(t)
		if self.Stopped then
			return
		end
		if not root.Parent or t >= self.Lifetime then
			self:Destroy()
			return
		end
		local released = t >= E.ReleaseAt
		local after = math.max(0, t - E.ReleaseAt)
		local disperse = clamp01(after / (E.Duration - E.ReleaseAt))
		local gather = smooth((t - E.GatherAt) / (E.EclipseAt - E.GatherAt))
		local eclipse = smooth((t - E.EclipseAt) / (E.HushAt - E.EclipseAt))
		local hush = if t >= E.HushAt and not released
			then 1 - 0.1 * smooth((t - E.HushAt) / (E.ReleaseAt - E.HushAt))
			else 1

		-- Lantern: pop in with squash and stretch, flicker under the moon, vanish on release.
		local grow = pop(t / E.PopSeconds) * E.LanternScale * hush
		local squash = 1 + math.sin(clamp01(t / E.PopSeconds) * math.pi) * 0.22
		local scale = Vector3.new(grow / squash, grow * squash, grow / squash)
		local bob = math.sin(t * 5) * 0.12
		local lantern = lanternAt * CFrame.new(0, bob, 0) * CFrame.Angles(0, math.sin(t * 2) * 0.25, 0)
		local flicker = eclipse * (0.5 + 0.5 * math.sin(t * 60))
		for _, c in self.Core do
			c.Part.CFrame = lantern * CFrame.new(c.Offset.Position * scale) * c.Offset.Rotation
			c.Part.Size = c.Size * scale
			local glow = if c.Part.Name == "Core_WispMint" then flicker * 0.7 else 0
			c.Part.Transparency = if released then 1 else math.max(c.Alpha, glow)
		end
		-- Glow heart: lights on ignite, swells through the gather, stays hot under the moon, dims in the hush.
		local burn = math.min(1, t / 0.2) * (1 + E.CoreGrow * gather) * (1 + 0.08 * math.sin(t * 23))
		self.Heart.CFrame = lantern
		self.Heart.Size = Vector3.one * E.CoreSize * burn * grow / E.LanternScale
		self.Heart.Transparency = if released then 1 else 0.25 + 2.5 * (1 - hush)

		-- Ghosts: swoop in on a wide spiral, circle tight and sing in a wave, then scatter upward and fade.
		for _, g in self.Ghosts do
			local swoop = easeIn((t - E.GatherAt) / (E.EclipseAt - E.GatherAt))
			local radius = E.GhostStartRadius + (E.GhostOrbitRadius - E.GhostStartRadius) * swoop
			radius += (E.GhostTightRadius - E.GhostOrbitRadius) * eclipse
			radius *= hush
			local height = E.GhostStartHeight * (1 - swoop)
			local spin = if t >= E.HushAt and not released then 0.15 else 0.4 + swoop + eclipse
			local angle = g.Phase + t * E.GhostSpin * spin
			local fade = 0
			local sing = 0
			if eclipse > 0 and not released then
				local wave = math.sin(t * E.ChoirHz * TAU - g.Phase)
				sing = math.max(0, wave) * eclipse * hush
				height += wave * E.ChoirBob * eclipse
			end
			if released then
				radius += E.GhostScatter * easeOut(disperse)
				height += E.GhostRise * disperse * disperse
				angle += disperse * 2
				fade = smooth((disperse - 0.4) / 0.6)
			end
			local tremble = if t >= E.HushAt and not released
				then Vector3.new(math.noise(t * 20, g.Phase), math.noise(g.Phase, t * 20), 0) * E.GhostTremble
				else Vector3.zero
			local at = (lantern * CFrame.new(math.cos(angle) * radius, height - 0.6, math.sin(angle) * radius)).Position
				+ tremble
			local heading = basis.Rotation * CFrame.Angles(0, 0, math.sin(angle) * 0.3)
			local appear = clamp01((t - E.GatherAt + 0.12) / 0.18)
			local s = E.GhostScale * math.max(0.01, appear)
			for _, p in g.Parts do
				local stretch = if p.Face then Vector3.new(1, 1 + sing * E.ChoirMouth, 1) else Vector3.one
				p.Part.CFrame = CFrame.new(at) * heading * CFrame.new(p.Offset.Position * s) * p.Offset.Rotation
				p.Part.Size = p.Size * s * stretch
				p.Part.Transparency = if appear <= 0 then 1 else p.Alpha + (1 - p.Alpha) * fade
			end
			if g.Trail then
				g.Trail.Enabled = appear > 0 and fade < 0.9
			end
		end

		-- Ground halo: spreads during the gather, pulses in the eclipse, rings out on release.
		local pulse = 1 + eclipse * 0.08 * math.sin(t * 30)
		local haloScale = if released
			then E.HaloScale + (E.HaloReleaseScale - E.HaloScale) * easeOut(after / 0.5)
			else math.max(0.01, smooth(t / E.EclipseAt) * E.HaloScale * pulse)
		for i, h in { self.Halo, self.InnerHalo } do
			h.Part.CFrame = basis * CFrame.new(0, 0.08 * i, 0)
			h.Part.Size = Vector3.new(h.Size.X * haloScale, h.Size.Y, h.Size.Z * haloScale)
			h.Part.Transparency = if released then smooth(after / 0.6) else 0.15
		end

		-- Spirals wind in around the lantern, then flare out.
		for i, sp in self.Spirals do
			local wind = 1 - 0.4 * smooth((t - 0.2) / (E.ReleaseAt - 0.2))
			local flare = if released then 1 + 0.9 * easeOut(after / 0.3) else 1
			local k = E.LanternScale * wind * flare * hush * math.min(1, t / 0.25)
			sp.Part.CFrame = lantern
				* CFrame.Angles(0, (if i % 2 == 0 then -1 else 1) * t * (2 + 6 * eclipse), 0)
				* CFrame.new(sp.Offset.Position * k)
				* sp.Offset.Rotation
			sp.Part.Size = sp.Size * k
			sp.Part.Transparency = if released then smooth(after / 0.3) else 0.1 + 0.9 * (1 - math.min(1, t / 0.25))
		end

		-- Moon: arcs in from the side during the gather, slides across the lantern, then drifts up and dissolves.
		local enterAt = E.GatherAt + 0.1
		local enter = easeOut((t - enterAt) / (E.EclipseAt - enterAt))
		local side = E.MoonStartOffset + (E.MoonGatherOffset - E.MoonStartOffset) * enter
		side *= 1 - eclipse
		local lift = (1 - enter) * 3 + (if released then E.MoonRise * smooth(after / 1.2) else 0)
		local moonAt = lantern
			* CFrame.new(side, lift, E.MoonTowardCamera)
			* CFrame.Angles(0, 0, (1 - enter) * 0.9 - eclipse * 0.25 + after * 0.4)
		local moonFade = if released then smooth((after - 0.35) / 0.8) else 1 - clamp01((t - enterAt) / 0.15)
		for _, m in self.Moon do
			m.Part.CFrame = moonAt * m.Offset
			m.Part.Size = m.Size * E.MoonScale * hush
			m.Part.Transparency = m.Alpha + (1 - m.Alpha) * moonFade
			if m.Rim then
				m.Part.Material = if released and after < 0.4 then Enum.Material.Neon else Enum.Material.SmoothPlastic
			end
		end

		-- Moon shadow sweeps the floor the same way the moon travels, darkest under the lantern.
		if #self.Shadow > 0 then
			local sweep = clamp01((t - (E.EclipseAt - 0.1)) / (E.HushAt + 0.1 - (E.EclipseAt - 0.1)))
			local presence = math.sin(sweep * math.pi)
			local x = E.ShadowTravel * 0.5 * (1 - 2 * smooth(sweep))
			local centre = basis.Position + basis.RightVector * x
			for _, d in self.Shadow do
				d.Part.CFrame = CFrame.new(centre.X, self.ShadowY, centre.Z) * CFrame.Angles(0, 0, math.pi / 2)
				d.Part.Transparency = if sweep <= 0 or sweep >= 1 or released then 1 else 1 - (1 - d.Alpha) * presence
			end
		end

		-- Screen grade: cool moonlight in, a warm flash on release, then back to normal.
		if self.Grade then
			local G = E.Grade
			local dark = smooth((t - (E.EclipseAt - 0.2)) / G.InSeconds)
			if released then
				dark *= 1 - smooth((after - 0.05) / G.OutSeconds)
			end
			local burst = if released then math.max(0, 1 - after / G.FlashSeconds) else 0
			local cool = dark * (1 - burst)
			self.Grade.TintColor =
				Color3.new(1, 1, 1):Lerp(Color3.fromHex(G.Tint), cool):Lerp(Color3.fromHex(G.FlashTint), burst)
			self.Grade.Brightness = G.Brightness * cool + G.FlashBrightness * burst
			self.Grade.Contrast = G.Contrast * dark
			self.Grade.Saturation = G.Saturation * cool + 0.15 * burst
		end

		-- Beams bind the lantern to each singer during the eclipse.
		for i, beam in self.Beams do
			local g = self.Ghosts[i]
			beam.Enabled = not lowDetail and g ~= nil and t >= E.EclipseAt - 0.2 and not released
			if beam.Enabled then
				beam.Attachment0.WorldPosition = lantern.Position
				beam.Attachment1.WorldPosition = g.Head.Position
			end
		end

		-- Light: the glow core burns through the gather, dims in the hush, then the release pops it.
		local flashT = after / E.FlashSeconds
		flash.CFrame = lantern
		flash.Size = Vector3.one * (if released then 0.5 + E.FlashSize * easeOut(flashT) else 0.1)
		flash.Transparency = if released and flashT < 1 then 0.35 + 0.65 * math.sqrt(flashT) else 1
		if self.Light then
			self.Light.Brightness = if released
				then E.LightBrightness * math.max(0, 1 - after / 0.5)
				else E.CoreLight * math.min(1, t / 0.2) * (0.6 + 0.4 * gather) * (if t >= E.HushAt then 0.5 else 1)
		end
		local shock = easeOut(after / E.ShockSeconds)
		self.Shock.CFrame = basis * CFrame.new(0, 0.2, 0)
		self.Shock.Size = self.ShockSize * (0.5 + E.ShockRadius * shock)
		self.Shock.Transparency = if released then shock else 1
		local ringT = easeOut(after / (E.ShockSeconds * 0.8))
		self.Ring.CFrame = lantern
		self.Ring.Size = self.RingSize * (1 + E.ShockRadius * 0.6 * ringT)
		self.Ring.Transparency = if released then ringT else 1
		for _, sh in self.Shards do
			if not released then
				sh.Part.Transparency = 1
				continue
			end
			local position = lantern.Position
				+ sh.Offset
				+ sh.Velocity * after
				- Vector3.yAxis * 0.5 * E.ShardGravity * after * after
			sh.Part.CFrame = CFrame.new(position)
				* CFrame.Angles(sh.Spin.X * after, sh.Spin.Y * after, sh.Spin.Z * after)
				* sh.Rotation
			local rest = sh.Part:GetAttribute("RestTransparency")
			sh.Part.Transparency = rest + (1 - rest) * smooth((disperse - 0.5) / 0.5)
		end
		for _, star in self.Stars do
			local fly = easeOut(after / 0.7)
			star.Part.CFrame = CFrame.new(lantern.Position + star.Direction * E.StarSpeed * fly * 0.5)
				* basis.Rotation
				* CFrame.Angles(0, 0, after * 6)
			star.Part.Size = star.Size * (1 - fly * 0.6)
			star.Part.Transparency = if released then fly else 1
		end
		if self.Glint then
			local k = (t - E.GlintAt) / 0.32
			self.Glint.Part.CFrame = lanternAt * CFrame.Angles(0, 0, t * 3)
			self.Glint.Part.Size = self.Glint.Size * math.max(0.01, pop(k * 2) * (1 - smooth((k - 0.4) / 0.6)))
			self.Glint.Part.Transparency = if k > 0 and k < 1 then 0.05 + 0.95 * smooth((k - 0.5) / 0.5) else 1
		end
		if self.Swirl then
			self.Swirl.Enabled = t >= E.GatherAt and t < E.HushAt
		end

		for _, entry in self.Emitters do
			if not entry.Fired and t >= entry.At then
				entry.Fired = true
				local count = entry.Emitter:GetAttribute("BurstCount") or 4
				entry.Emitter:Emit(math.max(1, math.floor(count / (if lowDetail then divisor else 1))))
			end
		end
	end

	root.Destroying:Once(function()
		state.Stopped = true
		if state.Connection then
			state.Connection:Disconnect()
		end
		if state.Grade then
			state.Grade:Destroy()
		end
	end)
	root.Parent = parent
	state:Step(0)
	return state
end

function FX.emit(parent, origin, lowDetail, orientation)
	local state = FX.create(parent, origin, lowDetail, orientation)
	if not state then
		return nil
	end
	local start = os.clock()
	state.Connection = RunService.Heartbeat:Connect(function()
		state:Step(os.clock() - start)
	end)
	return state.Root
end

return FX
