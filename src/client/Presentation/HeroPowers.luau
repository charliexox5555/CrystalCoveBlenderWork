-- Physical hero props and motion stay cosmetic; server facts own their timing and outcomes.
local B = require(game.ReplicatedStorage.Shared.Config.Balance)
local PowerFX = require(script.Parent.PowerFX)
local GlassyMotion = require(script.Parent.GlassyMotion)
local PV = require(game.ReplicatedStorage.Shared.Config.PowerVFX)
local VFX, M = B.CombatVFX, B.Motion
local Hero = {}

-- Every fight event, before CombatEffects filters them (hook added by workstream B): Ready / armed / cancel state and
-- the v2 per-kit moments (PowerFX, docs/vfx/POWER_VFX_V2.md).
function Hero.state(self, e)
	local ok, err = pcall(function()
		PowerFX.get(self):Event(e)
	end)
	if not ok then
		warn("PowerFX event " .. tostring(e.Type) .. ": " .. tostring(err))
	end
end
local function size(p, diameter)
	p.Size *= diameter / math.max(p.Size.X, p.Size.Y, p.Size.Z)
end
-- Seamless powers (POWER_DIRECTION_AUDIT): aims and anchors follow the drawn bodies, not the CastStart snapshot
-- (the glassies swing 30-110 degrees between windup and release). workspace PowerFXPinned = true is the old look.
local function pinned()
	return workspace:GetAttribute("PowerFXPinned") == true
end
local function toward(self, f)
	local foe = self.Scene.Fighters[3 - f.Side]
	local d = if foe then foe.Body.Position - f.Body.Position else Vector3.zero
	return if d.Magnitude > 0.01 then d.Unit else nil
end
local function upFor(direction)
	local up = Vector3.yAxis - direction * direction.Y
	return if up.Magnitude > 0.001 then up.Unit else Vector3.zAxis
end
function Hero.weapon(self, cast, color)
	-- The axe model is Crescent Axe's; other sweeps (Glass Top's spin) are drawn by PowerFX.
	if self.Scene.Fighters[cast.Side].Id ~= "crescent_axe" then
		return
	end
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
	-- Living glassies: v3/v4 imports animate their Details from Config/GlassyMotion (no-op for v2 models).
	local RS = game:GetService("ReplicatedStorage")
	local library = if self.Scene.Data.ReleasePrototype
		then RS.Assets.CombatReleasePreview.Glassies
		else RS.Assets.Glassies
	local source = library:FindFirstChild(f.RenderId or f.Id)
	if (f.RenderId or f.Id) == f.Id and GlassyMotion.enabled(source) then
		f.Motion = GlassyMotion.attach(f.Model, f.Id, { Scale = M.GlassyScale, Type = f.Def.Type, HitScale = 0.6 })
	end
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
			-- v2: the raised lid reads as a bright gold shield, not a dull disc.
			copy.Color = copy.Color:Lerp(Color3.fromHex("#FFD45A"), 0.45)
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
		f.RayAim, f.RayAimUntil, f.RayAimLive = cast.Direction, cast.Time + VFX.RayReadSeconds, false
	end
	-- PowerFX draws the ray (thick core + sheath that thins out); keep CombatEffects' locked beam as data only.
	for _, beam in { cast.Beam, cast.Halo } do
		if beam then
			beam.Enabled = false
		end
	end
	local _ = color
end
function Hero.guard(self, f, active)
	-- Scene:EndRoundEffects (Shatter / HideBroken) lands here with active = false: end every power moment now,
	-- even if the render clock has stopped at the final snapshot.
	if not active and self.PowerFX then
		local fighters = self.Scene.Fighters
		if fighters[1].Broken or fighters[2].Broken or f.Finishing then
			self.PowerFX:StopAll()
		end
	end
	if f.Id ~= "jam" then
		f.SignatureGuard.Transparency = 1 -- PowerFX draws every other guard (Duck bubble, crystal plates)
		return
	end
	if not f.HeroLid or not f.HeroLid.Parent then
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
	-- The v2 kits replace the shared windup / pressure rings. Unparent rather than destroy: CombatEffects still
	-- reads the ring's colour and steps its size.
	if cast.Ring and f.Id ~= "hollowlight" then
		cast.Ring.Parent = nil
	end
	if f.Id == "prism" and e.Type == "CastStart" then
		f.RayAim = if e.Direction
			then self.Scene.Frame:VectorToWorldSpace(Vector3.new(table.unpack(e.Direction))).Unit
			else self.Scene.Frame.RightVector * (if e.Side == 1 then 1 else -1)
		f.RayAimUntil, f.RayAimLive = e.Time + e.Windup, not pinned()
	elseif f.Id == "crescent_axe" and e.Type == "CastStart" then
		cast.Winding = true
		cast.Direction = if e.Direction
			then self.Scene.Frame:VectorToWorldSpace(Vector3.new(table.unpack(e.Direction))).Unit
			else self.Scene.Frame.RightVector * (if cast.Side == 1 then 1 else -1)
		Hero.weapon(self, cast, color)
	elseif f.Id == "hourglass" then
		-- The rewinding clock face is PowerFX (Kits.hourglass); the body still spins through the windup.
		if e.Type == "CastStart" then
			f.HealSpinAt, f.HealSpinSeconds = e.Time, e.Windup
		end
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
		cast.EndAt = e.Time + VFX.HeroRecoilSeconds + VFX.Tail
	end
end
function Hero.step(self, cast, age, alpha)
	local e, f = cast.Event, self.Scene.Fighters[cast.Side]
	if cast.Weapon then
		local progress = math.clamp(age / (if cast.Winding then e.Windup else e.Duration), 0, 1)
		local arc = if cast.Winding then B.CombatRelease.Kits.crescent_axe.Arc else e.Arc
		local angle = if cast.Winding then -0.5 * arc - progress * 0.25 else (-0.5 + progress) * arc
		-- Winding: the raised axe keeps facing the foe as both swing (the swing is aimed at it on release).
		local direction = if cast.Winding and not pinned() then toward(self, f) or cast.Direction else cast.Direction
		local castUp = if cast.Winding and not pinned() then upFor(direction) else cast.Up
		local outward = direction * math.cos(angle) + castUp * math.sin(angle)
		local up = castUp * math.cos(angle) - direction * math.sin(angle)
		-- The swing happens round the axe as drawn, not round where it was at release.
		local origin = if cast.Winding or not pinned() then f.Body.Position else cast.Origin
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
	for _, entry in cast.Caps or {} do
		local progress = math.clamp(age / VFX.HeroRecoilSeconds, 0, 1)
		entry.Mesh.CFrame = entry.Base
			* CFrame.new(0, math.sin(progress * math.pi) * PV.Motion.PopCapLift, 0)
			* CFrame.Angles(progress * math.pi * 1.5, progress * math.pi * 4, 0)
		entry.Mesh.Transparency = if progress > 0.8 then (progress - 0.8) / 0.2 else 0.1
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
				local aiming = f.RayAim and self.Time < (f.RayAimUntil or -1)
				f.MotionSkip = if aiming then { RayLens = true } else nil
				if aiming then
					-- Through the windup the lens tracks the foe; once fired it holds the ray's line.
					local aim = if f.RayAimLive then toward(self, f) or f.RayAim else f.RayAim
					local point = f.Body.Position + aim * f.Body.Size.X * 0.5
					p.CFrame = CFrame.lookAt(point, point + aim)
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
	local body = if f.Motion and not f.LowDetail then f.Motion:Body(time) else CFrame.identity
	return CFrame.Angles(0, twist, kick) * PowerFX.motion(f, time) * body
end
return Hero
