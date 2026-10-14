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

-- Runs one round to the end. Powers fire by themselves (FightRules.tick); aimed powers roll
-- their LandChance. Every ~HitInterval the glassies meet; MissChance of those swings pass by.
function FightModel.round(setup)
	local m = Balance.SimModel
	local rng = setup.Rng
	local state = FightRules.new(setup)
	local dt = 0.05
	local nextHit = m.HitInterval * (0.5 + 0.5 * rng())
	local events = {}
	while not state.Over do
		FightRules.tick(state, dt)
		if not state.Over and state.Time >= nextHit then
			if rng() >= m.MissChance then
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
