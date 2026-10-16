-- Scene-owned signature presentation. Only server cast/contact facts create attack effects.
local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Balance = require(RS.Shared.Config.Balance)
local Audio = require(RS.Shared.Config.Audio)
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
	for _, f in scene.Fighters do
		f.DetailStates = {}
		for _, p in f.Parts do
			if p ~= f.Body then
				f.DetailStates[p] = { Size = p.Size, Center = p.CFrame.Position, Rotation = p.CFrame.Rotation }
			end
		end
		local guard = assets.Meshes.GuardPlate:Clone()
		guard.Name, guard.Size = "LidGuard", guard.Size * M.GlassyScale
		guard.Material, guard.Color, guard.Transparency = Enum.Material.Glass, Color3.fromRGB(214, 171, 83), 1
		guard.Parent, f.SignatureGuard = root, guard
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
	self:ClearCast(e.CastId)
	local root = Instance.new("Folder")
	root.Name, root.Parent = "Cast_" .. e.CastId, self.Root
	root:SetAttribute("CastId", e.CastId)
	root:SetAttribute("ServerTime", e.Time)
	local cast = {
		Root = root,
		Side = e.Side,
		Time = e.Time,
		EndAt = e.Time + (e.Duration or e.Windup or 0) + VFX.Tail,
		Event = e,
	}
	self.Casts[e.CastId] = cast
	return cast
end

function Effects:Event(e)
	if e.Type == "Shatter" then
		self:ClearTransient()
		self:CancelSide(e.Side)
		return false
	end
	if
		not table.find(
			{ "Charge", "CastStart", "CastRelease", "CastContact", "SignatureContact", "SignatureBlock" },
			e.Type
		)
	then
		return false
	end
	local f = self.Scene.Fighters[e.Side]
	if not f or f.Broken or f.Finishing then
		return true
	end
	local key = if e.CastId then e.Type .. ":" .. e.CastId else e.Type .. ":" .. e.Side .. ":" .. e.Time
	if self.Seen[key] then
		return true
	end
	self.Seen[key] = true
	local color = Color3.fromHex(f.Def.Tint)
	local origin = if e.Origin then self.Scene.Frame:PointToWorldSpace(vector(e.Origin)) else f.Body.Position
	if e.Type == "Charge" then
		self:Burst("ContactGlint", f.Body.Position, color, f.LowDetail)
		self:Sound(if f.Id == "arc_coil" then "CapRattle" else "ClinkLightB", e.Side)
	elseif e.Type == "CastStart" then
		if self.Time > e.Time + e.Windup + VFX.Tail then
			return true
		end
		local cast = self:Cast(e)
		cast.Ring = self:Mesh("Ring", cast.Root, color)
		cast.Ring.Size *= VFX.ChargeRingScale
		self:Burst("ContactGlint", f.Body.Position, color, f.LowDetail)
		self:Sound(if e.Shape == "sweep" then "CapRattle" else "ChargeGlass", e.Side)
	elseif e.Type == "CastRelease" then
		if self.Time > e.Time + e.Duration + VFX.Tail then
			return true
		end
		if e.Shape == "guard" then
			f.GuardConsumed, f.GuardUntil = false, e.Time + e.Duration
			self:ClearCast(e.CastId)
			self:Sound("LidClick", e.Side)
			self:Burst("ContactGlint", f.Body.Position, Color3.fromRGB(214, 171, 83), f.LowDetail)
			return true
		end
		local cast = self:Cast(e)
		cast.Origin = origin
		cast.Direction = self.Scene.Frame:VectorToWorldSpace(vector(e.Direction)).Unit
		self:Burst("ContactGlint", origin, color, f.LowDetail)
		if e.Shape == "ray" then
			local a = anchor(cast.Root, "RayOrigin", origin)
			local b = anchor(cast.Root, "LockedRayEnd", origin + cast.Direction * e.Range)
			local at0, at1 = Instance.new("Attachment"), Instance.new("Attachment")
			at0.Parent, at1.Parent = a, b
			local beam = self.Assets.Beams[if f.Id == "arc_coil" then "ArcBolt" else "RayCore"]:Clone()
			beam.Attachment0, beam.Attachment1, beam.Enabled = at0, at1, true
			beam.Color, beam.Width0, beam.Width1 = ColorSequence.new(color), e.Radius * 2, e.Radius
			beam.Parent, cast.Beam, cast.Endpoint = cast.Root, beam, b
			if not f.LowDetail then
				local halo = beam:Clone()
				halo.Name, halo.Width0, halo.Width1 =
					"RayHalo", beam.Width0 * VFX.RayHaloScale, beam.Width1 * VFX.RayHaloScale
				halo.Transparency = NumberSequence.new(VFX.RayHaloTransparency)
				halo.Parent, cast.Halo = cast.Root, halo
			end
			self:Sound(if f.Id == "arc_coil" then "ElectricSnap" else "ClinkLightA", e.Side)
		elseif e.Shape == "sweep" then
			local weapon = self.Assets.Kits.crescent_axe.CrescentWeapon:Clone()
			weapon:ScaleTo(M.GlassyScale)
			cast.Weapon, cast.HeadCenter = weapon, weapon.AxeHead.Position
			weapon.Parent = cast.Root
			local up = Vector3.yAxis - cast.Direction * cast.Direction.Y
			cast.Up = if up.Magnitude > 0.0001 then up.Unit else self.Scene.Frame.ZVector
			cast.Slash = self:Mesh("CurvedSlash", cast.Root, color)
			self:Sound("AxeAir", e.Side)
		end
	elseif e.Type == "CastContact" then
		local cast = self.Casts[e.CastId]
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
		self:Burst("ContactGlint", point, color, f.LowDetail)
		if not e.Blocked then
			self:Burst("GlassChips", point, color, f.LowDetail)
		end
		self:Sound(if e.Blocked then "LidBlock" else "ClinkLightA", e.Side)
	elseif e.Type == "SignatureContact" or e.Type == "SignatureBlock" then
		local cast = self:Cast(e)
		cast.EndAt = e.Time + VFX.Tail
		cast.Origin = if e.Point then self.Scene.Frame:PointToWorldSpace(vector(e.Point)) else origin
		cast.Ring =
			self:Mesh("Ring", cast.Root, if e.Type == "SignatureBlock" then Color3.fromRGB(214, 171, 83) else color)
		cast.Pressure = true
		self:Sound(
			if e.Type == "SignatureBlock" then "LidBlock" elseif f.Id == "pop" then "BubblePop" else "ClinkLightA",
			e.Side
		)
		if e.Type == "SignatureBlock" then
			f.GuardConsumed, f.GuardUntil = true, -1
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
			continue
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
		local guard = not f.GuardConsumed
			and math.max((r.Effect[side] and r.Effect[side][1]) or 0, (f.GuardUntil or -1) - time) > 0
		f.SignatureGuard.Transparency = if guard then VFX.GuardTransparency else 1
		if guard then
			local foe = self.Scene.Fighters[3 - side]
			local delta = foe.Body.Position - f.Body.Position
			local dir = if delta.Magnitude > 0.001 then delta.Unit else self.Scene.Frame.RightVector
			local towardCamera = self.Scene.Frame.ZVector * (self.Scene.Data.CameraFacing or 1)
			local point = f.Body.Position + dir * math.max(f.Body.Size.X, f.Body.Size.Z) * 0.5
			f.SignatureGuard.CFrame = CFrame.lookAt(point, point + dir + towardCamera * VFX.GuardCameraBias)
		end
	end
	for id, cast in self.Casts do
		if time > cast.EndAt then
			self:ClearCast(id)
			continue
		end
		local e, f = cast.Event, self.Scene.Fighters[cast.Side]
		if f.Broken or f.Finishing then
			self:ClearCast(id)
			continue
		end
		local age = math.max(0, time - cast.Time)
		local alpha = math.clamp((time - (cast.EndAt - VFX.Tail)) / VFX.Tail, 0, 1)
		if cast.Ring then
			local position = cast.Origin or f.Body.Position
			cast.Ring.CFrame = CFrame.new(position) * workspace.CurrentCamera.CFrame.Rotation
			cast.Ring.Transparency = 0.2 + alpha * 0.8
			if cast.Pressure then
				cast.Ring.Size = self.Assets.Meshes.Ring.Size * (1 + age / VFX.Tail) * VFX.PressureRingScale
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
		if cast.Weapon then
			local angle = (-0.5 + math.clamp(age / e.Duration, 0, 1)) * e.Arc
			local outward = cast.Direction * math.cos(angle) + cast.Up * math.sin(angle)
			local head = cast.Origin + outward * e.Range
			local up = cast.Up * math.cos(angle) - cast.Direction * math.sin(angle)
			local rotation = CFrame.fromMatrix(outward, up, outward:Cross(up).Unit)
			cast.Weapon:PivotTo(CFrame.new(head) * rotation * CFrame.new(-cast.HeadCenter))
			cast.Slash.CFrame = CFrame.new(head) * rotation
			cast.Slash.Transparency = VFX.ChargeLit + alpha * (1 - VFX.ChargeLit)
			for _, part in cast.Weapon:GetChildren() do
				part.Transparency = 0.1 + alpha * 0.9
			end
		end
	end
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
