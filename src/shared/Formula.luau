-- Pure game math: stats, meter zones, damage, XP, catching and rolls.
-- No Roblox APIs here, so it runs both in Roblox and in Lune (tools/run_tests.luau).
-- Random numbers come in as an `rng` function returning a number in [0, 1).

local Balance = if script then require(script.Parent.Config.Balance) else require("./Config/Balance")

export type Stats = { Power: number, HP: number, Swing: number }
export type GlassyDef = {
	Id: string,
	Name: string,
	Type: string,
	Rarity: string,
	Base: Stats,
}
export type StatOptions = { Level: number?, Stars: number?, Rainbow: boolean? }
export type Zone = "Weak" | "Good" | "Great" | "Perfect"

local Formula = {}
Formula.Balance = Balance

local function round(x: number): number
	return math.floor(x + 0.5)
end

local function clamp(x: number, lo: number, hi: number): number
	return math.max(lo, math.min(hi, x))
end

-- Stats --------------------------------------------------------------------------------------

function Formula.levelMultiplier(level: number): number
	local growth = Balance.Growth
	level = clamp(level, 1, growth.MaxLevel)
	return 1 + growth.StatPerLevel * (level - 1)
end

function Formula.stats(def: GlassyDef, options: StatOptions?): Stats
	local opts = options or {}
	local level = opts.Level or 1
	local stars = clamp(opts.Stars or 0, 0, Balance.Growth.MaxStars)
	local rarity = Balance.Rarities[def.Rarity]
	assert(rarity, "Unknown rarity: " .. tostring(def.Rarity))

	local mult = rarity.StatMultiplier
		* Formula.levelMultiplier(level)
		* (1 + Balance.Growth.StatPerStar * stars)
		* (if opts.Rainbow then 1 + Balance.Growth.RainbowBonus else 1)

	return {
		Power = round(def.Base.Power * mult),
		HP = round(def.Base.HP * mult),
		Swing = round(def.Base.Swing * mult),
	}
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

-- Power meter --------------------------------------------------------------------------------

-- Half-widths of each zone, measured outward from the centre of the bar.
function Formula.meterBounds(swing: number): { Perfect: number, Great: number, Good: number }
	local m = Balance.Meter
	local perfect = m.PerfectWidth + m.PerfectWidthFromSwing * clamp(swing / m.SwingForMaxPerfect, 0, 1)
	local perfectHalf = perfect / 2
	local greatHalf = perfectHalf + m.GreatWidth / 2
	local goodHalf = greatHalf + m.GoodWidth / 2
	return { Perfect = perfectHalf, Great = greatHalf, Good = goodHalf }
end

-- position: 0..1 along the bar
function Formula.zoneAt(position: number, swing: number): Zone
	local bounds = Formula.meterBounds(swing)
	local d = math.abs(position - 0.5)
	if d <= bounds.Perfect then
		return "Perfect"
	elseif d <= bounds.Great then
		return "Great"
	elseif d <= bounds.Good then
		return "Good"
	end
	return "Weak"
end

-- Needle ping-pongs 0 -> 1 -> 0 ...
function Formula.needlePosition(elapsed: number, sweepTime: number?): number
	local sweep = sweepTime or Balance.Meter.SweepTime
	local k = (math.max(elapsed, 0) / sweep) % 2
	return if k <= 1 then k else 2 - k
end

-- Server-side check of a client's release time. Returns the elapsed time to judge, or nil if
-- the hold ran out (auto-release as Weak).
function Formula.validateRelease(claimedElapsed: number, serverElapsed: number): number?
	local m = Balance.Meter
	if serverElapsed > m.MaxHoldTime + m.LatencyAllowance then
		return nil
	end
	local judged = clamp(claimedElapsed, serverElapsed - m.LatencyAllowance, serverElapsed)
	if judged > m.MaxHoldTime then
		return nil
	end
	return math.max(judged, 0)
end

function Formula.zoneFromRelease(elapsed: number?, swing: number): Zone
	if elapsed == nil then
		return "Weak"
	end
	return Formula.zoneAt(Formula.needlePosition(elapsed), swing)
end

function Formula.swingMultiplier(zone: Zone): number
	return Balance.Meter.Multipliers[zone]
end

-- Damage -------------------------------------------------------------------------------------

function Formula.critChance(swing: number): number
	local d = Balance.Damage
	return math.min(d.CritBase + swing * d.CritPerSwing, d.CritMax)
end

-- Returns damage dealt and whether it was a crit.
function Formula.damage(
	attacker: { Power: number, Swing: number, Type: string },
	defenderType: string,
	zone: Zone,
	rng: () -> number
): (number, boolean)
	local d = Balance.Damage
	local crit = rng() < Formula.critChance(attacker.Swing)
	local variance = d.VarianceMin + (d.VarianceMax - d.VarianceMin) * rng()
	local amount = attacker.Power
		* Formula.swingMultiplier(zone)
		* Formula.typeMultiplier(attacker.Type, defenderType)
		* (if crit then d.CritMultiplier else 1)
		* variance
	return math.max(1, round(amount)), crit
end

-- NPC timing: skill 0..1 -> zone
function Formula.npcZone(skill: number, rng: () -> number): Zone
	local n = Balance.Npc
	skill = clamp(skill, 0, 1)
	local perfect = n.PerfectBase + n.PerfectPerSkill * skill
	local great = n.GreatBase + n.GreatPerSkill * skill
	local good = n.GoodBase + n.GoodPerSkill * skill
	local roll = rng()
	if roll < perfect then
		return "Perfect"
	elseif roll < perfect + great then
		return "Great"
	elseif roll < perfect + great + good then
		return "Good"
	end
	return "Weak"
end

-- XP -----------------------------------------------------------------------------------------

function Formula.xpToNext(level: number): number
	return Balance.Xp.ToNextBase + Balance.Xp.ToNextPerLevel * level
end

function Formula.xpForBattle(opponentLevel: number, won: boolean): number
	local x = Balance.Xp
	local xp = x.WinBase + x.WinPerOpponentLevel * opponentLevel
	return round(if won then xp else xp * x.LossFraction)
end

-- Adds XP and returns the new level, the XP left over and how many levels were gained.
function Formula.applyXp(level: number, xp: number, gained: number): (number, number, number)
	local maxLevel = Balance.Growth.MaxLevel
	local startLevel = level
	xp += gained
	while level < maxLevel and xp >= Formula.xpToNext(level) do
		xp -= Formula.xpToNext(level)
		level += 1
	end
	if level >= maxLevel then
		xp = 0
	end
	return level, xp, level - startLevel
end

-- Catching -----------------------------------------------------------------------------------

function Formula.catchChance(rarity: string, hp: number, maxHp: number, cork: string?): number
	local c = Balance.Catch
	local rarityInfo = Balance.Rarities[rarity]
	assert(rarityInfo, "Unknown rarity: " .. tostring(rarity))
	local missing = 1 - clamp(hp / maxHp, 0, 1)
	local corkBonus = c.Corks[cork or "Basic"] or 1
	local chance = rarityInfo.CatchRate * (c.HpFloor + (1 - c.HpFloor) * missing) * corkBonus
	return clamp(chance, 0, c.MaxChance)
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
function Formula.crateOdds(): { { Rarity: string, Chance: number } }
	local list = sortedCrateRarities()
	local total = 0
	for _, name in list do
		total += Balance.Rarities[name].CrateWeight
	end
	local odds = {}
	for _, name in list do
		table.insert(odds, { Rarity = name, Chance = Balance.Rarities[name].CrateWeight / total })
	end
	return odds
end

function Formula.rollRarity(rng: () -> number): string
	local odds = Formula.crateOdds()
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

function Formula.rollRainbow(rng: () -> number): boolean
	return rng() < Balance.Growth.RainbowChance
end

-- Coins --------------------------------------------------------------------------------------

function Formula.trainerCoins(level: number, isRematch: boolean): number
	local r = Balance.Rewards
	local coins = r.TrainerCoinsBase + r.TrainerCoinsPerLevel * level
	return round(if isRematch then coins * r.RematchFraction else coins)
end

return Formula
