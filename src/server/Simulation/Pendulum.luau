-- Deterministic spherical pendulums. Local X follows HookA -> HookB, Y is world up.
-- The same integrator runs live and in the offline calibration tool; no physics instances.
local Shared = if script then game.ReplicatedStorage.Shared else nil
local Balance = if Shared then require(Shared.Config.Balance) else require("../../shared/Config/Balance")
local Rules = if Shared then require(Shared.FightRules) else require("../../shared/FightRules")
local Rng = if Shared then require(Shared.Rng) else require("../../shared/Rng")
local Geometry = if script then require(script.Parent.AttackGeometry) else require("./AttackGeometry")
local Turnaround = if script then require(script.Parent.Turnaround) else require("./Turnaround")
local SignatureAttacks = if script then require(script.Parent.SignatureAttacks) else require("./SignatureAttacks")
local V = if script then Vector3 else require("@lune/roblox").Vector3
local M = Balance.Motion
local Pendulum = {}

local function tangent(v, n)
	return v - n * v:Dot(n)
end

function Pendulum.pull(aim, yaw, side)
	return V.new(
		(if side == 1 then -1 else 1) * math.sin(aim) * math.cos(yaw),
		-math.cos(aim),
		math.sin(aim) * math.sin(yaw)
	) * M.StringLength
end

function Pendulum.center(sim, side)
	local b = sim.Bodies[side]
	local center = sim.Fight.Fighters[side].BodyCenter or M.BodyCenter
	return sim.Hooks[side] + b.P * (1 + center * M.GlassyScale / M.StringLength)
end

function Pendulum.fireDirection(sim, side)
	local b = sim.Bodies[side]
	local facing = b.Facing
	local influence = if sim.Fight.Fighters[side].Signature
		then Balance.CombatRelease.TwistInfluence
		else M.PowerTwistInfluence
	local c, s = math.cos(b.Twist * influence), math.sin(b.Twist * influence)
	return V.new(facing.X * c - facing.Z * s, facing.Y, facing.X * s + facing.Z * c).Unit
end

function Pendulum.lands(sim, side)
	local b = sim.Bodies[side]
	local delta = Pendulum.center(sim, 3 - side) - Pendulum.center(sim, side)
	local facing = b.Facing
	-- The nozzle follows the body as the string twists. Aimed effects use this same direction.
	local c, s = math.cos(b.Twist * M.PowerTwistInfluence), math.sin(b.Twist * M.PowerTwistInfluence)
	facing = V.new(facing.X * c - facing.Z * s, facing.Y, facing.X * s + facing.Z * c)
	b.FireDirection = facing
	if sim.AimLog then
		table.insert(sim.AimLog, {
			Time = sim.Fight.Time,
			Side = side,
			Distance = delta.Magnitude,
			Dot = delta.Unit:Dot(facing),
			Twist = b.Twist,
		})
	end
	return delta.Magnitude <= M.PowerLandDistance and delta.Unit:Dot(facing) >= M.PowerLandCos
end

function Pendulum.new(setup, seed, gap)
	local sim = {
		Seed = seed,
		Bodies = {},
		Hooks = { V.new(-(gap or M.HookGap) / 2, 0, 0), V.new((gap or M.HookGap) / 2, 0, 0) },
		Rng = Rng.new(seed + 104729),
		LastHit = -10,
		LastCollision = -10,
		Attacks = {},
		LastEncounter = -10,
		PreviousApproach = 0,
		Metrics = { Speeds = {}, Shares = {}, Misses = 0, Powers = {}, Landed = {}, MaxRadiusError = 0 },
		MotionEvents = {},
		AimLog = {},
	}
	setup.PowerLands = function(side)
		return Pendulum.lands(sim, side)
	end
	setup.CastsManaged = true
	setup.CanReleaseCast = function(cast)
		local target = sim.Fight.Fighters[3 - cast.Side]
		return (Pendulum.center(sim, 3 - cast.Side) - Pendulum.center(sim, cast.Side)).Magnitude
			<= cast.Params.Range + target.Radius * M.GlassyScale
	end
	sim.Fight = Rules.new(setup)
	for side, f in sim.Fight.Fighters do
		sim.Bodies[side] = {
			P = Pendulum.pull(f.Aim, f.AimYaw, side),
			V = V.zero,
			Twist = 0,
			Spin = 0,
			Tilt = V.zero,
			Tumble = V.zero,
			Wander = 0,
			NextWander = 0,
			Facing = V.new(if side == 1 then 1 else -1, 0, 0),
			NextTracking = 0,
			Turnaround = Turnaround.new(Pendulum.pull(f.Aim, f.AimYaw, side).Y),
		}
	end
	return sim
end

local function constrain(b)
	b.P = b.P.Unit * M.StringLength
	local ceiling = -M.StringLength * math.cos(M.MaxAngle)
	if b.P.Y > ceiling then
		local flat = V.new(b.P.X, 0, b.P.Z).Unit
		b.P = flat * (M.StringLength * math.sin(M.MaxAngle)) + V.new(0, ceiling, 0)
		if b.V.Y > 0 then
			b.V = V.new(b.V.X, 0, b.V.Z)
		end
	end
	b.V = tangent(b.V, b.P.Unit)
end

local function integrate(sim, side, dt)
	local b, f = sim.Bodies[side], sim.Fight.Fighters[side]
	local signature = f.Signature
	if signature and sim.Fight.Time < (signature.BoostUntil or -1) and b.LastBoost ~= signature.LastReady then
		b.LastBoost = signature.LastReady
		if signature.Kit.Impulse and b.V.Magnitude > 0.1 then
			b.V += b.V.Unit * signature.Kit.Impulse
		end
	end
	local previousVy = b.V.Y
	if sim.Fight.Time >= b.NextWander then
		b.Wander = (sim.Rng() * 2 - 1) * M.WanderStrength * M.StringLength
		b.NextWander = sim.Fight.Time + M.WanderIntervalMin + sim.Rng() * (M.WanderIntervalMax - M.WanderIntervalMin)
	end
	local frozen = Rules.isFrozen(sim.Fight, side)
	local amp = math.min(M.MaxAngle, Rules.targetAmplitude(f.Swing) * Rules.swingMultiplier(sim.Fight, side))
	local energy = b.V.Magnitude ^ 2 / 2 + M.Gravity * (b.P.Y + M.StringLength)
	local target = M.Gravity * M.StringLength * (1 - math.cos(amp))
	local drive = V.zero
	if not frozen and b.V.Magnitude > 0.1 then
		drive = b.V.Unit
			* math.clamp(
				(target - energy) * M.DriveGain / math.max(b.V.Magnitude, 2),
				-M.DriveAcceleration,
				M.DriveAcceleration
			)
	end
	local drag = M.AirDrag + (if frozen then M.FrozenDamping else 0)
	local foe = sim.Bodies[3 - side]
	local phase = if frozen then 0 else -(b.P.X + foe.P.X) * M.PhaseCoupling - (b.V.X + foe.V.X) * M.PhaseDamping
	local force = V.new(
		phase,
		-M.Gravity,
		b.Wander * (if frozen then 0 else 1) - b.P.Z * M.OutOfPlaneDamping - b.V.Z * M.OutOfPlaneDamping
	) + drive - b.V * drag
	if sim.Well and sim.Fight.Time < sim.Well.Until then
		local delta = sim.Well.Origin - Pendulum.center(sim, side)
		if delta.Magnitude > 0.01 and delta.Magnitude <= sim.Well.Range then
			force += delta.Unit * sim.Well.Force
		end
	end
	b.V += tangent(force, b.P.Unit) * dt
	b.P += b.V * dt
	constrain(b)
	b.Spin += (-M.TwistStiffness * b.Twist - M.TwistDamping * b.Spin) * dt
	b.Spin = math.clamp(b.Spin, -M.MaxSpin, M.MaxSpin)
	b.Twist += b.Spin * dt
	b.Tumble += (-b.Tilt * M.TumbleStiffness - b.Tumble * M.TumbleDamping) * dt
	b.Tilt += b.Tumble * dt
	if b.Tilt.Magnitude > M.MaxTilt then
		b.Tilt = b.Tilt.Unit * M.MaxTilt
	end
	sim.Metrics.MaxRadiusError = math.max(sim.Metrics.MaxRadiusError, math.abs(b.P.Magnitude - M.StringLength))
	if Turnaround.step(b.Turnaround, sim.Fight.Time, previousVy, b.V.Y, b.P.Y, sim.LastCollision) then
		Rules.turnaround(sim.Fight, side)
	end
end

local function array(v)
	return { v.X, v.Y, v.Z }
end

local function sweepPoint(attack, age)
	local angle = (-0.5 + math.clamp(age / attack.Cast.Params.Duration, 0, 1)) * attack.Cast.Params.Arc
	return attack.Origin + (attack.Direction * math.cos(angle) + attack.Up * math.sin(angle)) * attack.Cast.Params.Range
end

local function attacks(sim, dt)
	for _, cast in Rules.drainCasts(sim.Fight) do
		if sim.Fight.Over then
			break
		end
		local origin, direction = Pendulum.center(sim, cast.Side), Pendulum.fireDirection(sim, cast.Side)
		if cast.Params.StoredOrigin then
			origin = V.new(table.unpack(cast.Params.StoredOrigin))
		end
		if cast.Shape == "orbit" then
			origin = (Pendulum.center(sim, 1) + Pendulum.center(sim, 2)) / 2
		end
		if cast.Shape == "projectile" or cast.Shape == "volley" then
			direction = (
				Pendulum.center(sim, 3 - cast.Side)
				+ sim.Bodies[3 - cast.Side].V * Balance.CombatRelease.ProjectileLeadSeconds
				- origin
			).Unit
		end
		if not Rules.releaseCast(sim.Fight, cast, array(origin), array(direction)) then
			continue
		end
		local target = Pendulum.center(sim, 3 - cast.Side)
		local radius = sim.Fight.Fighters[3 - cast.Side].Radius * M.GlassyScale + cast.Params.Radius
		if SignatureAttacks.add(sim, cast, origin, direction, target) then
			continue
		elseif cast.Shape == "ray" then
			local hit, point = Geometry.segmentSphere(origin, origin + direction * cast.Params.Range, target, radius)
			Rules.resolveAbility(sim.Fight, cast.Id, hit, if hit then array(point) else nil)
		elseif cast.Shape == "sweep" then
			local up = V.yAxis - direction * direction.Y
			up = if up.Magnitude > 0.0001 then up.Unit else V.zAxis
			local attack =
				{ Cast = cast, Origin = origin, Direction = direction, Up = up, Age = 0, PreviousTarget = target }
			attack.PreviousPoint = sweepPoint(attack, 0)
			table.insert(sim.Attacks, attack)
		end
	end
	local remaining = {}
	for _, attack in sim.Attacks do
		if sim.Fight.Over then
			break
		end
		local cast = attack.Cast
		attack.Age = math.min(cast.Params.Duration, attack.Age + dt)
		local target = Pendulum.center(sim, 3 - cast.Side)
		local point = sweepPoint(attack, attack.Age)
		local radius = sim.Fight.Fighters[3 - cast.Side].Radius * M.GlassyScale + cast.Params.Radius
		local hit = Geometry.movingSphere(attack.PreviousPoint, point, attack.PreviousTarget, target, radius)
		if hit or attack.Age >= cast.Params.Duration then
			Rules.resolveAbility(sim.Fight, cast.Id, hit, if hit then array(point) else nil)
		else
			attack.PreviousPoint, attack.PreviousTarget = point, target
			table.insert(remaining, attack)
		end
	end
	sim.Attacks = if sim.Fight.Over then {} else remaining
	SignatureAttacks.step(sim, dt, Pendulum.center)
end

function Pendulum.step(sim, dt)
	if sim.Fight.Over then
		return
	end
	for _ = 1, M.Substeps do
		local h = dt / M.Substeps
		for side, body in sim.Bodies do
			if sim.Fight.Time >= body.NextTracking then
				body.Facing = (Pendulum.center(sim, 3 - side) - Pendulum.center(sim, side)).Unit
				body.NextTracking = sim.Fight.Time
					+ (
						if sim.Fight.Fighters[side].Signature
							then Balance.CombatRelease.TrackingSeconds
							else M.PowerTrackingSeconds
					)
			end
		end
		Rules.tick(sim.Fight, h)
		if sim.Fight.Over then
			break
		end
		integrate(sim, 1, h)
		integrate(sim, 2, h)
		attacks(sim, h)
		if sim.Fight.Over then
			break
		end
		local a, b = sim.Bodies[1], sim.Bodies[2]
		local fa, fb = sim.Fight.Fighters[1], sim.Fight.Fighters[2]
		local ca, cb = Pendulum.center(sim, 1), Pendulum.center(sim, 2)
		local delta = cb - ca
		local distance = delta.Magnitude
		local normal = if distance > 0.0001 then delta / distance else V.xAxis
		local relative = a.V - b.V
		local approach = relative:Dot(normal)
		local intoA, intoB = math.max(0, a.V:Dot(normal)), math.max(0, -b.V:Dot(normal))
		local radius = (fa.Radius + fb.Radius) * M.GlassyScale
		if distance < radius then
			local inverseMass = 1 / fa.Mass + 1 / fb.Mass
			-- Resolve overlap on the two string spheres, then apply a momentum impulse.
			for _ = 1, 4 do
				local separation = Pendulum.center(sim, 2) - Pendulum.center(sim, 1)
				local depth = radius - separation.Magnitude
				if depth <= 0 then
					break
				end
				local n = if separation.Magnitude > 0.0001 then separation.Unit else normal
				a.P -= n * depth / (fa.Mass * inverseMass)
				b.P += n * depth / (fb.Mass * inverseMass)
				constrain(a)
				constrain(b)
			end
			if approach > 0 then
				sim.LastCollision = sim.Fight.Time
				local qualifies = approach >= M.MinHitSpeed and sim.Fight.Time - sim.LastHit >= M.HitCooldown
				local impulse = normal * ((1 + M.Restitution) * approach / inverseMass)
				local slip = tangent(relative, normal)
				local friction = slip * M.HitFriction / inverseMass
				local deflect = V.new(0, 0, (sim.Rng() * 2 - 1) * approach * M.HitDeflect / inverseMass)
				a.V += (-impulse - friction + deflect) * Rules.knockbackMultiplier(sim.Fight, 1, qualifies) / fa.Mass
				b.V += (impulse + friction - deflect) * Rules.knockbackMultiplier(sim.Fight, 2, qualifies) / fb.Mass
				constrain(a)
				constrain(b)
				local glancing = normal.X * relative.Z - normal.Z * relative.X
				a.Spin = math.clamp(a.Spin + glancing * M.SpinFromHit / fa.Mass, -M.MaxSpin, M.MaxSpin)
				b.Spin = math.clamp(b.Spin - glancing * M.SpinFromHit / fb.Mass, -M.MaxSpin, M.MaxSpin)
				a.Tumble += V.new(normal.Z, 0, -normal.X) * approach * M.TumbleFromHit * M.TumbleStiffness
				b.Tumble -= V.new(normal.Z, 0, -normal.X) * approach * M.TumbleFromHit * M.TumbleStiffness
				if qualifies then
					-- Use pre-impulse velocities for the approach share.
					local share = if intoA + intoB > 0 then intoA / (intoA + intoB) else 0.5
					sim.LastHit, sim.LastEncounter = sim.Fight.Time, sim.Fight.Time
					table.insert(sim.Metrics.Speeds, approach)
					table.insert(sim.Metrics.Shares, share)
					Rules.hit(sim.Fight, approach, share, (ca.X + cb.X) / 2, (ca.Y + cb.Y) / 2, (ca.Z + cb.Z) / 2)
				end
			end
		elseif
			sim.PreviousApproach > 0
			and approach <= 0
			and distance < M.EncounterDistance
			and sim.Fight.Time - sim.LastEncounter >= M.EncounterCooldown
		then
			sim.LastEncounter = sim.Fight.Time
			sim.Metrics.Misses += 1
			if distance < radius + M.NearMissDistance then
				table.insert(sim.MotionEvents, { Type = "Whoosh", Time = sim.Fight.Time, Distance = distance })
			end
		end
		sim.PreviousApproach = approach
	end
end

function Pendulum.presentation(sim)
	local events = {}
	for _, cast in sim.Fight.PendingCasts do
		table.insert(events, {
			Type = "CastStart",
			Side = cast.Side,
			CastId = cast.Id,
			Kit = cast.Kit,
			Time = cast.Start,
			Windup = cast.Params.Windup + (cast.Params.Hold or 0),
			Shape = cast.Shape,
		})
	end
	for _, cast in sim.Fight.AbilityResults do
		if cast.Released then
			local p = cast.Params
			table.insert(events, {
				Type = "CastRelease",
				Side = cast.Side,
				CastId = cast.Id,
				Kit = cast.Kit,
				Time = cast.ReleasedAt,
				Origin = cast.Origin,
				Direction = cast.Direction,
				Shape = cast.Shape,
				Range = p.Range,
				Radius = p.Radius,
				Arc = p.Arc,
				Pulses = p.Pulses,
				Path = p.Path,
				Duration = p.Duration,
				Resolved = table.clone(cast.Results or {}),
			})
		end
	end
	for side, f in sim.Fight.Fighters do
		local s = f.Signature
		if s and s.EchoPoint then
			table.insert(events, {
				Type = "SignatureStatus",
				Kind = "Echo",
				Side = side,
				Kit = f.Id,
				Time = sim.Fight.Time,
				Point = s.EchoPoint,
				Seconds = math.max(0, s.EchoUntil - sim.Fight.Time),
			})
		end
	end
	return events
end

function Pendulum.snapshot(sim)
	local out = { T = sim.Fight.Time, B = {}, R = Rules.snapshot(sim.Fight) }
	for side, b in sim.Bodies do
		out.B[side] = { b.P.X, b.P.Y, b.P.Z, b.V.X, b.V.Y, b.V.Z, b.Twist, b.Spin, b.Tilt.X, b.Tilt.Z }
	end
	return out
end

function Pendulum.events(sim)
	local out = Rules.drainEvents(sim.Fight)
	for _, e in out do
		if e.Side and (e.Type == "CastStart" or e.Type == "SignatureContact" or e.Type == "SignatureBlock") then
			e.Origin = array(Pendulum.center(sim, e.Side))
			e.Direction = array(Pendulum.fireDirection(sim, e.Side))
		end
		if e.Type == "CastRelease" or e.Type == "SignatureContact" then
			sim.Metrics.Powers[e.Kit] = (sim.Metrics.Powers[e.Kit] or 0) + 1
		end
		if e.Type == "CastContact" or e.Type == "SignatureContact" then
			sim.Metrics.Landed[e.Kit] = (sim.Metrics.Landed[e.Kit] or 0) + (if e.Missed then 0 else 1)
		end
		if e.Type == "Power" then
			e.Origin =
				{ Pendulum.center(sim, e.Side).X, Pendulum.center(sim, e.Side).Y, Pendulum.center(sim, e.Side).Z }
			local direction = sim.Bodies[e.Side].FireDirection or sim.Bodies[e.Side].Facing
			e.Direction = { direction.X, direction.Y, direction.Z }
			sim.Metrics.Powers[e.Id] = (sim.Metrics.Powers[e.Id] or 0) + 1
			sim.Metrics.Landed[e.Id] = (sim.Metrics.Landed[e.Id] or 0) + (if e.Missed then 0 else 1)
		end
	end
	for _, e in sim.MotionEvents do
		table.insert(out, e)
	end
	sim.MotionEvents = {}
	return out
end

return Pendulum
