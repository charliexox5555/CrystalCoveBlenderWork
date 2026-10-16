-- A stand-in for the real swing, used only by tests and the balance simulator. It produces one
-- hit every ~Balance.SimModel.HitInterval seconds with an approach speed from both glassies'
-- swing heights, and lets FightRules do everything else. Once FightService runs in Studio,
-- measure the real hit rate and speeds and update Balance.SimModel to match.

local Deps = if script then require(script.Parent.Deps) else require("./Deps")
local Balance, FightRules = Deps.Balance, Deps.FightRules

local FightModel = {}

local function swingOf(state, side: number): number
	local f = state.Fighters[side]
	local amp = FightRules.targetAmplitude(f.Swing) * FightRules.swingMultiplier(state, side)
	if FightRules.isFrozen(state, side) then
		amp *= Balance.SimModel.FrozenSwing
	end
	return amp
end

-- Chance that an encounter is a pass-by. With MissAtRadius set (measured on the real swing, see
-- docs/testing/CALIBRATION_REVIEW.md) bigger glassies collide more often and slowed swings (Sticky,
-- Freeze) hang close together and rarely pass; otherwise the flat MissChance is used.
local function missChance(state): number
	local m = Balance.SimModel
	if not m.MissAtRadius then
		return m.MissChance
	end
	local a, b = state.Fighters[1], state.Fighters[2]
	local base = m.MissAtRadius - m.MissPerRadius * (a.Radius + b.Radius - 1)
	local full = FightRules.targetAmplitude(a.Swing) + FightRules.targetAmplitude(b.Swing)
	local slowed = math.clamp((swingOf(state, 1) + swingOf(state, 2)) / full, 0, 1)
	return math.clamp(base * slowed ^ m.MissSlowExponent, 0.02, 0.8)
end

-- Runs one round to the end. Powers fire by themselves (FightRules.tick); aimed powers roll
-- their LandChance. Every ~HitInterval the glassies meet; missChance() of those swings pass by.
function FightModel.round(setup)
	local m = Balance.SimModel
	local rng = setup.Rng
	local state = FightRules.new(setup)
	local dt = 0.05
	local nextHit = m.HitInterval * (0.5 + 0.5 * rng())
	-- Stand-in apex cadence; actual 3D turnarounds are measured by Pendulum, never this timer.
	local halfPeriod = math.pi * math.sqrt(Balance.Motion.StringLength / Balance.Motion.Gravity)
	local nextTurns = { halfPeriod * 0.5, halfPeriod }
	local events = {}
	while not state.Over do
		FightRules.tick(state, dt)
		if state.ReleaseKits then
			for side = 1, 2 do
				if state.Time >= nextTurns[side] then
					FightRules.turnaround(state, side)
					nextTurns[side] += halfPeriod
				end
			end
		end
		if not state.Over and state.Time >= nextHit then
			if rng() >= missChance(state) then
				local a, b = swingOf(state, 1), swingOf(state, 2)
				local speed = m.SpeedAtAmplitude * (a + b) / 2 * (1 + m.SpeedSpread * (rng() * 2 - 1))
				local share = math.clamp(a / (a + b) + m.ShareSpread * (rng() * 2 - 1), 0.05, 0.95)
				FightRules.hit(state, speed, share)
			end
			nextHit += m.HitInterval * (1 + m.HitIntervalJitter * (rng() * 2 - 1))
		end
		for _, e in FightRules.drainEvents(state) do
			table.insert(events, e)
		end
	end
	state.Events = events
	return state
end

-- Quick setup helper: FightModel.setup("pop", "jam", rng, { AimA = 0.8, SweetSpot = 0.8, ... })
function FightModel.setup(idA: string, idB: string, rng, opts: { [string]: any }?)
	local o = opts or {}
	return {
		A = { Id = idA, Stars = o.StarsA, Aim = o.AimA },
		B = { Id = idB, Stars = o.StarsB, Aim = o.AimB },
		Rng = rng,
		SweetSpot = o.SweetSpot,
	}
end

return FightModel
