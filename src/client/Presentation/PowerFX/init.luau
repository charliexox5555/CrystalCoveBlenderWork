-- Power VFX v2 engine (workstream E, docs/vfx/POWER_VFX_V2.md). One per CombatEffects. Every effect steps from the
-- fight render clock (Effects.Time), so hitstop, slow-mo and preview freezes apply for free. Meshes, particle sockets
-- and lights are pooled under one `PowerFX` folder (attribute Pooled, so ClearTransient keeps it); effects borrow and
-- return them. Presentation only: server facts own timing and outcomes.
local RS = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local C = require(RS.Shared.Config.PowerVFX)
local PowerAudio = require(RS.Shared.Config.PowerAudio)
local Audio = require(RS.Shared.Config.Audio)
local Visuals = require(RS.Shared.Config.CombatKitVisuals)
local Motion = require(script.Parent.Parent.UI.Components.Motion)

local FX = {}
FX.__index = FX
FX.C = C

local FAR = CFrame.new(0, -10000, 0)
local NEON, GLASS = Enum.Material.Neon, Enum.Material.Glass

-- Easing ------------------------------------------------------------------------------------------------------------
local function clamp01(x)
	return math.clamp(x, 0, 1)
end
FX.clamp01 = clamp01
function FX.smooth(x)
	x = clamp01(x)
	return x * x * (3 - 2 * x)
end
function FX.easeOut(x)
	x = clamp01(x)
	return 1 - (1 - x) ^ 3
end
function FX.easeIn(x)
	x = clamp01(x)
	return x * x * x
end
-- Back ease-out: 0 -> ~10% overshoot -> 1.
function FX.pop(x)
	x = clamp01(x)
	return 1 + 2.70158 * (x - 1) ^ 3 + 1.70158 * (x - 1) ^ 2
end
-- 0 -> 1 -> 0 over [0, 1] with a fast rise.
function FX.bell(x, rise)
	x = clamp01(x)
	rise = rise or 0.25
	return if x < rise then FX.easeOut(x / rise) else 1 - FX.smooth((x - rise) / (1 - rise))
end

function FX.face(position)
	return CFrame.new(position) * workspace.CurrentCamera.CFrame.Rotation
end
-- A rotation that faces mostly the camera but leans toward `dir`: rings "along" a travel direction would be seen
-- edge-on from the fixed side camera, so they read as an ellipse instead.
function FX.tilted(dir, lean)
	local look = workspace.CurrentCamera.CFrame.LookVector
	return CFrame.lookAt(Vector3.zero, (dir * (lean or 0.5) - look).Unit).Rotation
end

-- A camera-plane basis whose X axis points along `dir` (projected): for sheets and slashes that travel.
function FX.along(position, dir)
	local c = workspace.CurrentCamera.CFrame
	local x = dir - c.LookVector * dir:Dot(c.LookVector)
	x = if x.Magnitude > 0.001 then x.Unit else c.RightVector
	local z = -c.LookVector
	return CFrame.fromMatrix(position, x, z:Cross(x), z)
end

function FX.hex(h)
	return Color3.fromHex(h)
end

-- Construction ------------------------------------------------------------------------------------------------------
function FX.get(effects)
	if effects.PowerFX and effects.PowerFX.Root.Parent then
		return effects.PowerFX
	end
	local root = Instance.new("Folder")
	root.Name = "PowerFX"
	root:SetAttribute("Pooled", true)
	root.Parent = effects.Root
	local hero = RS.Assets:FindFirstChild("VFX") and RS.Assets.VFX:FindFirstChild("RoundHeroV2")
	local self = setmetatable({
		Effects = effects,
		Scene = effects.Scene,
		Root = root,
		Meshes = effects.Assets.Meshes,
		Hero = hero,
		Pool = {},
		Base = {},
		Active = {},
		Sockets = {},
		Lights = {},
		Outlines = {},
		Seen = {},
		Ready = {},
		Armed = {},
		Statuses = {},
	}, FX)
	effects.PowerFX = self
	return self
end

function FX:Time()
	return self.Effects.Time or 0
end

function FX:Fighter(side)
	return self.Scene.Fighters[side]
end

function FX:Visual(side)
	local f = self:Fighter(side)
	return f and Visuals[f.Id] or {}
end

-- The power's signature colours (not the glassy tint, which the old clamp turned pink for Milk).
function FX:Colors(side)
	local v = self:Visual(side)
	local f = self:Fighter(side)
	local main = if v.Color then Color3.fromHex(v.Color) else Color3.fromHex(f and f.Def.Tint or "#FFFFFF")
	local accent = if v.Accent then Color3.fromHex(v.Accent) else Color3.new(1, 1, 1)
	-- Cycle kits (Potion Flask) take the current brew's colour.
	local brew = self.Brew and self.Brew[side]
	if brew and v.Brews and v.Brews[brew] then
		return Color3.fromHex(v.Brews[brew]), main
	end
	return main, accent
end

-- A colour that reads against the bright sky: pale signature colours (white, cream, silver) use the accent.
function FX:Vivid(side)
	local main, accent = self:Colors(side)
	local _, s = main:ToHSV()
	return if s < 0.25 then accent else main
end

function FX:Tier(side)
	local f = self:Fighter(side)
	-- A kit may ask for a higher presentation tier than its rarity (Hollowlight: premium seasonal set).
	local kit = f and self.Kits and self.Kits[f.Id]
	return (kit and kit.Tier) or C.Tier[f and f.Def.Rarity or "Common"] or "Crisp"
end

function FX:Rank(side)
	return C.TierRank[self:Tier(side)] or 1
end

-- Detail: 0 = low (unwatched fights, low quality), 1 = full. Particle scale for phones / low quality.
function FX:Low(side)
	local f = side and self:Fighter(side)
	if (f and f.LowDetail) or self.Scene.Viewing ~= true then
		return true
	end
	local now = os.clock()
	if not self.QualityAt or now - self.QualityAt > 1 then
		self.QualityAt = now
		local ok, level = pcall(function()
			return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
		end)
		self.LowQuality = (ok and level > 0 and level <= C.Budget.LowQualityLevel)
			or require(script.Parent.Parent.LocalSettings).lowEffects() -- Settings: Large Effects off
			-- Studio check of the low-detail branch without touching the user's graphics setting.
			or (game:GetService("RunService"):IsStudio() and workspace:GetAttribute("PowerFXLowDetail") == true)
		self.Reduced = Motion.reduced()
		self.ParticleScale = if self.LowQuality
			then C.Budget.LowParticles
			elseif UIS.TouchEnabled and not UIS.KeyboardEnabled then C.Budget.TouchParticles
			else 1
	end
	return self.LowQuality == true
end

function FX:Count(side, n)
	if n <= 0 then
		return 0
	end
	local low = self:Low(side)
	return math.max(1, math.floor(n * (if low then 0.5 else 1) + 0.5))
end

-- Pooled mesh actors ------------------------------------------------------------------------------------------------
local BASIC = {
	Ball = Enum.PartType.Ball,
	Anchor = Enum.PartType.Ball,
	Block = Enum.PartType.Block,
	Disc = Enum.PartType.Cylinder,
}

function FX:Template(kind)
	local t = self.Meshes:FindFirstChild(kind) or (self.Hero and self.Hero:FindFirstChild(kind))
	if t then
		return t
	end
	if BASIC[kind] then
		return nil
	end
	-- RoundHeroV2 missing (preview library): fall back to the closest shared shape.
	local fallback = ({
		ShockCrown = "Ring",
		NovaStar = "CrystalChip",
		BlastBloom = "BubbleDome",
		CrystalShard = "Thorn",
	})[kind]
	return self.Meshes:FindFirstChild(fallback or "Ring")
end

function FX:Part(kind, color, material)
	local list = self.Pool[kind]
	local p = list and table.remove(list)
	if not p or not p.Parent then
		local template = self:Template(kind)
		if template then
			p = template:Clone()
		else
			p = Instance.new("Part")
			p.Shape = BASIC[kind]
			p.Size = if kind == "Disc"
				then Vector3.new(0.1, 1, 1)
				elseif kind == "Anchor" then Vector3.one * 0.05
				else Vector3.one
		end
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
		p:SetAttribute("PowerFXKind", kind)
		self.Base[kind] = self.Base[kind] or p.Size
		p.Parent = self.Root
	end
	p.Name = "FX_" .. kind
	p.Size = self.Base[kind]
	p.Color, p.Material, p.Transparency = color or Color3.new(1, 1, 1), material or NEON, 1
	p.Reflectance = 0
	return p
end

-- Size helpers: scale a pooled part so its largest side (or a chosen axis) is `size` studs.
function FX:Fit(p, size)
	local base = self.Base[p:GetAttribute("PowerFXKind")] or p.Size
	p.Size = base * (size / math.max(base.X, base.Y, base.Z))
	return p.Size
end

function FX:Free(p)
	if not p or not p.Parent then
		return
	end
	p.Transparency, p.CFrame = 1, FAR
	for _, child in p:GetChildren() do
		if child:IsA("Trail") then
			child.Enabled = false
		end
	end
	local kind = p:GetAttribute("PowerFXKind")
	self.Pool[kind] = self.Pool[kind] or {}
	table.insert(self.Pool[kind], p)
end

-- Trail on a pooled part (created once per part, reused).
function FX:Trail(p, color, lifetime, width, transparency)
	local trail = p:FindFirstChild("FXTrail")
	if not trail then
		local a, b = Instance.new("Attachment"), Instance.new("Attachment")
		a.Name, b.Name = "FXTrailA", "FXTrailB"
		a.Parent, b.Parent = p, p
		trail = Instance.new("Trail")
		trail.Name, trail.Attachment0, trail.Attachment1 = "FXTrail", a, b
		trail.LightEmission, trail.FaceCamera = 0.8, true
		trail.Parent = p
	end
	local half = (width or 0.5) / 2
	trail.Attachment0.Position, trail.Attachment1.Position = Vector3.new(0, half, 0), Vector3.new(0, -half, 0)
	local c = if typeof(color) == "ColorSequence" then color else ColorSequence.new(color)
	trail.Color, trail.Lifetime = c, lifetime or 0.2
	trail.Transparency = transparency or NumberSequence.new(0.1, 1)
	trail.WidthScale = NumberSequence.new(1, 0.15)
	trail:Clear()
	trail.Enabled = true
	return trail
end

-- Pooled particle sockets -------------------------------------------------------------------------------------------
local TEXTURE = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
}

function FX:Socket(kind, color)
	local key = kind .. ":" .. color:ToHex()
	local socket = self.Sockets[key]
	if socket and socket.Parent then
		return socket
	end
	socket = Instance.new("Part")
	socket.Name = "FXSocket_" .. kind
	socket.Size, socket.Transparency = Vector3.one * 0.05, 1
	socket.Anchored, socket.CanCollide, socket.CanTouch, socket.CanQuery = true, false, false, false
	socket.CFrame = FAR
	local e
	local template = self.Effects.Assets.Particles:FindFirstChild(kind)
	if template then
		e = template:Clone()
	else
		e = Instance.new("ParticleEmitter")
		e.Texture = TEXTURE[kind] or TEXTURE.Sparkle
		e.LightEmission, e.LightInfluence = 1, 0
		e.Lifetime = NumberRange.new(0.35, 0.7)
		e.Speed = NumberRange.new(2, 6)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.75),
			NumberSequenceKeypoint.new(0.3, 0.6),
			NumberSequenceKeypoint.new(1, 0),
		})
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		e.Drag = 3
		if kind == "Fire" then
			e.LightEmission = 0.45 -- full additive washes out against the bright sky
			e.Lifetime = NumberRange.new(0.25, 0.45)
			e.Speed = NumberRange.new(2, 4)
			e.SpreadAngle = Vector2.new(25, 25)
			e.Acceleration = Vector3.new(0, 6, 0)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0.3) })
			e.RotSpeed = NumberRange.new(-90, 90)
		elseif kind == "Smoke" then
			e.LightEmission = 0.2
			e.Lifetime = NumberRange.new(0.4, 0.8)
			e.Speed = NumberRange.new(1, 3)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1.2) })
			e.Transparency =
				NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		end
	end
	e.Name, e.Rate, e.Enabled = "Emitter", 0, true
	e.LockedToPart = false
	e.Color = ColorSequence.new(color)
	e.Parent = socket
	socket.Parent = self.Root
	self.Sockets[key] = socket
	return socket
end

-- Emits `count` particles at cf (its LookVector is the emission direction for directional sockets).
-- opts: Speed (NumberRange), Spread (Vector2), Size (multiplier), Accel (Vector3), Lifetime (NumberRange).
function FX:Emit(side, kind, where, count, color, opts)
	count = math.floor(count * (self.ParticleScale or 1) * (if self:Low(side) then 0.5 else 1) + 0.5)
	if count <= 0 then
		return
	end
	local socket = self:Socket(kind, color)
	local e = socket.Emitter
	local base = e:GetAttribute("FXBase")
	if not base then
		e:SetAttribute("FXBase", true)
		e:SetAttribute("FXSpeedMin", e.Speed.Min)
		e:SetAttribute("FXSpeedMax", e.Speed.Max)
		e:SetAttribute("FXSpreadX", e.SpreadAngle.X)
		e:SetAttribute("FXSpreadY", e.SpreadAngle.Y)
		e:SetAttribute("FXAccel", e.Acceleration)
		e:SetAttribute("FXLifeMin", e.Lifetime.Min)
		e:SetAttribute("FXLifeMax", e.Lifetime.Max)
		local keys = {}
		for _, k in e.Size.Keypoints do
			table.insert(keys, k.Value)
		end
		e:SetAttribute("FXSizes", table.concat(keys, ","))
	end
	opts = opts or {}
	e.Speed = opts.Speed or NumberRange.new(e:GetAttribute("FXSpeedMin"), e:GetAttribute("FXSpeedMax"))
	e.SpreadAngle = opts.Spread or Vector2.new(e:GetAttribute("FXSpreadX"), e:GetAttribute("FXSpreadY"))
	e.Acceleration = opts.Accel or e:GetAttribute("FXAccel")
	e.Lifetime = opts.Lifetime or NumberRange.new(e:GetAttribute("FXLifeMin"), e:GetAttribute("FXLifeMax"))
	if opts.Size or e:GetAttribute("FXSized") then
		e:SetAttribute("FXSized", opts.Size ~= nil and opts.Size ~= 1)
		local scale = opts.Size or 1
		local values = string.split(e:GetAttribute("FXSizes"), ",")
		local keys = {}
		for i, k in e.Size.Keypoints do
			table.insert(keys, NumberSequenceKeypoint.new(k.Time, (tonumber(values[i]) or k.Value) * scale, k.Envelope))
		end
		e.Size = NumberSequence.new(keys)
	end
	socket.CFrame = if typeof(where) == "CFrame" then where else CFrame.new(where)
	e:Emit(count)
end

-- Effects -----------------------------------------------------------------------------------------------------------
-- spec: { Side, Seconds, Step = function(e, age, k, time) end, Stop = function(e) end, Key, Start }
-- Step returns false to end early. Parts in e.Parts are freed when the effect ends.
function FX:Spawn(spec)
	local now = self:Time()
	spec.Start = spec.Start or now
	spec.Parts = spec.Parts or {}
	if spec.Key then
		self:StopKey(spec.Key)
	end
	if now > spec.Start + spec.Seconds then
		return nil
	end
	if #self.Active >= C.Budget.MaxEffects then
		self:Stop(self.Active[1])
	end
	table.insert(self.Active, spec)
	return spec
end

function FX:Own(e, p)
	table.insert(e.Parts, p)
	return p
end

function FX:Stop(e)
	if not e or e.Done then
		return
	end
	e.Done = true
	if e.Stop then
		pcall(e.Stop, e)
	end
	for _, p in e.Parts do
		self:Free(p)
	end
	e.Parts = {}
	local i = table.find(self.Active, e)
	if i then
		table.remove(self.Active, i)
	end
end

function FX:StopKey(key)
	for i = #self.Active, 1, -1 do
		local e = self.Active[i]
		if e.Key == key then
			self:Stop(e)
		end
	end
end

function FX:StopSide(side)
	for i = #self.Active, 1, -1 do
		local e = self.Active[i]
		if e.Side == side then
			self:Stop(e)
		end
	end
	self.Ready[side], self.Armed[side] = nil, nil
	self:OutlineOff(side)
end

function FX:StopAll()
	for i = #self.Active, 1, -1 do
		self:Stop(self.Active[i])
	end
	self.Ready, self.Armed = {}, {}
	for side in self.Scene.Fighters do
		self:OutlineOff(side)
	end
	if self.Bloom then
		self.Bloom:Destroy()
		self.Bloom = nil
	end
end

function FX:Step(time)
	for i = #self.Active, 1, -1 do
		local e = self.Active[i]
		if not e or e.Done then
			continue
		end
		local age = time - e.Start
		if age < 0 then
			continue
		end
		local k = if e.Seconds > 0 then age / e.Seconds else 1
		local ok, alive = pcall(e.Step, e, age, math.min(k, 1), time)
		if not ok then
			warn("PowerFX effect failed: " .. tostring(alive))
			self:Stop(e)
		elseif alive == false or k >= 1 then
			self:Stop(e)
		end
	end
	if self.Bloom then
		local k = (time - self.BloomAt) / C.Hero.BloomSeconds
		if k >= 1 or k < 0 then
			self.Bloom:Destroy()
			self.Bloom = nil
		else
			local b = FX.bell(k, 0.2) * self.BloomStrength
			self.Bloom.Brightness = C.Hero.BloomBrightness * b
			self.Bloom.Saturation = C.Hero.BloomSaturation * b
		end
	end
end

-- Lights ------------------------------------------------------------------------------------------------------------
-- A pooled PointLight following `at` (Vector3 or function() -> Vector3), shaped by FX.bell over `seconds`.
function FX:Light(side, at, color, seconds, brightness, range)
	if self:Low(side) then
		return
	end
	local count = 0
	for _, e in self.Active do
		if e.IsLight then
			count += 1
		end
	end
	if count >= C.Budget.Lights then
		return
	end
	local p = self:Part("Anchor", color)
	local light = p:FindFirstChildOfClass("PointLight") or Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = color, range or C.Light.Range, 0, false
	light.Parent = p
	local peak = brightness or C.Light.Brightness
	return self:Spawn({
		Side = side,
		Seconds = seconds,
		IsLight = true,
		Parts = { p },
		Step = function(e, age, k)
			p.CFrame = CFrame.new(if type(at) == "function" then at(age) else at)
			light.Brightness = peak * FX.bell(k, e.Rise or 0.15)
		end,
		Stop = function()
			light.Brightness = 0
		end,
	})
end

-- Brief hero bloom (viewed fight only; skipped with reduced motion and on low detail).
function FX:HeroBloom(side, strength)
	if self:Low(side) or self.Reduced or not self.Scene.Viewing then
		return
	end
	if not self.Bloom or not self.Bloom.Parent then
		self.Bloom = Instance.new("ColorCorrectionEffect")
		self.Bloom.Name = "PowerHeroBloom"
		self.Bloom.Parent = Lighting
	end
	self.BloomAt, self.BloomStrength = self:Time(), strength or 1
end

-- Ground ------------------------------------------------------------------------------------------------------------
-- The arena floor under a point (cached per fight; the stand floor is flat).
function FX:Ground(position)
	if self.FloorY then
		return Vector3.new(position.X, self.FloorY, position.Z)
	end
	local params = RaycastParams.new()
	local ignore = { self.Scene.Root }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(position, Vector3.new(0, -40, 0), params)
	self.FloorY = if hit then hit.Position.Y + 0.06 else position.Y - 6
	return Vector3.new(position.X, self.FloorY, position.Z)
end

-- Outlines (one Highlight per fighter, only while it carries a state) -------------------------------------------------
function FX:Outline(side, color, transparency)
	local f = self:Fighter(side)
	if not f or self:Low(side) or f.Broken or f.Finishing then
		self:OutlineOff(side)
		return
	end
	local h = self.Outlines[side]
	if not h or not h.Parent then
		h = Instance.new("Highlight")
		h.Name = "PowerFXOutline"
		h.FillTransparency = 1
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Adornee = f.Model
		h.Parent = self.Root
		self.Outlines[side] = h
	end
	h.OutlineColor, h.OutlineTransparency, h.Enabled = color, transparency, true
end

function FX:OutlineOff(side)
	local h = self.Outlines[side]
	if h then
		h.Enabled = false
	end
end

-- Body helpers ------------------------------------------------------------------------------------------------------
function FX:Body(side)
	local f = self:Fighter(side)
	return f.Body.Position, math.max(f.Body.Size.X, f.Body.Size.Y, f.Body.Size.Z)
end

-- Toward the foe (flattened to the fight plane when the bodies overlap).
function FX:Toward(side)
	local a, b = self:Fighter(side).Body.Position, self:Fighter(3 - side).Body.Position
	local d = b - a
	return if d.Magnitude > 0.01 then d.Unit else self.Scene.Frame.RightVector * (if side == 1 then 1 else -1)
end

-- Body motion layers read by Hero.motion (anticipation wiggle, rear-back, recoil).
function FX:Move(side, kind, seconds, amount, start)
	local f = self:Fighter(side)
	f.FxMoves = f.FxMoves or {}
	table.insert(f.FxMoves, { Kind = kind, At = start or self:Time(), Seconds = seconds, Amount = amount or 1 })
end

function FX.motion(f, time)
	local moves = f.FxMoves
	if not moves or #moves == 0 then
		return CFrame.identity
	end
	local pitch, roll, yaw = 0, 0, 0
	for i = #moves, 1, -1 do
		local m = moves[i]
		local t = (time - m.At) / m.Seconds
		if t >= 1 or t < -2 then
			table.remove(moves, i)
		elseif t >= 0 then
			if m.Kind == "wiggle" then
				-- Builds toward release: a quickening shiver.
				roll += math.sin((time - m.At) * C.Motion.WindupHz * math.pi * 2 * (0.6 + t)) * C.Motion.WindupWiggle * t * m.Amount
			elseif m.Kind == "rear" then
				-- Lean back through the windup, snap forward at release.
				pitch -= FX.smooth(t / 0.85) * (1 - FX.smooth((t - 0.85) / 0.15)) * C.Motion.RearBack * m.Amount
			elseif m.Kind == "recoil" then
				roll += math.sin(t * math.pi * 2) * (1 - t) * C.Motion.Recoil * m.Amount
			elseif m.Kind == "spin" then
				yaw += FX.smooth(t) * math.pi * 2 * m.Amount
			end
		end
	end
	return CFrame.Angles(pitch, yaw, roll)
end

-- Sound cues (Config/PowerAudio) -------------------------------------------------------------------------------------
local voices = {} -- client-wide: power sounds alive right now
local preloaded = false

local function preload()
	if preloaded then
		return
	end
	preloaded = true
	task.spawn(function()
		local cache = Instance.new("Folder")
		cache.Name = "PowerAudioCache"
		cache.Parent = game:GetService("SoundService")
		local list = {}
		for _, def in PowerAudio.Sounds do
			local sound = Instance.new("Sound")
			sound.SoundId, sound.Parent = def.Id, cache
			table.insert(list, sound)
		end
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(list)
		end)
	end)
end

-- Plays a cue's layers on the fighter's body (3D, Scene:Sound rolloff). Unwatched fights get only the first layer.
-- Sounds join Effects.Sounds, so ClearTransient (round end, stop viewing) stops them.
function FX:Cue(side, name)
	local layers = PowerAudio.Cues[name]
	local f = self:Fighter(side)
	if not layers or not f or self.Scene.Muted then
		return
	end
	preload()
	local watched = self.Scene.Viewing == true
	local bigHit = layers.Contact and self.BigHitAt and math.abs(self:Time() - self.BigHitAt) <= PowerAudio.BigHitWindow
	for i, layer in ipairs(layers) do -- ipairs: cues also carry a Contact flag
		if (not watched or bigHit) and i > 1 then
			break
		end
		local def = PowerAudio.Sounds[layer.Key]
		local id = if def then def.Id else Audio[layer.Key]
		if not id then
			continue
		end
		local function play()
			if f.Broken or not f.Body.Parent or not self.Root.Parent or self.Scene.Muted then
				return
			end
			for j = #voices, 1, -1 do
				if not voices[j].Parent then
					table.remove(voices, j)
				end
			end
			if #voices >= PowerAudio.VoiceCap then
				return
			end
			local jitter = 1 + (math.random() * 2 - 1) * (layer.Jitter or 0)
			local volume = (layer.Volume or 0.35) * (if watched then 1 else PowerAudio.UnwatchedScale)
			if layers.Contact then
				volume = math.min(volume, PowerAudio.ContactMaxVolume)
			end
			local seconds = layer.Seconds or (def and def.Seconds)
			local sound = self.Scene:Sound(id, f.Body, (layer.Pitch or 1) * jitter, volume, seconds)
			if sound then
				table.insert(voices, sound)
				table.insert(self.Effects.Sounds, sound)
				if layers.Contact and i > 1 then
					self.Tails = self.Tails or {}
					table.insert(self.Tails, { Sound = sound, At = self:Time() })
				end
			end
		end
		if layer.Delay and layer.Delay > 0 then
			task.delay(layer.Delay, play)
		else
			play()
		end
	end
end

-- B's hit tiers: a Smash/Crit hit near a power contact keeps the mix clean (see PowerAudio.BigHitWindow).
local HIT_STRENGTH = { Glance = 0.4, Solid = 0.7, Smash = 1, Crit = 1.3, Block = 0.5 }

function FX:HitTier(e)
	local feel = self.Scene.Feel
	local ok, name = pcall(function()
		return feel and feel:Classify(e)
	end)
	name = if ok and name then name else "Solid"
	-- Living glassies: every reacting detail part rings with the hit, scaled by B's tier.
	local strength = HIT_STRENGTH[name] or 0.7
	for side, f in self.Scene.Fighters do
		if f.Motion and not f.Broken and not f.Finishing then
			local dealt = e.Damage and e.Damage[side] or 0
			local share = if dealt > 0 then 1 else 0.6
			f.Motion:Hit(strength * share, if side == 1 then -1 else 1, e.Time)
		end
	end
	if name ~= "Smash" and name ~= "Crit" then
		return
	end
	local at = e.Time or self:Time()
	self.BigHitAt = at
	for i = #(self.Tails or {}), 1, -1 do
		local tail = self.Tails[i]
		if math.abs(tail.At - at) <= PowerAudio.BigHitWindow and tail.Sound.Parent then
			tail.Sound:Destroy()
		end
		if not tail.Sound.Parent or at - tail.At > 1 then
			table.remove(self.Tails, i)
		end
	end
end

require(script.Shapes)(FX)
require(script.Dispatch)(FX)
return FX
