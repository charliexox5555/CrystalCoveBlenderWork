-- Pure battle resolution (GAME_DESIGN 3). The server's BattleService calls this to decide each
-- clash, then tells clients what to animate. No Roblox APIs, so tests and the balance
-- simulator can run it outside Roblox.

local Formula = if script then require(script.Parent.Formula) else require("./Formula")

export type Fighter = {
	Id: string,
	Name: string,
	Type: string,
	Rarity: string,
	Level: number,
	Power: number,
	Swing: number,
	MaxHP: number,
	HP: number,
}

-- A side's action for one clash: a meter zone, or "Cork" (try to catch instead of swinging).
export type Action = Formula.Zone | "Cork"

export type ClashResult = {
	ActionA: Action,
	ActionB: Action,
	DamageToA: number,
	DamageToB: number,
	CritA: boolean,
	CritB: boolean,
	HpA: number,
	HpB: number,
	Clutch: boolean,
	Winner: ("A" | "B")?,
}

local BattleLogic = {}

function BattleLogic.newFighter(def: Formula.GlassyDef, options: Formula.StatOptions?, hp: number?): Fighter
	local stats = Formula.stats(def, options)
	return {
		Id = def.Id,
		Name = def.Name,
		Type = def.Type,
		Rarity = def.Rarity,
		Level = (options and options.Level) or 1,
		Power = stats.Power,
		Swing = stats.Swing,
		MaxHP = stats.HP,
		HP = math.clamp(hp or stats.HP, 0, stats.HP),
	}
end

-- Both glassies hit each other at the same time. A side that corks deals no damage.
-- Mutates a.HP and b.HP.
function BattleLogic.resolveClash(a: Fighter, b: Fighter, actionA: Action, actionB: Action, rng: () -> number): ClashResult
	local damageToB, critA = 0, false
	local damageToA, critB = 0, false
	if actionA ~= "Cork" then
		damageToB, critA = Formula.damage(a, b.Type, actionA :: Formula.Zone, rng)
	end
	if actionB ~= "Cork" then
		damageToA, critB = Formula.damage(b, a.Type, actionB :: Formula.Zone, rng)
	end

	local hpA = a.HP - damageToA
	local hpB = b.HP - damageToB
	local clutch = false
	local winner: ("A" | "B")? = nil

	if hpA <= 0 and hpB <= 0 then
		-- Double KO: whoever went less far below zero survives on 1 HP ("CLUTCH!").
		clutch = true
		local aSurvives = if hpA == hpB then rng() < 0.5 else hpA > hpB
		if aSurvives then
			hpA, hpB, winner = 1, 0, "A"
		else
			hpA, hpB, winner = 0, 1, "B"
		end
	elseif hpB <= 0 then
		hpB, winner = 0, "A"
	elseif hpA <= 0 then
		hpA, winner = 0, "B"
	end

	a.HP, b.HP = hpA, hpB
	return {
		ActionA = actionA,
		ActionB = actionB,
		DamageToA = damageToA,
		DamageToB = damageToB,
		CritA = critA,
		CritB = critB,
		HpA = hpA,
		HpB = hpB,
		Clutch = clutch,
		Winner = winner,
	}
end

export type SimResult = { Winner: ("A" | "B")?, Clashes: number, Log: { ClashResult } }

-- Runs a full battle. chooseA/chooseB return each side's action for the next clash.
-- Winner is nil if MaxClashes is reached (a draw).
function BattleLogic.simulate(
	a: Fighter,
	b: Fighter,
	chooseA: (Fighter, Fighter) -> Action,
	chooseB: (Fighter, Fighter) -> Action,
	rng: () -> number,
	keepLog: boolean?
): SimResult
	local log = {}
	local maxClashes = Formula.Balance.Battle.MaxClashes
	for clash = 1, maxClashes do
		local result = BattleLogic.resolveClash(a, b, chooseA(a, b), chooseB(b, a), rng)
		if keepLog then
			table.insert(log, result)
		end
		if result.Winner then
			return { Winner = result.Winner, Clashes = clash, Log = log }
		end
	end
	return { Winner = nil, Clashes = maxClashes, Log = log }
end

-- Helper for NPCs and simulations: swing with a given timing skill (0..1).
function BattleLogic.npcChooser(skill: number, rng: () -> number): (Fighter, Fighter) -> Action
	return function(): Action
		return Formula.npcZone(skill, rng)
	end
end

return BattleLogic
