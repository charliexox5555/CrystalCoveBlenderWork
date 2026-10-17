-- Physical hero props and motion stay cosmetic; server facts own their timing and outcomes.
local B = require(game.ReplicatedStorage.Shared.Config.Balance)
local VFX, M = B.CombatVFX, B.Motion
local Hero = {}
local function size(p, diameter)
	p.Size *= diameter / math.max(p.Size.X, p.Size.Y, p.Size.Z)
end
local function upFor(direction)
	local up = Vector3.yAxis - direction * direction.Y
	return if up.Magnitude > 0.001 then up.Unit else Vector3.zAxis
end
function Hero.weapon(self, cast, color)
	local weapon = self.Assets.Kits.crescent_axe.CrescentWeapon:Clone()
	weapon:ScaleTo(M.GlassyScale)
	cast.Weapon, cast.HeadCenter = weapon, weapon:GetPivot():PointToObjectSpace(weapon.AxeHead.Position)
	weapon.Parent = cast.Root
	weapon.AxeHead.Color = Color3.fromHex(VFX.WeaponHeadColor)
	weapon.AxeHandle.Color = Color3.fromHex(VFX.WeaponHandleColor)
	cast.Up = upFor(cast.Direction)
	local outline = Instance.new("Highlight")
	outline.Adornee, outline.FillTransparency, outline.OutlineTransparency = weapon, 1, 0.1
	outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	outline.OutlineColor, outline.Parent = Color3.fromHex("#304477"), weapon
	outline.Enabled = not self.Scene.Fighters[cast.Side].LowDetail
	cast.Slash = self:Mesh("CurvedSlash", cast.Root, color)
	cast.Slash.Size *= M.GlassyScale
	cast.Slash.Material = Enum.Material.Neon
	local a, b = Instance.new("Attachment"), Instance.new("Attachment")
	a.Position, b.Position = Vector3.xAxis * weapon.AxeHead.Size.X / 2, -Vector3.xAxis * weapon.AxeHead.Size.X / 2
	a.Parent, b.Parent = weapon.AxeHead, weapon.AxeHead
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1, trail.Color = a, b, ColorSequence.new(color)
	trail.Transparency, trail.Lifetime, trail.LightEmission = NumberSequence.new(0.25, 1), VFX.WeaponTrailSeconds, 1
	trail.Parent = weapon.AxeHead
end
function Hero.init(self, f)
	if f.Id ~= "jam" then
		return
	end
	local lid = Instance.new("Model")
	lid.Name, lid.WorldPivot, lid.Parent = "HeroLid", CFrame.identity, self.Root
	f.HeroLid, f.LidParts = lid, {}
	for p, rest in f.DetailStates do
		if p.Name:find("Cap") or p.Name:find("LidRidge") then
			local copy = p:Clone()
			copy.Transparency, copy.Parent = 1, lid
			table.insert(f.LidParts, { Mesh = copy, Original = p, Rest = rest })
			if p.Name:find("Cap") then
				f.LidCenter = rest.Center
			end
		end
	end
	local outline = Instance.new("Highlight")
	outline.Adornee, outline.FillTransparency, outline.OutlineTransparency = lid, 1, 0.1
	outline.OutlineColor, outline.Parent = Color3.fromHex("#78532E"), lid
	outline.Enabled = false
	f.HeroLidOutline = outline
end
function Hero.ray(self, cast, color)
	local f = self.Scene.Fighters[cast.Side]
	f.RayAt = cast.Time
	if f.Id == "prism" then
		f.RayAim, f.RayAimUntil = cast.Direction, cast.Time + VFX.RayReadSeconds
	end
	cast.RayRings = {}
	for i = 1, (if f.LowDetail then 1 else VFX.RayRingCount) do
		local tint = if f.Id == "prism" then Color3.fromHSV((i - 1) / VFX.RayRingCount, 0.7, 1) else color
		local p = self:Mesh("Ring", cast.Root, tint)
		p.Name, p.Material = "RayRefraction", Enum.Material.Neon
		size(p, VFX.RayRingSize)
		table.insert(cast.RayRings, p)
	end
end
function Hero.guard(self, f, active)
	if f.Id ~= "jam" or not f.HeroLid or not f.HeroLid.Parent then
		return
	end
	f.HeroLidOutline.Enabled = active and not f.LowDetail and not f.Broken and not f.Finishing
	for _, entry in f.LidParts do
		entry.Mesh.Transparency = if active then 0.08 else 1
		if not f.Broken and not f.Finishing then
			entry.Original.Transparency = if active then 1 else entry.Rest.Transparency
		end
	end
	if not active then
		f.GuardAt = nil
		return
	end
	f.SignatureGuard.Transparency = 1
	local delta = self.Scene.Fighters[3 - f.Side].Body.Position - f.Body.Position
	local dir = if delta.Magnitude > 0.001 then delta.Unit else self.Scene.Frame.RightVector
	local normal = (workspace.CurrentCamera.CFrame.ZVector + dir * VFX.ShieldFacingBias).Unit
	local position = f.Body.Position + dir * math.max(f.Body.Size.X, f.Body.Size.Z) * VFX.ShieldStandOff
	f.GuardAt = f.GuardAt or self.Time
	local reveal = math.clamp((self.Time - f.GuardAt) / VFX.ShieldRevealSeconds, 0, 1)
	local top = (f.Pivot or CFrame.new(f.Body.Position)):PointToWorldSpace(f.LidCenter)
	position = top:Lerp(position, 1 - (1 - reveal) ^ 3)
	f.HeroLid:PivotTo(
		CFrame.lookAt(position, position + normal) * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.new(-f.LidCenter)
	)
end
function Hero.start(self, cast, e, color)
	local f = self.Scene.Fighters[e.Side]
	if f.Id == "prism" and e.Type == "CastStart" then
		f.RayAim = if e.Direction
			then self.Scene.Frame:VectorToWorldSpace(Vector3.new(table.unpack(e.Direction))).Unit
			else self.Scene.Frame.RightVector * (if e.Side == 1 then 1 else -1)
		f.RayAimUntil = e.Time + e.Windup
	elseif f.Id == "crescent_axe" and e.Type == "CastStart" then
		cast.Winding = true
		cast.Direction = if e.Direction
			then self.Scene.Frame:VectorToWorldSpace(Vector3.new(table.unpack(e.Direction))).Unit
			else self.Scene.Frame.RightVector * (if cast.Side == 1 then 1 else -1)
		Hero.weapon(self, cast, color)
	elseif f.Id == "hourglass" then
		if e.Type == "CastStart" then
			f.HealSpinAt, f.HealSpinSeconds = e.Time, e.Windup
		end
		cast.Clock = {}
		for i = 1, (if f.LowDetail then 4 else VFX.ClockTicks) do
			local p = self:Mesh("CrystalChip", cast.Root, Color3.fromHex(VFX.HealColor))
			p.Name, p.Material = "ClockTick", Enum.Material.Neon
			size(p, 0.22)
			table.insert(cast.Clock, p)
		end
		cast.ClockRing = self:Mesh("Ring", cast.Root, Color3.fromHex(VFX.HealColor))
		cast.ClockRing.Name, cast.ClockRing.Material = "HealClock", Enum.Material.Neon
		size(cast.ClockRing, VFX.ClockSize)
		cast.ClockSize = cast.ClockRing.Size
		cast.ClockRelease = e.Type == "CastRelease"
	elseif e.Type == "SignatureContact" and f.Id == "pop" then
		f.PopAt, f.PopCapUntil = e.Time, e.Time + VFX.HeroRecoilSeconds
		cast.Caps = {}
		for p in f.DetailStates do
			if p.Name:match("^Cap") then
				local copy = p:Clone()
				copy.Name, copy.Parent = "PoppedCap", cast.Root
				table.insert(cast.Caps, { Mesh = copy, Base = p.CFrame })
			end
		end
		cast.Waves = { self:Mesh("Ring", cast.Root, color), self:Mesh("BubbleDome", cast.Root, color) }
		cast.EndAt = e.Time + VFX.HeroRecoilSeconds + VFX.Tail
	end
end
function Hero.step(self, cast, age, alpha)
	local e, f = cast.Event, self.Scene.Fighters[cast.Side]
	for i, p in cast.RayRings or {} do
		local t = i / (#cast.RayRings + 1)
		local point = cast.Origin:Lerp(cast.Endpoint.Position, t)
		p.CFrame = CFrame.lookAt(point, point + cast.Direction + workspace.CurrentCamera.CFrame.ZVector * 0.35)
			* CFrame.Angles(0, 0, age * 3 + i)
		p.Transparency = 0.15 + alpha * 0.85
	end
	if cast.Weapon then
		local progress = math.clamp(age / (if cast.Winding then e.Windup else e.Duration), 0, 1)
		local arc = if cast.Winding then B.CombatRelease.Kits.crescent_axe.Arc else e.Arc
		local angle = if cast.Winding then -0.5 * arc - progress * 0.25 else (-0.5 + progress) * arc
		local direction = cast.Direction
		local outward = direction * math.cos(angle) + cast.Up * math.sin(angle)
		local up = cast.Up * math.cos(angle) - direction * math.sin(angle)
		local origin = if cast.Winding then f.Body.Position else cast.Origin
		local reach = if cast.Winding then VFX.WeaponWindupRange else e.Range
		local head = origin + outward * reach
		-- Position is a separate argument; all three following arguments are basis vectors.
		local rotation = CFrame.fromMatrix(Vector3.zero, outward, up, outward:Cross(up).Unit)
		cast.Weapon:PivotTo(CFrame.new(head) * rotation * CFrame.new(-cast.HeadCenter))
		cast.Slash.CFrame = CFrame.new(head) * workspace.CurrentCamera.CFrame.Rotation * CFrame.Angles(0, 0, angle)
		cast.Slash.Transparency = if cast.Winding then 1 else 0.2 + alpha * 0.8
		for _, p in cast.Weapon:GetChildren() do
			if p:IsA("BasePart") then
				p.Transparency = 0.08 + alpha * 0.92
			end
		end
	end
	if cast.Clock then
		local progress = math.clamp(age / (if cast.ClockRelease then e.Duration else e.Windup), 0, 1)
		local basis = CFrame.new(f.Body.Position) * workspace.CurrentCamera.CFrame.Rotation
		local radius = VFX.ClockSize / 2 * (if cast.ClockRelease then 1 + progress * 0.4 else 1)
		for i, p in cast.Clock do
			local angle = i / #cast.Clock * math.pi * 2 + progress * math.pi * 2
			p.CFrame = basis
				* CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
				* CFrame.Angles(0, 0, angle)
			p.Transparency = if cast.ClockRelease then progress else 0.12
		end
		cast.ClockRing.CFrame = basis
		cast.ClockRing.Size = cast.ClockSize * (if cast.ClockRelease then 1 + progress * 0.4 else 1)
		cast.ClockRing.Transparency = if cast.ClockRelease then progress else 0.25
	end
	for _, entry in cast.Caps or {} do
		local progress = math.clamp(age / VFX.HeroRecoilSeconds, 0, 1)
		entry.Mesh.CFrame = entry.Base
			* CFrame.new(0, math.sin(progress * math.pi) * VFX.PopCapLift, 0)
			* CFrame.Angles(0, progress * math.pi * 2, 0)
		entry.Mesh.Transparency = if progress > 0.8 then (progress - 0.8) / 0.2 else 0.1
	end
	for i, p in cast.Waves or {} do
		local progress = math.clamp(age / VFX.HeroRecoilSeconds, 0, 1)
		local spread = 1 - (1 - progress) ^ 3
		local diameter = 0.3 + VFX.PopWaveSize * spread
		p.Size = self.Assets.Meshes[if i == 1 then "Ring" else "BubbleDome"].Size * diameter / 2
		p.Material, p.CFrame = Enum.Material.Neon, CFrame.new(cast.Origin) * workspace.CurrentCamera.CFrame.Rotation
		p.Transparency = (if i == 1 then 0.15 else 0.8) + progress * (if i == 1 then 0.85 else 0.2)
	end
end
function Hero.details(self, f)
	if f.Id == "pop" then
		for p, rest in f.DetailStates do
			if p.Name:match("^Cap") then
				p.Transparency = if self.Time < (f.PopCapUntil or -1) then 1 else rest.Transparency
			end
		end
	elseif f.Id == "prism" then
		for p, rest in f.DetailStates do
			if p.Name == "RayLens" then
				if f.RayAim and self.Time < (f.RayAimUntil or -1) then
					local point = f.Body.Position + f.RayAim * f.Body.Size.X * 0.5
					p.CFrame = CFrame.lookAt(point, point + f.RayAim)
					p.Material, p.Transparency = Enum.Material.Neon, 0.08
				else
					p.CFrame = f.Pivot * CFrame.new(rest.Center) * rest.Rotation
					p.Material, p.Transparency = Enum.Material.Glass, rest.Transparency
				end
			end
		end
	end
end
function Hero.motion(f, time)
	local twist, kick = 0, 0
	if f.HealSpinAt and time >= f.HealSpinAt and time < f.HealSpinAt + f.HealSpinSeconds then
		local t = (time - f.HealSpinAt) / f.HealSpinSeconds
		twist = (t * t * (3 - 2 * t)) * math.pi * 2
	end
	if f.PopAt then
		local t = (time - f.PopAt) / VFX.HeroRecoilSeconds
		if t >= 0 and t < 1 then
			kick = math.sin(t * math.pi * 2) * (1 - t) * VFX.HeroRecoilAngle
		end
	end
	local recoil = f.RayAt or f.GuardHitAt
	if recoil then
		local t = (time - recoil) / VFX.HeroRecoilSeconds
		if t >= 0 and t < 1 then
			kick += math.sin(t * math.pi) * (1 - t) * VFX.HeroRecoilAngle * 0.6
		end
	end
	return CFrame.Angles(0, twist, kick)
end
return Hero
