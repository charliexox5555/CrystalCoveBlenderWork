--!strict
-- Player levels (decision 104): XP per finished match and the level curve. Pure: no Roblox APIs.
-- Profiles store only the total XP (`data.Xp`); the level and progress are derived from it, so a curve change
-- never needs a migration. Numbers live in Balance.Levels.
--
--   LevelRules.matchXp({ Won = true, RoundsWon = 3, Perfects = 1, VsBot = false })  --> 130
--   LevelRules.view(total)  --> { Level = 4, Xp = 120, XpNext = 220, Total = total }
local Balance = if script then require(script.Parent.Config.Balance) else require("./Config/Balance")
local L = Balance.Levels
local Rules = {}

export type Result = { Won: boolean, RoundsWon: number?, Perfects: number?, VsBot: boolean?, Forfeited: boolean? }
export type View = { Level: number, Xp: number, XpNext: number, Total: number }

local function natural(value: any): number
	return if type(value) == "number"
			and value == value
			and math.abs(value) < math.huge
		then math.max(0, math.floor(value))
		else 0
end
Rules.natural = natural

-- XP earned by one side of a finished match. A forfeit earns nothing.
function Rules.matchXp(result: Result): number
	if result.Forfeited then
		return 0
	end
	local xp = if result.Won then L.WinXp else L.LossXp
	xp += natural(result.RoundsWon) * L.RoundWonXp + natural(result.Perfects) * L.PerfectXp
	if result.VsBot then
		xp *= L.BotScale
	end
	return math.floor(xp + 0.5)
end

-- XP needed to go from `level` to the next one.
function Rules.need(level: number): number
	return L.BaseXp + L.StepXp * (math.max(1, math.floor(level)) - 1)
end

-- Total XP at which `level` starts (level 1 starts at 0).
function Rules.totalFor(level: number): number
	local n = math.max(1, math.floor(level)) - 1
	return L.BaseXp * n + L.StepXp * n * (n - 1) / 2
end

function Rules.view(total: any): View
	local xp = natural(total)
	-- Closed form for a first guess (the curve is quadratic), then settle exactly.
	local level = 1
	if L.StepXp > 0 then
		local a, b = L.StepXp / 2, L.BaseXp - L.StepXp / 2
		level = math.max(1, math.floor((-b + math.sqrt(b * b + 4 * a * xp)) / (2 * a)) + 1)
	else
		level = math.floor(xp / L.BaseXp) + 1
	end
	while level > 1 and Rules.totalFor(level) > xp do
		level -= 1
	end
	while Rules.totalFor(level + 1) <= xp do
		level += 1
	end
	return { Level = level, Xp = xp - Rules.totalFor(level), XpNext = Rules.need(level), Total = xp }
end

function Rules.level(total: any): number
	return Rules.view(total).Level
end

-- Adds XP to a total; returns the new total and how many levels were gained.
function Rules.add(total: any, amount: any): (number, number)
	local before = natural(total)
	local after = before + natural(amount)
	return after, Rules.level(after) - Rules.level(before)
end

return Rules
