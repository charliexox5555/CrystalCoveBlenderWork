-- Hollowlight Lantern Seeds presentation: pooled seeds orbit the seeded foe, then each seed bursts
-- into a wisp that arcs home. Seed count follows the authoritative power progress; events only add
-- one-shot pops, flares and wisps. Client-only, no damage.
local RS = game:GetService("ReplicatedStorage")
local Balance = require(RS.Shared.Config.Balance)
local HollowlightFX = require(script.Parent.HollowlightFX)
local V = Balance.CombatVFX.LanternSeeds
local Kit = Balance.CombatRelease.Kits.hollowlight
local Seeds = {}

local function ball(parent, name, size, color, material, transparency)
	local p = Instance.new("Part")
	p.Name, p.Shape, p.Size = name, Enum.PartType.Ball, Vector3.one * size
	p.Color, p.Material, p.Transparency = color, material, 1
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p:SetAttribute("RestTransparency", transparency)
	p.Parent = parent
	return p
end

function Seeds.init(effects, f)
	local seedColor, glowColor = Color3.fromHex(V.SeedColor), Color3.fromHex(V.GlowColor)
	local folder = Instance.new("Folder")
	folder.Name = "LanternSeeds" .. f.Side
	folder:SetAttribute("Pooled", true)
	folder.Parent = effects.Root
	local state = { Folder = folder, Slots = {}, Wisps = {}, Shown = 0, Face = {} }
	for i = 1, Kit.MaxSeeds do
		local core = ball(folder, "Seed" .. i, V.SeedSize, seedColor, Enum.Material.Neon, 0)
		local shell = not f.LowDetail
			and ball(folder, "SeedShell" .. i, V.SeedSize * V.ShellScale, glowColor, Enum.Material.Glass, 0.55)
		state.Slots[i] = { Core = core, Shell = shell, BornAt = -math.huge }
		local wisp = ball(folder, "Wisp" .. i, V.WispSize, glowColor, Enum.Material.Neon, 0)
		local trail
		if not f.LowDetail then
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Position, a1.Position = Vector3.new(0, V.WispSize * 0.5, 0), Vector3.new(0, -V.WispSize * 0.5, 0)
			a0.Parent, a1.Parent = wisp, wisp
			trail = Instance.new("Trail")
			trail.Attachment0, trail.Attachment1, trail.Lifetime = a0, a1, V.TrailSeconds
			trail.Color = ColorSequence.new(glowColor, seedColor)
			trail.Transparency = NumberSequence.new(0.1, 1)
			trail.LightEmission, trail.FaceCamera, trail.Enabled = 1, true, false
			trail.Parent = wisp
		end
		state.Wisps[i] = { Part = wisp, Trail = trail }
	end
	for _, p in f.Parts do
		local name = p:GetAttribute("SourceName") or p.Name
		if name == "Eye_L" or name == "Eye_R" or name == "Grin" then
			state.Face[p] = p.Material
		end
	end
	f.Seeds = state
end

local function width(foe)
	return math.max(foe.Body.Size.X, foe.Body.Size.Z)
end

local function seedPosition(foe, i, count, time)
	local radius = width(foe) * (0.5 + V.OrbitGap)
	local angle = time * V.OrbitHz * math.pi * 2 + (i - 1) * math.pi * 2 / math.max(count, 1)
	local offset =
		Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius * V.OrbitTilt, math.sin(angle) * radius)
	return foe.Body.Position + offset + Vector3.yAxis * math.sin(time * 3 + i) * V.Bob * width(foe)
end

local function hide(slot)
	slot.Core.Transparency = 1
	if slot.Shell then
		slot.Shell.Transparency = 1
	end
end

-- One-shot reactions. Returns true when the event needs no generic signature presentation.
function Seeds.event(effects, f, e)
	local s = f.Seeds
	local foe = effects.Scene.Fighters[3 - f.Side]
	if e.Type == "Charge" then
		return true -- every clash charges; the seed pop below is the readable beat
	elseif e.Type == "SignatureStatus" and e.Kind == "Seed" then
		local slot = s.Slots[e.Count]
		if slot then
			slot.BornAt = e.Time
			local at = seedPosition(foe, e.Count, e.Count, effects.Time)
			effects:Burst("ContactGlint", at, Color3.fromHex(V.SeedColor), f.LowDetail)
		end
		effects:Sound("ClinkLightB", f.Side)
		return true
	elseif e.Type == "SignatureStatus" and (e.Kind == "SeedLost" or e.Kind == "SeedFade") then
		for i = (e.Count or 0) + 1, Kit.MaxSeeds do
			if s.Slots[i].Core.Transparency < 1 then
				effects:Burst("GlassDust", s.Slots[i].Core.Position, Color3.fromHex(V.SeedColor), true)
			end
		end
		if e.Kind == "SeedLost" then
			effects:Sound("ClinkLightA", f.Side)
		end
		return true
	elseif e.Type == "CastStart" and e.Shape == "bloom" then
		s.Bloom = {
			Start = e.Time,
			Count = e.Pulses or math.max(s.Shown, 1),
			Released = 0,
			EndAt = e.Time + e.Windup + Kit.Duration + V.WispSeconds,
		}
	elseif e.Type == "CastContact" and s.Bloom and not e.Missed then
		local b = s.Bloom
		b.Released += 1
		local wisp = s.Wisps[b.Released]
		local slot = s.Slots[b.Count - b.Released + 1]
		if wisp and slot then
			local from = if slot.Core.Transparency < 1 then slot.Core.Position else foe.Body.Position
			local side = effects.Scene.Frame.LookVector * (if b.Released % 2 == 0 then 1 else -1)
			local arc, size = V.WispArc * width(foe), V.WispSize * width(foe)
			wisp.From, wisp.Bend, wisp.Start = from, Vector3.yAxis * arc + side * arc * 0.4, e.Time
			wisp.Part.Size = Vector3.one * size
			if wisp.Trail then
				wisp.Trail.Attachment0.Position = Vector3.yAxis * size * 0.5
				wisp.Trail.Attachment1.Position = -Vector3.yAxis * size * 0.5
			end
			wisp.Last = b.Released == b.Count
		end
	end
	return false
end

function Seeds.update(effects, f, r, time, active)
	local s = f.Seeds
	local foe = effects.Scene.Fighters[3 - f.Side]
	local count = if active then math.floor((r.Power[f.Side] or 0) * Kit.MaxSeeds + 0.01) else 0
	local flare = 1
	if s.Bloom then
		if time > s.Bloom.EndAt or not active then
			s.Bloom = nil
		else
			count = s.Bloom.Count - s.Bloom.Released
			flare = 1 + (V.FlareScale - 1) * math.clamp((time - s.Bloom.Start) / Kit.Windup, 0, 1)
		end
	end
	s.Shown = count
	for i, slot in s.Slots do
		if i > count or foe.Broken then
			hide(slot)
			continue
		end
		local grow = math.clamp((time - slot.BornAt) / V.PopInSeconds, 0, 1)
		local pop = (1 + math.sin(grow * math.pi) * 0.35) * flare
		local at = seedPosition(foe, i, count, time)
		local size = V.SeedSize * width(foe) * pop
		slot.Core.Size, slot.Core.Position, slot.Core.Transparency = Vector3.one * size, at, 0
		if slot.Shell then
			slot.Shell.Size = Vector3.one * size * V.ShellScale
			slot.Shell.Position = at
			slot.Shell.Transparency = slot.Shell:GetAttribute("RestTransparency") + 0.15 * math.sin(time * 6 + i)
		end
	end
	for _, wisp in s.Wisps do
		if not wisp.Start then
			continue
		end
		local t = (time - wisp.Start) / V.WispSeconds
		local target = f.Body.Position
		if t < 0 then
			continue
		end
		if wisp.Part.Transparency >= 1 and t < 1 then
			wisp.Part.Position, wisp.Part.Transparency = wisp.From, 0
			if wisp.Trail then
				wisp.Trail.Enabled = true
			end
		end
		if t >= 1 or not active then
			wisp.Start, wisp.Part.Transparency = nil, 1
			if wisp.Trail then
				wisp.Trail.Enabled = false
			end
			if active then
				s.GlowUntil = time + V.FaceGlowSeconds
				effects:Burst("ContactGlint", target, Color3.fromHex(V.SeedColor), f.LowDetail)
				if wisp.Last and not f.LowDetail then
					HollowlightFX.pressure(effects.Root, target)
				end
			end
			continue
		end
		local eased = 1 - (1 - t) ^ 2
		local mid = (wisp.From + target) / 2 + wisp.Bend
		wisp.Part.Position = wisp.From:Lerp(mid, eased):Lerp(mid:Lerp(target, eased), eased)
	end
	local lit = active and (count >= Kit.MaxSeeds or time < (s.GlowUntil or -1))
	for part, material in s.Face do
		part.Material = if lit then Enum.Material.Neon else material
	end
end

function Seeds.reset(f)
	local s = f.Seeds
	s.Bloom, s.Shown, s.GlowUntil = nil, 0, nil
	for _, slot in s.Slots do
		hide(slot)
	end
	for _, wisp in s.Wisps do
		wisp.Start, wisp.Part.Transparency = nil, 1
		if wisp.Trail then
			wisp.Trail.Enabled = false
		end
	end
	for part, material in s.Face do
		part.Material = material
	end
end

return Seeds
