-- Persistent statuses (mark, slow, brine) and glassy detail animation; the v2 power moments live in PowerFX.
local RS = game:GetService("ReplicatedStorage")
local Balance = require(RS.Shared.Config.Balance)
local Visuals = require(RS.Shared.Config.CombatKitVisuals)
local PowerFX = require(script.Parent.PowerFX)
local VFX, M = Balance.CombatVFX, Balance.Motion
local Presentation = {}
function Presentation.color(f)
	local visual = Visuals[f.Id]
	if visual and visual.Color then
		return Color3.fromHex(visual.Color) -- v2: the power's own colour (the clamp below turned Milk pink)
	end
	local h, s, v = Color3.fromHex(f.Def.Tint):ToHSV()
	return Color3.fromHSV(h, math.max(s, VFX.ColorSaturation), math.max(v, VFX.ColorValue))
end
-- v2: PowerFX (Kits) draws every shape from the same events; this only keeps per-fighter state and tells
-- CombatEffects which shapes are "handled" (so it plays the release sound and skips its ray/sweep branch).
local HANDLED = {
	heal = true,
	boost = true,
	mirror = true,
	projectile = true,
	volley = true,
	cone = true,
	breath = true,
	pulse = true,
	orbit = true,
}
function Presentation.release(self, cast, e, color)
	local f = self.Scene.Fighters[e.Side]
	if not HANDLED[e.Shape] then
		return false
	end
	cast.Follow = table.find({ "heal", "boost", "mirror" }, e.Shape) ~= nil
	if f.Id == "comet" then
		f.EchoUntil = -1
	end
	if f.Id == "hourglass" and (e.Shape == "projectile" or e.Shape == "volley") then
		f.FlipAt = e.Time
	end
	local _ = color
	return true
end

function Presentation.contact(cast, e)
	-- PowerFX tracks its own shots per CastId (Dispatch: CastContact).
	local _ = cast
	local _ = e
end

function Presentation.step(self, cast, age, alpha)
	-- Every v2 shape is stepped by PowerFX from the fight clock.
	local _ = self
	local _ = cast
	local _ = age
	local _ = alpha
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
	-- v2 power moments, Ready / armed states and their cleanup step from the same clock.
	local ok, err = pcall(function()
		PowerFX.get(self):Update(r, time)
	end)
	if not ok then
		warn("PowerFX update: " .. tostring(err))
	end
	local camera = workspace.CurrentCamera.CFrame
	for side, f in self.Scene.Fighters do
		local ef = r.Effect[side] or {}
		local alive = not f.Broken and not f.Finishing and self.Scene.Viewing == true
		local foe = self.Scene.Fighters[3 - side]
		local foeColor = Presentation.color(foe)
		local size = math.max(f.Body.Size.X, f.Body.Size.Y)
		-- Marked (Ketchup): a glossy orange badge with a white ring bobs in front of the target.
		local marked = alive and (ef[4] or 0) > 0
		local badge = persistent(self, f, "Tomato", "Droplet", marked, foeColor)
		local badgeRing = persistent(self, f, "TomatoRing", "Ring", marked, Color3.new(1, 1, 1))
		if badge then
			local at = f.Body.Position
				- camera.LookVector * size * 0.55
				+ Vector3.yAxis * (size * 0.45 + math.sin(time * 4) * 0.12)
			badge.Material = Enum.Material.Neon
			badge.Size = self.Assets.Meshes.Droplet.Size * 1.5 * (1 + math.sin(time * 8) * 0.06)
			badge.CFrame = CFrame.new(at) * camera.Rotation * CFrame.Angles(0, 0, math.pi)
			badge.Transparency = 0.02
			badgeRing.Material = Enum.Material.Neon
			badgeRing.Size = self.Assets.Meshes.Ring.Size * 0.75
			badgeRing.CFrame = CFrame.new(at) * camera.Rotation * CFrame.Angles(0, 0, time * 3)
			badgeRing.Transparency = 0.15
		end
		-- Slowed: a crown of crystal chips in the slowing kit's colour circles the target.
		local slowed = alive and (ef[2] or 0) > 0
		for i = 1, 5 do
			local chip = persistent(self, f, "Slow" .. i, "CrystalChip", slowed, foeColor)
			if chip then
				local a = time * 1.6 + i / 5 * math.pi * 2
				chip.Material = Enum.Material.Neon
				chip.Size = self.Assets.Meshes.CrystalChip.Size * 0.9
				chip.CFrame = CFrame.new(
					f.Body.Position + Vector3.new(math.cos(a) * size * 0.7, size * 0.35, math.sin(a) * size * 0.7)
				) * CFrame.Angles(0, -a, 0.4)
				chip.Transparency = 0.1
			end
		end
		if slowed and foe.Id == "pickle_jar" then
			if not f.Brine or not f.Brine.Parent then
				local source = Instance.new("Attachment")
				local target = Instance.new("Attachment")
				source.Parent, target.Parent = foe.Body, f.Body
				local beam = self.Assets.Beams.BrineTether:Clone()
				beam.Attachment0, beam.Attachment1, beam.Enabled = source, target, true
				beam.Color = ColorSequence.new(foeColor, Color3.fromHex("#E8FFB0"))
				beam.Width0, beam.Width1, beam.LightEmission, beam.Segments = 0.5, 0.35, 0.15, 16
				beam.Texture, beam.Transparency = "", NumberSequence.new(0.1, 0.25)
				beam.Parent, f.Brine = self.Root, beam
				f.BrineAttachments = { source, target }
			end
			-- A sticky rope that sags and wobbles.
			f.Brine.CurveSize0 = -1.2 + math.sin(time * 5) * 0.4
			f.Brine.CurveSize1 = 1.2 + math.sin(time * 5 + 1) * 0.4
		elseif f.Brine then
			f.Brine:Destroy()
			f.Brine = nil
			for _, a in f.BrineAttachments or {} do
				a:Destroy()
			end
			f.BrineAttachments = nil
		end
		-- Detail animations must never resurrect shattered meshes or snap a flying winner back.
		if f.Broken or f.Finishing then
			continue
		end
		if f.Motion then
			-- v3/v4 models: GlassyMotion owns the Details (idle, reactions, Ready); the name-based v2 block is skipped.
			-- Fights the viewer isn't watching stay at rest (cheap); watched fights animate every Details part.
			if f.LowDetail then
				f.Motion:Rest()
			else
				f.Motion:Step(time, f.MotionSkip)
			end
			continue
		end
		for p, rest in f.DetailStates do
			if not p.Parent or not f.Pivot then
				continue
			end
			local name = rest.SourceName or p:GetAttribute("SourceName") or p.Name
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
