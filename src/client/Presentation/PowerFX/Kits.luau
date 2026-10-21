-- Per-kit power moments (docs/vfx/POWER_VFX_V2.md §4). Each kit may define:
--   Windup(fx, side, e)            CastStart: anticipation over e.Windup
--   Release(fx, side, e, ctx)      CastRelease: ctx = { Origin, Direction, Event, Shots, End }
--   Hit(fx, side, e, point, ctx)   CastContact landed      Miss(fx, side, e, ctx)   CastContact missed
--   Payoff(fx, side, e, point)     SignatureContact        Block(fx, side, e)       SignatureBlock (guard owner)
--   Status(fx, side, e)            SignatureStatus         Armed(fx, side, age, k, pos, size)  per frame while armed
-- Anything a kit leaves out falls back to the shape default at the bottom.
local RS = game:GetService("ReplicatedStorage")
local Path = require(RS.Shared.AttackPath)
local Kits = {}

local WHITE = Color3.new(1, 1, 1)
local hex = Color3.fromHex

local function cam()
	return workspace.CurrentCamera.CFrame
end

local function fan(direction, i, count, arc)
	local right = direction:Cross(Vector3.yAxis)
	if right.Magnitude < 0.0001 or count <= 1 then
		return direction
	end
	local angle = ((i - 1) / (count - 1) - 0.5) * (arc or 0)
	return (direction * math.cos(angle) + right.Unit * math.sin(angle)).Unit
end
Kits.fan = fan

local function bodyAt(fx, side)
	return function()
		return (fx:Body(side))
	end
end

-- Generic anticipation: motes spiral into the body, a ring closes in, the body shivers; Rare+ builds a light;
-- Epic+ ends in a tight bright "hush" (second stage). opts: At (function), MoteKind, Motes, Motion, Light.
local function gather(fx, side, e, opts)
	opts = opts or {}
	local color, accent = fx:Colors(side)
	local windup = math.max(0.08, e.Windup or 0.3)
	local rank = fx:Rank(side)
	local two = rank >= 3 or opts.TwoStage
	fx:Move(side, opts.Motion or "wiggle", windup, opts.MotionAmount)
	local at = opts.At or bodyAt(fx, side)
	local count = fx:Count(side, opts.Motes or (3 + rank * 2))
	local motes = {}
	for i = 1, count do
		motes[i] = fx:Part(opts.MoteKind or "CrystalChip", if i % 2 == 0 then accent else color)
		fx:Fit(motes[i], opts.MoteSize or 0.38)
	end
	local ring = fx:Part(opts.RingKind or "Ring", color)
	local parts = table.clone(motes)
	table.insert(parts, ring)
	local size = select(2, fx:Body(side))
	fx:Spawn({
		Side = side,
		Seconds = windup,
		Parts = parts,
		Step = function(_, age, k)
			local pos = at(age)
			local c = cam()
			local g = if two then math.min(k / 0.7, 1) else k
			for i, p in motes do
				local angle = i / count * math.pi * 2 + age * (5 + 8 * k)
				local r = size * (opts.Spread or 1.9) * (1 - 0.85 * fx.easeIn(g))
				p.CFrame = CFrame.new(pos + c.RightVector * math.cos(angle) * r + c.UpVector * math.sin(angle) * r)
					* CFrame.Angles(angle, angle * 0.5, 0)
				p.Transparency = 0.05 + 0.95 * fx.smooth((g - 0.9) / 0.1)
			end
			local hush = if two then fx.smooth((k - 0.7) / 0.3) else 0
			fx:Fit(ring, size * (1.7 - 0.9 * k - 0.25 * hush))
			ring.CFrame = fx.face(pos) * CFrame.Angles(0, 0, -age * 4)
			ring.Transparency = 0.55 - 0.4 * k - 0.15 * hush + (if hush > 0 then math.sin(age * 60) * 0.08 else 0)
		end,
	})
	if rank >= 2 and opts.Light ~= false then
		local l = fx:Light(side, at, color, windup + 0.12, fx.C.Light.Brightness * (if two then 1.3 else 1))
		if l then
			l.Rise = 0.85
		end
	end
end
Kits.gather = gather

-- A travelling shot that follows the authoritative path and disappears when its pulse resolves.
-- opts: Kind, Size, Core (white inner part), Trail (lifetime), TrailWidth, Spin, FaceCamera, Alternate.
local function shots(fx, side, e, ctx, opts)
	opts = opts or {}
	local color, accent = fx:Colors(side)
	local count = if e.Shape == "volley" then e.Pulses or 1 else 1
	local duration = math.max(0.05, e.Duration or 0.5)
	for i = 1, count do
		local shot = { Done = e.Resolved and e.Resolved[if e.Path == "return" then 2 else i] }
		ctx.Shots[i] = shot
		if shot.Done then
			continue
		end
		local dir = fan(ctx.Direction, i, count, e.Arc)
		local p = fx:Part(opts.Kind or "Droplet", if opts.Alternate and i % 2 == 0 then opts.Alternate else color)
		fx:Fit(p, opts.Size or math.max(0.9, (e.Radius or 0.2) * 4))
		local core
		if opts.Core ~= false then
			core = fx:Part(opts.CoreKind or "Ball", WHITE)
			core.Size = Vector3.one * (opts.Size or 0.9) * 0.45
		end
		local trailColor = ColorSequence.new({
			ColorSequenceKeypoint.new(0, WHITE),
			ColorSequenceKeypoint.new(0.25, color),
			ColorSequenceKeypoint.new(1, accent),
		})
		fx:Trail(p, trailColor, opts.Trail or 0.22, opts.TrailWidth or (opts.Size or 0.9) * 0.9)
		local parts = { p }
		if core then
			table.insert(parts, core)
		end
		shot.Effect = fx:Spawn({
			Side = side,
			Start = e.Time,
			Seconds = duration,
			Parts = parts,
			Step = function(_, age, k)
				if shot.Done then
					return false
				end
				-- World-fixed like the server's shot; a returning shot (Prism Blade, Fishbowl) is caught by the
				-- glassy where it is now, not where it threw from.
				local from = ctx.Origin
				if e.Path == "return" and k > 0.5 and ctx.Here then
					from = ctx.Origin:Lerp(ctx.Here(), fx.smooth((k - 0.5) / 0.5))
				end
				local pos = from + dir * (e.Range or 6) * Path.distance(k, e.Path)
				-- Volleys fan in depth (true to the server); a small vertical stagger keeps them readable side-on.
				pos += Vector3.yAxis * ((i - (count + 1) / 2) * 0.35 * math.min(1, k * 4))
				shot.Position = pos
				local spin = age * (opts.Spin or 10)
				if opts.FaceCamera then
					p.CFrame = fx.face(pos) * CFrame.Angles(0, 0, spin)
				else
					p.CFrame = CFrame.lookAt(pos, pos + dir)
						* CFrame.Angles(0, 0, spin)
						* (opts.Rotate or CFrame.identity)
				end
				p.Transparency = 0.02 + 0.98 * fx.smooth((k - 0.9) / 0.1)
				if core then
					core.CFrame = CFrame.new(pos)
					core.Transparency = 0.1 + 0.9 * fx.smooth((k - 0.9) / 0.1)
				end
				if opts.Step then
					opts.Step(pos, age, k, i)
				end
			end,
		})
	end
end
Kits.shots = shots

-- A thick ray: white core + coloured sheath, thins out instead of fading. The end follows ctx.End (contact point).
local function ray(fx, side, e, ctx, opts)
	opts = opts or {}
	local color, accent = fx:Colors(side)
	local seconds = opts.Seconds or 0.5
	local width = opts.Width or 0.55
	-- Both ends are live: the ray leaves the caster as drawn and stays on the glass it struck.
	local finish = function()
		if ctx.EndAt then
			return ctx.EndAt()
		end
		return ctx.End or (ctx.Here() + ctx.Direction * (e.Range or 8))
	end
	local start = opts.Start or ctx.Here
	local shape = function(k)
		return fx.pop(k / 0.12) * (1 - fx.smooth((k - 0.25) / 0.75))
	end
	fx:Beam(
		side,
		start,
		finish,
		opts.Sheath or color,
		width * 2.4,
		seconds,
		{ Shape = shape, Alpha = 0.2, Emission = 0 }
	)
	fx:Beam(side, start, finish, WHITE, width, seconds * 0.85, { Shape = shape })
	if opts.Rainbow and not fx:Low(side) then
		local rainbow = ColorSequence.new({
			ColorSequenceKeypoint.new(0, hex("#FF6B8B")),
			ColorSequenceKeypoint.new(0.25, hex("#FFD34E")),
			ColorSequenceKeypoint.new(0.5, hex("#6CFF9A")),
			ColorSequenceKeypoint.new(0.75, hex("#5FB4FF")),
			ColorSequenceKeypoint.new(1, hex("#C9A8FF")),
		})
		fx:Beam(side, start, finish, rainbow, width * 1.7, seconds * 0.9, {
			Shape = function(k)
				return shape(k) * (1 + 0.15 * math.sin(k * 40))
			end,
			Alpha = 0,
			Emission = 0,
		})
	end
	fx:Flash(side, start, color, 1.6, 0.14)
	fx:Ring(side, start, accent, 0.5, 2.6, 0.22, { Rotation = fx.tilted(ctx.Direction), Alpha = 0.1 })
end
Kits.ray = ray

-- A cone that flows outward in pulses: sheets oriented along the direction, particles and chips.
local function cone(fx, side, e, ctx, opts)
	opts = opts or {}
	local color, accent = fx:Colors(side)
	local pulses = e.Pulses or 1
	local duration = math.max(0.1, e.Duration or 0.3)
	local range, arc = e.Range or 5.5, e.Arc or 0.9
	for pulse = 1, pulses do
		local delay = (pulse - 1) * duration / pulses
		local sheets = fx:Count(side, opts.Sheets or 2)
		for s = 1, sheets do
			local p = fx:Part(opts.SheetKind or "PuffSheet", if s % 2 == 0 then accent else color)
			local roll = (s - 1) / math.max(1, sheets) * math.pi + pulse * 0.7
			fx:Spawn({
				Side = side,
				Start = fx:Time() + delay + (s - 1) * 0.03,
				Seconds = opts.SheetSeconds or 0.42,
				Parts = { p },
				Step = function(_, _, k)
					-- A puff travelling out along the cone in the camera plane, growing to the cone's width.
					local d = range * fx.easeOut(k) * 0.85
					local w = math.max(0.6, 2 * d * math.tan(arc / 2)) * (opts.Width or 1)
					local base = fx.Base[p:GetAttribute("PowerFXKind")]
					-- The cone grows from the caster's mouth as it swings, toward the glass once a pulse landed.
					local dir = ctx.Aim()
					p.Size = Vector3.new(w * 1.25, w * base.Y / base.X * 1.25, base.Z)
					p.CFrame = fx.along(fx.front(ctx.Here() + dir * d, 0.6), dir) * CFrame.Angles(0, 0, roll * 0.15)
					p.Transparency = 0.12 + 0.88 * fx.easeIn(k)
				end,
			})
		end
		fx:Spawn({
			Side = side,
			Start = fx:Time() + delay,
			Seconds = 0.01,
			Step = function()
				local origin, dir = ctx.Here(), ctx.Aim()
				local look = CFrame.lookAt(origin, origin + dir)
				fx:Emit(
					side,
					opts.Particle or "Sparkle",
					look,
					opts.ParticleCount or 14,
					opts.ParticleColor or accent,
					{
						Speed = NumberRange.new(range * 1.2, range * 2),
						Spread = Vector2.new(math.deg(arc) * 0.5, math.deg(arc) * 0.5),
						Size = opts.ParticleSize or 1.4,
						Lifetime = NumberRange.new(0.3, 0.5),
					}
				)
				if opts.Chips ~= 0 then
					fx:Chips(side, origin, color, opts.Chips or 4, range * 2.2, 0.4, {
						Kind = opts.ChipKind or "CrystalChip",
						Direction = dir,
						Cone = arc * 0.5,
						Up = 0.5,
						Gravity = opts.Gravity or 6,
						Size = opts.ChipSize or 0.4,
					})
				end
				return false
			end,
		})
	end
	fx:Flash(side, ctx.Here, color, 1.4, 0.14)
end
Kits.cone = cone

-- Concentric camera-facing rings, staggered (a sound wave / shock wave).
local function pulseRings(fx, side, e, ctx, opts)
	opts = opts or {}
	local color, accent = fx:Colors(side)
	local range = e.Range or 6
	local duration = math.max(0.2, e.Duration or 0.6)
	for i = 1, fx:Count(side, opts.Rings or 3) do
		fx:Ring(side, ctx.Here, if i % 2 == 0 then accent else color, 0.8, range * 2, duration * 0.85, {
			Kind = opts.Kind or "Ring",
			Delay = (i - 1) * duration * 0.18,
			Alpha = 0.12 + (i - 1) * 0.15,
			Spin = (if i % 2 == 0 then -1 else 1) * 1.5,
		})
	end
	fx:Flash(side, ctx.Here, color, 2, 0.16)
end
Kits.pulseRings = pulseRings

local function point(fx, e, fallbackSide)
	if e.Point then
		return fx.Scene.Frame:PointToWorldSpace(Vector3.new(e.Point[1], e.Point[2], e.Point[3]))
	end
	return (fx:Body(fallbackSide))
end
Kits.point = point

-- Boost aura that follows the body while the server boost status lasts (ctx.Until updated by the dispatcher).
local function aura(fx, side, e, seconds, step, parts)
	return fx:Spawn({
		Side = side,
		Key = "aura:" .. side,
		Start = e.Time,
		Seconds = seconds,
		Parts = parts,
		Step = function(_, age, k, time)
			local f = fx:Fighter(side)
			if f.Broken or f.Finishing then
				return false
			end
			local pos, size = fx:Body(side)
			return step(pos, size, age, k, time)
		end,
	})
end
Kits.aura = aura

-- ===================================================================================================================
-- Starters
-- ===================================================================================================================

Kits.pop = {
	Armed = function(fx, side, age, _, pos, size)
		-- Fizz rising inside the bottle while armed.
		if math.floor(age * 8) ~= math.floor((age - 1 / 60) * 8) then
			local color = fx:Colors(side)
			fx:Glints(side, pos - Vector3.yAxis * size * 0.3, color:Lerp(WHITE, 0.5), 1, {
				Speed = NumberRange.new(1, 2),
				Accel = Vector3.new(0, 5, 0),
				Spread = Vector2.new(15, 15),
			})
		end
	end,
	Payoff = function(fx, side, _, at)
		local color, accent = fx:Colors(side)
		fx:Flash(side, at, color, 2.2, 0.16)
		fx:Ring(side, at, color, 0.8, 6.5, 0.36, { Kind = "ShockCrown", Spin = 3 })
		fx:Ring(side, at, WHITE, 0.5, 4, 0.24, { Delay = 0.03, Alpha = 0.2 })
		fx:Chips(
			side,
			at,
			color:Lerp(WHITE, 0.35),
			8,
			7,
			0.5,
			{ Kind = "BubbleDome", Size = 0.55, Up = 2, Gravity = 4 }
		)
		fx:Glints(side, at, accent, 6)
		fx:Glints(side, at, WHITE, 10)
		fx:Cue(side, "pop_payoff")
	end,
}

Kits.jam = {
	Windup = function(fx, side, e)
		local color = fx:Colors(side)
		fx:Move(side, "wiggle", e.Windup or 0.15, 0.6)
		fx:Glints(side, (fx:Body(side)), color, 6)
	end,
	Release = function(fx, side, e)
		-- The lid itself is the shield (HeroPowers moves it); add a gold rim glow and a shimmer sweep while it's up.
		local color, accent = fx:Colors(side)
		local f = fx:Fighter(side)
		local rim, sheen = fx:Part("Ring", color), fx:Part("Block", WHITE)
		fx:Spawn({
			Side = side,
			Key = "guard:" .. side,
			Start = e.Time,
			Seconds = e.Duration or 2,
			Parts = { rim, sheen },
			Step = function(_, age, k)
				if f.Broken or f.Finishing or not f.HeroLid or not f.GuardAt then
					return age < 0.3
				end
				local lid = f.HeroLid:GetPivot() * CFrame.new(f.LidCenter or Vector3.zero)
				local d = (f.LidParts and f.LidParts[1] and f.LidParts[1].Mesh.Size) or Vector3.one
				local diameter = math.max(d.X, d.Z) * 1.15
				fx:Fit(rim, diameter * fx.pop(age / 0.25))
				rim.CFrame = lid * CFrame.Angles(math.pi / 2, 0, 0)
				rim.Transparency = 0.15 + 0.25 * (1 + math.sin(age * 7)) / 2 + 0.6 * fx.smooth((k - 0.85) / 0.15)
				-- A sheen bar sweeps across the lid every 0.8 s.
				local sweep = (age % 0.8) / 0.8
				sheen.Size = Vector3.new(diameter * 0.12, 0.06, diameter * 0.9 * math.sin(sweep * math.pi))
				sheen.CFrame = lid * CFrame.new((sweep - 0.5) * diameter * 0.9, 0.08, 0) * CFrame.Angles(0, 0.5, 0)
				sheen.Transparency = 0.25 + 0.75 * math.abs(sweep - 0.5) * 2
			end,
		})
		fx:Glints(side, (fx:Body(side)), accent, 10)
	end,
	Block = function(fx, side, e)
		local color = fx:Colors(side)
		local f = fx:Fighter(side)
		local at = if f.HeroLid and f.GuardAt then f.HeroLid:GetPivot().Position else point(fx, e, side)
		fx:StopKey("guard:" .. side)
		fx:Flash(side, at, WHITE, 2.4, 0.12)
		fx:Ring(side, at, color, 1, 6, 0.32, { Kind = "ShockCrown", Spin = 4 })
		fx:Spokes(side, at, color, 8, 2, 0.25, { Alternate = WHITE, Width = 0.36 })
		fx:Move(side, "recoil", 0.35, 1)
		fx:Cue(side, "jam_bonk")
	end,
}

Kits.prism = {
	Windup = function(fx, side, e)
		local rainbow = { "#FF6B8B", "#FFB347", "#FFE45C", "#6CFF9A", "#5FB4FF", "#C9A8FF" }
		local windup = math.max(0.1, e.Windup or 0.45)
		local lens = function()
			local pos, size = fx:Body(side)
			-- Aims at the foe live through the windup: the server fires along that line on release.
			return pos + fx:Toward(side) * size * 0.5
		end
		local motes = {}
		for i = 1, fx:Count(side, 6) do
			motes[i] = fx:Part("CrystalChip", hex(rainbow[(i - 1) % #rainbow + 1]))
			fx:Fit(motes[i], 0.42)
		end
		fx:Move(side, "wiggle", windup, 0.5)
		fx:Spawn({
			Side = side,
			Seconds = windup,
			Parts = motes,
			Step = function(_, age, k)
				local at, c = lens(), cam()
				for i, p in motes do
					local a = i / #motes * math.pi * 2 + age * (6 + 10 * k)
					local r = 2.6 * (1 - fx.easeIn(k))
					p.CFrame = CFrame.new(at + c.RightVector * math.cos(a) * r + c.UpVector * math.sin(a) * r)
						* CFrame.Angles(a, a, 0)
					p.Transparency = 0.05 + 0.95 * fx.smooth((k - 0.9) / 0.1)
				end
			end,
		})
		fx:Ring(side, lens, WHITE, 2.6, 0.5, windup, { Ease = "in", Alpha = 0.3 })
		fx:Cue(side, "prism_gather")
	end,
	Release = function(fx, side, e, ctx)
		-- The ray leaves from the lens (HeroPowers aims it along the ray), not from the body's centre.
		local f = fx:Fighter(side)
		local lens = function()
			if fx:Pinned() then
				return ctx.Origin
			end
			local aim = f.RayAim or ctx.Aim()
			return f.Body.Position + aim * f.Body.Size.X * 0.5
		end
		ray(fx, side, e, ctx, { Width = 0.45, Rainbow = true, Sheath = hex("#9C6CFF"), Seconds = 0.5, Start = lens })
	end,
	Hit = function(fx, side, _, at)
		fx:Flash(side, at, WHITE, 2, 0.14)
		fx:Ring(side, at, hex("#C9A8FF"), 0.6, 3.6, 0.3, { Kind = "NovaStar", Spin = 6 })
		local rainbow = { "#FF6B8B", "#FFE45C", "#6CFF9A", "#5FB4FF", "#C9A8FF", "#FFB347" }
		for i = 1, 3 do
			fx:Spokes(side, at, hex(rainbow[i * 2 - 1]), 2, 2.2, 0.26, { Alternate = hex(rainbow[i * 2]), Width = 0.3 })
		end
		fx:Glints(side, at, WHITE, 12)
	end,
	Miss = function(fx, side, _, ctx)
		local at = ctx.Here() + ctx.Direction * 8
		fx:Glints(side, at, hex("#C9A8FF"), 8, { Speed = NumberRange.new(2, 5) })
		fx:Ring(side, at, WHITE, 0.4, 1.8, 0.25, { Alpha = 0.4 })
	end,
}

-- ===================================================================================================================
-- Legendary / Mythic
-- ===================================================================================================================

Kits.comet = {
	Status = function(fx, side, e)
		if e.Kind ~= "Echo" then
			return
		end
		-- The planted star: hovers, spins, sparkles until it flies home (ends on the next CastRelease or timeout).
		local color, accent = fx:Colors(side)
		local at = point(fx, e, side)
		local star, halo = fx:Part("NovaStar", accent), fx:Part("Ring", color)
		local nextGlint = 0
		fx:Spawn({
			Side = side,
			Key = "echo:" .. side,
			Start = e.Time,
			Seconds = e.Seconds or 5,
			Parts = { star, halo },
			Step = function(_, age, k)
				local bob = at + Vector3.yAxis * math.sin(age * 3) * 0.15
				fx:Fit(star, 1.1 * fx.pop(age / 0.3) * (1 + math.sin(age * 6) * 0.08))
				star.CFrame = fx.face(bob) * CFrame.Angles(0, 0, age * 1.5)
				star.Transparency = 0.02 + 0.6 * fx.smooth((k - 0.85) / 0.15)
				fx:Fit(halo, 2.2 + math.sin(age * 4) * 0.2)
				halo.CFrame = fx.face(bob) * CFrame.Angles(0, 0, -age)
				halo.Transparency = 0.5 + 0.5 * fx.smooth((k - 0.8) / 0.2)
				if age >= nextGlint then
					nextGlint = age + 0.2
					fx:Glints(side, bob, accent, 1, { Speed = NumberRange.new(0.5, 1.5) })
				end
			end,
		})
		fx:Flash(side, at, accent, 1.6, 0.16)
		fx:GroundRing(side, at, color, 2.2, 0.6)
	end,
	Windup = function(fx, side, e)
		-- Two-stage: the star shrinks and brightens (gather), then flares (hush) right before launch.
		local color, accent = fx:Colors(side)
		gather(fx, side, e, { MoteKind = "NovaStar", MoteSize = 0.32, Motes = 6, TwoStage = true })
		fx:Ring(
			side,
			bodyAt(fx, side),
			accent,
			3,
			1,
			e.Windup or 0.25,
			{ Kind = "ShockCrown", Ease = "in", Spin = -5, Alpha = 0.25 }
		)
		local _ = color
	end,
	Release = function(fx, side, e, ctx)
		fx:StopKey("echo:" .. side)
		local color, accent = fx:Colors(side)
		local tail = ColorSequence.new({
			ColorSequenceKeypoint.new(0, WHITE),
			ColorSequenceKeypoint.new(0.2, accent),
			ColorSequenceKeypoint.new(1, color),
		})
		shots(fx, side, e, ctx, {
			Kind = "NovaStar",
			Size = 1.2,
			FaceCamera = true,
			Spin = 8,
			Trail = 0.45,
			TrailWidth = 1.1,
			Step = function(pos, age)
				if math.floor(age * 30) % 3 == 0 then
					fx:Glints(side, pos, accent, 1, { Speed = NumberRange.new(0.5, 2) })
				end
			end,
		})
		for _, s in ctx.Shots do
			if s.Effect then
				local p = s.Effect.Parts[1]
				fx:Trail(p, tail, 0.45, 1.1)
			end
		end
		fx:Flash(side, ctx.Here, accent, 2.2, 0.16)
		fx:Ring(side, ctx.Here, color, 0.6, 4, 0.3, { Kind = "ShockCrown", Spin = 3 })
		fx:Light(side, ctx.Here, accent, 0.35)
		fx:Cue(side, "comet_launch")
	end,
	Hit = function(fx, side, _, at)
		local color, accent = fx:Colors(side)
		fx:Flash(side, at, accent, 3, 0.18)
		fx:Ring(side, at, accent, 0.8, 4.5, 0.4, { Kind = "NovaStar", Spin = 4 })
		fx:Ring(side, at, color, 1, 8, 0.45, { Kind = "ShockCrown", Spin = -2, Delay = 0.04 })
		fx:Spokes(side, at, accent, 10, 2.8, 0.32, { Alternate = WHITE, Width = 0.36 })
		fx:Chips(side, at, accent, 6, 6, 0.6, { Kind = "NovaStar", Size = 0.4, Up = 3 })
		fx:GroundRing(side, at, color, 4, 0.55)
		fx:Light(side, at, accent, 0.4, 5)
		fx:HeroBloom(side, 1)
		fx:Cue(side, "comet_hit")
	end,
	Miss = function(fx, side, _, ctx)
		local _, accent = fx:Colors(side)
		local at = ctx.Here() + ctx.Direction * 8
		fx:Glints(side, at, accent, 10, { Speed = NumberRange.new(1, 3) })
	end,
}

Kits.glass_dragon = {
	Windup = function(fx, side, e)
		-- ≥0.5 s, two stages: (1) rear back, wings flare, sparkle motes drawn into the mouth, light builds;
		-- (2) hush: a tight bright ring at the mouth, then the breath.
		local color, accent = fx:Colors(side)
		local windup = math.max(0.2, e.Windup or 0.5)
		local mouth = function()
			local pos, size = fx:Body(side)
			return pos + fx:Toward(side) * size * 0.45 + Vector3.yAxis * size * 0.15
		end
		fx:Move(side, "rear", windup + 0.1, 1)
		gather(fx, side, e, {
			At = mouth,
			MoteKind = "CrystalChip",
			Motes = 10,
			Spread = 2.6,
			TwoStage = true,
			Motion = "wiggle",
			MotionAmount = 0.3,
		})
		fx:Spawn({
			Side = side,
			Seconds = windup * 0.7,
			Step = function(_, age)
				if math.floor(age * 30) % 2 == 0 then
					local at = mouth()
					local c = cam()
					local a = math.random() * math.pi * 2
					local from = at + (c.RightVector * math.cos(a) + c.UpVector * math.sin(a)) * 3
					fx:Glints(side, CFrame.lookAt(from, at), accent, 1, {
						Speed = NumberRange.new(6, 8),
						Spread = Vector2.new(2, 2),
						Lifetime = NumberRange.new(0.35, 0.4),
					})
				end
			end,
		})
		fx:Ring(
			side,
			mouth,
			WHITE,
			1.8,
			0.6,
			windup * 0.3,
			{ Delay = windup * 0.7, Ease = "in", Alpha = 0.05, Spin = 8 }
		)
		fx:GroundRing(side, (fx:Body(side)), color, 3, windup + 0.4, { Alpha = 0.3 })
		fx:Cue(side, "dragon_inhale")
	end,
	Release = function(fx, side, e, ctx)
		local color, accent = fx:Colors(side)
		cone(fx, side, e, ctx, {
			Sheets = 3,
			SheetKind = "PuffSheet",
			SheetSeconds = 0.38,
			Particle = "Sparkle",
			ParticleCount = 18,
			ParticleColor = accent,
			ParticleSize = 1.6,
			Chips = 5,
			ChipKind = "CrystalChip",
			Width = 1.1,
		})
		fx:Ring(
			side,
			ctx.Here,
			accent,
			0.8,
			5,
			0.35,
			{ Kind = "ShockCrown", Rotation = fx.tilted(ctx.Direction), Spin = 3 }
		)
		fx:Flash(side, ctx.Here, WHITE, 2.4, 0.16)
		fx:Light(side, function()
			return ctx.Here() + ctx.Aim() * 2.5
		end, color, (e.Duration or 0.5) + 0.25, 6, 16)
		fx:HeroBloom(side, 1)
		fx:GroundRing(side, ctx.Here() + ctx.Direction * 3, color, 5, 0.6)
		fx:Cue(side, "dragon_breath")
	end,
	Hit = function(fx, side, e, at)
		local color, accent = fx:Colors(side)
		local s = if (e.Pulse or 1) == 1 then 1 else 0.7
		fx:Flash(side, at, accent, 2 * s, 0.14)
		fx:Chips(side, at, color, 5, 5, 0.45, { Kind = "CrystalShard", Size = 0.7 * s, Up = 2 })
		fx:Ring(side, at, color, 0.6, 3.6 * s, 0.3, { Kind = "ShockCrown", Spin = 4 })
		fx:Glints(side, at, WHITE, 8)
	end,
}

Kits.galaxy_orb = {
	Windup = function(fx, side, e)
		local color, accent = fx:Colors(side)
		gather(fx, side, e, { MoteKind = "NovaStar", MoteSize = 0.3, Motes = 8, TwoStage = true, Spread = 2.4 })
		fx:Ring(
			side,
			bodyAt(fx, side),
			hex("#FF7AE6"),
			3.2,
			1.2,
			e.Windup or 0.5,
			{ Kind = "ShockCrown", Ease = "in", Spin = 6, Alpha = 0.3 }
		)
		fx:GroundRing(side, (fx:Body(side)), color, 2.5, (e.Windup or 0.5) + 0.3, { Alpha = 0.35 })
		local _ = accent
	end,
	Release = function(fx, side, e, ctx)
		-- The vortex: spinning accretion disc + spiral arms, a dark-violet core with a bright rim, stars spiralling in.
		local color, accent = fx:Colors(side)
		local duration = math.max(0.3, e.Duration or 1.2)
		local range = e.Range or 3.5
		local disc = fx:Part("Ring", color)
		local arms = { fx:Part("HalfRing", hex("#FF7AE6")), fx:Part("HalfRing", accent), fx:Part("HalfRing", color) }
		local core, rim = fx:Part("Ball", hex("#2A1468"), Enum.Material.SmoothPlastic), fx:Part("Ring", accent)
		local stars = {}
		for i = 1, fx:Count(side, 8) do
			stars[i] = fx:Part("NovaStar", if i % 2 == 0 then accent else WHITE)
			fx:Fit(stars[i], 0.38)
		end
		local parts = { disc, core, rim }
		for _, p in arms do
			table.insert(parts, p)
		end
		for _, p in stars do
			table.insert(parts, p)
		end
		local tilt = CFrame.Angles(math.rad(62), 0, 0)
		fx:Spawn({
			Side = side,
			Start = e.Time,
			Seconds = duration,
			Parts = parts,
			Step = function(_, age, k)
				local open = fx.pop(age / 0.3) * (1 - fx.easeIn((k - 0.8) / 0.2))
				local center = CFrame.new(ctx.Origin) * cam().Rotation * tilt
				fx:Fit(disc, range * 2 * open)
				disc.CFrame = center * CFrame.Angles(0, 0, age * 3)
				disc.Transparency = 0.25 + 0.6 * fx.smooth((k - 0.8) / 0.2)
				for i, p in arms do
					fx:Fit(p, range * (1.8 - i * 0.35) * open)
					p.CFrame = center * CFrame.Angles(0, 0, age * (4 + i * 1.5) + i * 2.1)
					p.Transparency = 0.15 + 0.85 * fx.smooth((k - 0.75) / 0.25)
				end
				core.Size = Vector3.one * 1.1 * open
				core.CFrame = CFrame.new(ctx.Origin)
				core.Transparency = 0.05 + 0.95 * fx.smooth((k - 0.85) / 0.15)
				fx:Fit(rim, 1.4 * open * (1 + math.sin(age * 12) * 0.06))
				rim.CFrame = fx.face(ctx.Origin)
				rim.Transparency = 0.05 + 0.95 * fx.smooth((k - 0.85) / 0.15)
				for i, p in stars do
					local phase = (age * 0.9 + i / #stars) % 1
					local a = i * 1.7 + age * 5 + phase * 6
					local r = range * (1 - phase) * open
					p.CFrame = center * CFrame.new(math.cos(a) * r, math.sin(a) * r, 0) * CFrame.Angles(0, 0, a)
					p.Transparency = 0.05 + 0.95 * math.max(phase ^ 3, fx.smooth((k - 0.85) / 0.15))
				end
			end,
		})
		fx:Flash(side, ctx.Origin, accent, 2.6, 0.16)
		fx:Light(side, ctx.Origin, color, duration, 5, 14)
		fx:GroundRing(side, ctx.Origin, color, range, duration, { Alpha = 0.2, Spin = 2 })
		fx:HeroBloom(side, 0.8)
		fx:Cue(side, "galaxy_vortex")
	end,
	Hit = function(fx, side, _, at)
		local color, accent = fx:Colors(side)
		fx:Flash(side, at, accent, 2.4, 0.16)
		fx:Ring(side, at, color, 0.5, 5, 0.35, { Kind = "ShockCrown", Spin = -4 })
		fx:Chips(side, at, accent, 6, 5, 0.5, { Kind = "NovaStar", Size = 0.35, Up = 2 })
		fx:Glints(side, at, WHITE, 10)
	end,
}

-- ===================================================================================================================
-- Epic
-- ===================================================================================================================

Kits.rocket_pop = {
	Windup = function(fx, side, e)
		-- Two-stage: the fins rattle and the base sputters smoke, then an ignition flash.
		local windup = math.max(0.1, e.Windup or 0.3)
		local color = fx:Colors(side)
		fx:Move(side, "wiggle", windup, 1.4)
		fx:Spawn({
			Side = side,
			Seconds = windup * 0.75,
			Step = function(_, age)
				if math.floor(age * 20) ~= math.floor((age - 1 / 60) * 20) then
					local pos, size = fx:Body(side)
					fx:Emit(
						side,
						"Smoke",
						CFrame.lookAt(pos - Vector3.yAxis * size * 0.5, pos - Vector3.yAxis * 3),
						2,
						hex("#DDE6F0"),
						{
							Speed = NumberRange.new(1, 3),
							Spread = Vector2.new(30, 30),
						}
					)
				end
			end,
		})
		local base = function()
			local pos, size = fx:Body(side)
			return pos - Vector3.yAxis * size * 0.5
		end
		fx:Flash(side, base, color, 1.8, 0.14, { Delay = windup * 0.8 })
		local l = fx:Light(side, base, color, windup + 0.1, 4)
		if l then
			l.Rise = 0.9
		end
	end,
	Release = function(fx, side, e)
		local color, accent = fx:Colors(side)
		local f = fx:Fighter(side)
		local jets = { fx:Part("Thorn", color), fx:Part("Thorn", accent), fx:Part("Thorn", WHITE) }
		local nextPuff = 0
		local seconds = e.Duration or 2.5
		aura(fx, side, e, seconds, function(pos, size, age, k, time)
			local flicker = 1 + math.sin(age * 37) * 0.12 + math.sin(age * 23) * 0.08
			local down = -f.Body.CFrame.UpVector
			local base = pos + down * size * 0.48
			for i, p in jets do
				local len = (if i == 3 then 1.2 else 2.1 - (i - 1) * 0.4) * flicker * fx.pop(age / 0.2)
				local w = if i == 3 then 0.5 else 1.15 - (i - 1) * 0.3
				local base0 = fx.Base.Thorn
				p.Size = Vector3.new(w, len * 1.4, base0.Z * 2)
				local x = cam().RightVector - down * cam().RightVector:Dot(down)
				x = if x.Magnitude > 0.01 then x.Unit else Vector3.xAxis
				-- Thorn tips point along +Y: aim them down and away from the base.
				p.CFrame = CFrame.fromMatrix(base + down * len * 0.7, x, down)
				p.Transparency = (if i == 3 then 0.1 else 0.05) + 0.9 * fx.smooth((k - 0.9) / 0.1)
			end
			if age >= nextPuff then
				nextPuff = age + 0.06
				fx:Emit(
					side,
					"Fire",
					CFrame.lookAt(base, base + down),
					2,
					color,
					{ Speed = NumberRange.new(3, 6), Spread = Vector2.new(15, 15) }
				)
			end
			local _ = time
		end, jets)
		local l = fx:Light(side, function()
			local pos, size = fx:Body(side)
			return pos - Vector3.yAxis * size * 0.6
		end, color, seconds, 3)
		if l then
			l.Rise = 0.05
		end
		fx:Flash(side, (fx:Body(side)), WHITE, 2.2, 0.14)
		fx:Ring(side, (fx:Body(side)), color, 1, 6, 0.32, { Kind = "ShockCrown", Spin = 3 })
		fx:Cue(side, "rocket_ignite")
	end,
}

Kits.prism_blade = {
	Windup = function(fx, side, e)
		-- Two-stage: a glint slides down the blade, then the crescent forms and grows at its tip.
		local color, accent = fx:Colors(side)
		local windup = math.max(0.1, e.Windup or 0.3)
		local sliver = fx:Part("Block", WHITE)
		local crescent = fx:Part("CurvedSlash", color)
		fx:Move(side, "wiggle", windup, 0.6)
		fx:Spawn({
			Side = side,
			Seconds = windup,
			Parts = { sliver, crescent },
			Step = function(_, age, k)
				local f = fx:Fighter(side)
				local pos, size = fx:Body(side)
				local up = f.Body.CFrame.UpVector
				local s = fx.smooth(k / 0.55)
				sliver.Size = Vector3.new(0.12, size * 0.35, 0.12)
				sliver.CFrame = CFrame.lookAt(pos, pos + cam().LookVector, up)
					* CFrame.new(0, size * (0.4 - s * 0.8), -size * 0.3)
				sliver.Transparency = if k < 0.55 then 0.05 else 1
				local g = fx.pop((k - 0.5) / 0.5)
				fx:Fit(crescent, 2.4 * g)
				crescent.CFrame = fx.face(pos + fx:Toward(side) * size * 0.6) * CFrame.Angles(0, 0, age * 8)
				crescent.Transparency = if k < 0.5 then 1 else 0.1
			end,
		})
		fx:Ring(side, bodyAt(fx, side), accent, 2.6, 0.8, windup, { Ease = "in", Alpha = 0.35 })
		local l = fx:Light(side, bodyAt(fx, side), color, windup + 0.1, 3.5)
		if l then
			l.Rise = 0.9
		end
	end,
	Release = function(fx, side, e, ctx)
		local color = fx:Colors(side)
		shots(fx, side, e, ctx, {
			Kind = "CurvedSlash",
			Size = 2.4,
			FaceCamera = true,
			Spin = 14,
			Trail = 0.28,
			TrailWidth = 1.4,
			Core = false,
		})
		fx:Flash(side, ctx.Here, color, 1.8, 0.14)
	end,
	Hit = function(fx, side, _, at)
		local color, accent = fx:Colors(side)
		-- An X slash.
		for i = 1, 2 do
			local p = fx:Part("CurvedSlash", if i == 1 then WHITE else color)
			fx:Spawn({
				Side = side,
				Seconds = 0.28,
				Parts = { p },
				Step = function(_, _, k)
					fx:Fit(p, 3.2 * fx.pop(k / 0.3))
					p.CFrame = fx.face(at) * CFrame.Angles(0, 0, if i == 1 then 0.8 else -0.8)
					p.Transparency = 0.02 + 0.98 * fx.easeIn(k)
				end,
			})
		end
		fx:Impact(side, at, color, accent, 0.9, { Spokes = 4 })
	end,
}

Kits.glass_duck = {
	Windup = function(fx, side, e)
		-- Two-stage: a bubble swells from the bill, then wraps the duck.
		local color, accent = fx:Colors(side)
		local windup = math.max(0.1, e.Windup or 0.12)
		local bubble = fx:Part("BubbleDome", accent, Enum.Material.Glass)
		fx:Move(side, "wiggle", windup + 0.1, 0.8)
		fx:Spawn({
			Side = side,
			Seconds = windup + 0.1,
			Parts = { bubble },
			Step = function(_, _, k)
				local pos, size = fx:Body(side)
				local bill = pos + fx:Toward(side) * size * 0.45 + Vector3.yAxis * size * 0.2
				fx:Fit(bubble, size * 1.4 * fx.easeOut(k))
				bubble.CFrame = fx.face(bill:Lerp(pos, fx.smooth(k)))
				bubble.Transparency = 0.45
			end,
		})
		local _ = color
	end,
	Release = function(fx, side, e)
		local color, accent = fx:Colors(side)
		local f = fx:Fighter(side)
		-- ForceField reads as a shimmering bubble and keeps the duck visible inside.
		local shell = fx:Part("Ball", accent, Enum.Material.ForceField)
		local rim, rim2 = fx:Part("Ring", WHITE), fx:Part("Ring", hex("#FF9BE0"))
		local nextBubble = 0
		fx:Spawn({
			Side = side,
			Key = "guard:" .. side,
			Start = e.Time,
			Seconds = e.Duration or 2.5,
			Parts = { shell, rim, rim2 },
			Step = function(_, age, k)
				if f.Broken or f.Finishing or f.GuardConsumed then
					return false
				end
				local pos, size = fx:Body(side)
				local wobble = 1 + math.sin(age * 9) * 0.04
				local d = size * 1.55 * fx.pop(age / 0.25) * wobble
				shell.Size = Vector3.new(d, d * (2 - wobble), d)
				shell.CFrame = CFrame.new(pos)
				shell.Transparency = 0.05 + 0.95 * fx.smooth((k - 0.9) / 0.1)
				fx:Fit(rim, d * 1.02)
				rim.CFrame = fx.face(pos) * CFrame.Angles(0, 0, age)
				rim.Transparency = 0.35 + 0.65 * fx.smooth((k - 0.9) / 0.1)
				fx:Fit(rim2, d * 0.96)
				rim2.CFrame = fx.face(pos) * CFrame.Angles(0, 0, -age * 1.3)
				rim2.Transparency = 0.6 + 0.4 * fx.smooth((k - 0.9) / 0.1)
				if age >= nextBubble then
					nextBubble = age + 0.25
					fx:Glints(side, pos, color, 1, { Speed = NumberRange.new(1, 2), Accel = Vector3.new(0, 3, 0) })
				end
			end,
		})
		fx:Flash(side, (fx:Body(side)), accent, 2, 0.14)
	end,
	Block = function(fx, side, e)
		local color, accent = fx:Colors(side)
		local at = (fx:Body(side))
		fx:StopKey("guard:" .. side)
		fx:Flash(side, at, WHITE, 2.6, 0.12)
		fx:Ring(side, at, accent, 1.5, 6.5, 0.32, { Spin = 3 })
		fx:Chips(side, at, accent, 8, 6, 0.5, { Kind = "Droplet", Size = 0.4, Up = 2 })
		fx:Glints(side, at, color, 10)
		fx:Move(side, "recoil", 0.35, 1)
		local _ = e
		fx:Cue(side, "duck_pop")
	end,
}

-- ===================================================================================================================
-- Rare
-- ===================================================================================================================

Kits.crescent_axe = {
	Windup = function(fx, side, e)
		gather(fx, side, e, { MoteKind = "CrystalChip", Motes = 6 })
	end,
	Release = function(fx, side, e, ctx)
		-- A crescent the size of the swing: an arc mesh sweeping with the weapon, then flung chips.
		local color, accent = fx:Colors(side)
		local duration = math.max(0.1, e.Duration or 0.5)
		local arcP, edge = fx:Part("CurvedSlash", color), fx:Part("CurvedSlash", WHITE)
		local up = Vector3.yAxis - ctx.Direction * ctx.Direction.Y
		up = if up.Magnitude > 0.001 then up.Unit else Vector3.zAxis
		local range, arc = e.Range or 4, e.Arc or 1.4
		fx:Spawn({
			Side = side,
			Start = e.Time,
			Seconds = duration + 0.18,
			Parts = { arcP, edge },
			Step = function(_, age)
				local progress = math.clamp(age / duration, 0, 1)
				local angle = (-0.5 + progress) * arc
				local outward = ctx.Direction * math.cos(angle) + up * math.sin(angle)
				local fade = fx.smooth((age - duration) / 0.18)
				local head = ctx.Here() + outward * range * 0.75
				-- Camera-plane crescent: X along the swing tangent, Y (the bulge) outward.
				local c = cam()
				local tangent = -ctx.Direction * math.sin(angle) + up * math.cos(angle)
				local x = tangent - c.LookVector * tangent:Dot(c.LookVector)
				x = if x.Magnitude > 0.01 then x.Unit else c.RightVector
				local y = outward - x * outward:Dot(x) - c.LookVector * outward:Dot(c.LookVector)
				y = if y.Magnitude > 0.01 then y.Unit else c.UpVector
				fx:Fit(arcP, range * 1.3)
				arcP.CFrame = CFrame.fromMatrix(fx.front(head, 0.5), x, y)
				arcP.Transparency = 0.15 + 0.85 * fade
				fx:Fit(edge, range * 1.05)
				edge.CFrame = arcP.CFrame * CFrame.new(0, 0.12, -0.05)
				edge.Transparency = 0.55 + 0.45 * fade
			end,
		})
		fx:Chips(
			side,
			ctx.Here() + ctx.Direction * range * 0.6,
			accent,
			5,
			6,
			0.5,
			{ Kind = "CrystalChip", Direction = ctx.Direction, Cone = 0.8, Size = 0.35 }
		)
		fx:Light(side, function()
			return ctx.Here() + ctx.Direction * range * 0.5
		end, color, duration + 0.1)
	end,
	Hit = function(fx, side, _, at)
		local color, accent = fx:Colors(side)
		fx:Impact(side, at, color, accent, 1.1, { SpokeKind = "CrystalShard" })
	end,
}

Kits.briar_flask = {
	Armed = function(fx, side, age, _, pos, size)
		-- A thorn crown rings the flask and slowly turns (drawn as per-frame thorns owned by the armed effect).
		local key = "armedkit:" .. side
		local exists = false
		for _, e in fx.Active do
			if e.Key == key then
				exists = true
				break
			end
		end
		if exists then
			return
		end
		local color, accent = fx:Colors(side)
		local thorns = {}
		for i = 1, fx:Count(side, 6) do
			thorns[i] = fx:Part("Thorn", if i % 2 == 0 then accent else color)
		end
		fx:Spawn({
			Side = side,
			Key = key,
			Seconds = 4,
			Parts = thorns,
			Step = function(_, a)
				if not fx.Armed[side] then
					return false
				end
				local p0 = fx:Body(side)
				for i, p in thorns do
					local angle = i / #thorns * math.pi * 2 + a * 0.8
					local dir = Vector3.new(math.cos(angle), 0.15, math.sin(angle)).Unit
					p.Size = fx.Base.Thorn * 1.6 * fx.pop(a / 0.3)
					p.CFrame = CFrame.lookAt(p0 + dir * size * 0.55, p0 + dir * size * 2)
						* CFrame.Angles(-math.pi / 2, 0, 0)
					p.Transparency = 0.05
				end
			end,
		})
		local _ = age
		local _ = pos
	end,
	Payoff = function(fx, side, _, at)
		local color, accent = fx:Colors(side)
		fx:StopKey("armedkit:" .. side)
		fx:Spokes(side, at, color, 8, 2.8, 0.32, { Kind = "Thorn", Alternate = accent, Width = 0.5 })
		local blossom = fx:Part("NovaStar", accent)
		fx:Spawn({
			Side = side,
			Seconds = 0.45,
			Parts = { blossom },
			Step = function(_, _, k)
				fx:Fit(blossom, 2.6 * fx.pop(k / 0.35))
				blossom.CFrame = fx.face(at) * CFrame.Angles(0, 0, k * 1.5)
				blossom.Transparency = 0.05 + 0.95 * fx.easeIn(k)
			end,
		})
		fx:Flash(side, at, color, 1.8, 0.14)
		fx:Glints(side, at, accent, 12, { Speed = NumberRange.new(2, 5), Accel = Vector3.new(0, -4, 0) })
		fx:Light(side, at, color, 0.3)
	end,
}

-- Jagged lightning between two points: 4 segments re-jittered every few frames.
local function bolt(fx, side, from, to, color, width, seconds)
	local segs = 4
	local points = {}
	local jitterAt = -1
	local function pointsAt(age)
		if age - jitterAt > 0.045 then
			jitterAt = age
			local a, b = from(), to()
			local d = b - a
			local side2 = d:Cross(cam().LookVector)
			side2 = if side2.Magnitude > 0.001 then side2.Unit else Vector3.yAxis
			points[1], points[segs + 1] = a, b
			for i = 2, segs do
				points[i] = a + d * ((i - 1) / segs) + side2 * (math.random() - 0.5) * math.min(1.4, d.Magnitude * 0.18)
			end
		end
		return points
	end
	for i = 1, segs do
		local get0 = function(age)
			return pointsAt(age)[i]
		end
		local get1 = function(age)
			return pointsAt(age)[i + 1]
		end
		fx:Beam(side, get0, get1, color, width * 2.2, seconds, {
			Alpha = 0.35,
			Shape = function(k)
				return fx.pop(k / 0.1) * (1 - fx.smooth((k - 0.4) / 0.6))
			end,
		})
		fx:Beam(side, get0, get1, WHITE, width, seconds * 0.9, {
			Shape = function(k, age)
				return (0.7 + 0.3 * math.sin(age * 90)) * (1 - fx.smooth((k - 0.4) / 0.6))
			end,
		})
	end
end
Kits.bolt = bolt

Kits.arc_coil = {
	Windup = function(fx, side, e)
		local color = fx:Colors(side)
		local windup = math.max(0.1, e.Windup or 0.35)
		gather(fx, side, e, { Motes = 0, Light = true })
		-- Crackle arcs around the body.
		fx:Spawn({
			Side = side,
			Seconds = windup,
			Step = function(_, age)
				if math.floor(age * 14) ~= math.floor((age - 1 / 60) * 14) then
					local pos, size = fx:Body(side)
					local a, b = math.random() * math.pi * 2, math.random() * math.pi * 2
					local p1 = pos + Vector3.new(math.cos(a), math.sin(a) * 0.8, math.sin(a)) * size * 0.6
					local p2 = pos + Vector3.new(math.cos(b), math.sin(b) * 0.8, math.sin(b)) * size * 0.7
					bolt(fx, side, function()
						return p1
					end, function()
						return p2
					end, color, 0.12, 0.09)
				end
			end,
		})
		fx:Cue(side, "arc_crackle")
	end,
	Release = function(fx, side, e, ctx)
		local color = fx:Colors(side)
		bolt(fx, side, ctx.Here, function()
			if ctx.EndAt then
				return ctx.EndAt()
			end
			return ctx.End or (ctx.Here() + ctx.Direction * (e.Range or 12))
		end, color, 0.32, 0.45)
		fx:Flash(side, ctx.Here, color, 1.8, 0.12)
		fx:Cue(side, "arc_bolt")
		local l = fx:Light(side, ctx.Here, color, 0.45, 5)
		if l then
			l.Rise = 0.05
		end
	end,
	Hit = function(fx, side, _, at)
		local color, accent = fx:Colors(side)
		fx:Flash(side, at, WHITE, 2, 0.12)
		fx:Ring(side, at, color, 0.5, 3.6, 0.26, { Kind = "ShockCrown", Spin = 8 })
		fx:Glints(side, at, color, 14, { Speed = NumberRange.new(5, 10) })
		fx:Glints(side, at, accent, 6, { Speed = NumberRange.new(3, 6) })
		fx:Light(side, at, color, 0.25, 4)
	end,
	Miss = function(fx, side, _, ctx)
		local color = fx:Colors(side)
		fx:Glints(side, ctx.Here() + ctx.Direction * 12, color, 6)
	end,
}

Kits.hourglass = {
	Windup = function(fx, side, e)
		-- A clock face in front with a hand sweeping backwards (rewind) while sand flows up.
		local color, accent = fx:Colors(side)
		local windup = math.max(0.2, e.Windup or 0.85)
		local face, hand, hand2 = fx:Part("Ring", color), fx:Part("Block", WHITE), fx:Part("Block", color)
		local ticks = {}
		for i = 1, fx:Count(side, 12) do
			ticks[i] = fx:Part("Block", if i % 3 == 1 then WHITE else color)
		end
		local parts = { face, hand, hand2 }
		for _, p in ticks do
			table.insert(parts, p)
		end
		local nextSand = 0
		fx:Spawn({
			Side = side,
			Seconds = windup + 0.1,
			Parts = parts,
			Step = function(_, age, k)
				local pos, size = fx:Body(side)
				local c = cam()
				local front = pos - c.LookVector * size * 0.7
				local r = size * 0.62 * fx.pop(age / 0.25)
				fx:Fit(face, r * 2)
				face.CFrame = CFrame.new(front) * c.Rotation * CFrame.Angles(0, 0, -age * 0.5)
				face.Transparency = 0.2 + 0.8 * fx.smooth((k - 0.9) / 0.1)
				for i, p in ticks do
					local a = i / #ticks * math.pi * 2
					p.Size = Vector3.new(0.12, if i % 3 == 1 then 0.4 else 0.22, 0.05)
					p.CFrame = CFrame.new(front) * c.Rotation * CFrame.Angles(0, 0, a) * CFrame.new(0, r * 0.82, 0)
					p.Transparency = 0.05 + 0.95 * fx.smooth((k - 0.9) / 0.1)
				end
				local sweep = -fx.smooth(k) * math.pi * 4
				hand.Size = Vector3.new(0.14, r * 0.75, 0.06)
				hand.CFrame = CFrame.new(front)
					* c.Rotation
					* CFrame.Angles(0, 0, sweep)
					* CFrame.new(0, r * 0.37, -0.02)
				hand.Transparency = 0.02 + 0.98 * fx.smooth((k - 0.9) / 0.1)
				hand2.Size = Vector3.new(0.18, r * 0.45, 0.06)
				hand2.CFrame = CFrame.new(front)
					* c.Rotation
					* CFrame.Angles(0, 0, sweep / 12)
					* CFrame.new(0, r * 0.22, -0.01)
				hand2.Transparency = hand.Transparency
				if age >= nextSand then
					nextSand = age + 0.07
					fx:Glints(side, pos - Vector3.yAxis * size * 0.4, color, 1, {
						Speed = NumberRange.new(1, 2),
						Accel = Vector3.new(0, 6, 0),
						Spread = Vector2.new(20, 20),
					})
				end
			end,
		})
		local l = fx:Light(side, bodyAt(fx, side), accent, windup + 0.2, 3)
		if l then
			l.Rise = 0.85
		end
	end,
	Status = function(fx, side, e)
		if e.Kind ~= "Heal" then
			return
		end
		Kits.heal(fx, side, e)
	end,
}

Kits.frostglobe = {
	Windup = function(fx, side, e)
		local _, accent = fx:Colors(side)
		gather(fx, side, e, { MoteKind = "CrystalChip", Motes = 6, MoteSize = 0.3 })
		fx:Spawn({
			Side = side,
			Seconds = e.Windup or 0.4,
			Step = function(_, age)
				if math.floor(age * 20) ~= math.floor((age - 1 / 60) * 20) then
					fx:Glints(side, (fx:Body(side)), accent, 2, { Speed = NumberRange.new(1, 2.5) })
				end
			end,
		})
	end,
	Release = function(fx, side, e, ctx)
		local color = fx:Colors(side)
		cone(fx, side, e, ctx, {
			Sheets = 2,
			SheetKind = "PuffSheet",
			Particle = "Frost",
			ParticleCount = 14,
			ParticleColor = WHITE,
			ParticleSize = 1.8,
			Chips = 4,
			ChipKind = "CrystalShard",
			ChipSize = 0.5,
		})
		fx:Light(side, function()
			return ctx.Here() + ctx.Aim() * 2
		end, color, 0.4)
	end,
	Hit = function(fx, side, _, at)
		local color, accent = fx:Colors(side)
		-- Ice spikes jut out of the struck glassy briefly.
		local spikes = {}
		for i = 1, fx:Count(side, 6) do
			spikes[i] = fx:Part("CrystalShard", if i % 2 == 0 then accent else color, Enum.Material.Glass)
		end
		local dirs = {}
		for i = 1, #spikes do
			dirs[i] = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit
		end
		fx:Spawn({
			Side = side,
			Seconds = 0.6,
			Parts = spikes,
			Step = function(_, _, k)
				for i, p in spikes do
					local g = fx.pop(k / 0.25) * (1 - fx.easeIn((k - 0.6) / 0.4))
					p.Size = fx.Base.CrystalShard * 0.7 * g
					p.CFrame = CFrame.lookAt(at, at + dirs[i])
						* CFrame.Angles(-math.pi / 2, 0, 0)
						* CFrame.new(0, 0.5 * g, 0)
					p.Transparency = 0.2
				end
			end,
		})
		fx:Flash(side, at, WHITE, 1.8, 0.14)
		fx:Glints(side, at, WHITE, 10)
	end,
}

-- ===================================================================================================================
-- Commons / Uncommons
-- ===================================================================================================================

-- Shared heal look: rising rings, foam/plus glints, a flash.
function Kits.heal(fx, side, e, opts)
	opts = opts or {}
	local color, accent = fx:Colors(side)
	local healColor = opts.Color or accent
	local pos, size = fx:Body(side)
	for i = 1, 3 do
		fx:Ring(
			side,
			function(age)
				local p = fx:Body(side)
				return p + Vector3.yAxis * (-size * 0.5 + age * 4)
			end,
			healColor,
			size * 1.4,
			size * 0.9,
			0.45,
			{
				Rotation = CFrame.Angles(math.pi / 2, 0, 0),
				Delay = (i - 1) * 0.1,
				Alpha = 0.1,
			}
		)
	end
	fx:Flash(side, pos, healColor, 2, 0.16)
	fx:Glints(side, pos, healColor, 14, { Speed = NumberRange.new(2, 4), Accel = Vector3.new(0, 5, 0) })
	fx:Glints(side, pos, color, 6, { Speed = NumberRange.new(1, 3), Accel = Vector3.new(0, 4, 0) })
	local _ = e
end

Kits.milk_bottle = {
	Windup = function(fx, side, e)
		gather(fx, side, e, { MoteKind = "BubbleDome", MoteSize = 0.35, Motes = 5 })
	end,
	Status = function(fx, side, e)
		if e.Kind ~= "Heal" then
			return
		end
		local color, accent = fx:Colors(side)
		local pos, size = fx:Body(side)
		-- Foam blooms up around the bottle; a blue seal ring tightens on the neck.
		fx:Chips(
			side,
			pos - Vector3.yAxis * size * 0.3,
			color,
			8,
			2.5,
			0.6,
			{ Kind = "BubbleDome", Size = 0.6, Up = 3, Gravity = -2, Alpha = 0.1 }
		)
		fx:Ring(side, function()
			local p, s = fx:Body(side)
			return p + Vector3.yAxis * s * 0.35
		end, accent, size * 1.6, size * 0.5, 0.4, { Rotation = CFrame.Angles(math.pi / 2, 0, 0), Ease = "in" })
		Kits.heal(fx, side, e, { Color = color })
	end,
}

Kits.pickle_jar = {
	Armed = function(fx, side, age, _, pos, size)
		if math.floor(age * 6) ~= math.floor((age - 1 / 60) * 6) then
			local color = fx:Colors(side)
			fx:Glints(
				side,
				pos - Vector3.yAxis * size * 0.3,
				color,
				1,
				{ Speed = NumberRange.new(1, 2), Accel = Vector3.new(0, 4, 0) }
			)
		end
	end,
	Status = function(fx, side, e)
		if e.Kind ~= "Slow" then
			return
		end
		local color, accent = fx:Colors(side)
		local target = e.Target or (3 - side)
		local at = (fx:Body(target))
		fx:Flash(side, at, color, 1.8, 0.14)
		fx:Chips(side, at, color, 6, 4, 0.5, { Kind = "Droplet", Size = 0.4, Up = 1 })
		fx:Ring(side, at, accent, 0.6, 3.4, 0.3, { Spin = 2 })
	end,
}

Kits.ketchup_bottle = {
	Status = function(fx, side, e)
		if e.Kind ~= "Mark" then
			return
		end
		local color, accent = fx:Colors(side)
		local at = (fx:Body(e.Target or (3 - side)))
		fx:Flash(side, at, color, 1.6, 0.14)
		fx:Ring(side, at, accent, 0.5, 3, 0.28, {})
	end,
	Payoff = function(fx, side, _, at)
		-- A cartoon splat star with confetti dots (never blood-like: orange, glossy, no drips).
		local color, accent = fx:Colors(side)
		local star = fx:Part("NovaStar", color)
		fx:Spawn({
			Side = side,
			Seconds = 0.4,
			Parts = { star },
			Step = function(_, _, k)
				fx:Fit(star, 2.8 * fx.pop(k / 0.3))
				star.CFrame = fx.face(at) * CFrame.Angles(0, 0, 0.3)
				star.Transparency = 0.02 + 0.98 * fx.easeIn(k)
			end,
		})
		fx:Flash(side, at, accent, 1.6, 0.12)
		fx:Chips(side, at, accent, 6, 5, 0.45, { Kind = "Ball", Size = 0.28, Alternate = WHITE, Up = 2 })
	end,
}

Kits.glass_cup = {
	Release = function(fx, side, e)
		local color, accent = fx:Colors(side)
		local f = fx:Fighter(side)
		local rim = fx:Part("ShockCrown", color)
		-- Speed streaks: a wide trail riding the body while boosted.
		local streak = fx:Part("Anchor", WHITE)
		fx:Trail(
			streak,
			ColorSequence.new(WHITE, color),
			0.22,
			select(2, fx:Body(side)) * 0.8,
			NumberSequence.new(0.35, 1)
		)
		aura(fx, side, e, e.Duration or 2.5, function(pos, size, age, k)
			local top = pos + f.Body.CFrame.UpVector * size * 0.45
			fx:Fit(rim, size * 1.05 * fx.pop(age / 0.2))
			rim.CFrame = CFrame.lookAt(top, top + f.Body.CFrame.UpVector) * CFrame.Angles(0, 0, age * 9)
			rim.Transparency = 0.1 + 0.9 * fx.smooth((k - 0.9) / 0.1)
			streak.CFrame = CFrame.lookAt(pos, pos + cam().LookVector)
		end, { rim, streak })
		fx:Flash(side, (fx:Body(side)), accent, 1.6, 0.14)
		fx:Ring(side, (fx:Body(side)), color, 0.8, 4, 0.28, {})
	end,
}

Kits.water_jug = {
	Windup = function(fx, side, e)
		gather(fx, side, e, { MoteKind = "Droplet", Motes = 5, MoteSize = 0.35 })
	end,
	Release = function(fx, side, e, ctx)
		cone(fx, side, e, ctx, {
			Sheets = 2,
			SheetKind = "SplashSheet",
			Particle = "Droplets",
			ParticleCount = 16,
			ParticleColor = fx:Colors(side),
			ParticleSize = 1.6,
			Chips = 5,
			ChipKind = "Droplet",
			ChipSize = 0.45,
			Gravity = 18,
		})
	end,
	Hit = function(fx, side, _, at)
		local color, accent = fx:Colors(side)
		fx:Ring(side, at, color, 0.6, 3.6, 0.3, { Kind = "ShockCrown", Spin = 2 })
		fx:Chips(side, at, accent, 7, 5, 0.5, { Kind = "Droplet", Size = 0.4, Up = 3 })
		fx:Flash(side, at, accent, 1.5, 0.12)
	end,
}

Kits.lemonade_bottle = {
	Windup = function(fx, side, e)
		local color = fx:Colors(side)
		gather(fx, side, e, { MoteKind = "BubbleDome", Motes = 4, MoteSize = 0.3 })
		fx:Glints(side, (fx:Body(side)), color, 6, { Speed = NumberRange.new(1, 2), Accel = Vector3.new(0, 5, 0) })
	end,
	Release = function(fx, side, e, ctx)
		local color, accent = fx:Colors(side)
		shots(
			fx,
			side,
			e,
			ctx,
			{ Kind = "Droplet", Size = 0.95, Alternate = hex("#FFB21F"), Trail = 0.2, TrailWidth = 0.7 }
		)
		fx:Flash(side, ctx.Here, color, 1.4, 0.12)
		local _ = accent
	end,
	Hit = function(fx, side, _, at)
		local color, accent = fx:Colors(side)
		fx:Flash(side, at, color, 1.4, 0.12)
		fx:Spokes(side, at, color, 6, 1.5, 0.22, { Alternate = accent, Width = 0.3 })
		fx:Glints(side, at, color, 6)
	end,
}

Kits.mason_jar = {
	Armed = function(fx, side, age, _, pos, size)
		-- The lid screws tight: a glowing band at the top turns.
		local key = "armedkit:" .. side
		for _, e in fx.Active do
			if e.Key == key then
				return
			end
		end
		local _, accent = fx:Colors(side)
		local f = fx:Fighter(side)
		local band = fx:Part("ShockCrown", accent)
		fx:Spawn({
			Side = side,
			Key = key,
			Seconds = 4,
			Parts = { band },
			Step = function(_, a)
				if not fx.Armed[side] then
					return false
				end
				local p0, s0 = fx:Body(side)
				local top = p0 + f.Body.CFrame.UpVector * s0 * 0.42
				fx:Fit(band, s0 * 0.95 * fx.pop(a / 0.25))
				band.CFrame = CFrame.lookAt(top, top + f.Body.CFrame.UpVector) * CFrame.Angles(0, 0, -a * 5)
				band.Transparency = 0.1 + 0.2 * math.sin(a * 10)
			end,
		})
		local _ = age
		local _ = pos
		local _ = size
	end,
	Payoff = function(fx, side, _, at)
		local color, accent = fx:Colors(side)
		fx:StopKey("armedkit:" .. side)
		fx:Flash(side, at, accent, 2, 0.14)
		fx:Ring(side, at, accent, 1, 6, 0.34, { Kind = "ShockCrown", Spin = -5, Thick = 0.6 })
		fx:Ring(side, at, color, 0.6, 4, 0.26, { Delay = 0.04 })
		fx:Chips(side, at, color, 6, 6, 0.45, { Kind = "CrystalChip", Size = 0.4 })
		fx:Move(side, "recoil", 0.3, -0.8)
	end,
}

Kits.hot_sauce = {
	Release = function(fx, side, e)
		local color, accent = fx:Colors(side)
		local heat = fx:Part("ShockCrown", color)
		local nextFlame = 0
		aura(fx, side, e, e.Duration or 3.5, function(pos, size, age, k)
			local base = pos - Vector3.yAxis * size * 0.5
			fx:Fit(heat, size * 1.3 * (1 + math.sin(age * 14) * 0.06) * fx.pop(age / 0.2))
			heat.CFrame = CFrame.new(base) * CFrame.Angles(math.pi / 2, 0, age * 2)
			heat.Transparency = 0.25 + 0.75 * fx.smooth((k - 0.9) / 0.1)
			if age >= nextFlame then
				nextFlame = age + 0.07
				fx:Emit(
					side,
					"Fire",
					CFrame.lookAt(base, base + Vector3.yAxis),
					2,
					if math.random() < 0.5 then color else accent,
					{
						Speed = NumberRange.new(2, 4),
						Spread = Vector2.new(35, 35),
						Size = 1.1,
					}
				)
			end
		end, { heat })
		local l = fx:Light(side, bodyAt(fx, side), accent, e.Duration or 3.5, 2.5)
		if l then
			l.Rise = 0.05
		end
		fx:Cue(side, "hot_sauce")
		fx:Flash(side, (fx:Body(side)), accent, 2, 0.14)
	end,
}

Kits.crystal_tumbler = {
	Status = function(fx, side, e)
		local color, accent = fx:Colors(side)
		if e.Kind == "Mirror" then
			local f = fx:Fighter(side)
			local plate, rim, sheen =
				fx:Part("GuardPlate", color, Enum.Material.Glass), fx:Part("Ring", accent), fx:Part("Block", WHITE)
			fx:Spawn({
				Side = side,
				Key = "mirror:" .. side,
				Start = e.Time,
				Seconds = e.Seconds or 1.8,
				Parts = { plate, rim, sheen },
				Step = function(_, age, k)
					if f.Broken or f.Finishing then
						return false
					end
					local pos, size = fx:Body(side)
					local dir = fx:Toward(side)
					local at = pos + dir * size * 0.62
					local normal = (dir + cam().LookVector * -0.6).Unit
					local d = size * 1.25 * fx.pop(age / 0.2)
					fx:Fit(plate, d)
					plate.CFrame = CFrame.lookAt(at, at + normal)
					plate.Transparency = 0.25 + 0.75 * fx.smooth((k - 0.9) / 0.1)
					plate.Reflectance = 0.4
					fx:Fit(rim, d * 1.1)
					rim.CFrame = CFrame.lookAt(at, at + normal) * CFrame.Angles(0, 0, age * 2)
					rim.Transparency = 0.2 + 0.8 * fx.smooth((k - 0.9) / 0.1)
					local sweep = (age % 0.7) / 0.7
					sheen.Size = Vector3.new(d * 0.08, d * 0.9 * math.sin(sweep * math.pi), 0.05)
					sheen.CFrame = CFrame.lookAt(at, at + normal)
						* CFrame.new((sweep - 0.5) * d * 0.8, 0, -0.08)
						* CFrame.Angles(0, 0, 0.5)
					sheen.Transparency = 0.2 + 0.8 * math.abs(sweep - 0.5) * 2
				end,
			})
			fx:Flash(side, (fx:Body(side)), accent, 1.6, 0.14)
		elseif e.Kind == "MirrorCatch" then
			fx:StopKey("mirror:" .. side)
			local at = (fx:Body(side)) + fx:Toward(side) * 1.2
			fx:Flash(side, at, WHITE, 2.4, 0.12)
			fx:Spokes(side, at, accent, 6, 2.2, 0.25, { Alternate = color })
			fx:Glints(side, at, hex("#FFB3F0"), 6)
			fx:Glints(side, at, hex("#B3FFF0"), 6)
		end
	end,
	Release = function(fx, side, e, ctx)
		-- The reflected glint (a ray cast by the mirror).
		if e.Shape == "ray" then
			ray(fx, side, e, ctx, { Width = 0.32, Rainbow = true, Seconds = 0.4 })
		end
	end,
}

Kits.chime = {
	Windup = function(fx, side, e)
		gather(fx, side, e, { MoteKind = "HalfRing", Motes = 4, MoteSize = 0.5 })
	end,
	Release = function(fx, side, e, ctx)
		pulseRings(fx, side, e, ctx, { Rings = 3, Kind = "Ring" })
		local _, accent = fx:Colors(side)
		fx:Glints(side, ctx.Here(), accent, 10, { Speed = NumberRange.new(3, 6) })
		fx:Cue(side, "chime_ring")
	end,
}

-- ===================================================================================================================
-- Launch glassies (ROSTER_V2): zones, drain, Cycle, riposte, dash, rebirth and the horizontal spin come from LaunchKit
-- through Launch.event; these entries give the travelling shots their identity.
-- ===================================================================================================================

Kits.fishbowl = {
	Release = function(fx, side, e, ctx)
		local _, accent = fx:Colors(side)
		-- The fish leaps out and back (return path), trailing water.
		shots(fx, side, e, ctx, { Kind = "Droplet", Size = 1.1, Alternate = accent, Trail = 0.25, TrailWidth = 0.8 })
		for _, shot in ctx.Shots do
			if shot.Effect then
				shot.Effect.Parts[1].Color = accent
			end
		end
		fx:Chips(side, ctx.Here(), fx:Colors(side), 4, 4, 0.4, { Kind = "Droplet", Size = 0.35, Up = 2 })
	end,
	Hit = function(fx, side, e, at)
		Kits.water_jug.Hit(fx, side, e, at)
	end,
}

Kits.cookie_jar = {
	Release = function(fx, side, e, ctx)
		shots(fx, side, e, ctx, { Kind = "CrystalChip", Size = 0.85, Trail = 0.16, TrailWidth = 0.5, Spin = 14 })
	end,
	Hit = function(fx, side, _, at)
		local color, accent = fx:Colors(side)
		fx:Flash(side, at, accent, 1.3, 0.12)
		fx:Chips(side, at, color, 6, 4, 0.45, { Kind = "CrystalChip", Size = 0.3, Up = 2 })
	end,
}

Kits.piggy_bank = {
	Release = function(fx, side, e, ctx)
		local _, accent = fx:Colors(side)
		-- Three glass coins.
		shots(fx, side, e, ctx, { Kind = "Disc", Size = 0.9, Trail = 0.2, TrailWidth = 0.6, Spin = 16, Core = false })
		for _, shot in ctx.Shots do
			if shot.Effect then
				shot.Effect.Parts[1].Color = accent
			end
		end
	end,
	Hit = function(fx, side, _, at)
		local _, accent = fx:Colors(side)
		fx:Flash(side, at, accent, 1.4, 0.12)
		fx:Spokes(side, at, accent, 6, 1.6, 0.22, { Alternate = WHITE, Width = 0.3 })
		fx:Glints(side, at, accent, 8)
	end,
}

Kits.glass_top = {
	Windup = function(fx, side, e)
		gather(fx, side, e, { Motion = "spin", MotionAmount = 1.5, Motes = 4 })
	end,
}

Kits.glass_phoenix = {
	Release = function(fx, side, e, ctx)
		local color, accent = fx:Colors(side)
		-- Ember feathers: flame-trailed thorns (one before the rebirth, a volley of three after).
		shots(fx, side, e, ctx, {
			Kind = "Thorn",
			Size = 1.1,
			Rotate = CFrame.Angles(math.pi / 2, 0, 0), -- the feather's tip (+Y) leads
			Alternate = accent,
			Trail = 0.3,
			TrailWidth = 0.7,
			Spin = 0,
			Step = function(pos, age)
				if math.floor(age * 20) % 2 == 0 then
					fx:Emit(side, "Fire", pos, 1, color, { Speed = NumberRange.new(0.5, 1.5) })
				end
			end,
		})
		fx:Flash(side, ctx.Here, accent, 1.6, 0.12)
	end,
}

-- ===================================================================================================================
-- Daily Rewards glassies (decision 115)
-- ===================================================================================================================

-- Yarn loops wrapped round a tangled glassy for `seconds` (Whiskers' slow): three tilted rings that spin and tighten.
local function tangle(fx, side, target, seconds, start)
	local color, accent = fx:Colors(side)
	local loops = {}
	for i = 1, fx:Count(side, 3) do
		loops[i] = fx:Part("Ring", if i == 2 then accent else color)
	end
	fx:Spawn({
		Side = side,
		Key = "tangle:" .. target,
		Start = start,
		Seconds = seconds,
		Parts = loops,
		Step = function(_, age, k)
			local f = fx:Fighter(target)
			if not f or f.Broken or f.Finishing then
				return false
			end
			local pos, size = fx:Body(target)
			local wrap = fx.pop(age / 0.25)
			for i, p in loops do
				fx:Fit(p, size * (1.35 - 0.12 * i) * (1.6 - 0.6 * wrap))
				p.CFrame = CFrame.new(pos) * CFrame.Angles(0.9 * i, age * (2 + i), 0.6 * i + age * 1.5)
				p.Transparency = 0.15 + 0.85 * fx.smooth((k - 0.82) / 0.18)
			end
		end,
	})
end

Kits.whiskers = {
	Windup = function(fx, side, e)
		-- Stage 1: the kitty crouches and wiggles its bottom; stage 2 (Epic hush): it freezes, then pounces.
		gather(fx, side, e, { MoteKind = "Ball", Motes = 5, MoteSize = 0.3, MotionAmount = 1.6, TwoStage = true })
		fx:Cue(side, "whiskers_wiggle")
	end,
	Release = function(fx, side, e, ctx)
		local color, accent = fx:Colors(side)
		-- A glass yarn ball rolls out and back, trailing a long thin strand of yarn.
		shots(fx, side, e, ctx, {
			Kind = "BubbleDome",
			Size = 1.05,
			Core = false,
			Trail = 0.55,
			TrailWidth = 0.18,
			Spin = 12,
			Step = function(pos, age)
				if math.floor(age * 12) ~= math.floor((age - 1 / 60) * 12) then
					fx:Glints(side, pos, accent, 1, { Speed = NumberRange.new(0.5, 1.5) })
				end
			end,
		})
		for _, shot in ctx.Shots do
			if shot.Effect then
				shot.Effect.Parts[1].Color = color
				shot.Effect.Parts[1].Material = Enum.Material.Glass
			end
		end
		fx:Flash(side, ctx.Here, accent, 1.2, 0.12)
		fx:Cue(side, "whiskers_toss")
	end,
	Hit = function(fx, side, _, at)
		local color, accent = fx:Colors(side)
		fx:Flash(side, at, color, 1.6, 0.14)
		fx:Ring(side, at, accent, 0.6, 3.2, 0.3, { Kind = "ShockCrown", Spin = 3 })
		fx:Chips(side, at, color, 6, 4, 0.5, { Kind = "Ball", Size = 0.25, Alternate = accent, Up = 2 })
		fx:Cue(side, "whiskers_tangle")
	end,
	Status = function(fx, side, e)
		if e.Kind == "Slow" and e.Target then
			tangle(fx, side, e.Target, e.Seconds or 1.2, e.Time)
		end
	end,
}

-- "z z Z" floating up from a sleepy glassy (Midnight's lullaby). A BillboardGui on a pooled anchor; letters only, no
-- words, so it reads at any age. Bystander fights skip it (low tier).
local function sleepy(fx, side, target, seconds, start)
	if fx:Low(side) then
		return
	end
	local _, accent = fx:Colors(side)
	local anchor = fx:Part("Anchor", WHITE)
	local stars = { fx:Part("NovaStar", accent), fx:Part("NovaStar", WHITE) }
	local board = Instance.new("BillboardGui")
	board.Name, board.Size, board.LightInfluence = "Sleepy", UDim2.fromScale(2.2, 2.2), 0
	board.AlwaysOnTop, board.Adornee, board.Parent = false, anchor, anchor
	local letters = {}
	for i = 1, 3 do
		local z = Instance.new("TextLabel")
		z.BackgroundTransparency, z.Text = 1, if i == 3 then "Z" else "z"
		z.FontFace = Font.new("rbxasset://fonts/families/DenkOne.json")
		z.TextScaled, z.TextColor3 = true, Color3.fromHex("#E9E6FF")
		z.Size = UDim2.fromScale(0.28 + 0.1 * i, 0.28 + 0.1 * i)
		z.AnchorPoint = Vector2.new(0.5, 0.5)
		z:SetAttribute("TextFit", false)
		local stroke = Instance.new("UIStroke")
		stroke.Color, stroke.Thickness = Color3.fromHex("#2B2F95"), 2
		stroke.Parent = z
		z.Parent = board
		letters[i] = z
	end
	local parts = { anchor, stars[1], stars[2] }
	local effect = fx:Spawn({
		Side = side,
		Key = "sleepy:" .. target,
		Start = start,
		Seconds = seconds,
		Parts = parts,
		Stop = function()
			board:Destroy()
		end,
		Step = function(_, age, k)
			local f = fx:Fighter(target)
			if not f or f.Broken or f.Finishing then
				return false
			end
			local pos, size = fx:Body(target)
			anchor.CFrame = CFrame.new(pos + Vector3.yAxis * size * 0.9)
			for i, z in letters do
				local t = (age * 0.7 + i / 3) % 1
				z.Position = UDim2.fromScale(0.35 + 0.18 * i + 0.05 * math.sin(age * 3 + i), 0.85 - 0.7 * t)
				z.TextTransparency = 0.1 + 0.9 * math.max(fx.smooth((t - 0.7) / 0.3), fx.smooth((k - 0.85) / 0.15))
			end
			for i, p in stars do
				local a = age * 2.2 + i * math.pi
				fx:Fit(p, size * 0.35)
				p.CFrame = CFrame.new(pos + Vector3.new(math.cos(a), 0.55, math.sin(a)) * size * 0.75)
					* CFrame.Angles(0, a, 0)
				p.Transparency = 0.1 + 0.9 * fx.smooth((k - 0.85) / 0.15)
			end
		end,
	})
	if not effect then -- already over (a late event): nothing was registered, so clean up here
		board:Destroy()
		for _, p in parts do
			fx:Free(p)
		end
	end
end

Kits.midnight_moon = {
	Windup = function(fx, side, e)
		-- The moon rocks like a cradle while stars gather in, then a hush (Hero two-stage anticipation).
		local _, accent = fx:Colors(side)
		gather(fx, side, e, { MoteKind = "NovaStar", Motes = 6, MoteSize = 0.42, Motion = "rear", MotionAmount = 0.8 })
		fx:Move(side, "wiggle", e.Windup or 0.5, 0.7)
		fx:Glints(side, (fx:Body(side)), accent, 8, { Speed = NumberRange.new(1, 2.5) })
		fx:Cue(side, "midnight_lullaby")
	end,
	Release = function(fx, side, e, ctx)
		local color, accent = fx:Colors(side)
		-- The lullaby: soft violet rings with gold star notes drifting out on them.
		pulseRings(fx, side, e, ctx, { Rings = 3, Kind = "Ring" })
		local range = e.Range or 5.5
		local notes = {}
		for i = 1, fx:Count(side, 8) do
			notes[i] = fx:Part("NovaStar", if i % 2 == 0 then accent else WHITE)
		end
		fx:Spawn({
			Side = side,
			Start = e.Time,
			Seconds = math.max(0.4, e.Duration or 0.6) + 0.3,
			Parts = notes,
			Step = function(_, age, k)
				local here = ctx.Here()
				local c = workspace.CurrentCamera.CFrame
				for i, p in notes do
					local a = i / #notes * math.pi * 2 + age * 1.2
					local r = range * fx.easeOut(k) * 0.9
					local bob = math.sin(age * 6 + i) * 0.25
					fx:Fit(p, 0.55 * (1 - 0.4 * k))
					p.CFrame = CFrame.new(here + c.RightVector * math.cos(a) * r + c.UpVector * (math.sin(a) * r + bob))
						* CFrame.Angles(0, 0, age * 2)
					p.Transparency = 0.05 + 0.95 * fx.smooth((k - 0.75) / 0.25)
				end
			end,
		})
		fx:Light(side, ctx.Here, color, 0.6)
		fx:HeroBloom(side, 0.8)
	end,
	Hit = function(fx, side, _, at)
		local color, accent = fx:Colors(side)
		fx:Flash(side, at, color, 1.8, 0.16)
		fx:Chips(side, at, accent, 6, 3, 0.6, { Kind = "NovaStar", Size = 0.4, Alternate = WHITE, Up = 1 })
		fx:Glints(side, at, accent, 10, { Speed = NumberRange.new(1, 3) })
	end,
	Status = function(fx, side, e)
		if e.Kind == "Mark" and e.Target then
			sleepy(fx, side, e.Target, e.Seconds or 3.5, e.Time)
			fx:Cue(side, "midnight_sleepy")
		end
	end,
	Payoff = function(fx, side, _, at)
		-- Wake-up bonk: a big gold star pops on the clash and the Zzz vanish.
		local color, accent = fx:Colors(side)
		fx:StopKey("sleepy:" .. (3 - side))
		local star = fx:Part("NovaStar", accent)
		fx:Spawn({
			Side = side,
			Seconds = 0.45,
			Parts = { star },
			Step = function(_, _, k)
				fx:Fit(star, 3.2 * fx.pop(k / 0.3))
				star.CFrame = fx.face(at) * CFrame.Angles(0, 0, 0.25 + k * 0.6)
				star.Transparency = 0.02 + 0.98 * fx.easeIn(k)
			end,
		})
		fx:Spokes(side, at, accent, 8, 2.2, 0.3, { Alternate = color, Width = 0.3 })
		fx:Flash(side, at, WHITE, 1.6, 0.12)
		fx:Glints(side, at, accent, 12)
		fx:Cue(side, "midnight_bonk")
	end,
}

-- Hollowlight keeps its bespoke LanternSeeds presentation, with the Hero tier of the shared Ready/cast states
-- (premium seasonal set; rarity and stats stay Epic). docs/vfx/HOLLOWLIGHT_PREMIUM.md section 4.
Kits.hollowlight = { Skip = true, Tier = "Hero" }

-- ===================================================================================================================
-- Shape defaults (new kits fall back to these until they get their own moments)
-- ===================================================================================================================
-- A faceted crystal plate facing the foe while a guard is up (kits without their own guard look).
local function plate(fx, side, e)
	local color, accent = fx:Vivid(side), select(2, fx:Colors(side))
	local f = fx:Fighter(side)
	local p, rim = fx:Part("GuardPlate", color, Enum.Material.Glass), fx:Part("ShockCrown", accent)
	fx:Spawn({
		Side = side,
		Key = "guard:" .. side,
		Start = e.Time,
		Seconds = e.Duration or 2.5,
		Parts = { p, rim },
		Step = function(_, age, k)
			if f.Broken or f.Finishing or f.GuardConsumed then
				return false
			end
			local pos, size = fx:Body(side)
			local dir = fx:Toward(side)
			local at = pos + dir * size * 0.6
			local normal = (dir - cam().LookVector * 0.6).Unit
			local d = size * 1.2 * fx.pop(age / 0.22)
			fx:Fit(p, d)
			p.CFrame = CFrame.lookAt(at, at + normal)
			p.Transparency = 0.2 + 0.8 * fx.smooth((k - 0.9) / 0.1)
			fx:Fit(rim, d * 1.15)
			rim.CFrame = CFrame.lookAt(at, at + normal) * CFrame.Angles(0, 0, age * 1.5)
			rim.Transparency = 0.15 + 0.2 * math.sin(age * 8) + 0.65 * fx.smooth((k - 0.9) / 0.1)
		end,
	})
	fx:Glints(side, (fx:Body(side)), accent, 8)
end
Kits.plate = plate

Kits.default = {
	Windup = function(fx, side, e)
		gather(fx, side, e)
	end,
	Release = function(fx, side, e, ctx)
		local s = e.Shape
		if s == "guard" then
			plate(fx, side, e)
		elseif s == "sweep" then
			Kits.crescent_axe.Release(fx, side, e, ctx)
		elseif s == "boost" then
			local color = fx:Vivid(side)
			local band = fx:Part("ShockCrown", color)
			aura(fx, side, e, e.Duration or 2, function(pos, size, age, k)
				fx:Fit(band, size * 1.2 * fx.pop(age / 0.2))
				band.CFrame = CFrame.new(pos) * CFrame.Angles(math.pi / 2, 0, age * 6)
				band.Transparency = 0.2 + 0.8 * fx.smooth((k - 0.9) / 0.1)
			end, { band })
		elseif s == "ray" then
			ray(fx, side, e, ctx)
		elseif s == "projectile" or s == "volley" then
			shots(fx, side, e, ctx)
		elseif s == "cone" or s == "breath" then
			cone(fx, side, e, ctx)
		elseif s == "pulse" then
			pulseRings(fx, side, e, ctx)
		end
	end,
	Hit = function(fx, side, _, at)
		local color, accent = fx:Colors(side)
		fx:Impact(side, at, color, accent, 1)
	end,
	Miss = function(fx, side, _, ctx)
		local color = fx:Colors(side)
		if ctx and ctx.Origin then
			fx:Glints(side, (if ctx.Here then ctx.Here() else ctx.Origin) + ctx.Direction * 4, color, 4)
		end
	end,
	Payoff = function(fx, side, _, at)
		local color, accent = fx:Colors(side)
		fx:Impact(side, at, color, accent, 1)
	end,
	Block = function(fx, side)
		local color = fx:Colors(side)
		local at = (fx:Body(side))
		fx:StopKey("guard:" .. side)
		fx:Ring(side, at, color, 1, 5, 0.3, { Kind = "ShockCrown" })
		fx:Move(side, "recoil", 0.3, 1)
	end,
	Status = function(fx, side, e)
		if e.Kind == "Heal" then
			Kits.heal(fx, side, e)
		end
	end,
}

return Kits
