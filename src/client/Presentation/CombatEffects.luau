-- Scene-owned signature presentation. Only server cast/contact facts create attack effects.
local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Balance = require(RS.Shared.Config.Balance)
local Audio = require(RS.Shared.Config.Audio)
local Visuals = require(RS.Shared.Config.CombatKitVisuals)
local Presentation = require(script.Parent.SignaturePresentation)
local Accent = require(script.Parent.SignatureAccent)
local Hero = require(script.Parent.HeroPowers)
local Impact = require(script.Parent.ImpactBeat)
local K, VFX, M = Balance.CombatRelease.Kits, Balance.CombatVFX, Balance.Motion
local Effects = {}
Effects.__index = Effects

local function vector(a)
	return Vector3.new(a[1], a[2], a[3])
end

local function anchor(parent, name, position)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position, p.Transparency = name, Vector3.one * 0.05, position, 1
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Parent = parent
	return p
end

function Effects.new(scene)
	local assets = if scene.Data.ReleasePrototype then RS.Assets.CombatReleasePreview.Combat else RS.Assets.VFX.Combat
	local root = Instance.new("Folder")
	root.Name, root.Parent = "Signatures", scene.Root
	local self = setmetatable(
		{ Scene = scene, Assets = assets, Root = root, Casts = {}, Seen = {}, Sounds = {}, Time = 0 },
		Effects
	)
	for side, f in scene.Fighters do
		f.Side = side
		f.DetailStates = {}
		for _, p in f.Parts do
			if p ~= f.Body then
				f.DetailStates[p] = {
					Size = p.Size,
					Center = p.CFrame.Position,
					Rotation = p.CFrame.Rotation,
					Transparency = p.Transparency,
				}
			end
		end
		local guard = assets.Meshes[if f.Id == "glass_duck" then "BubbleDome" else "GuardPlate"]:Clone()
		guard.Name, guard.Size = "LidGuard", guard.Size * M.GlassyScale
		guard.Material, guard.Color, guard.Transparency = Enum.Material.Glass, Color3.fromRGB(214, 171, 83), 1
		guard.Parent, f.SignatureGuard = root, guard
		Hero.init(self, f)
	end
	return self
end

function Effects:Sound(name, side)
	local sound = self.Scene:Sound(Audio[name], self.Scene.Fighters[side].Body)
	if sound then
		table.insert(self.Sounds, sound)
	end
end

function Effects:Mesh(name, parent, color)
	local p = self.Assets.Meshes[name]:Clone()
	p.Color, p.Parent = color, parent
	return p
end

function Effects:Burst(name, position, color, lowDetail)
	local p = anchor(self.Root, "Signature_" .. name, position)
	local e = self.Assets.Particles[name]:Clone()
	e.Color, e.Parent = ColorSequence.new(color), p
	local keys = {}
	for _, key in e.Size.Keypoints do
		table.insert(keys, NumberSequenceKeypoint.new(key.Time, key.Value * VFX.ChargeBurstScale, key.Envelope))
	end
	e.Size = NumberSequence.new(keys)
	e:Emit(math.max(1, math.floor(e:GetAttribute("BurstCount") * (if lowDetail then 0.5 else VFX.ChargeBurstScale))))
	Debris:AddItem(p, e.Lifetime.Max + VFX.Tail)
end

function Effects:ClearCast(id)
	local cast = self.Casts[id]
	if cast then
		cast.Root:Destroy()
		self.Casts[id] = nil
	end
end

function Effects:ClearTransient()
	for _, f in self.Scene.Fighters do
		for _, a in f.BrineAttachments or {} do
			a:Destroy()
		end
		f.Brine, f.BrineAttachments = nil, nil
	end
	for id in self.Casts do
		self:ClearCast(id)
	end
	for _, sound in self.Sounds do
		if sound.Parent then
			sound:Destroy()
		end
	end
	self.Sounds = {}
	for _, child in self.Root:GetChildren() do
		if child.Name ~= "LidGuard" then
			child:Destroy()
		end
	end
end

function Effects:CancelSide(side)
	for id, cast in self.Casts do
		if cast.Side == side then
			self:ClearCast(id)
		end
	end
	self.Scene.Fighters[side].SignatureGuard.Transparency = 1
end

function Effects:Cast(e)
	local id = e.CastId or (e.Type .. ":" .. e.Side .. ":" .. e.Time)
	self:ClearCast(id)
	local root = Instance.new("Folder")
	root.Name, root.Parent = "Cast_" .. id, self.Root
	root:SetAttribute("CastId", id)
	root:SetAttribute("ServerTime", e.Time)
	local cast = {
		Root = root,
		Side = e.Side,
		Time = e.Time,
		EndAt = e.Time + (e.Duration or e.Windup or 0) + VFX.Tail,
		Event = e,
	}
	self.Casts[id] = cast
	return cast
end

function Effects:Event(e)
	if e.Type == "Shatter" then
		self:ClearTransient()
		self:CancelSide(e.Side)
		return false
	end
	if
		not table.find({
			"Charge",
			"CastStart",
			"CastRelease",
			"CastContact",
			"SignatureContact",
			"SignatureBlock",
			"SignatureStatus",
		}, e.Type)
	then
		return false
	end
	local f = self.Scene.Fighters[e.Side]
	if not f or f.Broken or f.Finishing then
		return true
	end
	local key = if e.CastId then e.Type .. ":" .. e.CastId else e.Type .. ":" .. e.Side .. ":" .. e.Time
	key ..= ":" .. tostring(e.Pulse or e.Kind or "")
	if self.Seen[key] then
		return true
	end
	self.Seen[key] = true
	local color = Presentation.color(f)
	local origin = if e.Origin then self.Scene.Frame:PointToWorldSpace(vector(e.Origin)) else f.Body.Position
	if e.Type == "SignatureStatus" then
		if e.Kind == "Echo" then
			f.EchoPoint, f.EchoUntil = self.Scene.Frame:PointToWorldSpace(vector(e.Point)), e.Time + e.Seconds
		end
		self:Burst(if e.Kind == "Heal" then "Frost" else "ContactGlint", origin, color, f.LowDetail)
		self:Sound(Visuals[f.Id].ReleaseSound, e.Side)
	elseif e.Type == "Charge" then
		self:Burst("ContactGlint", f.Body.Position, color, f.LowDetail)
		self:Sound(if f.Id == "arc_coil" then "CapRattle" else "ClinkLightB", e.Side)
	elseif e.Type == "CastStart" then
		if self.Time > e.Time + e.Windup + VFX.Tail then
			return true
		end
		local cast = self:Cast(e)
		cast.Ring = self:Mesh("Ring", cast.Root, color)
		cast.Ring.Size *= VFX.ChargeRingScale
		Accent.create(self, cast, "windup", color)
		Hero.start(self, cast, e, color)
		self:Burst("ContactGlint", f.Body.Position, color, f.LowDetail)
		self:Sound(if e.Shape == "sweep" then "CapRattle" else "ChargeGlass", e.Side)
	elseif e.Type == "CastRelease" then
		local readable = if e.Shape == "ray" then VFX.RayReadSeconds else e.Duration
		if self.Time > e.Time + readable + VFX.Tail then
			return true
		end
		if e.Shape == "guard" then
			f.GuardConsumed, f.GuardUntil = false, e.Time + e.Duration
			f.GuardAt = e.Time
			self:ClearCast(e.CastId)
			self:Sound("LidClick", e.Side)
			self:Burst("ContactGlint", f.Body.Position, Color3.fromRGB(214, 171, 83), f.LowDetail)
			return true
		end
		local cast = self:Cast(e)
		cast.Origin = origin
		cast.Direction = if e.Direction
			then self.Scene.Frame:VectorToWorldSpace(vector(e.Direction)).Unit
			else self.Scene.Frame.RightVector
		Hero.start(self, cast, e, color)
		Accent.create(self, cast, "release", color)
		self:Burst("ContactGlint", origin, color, f.LowDetail)
		if Presentation.release(self, cast, e, color) then
			self:Sound(Visuals[f.Id].ReleaseSound, e.Side)
		elseif e.Shape == "ray" then
			cast.EndAt = e.Time + VFX.RayReadSeconds + VFX.Tail
			local a = anchor(cast.Root, "RayOrigin", origin)
			local b = anchor(cast.Root, "LockedRayEnd", origin + cast.Direction * e.Range)
			local at0, at1 = Instance.new("Attachment"), Instance.new("Attachment")
			at0.Parent, at1.Parent = a, b
			local beam = self.Assets.Beams[if f.Id == "arc_coil" then "ArcBolt" else "RayCore"]:Clone()
			beam.Attachment0, beam.Attachment1, beam.Enabled = at0, at1, true
			beam.Color, beam.Width0, beam.Width1 = ColorSequence.new(color), e.Radius * 2, e.Radius
			beam.Transparency = NumberSequence.new(0)
			if f.Id == "prism" then
				beam.Texture = ""
				beam.Color = ColorSequence.new(Color3.new(1, 1, 1))
			end
			beam.Parent, cast.Beam, cast.Endpoint = cast.Root, beam, b
			if not f.LowDetail then
				local halo = beam:Clone()
				halo.Name, halo.Width0, halo.Width1 =
					"RayHalo", beam.Width0 * VFX.RayHaloScale, beam.Width1 * VFX.RayHaloScale
				halo.Transparency = NumberSequence.new(VFX.RayHaloTransparency)
				halo.Color = ColorSequence.new(color)
				halo.Parent, cast.Halo = cast.Root, halo
			end
			Hero.ray(self, cast, color)
			self:Sound(if f.Id == "arc_coil" then "ElectricSnap" else "ClinkLightA", e.Side)
		elseif e.Shape == "sweep" then
			cast.EndAt = e.Time + e.Duration + VFX.WeaponReadTail + VFX.Tail
			Hero.weapon(self, cast, color)
			self:Sound("AxeAir", e.Side)
		end
	elseif e.Type == "CastContact" then
		local cast = self.Casts[e.CastId]
		Presentation.contact(cast, e)
		if e.Missed then
			if cast then
				cast.Root:SetAttribute("Missed", true)
			end
			return true
		end
		local point = if e.Point
			then self.Scene.Frame:PointToWorldSpace(vector(e.Point))
			else self.Scene.Fighters[e.Target].Body.Position
		if cast and cast.Endpoint then
			cast.Endpoint.Position = point
		end
		local accentEvent = table.clone(e)
		accentEvent.CastId = "Impact:" .. e.CastId .. ":" .. (e.Pulse or 1)
		accentEvent.Duration = VFX.AccentSeconds
		local impact = self:Cast(accentEvent)
		impact.Origin = point
		Impact.emit(impact.Root, self.Assets, point, color, true, f.LowDetail)
		self:Sound(if e.Blocked then "LidBlock" else Visuals[f.Id].ContactSound, e.Side)
	elseif e.Type == "SignatureContact" or e.Type == "SignatureBlock" then
		local cast = self:Cast(e)
		cast.EndAt = e.Time + VFX.Tail
		cast.Origin = if e.Point then self.Scene.Frame:PointToWorldSpace(vector(e.Point)) else origin
		cast.Ring =
			self:Mesh("Ring", cast.Root, if e.Type == "SignatureBlock" then Color3.fromRGB(214, 171, 83) else color)
		cast.Pressure = true
		cast.EndAt = e.Time + VFX.AccentSeconds + VFX.Tail
		Accent.create(self, cast, "impact", cast.Ring.Color)
		Hero.start(self, cast, e, color)
		self:Sound(
			if e.Type == "SignatureBlock" then "LidBlock" elseif f.Id == "pop" then "BubblePop" else "ClinkLightA",
			e.Side
		)
		if e.Type == "SignatureBlock" then
			f.GuardConsumed, f.GuardUntil = true, -1
			f.GuardHitAt = e.Time
			Impact.emit(cast.Root, self.Assets, cast.Origin, cast.Ring.Color, true, f.LowDetail)
		end
		self:Burst("ContactGlint", cast.Origin, cast.Ring.Color, f.LowDetail)
		if e.Type == "SignatureContact" and f.Id == "briar_flask" then
			self:Burst("GlassChips", cast.Origin, color, f.LowDetail)
		end
		if f.Id == "pop" and not f.LowDetail then
			self:Burst("PressurePop", cast.Origin, color, false)
		end
	end
	return true
end

function Effects:Update(r, time)
	self.Time = time
	for side, f in self.Scene.Fighters do
		local kit = K[f.Id]
		if not kit or f.Broken or f.Finishing then
			f.SignatureGuard.Transparency = 1
			Hero.guard(self, f, false)
			continue
		end
		if
			self.Scene.Viewing
			and r.Hp[side] / f.Stats.MaxHP <= VFX.LowHealthFraction
			and time >= (f.NextStress or 0)
		then
			f.NextStress = time + VFX.StressInterval
			self:Burst("GlassDust", f.Body.Position, Color3.fromHex(f.Def.Tint), true)
		end
		local count = math.floor((r.Power[side] or 0) * (kit.Every or 3) + 0.01)
		for p, rest in f.DetailStates do
			local name = p:GetAttribute("SourceName") or p.Name
			local index = tonumber(name:match("_(%d+)")) or 1
			if name:find("ChargeBubble") or name:find("CoilSegment") then
				local active = count >= index
				p.Transparency = if active then VFX.ChargeLit else VFX.ChargeDim
				p.Material = if active then Enum.Material.Neon else Enum.Material.Glass
			elseif name:find("Thorn_") then
				local growth = if count >= index then 1 else 0.15
				local base = (p:GetAttribute("AnimationPivot") or Vector3.zero) * M.GlassyScale
				p.Size = rest.Size * growth
				p.CFrame = f.Pivot * CFrame.new(base + (rest.Center - base) * growth) * rest.Rotation
				p.Transparency = if count >= index then VFX.ChargeLit else VFX.ChargeDim
			elseif name == "RayLens" then
				p.Material = if r.Power[side] > 0.7 then Enum.Material.Neon else Enum.Material.Glass
			elseif name:match("^Cap") and f.Id == "pop" then
				p.CFrame = f.Pivot
					* CFrame.new(rest.Center + Vector3.yAxis * (if count == 2 then math.sin(time * 30) * 0.035 else 0))
					* rest.Rotation
			end
		end
		local guard = kit.Shape == "guard"
			and not f.GuardConsumed
			and math.max((r.Effect[side] and r.Effect[side][1]) or 0, (f.GuardUntil or -1) - time) > 0
		f.SignatureGuard.Transparency = if guard then VFX.GuardTransparency else 1
		if guard then
			local foe = self.Scene.Fighters[3 - side]
			local delta = foe.Body.Position - f.Body.Position
			local dir = if delta.Magnitude > 0.001 then delta.Unit else self.Scene.Frame.RightVector
			local towardCamera = workspace.CurrentCamera.CFrame.ZVector
			local point = f.Body.Position + dir * math.max(f.Body.Size.X, f.Body.Size.Z) * 0.5
			f.SignatureGuard.CFrame = CFrame.lookAt(point, point + dir + towardCamera * VFX.GuardCameraBias)
		end
		Hero.guard(self, f, guard)
		Hero.details(self, f)
	end
	for id, cast in self.Casts do
		if time > cast.EndAt then
			self:ClearCast(id)
			continue
		end
		local e, f = cast.Event, self.Scene.Fighters[cast.Side]
		if
			e.Shape == "boost"
			and time > e.Time + VFX.Tail
			and ((r.Effect[cast.Side] and r.Effect[cast.Side][3]) or 0) <= 0
		then
			self:ClearCast(id)
			continue
		end
		if f.Broken or f.Finishing then
			self:ClearCast(id)
			continue
		end
		local age = math.max(0, time - cast.Time)
		local alpha = math.clamp((time - (cast.EndAt - VFX.Tail)) / VFX.Tail, 0, 1)
		Presentation.step(self, cast, age, alpha)
		Accent.step(self, cast, age)
		Hero.step(self, cast, age, alpha)
		if cast.Ring then
			local position = cast.Origin or f.Body.Position
			cast.Ring.CFrame = CFrame.new(position) * workspace.CurrentCamera.CFrame.Rotation
			cast.Ring.Transparency = 0.2 + alpha * 0.8
			if cast.Pressure then
				local progress = math.clamp(age / VFX.AccentSeconds, 0, 1)
				cast.Ring.Size = self.Assets.Meshes.Ring.Size * (1 + progress) * VFX.PressureRingScale
				cast.Ring.Transparency = progress
			else
				local progress = math.clamp(age / e.Windup, 0, 1)
				local pulse = (1 + math.sin(age * math.pi * 2 * VFX.WindupPulseHz)) / 2
				cast.Ring.Size = self.Assets.Meshes.Ring.Size
					* VFX.ChargeRingScale
					* (1 + progress * VFX.WindupRingGrowth)
				cast.Ring.Transparency = VFX.ChargeDim - pulse * (VFX.ChargeDim - VFX.ChargeLit)
			end
		end
		if cast.Beam then
			cast.Beam.Transparency = NumberSequence.new(alpha)
			if cast.Halo then
				cast.Halo.Transparency =
					NumberSequence.new(VFX.RayHaloTransparency + alpha * (1 - VFX.RayHaloTransparency))
			end
		end
	end
	Presentation.status(self, r, time)
	for i = #self.Sounds, 1, -1 do
		if not self.Sounds[i].Parent then
			table.remove(self.Sounds, i)
		end
	end
end

function Effects:Destroy()
	self:ClearTransient()
	self.Root:Destroy()
end

return Effects
