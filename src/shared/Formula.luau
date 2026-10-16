--!strict
-- Pure game math: stats, types, crits, crate odds and rolls.
-- No Roblox APIs here, so it runs both in Roblox and in Lune (tools/run_tests.luau).
-- Random numbers come in as an `rng` function returning a number in [0, 1).

local Balance = if script then require(script.Parent.Config.Balance) else require("./Config/Balance")
local Glassies = if script then require(script.Parent.Config.Glassies) else require("./Config/Glassies")

export type Stats = { Power: number, HP: number, Swing: number }
export type GlassyDef = {
	Id: string,
	Name: string,
	Type: string,
	Rarity: string,
	Base: Stats,
}
export type StatOptions = { Stars: number?, Rainbow: boolean? }

local Formula = {}
Formula.Balance = Balance

local function round(x: number): number
	return math.floor(x + 0.5)
end

local function clamp(x: number, lo: number, hi: number): number
	return math.max(lo, math.min(hi, x))
end

-- Stats --------------------------------------------------------------------------------------

function Formula.statMultiplier(rarity: string, options: StatOptions?): number
	local opts = options or {}
	local info = Balance.Rarities[rarity]
	assert(info, "Unknown rarity: " .. tostring(rarity))
	local stars = clamp(opts.Stars or 0, 0, Balance.Growth.MaxStars)
	return info.StatMultiplier
		* (1 + Balance.Growth.StatPerStar * stars)
		* (if opts.Rainbow then 1 + Balance.Growth.RainbowBonus else 1)
end

function Formula.stats(def: GlassyDef, options: StatOptions?): Stats
	local mult = Formula.statMultiplier(def.Rarity, options)
	return {
		Power = round(def.Base.Power * mult),
		HP = round(def.Base.HP * mult),
		Swing = round(def.Base.Swing * mult),
	}
end

-- Stars after `duplicates` extra copies, and how many duplicates overflowed past max stars.
function Formula.starsFromDuplicates(duplicates: number): (number, number)
	local g = Balance.Growth
	local stars = math.floor(math.max(duplicates, 0) / g.DuplicatesPerStar)
	if stars > g.MaxStars then
		return g.MaxStars, duplicates - g.MaxStars * g.DuplicatesPerStar
	end
	return stars, 0
end

-- Types --------------------------------------------------------------------------------------

function Formula.typeMultiplier(attackerType: string, defenderType: string): number
	local beats = Balance.Types.Beats
	if beats[attackerType] == defenderType then
		return Balance.Types.Strong
	elseif beats[defenderType] == attackerType then
		return Balance.Types.Weak
	end
	return 1
end

-- Crits --------------------------------------------------------------------------------------

function Formula.critChance(swing: number, bonus: number?): number
	local f = Balance.Fight
	return math.min(f.CritBase + swing * f.CritPerSwing, f.CritMax) + (bonus or 0)
end

-- Rolls --------------------------------------------------------------------------------------

local function sortedCrateRarities(): { string }
	local list = {}
	for name, info in Balance.Rarities do
		if info.CrateWeight > 0 then
			table.insert(list, name)
		end
	end
	table.sort(list, function(a, b)
		return Balance.Rarities[a].Order < Balance.Rarities[b].Order
	end)
	return list
end

-- Odds shown to players before buying a crate (Roblox requires this for paid random items).
function Formula.crateOdds(available: { [string]: boolean }?): { { Rarity: string, Chance: number } }
	local list = sortedCrateRarities()
	local eligible = {}
	local total = 0
	for _, name in list do
		if not available or #Formula.kilnPool(name, available) > 0 then
			table.insert(eligible, name)
			total += Balance.Rarities[name].CrateWeight
		end
	end
	local odds = {}
	for _, name in eligible do
		table.insert(odds, { Rarity = name, Chance = Balance.Rarities[name].CrateWeight / total })
	end
	return odds
end

function Formula.rollRarity(rng: () -> number, available: { [string]: boolean }?): string
	local odds = Formula.crateOdds(available)
	assert(#odds > 0, "No eligible Kiln glassies")
	local roll = rng()
	local acc = 0
	for _, entry in odds do
		acc += entry.Chance
		if roll < acc then
			return entry.Rarity
		end
	end
	return odds[#odds].Rarity
end

-- Glassies of a rarity that can come out of the Kiln, sorted by id.
function Formula.kilnPool(rarity: string, available: { [string]: boolean }?): { string }
	local ids = {}
	for _, def in Glassies.List do
		if Glassies.isRelease(def.Id) and def.Rarity == rarity and (not available or available[def.Id] == true) then
			table.insert(ids, def.Id)
		end
	end
	table.sort(ids)
	return ids
end

-- Per-glassy Kiln odds for the odds screen (rarity chance split evenly within the rarity).
function Formula.kilnOdds(available: { [string]: boolean }?): { { Id: string, Rarity: string, Chance: number } }
	local out = {}
	for _, entry in Formula.crateOdds(available) do
		local pool = Formula.kilnPool(entry.Rarity, available)
		for _, id in pool do
			table.insert(out, { Id = id, Rarity = entry.Rarity, Chance = entry.Chance / #pool })
		end
	end
	return out
end

-- One Kiln pull: a rarity by CrateWeight, then a glassy of that rarity, uniformly.
function Formula.rollKiln(rng: () -> number, available: { [string]: boolean }?): string
	local rarity = Formula.rollRarity(rng, available)
	local pool = Formula.kilnPool(rarity, available)
	assert(#pool > 0, "No glassies of rarity " .. rarity)
	return pool[math.floor(rng() * #pool) + 1]
end

function Formula.rollRainbow(rng: () -> number): boolean
	return rng() < Balance.Growth.RainbowChance
end

return Formula
