-- Reusable VFX for the launch powers in ROSTER_V2 §3–4 (zone hazards, drain_contact, Cycle brews, guard Riposte,
-- aimed rainbow dash, Phoenix rebirth). Builders take the PowerFX engine and plain world-space specs, so they wire
-- to A's events with a few lines once the rules land (see Launch.event and docs/vfx/POWER_VFX_V2.md §5).
local Launch = {}
local WHITE = Color3.new(1, 1, 1)
local hex = Color3.fromHex

local function cam()
	return workspace.CurrentCamera.CFrame
end

-- Zone hazard -------------------------------------------------------------------------------------------------------
-- spec: { At = Vector3, Radius = studs, Delay = s (telegraph before live), Seconds = live time, Kind = "bubble" |
--         "honey" | "rune", Color, Accent, Key, Start }. Every zone draws a ground ring + drop shadow for depth.
-- Returns a handle: handle:Pop(point) ends it with a burst; handle:End() fades it.
function Launch.zone(fx, side, spec)
	local color = spec.Color or (fx:Colors(side))
	local accent = spec.Accent or select(2, fx:Colors(side))
	local radius = spec.Radius or 1.2
	local delay = spec.Delay or 0
	local seconds = delay + (spec.Seconds or 4)
	local kind = spec.Kind or "bubble"
	local key = spec.Key or ("zone:" .. side)
	local at = spec.At
	local parts = {}
	local actor, rim, rim2
	if kind == "bubble" then
		actor = fx:Part("Ball", hex("#8FE6FF"), Enum.Material.ForceField)
		rim, rim2 = fx:Part("Ring", hex("#FF9BE0")), fx:Part("Ring", hex("#9BFFE8"))
	elseif kind == "honey" then
		actor = fx:Part("BubbleDome", color, Enum.Material.Glass)
		rim, rim2 = fx:Part("Ball", hex("#C96A00"), Enum.Material.Glass), fx:Part("Ring", accent)
	else -- rune
		actor = fx:Part("ShockCrown", accent)
		rim, rim2 = fx:Part("Ring", color), fx:Part("NovaStar", accent)
	end
	table.insert(parts, actor)
	table.insert(parts, rim)
	table.insert(parts, rim2)
	local floor = fx:Ground(at)
	local ground = fx:Part("ShockCrown", color)
	local fill = fx:Part("Ring", accent) -- telegraph: fills toward full size during Delay
	table.insert(parts, ground)
	table.insert(parts, fill)
	local handle = { Live = delay <= 0 }
	handle.Effect = fx:Spawn({
		Side = side,
		Key = key,
		Start = spec.Start,
		Seconds = seconds,
		Parts = parts,
		Step = function(_, age, k)
			local live = age >= delay
			handle.Live = live
			local telegraph = if delay > 0 then math.clamp(age / delay, 0, 1) else 1
			local appear = fx.pop((age - (if kind == "rune" then 0 else delay * 0.6)) / 0.3)
			local fade = fx.smooth((k - 0.88) / 0.12)
			local bob = Vector3.yAxis * math.sin(age * 2.4) * 0.12
			local pos = at + (if kind == "rune" then Vector3.zero else bob)
			-- Ground ring + telegraph fill (depth readability from the straight-on camera).
			fx:Fit(ground, radius * 2.2 * fx.easeOut(age / 0.25))
			ground.CFrame = CFrame.new(pos.X, floor.Y, pos.Z) * CFrame.Angles(math.pi / 2, 0, age * 0.8)
			ground.Transparency = (if live then 0.2 else 0.45) + 0.8 * fade
			fx:Fit(fill, math.max(0.05, radius * 2 * telegraph))
			fill.CFrame = CFrame.new(pos.X, floor.Y + 0.03, pos.Z) * CFrame.Angles(math.pi / 2, 0, 0)
			fill.Transparency = if live then 1 else 0.3
			if kind == "bubble" then
				local wob = 1 + math.sin(age * 7) * 0.04
				local d = radius * 2 * appear
				actor.Size = Vector3.new(d * wob, d / wob, d * wob)
				actor.CFrame = CFrame.new(pos)
				actor.Transparency = 0.05 + 0.95 * fade
				fx:Fit(rim, d * 1.02)
				rim.CFrame = fx.face(pos) * CFrame.Angles(0, 0, age * 0.7)
				rim.Transparency = 0.35 + 0.65 * fade
				fx:Fit(rim2, d * 0.95)
				rim2.CFrame = fx.face(pos) * CFrame.Angles(0, 0, -age)
				rim2.Transparency = 0.55 + 0.45 * fade
			elseif kind == "honey" then
				local d = radius * 2 * appear
				local squish = 1 + math.sin(age * 4) * 0.06
				fx:Fit(actor, d)
				actor.Size = Vector3.new(actor.Size.X * squish, actor.Size.Y / squish, actor.Size.Z * squish)
				actor.CFrame = fx.face(pos)
				actor.Transparency = 0.15 + 0.85 * fade
				rim.Size = Vector3.one * d * 0.45
				rim.CFrame = CFrame.new(pos)
				rim.Transparency = 0.25 + 0.75 * fade
				fx:Fit(rim2, d * 1.1)
				rim2.CFrame = fx.face(pos) * CFrame.Angles(0, 0, age * 0.5)
				rim2.Transparency = 0.5 + 0.5 * fade
			else
				-- Rune: a flat disc above the floor at the predicted spot plus a rotating star; brightens when live.
				local d = radius * 2 * fx.easeOut(age / 0.3)
				fx:Fit(actor, d)
				actor.CFrame = CFrame.new(pos.X, floor.Y + 0.08, pos.Z) * CFrame.Angles(math.pi / 2, 0, -age * 1.2)
				actor.Transparency = (if live then 0.05 else 0.35) + 0.95 * fade
				fx:Fit(rim, d * 0.75)
				rim.CFrame = CFrame.new(pos.X, floor.Y + 0.1, pos.Z) * CFrame.Angles(math.pi / 2, 0, age * 2)
				rim.Transparency = 0.25 + 0.75 * fade
				fx:Fit(rim2, d * 0.5)
				rim2.CFrame = CFrame.new(pos.X, floor.Y + 0.12, pos.Z) * CFrame.Angles(math.pi / 2, 0, age)
				rim2.Transparency = 0.2 + 0.8 * fade
			end
		end,
	})
	if kind ~= "rune" then
		fx:Shadow(side, at, radius * 0.9, seconds, { Key = key .. ":shadow" })
	end
	function handle:Pop(point)
		fx:StopKey(key)
		fx:StopKey(key .. ":shadow")
		local p = point or at
		fx:Flash(side, p, if kind == "bubble" then WHITE else color, radius * 2, 0.14)
		fx:Ring(side, p, accent, radius, radius * 4, 0.32, { Kind = "ShockCrown", Spin = 3 })
		fx:Chips(side, p, if kind == "honey" then color else hex("#BFF3FF"), 6, 5, 0.5, {
			Kind = if kind == "honey" then "BubbleDome" else "Droplet",
			Size = 0.4,
			Up = 2,
		})
		fx:Glints(side, p, WHITE, 10)
		-- SFX: zone pop.
	end
	function handle:End()
		fx:StopKey(key)
		fx:StopKey(key .. ":shadow")
	end
	return handle
end

-- A star falls from above onto a point (Crystal Ball's strike after the rune's Delay).
function Launch.strike(fx, side, at, spec)
	spec = spec or {}
	local color = spec.Color or (fx:Colors(side))
	local accent = spec.Accent or select(2, fx:Colors(side))
	local fall = spec.Seconds or 0.3
	local star = fx:Part("NovaStar", accent)
	fx:Trail(star, ColorSequence.new(WHITE, color), 0.25, 0.9)
	local from = at + Vector3.new(1.2, 9, 0)
	fx:Spawn({
		Side = side,
		Start = spec.Start,
		Seconds = fall,
		Parts = { star },
		Step = function(_, age, k)
			local pos = from:Lerp(at, fx.easeIn(k))
			fx:Fit(star, 1.3)
			star.CFrame = fx.face(pos) * CFrame.Angles(0, 0, age * 10)
			star.Transparency = 0.02
		end,
		Stop = function()
			fx:Flash(side, at, accent, 2.6, 0.16)
			fx:Ring(side, at, accent, 0.8, 5.5, 0.38, { Kind = "NovaStar", Spin = 4 })
			fx:GroundRing(side, at, color, 3, 0.45)
			fx:Spokes(side, at, accent, 8, 2.4, 0.28, { Alternate = WHITE })
			fx:Light(side, at, accent, 0.35, 5)
		end,
	})
	fx:Shadow(side, at, 0.9, fall, {})
end

-- Charge-steal beam: from the foe to the drainer, in the foe's colour, motes travelling home, then a flare.
function Launch.drain(fx, toSide, spec)
	spec = spec or {}
	local fromSide = 3 - toSide
	local foeColor = spec.FoeColor or (fx:Colors(fromSide))
	local color = spec.Color or (fx:Colors(toSide))
	local seconds = spec.Seconds or 0.55
	local a = function()
		return (fx:Body(fromSide))
	end
	local b = function()
		return (fx:Body(toSide))
	end
	fx:Beam(toSide, a, b, ColorSequence.new(foeColor, color), 0.7, seconds, {
		Alpha = 0.1,
		Curve = function(age)
			return math.sin(age * 18) * 0.8
		end,
	})
	fx:Beam(toSide, a, b, WHITE, 0.22, seconds * 0.9, {})
	local motes = {}
	for i = 1, fx:Count(toSide, 6) do
		motes[i] = fx:Part("CrystalChip", foeColor)
		fx:Fit(motes[i], 0.35)
	end
	fx:Spawn({
		Side = toSide,
		Seconds = seconds,
		Parts = motes,
		Step = function(_, age, k)
			for i, p in motes do
				local t = ((age * 2.2) + i / #motes) % 1
				p.CFrame = CFrame.new(a():Lerp(b(), fx.smooth(t)) + Vector3.yAxis * math.sin(t * math.pi) * 0.6)
				p.Transparency = 0.05 + 0.95 * fx.smooth((k - 0.85) / 0.15)
			end
		end,
	})
	fx:Flash(toSide, b, color, 2.4, 0.18, { Delay = seconds * 0.7 })
	fx:Light(toSide, b, color, seconds + 0.2, 5)
	fx:Ring(fromSide, a, foeColor, 2.6, 0.4, 0.3, { Ease = "in", Alpha = 0.3 })
	-- SFX: drain zap.
end

-- Brew swirl: two coloured bands spiral around the flask for `seconds` (shows the next Cycle brew).
function Launch.brew(fx, side, color, seconds, spec)
	spec = spec or {}
	local bands = { fx:Part("HalfRing", color), fx:Part("HalfRing", color:Lerp(WHITE, 0.4)) }
	fx:Spawn({
		Side = side,
		Key = spec.Key or ("brew:" .. side),
		Seconds = seconds or 1,
		Parts = bands,
		Step = function(_, age, k)
			local pos, size = fx:Body(side)
			for i, p in bands do
				fx:Fit(p, size * (1.25 - i * 0.12) * fx.pop(age / 0.25))
				p.CFrame = CFrame.new(pos + Vector3.yAxis * math.sin(age * 3 + i) * size * 0.2)
					* CFrame.Angles(0.4 * (if i == 1 then 1 else -1), age * 6 * (if i == 1 then 1 else -1.2), 0)
					* CFrame.Angles(math.pi / 2, 0, 0)
				p.Transparency = 0.15 + 0.85 * fx.smooth((k - 0.85) / 0.15)
			end
		end,
	})
end

-- Guard riposte: a gold block ring, a short beat, then a roar shockwave with a ground ring.
function Launch.roar(fx, side, spec)
	spec = spec or {}
	local color = spec.Color or (fx:Colors(side))
	local accent = spec.Accent or select(2, fx:Colors(side))
	local pos = fx:Body(side)
	local range = spec.Range or 5
	fx:Ring(side, pos, hex("#FFC23D"), 1.2, 4, 0.2, { Kind = "ShockCrown" })
	local bloom = fx:Part("BlastBloom", color)
	fx:Spawn({
		Side = side,
		Start = fx:Time() + 0.06,
		Seconds = 0.45,
		Parts = { bloom },
		Step = function(_, _, k)
			fx:Fit(bloom, range * 1.4 * fx.easeOut(k))
			bloom.CFrame = fx.face((fx:Body(side))) * CFrame.Angles(0, 0, k)
			bloom.Transparency = 0.3 + 0.7 * fx.easeIn(k)
		end,
	})
	fx:Ring(side, (fx:Body(side)), accent, 1, range * 2, 0.45, { Kind = "ShockCrown", Delay = 0.06, Spin = 2 })
	fx:Ring(side, (fx:Body(side)), WHITE, 0.8, range * 1.4, 0.35, { Delay = 0.1, Alpha = 0.2 })
	fx:GroundRing(side, pos, color, range, 0.5, { Delay = 0.06 })
	fx:Light(side, pos, color, 0.45, 6)
	fx:HeroBloom(side, 0.7)
	-- SFX: low-glass ROAR.
end

-- Aimed rainbow dash: a rainbow trail on the dashing body for `seconds`, hoof-spark stars behind it.
function Launch.dash(fx, side, seconds, spec)
	spec = spec or {}
	local rainbow = ColorSequence.new({
		ColorSequenceKeypoint.new(0, hex("#FF6B8B")),
		ColorSequenceKeypoint.new(0.2, hex("#FFB347")),
		ColorSequenceKeypoint.new(0.4, hex("#FFE45C")),
		ColorSequenceKeypoint.new(0.6, hex("#6CFF9A")),
		ColorSequenceKeypoint.new(0.8, hex("#5FB4FF")),
		ColorSequenceKeypoint.new(1, hex("#C9A8FF")),
	})
	local anchor = fx:Part("Anchor", WHITE)
	local size = select(2, fx:Body(side))
	fx:Trail(anchor, rainbow, 0.4, size * 0.9, NumberSequence.new(0.05, 1))
	local nextStar = 0
	fx:Spawn({
		Side = side,
		Key = spec.Key or ("dash:" .. side),
		Seconds = seconds or 1.5,
		Parts = { anchor },
		Step = function(_, age)
			local pos = fx:Body(side)
			anchor.CFrame = CFrame.lookAt(pos, pos + cam().LookVector)
			if age >= nextStar then
				nextStar = age + 0.08
				fx:Glints(side, pos, hex("#FFE45C"), 2, { Speed = NumberRange.new(0.5, 2) })
			end
		end,
	})
	fx:Flash(side, (fx:Body(side)), WHITE, 2.2, 0.14)
	-- SFX: chime-whinny on launch.
end

-- A guard shattered by a piercing hit: glass plate shards fly, a white X flash.
function Launch.pierce(fx, side, at, spec)
	spec = spec or {}
	local color = spec.Color or (fx:Colors(side))
	fx:Flash(side, at, WHITE, 2.8, 0.12)
	fx:Chips(side, at, hex("#FFE7A8"), 8, 8, 0.55, { Kind = "CrystalShard", Size = 0.6, Up = 2, Alternate = color })
	fx:Ring(side, at, color, 0.6, 5, 0.3, { Kind = "NovaStar", Spin = 5 })
	fx:Light(side, at, color, 0.3, 5)
end

-- Phoenix rebirth: light cracks the body, the wings flare and an ember swirl gathers (Gather seconds), then a
-- fire-glass ring pulse, heal shimmer, ground ring and bloom.
function Launch.rebirth(fx, side, spec)
	spec = spec or {}
	local color = spec.Color or hex("#FF7A2E")
	local accent = spec.Accent or hex("#FFD34E")
	local gatherSeconds = spec.Gather or 0.45
	local range = spec.Range or 6
	local pos, size = fx:Body(side)
	local embers = {}
	for i = 1, fx:Count(side, 10) do
		embers[i] = fx:Part("CrystalChip", if i % 2 == 0 then accent else color)
		fx:Fit(embers[i], 0.32)
	end
	local cracks = {}
	for i = 1, fx:Count(side, 6) do
		cracks[i] = fx:Part("Block", accent)
	end
	local parts = table.clone(embers)
	for _, p in cracks do
		table.insert(parts, p)
	end
	fx:Move(side, "wiggle", gatherSeconds, 1.2)
	fx:Spawn({
		Side = side,
		Seconds = gatherSeconds,
		Parts = parts,
		Step = function(_, age, k)
			local p0 = fx:Body(side)
			local c = cam()
			for i, p in embers do
				local a = i / #embers * math.pi * 2 + age * (6 + 10 * k)
				local r = size * (2.2 - 1.6 * fx.easeIn(k))
				p.CFrame = CFrame.new(
					p0
						+ c.RightVector * math.cos(a) * r
						+ Vector3.yAxis * (math.sin(a * 2) * 0.4 + k * 0.6)
						+ c.UpVector * math.sin(a) * r * 0.5
				)
				p.Transparency = 0.05
			end
			for i, p in cracks do
				local a = i / #cracks * math.pi * 2
				p.Size = Vector3.new(0.08, size * 0.5 * fx.easeOut(k), 0.08)
				p.CFrame = fx.face(p0) * CFrame.Angles(0, 0, a) * CFrame.new(0, size * 0.22, -size * 0.3)
				p.Transparency = 0.05
			end
		end,
	})
	local l = fx:Light(side, function()
		return (fx:Body(side))
	end, color, gatherSeconds + 0.5, 7, 16)
	if l then
		l.Rise = 0.5
	end
	-- Release beat.
	fx:Flash(side, function()
		return (fx:Body(side))
	end, accent, 3.2, 0.2, { Delay = gatherSeconds })
	fx:Ring(side, function()
		return (fx:Body(side))
	end, color, 1, range * 2, 0.5, { Kind = "ShockCrown", Delay = gatherSeconds, Spin = 3 })
	fx:Ring(side, function()
		return (fx:Body(side))
	end, accent, 0.8, range * 1.5, 0.42, { Delay = gatherSeconds + 0.05, Spin = -4 })
	fx:GroundRing(side, pos, color, range, 0.6, { Delay = gatherSeconds })
	fx:Spawn({
		Side = side,
		Start = fx:Time() + gatherSeconds,
		Seconds = 0.6,
		Step = function(_, age)
			if math.floor(age * 20) ~= math.floor((age - 1 / 60) * 20) then
				fx:Emit(side, "Fire", CFrame.lookAt(fx:Body(side), fx:Body(side) + Vector3.yAxis), 3, accent, {
					Speed = NumberRange.new(3, 6),
					Spread = Vector2.new(60, 60),
				})
			end
		end,
	})
	fx:Spawn({
		Side = side,
		Start = fx:Time() + gatherSeconds,
		Seconds = 0.01,
		Step = function()
			fx:HeroBloom(side, 1.2)
			fx:Glints(
				side,
				(fx:Body(side)),
				hex("#FFF3B0"),
				16,
				{ Speed = NumberRange.new(2, 5), Accel = Vector3.new(0, 5, 0) }
			)
			return false
		end,
	})
	-- SFX: rebirth flare (whoomph + rising chime).
end

-- Event wiring for A's planned fields (ROSTER_V2 §3). Returns true when a launch builder handled the moment.
function Launch.event(fx, e, ctx)
	local side = e.Side
	if e.Type == "CastRelease" and e.Shape == "zone" and e.Point then
		local at = fx.Scene.Frame:PointToWorldSpace(Vector3.new(e.Point[1], e.Point[2], e.Point[3]))
		local kind = e.Kind or "bubble"
		local zone = Launch.zone(fx, side, {
			At = at,
			Radius = e.Range,
			Delay = e.Delay,
			Seconds = e.Duration,
			Kind = kind,
			Start = e.Time,
		})
		if ctx then
			ctx.Zone = zone
		end
		if kind == "rune" then
			Launch.strike(fx, side, at, { Start = e.Time + math.max(0, (e.Delay or 0.6) - 0.3), Seconds = 0.3 })
		end
		return true
	elseif e.Type == "SignatureStatus" and e.Kind == "Drain" then
		Launch.drain(fx, side)
		return true
	elseif e.Type == "CastStart" and e.Rebirth then
		Launch.rebirth(fx, side, { Gather = e.Windup })
		return true
	elseif e.Type == "CastStart" and e.Riposte then
		Launch.roar(fx, side, {})
		return true
	elseif e.Type == "CastRelease" and e.PierceGuard then
		Launch.dash(fx, side, e.Duration or 1.5)
		return true
	end
	return false
end

return Launch
