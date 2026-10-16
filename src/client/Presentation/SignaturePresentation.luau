-- Shared native shapes with distinct timelines for traveling attacks and persistent statuses.
local RS = game:GetService("ReplicatedStorage")
local Balance = require(RS.Shared.Config.Balance)
local Visuals = require(RS.Shared.Config.CombatKitVisuals)
local Path = require(RS.Shared.AttackPath)
local VFX, M = Balance.CombatVFX, Balance.Motion
local Presentation = {}
function Presentation.color(f)
	local h, s, v = Color3.fromHex(f.Def.Tint):ToHSV()
	return Color3.fromHSV(h, math.max(s, VFX.ColorSaturation), math.max(v, VFX.ColorValue))
end
local function vector(a)
	return Vector3.new(a[1], a[2], a[3])
end
local function fan(direction, i, count, arc)
	local right = direction:Cross(Vector3.yAxis)
	if right.Magnitude < 0.0001 then
		return direction
	end
	local angle = if count == 1 then 0 else ((i - 1) / (count - 1) - 0.5) * arc
	return (direction * math.cos(angle) + right.Unit * math.sin(angle)).Unit
end

function Presentation.release(self, cast, e, color)
	local f = self.Scene.Fighters[e.Side]
	local visual = Visuals[f.Id]
	if table.find({ "heal", "boost", "mirror" }, e.Shape) then
		cast.Follow = true
		cast.Aura = self:Mesh(if e.Shape == "boost" then "HalfRing" else "Ring", cast.Root, color)
		if e.Shape == "boost" and (f.Id == "rocket_pop" or f.Id == "hot_sauce") then
			cast.Flames =
				{ self:Mesh("Thorn", cast.Root, Color3.fromHex(VFX.FlameColor)), self:Mesh("Thorn", cast.Root, color) }
		end
		return true
	end
	if e.Shape == "projectile" or e.Shape == "volley" then
		cast.Shots = {}
		local count = if e.Shape == "volley" then e.Pulses or 1 else 1
		for i = 1, count do
			local p = self:Mesh(visual.MeshA, cast.Root, color)
			p.Name, p.Material = "Shot" .. i, Enum.Material.Neon
			p.Size *= e.Radius * 2 / math.max(p.Size.X, p.Size.Y, p.Size.Z)
			local a, b = Instance.new("Attachment"), Instance.new("Attachment")
			a.Position, b.Position = Vector3.xAxis * e.Radius, -Vector3.xAxis * e.Radius
			a.Parent, b.Parent = p, p
			local trail = Instance.new("Trail")
			trail.Attachment0, trail.Attachment1 = a, b
			trail.Color, trail.Lifetime, trail.LightEmission = ColorSequence.new(color), VFX.SwingTrailSeconds, 1
			trail.Transparency = NumberSequence.new(0.2, 1)
			trail.Parent = p
			local halo = self:Mesh("HalfRing", cast.Root, color)
			halo.Material = Enum.Material.Neon
			halo.Name = "ShotHalo" .. i
			halo.Size *= e.Radius * 2 * VFX.ShotHaloScale / math.max(halo.Size.X, halo.Size.Y, halo.Size.Z)
			cast.Shots[i] = {
				Mesh = p,
				Halo = halo,
				Direction = fan(cast.Direction, i, count, e.Arc or 0),
				Trail = trail,
				Done = e.Resolved and e.Resolved[if e.Path == "return" then 2 else i],
			}
		end
		if f.Id == "comet" then
			f.EchoUntil = -1
		end
		if f.Id == "hourglass" then
			f.FlipAt = e.Time
		end
	elseif e.Shape == "cone" or e.Shape == "breath" then
		cast.Motes = {}
		for i = 1, (if f.LowDetail then 2 else VFX.ConeMotes) do
			local p = self:Mesh(if f.Id == "water_jug" then "Droplet" else "CrystalChip", cast.Root, color)
			p.Name = "ConeMote" .. i
			p.Material = Enum.Material.Neon
			p.Size *= VFX.ConeMoteSize / math.max(p.Size.X, p.Size.Y, p.Size.Z)
			table.insert(cast.Motes, p)
		end
		cast.Sheets = {}
		for i = 1, 2 do
			local p = self:Mesh(if f.Id == "water_jug" then "SplashSheet" else "PuffSheet", cast.Root, color)
			table.insert(cast.Sheets, p)
		end
	elseif e.Shape == "pulse" then
		cast.PulseRings = {
			self:Mesh("Ring", cast.Root, color),
			self:Mesh("HalfRing", cast.Root, color),
			self:Mesh("Ring", cast.Root, color),
		}
	elseif e.Shape == "orbit" then
		cast.Satellites = {}
		for i = 1, (if f.LowDetail then 2 else 4) do
			local p = self:Mesh("CrystalChip", cast.Root, Color3.fromHex("#FFE8A9"))
			p.Size *= VFX.AccentSize / math.max(p.Size.X, p.Size.Y, p.Size.Z)
			table.insert(cast.Satellites, p)
		end
		cast.Orbit = {
			self:Mesh("Ring", cast.Root, color),
			self:Mesh("HalfRing", cast.Root, color),
			self:Mesh("CrystalChip", cast.Root, Color3.fromHex("#FFE8A9")),
		}
	else
		return false
	end
	return true
end

function Presentation.contact(cast, e)
	if cast and cast.Event.Path == "return" and e.Pulse == 1 then
		return
	end
	if cast and cast.Shots and cast.Shots[e.Pulse or 1] then
		local shot = cast.Shots[e.Pulse or 1]
		shot.Done, shot.Trail.Enabled, shot.Mesh.Transparency = true, false, 1
		shot.Halo.Transparency = 1
	elseif cast and cast.Event.Path == "return" and e.Pulse == 2 then
		cast.Shots[1].Done = true
	end
end

function Presentation.step(self, cast, age, alpha)
	local e, f = cast.Event, self.Scene.Fighters[cast.Side]
	local color = Presentation.color(f)
	local progress = math.clamp(age / (e.Duration or 1), 0, 1)
	if cast.Aura then
		local y = if e.Shape == "heal" then f.Body.Size.Y * (0.5 - progress) else 0
		cast.Aura.CFrame = CFrame.new(f.Body.Position + Vector3.yAxis * y)
			* workspace.CurrentCamera.CFrame.Rotation
			* CFrame.Angles(0, 0, age * VFX.OrbitSpeed)
		cast.Aura.Size = self.Assets.Meshes.Ring.Size * f.Body.Size.X * VFX.StatusScale
		cast.Aura.Transparency = VFX.StatusTransparency + alpha * (1 - VFX.StatusTransparency)
	end
	for i, p in cast.Flames or {} do
		p.Size = self.Assets.Meshes.Thorn.Size
			* VFX.FlameScale
			* (1 + math.sin(age * VFX.OrbitSpeed * i) * VFX.DetailPulse)
		p.CFrame = f.Body.CFrame
			* CFrame.new((i - 1.5) * VFX.FlameScale, -f.Body.Size.Y / 2, 0)
			* CFrame.Angles(math.pi, 0, 0)
		p.Transparency = VFX.ChargeLit + alpha * (1 - VFX.ChargeLit)
	end
	for _, shot in cast.Shots or {} do
		if shot.Done then
			shot.Mesh.Transparency, shot.Trail.Enabled = 1, false
			shot.Halo.Transparency = 1
		else
			local position = cast.Origin + shot.Direction * e.Range * Path.distance(progress, e.Path)
			local pose = CFrame.lookAt(position, position + shot.Direction)
			local facing = CFrame.new(position) * workspace.CurrentCamera.CFrame.Rotation
			shot.Mesh.CFrame = (if f.Id == "prism_blade" then facing else pose)
				* CFrame.Angles(0, 0, age * VFX.AccentSpin)
			shot.Mesh.Transparency = VFX.ChargeLit + alpha * (1 - VFX.ChargeLit)
			shot.Halo.CFrame = facing * CFrame.Angles(0, 0, -age * VFX.AccentSpin)
			shot.Halo.Transparency = VFX.StatusTransparency + alpha * (1 - VFX.StatusTransparency)
		end
	end
	for i, p in cast.Motes or {} do
		local phase = (progress * (e.Pulses or 1) + (i - 1) / #cast.Motes) % 1
		local distance = e.Range * phase
		local radius = distance * math.tan(e.Arc / 2) * VFX.ConeSheetScale
		local angle = i / #cast.Motes * math.pi * 2 + age * VFX.AccentSpin
		p.CFrame = CFrame.lookAt(cast.Origin, cast.Origin + cast.Direction)
			* CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, -distance)
			* CFrame.Angles(angle, age, angle)
		p.Transparency = math.clamp(VFX.ChargeLit + phase * VFX.StatusTransparency + alpha, 0, 1)
	end
	for i, p in cast.Sheets or {} do
		local distance = e.Range * i / 2
		local position = cast.Origin + cast.Direction * distance
		local width = 2 * distance * math.tan(e.Arc / 2)
		p.CFrame = CFrame.new(position) * workspace.CurrentCamera.CFrame.Rotation
		p.Size = Vector3.new(width, width * VFX.ConeSheetScale, p.Size.Z)
		local pulse = if e.Pulses then (age * e.Pulses / e.Duration) % 1 else progress
		p.Transparency = math.clamp(VFX.ConeTransparency + pulse * (1 - VFX.ConeTransparency) + alpha, 0, 1)
	end
	for i, p in cast.PulseRings or {} do
		local diameter = math.max(0.05, e.Range * 2 * progress)
		p.Size = Vector3.new(diameter, diameter, self.Assets.Meshes.Ring.Size.Z)
		p.CFrame = CFrame.new(cast.Origin)
			* CFrame.Angles(if i == 2 then math.pi / 2 else 0, if i == 3 then math.pi / 2 else 0, 0)
		p.Transparency = VFX.StatusTransparency + alpha * (1 - VFX.StatusTransparency)
	end
	for i, p in cast.Satellites or {} do
		local angle = i / #cast.Satellites * math.pi * 2 + age * VFX.AccentSpin
		local radius = e.Range * (1 - progress)
		p.CFrame = CFrame.new(
			cast.Origin
				+ Vector3.new(
					math.cos(angle) * radius,
					math.sin(angle * 2) * radius * VFX.StatusScale,
					math.sin(angle) * radius
				)
		) * CFrame.Angles(angle, age, angle)
		p.Transparency = VFX.ChargeLit + alpha * (1 - VFX.ChargeLit)
	end
	for i, p in cast.Orbit or {} do
		p.CFrame = CFrame.new(cast.Origin)
			* workspace.CurrentCamera.CFrame.Rotation
			* CFrame.Angles(0, 0, age * VFX.OrbitSpeed * (if i == 1 then 1 else -1))
		local scale = if i == 3 then VFX.StatusScale else e.Range * (1 - progress * VFX.StatusScale)
		p.Size = self.Assets.Meshes[p.Name].Size * scale
		p.Transparency = VFX.ChargeLit + alpha * (1 - VFX.ChargeLit)
	end
end

local function persistent(self, f, key, name, active, color)
	f.StatusMeshes = f.StatusMeshes or {}
	local p = f.StatusMeshes[key]
	if p and not p.Parent then
		p = nil
		f.StatusMeshes[key] = nil
	end
	if not active then
		if p then
			p:Destroy()
			f.StatusMeshes[key] = nil
		end
		return nil
	end
	if not p then
		p = self:Mesh(name, self.Root, color)
		p.Name = "Status_" .. key
		f.StatusMeshes[key] = p
	end
	return p
end

function Presentation.status(self, r, time)
	for side, f in self.Scene.Fighters do
		local ef = r.Effect[side] or {}
		local alive = not f.Broken and not f.Finishing and self.Scene.Viewing == true
		local color = Presentation.color(f)
		local mark = persistent(self, f, "Tomato", "Droplet", alive and (ef[4] or 0) > 0, Color3.fromHex("#FFA35B"))
		if mark then
			mark.Size = self.Assets.Meshes.Droplet.Size * VFX.StatusScale
			mark.CFrame = CFrame.new(f.Body.Position + workspace.CurrentCamera.CFrame.ZVector * f.Body.Size.X / 2)
			mark.Transparency = VFX.ChargeLit
		end
		local frost = persistent(self, f, "Slow", "HalfRing", alive and (ef[2] or 0) > 0, Color3.fromHex("#B3F4FF"))
		if frost then
			frost.CFrame = CFrame.new(f.Body.Position)
				* workspace.CurrentCamera.CFrame.Rotation
				* CFrame.Angles(0, 0, time)
			frost.Size = self.Assets.Meshes.HalfRing.Size * f.Body.Size.X
			frost.Transparency = VFX.StatusTransparency
		end
		if alive and (ef[2] or 0) > 0 and self.Scene.Fighters[3 - side].Id == "pickle_jar" then
			if not f.Brine or not f.Brine.Parent then
				local source = Instance.new("Attachment")
				local target = Instance.new("Attachment")
				source.Parent, target.Parent = self.Scene.Fighters[3 - side].Body, f.Body
				local beam = self.Assets.Beams.BrineTether:Clone()
				beam.Attachment0, beam.Attachment1, beam.Enabled = source, target, true
				beam.Color = ColorSequence.new(Color3.fromHex(self.Scene.Fighters[3 - side].Def.Tint))
				beam.Parent, f.Brine = self.Root, beam
				f.BrineAttachments = { source, target }
			end
		elseif f.Brine then
			f.Brine:Destroy()
			f.Brine = nil
			for _, a in f.BrineAttachments or {} do
				a:Destroy()
			end
			f.BrineAttachments = nil
		end
		local echo =
			persistent(self, f, "Echo", "CrystalChip", alive and (f.EchoUntil or -1) > time, Color3.fromHex("#FFE8A9"))
		if echo then
			echo.CFrame = CFrame.new(f.EchoPoint) * CFrame.Angles(0, time * VFX.OrbitSpeed, 0)
			echo.Size = self.Assets.Meshes.CrystalChip.Size * VFX.StatusScale
		end
		local mirror =
			persistent(self, f, "Mirror", "GuardPlate", alive and f.Id == "crystal_tumbler" and (ef[1] or 0) > 0, color)
		if mirror then
			mirror.CFrame = CFrame.new(f.Body.Position + workspace.CurrentCamera.CFrame.ZVector * f.Body.Size.X / 2)
				* workspace.CurrentCamera.CFrame.Rotation
			mirror.Size = self.Assets.Meshes.GuardPlate.Size * M.GlassyScale * VFX.StatusScale
			mirror.Transparency = VFX.StatusTransparency
		end
		-- Detail animations must never resurrect shattered meshes or snap a flying winner back.
		if f.Broken or f.Finishing then
			continue
		end
		for p, rest in f.DetailStates do
			if not p.Parent or not f.Pivot then
				continue
			end
			local name = p:GetAttribute("SourceName") or p.Name
			local charge = r.Power[side] or 0
			local active = charge >= VFX.ReadyGlowThreshold or (ef[3] or 0) > 0
			if
				name:find("StressBand")
				or name:find("Ember")
				or name:find("LemonPulp")
				or name:find("StarCore")
				or name:find("CrystalSprout")
			then
				p.Material = if active then Enum.Material.Neon else Enum.Material.Glass
				p.Transparency = if active then VFX.ChargeLit else VFX.StatusTransparency
			elseif name == "WaterInsert" or name == "SandInsert" then
				local growth = VFX.StatusScale + (1 - VFX.StatusScale) * charge
				p.Size = Vector3.new(rest.Size.X, rest.Size.Y * growth, rest.Size.Z)
				p.CFrame = f.Pivot
					* CFrame.new(rest.Center - Vector3.yAxis * rest.Size.Y * (1 - growth) / 2)
					* rest.Rotation
			elseif name:find("FoamBubble") then
				p.Size = rest.Size * (1 + charge * VFX.DetailPulse)
			elseif name:find("FrameCap") or name:find("FramePost") then
				local progress = if f.FlipAt
					then math.clamp((time - f.FlipAt) / Balance.CombatRelease.Kits.hourglass.Duration, 0, 1)
					else 0
				local center = -Vector3.yAxis * f.Body.Size.Y / 2
				p.CFrame = f.Pivot
					* CFrame.new(center)
					* CFrame.Angles(0, 0, math.pi * progress)
					* CFrame.new(rest.Center - center)
					* rest.Rotation
			elseif name:find("OrbitBand") then
				p.CFrame = f.Pivot
					* CFrame.new(rest.Center)
					* CFrame.Angles(0, time * VFX.OrbitSpeed * charge, 0)
					* rest.Rotation
			elseif name:find("Wing") or name == "Jaw" or name == "Clapper" then
				local base = (p:GetAttribute("AnimationPivot") or rest.Center / M.GlassyScale) * M.GlassyScale
				p.CFrame = f.Pivot
					* CFrame.new(base)
					* CFrame.Angles(math.sin(time * VFX.OrbitSpeed) * charge * VFX.DetailPulse, 0, 0)
					* CFrame.new(rest.Center - base)
					* rest.Rotation
			end
		end
	end
end

return Presentation
