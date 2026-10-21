-- Shared toolkit for the standard finisher shows (Presentation/FinisherFX). A rig owns every Instance of one show:
-- actors (anchored, non-colliding parts), particle emitters on invisible sockets, trails, beams, a light and the
-- Legendary colour grade. Rigs are built once and reused from FinisherFX's pool, so everything here is created
-- up front and only positioned/faded per frame. Client-only and cosmetic: nothing collides, damages or replicates.
local RS = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Shows = require(RS.Shared.Config.FinisherShows)
local Kit = {}

-- Easing --------------------------------------------------------------------------------------------------------
function Kit.clamp01(x)
	return math.clamp(x, 0, 1)
end
function Kit.smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
function Kit.easeIn(x)
	x = math.clamp(x, 0, 1)
	return x * x * x
end
function Kit.easeOut(x)
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) ^ 3
end
-- Back ease-out: 0 -> ~10% overshoot -> 1.
function Kit.pop(x)
	x = math.clamp(x, 0, 1)
	return 1 + 2.70158 * (x - 1) ^ 3 + 1.70158 * (x - 1) ^ 2
end
-- Damped spring settle from 1 toward 0 (squash/stretch recovery), t in seconds.
function Kit.spring(t, frequency, damping)
	if t <= 0 then
		return 1
	end
	return math.exp(-damping * t) * math.cos(frequency * t)
end
function Kit.lerp(a, b, t)
	return a + (b - a) * t
end
-- 0 before `from`, 1 after `to`, smooth between.
function Kit.window(t, from, to)
	return Kit.smooth((t - from) / math.max(1e-3, to - from))
end
function Kit.rainbow(i, count, saturation, value)
	return Color3.fromHSV((i / count) % 1, saturation or 0.45, value or 1)
end

-- Templates -----------------------------------------------------------------------------------------------------
local Fallback = {
	StarGlint = { Texture = "rbxassetid://118014953401567" },
	SoftGlow = { Texture = "rbxassetid://101019590487297", Flipbook = Enum.ParticleFlipbookLayout.Grid4x4 },
	Streak = { Texture = "rbxassetid://118014953401567" },
	Bubble = { Texture = "rbxassetid://118823344389220" },
	Confetti = { Texture = "rbxassetid://119749428254490" },
	Dust = { Texture = "rbxassetid://101019590487297", Flipbook = Enum.ParticleFlipbookLayout.Grid4x4 },
	Puff = { Texture = "rbxassetid://130955555778708", Flipbook = Enum.ParticleFlipbookLayout.Grid4x4 },
	Snow = { Texture = "rbxassetid://118014953401567" },
	Petal = { Texture = "rbxassetid://119749428254490" },
	Ember = { Texture = "rbxassetid://101019590487297", Flipbook = Enum.ParticleFlipbookLayout.Grid4x4 },
	Feather = { Texture = "rbxassetid://119749428254490" },
	Heart = { Texture = "rbxassetid://118014953401567" },
	Hex = { Texture = "rbxassetid://118014953401567" },
}
local Flipbooks = { Confetti = Enum.ParticleFlipbookLayout.Grid4x4 }

-- Uploaded textures are preloaded once; one that fails to load (still processing, moderated) switches every
-- emitter using it back to its combat-bank fallback, so particles never turn invisible.
local failed = {}
local users = {} -- key -> weak set of emitters using the uploaded texture
local function useFallback(e, key)
	local fallback = Fallback[key] or Fallback.StarGlint
	e.Texture = fallback.Texture
	e.FlipbookLayout = fallback.Flipbook or Enum.ParticleFlipbookLayout.None
end
task.spawn(function()
	local byId = {}
	for key, id in Shows.Textures do
		if id then
			byId[id] = key
		end
	end
	-- ImageLabels, not bare id strings: a string preload reports Failure even for a good image (decision 111), which
	-- sent every show to its fallbacks. Waits for the loading screen so it doesn't compete with the Essential tier.
	local labels = {}
	for id in byId do
		local label = Instance.new("ImageLabel")
		label.Image = id
		table.insert(labels, label)
	end
	require(script.Parent.Parent.Parent.LoadGate).afterLoading()
	pcall(function()
		game:GetService("ContentProvider"):PreloadAsync(labels, function(id, status)
			local key = byId[id]
			if key and status ~= Enum.AssetFetchStatus.Success then
				failed[key] = true
				for e in users[key] or {} do
					if e.Parent then
						useFallback(e, key)
					end
				end
			end
		end)
	end)
end)

local function libraries()
	local vfx = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("VFX")
	if not vfx then
		return {}
	end
	local combat = vfx:FindFirstChild("Combat")
	return {
		vfx:FindFirstChild("FinishersV4"),
		vfx:FindFirstChild("FinishersV3"),
		vfx:FindFirstChild("RoundHeroV2"),
		combat and combat:FindFirstChild("Meshes"),
	}
end

-- First template found for `names` (a name or list of names) in FinishersV4, FinishersV3, RoundHeroV2, then
-- Combat.Meshes. Blender exports are prefixed FV3_/FV4_.
function Kit.template(names)
	if type(names) == "string" then
		names = { names }
	end
	local libs = libraries()
	for _, name in names do
		for i = 1, 4 do
			local lib = libs[i]
			local found = lib
				and (
					lib:FindFirstChild(name)
					or lib:FindFirstChild("FV3_" .. name)
					or lib:FindFirstChild("FV4_" .. name)
				)
			if found and found:IsA("BasePart") then
				return found
			end
		end
	end
	return nil
end

-- Rig -----------------------------------------------------------------------------------------------------------
local Rig = {}
Rig.__index = Rig

function Kit.rig(id, lowDetail, still)
	local root = Instance.new("Folder")
	root.Name = "Finisher_" .. id
	root:SetAttribute("CosmeticOnly", true)
	local self = setmetatable({
		Id = id,
		Low = lowDetail == true,
		Still = still == true,
		Root = root,
		Actors = {},
		Moving = {},
		Emitters = {},
		Trails = {},
		Beams = {},
		Schedule = {},
		Lights = {},
		Highlights = {},
		Steps = {},
		ResetHooks = {},
		ParticleScale = 1,
	}, Rig)
	self.Socket = self:SocketPart("Socket", Vector3.one * 0.2)
	return self
end

local function still(p)
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Locked = true
	return p
end

-- Invisible part that carries emitters (Emit happens at its current CFrame).
function Rig:SocketPart(name, size)
	local p = still(Instance.new("Part"))
	p.Name, p.Size, p.Transparency = name, size, 1
	p.Parent = self.Root
	return p
end

--[[ opts:
	Mesh       template name or list (Kit.template); falls back to a native part with Shape
	Shape      Enum.PartType for the native fallback (default Block)
	Size       studs along the template's longest axis (number) or an exact Vector3 for native parts
	Color, Material, Transparency (rest transparency), Reflectance
	Parent     optional container (e.g. a Model for a Highlight)
]]
function Rig:Actor(name, opts)
	local source = opts.Source or (opts.Mesh and Kit.template(opts.Mesh))
	local p = if source then source:Clone() else Instance.new("Part")
	still(p)
	p.Name = name
	if not source and p:IsA("Part") then
		p.Shape = opts.Shape or Enum.PartType.Block
	end
	local base
	if typeof(opts.Size) == "Vector3" then
		base = opts.Size
	else
		local raw = if source then source.Size else (opts.NativeSize or Vector3.one)
		base = raw / math.max(raw.X, raw.Y, raw.Z) * (opts.Size or 1)
	end
	p.Size = base
	local rest = opts.Transparency or 0
	if opts.Keep and source then
		-- Keep the template's own look (glassy heroes): colour, material, transparency. Drop anything that
		-- would run on its own (emitters, lights, scripts) so the show stays the only clock.
		rest = source.Transparency
		for _, d in p:GetDescendants() do
			if
				d:IsA("ParticleEmitter")
				or d:IsA("Trail")
				or d:IsA("Beam")
				or d:IsA("Light")
				or d:IsA("LuaSourceContainer")
			then
				d:Destroy()
			end
		end
	else
		p.Color = opts.Color or Color3.new(1, 1, 1)
		p.Material = opts.Material or Enum.Material.Neon
		p.Reflectance = opts.Reflectance or 0
	end
	p.Transparency = 1
	p.Parent = opts.Parent or self.Root
	-- Longest local axis, so Stretch() can lay elongated pieces along a direction whatever the template.
	local axis = if base.X >= base.Y and base.X >= base.Z then "X" elseif base.Y >= base.Z then "Y" else "Z"
	local actor = {
		Part = p,
		Base = base,
		Rest = rest,
		Axis = axis,
		Fallback = source == nil,
		Template = source and source.Name,
	}
	table.insert(self.Actors, actor)
	return actor
end

-- Positions an actor. scale: number or Vector3 multiplier on its base size; alpha: 0 = rest look, 1 = hidden.
function Rig:Place(actor, cf, scale, alpha)
	local p = actor.Part
	local s = if typeof(scale) == "Vector3" then scale else Vector3.one * (scale or 1)
	if alpha >= 0.999 or s.X <= 1e-3 or s.Y <= 1e-3 or s.Z <= 1e-3 then
		p.Transparency = 1
		return
	end
	table.insert(self.Moving, p)
	table.insert(self.MovingCF, cf)
	p.Size = actor.Base * s
	p.Transparency = actor.Rest + (1 - actor.Rest) * math.clamp(alpha, 0, 1)
end

function Rig:Hide(actor)
	actor.Part.Transparency = 1
end

-- CFrame that lays an actor's longest axis along `direction` (unit), centred at `center`, in the view plane.
function Rig:Along(actor, center, direction)
	local side = self.View.ZVector:Cross(direction)
	if side.Magnitude < 1e-3 then
		side = self.View.UpVector:Cross(direction)
	end
	side = side.Unit
	local normal = direction:Cross(side).Unit
	local cf
	if actor.Axis == "X" then
		cf = CFrame.fromMatrix(center, direction, side, normal)
	elseif actor.Axis == "Y" then
		cf = CFrame.fromMatrix(center, side, direction, -normal)
	else
		cf = CFrame.fromMatrix(center, side, normal, direction)
	end
	return cf
end

-- Lays an elongated actor along `direction` with its long axis `length` studs; `thickness` multiplies the
-- other two axes of its base size.
function Rig:Stretch(actor, center, direction, length, thickness, alpha)
	local axis = actor.Axis
	local stretch = math.max(0.01, length) / actor.Base[axis]
	local k = thickness or 1
	local scale = Vector3.new(
		if axis == "X" then stretch else k,
		if axis == "Y" then stretch else k,
		if axis == "Z" then stretch else k
	)
	self:Place(actor, self:Along(actor, center, direction), scale, alpha)
end

-- Places a flat ring/plate (thin along local Z) at `radius` studs without thickening it.
function Rig:Disc(actor, cf, radius, alpha, thickness)
	local k = radius / (math.max(actor.Base.X, actor.Base.Y) / 2)
	self:Place(actor, cf, Vector3.new(k, k, thickness or 1), alpha)
end

-- A hero built from an installed glassy (Assets.Glassies.<id>: Body + Details, no shards or hang chain), so
-- set items (Starmane's unicorn, Emberwing's phoenix, Hocus Pop's flask) match their glassy exactly.
-- `height` is the hero's size in studs along its tallest axis. Returns nil if the glassy isn't installed.
function Rig:GlassyHero(id, height)
	local glassies = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("Glassies")
	local model = glassies and glassies:FindFirstChild(id)
	local body = model and model:FindFirstChild("Body")
	if not body then
		return nil
	end
	local sources = { body }
	local details = model:FindFirstChild("Details")
	for _, d in details and details:GetDescendants() or {} do
		if d:IsA("BasePart") and not d.Name:match("^Hang") then
			table.insert(sources, d)
		end
	end
	local _, extent = model:GetBoundingBox()
	local scale = height / math.max(extent.X, extent.Y, extent.Z)
	local hero = { Parts = {}, Scale = scale, Group = self:Group("Hero_" .. id) }
	for _, src in sources do
		local actor = self:Actor(src.Name, { Source = src, Keep = true, Size = src.Size * scale, Parent = hero.Group })
		table.insert(hero.Parts, { Actor = actor, Name = src.Name, Offset = body.CFrame:ToObjectSpace(src.CFrame) })
	end
	return hero
end

-- Places a glassy hero. `pose` (optional) maps a part name pattern to an extra local rotation (wing flap, fold).
function Rig:PlaceHero(hero, cf, scale, alpha, pose)
	local k = hero.Scale * (scale or 1)
	for _, p in hero.Parts do
		local extra = CFrame.identity
		if pose then
			for pattern, rot in pose do
				if p.Name:match(pattern) then
					extra = rot
				end
			end
		end
		local local_ = CFrame.new(p.Offset.Position * k) * extra * p.Offset.Rotation
		self:Place(p.Actor, cf * local_, scale or 1, alpha)
	end
end

function Rig:HideHero(hero)
	for _, p in hero.Parts do
		p.Actor.Part.Transparency = 1
	end
end

-- World position from view-space offsets: x = screen right, y = up, z = toward the camera.
function Rig:At(x, y, z)
	return self.View:PointToWorldSpace(Vector3.new(x, y, z))
end

-- Emitters --------------------------------------------------------------------------------------------------------
local function numbers(spec)
	if typeof(spec) == "NumberSequence" then
		return spec
	end
	if type(spec) == "number" then
		return NumberSequence.new(spec)
	end
	local keys = {}
	for _, k in spec do
		table.insert(keys, NumberSequenceKeypoint.new(k[1], k[2], k[3] or 0))
	end
	return NumberSequence.new(keys)
end

local function colors(spec)
	if typeof(spec) == "ColorSequence" then
		return spec
	end
	if typeof(spec) == "Color3" then
		return ColorSequence.new(spec)
	end
	local keys = {}
	for i, c in spec do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #spec - 1), c))
	end
	return ColorSequence.new(keys)
end

--[[ spec: Texture (key in FinisherShows.Textures), Color (Color3 | {Color3} | ColorSequence), Size/Transparency
	(number | {{time, value, envelope}}), Lifetime {min, max}, Speed {min, max}, Spread (degrees), Acceleration,
	Drag, Rotation {min,max}, RotSpeed {min,max}, LightEmission, Brightness, Squash, Orientation, ZOffset,
	Direction (Enum.NormalId), Shape/ShapeStyle/ShapeInOut (with a sized socket), Socket (a part; default rig socket),
	Offset (attachment position on the socket).]]
function Rig:Emitter(name, spec)
	local socket = spec.Socket or self.Socket
	local attachment = socket:FindFirstChild(name .. "_At")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = name .. "_At"
		attachment.Position = spec.Offset or Vector3.zero
		attachment.Parent = socket
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Enabled, e.Rate = false, 0
	local key = spec.Texture or "StarGlint"
	local uploaded = if failed[key] then nil else Shows.Textures[key]
	local fallback = Fallback[key] or Fallback.StarGlint
	if uploaded then
		users[key] = users[key] or setmetatable({}, { __mode = "k" })
		users[key][e] = true
	end
	e.Texture = uploaded or fallback.Texture
	e.FlipbookLayout = if uploaded
		then (Flipbooks[key] or Enum.ParticleFlipbookLayout.None)
		else (fallback.Flipbook or Enum.ParticleFlipbookLayout.None)
	if e.FlipbookLayout ~= Enum.ParticleFlipbookLayout.None then
		e.FlipbookMode = spec.FlipbookMode or Enum.ParticleFlipbookMode.OneShot
		e.FlipbookStartRandom = spec.FlipbookStartRandom or false
	end
	e.Color = colors(spec.Color or Color3.new(1, 1, 1))
	e.Size = numbers(spec.Size or { { 0, 0.6 }, { 1, 0 } })
	e.Transparency = numbers(spec.Transparency or { { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } })
	local life = spec.Lifetime or { 0.4, 0.7 }
	e.Lifetime = NumberRange.new(life[1], life[2])
	local speed = spec.Speed or { 6, 12 }
	e.Speed = NumberRange.new(speed[1], speed[2])
	local spread = spec.Spread or 180
	e.SpreadAngle = Vector2.new(spread, spread)
	e.Acceleration = spec.Acceleration or Vector3.zero
	e.Drag = spec.Drag or 0
	local rot, rs = spec.Rotation or { 0, 360 }, spec.RotSpeed or { -120, 120 }
	e.Rotation, e.RotSpeed = NumberRange.new(rot[1], rot[2]), NumberRange.new(rs[1], rs[2])
	e.LightEmission = spec.LightEmission or 1
	e.LightInfluence = spec.LightInfluence or 0
	e.Brightness = spec.Brightness or 1
	e.Squash = numbers(spec.Squash or 0)
	e.Orientation = spec.Orientation or Enum.ParticleOrientation.FacingCamera
	e.ZOffset = spec.ZOffset or 0.5
	e.EmissionDirection = spec.Direction or Enum.NormalId.Top
	e.LockedToPart = false
	if spec.Shape then
		e.Shape, e.ShapeStyle = spec.Shape, spec.ShapeStyle or Enum.ParticleEmitterShapeStyle.Surface
		e.ShapeInOut = spec.ShapeInOut or Enum.ParticleEmitterShapeInOut.Outward
	end
	e.Parent = attachment
	self.Emitters[name] = e
	return e
end

-- Schedules a burst of `count` particles (scaled by detail) at show time `at`.
function Rig:Burst(at, name, count)
	table.insert(self.Schedule, {
		At = at,
		Run = function(rig)
			local e = rig.Emitters[name]
			if e then
				e:Emit(math.max(1, math.floor(count * rig.ParticleScale + 0.5)))
			end
		end,
	})
end

-- Schedules any callback at show time `at` (fired once per play, in order).
function Rig:On(at, callback)
	table.insert(self.Schedule, { At = at, Run = callback })
end

-- Trails, beams, lights, highlights (skipped in low detail and stills) ------------------------------------------
function Rig:Trail(actor, color, lifetime, width)
	if self.Low or self.Still then
		return nil
	end
	local p = actor.Part
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, width / 2, 0), Vector3.new(0, -width / 2, 0)
	a0.Parent, a1.Parent = p, p
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = colors(color)
	trail.Lifetime, trail.LightEmission, trail.FaceCamera = lifetime, 1, true
	trail.Transparency = NumberSequence.new(0.15, 1)
	trail.WidthScale = NumberSequence.new(1, 0.1)
	trail.MinLength = 0.05
	trail.Enabled = false
	trail.Parent = p
	table.insert(self.Trails, { Trail = trail, Actor = actor })
	return trail
end

function Rig:Beam(from, to, color, width)
	if self.Low or self.Still then
		return nil
	end
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = from.Part, to.Part
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Color = colors(color)
	beam.LightEmission, beam.LightInfluence, beam.FaceCamera = 1, 0, true
	beam.Width0, beam.Width1 = width, width * 0.3
	beam.Transparency = NumberSequence.new(0.2, 0.6)
	beam.Segments = 6
	beam.Enabled = false
	beam.Parent = from.Part
	table.insert(self.Beams, beam)
	return beam
end

function Rig:Light(actor, color, range)
	if self.Low or self.Still then
		return nil
	end
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = color, range, 0, false
	light.Parent = actor.Part
	table.insert(self.Lights, light)
	return light
end

function Rig:Group(name)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = self.Root
	return model
end

function Rig:Outline(model, color)
	if self.Low or self.Still then
		return nil
	end
	local h = Instance.new("Highlight")
	h.Name = "FinisherOutline"
	h.Adornee = model
	h.FillTransparency, h.OutlineTransparency = 1, 1
	h.OutlineColor = color
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Enabled = false
	h.Parent = model
	table.insert(self.Highlights, h)
	return h
end

-- Legendary colour grade on the local camera. Created per play and always destroyed with the play.
function Rig:Grade()
	if self.Low or self.Still or not self.AllowPost then
		return nil
	end
	if not self.GradeEffect then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "FinisherGrade"
		cc.Enabled = true
		cc.Parent = workspace.CurrentCamera or Lighting
		self.GradeEffect = cc
	end
	return self.GradeEffect
end

-- Frame plumbing used by FinisherFX ----------------------------------------------------------------------------
function Rig:BeginFrame()
	self.Moving = {}
	self.MovingCF = {}
end

-- Resets everything that a previous play touched so a pooled rig replays identically.
function Rig:Reset()
	for _, entry in self.Schedule do
		entry.Fired = false
	end
	for _, actor in self.Actors do
		actor.Part.Transparency = 1
	end
	for _, e in self.Emitters do
		e:Clear()
	end
	for _, t in self.Trails do
		t.Trail.Enabled = false
		t.Trail:Clear()
	end
	for _, b in self.Beams do
		b.Enabled = false
	end
	for _, l in self.Lights do
		l.Brightness = 0
	end
	for _, h in self.Highlights do
		h.Enabled = false
	end
	self:DropGrade()
	self.TrailsLive = false
	for _, hook in self.ResetHooks do
		hook()
	end
end

-- Shared modules (Finishers/Modules) register a per-frame step here; FinisherFX runs them after the show's own
-- step. `reset` (optional) clears any per-play state when a pooled rig is reused.
function Rig:AddStep(step, reset)
	table.insert(self.Steps, step)
	if reset then
		table.insert(self.ResetHooks, reset)
	end
end

function Rig:StepModules(t)
	for _, step in self.Steps do
		step(t)
	end
end

function Rig:DropGrade()
	if self.GradeEffect then
		self.GradeEffect:Destroy()
		self.GradeEffect = nil
	end
end

-- Stills: no particles/trails, so only geometry stays.
function Rig:Freeze()
	for _, e in self.Emitters do
		e:Destroy()
	end
	self.Emitters = {}
end

return Kit
