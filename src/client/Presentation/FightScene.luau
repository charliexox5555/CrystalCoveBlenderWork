local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local Balance = require(RS.Shared.Config.Balance)
local Glassies = require(RS.Shared.Config.Glassies)
local Powers = require(RS.Shared.Config.Powers)
local Audio = require(RS.Shared.Config.Audio)
local Health = require(script.Parent.FightHealth)
local AbilityNumbers = require(script.Parent.AbilityNumbers)
local Hero = require(script.Parent.HeroPowers)
local M, Feel = Balance.Motion, Balance.Feel
local Scene = {}
Scene.__index = Scene

function Scene:Sound(...)
	if not self.Muted then
		return self.Shatter:Sound(...)
	end
end

local function part(parent, name, color)
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = name, true, false, false, false
	p.CastShadow, p.Material, p.Color = false, Enum.Material.Neon, color
	p.Parent = parent
	return p
end

local function emitter(parent, color)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color, e.LightEmission, e.Rate = ColorSequence.new(color), 0.8, 0
	e.Lifetime, e.Speed, e.SpreadAngle = NumberRange.new(0.2, 0.6), NumberRange.new(2, 5), Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
	e.Parent = parent
	return e
end

function Scene.new(data, maxima, shatter)
	local self = setmetatable({
		Data = data,
		Frame = data.Frame,
		ArenaId = data.ArenaId,
		HeartPositions = data.HeartPositions,
		Fighters = {},
		Shatter = shatter,
		Ghost = {},
	}, Scene)
	self.Root = Instance.new("Folder")
	self.Root.Name = "LocalFight_" .. tostring(data.Id)
	self.Root:SetAttribute("FightId", data.Id)
	self.Root.Parent = workspace
	for side, setup in { data.A, data.B } do
		-- Value coordinates survive streaming/replication ordering; Instance references may arrive nil.
		local anchor = part(self.Root, "HookAnchor" .. side, Color3.new(1, 1, 1))
		anchor.Size, anchor.Transparency = Vector3.one * 0.1, 1
		anchor.Position = if data.HookPositions
			then data.HookPositions[side]
			else data.Frame:PointToWorldSpace(Vector3.new((if side == 1 then -1 else 1) * M.HookGap / 2, 0, 0))
		local hook = Instance.new("Attachment")
		hook.Name, hook.Parent = "StringHook", anchor
		local def = Glassies.get(setup.Id)
		local library = if data.ReleasePrototype then RS.Assets.CombatReleasePreview.Glassies else RS.Assets.Glassies
		local renderId = if library:FindFirstChild(def.Asset)
			then def.Asset
			else if def.Type == "Heavy" then "jam" elseif def.Type == "Sharp" then "prism" else "pop"
		local source = library[renderId]
		local model = Instance.new("Model")
		model.Name = setup.Id
		model.WorldPivot = CFrame.identity
		local body = source.Body:Clone()
		body.Parent = model
		local parts = { body }
		for _, template in (source:FindFirstChild("Details") and source.Details:GetChildren() or {}) do
			if template:GetAttribute("EffectOnly") then
				continue
			end
			local detail = template:Clone()
			detail.Parent = model
			table.insert(parts, detail)
		end
		for _, p in parts do
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		end
		if renderId ~= def.Asset then
			body.Color = Color3.fromHex(def.Tint)
		end
		model:ScaleTo(M.GlassyScale)
		model.Parent = self.Root
		local templates = Instance.new("Model")
		templates.Name = "ShardTemplates"
		templates.WorldPivot = CFrame.identity
		for _, template in source.Shards:GetChildren() do
			template:Clone().Parent = templates
		end
		for _, template in (source:FindFirstChild("Details") and source.Details:GetChildren() or {}) do
			if not template.Name:find("Bubble") and not template:GetAttribute("EffectOnly") then
				template:Clone().Parent = templates
			end
		end
		templates:ScaleTo(M.GlassyScale)
		local endpoint = Instance.new("Attachment")
		endpoint.Name, endpoint.CFrame = "StringEnd", body.PivotOffset
		endpoint.Parent = body
		local beam = Instance.new("Beam")
		beam.Name, beam.Attachment0, beam.Attachment1 = "String", hook, endpoint
		beam.Width0, beam.Width1, beam.FaceCamera = 0.04, 0.04, true
		beam.Color = ColorSequence.new(Color3.fromHex("#F2EAD8"))
		beam.Parent = model
		local highlight = Instance.new("Highlight")
		highlight.Adornee, highlight.DepthMode, highlight.FillTransparency, highlight.OutlineTransparency =
			model, Enum.HighlightDepthMode.Occluded, 1, 1
		highlight.Enabled = false
		highlight.Parent = model
		local bubble = part(self.Root, "ShieldBubble", Color3.fromHex("#A7E8FF"))
		bubble.Shape, bubble.Size, bubble.Transparency, bubble.Material =
			Enum.PartType.Ball, Vector3.one * (def.Radius * M.GlassyScale * 2.7), 1, Enum.Material.ForceField
		local glints = emitter(body, Color3.fromHex(def.Tint))
		local at0, at1 = Instance.new("Attachment"), Instance.new("Attachment")
		at0.Position, at1.Position = Vector3.new(-0.5, 0, 0), Vector3.new(0.5, 0, 0)
		at0.Parent, at1.Parent = body, body
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1, trail.Lifetime, trail.Enabled = at0, at1, 0.28, false
		trail.Color, trail.LightEmission = ColorSequence.new(Color3.fromHex(def.Tint)), 0.8
		trail.Transparency = NumberSequence.new(0.5, 1)
		trail.Parent = body
		self.Fighters[side] = {
			ReleaseArt = data.ReleasePrototype or source:GetAttribute("ReleaseVersion") == 2,
			CrackStage = 0,
			Id = setup.Id,
			RenderId = renderId,
			Def = def,
			Model = model,
			Body = body,
			Parts = parts,
			Hook = hook,
			Beam = beam,
			Highlight = highlight,
			Bubble = bubble,
			Glints = glints,
			Trail = trail,
			Stats = { MaxHP = maxima[side] },
			Scale = M.GlassyScale,
			ShardTemplates = templates,
			Effects = {},
		}
		Health.new(self.Fighters[side], self.Root)
		trail.Lifetime = Balance.CombatVFX.SwingTrailSeconds
	end
	if data.ReleasePrototype or Balance.CombatRelease.Enabled then
		self.Combat = require(script.Parent.CombatEffects).new(self)
		self.Combat.Time = data.Snapshot and data.Snapshot.T or 0
		for _, e in data.SignatureState or {} do
			self.Combat:Event(e)
		end
	end
	return self
end

function Scene:Pose(side, p, twist, tilt)
	local f = self.Fighters[side]
	if f.Broken or f.Finishing then
		return
	end
	local up = -self.Frame:VectorToWorldSpace(p.Unit)
	local right = self.Frame.RightVector - up * self.Frame.RightVector:Dot(up)
	right = right.Unit
	f.Twist = twist
	f.Pivot = CFrame.fromMatrix(f.Hook.WorldPosition + self.Frame:VectorToWorldSpace(p), right, up, right:Cross(up))
		* CFrame.Angles(tilt.X, twist, tilt.Z)
		* Hero.motion(f, self.Combat and self.Combat.Time or 0)
		* (f.React or CFrame.identity) -- CombatFeel wobble/jolt, presentation only
	f.Model:PivotTo(f.Pivot)
	f.Bubble.CFrame = f.Body.CFrame
end

function Scene:GhostPath(aim, yaw, side)
	side = side or 1
	for i = 1, 18 do
		local dot = self.Ghost[i]
		if not dot then
			dot = part(self.Root, "FirstSwingGhost", Color3.fromHex("#FFE45C"))
			dot.Shape, dot.Size, dot.Transparency = Enum.PartType.Ball, Vector3.one * 0.13, 0.35
			self.Ghost[i] = dot
		end
		local angle = -aim + 2 * aim * (i - 1) / 17
		local p = Vector3.new(
			(if side == 1 then 1 else -1) * math.sin(angle) * math.cos(yaw),
			-math.cos(angle),
			-math.sin(angle) * math.sin(yaw)
		) * M.StringLength
		dot.Position = self.Fighters[side].Hook.WorldPosition + self.Frame:VectorToWorldSpace(p)
	end
end

function Scene:HideGhost()
	for _, p in self.Ghost do
		p:Destroy()
	end
	self.Ghost = {}
end

-- The round is over: casts of both sides (ray lenses, weapons, guard lids...) stop here. The render clock stops at
-- the final snapshot, so their end times never arrive and they would hang in the air until the scene goes Idle.
function Scene:EndRoundEffects()
	if not self.Combat then
		return
	end
	for side, f in self.Fighters do
		self.Combat:CancelSide(side)
		Hero.guard(self.Combat, f, false)
	end
end

function Scene:HideBroken(side)
	local f = self.Fighters[side]
	f.Broken = true
	f.Health.Enabled = false
	self:EndRoundEffects()
	for _, p in f.Parts do
		p.Transparency = 1
	end
	f.Beam.Enabled, f.Trail.Enabled, f.Highlight.Enabled = false, false, false
	f.Glints.Rate, f.Bubble.Transparency = 0, 1
	f.Glints.Enabled = false
	for _, crack in f.Cracks or {} do
		crack:Destroy()
	end
	f.Cracks = {}
	if f.Tag then
		f.Tag.Enabled = false
	end
end

-- Status tints, built once (Update runs every frame for every fighter in range).
local WHITE, FROZEN, RAGE = Color3.new(1, 1, 1), Color3.fromHex("#B3F4FF"), Color3.fromHex("#FF5533")

function Scene:Update(r, time)
	for side, f in self.Fighters do
		Health.update(f, r.Hp[side], self.Viewing)
		if f.Broken or f.Finishing then
			continue
		end
		local previous = f.CrackStage or 0
		self.Shatter:SetCracks(f, r.Hp[side], f.Stats.MaxHP)
		if f.CrackStage > previous and r.Hp[side] > 0 then
			self:Sound(Audio.Heavy, f.Body, 1.4, Feel.CrackVolume, 0.18)
		end
		local frozen, shield, rage = r.Frozen[side], r.Shield[side], r.Rage[side]
		f.Bubble.Transparency = if shield then 0.42 else 1
		local glaze = (f.Effects.glaze or -1) > time
		local active = frozen or rage or r.Slam[side] or r.Pump[side] or glaze
		f.TintColor = f.TintColor or Color3.fromHex(f.Def.Tint)
		local tint = if glaze then WHITE elseif frozen then FROZEN elseif rage then RAGE else f.TintColor
		-- Highlights are a render pass each (and capped per client); only keep them on while visible.
		f.Highlight.Enabled = active == true
		if active then
			f.Highlight.FillColor, f.Highlight.OutlineColor = tint, tint
			f.Highlight.FillTransparency, f.Highlight.OutlineTransparency = 0.55, 0.15
		end
		f.Glints.Rate = if frozen then 14 elseif rage then 24 elseif f.Def.Passive == "glow_core" then 4 else 0
		if f.GlintTint ~= tint then
			f.GlintTint, f.Glints.Color = tint, ColorSequence.new(tint)
		end
		local dt = time - (f.LastPoseTime or time)
		local speed = if f.LastPosePosition and dt > 0 then (f.Body.Position - f.LastPosePosition).Magnitude / dt else 0
		f.LastPosePosition, f.LastPoseTime = f.Body.Position, time
		-- Fast-swing trails read from across the lobby, so bystanders get them too.
		f.Trail.Enabled = r.Pump[side] or speed >= Balance.CombatVFX.FastSwingSpeed
	end
	if self.Combat then
		self.Combat:Update(r, time)
	end
end

function Scene:Ray(side, id, missed, event)
	local f, foe = self.Fighters[side], self.Fighters[3 - side]
	local start = f.Body.Position
	local target = foe.Body.Position
	if missed then
		local facing = Vector3.new(event.Direction[1], event.Direction[2], event.Direction[3])
		target = start + self.Frame:VectorToWorldSpace(facing) * M.PowerLandDistance
	end
	local ray = part(
		self.Root,
		if missed then "MissedRay" else "PowerRay",
		if id == "freeze" then Color3.fromHex("#B3F4FF") else Color3.fromHex(f.Def.Tint)
	)
	ray.Size = Vector3.new(0.2, 0.2, (target - start).Magnitude)
	ray.CFrame = CFrame.lookAt((start + target) / 2, target)
	TweenService:Create(
		ray,
		TweenInfo.new(Feel.PowerEffectSeconds),
		{ Transparency = 1, Size = Vector3.new(0.01, 0.01, ray.Size.Z) }
	):Play()
	Debris:AddItem(ray, Feel.PowerEffectSeconds)
	if not missed then
		foe.Glints:Emit(18)
	end
end

function Scene:Event(e, hud)
	if self.Combat and self.Combat:Event(e) then
		AbilityNumbers.event(self, e, hud)
		return
	end
	local f = e.Side and self.Fighters[e.Side]
	if e.Type == "Power" then
		local def = f.Def
		if hud then
			hud:Edge(if e.Missed then Color3.fromHex("#C3CAD6") else Color3.fromHex(def.Tint))
			hud:Banner(
				e.Side,
				string.upper(def.SpecialName or Powers.special(e.Id).Name) .. (if e.Missed then " • MISSED!" else "!"),
				if e.Missed then Color3.fromHex("#C3CAD6") else Color3.fromHex(def.Tint)
			)
		end
		f.Effects[e.Id] = e.Time + (e.Seconds or Feel.PowerEffectSeconds)
		f.Glints:Emit(20)
		if e.Id == "beam" or e.Id == "freeze" then
			self:Ray(e.Side, e.Id, e.Missed, e)
		end
		if e.Id == "glaze" then
			f.Highlight.Enabled = true
			f.Highlight.FillColor = Color3.new(1, 1, 1)
			f.Highlight.FillTransparency = 0.2
			TweenService:Create(f.Highlight, TweenInfo.new(Feel.PowerEffectSeconds), { FillTransparency = 1 }):Play()
		end
		self:Sound(Audio.Whoosh, f.Body, if e.Id == "freeze" then 1.5 elseif e.Id == "rage" then 0.7 else 1.1, 0.3, 0.6)
	elseif e.Type == "Passive" then
		f.Glints:Emit(12)
		if hud then
			hud:Banner(
				e.Side,
				string.upper(f.Def.PassiveName or Powers.passive(e.Id).Name),
				Color3.fromHex(f.Def.Tint),
				true
			)
		end
	elseif e.Type == "PerfectRelease" and hud then
		hud:Banner(e.Side, "PERFECT RELEASE!", Color3.fromHex("#FFE45C"))
		f.Glints:Emit(18)
	elseif e.Type == "Whoosh" then
		if hud then
			hud:Popup(
				"WHOOSH",
				(self.Fighters[1].Body.Position + self.Fighters[2].Body.Position) / 2,
				Color3.fromHex("#E1E9FF")
			)
		end
		self:Sound(Audio.Whoosh, self.Fighters[1].Body, 1.2, 0.16, 0.3)
	elseif e.Type == "Hit" then
		local a, b = self.Fighters[1], self.Fighters[2]
		Health.bump(a)
		Health.bump(b)
		-- With a CombatFeel attached (every FightView), the tiered impact and layered sound come from there.
		if not self.Feel then
			self.Shatter:HitBurst(a, b, {
				CritA = e.Crit[1],
				CritB = e.Crit[2],
				Point = if e.Z then self.Frame:PointToWorldSpace(Vector3.new(e.X, e.Y, e.Z)) else nil,
			}, self.Root)
			local weight = math.clamp(e.Speed / Balance.Fight.RefSpeed, 0, 1)
			local volume = Feel.ClinkVolumeMin + (Feel.ClinkVolumeMax - Feel.ClinkVolumeMin) * weight
			self:Sound(
				if weight > 0.75 then Audio.Heavy else Audio.Clink,
				a.Body,
				a.Def.ClinkPitch * (1.12 - weight * 0.2),
				volume
			)
			self:Sound(Audio.ClinkAlt, b.Body, b.Def.ClinkPitch, volume * 0.45)
		end
		if hud then
			self.Shatter:Pulse()
		end
		if hud and (e.Crit[1] or e.Crit[2] or e.Speed >= Balance.Fight.RefSpeed * Feel.BigHitSpeed) then
			hud:Popup(
				if e.Crit[1] or e.Crit[2] then "CRIT!" else "SMASH!",
				(a.Body.Position + b.Body.Position) / 2 + Vector3.yAxis * 3.2, -- above the BLOCKED/damage lanes
				Color3.fromHex("#FFE45C"),
				0,
				"Impact"
			)
		end
		for side, fighter in self.Fighters do
			if hud then
				local tint, scale = AbilityNumbers.clash(self, e, side)
				hud:Popup(
					if e.Blocked[side] then "BLOCKED" else "−" .. math.floor(e.Damage[side] + 0.5),
					fighter.Body.Position,
					tint,
					if side == 1 then -1 else 1,
					"Damage" .. side,
					scale
				)
			end
		end
	elseif e.Type == "Shatter" and not f.Broken then
		self.Shatter:Break(f, self.Root)
		f.Broken = true
		self:EndRoundEffects()
		f.Health.Enabled = false
		f.Bubble.Transparency, f.Glints.Enabled, f.Trail.Enabled = 1, false, false
		f.Highlight.Enabled = false
		if f.Tag then
			f.Tag.Enabled = false
		end
		if hud then
			hud:Phase("RoundEnd", "")
		end
	elseif e.Type == "Overtime" and hud then
		hud:Phase("Fighting", "OVERTIME • HITS GET STRONGER!")
		hud.Gui:SetAttribute("Overtime", true) -- MusicController crossfades to the Overtime bed
	end
end

function Scene:Heart(side)
	local anchor = part(self.Root, "GlassHeartPop", Color3.fromHex(self.Fighters[side].Def.Tint))
	anchor.Size, anchor.Transparency = Vector3.one * 0.2, 1
	anchor.Position = (self.HeartPositions and self.HeartPositions[side] or self.Fighters[side].Body.Position)
		+ Vector3.yAxis * 5
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(70, 70)
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text, text.TextColor3, text.TextScaled = "♥", anchor.Color, true
	text.Parent = gui
	emitter(anchor, anchor.Color):Emit(14)
	self:Sound(Audio.Tinkle, anchor, 1.6, 0.35)
	TweenService:Create(text, TweenInfo.new(0.6), { Rotation = 25, TextTransparency = 1 }):Play()
	TweenService:Create(anchor, TweenInfo.new(0.6), { Position = anchor.Position + Vector3.yAxis * 1.5 }):Play()
	Debris:AddItem(anchor, 1)
end

-- A small marker over the local player's glassy; mirror matches otherwise look identical.
function Scene:Tag(side, text, color)
	local f = self.Fighters[side]
	if not f or f.Broken then
		return
	end
	local gui = f.Tag or Instance.new("BillboardGui")
	gui.Name, gui.Adornee, gui.AlwaysOnTop, gui.LightInfluence = "OwnerTag", f.Body, true, 0
	gui.Size = UDim2.fromScale(Feel.OwnerTagSize, Feel.OwnerTagSize * 0.55)
	gui.StudsOffsetWorldSpace = Vector3.yAxis * (f.Body.Size.Y * 0.5 + Feel.OwnerTagHeight)
	local label = gui:FindFirstChild("Text") or Instance.new("TextLabel")
	label.Name, label.Size, label.BackgroundTransparency = "Text", UDim2.fromScale(1, 1), 1
	label.Text, label.TextScaled, label.TextColor3 = text .. "\n▼", true, color
	label.FontFace = Font.fromName("Montserrat", Enum.FontWeight.Heavy)
	label.TextStrokeTransparency, label.TextStrokeColor3 = 0.2, Color3.fromHex("#05071C")
	label.Parent = gui
	gui.Parent = self.Root
	f.Tag = gui
end

function Scene:GetStand()
	if self.Stand and self.Stand.Parent then
		return self.Stand
	end
	for _, stand in CollectionService:GetTagged("ArenaStand") do
		if stand:GetAttribute("ArenaId") == self.ArenaId then
			self.Stand = stand
			return stand
		end
	end
end

function Scene:Destroy()
	if self.Combat then
		self.Combat:Destroy()
	end
	if self.Finisher then
		self.Finisher:Destroy()
	end
	for _, f in self.Fighters do
		f.ShardTemplates:Destroy()
	end
	self.Root:Destroy()
end

function Scene:SetViewing(on)
	self.Viewing = on
	for _, f in self.Fighters do
		f.Health.Enabled = on and not f.Broken and not f.Finishing
	end
	if not on and self.Combat then
		self.Combat:ClearTransient()
	end
	if not on and self.Finisher then
		self.Finisher:Destroy()
	end
end

function Scene:StartFinisher(side, now)
	if not self.Finisher then
		self.Finisher = require(script.Parent.FightFinisher).new(self, side, now)
	end
end

return Scene
