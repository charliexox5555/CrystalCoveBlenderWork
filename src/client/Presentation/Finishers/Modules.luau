-- The finisher module kit (docs/design/COSMETICS_V2.md §4.1): parameterised building blocks every standard show
-- composes on Kit's rig and single clock. Each constructor builds its actors/emitters once (pooled with the rig)
-- and registers a per-frame step; a show only writes what is unique to its hero.
--   Flash, Shockwave        peaks
--   ShardBurst              pieces that fly, tumble, bounce on a floor and fade (or pop)
--   BeamColumn              Epic+ light column
--   ParticleField           burst / rain / rise / swirl / orbit emitters, budget-scaled by detail
--   Light                   PointLight curve (skipped in low detail)
--   reveal()                MeshReveal arrival curves: drop, assemble, grow, swoop, orbit, rise
-- Camera beats live in Config/FinisherShows (`Beats`), sound in Config/FinisherAudio.
local Kit = require(script.Parent.Kit)
local M = {}

local WHITE = Color3.new(1, 1, 1)

-- Flash: a bright ball at the peak. spec: At, Size, Seconds, Color, Offset (view space)
function M.Flash(rig, spec)
	local actor = rig:Actor("Flash", { Shape = Enum.PartType.Ball, Size = 1, Color = spec.Color or WHITE })
	local seconds = spec.Seconds or 0.14
	rig:AddStep(function(t)
		local u = (t - spec.At) / seconds
		if u >= 0 and u < 1 then
			local at = rig:At(
				(spec.Offset or Vector3.zero).X,
				(spec.Offset or Vector3.zero).Y,
				(spec.Offset or Vector3.zero).Z
			)
			rig:Place(actor, CFrame.new(at), 0.5 + spec.Size * Kit.easeOut(u), 0.15 + 0.85 * math.sqrt(u))
		else
			rig:Hide(actor)
		end
	end)
	return actor
end

-- Shockwave: an expanding ring. spec: At, Radius, Seconds, Color, Plane ("view" | "ground"), Height (view y),
-- Offset (view space), Mesh (default crown), Thickness, Spin, Count (extra delayed copies), Delay
function M.Shockwave(rig, spec)
	local count = if rig.Low then 1 else (spec.Count or 1)
	local rings = {}
	for i = 1, count do
		rings[i] = rig:Actor("Shockwave", {
			Mesh = spec.Mesh or { "ShockCrown", "Ring" },
			Size = 2,
			Color = if i % 2 == 0 and spec.Accent then spec.Accent else (spec.Color or WHITE),
			Transparency = 0.08,
		})
	end
	local seconds = spec.Seconds or 0.5
	rig:AddStep(function(t)
		for i, ring in rings do
			local u = (t - spec.At - (i - 1) * (spec.Delay or 0.07)) / seconds
			if u >= 0 and u < 1 then
				local e = Kit.easeOut(u)
				local off = spec.Offset or Vector3.zero
				local center = rig:At(off.X, (spec.Height or 0) + off.Y, off.Z)
				local cf = if spec.Plane == "ground"
					then CFrame.new(center) * CFrame.Angles(math.pi / 2, 0, (spec.Spin or 0) * u)
					else CFrame.new(center) * rig.Facing.Rotation * CFrame.Angles(0, 0, (spec.Spin or 0) * u)
				rig:Disc(ring, cf, 1 + spec.Radius * (1 + (i - 1) * 0.25) * e, u, spec.Thickness or 1)
			else
				rig:Hide(ring)
			end
		end
	end)
	return rings
end

--[[ ShardBurst: pieces launched at `At` from `From(i)` (view-space start, default origin) along `Dir(i)` (view space).
	spec: At, Count, Mesh, Shape, Size {min,max}, Tints {Color3}, Material, Transparency, Reflectance,
	Speed {min,max}, Lift, Gravity, Spin, Drag (0 = none),
	Floor (view y; pieces bounce Bounces times with Restitution), Fade {At (s after launch), Seconds},
	PopAt (function(i) -> show time the piece pops into sparkles, optional) with PopEmitter (emitter name),
	Trails (how many pieces get a trail), TrailColor, Seed, Hidden (bool, skip before At), Orient ("tumble" | "face")]]
function M.ShardBurst(rig, spec)
	local random = Random.new(spec.Seed or 5)
	local count = if rig.Low then math.max(1, math.floor(spec.Count / 2)) else spec.Count
	local pieces = {}
	local size = spec.Size or { 0.6, 1 }
	local speed = spec.Speed or { 8, 12 }
	local gravity = spec.Gravity or 14
	for i = 1, count do
		local tints = spec.Tints or { WHITE }
		local actor = rig:Actor(spec.Name or "Shard", {
			Mesh = spec.Mesh,
			Shape = spec.Shape,
			NativeSize = spec.NativeSize,
			Size = random:NextNumber(size[1], size[2]),
			Color = tints[(i - 1) % #tints + 1],
			Material = spec.Material or Enum.Material.Glass,
			Transparency = spec.Transparency or 0.15,
			Reflectance = spec.Reflectance or 0.2,
		})
		local dir = if spec.Dir
			then spec.Dir(i, count, random)
			else Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-0.2, 1), random:NextNumber(-0.6, 0.6)).Unit
		local start = if spec.From then spec.From(i, count) else Vector3.zero
		local v = dir * random:NextNumber(speed[1], speed[2]) + Vector3.new(0, spec.Lift or 0, 0)
		-- Precompute bounce arcs in view space (independent of where the show plays).
		local arcs = { { T = 0, P = start, V = v } }
		if spec.Floor then
			local p, vel, t0 = start, v, 0
			for _ = 1, spec.Bounces or 2 do
				local dy = p.Y - spec.Floor
				local a, b, c = -0.5 * gravity, vel.Y, dy
				local disc = b * b - 4 * a * c
				if disc < 0 then
					break
				end
				local hit = (-b - math.sqrt(disc)) / (2 * a)
				if hit <= 0 then
					break
				end
				p = p + Vector3.new(vel.X, 0, vel.Z) * hit + Vector3.new(0, vel.Y * hit - 0.5 * gravity * hit * hit, 0)
				local vy = (vel.Y - gravity * hit) * -(spec.Restitution or 0.45)
				vel = Vector3.new(vel.X * 0.7, vy, vel.Z * 0.7)
				t0 += hit
				table.insert(arcs, { T = t0, P = Vector3.new(p.X, spec.Floor, p.Z), V = vel, Land = true })
			end
		end
		local piece = {
			Actor = actor,
			Arcs = arcs,
			Spin = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-1, 1), random:NextNumber(-1, 1))
				* (spec.Spin or 6),
			PopAt = spec.PopAt and spec.PopAt(i, count),
		}
		if i <= (spec.Trails or 0) then
			piece.Trail = rig:Trail(actor, { spec.TrailColor or actor.Part.Color, WHITE }, 0.3, 0.35)
		end
		pieces[i] = piece
	end
	local function pose(piece, a)
		local arc = piece.Arcs[1]
		for _, candidate in piece.Arcs do
			if a >= candidate.T then
				arc = candidate
			end
		end
		local dt = a - arc.T
		local drag = spec.Drag or 0
		local travel = if drag > 0 then (1 - math.exp(-drag * dt)) / drag else dt
		local h = Vector3.new(arc.V.X, 0, arc.V.Z) * travel
		local y = arc.V.Y * dt - 0.5 * gravity * dt * dt
		local p = arc.P + h + Vector3.new(0, y, 0)
		if spec.Floor and p.Y < spec.Floor then
			p = Vector3.new(p.X, spec.Floor, p.Z)
		end
		return p, arc, dt
	end
	rig:AddStep(function(t)
		local a = t - spec.At
		for _, piece in pieces do
			if a < 0 or (piece.PopAt and t >= piece.PopAt + 0.08) then
				rig:Hide(piece.Actor)
				if piece.Trail then
					piece.Trail.Enabled = false
				end
				continue
			end
			local p, arc, dt = pose(piece, a)
			local world = rig.View:PointToWorldSpace(p)
			local rot = if spec.Orient == "face"
				then rig.Facing.Rotation * CFrame.Angles(0, 0, piece.Spin.Z * a * 0.2)
				else CFrame.Angles(piece.Spin.X * a, piece.Spin.Y * a, piece.Spin.Z * a)
			-- Squash on landing.
			local squash = if arc.Land then Kit.spring(dt, 34, 12) * 0.25 else 0
			local scale = Vector3.new(1 + squash * 0.6, 1 - squash, 1 + squash * 0.6) * Kit.pop(a / 0.1)
			local alpha = 0
			if spec.Fade then
				alpha = Kit.smooth((a - spec.Fade.At) / spec.Fade.Seconds)
			end
			if piece.PopAt and t >= piece.PopAt then
				local u = (t - piece.PopAt) / 0.08
				scale *= 1 + 0.35 * u
				alpha = math.max(alpha, u)
			end
			rig:Place(piece.Actor, CFrame.new(world) * rot, scale, alpha)
			if piece.Trail then
				piece.Trail.Enabled = a > 0.02 and alpha < 0.7
			end
		end
	end)
	-- Pops: sparkle at the piece's position.
	if spec.PopEmitter then
		local socket = rig:SocketPart("PopSocket", Vector3.one * 0.2)
		rig:Emitter(spec.PopEmitter, spec.PopSpec or {
			Socket = socket,
			Texture = "StarGlint",
			Color = { WHITE, spec.Tints and spec.Tints[1] or WHITE },
			Size = { { 0, 0.8 }, { 1, 0 } },
			Lifetime = { 0.2, 0.35 },
			Speed = { 5, 9 },
			Drag = 6,
		})
		for _, piece in pieces do
			if piece.PopAt then
				rig:On(piece.PopAt, function(r)
					local e = r.Emitters[spec.PopEmitter]
					if e and piece.Actor.Part.Transparency < 1 then
						socket.CFrame = piece.Actor.Part.CFrame
						e:Emit(math.max(1, math.floor(5 * r.ParticleScale + 0.5)))
					end
				end)
			end
		end
	end
	return pieces
end

-- BeamColumn: a light column. spec: At, Height, Width, Colors {Color3} (beam gradient), CoreColor, Rise, Hold,
-- Fade, Twist, Offset (view)
function M.BeamColumn(rig, spec)
	local colors = spec.Colors or { WHITE }
	local core = rig:Actor("ColumnCore", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 1, 1),
		Color = spec.CoreColor or colors[1],
		Transparency = 0.15,
	})
	local inner = rig:Actor("ColumnInner", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 1, 1),
		Color = WHITE,
		Transparency = 0.05,
	})
	local beam
	if not (rig.Low or rig.Still) then
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = rig.Socket, rig.Socket
		beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		local keys = {}
		for i, c in colors do
			table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #colors - 1), c))
		end
		beam.Color = ColorSequence.new(keys)
		beam.LightEmission, beam.LightInfluence, beam.FaceCamera = 1, 0, true
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.8, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Segments = 2
		beam.Enabled = false
		beam.Parent = rig.Socket
		table.insert(rig.Beams, beam)
		spec.A0, spec.A1 = a0, a1
	end
	rig:AddStep(function(t)
		local a = t - spec.At
		local life = spec.Rise + spec.Hold + spec.Fade
		if a < 0 or a > life then
			rig:Hide(core)
			rig:Hide(inner)
			if beam then
				beam.Enabled = false
			end
			return
		end
		local rise = Kit.easeOut(a / spec.Rise)
		local fade = Kit.smooth((a - spec.Rise - spec.Hold) / spec.Fade)
		local height = spec.Height * rise
		local width = spec.Width * (1 + 0.25 * math.sin(a * 18) * (1 - fade)) * (1 - 0.5 * fade)
		local off = spec.Offset or Vector3.zero
		local base = rig:At(off.X, off.Y, off.Z)
		local cf = CFrame.new(base + Vector3.yAxis * height / 2) * CFrame.Angles(0, (spec.Twist or 0) * a, math.pi / 2)
		rig:Place(core, cf, Vector3.new(height, width, width), fade)
		rig:Place(inner, cf, Vector3.new(height, width * 0.45, width * 0.45), fade)
		if beam then
			beam.Enabled = fade < 0.95
			spec.A0.WorldPosition = base
			spec.A1.WorldPosition = base + Vector3.yAxis * height * 1.15
			beam.Width0, beam.Width1 = width * 2.4, width * 1.2
		end
	end)
	return core
end

--[[ ParticleField: spec Name, Mode ("burst" | "rain" | "rise" | "swirl" | "orbit"), At, Until (for timed modes),
	Count (total), Radius, Height, Speed, Emitter (Kit emitter spec: Texture, Color, Size, ...), Offset (view y).
	burst: all at At from the offset point. rain: from a disc Height above, falling. rise: from a disc below,
	rising. swirl/orbit: a socket circles the centre (swirl spirals inward/upward), emitting along the path.]]
function M.ParticleField(rig, spec)
	local mode = spec.Mode or "burst"
	local socket = rig:SocketPart(spec.Name .. "Socket", Vector3.new(spec.Radius or 1, 0.2, spec.Radius or 1) * 2)
	local e = spec.Emitter
	e.Socket = socket
	if mode == "rain" or mode == "rise" then
		e.Shape = Enum.ParticleEmitterShape.Disc
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Direction = if mode == "rain" then Enum.NormalId.Bottom else Enum.NormalId.Top
	end
	rig:Emitter(spec.Name, e)
	local emitted = 0
	local function reset()
		emitted = 0
	end
	rig:AddStep(function(t)
		local y = spec.Offset or 0
		local center = rig:At(0, y, 0)
		if mode == "burst" then
			socket.CFrame = CFrame.new(center)
			return
		end
		if mode == "rain" then
			socket.CFrame = CFrame.new(center + Vector3.yAxis * (spec.Height or 6))
		elseif mode == "rise" then
			socket.CFrame = CFrame.new(center - Vector3.yAxis * (spec.Height or 3))
		else
			local u = Kit.clamp01((t - spec.At) / math.max(0.05, spec.Until - spec.At))
			local radius = (spec.Radius or 3) * (if mode == "swirl" then 1 - 0.55 * u else 1)
			local angle = t * (spec.Spin or 9)
			local lift = if mode == "swirl" then (spec.Lift or 2) * u - 1 else 0
			socket.CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * radius, lift, math.sin(angle) * radius))
		end
		-- Timed modes emit evenly between At and Until.
		if t >= spec.At and t <= spec.Until then
			local target = math.floor(spec.Count * rig.ParticleScale * (t - spec.At) / (spec.Until - spec.At))
			local n = target - emitted
			if n > 0 and rig.Emitters[spec.Name] then
				rig.Emitters[spec.Name]:Emit(n)
				emitted = target
			end
		end
	end, reset)
	if mode == "burst" then
		rig:Burst(spec.At, spec.Name, spec.Count)
	end
	return socket
end

-- Light: a PointLight curve. spec: At, Brightness, Range, Color, Rise, Decay, Offset (view)
function M.Light(rig, spec)
	local holder = rig:SocketPart("LightSocket", Vector3.one * 0.2)
	local light = rig:Light({ Part = holder }, spec.Color or WHITE, spec.Range or 14)
	if not light then
		return nil
	end
	rig:AddStep(function(t)
		local off = spec.Offset or Vector3.zero
		holder.CFrame = CFrame.new(rig:At(off.X, off.Y, off.Z))
		local a = t - spec.At
		local rise = spec.Rise or 0
		local up = if rise > 0 then Kit.smooth((t - (spec.At - rise)) / rise) else (if a >= 0 then 1 else 0)
		local down = if a > 0 then math.max(0, 1 - a / (spec.Decay or 0.5)) else 1
		light.Brightness = spec.Brightness * math.min(up, down)
	end)
	return light
end

--[[ reveal: MeshReveal arrival curve, evaluated by a show for its hero. Returns (offset in view space, scale
	Vector3, done 0..1). spec: Mode, T0, T1, From (view offset for swoop/drop/rise), To (view offset), Height,
	Overshoot, Squash.]]
function M.reveal(spec, t)
	local u = Kit.clamp01((t - spec.T0) / math.max(1e-3, spec.T1 - spec.T0))
	local to = spec.To or Vector3.zero
	local mode = spec.Mode
	local squash = spec.Squash or 0.2
	if mode == "drop" then
		local from = to + Vector3.new(0, spec.Height or 6, 0)
		local p = from:Lerp(to, Kit.easeIn(u))
		local land = t - spec.T1
		local s = if land < 0
			then Vector3.new(1 - 0.08 * u, 1 + squash * u, 1 - 0.08 * u)
			else Vector3.new(
				1 + 0.6 * squash * Kit.spring(land, 30, 9),
				1 - squash * Kit.spring(land, 30, 9),
				1 + 0.6 * squash * Kit.spring(land, 30, 9)
			)
		return p, s, u
	elseif mode == "grow" or mode == "rise" then
		local k = if mode == "grow" then Kit.pop(u) else Kit.easeOut(u)
		local from = if mode == "rise" then to - Vector3.new(0, spec.Height or 3, 0) else to
		local stretch = 1 + squash * math.sin(u * math.pi)
		return from:Lerp(to, Kit.easeOut(u)), Vector3.new(k / stretch, k * stretch, k / stretch), u
	elseif mode == "swoop" then
		local from = spec.From or (to + Vector3.new(-10, 6, -2))
		local mid = (from + to) / 2 + Vector3.new(0, spec.Height or 4, 0)
		local e = Kit.easeOut(u)
		local p = from:Lerp(mid, e):Lerp(mid:Lerp(to, e), e)
		return p, Vector3.one * (0.6 + 0.4 * e), u
	elseif mode == "orbit" then
		local radius = spec.Radius or 4
		local angle = (spec.Phase or 0) + (spec.Turns or 2) * math.pi * 2 * u
		local p = to
			+ Vector3.new(math.cos(angle) * radius, (spec.Height or 3) * (1 - u * 0.3), math.sin(angle) * radius)
		return p, Vector3.one, u
	end
	-- assemble: the caller lerps its own pieces; return the shared ease.
	return to, Vector3.one * Kit.pop(u), u
end

return M
