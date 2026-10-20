-- Power direction audit (docs/testing/combat_release/POWER_DIRECTION_AUDIT.md): `lune run tools/power_direction_audit`.
-- For every directional kit, real Pendulum rounds; per cast it measures
--   startToRelease: angle between the CastStart (windup) direction and the CastRelease direction
--   releaseToFoe:   angle between the release direction and the line to the foe at release
--   drift:          how far the caster's centre moves during the effect (origin detaching)
--   foeMove:        how far the foe moves during the effect
local G = require("../src/shared/Config/Glassies")
local B = require("../src/shared/Config/Balance")
local Rules = require("../src/shared/FightRules")
local Rng = require("../src/shared/Rng")
local Pendulum = require("../src/server/Simulation/Pendulum")

local V = require("@lune/roblox").Vector3
local function vec(a)
	return V.new(a[1], a[2], a[3])
end
local function angle(a, b)
	local d = math.clamp(a.Unit:Dot(b.Unit), -1, 1)
	return math.deg(math.acos(d))
end

local kits = {}
for _, def in G.ReleaseList do
	local k = B.CombatRelease.Kits[def.Id]
	if
		k
		and (
			k.Shape == "ray"
			or k.Shape == "cone"
			or k.Shape == "breath"
			or k.Shape == "volley"
			or k.Shape == "projectile"
			or k.Shape == "sweep"
			or k.Shape == "boost"
			or k.Shape == "echo_contact"
		)
	then
		table.insert(kits, def.Id)
	end
end

for _, id in kits do
	local rows = { n = 0, s2r = 0, r2f = 0, drift = 0, foe = 0, s2rMax = 0, r2fMax = 0, driftMax = 0, landed = 0 }
	for n = 1, 12 do
		local foe = G.ReleaseList[(n * 5) % #G.ReleaseList + 1].Id
		if foe == id then
			foe = "jam"
		end
		local seed = 4000 + n * 17
		local rng = Rng.new(seed)
		local sweet = Rules.rollSweetSpot(rng)
		local sim = Pendulum.new({
			A = { Id = id, Aim = Rules.botAim(sweet, 0.45, rng), AimYaw = (rng() * 2 - 1) * B.Motion.AimYawMax },
			B = { Id = foe, Aim = Rules.botAim(sweet, 0.45, rng), AimYaw = (rng() * 2 - 1) * B.Motion.AimYawMax },
			SweetSpot = sweet,
			Rng = rng,
		}, seed)
		local starts, open = {}, {}
		local dt = 1 / B.Motion.StepRate
		while not sim.Fight.Over do
			Pendulum.step(sim, dt)
			for _, e in Pendulum.events(sim) do
				if e.Side == 1 and e.Type == "CastStart" and e.Direction then
					starts[e.CastId] = vec(e.Direction)
				elseif e.Side == 1 and e.Type == "CastRelease" then
					local origin = Pendulum.center(sim, 1)
					local foePos = Pendulum.center(sim, 2)
					local dir = if e.Direction then vec(e.Direction) else nil
					local row = {
						Start = starts[e.CastId],
						Dir = dir,
						Origin = origin,
						Foe = foePos,
						Until = sim.Fight.Time + math.max(e.Duration or 0, 0.5),
					}
					table.insert(open, row)
				elseif e.Side == 1 and e.Type == "CastContact" and not e.Missed then
					rows.landed += 1
				end
			end
			local still = {}
			for _, row in open do
				if sim.Fight.Time >= row.Until or sim.Fight.Over then
					rows.n += 1
					local drift = (Pendulum.center(sim, 1) - row.Origin).Magnitude
					local foeMove = (Pendulum.center(sim, 2) - row.Foe).Magnitude
					rows.drift += drift
					rows.foe += foeMove
					rows.driftMax = math.max(rows.driftMax, drift)
					if row.Dir then
						local r2f = angle(row.Dir, row.Foe - row.Origin)
						rows.r2f += r2f
						rows.r2fMax = math.max(rows.r2fMax, r2f)
						if row.Start then
							local s2r = angle(row.Start, row.Dir)
							rows.s2r += s2r
							rows.s2rMax = math.max(rows.s2rMax, s2r)
						end
					end
				else
					table.insert(still, row)
				end
			end
			open = still
		end
	end
	local n = math.max(rows.n, 1)
	print(
		string.format(
			"%-16s %-12s casts %3d landed %3d | windup->release %5.1f° (max %5.1f) | release->foe %5.1f° (max %5.1f) | drift %.2f (max %.2f) studs | foe moves %.2f",
			id,
			B.CombatRelease.Kits[id].Shape,
			rows.n,
			rows.landed,
			rows.s2r / n,
			rows.s2rMax,
			rows.r2f / n,
			rows.r2fMax,
			rows.drift / n,
			rows.driftMax,
			rows.foe / n
		)
	)
end
