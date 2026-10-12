-- Shared simulation helpers for balance tests and the balance simulator.

local Deps = if script then require(script.Parent.Deps) else require("./Deps")
local BattleLogic = Deps.BattleLogic
local Formula = Deps.Formula
local Glassies = Deps.Glassies
local Rng = Deps.Rng

local Sim = {}

export type Side = { Id: string, Level: number, Skill: number, Stars: number? }
export type MatchResult = { WinRateA: number, AvgClashes: number, Draws: number }

-- Runs `runs` battles between side A and side B and returns A's win rate and average length.
function Sim.match(a: Side, b: Side, runs: number, seed: number): MatchResult
	local rng = Rng.new(seed)
	local winsA, draws, totalClashes = 0, 0, 0
	local defA, defB = Glassies.get(a.Id), Glassies.get(b.Id)
	for _ = 1, runs do
		local fa = BattleLogic.newFighter(defA, { Level = a.Level, Stars = a.Stars })
		local fb = BattleLogic.newFighter(defB, { Level = b.Level, Stars = b.Stars })
		local result = BattleLogic.simulate(
			fa,
			fb,
			BattleLogic.npcChooser(a.Skill, rng),
			BattleLogic.npcChooser(b.Skill, rng),
			rng
		)
		totalClashes += result.Clashes
		if result.Winner == "A" then
			winsA += 1
		elseif result.Winner == nil then
			draws += 1
		end
	end
	return { WinRateA = winsA / runs, AvgClashes = totalClashes / runs, Draws = draws }
end

-- Wins needed to go from level 1 to `targetLevel` when always fighting same-level opponents.
function Sim.winsToLevel(targetLevel: number): number
	local level, xp, wins = 1, 0, 0
	while level < targetLevel do
		local gained = Formula.xpForBattle(level, true)
		level, xp = Formula.applyXp(level, xp, gained)
		wins += 1
	end
	return wins
end

return Sim
