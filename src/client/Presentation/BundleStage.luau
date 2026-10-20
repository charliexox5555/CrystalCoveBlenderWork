-- 3D stage for the bundle preview screen (UI/Screens/BundlePreview). Client-only and cosmetic: built in
-- the world high above the lobby (Config/BundlePreview.StageOrigin) because particles, beams, trails and
-- lights do not render in ViewportFrames. A dark round room with a pedestal; a copy of the player's avatar
-- rides the Moonlantern Carriage (lantern_carriage pose, RideMotion parts and RideEmitter effects), the
-- Hollowlight swings on a lantern post, then flies into the Lantern Eclipse on a loop with its sound cues.
-- Destroy() removes every instance, connection and sound it made.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config.BundlePreview)
local D = require(RS.Shared.Config.Showcase).Demo
local T = require(RS.Shared.Config.Balance).CosmeticPresentation
local Cosmetics = require(RS.Shared.Config.RoundCosmetics)
local RidePose = require(script.Parent.RidePose)
local CarriageFX = require(script.Parent.CarriageFX)
local FinisherFX = require(script.Parent.FinisherFX)
local FinisherAudio = require(script.Parent.FinisherAudio)
local Stage = {}
Stage.__index = Stage

local TAU = math.pi * 2
local CYCLE = D.IdleSeconds + D.RiseSeconds + D.FlySeconds + D.AfterSeconds
local random = Random.new()
local hex = Color3.fromHex

local function isEffect(obj)
	return obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Light")
end

local function still(model)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		end
	end
	return model
end

local function lowQuality()
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	return (ok and level > 0 and level <= 3) or require(script.Parent.Parent.LocalSettings).lowEffects()
end

local function ease(x)
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) ^ 3
end

local function bezier(a, b, c, t)
	return a:Lerp(b, t):Lerp(b:Lerp(c, t), t)
end

local function part(parent, name, props)
	local p = Instance.new("Part")
	p.Name, p.TopSurface, p.BottomSurface = name, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		p[key] = value
	end
	p.Parent = parent
	return p
end

local function rideSource(id)
	local def = Cosmetics.ByCategory.Rideables[id]
	if def and def.AssetBundle then
		local seasonal = RS.Assets:FindFirstChild("Seasonal")
		local bundle = seasonal and seasonal:FindFirstChild(def.AssetBundle)
		return bundle and bundle:FindFirstChild(def.AssetName)
	end
	return RS.Assets.Rideables:FindFirstChild(id)
end

-- A local copy of the player's character with scripts, sounds and tools stripped; the root is anchored
-- so the RidePose joints drive the rest. Nil when the avatar has not loaded.
local function copyAvatar()
	local character = Players.LocalPlayer.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return nil
	end
	local archivable = character.Archivable
	character.Archivable = true
	local ok, copy = pcall(character.Clone, character)
	character.Archivable = archivable
	if not ok or not copy then
		return nil
	end
	for _, obj in copy:GetDescendants() do
		if obj:IsA("LuaSourceContainer") or obj:IsA("Sound") or obj:IsA("Tool") or obj:IsA("ForceField") then
			obj:Destroy()
		elseif obj:IsA("BasePart") then
			obj.Anchored, obj.CanCollide, obj.CanTouch, obj.CanQuery, obj.Massless = false, false, false, false, true
		end
	end
	local human = copy:FindFirstChildOfClass("Humanoid")
	if not human then
		copy:Destroy()
		return nil
	end
	human.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	human.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	human.BreakJointsOnDeath, human.EvaluateStateMachine = false, false
	copy.HumanoidRootPart.Anchored = true
	copy.Name = "PreviewAvatar"
	return copy
end

-- ── Room, pedestal and post ─────────────────────────────────────────────────────────────────────
function Stage:BuildRoom()
	local o, room, ped = self.Origin, Config.Room, Config.Pedestal
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "Room", self.Root
	part(folder, "Floor", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, room.Radius * 2 + 4, room.Radius * 2 + 4),
		CFrame = o * CFrame.new(0, -0.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = hex("#1A1428"),
	})
	local arc = TAU / room.Panels
	local width = 2 * room.Radius * math.tan(arc / 2) + 1
	for i = 1, room.Panels do
		local angle = i * arc
		part(folder, "Wall", {
			Size = Vector3.new(width, room.Height, 1),
			CFrame = o * CFrame.Angles(0, angle, 0) * CFrame.new(0, room.Height / 2 - 1, -room.Radius),
			Color = if i % 2 == 0 then hex("#1F1830") else hex("#231B36"),
		})
	end
	part(folder, "Ceiling", {
		Size = Vector3.new(room.Radius * 2 + 4, 1, room.Radius * 2 + 4),
		CFrame = o * CFrame.new(0, room.Height - 0.5, 0),
		Color = hex("#140F20"),
	})
	-- Pinpoint "stars" on the walls in the palette's jewel colours.
	local colours = { hex("#CDAAFF"), hex("#9BF3F8"), hex("#FFD98A"), hex("#86EDB8") }
	for i = 1, room.Stars do
		local angle = random:NextNumber(0, TAU)
		local y = random:NextNumber(4, room.Height * 0.7)
		part(folder, "Star", {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * random:NextNumber(0.25, 0.6),
			CFrame = o * CFrame.Angles(0, angle, 0) * CFrame.new(0, y, -(room.Radius - 0.7)),
			Color = colours[i % #colours + 1],
			Material = Enum.Material.Neon,
			Transparency = random:NextNumber(0, 0.4),
		})
	end
	-- Pedestal: dark slate drum, amethyst neon rim and an amber glass top inlay.
	part(folder, "Pedestal", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(ped.Height, ped.Radius * 2, ped.Radius * 2),
		CFrame = o * CFrame.new(0, ped.Height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = hex("#2B2245"),
		Material = Enum.Material.Slate,
	})
	part(folder, "PedestalRim", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.25, ped.Radius * 2 + 0.5, ped.Radius * 2 + 0.5),
		CFrame = o * CFrame.new(0, ped.Height - 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = hex("#8B4FE0"),
		Material = Enum.Material.Neon,
	})
	part(folder, "PedestalInlay", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, (ped.Radius - ped.RimInset) * 2, (ped.Radius - ped.RimInset) * 2),
		CFrame = o * CFrame.new(0, ped.Height + 0.03, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = hex("#3A2E60"),
	})
	-- Lantern post the Hollowlight hangs from.
	local g = Config.Glassy
	local top = g.Hook.Y + 0.7
	part(folder, "Post", {
		Size = Vector3.new(0.45, top, 0.45),
		CFrame = o * CFrame.new(g.Post.X, top / 2, g.Post.Z),
		Color = hex("#1F1830"),
		Material = Enum.Material.Metal,
	})
	local armStart, armEnd = Vector3.new(g.Post.X, top, g.Post.Z), Vector3.new(g.Hook.X, top, g.Hook.Z)
	part(folder, "Arm", {
		Size = Vector3.new(0.3, 0.3, (armEnd - armStart).Magnitude + 0.3),
		CFrame = o * CFrame.lookAt((armStart + armEnd) / 2, armEnd),
		Color = hex("#1F1830"),
		Material = Enum.Material.Metal,
	})
	part(folder, "Hook", {
		Size = Vector3.new(0.14, top - g.Hook.Y, 0.14),
		CFrame = o * CFrame.new(g.Hook.X, (top + g.Hook.Y) / 2, g.Hook.Z),
		Color = hex("#332854"),
		Material = Enum.Material.Metal,
	})
	part(folder, "PostCap", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.8,
		CFrame = o * CFrame.new(g.Post.X, top + 0.3, g.Post.Z),
		Color = hex("#FFAA55"),
		Material = Enum.Material.Neon,
	})
	-- Stage lights: warm key from the front, violet rim from behind, mint glow at the eclipse spot.
	local function light(name, position, colour, brightness, range)
		local holder =
			part(folder, name, { Size = Vector3.one * 0.2, Transparency = 1, CFrame = o * CFrame.new(position) })
		local l = Instance.new("PointLight")
		l.Color, l.Brightness, l.Range, l.Shadows = colour, brightness, range, false
		l.Parent = holder
	end
	light("KeyLight", Vector3.new(4, 16, 18), hex("#FFE2B8"), 1.3, 40)
	light("RimLight", Vector3.new(-3, 12, -14), hex("#B07CFF"), 2.5, 34)
	light("FillLight", Vector3.new(-12, 6, 10), hex("#7FE8D0"), 1, 24)
end

-- ── Carriage and rider (motion mirrors RideController / ShowcaseController) ─────────────────────
function Stage:BuildRide(id)
	local source = rideSource(id)
	if not source then
		return
	end
	local model = still(source:Clone())
	model.Name = "PreviewRide"
	local base = self:RideBase(0)
	model:PivotTo(base)
	local ride = { Model = model, Parts = {}, Effects = {}, Lights = {} }
	for _, obj in model:GetDescendants() do
		if obj:IsA("BasePart") and obj:GetAttribute("RideMotion") then
			ride.Parts[obj] =
				{ Pose = base:ToObjectSpace(obj.CFrame), Size = obj.Size, Transparency = obj.Transparency }
		elseif obj:GetAttribute("RideEmitter") and isEffect(obj) then
			obj.Enabled = true
			if obj:IsA("Light") then
				ride.Lights[obj] = obj:GetAttribute("BaseBrightness") or obj.Brightness
			end
		end
	end
	model.Parent = self.Root
	-- Carriage extras: take-off, wing-tip flex, lantern flame, glows and the ride loop (workstream I).
	ride.FX = CarriageFX.attach(model, { Effects = self.Root })
	local avatar = copyAvatar()
	if avatar then
		avatar.Parent = self.Root
		ride.Npc = avatar
		ride.Pose = RidePose.new(avatar, model:GetAttribute("PoseId") or id)
	end
	self.Ride = ride
end

function Stage:RideBase(time)
	local c = Config.Carriage
	local yaw = c.Yaw + math.sin(time * c.YawHz * TAU) * c.YawSway
	return self.Origin * CFrame.new(Vector3.new(0, Config.Pedestal.Height, 0) + c.Offset) * CFrame.Angles(0, yaw, 0)
end

function Stage:StepRide(time)
	local ride = self.Ride
	if not ride then
		return
	end
	local base = self:RideBase(time)
	local phase = time * T.RideBobHz * TAU
	local wave = math.sin(phase)
	local pose = base
		* CFrame.new(0, wave * T.RideBob, 0)
		* CFrame.Angles(math.cos(phase) * T.RideNod, 0, wave * T.RideBank)
	if ride.FX then
		pose *= ride.FX:Offset(time)
	end
	for light, brightness in ride.Lights do
		light.Brightness = brightness
			* (1 - (T.RideLightFlicker or 0) * (0.5 + 0.5 * math.noise(time * 6, light.Range)))
	end
	ride.Model:PivotTo(pose)
	if ride.Pose and ride.Npc.Parent then
		local rootPose = pose * CFrame.new(0, ride.Pose.Height or 0, 0)
		ride.Npc:PivotTo(rootPose)
		ride.Pose:PlaceAnchored(rootPose)
	end
	for p, rest in ride.Parts do
		local kind = p:GetAttribute("RideMotion")
		if kind == "Wing" then
			local pivot = p:GetAttribute("WingPivot") or Vector3.zero
			local flap = wave + T.RideFlapSharpness * 0.35 * math.sin(phase * 2)
			p.CFrame = pose
				* rest.Pose
				* CFrame.new(pivot)
				* CFrame.Angles(0, 0, flap * T.RideWingAngle * (p:GetAttribute("WingSide") or 1))
				* CFrame.new(-pivot)
		elseif kind == "Swing" then
			local pivot = p:GetAttribute("SwingPivot") or Vector3.zero
			local swing = math.sin(phase - T.RideSwingLag) * T.RideSwingAngle
			p.CFrame = pose * rest.Pose * CFrame.new(pivot) * CFrame.Angles(swing, 0, -swing * 0.5) * CFrame.new(-pivot)
		elseif kind == "Spin" then
			p.CFrame = pose * rest.Pose * CFrame.Angles(0, 0, time * (T.RideSpinSpeed or 1.2))
		elseif kind == "Pulse" then
			local breathe = math.sin(time * (T.RidePulseHz or 0.9) * TAU)
			p.Size = rest.Size * (1 + (T.RidePulseScale or 0.08) * breathe)
			p.Transparency = rest.Transparency + (T.RidePulseFade or 0.25) * (0.5 + 0.5 * breathe)
		else
			p.Size = rest.Size * Vector3.new(1, 1, 0.8 + math.sin(time * T.RideExhaustSpeed) * 0.2)
		end
	end
	if ride.FX then
		ride.FX:Step(time, phase, self.Sound)
	end
end

-- ── Hollowlight on its post and the Lantern Eclipse loop ────────────────────────────────────────
function Stage:BuildDemo(glassyId)
	local source = RS.Assets.Glassies:FindFirstChild(glassyId)
	if not source then
		return
	end
	local o, g = self.Origin, Config.Glassy
	local glassy = still(source:Clone())
	glassy.Name = "PreviewGlassy"
	glassy:ScaleTo(D.GlassyScale)
	local hook = o * CFrame.new(g.Hook)
	local hang = hook * CFrame.new(0, -D.StringLength, 0)
	glassy:PivotTo(hang)
	-- Living glassies: v3/v4 imports idle their Details (no-op otherwise); stops when the copy is destroyed.
	local GlassyMotion = require(script.Parent.GlassyMotion)
	if GlassyMotion.enabled(source) then
		GlassyMotion.autoplay(glassy, glassyId, { Scale = D.GlassyScale })
	end
	local body = glassy:FindFirstChild("Body")
	if not body then
		glassy:Destroy()
		return
	end
	local demo = {
		Model = glassy,
		Body = body,
		Hook = hook,
		Hang = hang,
		Arc = (o * CFrame.new(g.Arc)).Position,
		Target = (o * CFrame.new(g.Target)).Position,
		Visible = {},
		Shards = {},
		Start = os.clock(),
	}
	demo.PivotFromBody = body.CFrame:ToObjectSpace(glassy:GetPivot())
	for _, p in glassy:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Parent.Name == "Shards" then
				table.insert(
					demo.Shards,
					{ Part = p, Alpha = p.Transparency, Rest = glassy:GetPivot():ToObjectSpace(p.CFrame) }
				)
				p.Transparency = 1
			else
				table.insert(demo.Visible, { Part = p, Alpha = p.Transparency })
			end
		end
	end
	local hookPart = part(self.Root, "HookPoint", { Size = Vector3.one * 0.2, Transparency = 1, CFrame = hook })
	local a0 = Instance.new("Attachment")
	a0.Parent = hookPart
	local a1 = Instance.new("Attachment")
	a1.CFrame, a1.Parent = demo.PivotFromBody, body
	local cord = Instance.new("Beam")
	cord.Name, cord.Attachment0, cord.Attachment1 = "String", a0, a1
	cord.Width0, cord.Width1, cord.FaceCamera, cord.Segments = 0.07, 0.07, true, 1
	cord.Color, cord.LightInfluence = ColorSequence.new(hex("#CDAAFF")), 1
	cord.Parent = hookPart
	demo.String = cord
	local t0, t1 = Instance.new("Attachment"), Instance.new("Attachment")
	t0.Position, t1.Position = Vector3.new(0, 0.5, 0), Vector3.new(0, -0.5, 0)
	t0.Parent, t1.Parent = body, body
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1, trail.Enabled = t0, t1, false
	trail.Lifetime, trail.LightEmission, trail.FaceCamera = 0.25, 1, true
	trail.Color = ColorSequence.new(hex("#FFAA55"), hex("#63EFBC"))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = body
	demo.Trail = trail
	glassy.Parent = self.Root
	self.Demo = demo
end

function Stage:ResetDemo()
	local demo = self.Demo
	if demo.Owner then
		demo.Owner:Destroy() -- also cancels pending and playing finisher sounds
	end
	demo.Owner = Instance.new("Folder")
	demo.Owner.Name, demo.Owner.Parent = "EclipseCycle", self.Root
	demo.Impacted, demo.ShardStart, demo.Phase = false, nil, nil
	demo.Trail.Enabled = false
	demo.Model:PivotTo(demo.Hang)
	local pivot = demo.Model:GetPivot()
	for _, shard in demo.Shards do
		shard.Part.CFrame, shard.Part.Transparency = pivot * shard.Rest, 1
	end
end

-- 2D cues (FinisherAudio preview volume) so the eclipse is heard wherever the camera orbits.
function Stage:Cue(phase)
	local demo = self.Demo
	if demo.Phase ~= phase and self.Sound then
		FinisherAudio.phase(demo.Owner, self.Finisher, phase, nil)
	end
	demo.Phase = phase
end

function Stage:Impact()
	local demo = self.Demo
	demo.Impacted = true
	demo.Trail.Enabled = false
	local center = demo.Body.Position
	for _, entry in demo.Visible do
		entry.Part.Transparency = 1
	end
	for _, shard in demo.Shards do
		local out = shard.Part.Position - center
		out = if out.Magnitude > 0.01 then out.Unit else Vector3.yAxis
		shard.Start, shard.Part.Transparency = shard.Part.CFrame, shard.Alpha
		shard.Velocity = (out + Vector3.new(0, 0.6, 0)) * D.ShardSpeed * random:NextNumber(0.6, 1.1)
		shard.Spin = Vector3.new(random:NextNumber(-8, 8), random:NextNumber(-8, 8), random:NextNumber(-8, 8))
	end
	demo.ShardStart = os.clock()
	FinisherFX.emit(demo.Owner, self.Finisher, demo.Target, lowQuality())
	self:Cue("Burst")
end

function Stage:StepDemo(now)
	local demo = self.Demo
	if not demo then
		return
	end
	local elapsed = now - demo.Start
	local index = math.floor(elapsed / CYCLE)
	local t = elapsed - index * CYCLE
	if index ~= demo.Cycle then
		demo.Cycle = index
		self:ResetDemo()
	end
	local flyEnd = D.IdleSeconds + D.RiseSeconds + D.FlySeconds
	if t < D.IdleSeconds then
		local sway = math.sin(now * D.SwayHz * TAU) * D.SwayAngle
		demo.Model:PivotTo(demo.Hook * CFrame.Angles(sway, 0, sway * 0.5) * CFrame.new(0, -D.StringLength, 0))
		local fade = math.clamp(t / D.RespawnSeconds, 0, 1)
		for _, entry in demo.Visible do
			entry.Part.Transparency = entry.Alpha + (1 - entry.Alpha) * (1 - fade)
		end
		demo.String.Enabled = true
	elseif t < flyEnd then
		demo.String.Enabled = false
		local rest = demo.Hang * demo.PivotFromBody:Inverse()
		local lifted = rest.Position + Vector3.yAxis * D.RiseHeight
		local bodyCFrame
		if t < D.IdleSeconds + D.RiseSeconds then
			self:Cue("Rise")
			local rise = ease((t - D.IdleSeconds) / D.RiseSeconds)
			bodyCFrame = CFrame.new(rest.Position:Lerp(lifted, rise)) * rest.Rotation * CFrame.Angles(0, rise * 2, 0)
		else
			self:Cue("Fly")
			demo.Trail.Enabled = true
			local fly = (t - D.IdleSeconds - D.RiseSeconds) / D.FlySeconds
			local f = fly * fly
			bodyCFrame = CFrame.new(bezier(lifted, demo.Arc, demo.Target, f))
				* rest.Rotation
				* CFrame.Angles(f * D.FlySpin * 0.4, 2 + f * D.FlySpin, 0)
		end
		demo.Model:PivotTo(bodyCFrame * demo.PivotFromBody)
	elseif not demo.Impacted then
		self:Impact()
	end
	if demo.ShardStart then
		local k = now - demo.ShardStart
		local fade = math.clamp((k / D.ShardSeconds - 0.6) / 0.4, 0, 1)
		for _, shard in demo.Shards do
			if k >= D.ShardSeconds then
				shard.Part.Transparency = 1
			else
				local position = shard.Start.Position
					+ shard.Velocity * k
					- Vector3.yAxis * (0.5 * D.ShardGravity * k * k)
				shard.Part.CFrame = CFrame.new(position)
					* shard.Start.Rotation
					* CFrame.Angles(shard.Spin.X * k, shard.Spin.Y * k, shard.Spin.Z * k)
				shard.Part.Transparency = shard.Alpha + (1 - shard.Alpha) * fade
			end
		end
		if k >= D.ShardSeconds then
			demo.ShardStart = nil
		end
	end
end

-- Restart the loop so the eclipse fires `lead` seconds before the glassy rises.
function Stage:ReplayEclipse(lead)
	local demo = self.Demo
	if not demo then
		return
	end
	local elapsed = os.clock() - demo.Start
	local t = elapsed % CYCLE
	-- Already flying or bursting: let this one finish.
	if t >= D.IdleSeconds - lead and t < CYCLE - 0.4 then
		return
	end
	demo.Start = os.clock() - (D.IdleSeconds - lead)
	demo.Cycle = nil
end

-- ── Public ──────────────────────────────────────────────────────────────────────────────────────
-- items: { Glassy = id, Flyer = id, Finisher = id } (any may be nil).
function Stage.new(items)
	local self = setmetatable({}, Stage)
	self.Origin = CFrame.new(Config.StageOrigin)
	self.Finisher = items.Finisher
	self.Sound = true
	self.Root = Instance.new("Folder")
	self.Root.Name = "BundlePreviewStage"
	self.Root:SetAttribute("CosmeticOnly", true)
	self.Clock = os.clock()
	self:BuildRoom()
	self.Root.Parent = workspace
	if items.Flyer then
		self:BuildRide(items.Flyer)
	end
	if items.Glassy then
		self:BuildDemo(items.Glassy)
	end
	self:StepRide(0)
	self:MeasureFocus()
	return self
end

-- World-space box around several models: centre and half-diagonal.
local function bounds(models)
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, model in models do
		local cf, size = model:GetBoundingBox()
		for _, x in { -0.5, 0.5 } do
			for _, y in { -0.5, 0.5 } do
				for _, z in { -0.5, 0.5 } do
					local corner = cf:PointToWorldSpace(size * Vector3.new(x, y, z))
					low, high = low:Min(corner), high:Max(corner)
				end
			end
		end
	end
	if low.X == math.huge then
		return nil
	end
	return { Center = (low + high) / 2, Radius = (high - low).Magnitude / 2 }
end

-- Orbit pivots, measured once at rest so the bob and sway never move them: the rider + carriage for the
-- whole bundle and the flyer, the hanging glassy, and the eclipse area.
function Stage:MeasureFocus()
	local focus = {}
	local ride = self.Ride
	if ride then
		focus.Rideables = bounds(if ride.Npc then { ride.Model, ride.Npc } else { ride.Model })
	end
	if self.Demo then
		focus.Glassies = bounds({ self.Demo.Model })
		local f = Config.FinisherArea
		focus.Finishers =
			{ Center = (self.Origin * CFrame.new(Config.Glassy.Target + f.Offset)).Position, Radius = f.Radius }
	end
	focus.Overview = focus.Rideables or focus.Glassies or focus.Finishers
	self.FocusBounds = focus
end

-- { Center, Radius } for a focus kind, or nil.
function Stage:Focus(kind)
	return self.FocusBounds and (self.FocusBounds[kind] or self.FocusBounds.Overview)
end

-- Stage-space point -> world.
function Stage:World(point)
	return (self.Origin * CFrame.new(point)).Position
end

function Stage:Step()
	if not self.Root then
		return
	end
	local now = os.clock()
	self:StepRide(now - self.Clock)
	if self.Demo and self.Finisher then
		self:StepDemo(now)
	end
end

function Stage:SetSound(on)
	self.Sound = on
end

function Stage:Destroy()
	if not self.Root then
		return
	end
	if self.Ride and self.Ride.Pose then
		self.Ride.Pose:Destroy()
	end
	if self.Ride and self.Ride.FX then
		self.Ride.FX:Destroy()
	end
	self.Root:Destroy() -- owners inside go with it, which stops the finisher sounds
	self.Root, self.Ride, self.Demo = nil, nil, nil
end

return Stage
