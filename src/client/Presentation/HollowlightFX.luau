-- Lantern Eclipse finisher: original Blender actors + native particles, client-only and cosmetic.
-- Beats (Balance.CosmeticPresentation.Eclipse): gather -> eclipse -> hush -> release -> dispersal.
-- The lantern hangs above the recipient so they stay readable; no damage, avatar hiding or physics.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local E = require(RS.Shared.Config.Balance).CosmeticPresentation.Eclipse
local FX = {}

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

	-- Lantern core: the five Core_* parts, kept relative to the amber body.
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

	-- Ghost groups: head + face + tail around each head.
	for i = 0, 2 do
		if lowDetail and i > 0 then
			break
		end
		local head = art["Wisp" .. i]
		local group = { Parts = {}, Phase = i * math.pi * 2 / 3 }
		for _, name in { "Wisp", "WispFace", "WispTail" } do
			local p = art[name .. i]
			local copy = actor(root, p)
			table.insert(group.Parts, {
				Part = copy,
				Offset = head.CFrame:ToObjectSpace(p.CFrame),
				Size = p.Size,
				Alpha = p.Transparency,
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

	-- Release actors.
	local flash = still(Instance.new("Part"))
	flash.Name, flash.Shape, flash.Material = "EclipseFlash", Enum.PartType.Ball, Enum.Material.Neon
	flash.Color, flash.Transparency, flash.Size = Color3.new(1, 1, 1), 1, Vector3.one * 0.1
	flash.CFrame, flash.Parent = lanternAt, root
	state.Flash = flash
	if not lowDetail then
		local light = Instance.new("PointLight")
		light.Range, light.Brightness, light.Color = E.LightRange, 0, Color3.fromHex(E.LightColor)
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
	if hero and hero:FindFirstChild("NovaStar") and not lowDetail then
		for i = 1, E.Stars do
			local star = actor(root, hero.NovaStar, "EclipseStar")
			star.Material, star.Color, star.Transparency = Enum.Material.Neon, Color3.fromHex(E.RimColor), 1
			star.Size *= 0.7 / math.max(star.Size.X, star.Size.Y, star.Size.Z)
			local angle = i / E.Stars * math.pi * 2
			table.insert(state.Stars, {
				Part = star,
				Size = star.Size,
				Direction = basis:VectorToWorldSpace(Vector3.new(math.cos(angle), math.sin(angle), 0)),
			})
		end
	end

	-- Native particle kit at the lantern; emitters fire on beats, beams bind lantern to ghosts.
	local kit = source.HollowlightPrototype:Clone()
	kit.Origin.CFrame = lanternAt
	kit.Parent = root
	local linger, divisor = 0, kit:GetAttribute("ReducedParticleDivisor") or 2
	local beats = {
		ChargeWisps = { 0.05, E.ReleaseAt + 0.15 },
		LanternPressure = { E.ReleaseAt },
		AmberGlassGlints = { E.ReleaseAt },
		VioletDust = { E.ReleaseAt + 0.05 },
	}
	state.Beams = {}
	for _, obj in kit:GetDescendants() do
		if obj:IsA("ParticleEmitter") then
			obj.Enabled = false
			linger = math.max(linger, obj.Lifetime.Max)
			for _, at in beats[obj.Name] or { obj:GetAttribute("PhaseStart") or E.ReleaseAt } do
				table.insert(state.Emitters, { Emitter = obj, At = at })
			end
		elseif obj:IsA("Beam") then
			obj.Enabled = false
			table.insert(state.Beams, obj)
		end
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
		local eclipse = smooth((t - E.EclipseAt) / (E.HushAt - E.EclipseAt))
		local hush = if t >= E.HushAt and not released
			then 1 - 0.1 * smooth((t - E.HushAt) / (E.ReleaseAt - E.HushAt))
			else 1

		-- Lantern: pop in with squash and stretch, dim and flicker under the moon, vanish on release.
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

		-- Ghosts: swoop in on a spiral, circle tight and tremble, then scatter upward and fade.
		for _, g in self.Ghosts do
			local gather = easeIn(t / E.EclipseAt)
			local radius = E.GhostStartRadius + (E.GhostOrbitRadius - E.GhostStartRadius) * gather
			radius += (E.GhostTightRadius - E.GhostOrbitRadius) * eclipse
			radius *= hush
			local height = E.GhostStartHeight * (1 - gather)
			local angle = g.Phase + t * E.GhostSpin * (0.4 + gather + eclipse)
			local fade = 0
			if released then
				radius += E.GhostScatter * easeOut(disperse)
				height += E.GhostRise * disperse * disperse
				fade = smooth((disperse - 0.45) / 0.55)
			end
			local tremble = if eclipse > 0 and not released
				then Vector3.new(math.noise(t * 20, g.Phase), math.noise(g.Phase, t * 20), 0) * E.GhostTremble
				else Vector3.zero
			local at = (lantern * CFrame.new(math.cos(angle) * radius, height - 0.6, math.sin(angle) * radius)).Position
				+ tremble
			local heading = basis.Rotation * CFrame.Angles(0, 0, math.sin(angle) * 0.3)
			local s = E.GhostScale * math.min(1, t / 0.12 + 0.01)
			for _, p in g.Parts do
				p.Part.CFrame = CFrame.new(at) * heading * CFrame.new(p.Offset.Position * s) * p.Offset.Rotation
				p.Part.Size = p.Size * s
				p.Part.Transparency = p.Alpha + (1 - p.Alpha) * fade
			end
			if g.Trail then
				g.Trail.Enabled = fade < 0.9
			end
		end

		-- Ground halo: spreads during the gather, pulses in the eclipse, rings out on release.
		local haloGrow = smooth(t / E.EclipseAt) * E.HaloScale
		local pulse = 1 + eclipse * 0.08 * math.sin(t * 30)
		local haloScale = if released
			then E.HaloScale + (E.HaloReleaseScale - E.HaloScale) * easeOut(after / 0.5)
			else haloGrow * pulse
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

		-- Moon: arcs in from the side, slides across the lantern, then drifts up and dissolves.
		local enter = easeOut((t - 0.12) / (E.EclipseAt - 0.12))
		local side = E.MoonStartOffset + (E.MoonGatherOffset - E.MoonStartOffset) * enter
		side *= 1 - eclipse
		local lift = (1 - enter) * 3 + (if released then E.MoonRise * smooth(after / 1.2) else 0)
		local moonAt = lantern
			* CFrame.new(side, lift, E.MoonTowardCamera)
			* CFrame.Angles(0, 0, (1 - enter) * 0.9 - eclipse * 0.25 + after * 0.4)
		local moonFade = if released then smooth((after - 0.35) / 0.8) else 1 - clamp01((t - 0.12) / 0.15)
		for _, m in self.Moon do
			m.Part.CFrame = moonAt * m.Offset
			m.Part.Size = m.Size * E.MoonScale * hush
			m.Part.Transparency = m.Alpha + (1 - m.Alpha) * moonFade
			if m.Rim then
				m.Part.Material = if released and after < 0.4 then Enum.Material.Neon else Enum.Material.SmoothPlastic
			end
		end

		-- Beams bind the lantern to each ghost during the eclipse.
		for i, beam in self.Beams do
			local g = self.Ghosts[i]
			beam.Enabled = not lowDetail and g ~= nil and t >= 0.35 and not released
			if beam.Enabled then
				beam.Attachment0.WorldPosition = lantern.Position
				beam.Attachment1.WorldPosition = g.Head.Position
			end
		end

		-- Release: flash, light, shockwaves, shards and stars.
		local flashT = after / E.FlashSeconds
		flash.Size = Vector3.one * (if released then 0.5 + E.FlashSize * easeOut(flashT) else 0.1)
		flash.Transparency = if released and flashT < 1 then 0.35 + 0.65 * math.sqrt(flashT) else 1
		if self.Light then
			self.Light.Brightness = if released then E.LightBrightness * math.max(0, 1 - after / 0.45) else eclipse
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
