-- Hollowlight Lantern Seeds presentation v2 (docs/vfx/HOLLOWLIGHT_PREMIUM.md section 4): pooled seeds with
-- mint flames orbit the seeded foe and ripen at three; each bloom pops a star blossom and sends a tiny ghost
-- home. While the bloom is Ready the pumpkin's face flickers like a candle and two wisps circle it; a manual
-- cast puffs a ring of ghosts. Every plant rings the next note of the Hollowlight chime. Seed count follows the
-- authoritative power progress; events only add one-shot moments. Client-only, no damage or rule changes.
local RS = game:GetService("ReplicatedStorage")
local Balance = require(RS.Shared.Config.Balance)
local Audio = require(RS.Shared.Config.Audio)
local AudioCues = require(RS.Shared.Config.AudioCues)
local Sound = require(RS.Shared.Config.HollowlightAudio)
local HollowlightFX = require(script.Parent.HollowlightFX)
local V = Balance.CombatVFX.LanternSeeds
local Kit = Balance.CombatRelease.Kits.hollowlight
local Seeds = {}

local TAU = math.pi * 2

local function still(p)
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	return p
end

local function ball(parent, name, size, color, material, transparency)
	local p = still(Instance.new("Part"))
	p.Name, p.Shape, p.Size = name, Enum.PartType.Ball, Vector3.one * size
	p.Color, p.Material, p.Transparency = color, material, 1
	p:SetAttribute("RestTransparency", transparency)
	p.Parent = parent
	return p
end

local function trail(part, color0, color1, seconds)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = part, part
	local t = Instance.new("Trail")
	t.Attachment0, t.Attachment1, t.Lifetime = a0, a1, seconds
	t.Color = ColorSequence.new(color0, color1)
	t.Transparency = NumberSequence.new(0.1, 1)
	t.WidthScale = NumberSequence.new(1, 0.15)
	t.LightEmission, t.FaceCamera, t.Enabled = 1, true, false
	t.Parent = part
	return t
end

local function fitTrail(t, size)
	if t then
		t.Attachment0.Position = Vector3.yAxis * size * 0.5
		t.Attachment1.Position = -Vector3.yAxis * size * 0.5
	end
end

-- A small ghost (head + face + tail) cloned from the eclipse's authored wisp; nil if the art is missing.
local function ghost(parent, name, withTrail)
	local seasonal = RS.Assets:FindFirstChild("Seasonal")
	local art = seasonal and seasonal:FindFirstChild("Hollowlight")
	art = art and art:FindFirstChild("lantern_eclipse")
	local head = art and art:FindFirstChild("Wisp0")
	if not head then
		return nil
	end
	local g = { Parts = {}, Height = head.Size.Y }
	for _, n in { "Wisp0", "WispFace0", "WispTail0" } do
		local template = art:FindFirstChild(n)
		if template then
			local p = still(template:Clone())
			p.Name, p.Transparency, p.Parent = name .. "_" .. n, 1, parent
			table.insert(g.Parts, {
				Part = p,
				Offset = head.CFrame:ToObjectSpace(template.CFrame),
				Size = template.Size,
				Alpha = template.Transparency,
			})
			if n == "Wisp0" then
				g.Head = p
			end
		end
	end
	if withTrail and g.Head then
		g.Trail = trail(g.Head, Color3.fromHex(V.GlowColor), Color3.fromHex(V.SeedColor), V.TrailSeconds)
	end
	return g
end

-- Places a ghost at `at`, `height` studs tall, facing the camera's heading, leaning along `lean`.
local function placeGhost(g, at, height, alpha, lean)
	if not g then
		return
	end
	local look = workspace.CurrentCamera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	local heading = CFrame.lookAt(Vector3.zero, flat) * CFrame.Angles(0, 0, lean or 0)
	local s = height / g.Height
	for _, p in g.Parts do
		p.Part.CFrame = CFrame.new(at) * heading * CFrame.new(p.Offset.Position * s) * p.Offset.Rotation
		p.Part.Size = p.Size * s
		p.Part.Transparency = if alpha >= 1 then 1 else p.Alpha + (1 - p.Alpha) * alpha
	end
	if g.Trail then
		fitTrail(g.Trail, height * 0.6)
	end
end

local function hideGhost(g)
	if g then
		for _, p in g.Parts do
			p.Part.Transparency = 1
		end
		if g.Trail then
			g.Trail.Enabled = false
		end
	end
end

-- Plays one Config/Audio key on the fighter's body (3D), scaled from its AudioCues trim.
local function play(effects, f, key, volume, pitch, delay)
	local id = Audio[key]
	if not id then
		return
	end
	local function go()
		if not effects.Root.Parent or f.Broken then
			return
		end
		local cue = AudioCues[id]
		local sound = effects.Scene:Sound(id, f.Body, pitch or 1, (if cue then cue.Volume else 0.35) * (volume or 1))
		if sound then
			table.insert(effects.Sounds, sound)
		end
	end
	if delay and delay > 0 then
		task.delay(delay, go)
	else
		go()
	end
end

local function note(effects, f, n, volume, delay)
	local pitches = Sound.Chime.Pitches
	play(effects, f, Sound.Chime.Key, Sound.Chime.Volume * volume, pitches[(n - 1) % #pitches + 1], delay)
end

local function arpeggio(effects, f, volume, gap)
	for n = 1, #Sound.Chime.Pitches do
		note(effects, f, n, volume, (n - 1) * gap)
	end
end

function Seeds.init(effects, f)
	local seedColor, glowColor = Color3.fromHex(V.SeedColor), Color3.fromHex(V.GlowColor)
	local folder = Instance.new("Folder")
	folder.Name = "LanternSeeds" .. f.Side
	folder:SetAttribute("Pooled", true)
	folder.Parent = effects.Root
	local low = f.LowDetail
	local state =
		{ Folder = folder, Slots = {}, Wisps = {}, Shown = 0, Face = {}, Phase = 0, Orbiters = {}, Puffs = {} }
	for i = 1, Kit.MaxSeeds do
		local core = ball(folder, "Seed" .. i, V.SeedSize, seedColor, Enum.Material.Neon, 0)
		local slot = { Core = core, BornAt = -math.huge }
		if not low then
			slot.Shell = ball(folder, "SeedShell" .. i, V.SeedSize * V.ShellScale, glowColor, Enum.Material.Glass, 0.55)
			slot.Flame = ball(
				folder,
				"SeedFlame" .. i,
				V.SeedSize * V.FlameScale,
				Color3.fromHex(V.FlameColor),
				Enum.Material.Neon,
				0.1
			)
			slot.Trail = trail(core, seedColor, glowColor, V.SeedTrailSeconds)
		end
		state.Slots[i] = slot
		-- Homing ghost (falls back to a glowing ball if the eclipse art is missing).
		local g = ghost(folder, "HomeGhost" .. i, not low)
		local wisp = { Ghost = g }
		if not g then
			wisp.Part = ball(folder, "Wisp" .. i, V.WispSize, glowColor, Enum.Material.Neon, 0)
			if not low then
				wisp.Trail = trail(wisp.Part, glowColor, seedColor, V.TrailSeconds)
			end
		end
		state.Wisps[i] = wisp
		-- Star blossom where the seed leaves on a bloom.
		local hero = RS.Assets.VFX:FindFirstChild("RoundHeroV2")
		local star = hero and hero:FindFirstChild("NovaStar")
		if star and not low then
			local p = still(star:Clone())
			p.Name, p.Material, p.Color, p.Transparency = "SeedBlossom" .. i, Enum.Material.Neon, seedColor, 1
			p.Parent = folder
			slot.Blossom = { Part = p, Size = p.Size / math.max(p.Size.X, p.Size.Y, p.Size.Z) }
		end
	end
	if not low then
		for i = 1, V.ReadyWisps do
			state.Orbiters[i] = ghost(folder, "ReadyWisp" .. i, true)
		end
		for i = 1, V.CastGhosts do
			state.Puffs[i] = ghost(folder, "CastGhost" .. i, false)
		end
		local light = Instance.new("PointLight")
		light.Name, light.Color = "LanternReadyLight", Color3.fromHex(V.ReadyColor)
		light.Range, light.Brightness, light.Shadows, light.Enabled = V.ReadyLightRange, 0, false, false
		light.Parent = f.Body
		state.Light = light
	end
	for _, p in f.Parts do
		local name = p:GetAttribute("SourceName") or p.Name
		if name == "Eye_L" or name == "Eye_R" or name == "Grin" then
			state.Face[p] = p.Material
		end
	end
	f.Seeds = state
end

local function width(fighter)
	return math.max(fighter.Body.Size.X, fighter.Body.Size.Z)
end

local function seedPosition(foe, i, count, phase, time)
	local radius = width(foe) * (0.5 + V.OrbitGap)
	local angle = phase + (i - 1) * TAU / math.max(count, 1)
	local offset =
		Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius * V.OrbitTilt, math.sin(angle) * radius)
	return foe.Body.Position + offset + Vector3.yAxis * math.sin(time * 3 + i) * V.Bob * width(foe)
end

local function hide(slot)
	slot.Core.Transparency = 1
	for _, p in { slot.Shell, slot.Flame } do
		p.Transparency = 1
	end
	if slot.Trail then
		slot.Trail.Enabled = false
	end
end

-- Ready / ReadyCancel reach here from CombatEffects (they skip the signature event list).
function Seeds.state(effects, f, e)
	local s = f.Seeds
	if e.Type == "SignatureReady" then
		if s.ReadyId == (e.ReadyId or e.Time) then
			return
		end
		s.ReadyId = e.ReadyId or e.Time
		s.ReadyAt = effects.Time
		s.ReadyUntil = (e.AutoAt or (e.Time + (e.Seconds or 2.5))) + 0.3
		arpeggio(effects, f, Sound.Seeds.Ready.Volume, Sound.Seeds.Ready.Gap)
	elseif e.Type == "ReadyCancel" then
		s.ReadyUntil = nil
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
			local at = seedPosition(foe, e.Count, e.Count, s.Phase, effects.Time)
			effects:Burst("ContactGlint", at, Color3.fromHex(V.SeedColor), f.LowDetail)
			if not f.LowDetail then
				effects:Burst("ContactGlint", at, Color3.fromHex(V.FlameColor), true)
			end
		end
		note(effects, f, e.Count or 1, Sound.Seeds.Plant)
		return true
	elseif e.Type == "SignatureStatus" and (e.Kind == "SeedLost" or e.Kind == "SeedFade") then
		for i = (e.Count or 0) + 1, Kit.MaxSeeds do
			if s.Slots[i].Core.Transparency < 1 then
				effects:Burst("GlassDust", s.Slots[i].Core.Position, Color3.fromHex(V.SeedColor), true)
			end
		end
		if e.Kind == "SeedLost" then
			local lost = Sound.Seeds.Lost
			play(effects, f, lost.Key, lost.Volume, lost.Pitch)
		end
		return true
	elseif e.Type == "CastStart" and e.Shape == "bloom" then
		s.ReadyUntil = nil
		s.Bloom = {
			Start = e.Time,
			Count = e.Pulses or math.max(s.Shown, 1),
			Released = 0,
			EndAt = e.Time + e.Windup + Kit.Duration + V.WispSeconds,
		}
		arpeggio(effects, f, Sound.Seeds.Bloom.Volume, Sound.Seeds.Bloom.Gap)
		if e.Manual then
			s.PuffAt = effects.Time
			for _, layer in Sound.Seeds.Manual do
				play(effects, f, layer.Key, layer.Volume, layer.Pitch, layer.At)
			end
		end
	elseif e.Type == "CastContact" and s.Bloom and not e.Missed then
		local b = s.Bloom
		b.Released += 1
		local wisp = s.Wisps[b.Released]
		local slot = s.Slots[b.Count - b.Released + 1]
		if wisp and slot then
			local from = if slot.Core.Transparency < 1 then slot.Core.Position else foe.Body.Position
			local side = effects.Scene.Frame.LookVector * (if b.Released % 2 == 0 then 1 else -1)
			local arc = V.WispArc * width(foe)
			wisp.From, wisp.Bend, wisp.Start = from, Vector3.yAxis * arc + side * arc * 0.4, e.Time
			wisp.Size = if wisp.Ghost then V.GhostSize * width(foe) else V.WispSize * width(foe)
			if wisp.Part then
				wisp.Part.Size = Vector3.one * wisp.Size
				fitTrail(wisp.Trail, wisp.Size)
			end
			wisp.Last = b.Released == b.Count
			if slot.Blossom then
				slot.Blossom.At, slot.Blossom.From = e.Time, from
			end
		end
	end
	return false
end

local function stepBlossoms(s, foe, time)
	for _, slot in s.Slots do
		local bl = slot.Blossom
		if not bl or not bl.At then
			continue
		end
		local k = (time - bl.At) / V.BlossomSeconds
		if k < 0 then
			continue
		end
		if k >= 1 then
			bl.At, bl.Part.Transparency = nil, 1
			continue
		end
		local grow = 1 - (1 - k) ^ 3
		bl.Part.CFrame = CFrame.new(bl.From) * workspace.CurrentCamera.CFrame.Rotation * CFrame.Angles(0, 0, k * 2)
		bl.Part.Size = bl.Size * V.BlossomScale * width(foe) * (0.3 + 0.7 * grow)
		bl.Part.Transparency = 0.05 + 0.95 * k * k
	end
end

-- Ready glow on Hollowlight itself: candle-flicker face, two orbiting wisps and a warm light.
local function stepReady(s, f, time, active)
	local ready = active and s.ReadyUntil ~= nil and time < s.ReadyUntil
	if not ready then
		s.ReadyUntil = if active then s.ReadyUntil else nil
	end
	local w = width(f)
	local intro = if ready then math.clamp((time - (s.ReadyAt or time)) / 0.25, 0, 1) else 0
	for i, g in s.Orbiters do
		if not ready then
			hideGhost(g)
			continue
		end
		local angle = time * V.ReadyHz * TAU + i * TAU / #s.Orbiters
		local radius = w * V.ReadyOrbit * (0.6 + 0.4 * intro)
		local at = f.Body.Position
			+ Vector3.new(math.cos(angle) * radius, math.sin(angle * 2) * 0.15 * w + 0.15 * w, math.sin(angle) * radius)
		placeGhost(g, at, w * 0.36 * intro, 0, math.sin(angle) * 0.4)
		if g and g.Trail then
			g.Trail.Enabled = true
		end
	end
	if s.Light then
		s.Light.Enabled = ready
		s.Light.Brightness = V.ReadyLight * intro * (0.75 + 0.25 * math.noise(time * V.ReadyFlickerHz, f.Side))
	end
	return ready, math.noise(time * V.ReadyFlickerHz, f.Side * 3.1) > -0.15
end

-- Manual cast: a ring of ghosts puffs out of Hollowlight and fades.
local function stepPuffs(s, f, time)
	if not s.PuffAt then
		return
	end
	local k = (time - s.PuffAt) / V.CastSeconds
	if k >= 1 or k < 0 then
		s.PuffAt = nil
		for _, g in s.Puffs do
			hideGhost(g)
		end
		return
	end
	local w = width(f)
	local out = 1 - (1 - k) ^ 3
	local right = workspace.CurrentCamera.CFrame.RightVector
	for i, g in s.Puffs do
		local angle = i * TAU / #s.Puffs + k * 0.8
		local dir = right * math.cos(angle) + Vector3.yAxis * math.sin(angle)
		placeGhost(g, f.Body.Position + dir * w * V.CastRadius * out, w * 0.34 * (0.5 + 0.5 * out), k * k, angle)
	end
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
	-- Orbit phase accumulates so ripening can speed it up without a jump.
	local dt = math.clamp(time - (s.LastTime or time), 0, 0.1)
	s.LastTime = time
	local ripe = count >= Kit.MaxSeeds
	local spin = if s.Bloom then V.RipeSpin * 1.6 elseif ripe then V.RipeSpin else 1
	s.Phase += dt * V.OrbitHz * TAU * spin
	s.Shown = count
	local ripePulse = if ripe then 1 + V.RipeGlow * (0.5 + 0.5 * math.sin(time * V.RipeHz * TAU)) else 1
	for i, slot in s.Slots do
		if i > count or foe.Broken then
			hide(slot)
			continue
		end
		local grow = math.clamp((time - slot.BornAt) / V.PopInSeconds, 0, 1)
		local pop = (1 + math.sin(grow * math.pi) * 0.35) * flare * ripePulse
		local at = seedPosition(foe, i, count, s.Phase, time)
		local size = V.SeedSize * width(foe) * pop
		slot.Core.Size, slot.Core.Position, slot.Core.Transparency = Vector3.one * size, at, 0
		if slot.Shell then
			slot.Shell.Size = Vector3.one * size * V.ShellScale
			slot.Shell.Position = at
			slot.Shell.Transparency = slot.Shell:GetAttribute("RestTransparency")
				+ 0.15 * math.sin(time * 6 + i)
				- (ripePulse - 1) * 0.6
		end
		if slot.Flame then
			local flicker = 1 + 0.35 * math.noise(time * V.FlameHz, i, f.Side)
			slot.Flame.Size = Vector3.one * size * V.FlameScale * flicker
			slot.Flame.Position = at + Vector3.yAxis * size * 0.55
			slot.Flame.Transparency = 0.1
		end
		if slot.Trail then
			fitTrail(slot.Trail, size * 0.8)
			slot.Trail.Enabled = true
		end
	end
	stepBlossoms(s, foe, time)
	for _, wisp in s.Wisps do
		if not wisp.Start then
			continue
		end
		local t = (time - wisp.Start) / V.WispSeconds
		local target = f.Body.Position
		if t < 0 then
			continue
		end
		if t >= 1 or not active then
			wisp.Start = nil
			hideGhost(wisp.Ghost)
			if wisp.Part then
				wisp.Part.Transparency = 1
				if wisp.Trail then
					wisp.Trail.Enabled = false
				end
			end
			if active then
				s.GlowUntil = time + V.FaceGlowSeconds
				effects:Burst("ContactGlint", target, Color3.fromHex(V.SeedColor), f.LowDetail)
				local home = if wisp.Last then Sound.Seeds.LastHome else Sound.Seeds.Home
				play(effects, f, home.Key, home.Volume, home.Pitch)
				if wisp.Last and not f.LowDetail then
					HollowlightFX.pressure(effects.Root, target)
				end
			end
			continue
		end
		local eased = 1 - (1 - t) ^ 2
		local mid = (wisp.From + target) / 2 + wisp.Bend
		local at = wisp.From:Lerp(mid, eased):Lerp(mid:Lerp(target, eased), eased)
		if wisp.Ghost then
			placeGhost(wisp.Ghost, at, wisp.Size * (0.7 + 0.3 * math.sin(t * math.pi)), 0, (0.5 - t) * 0.8)
			if wisp.Ghost.Trail then
				wisp.Ghost.Trail.Enabled = true
			end
		else
			wisp.Part.Position, wisp.Part.Transparency = at, 0
			if wisp.Trail then
				wisp.Trail.Enabled = true
			end
		end
	end
	local ready, candle = stepReady(s, f, time, active)
	stepPuffs(s, f, time)
	-- Ripe or just fed: the face glows; while Ready it flickers like a candle instead.
	local lit = if ready then candle else active and (count >= Kit.MaxSeeds or time < (s.GlowUntil or -1))
	for part, material in s.Face do
		part.Material = if lit then Enum.Material.Neon else material
	end
end

function Seeds.reset(f)
	local s = f.Seeds
	s.Bloom, s.Shown, s.GlowUntil, s.ReadyUntil, s.PuffAt = nil, 0, nil, nil, nil
	for _, slot in s.Slots do
		hide(slot)
		if slot.Blossom then
			slot.Blossom.At, slot.Blossom.Part.Transparency = nil, 1
		end
	end
	for _, wisp in s.Wisps do
		wisp.Start = nil
		hideGhost(wisp.Ghost)
		if wisp.Part then
			wisp.Part.Transparency = 1
			if wisp.Trail then
				wisp.Trail.Enabled = false
			end
		end
	end
	for _, g in s.Orbiters do
		hideGhost(g)
	end
	for _, g in s.Puffs do
		hideGhost(g)
	end
	if s.Light then
		s.Light.Enabled = false
	end
	for part, material in s.Face do
		part.Material = material
	end
end

return Seeds
