-- Deterministic spherical pendulums. Local X follows HookA -> HookB, Y is world up.
-- The same integrator runs live and in the offline calibration tool; no physics instances.
local Shared = if script then game.ReplicatedStorage.Shared else nil
local Balance = if Shared then require(Shared.Config.Balance) else require("../../shared/Config/Balance")
local Rules = if Shared then require(Shared.FightRules) else require("../../shared/FightRules")
local Rng = if Shared then require(Shared.Rng) else require("../../shared/Rng")
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
	return sim.Hooks[side] + b.P * (1 + M.BodyCenter * M.GlassyScale / M.StringLength)
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
		Bodies = {},
		Hooks = { V.new(-(gap or M.HookGap) / 2, 0, 0), V.new((gap or M.HookGap) / 2, 0, 0) },
		Rng = Rng.new(seed + 104729),
		LastHit = -10,
		LastEncounter = -10,
		PreviousApproach = 0,
		Metrics = { Speeds = {}, Shares = {}, Misses = 0, Powers = {}, Landed = {}, MaxRadiusError = 0 },
		MotionEvents = {},
		AimLog = {},
	}
	setup.PowerLands = function(side)
		return Pendulum.lands(sim, side)
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
				body.NextTracking = sim.Fight.Time + M.PowerTrackingSeconds
			end
		end
		Rules.tick(sim.Fight, h)
		if sim.Fight.Over then
			break
		end
		integrate(sim, 1, h)
		integrate(sim, 2, h)
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
				local impulse = normal * ((1 + M.Restitution) * approach / inverseMass)
				local slip = tangent(relative, normal)
				local friction = slip * M.HitFriction / inverseMass
				local deflect = V.new(0, 0, (sim.Rng() * 2 - 1) * approach * M.HitDeflect / inverseMass)
				a.V += (-impulse - friction + deflect) * Rules.knockbackMultiplier(sim.Fight, 1) / fa.Mass
				b.V += (impulse + friction - deflect) * Rules.knockbackMultiplier(sim.Fight, 2) / fb.Mass
				constrain(a)
				constrain(b)
				local glancing = normal.X * relative.Z - normal.Z * relative.X
				a.Spin = math.clamp(a.Spin + glancing * M.SpinFromHit / fa.Mass, -M.MaxSpin, M.MaxSpin)
				b.Spin = math.clamp(b.Spin - glancing * M.SpinFromHit / fb.Mass, -M.MaxSpin, M.MaxSpin)
				a.Tumble += V.new(normal.Z, 0, -normal.X) * approach * M.TumbleFromHit * M.TumbleStiffness
				b.Tumble -= V.new(normal.Z, 0, -normal.X) * approach * M.TumbleFromHit * M.TumbleStiffness
				if approach >= M.MinHitSpeed and sim.Fight.Time - sim.LastHit >= M.HitCooldown then
					-- Use pre-impulse velocities for the approach share.
					local share = if intoA + intoB > 0 then intoA / (intoA + intoB) else 0.5
					sim.LastHit, sim.LastEncounter = sim.Fight.Time, sim.Fight.Time
					table.insert(sim.Metrics.Speeds, approach)
					table.insert(sim.Metrics.Shares, share)
					Rules.hit(sim.Fight, approach, share, (ca.X + cb.X) / 2, (ca.Y + cb.Y) / 2)
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
