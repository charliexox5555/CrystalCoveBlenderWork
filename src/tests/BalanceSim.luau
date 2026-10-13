-- Balance simulator. Plays many rounds with FightRules + the FightModel stand-in and reports
-- win rates, round lengths and how much aim, specials, types and rarity matter.
--   Outside Studio: lune run tools/balance_sim [roundsPerMatchup]
--   In Studio:      print(require(game.ServerStorage.Tests.BalanceSim)())

local Deps = if script then require(script.Parent.Deps) else require("./Deps")
local FightModel = if script then require(script.Parent.FightModel) else require("./FightModel")
local Balance, Glassies, Rng = Deps.Balance, Deps.Glassies, Deps.Rng

local BalanceSim = {}

export type Result = { WinRate: number, Seconds: number, Hits: number, Timeouts: number, N: number }

-- opts: StarsA/B, AimA/B ("perfect" | "worst" | number), PolicyA/B ("ready" | "never"), Seed
function BalanceSim.matchup(idA: string, idB: string, n: number, opts: { [string]: any }?): Result
	local o = opts or {}
	local wins, seconds, hits, timeouts = 0, 0, 0, 0
	local M = Balance.Motion
	local function aimFor(spec, sweet: number): number
		if spec == "perfect" then
			return sweet
		elseif spec == "worst" then
			return if sweet - M.AimMin > M.AimMax - sweet then M.AimMin else M.AimMax
		elseif type(spec) == "number" then
			return spec
		end
		return sweet -- both aim equally well by default
	end
	for i = 1, n do
		local rng = Rng.new((o.Seed or 1000) + i * 7919)
		local sweet = M.AimMin + M.SweetSpotWidth + (M.AimMax - M.AimMin - 2 * M.SweetSpotWidth) * rng()
		-- Swap sides every other round so side bias cancels out.
		local swap = i % 2 == 0
		local a = {
			Id = idA,
			Stars = o.StarsA,
			Aim = aimFor(o.AimA, sweet),
			Policy = o.PolicyA or "ready",
		}
		local b = {
			Id = idB,
			Stars = o.StarsB,
			Aim = aimFor(o.AimB, sweet),
			Policy = o.PolicyB or "ready",
		}
		local first, second = if swap then b else a, if swap then a else b
		local setup = {
			A = { Id = first.Id, Stars = first.Stars, Aim = first.Aim },
			B = { Id = second.Id, Stars = second.Stars, Aim = second.Aim },
			Rng = rng,
			SweetSpot = sweet,
		}
		local state = FightModel.round(setup, { first.Policy, second.Policy })
		local aSide = if swap then 2 else 1
		if state.Winner == aSide then
			wins += 1
		end
		seconds += state.Time
		hits += state.Hits
		if state.Reason == "Timeout" then
			timeouts += 1
		end
	end
	return { WinRate = wins / n, Seconds = seconds / n, Hits = hits / n, Timeouts = timeouts / n, N = n }
end

-- Side bias: the same glassy on both sides, no side swapping.
function BalanceSim.sideBias(id: string, n: number): number
	local wins = 0
	for i = 1, n do
		local rng = Rng.new(5000 + i * 104729)
		local state = FightModel.round(FightModel.setup(id, id, rng, { AimA = 0.8, AimB = 0.8 }), { "ready", "ready" })
		if state.Winner == 1 then
			wins += 1
		end
	end
	return wins / n
end

function BalanceSim.byRarity(): { [string]: { string } }
	local groups = {}
	for _, def in Glassies.List do
		groups[def.Rarity] = groups[def.Rarity] or {}
		table.insert(groups[def.Rarity], def.Id)
	end
	for _, ids in groups do
		table.sort(ids)
	end
	return groups
end

-- Power balance: every glassy at the same stat multiplier (rarity ignored) against every other
-- glassy. Shows whether passives, specials and types are fair. Returns rows sorted by win rate,
-- plus averages by passive and by special.
function BalanceSim.powerTable(n: number)
	local saved = {}
	for name, info in Balance.Rarities do
		saved[name] = info.StatMultiplier
		info.StatMultiplier = 1
	end
	local ids = {}
	for _, def in Glassies.List do
		table.insert(ids, def.Id)
	end
	table.sort(ids)
	local totals = {}
	for i, a in ids do
		for j = i + 1, #ids do
			local b = ids[j]
			local r = BalanceSim.matchup(a, b, n, { Seed = i * 131 + j }).WinRate
			totals[a] = (totals[a] or 0) + r
			totals[b] = (totals[b] or 0) + (1 - r)
		end
	end
	for name, mult in saved do
		Balance.Rarities[name].StatMultiplier = mult
	end
	local rows = {}
	local byPassive, bySpecial, byType = {}, {}, {}
	local function addTo(map, key, value)
		map[key] = map[key] or { Sum = 0, N = 0 }
		map[key].Sum += value
		map[key].N += 1
	end
	for _, id in ids do
		local def = Glassies.get(id)
		local rate = totals[id] / (#ids - 1)
		table.insert(rows, { Id = id, Rarity = def.Rarity, Type = def.Type, Passive = def.Passive, Special = def.Special, WinRate = rate })
		addTo(byPassive, def.Passive, rate)
		addTo(bySpecial, def.Special, rate)
		addTo(byType, def.Type, rate)
	end
	table.sort(rows, function(x, y)
		return x.WinRate > y.WinRate
	end)
	return rows, byPassive, bySpecial, byType
end

-- Special used whenever ready vs never used, averaged over every glassy as a mirror match.
function BalanceSim.specialValue(n: number): (number, { [string]: number })
	local total, per = 0, {}
	for _, def in Glassies.List do
		local r = BalanceSim.matchup(def.Id, def.Id, n, { PolicyA = "ready", PolicyB = "never" }).WinRate
		per[def.Special] = per[def.Special] or {}
		table.insert(per[def.Special], r)
		total += r
	end
	local avg = {}
	for special, list in per do
		local s = 0
		for _, r in list do
			s += r
		end
		avg[special] = s / #list
	end
	return total / #Glassies.List, avg
end

local function pct(x: number): string
	return string.format("%d%%", math.floor(x * 100 + 0.5))
end

function BalanceSim.report(roundsPerMatchup: number?): string
	local n = roundsPerMatchup or 200
	local lines = { string.format("Glass Clash balance report (%d rounds per matchup, FightModel stand-in)", n) }
	local function add(fmt: string, ...)
		table.insert(lines, string.format(fmt, ...))
	end

	add("")
	add("Mirror rounds (avg seconds / hits / timeouts):")
	for _, id in { "pop", "jam", "prism", "milk_bottle", "glass_dragon" } do
		local r = BalanceSim.matchup(id, id, n)
		add("  %-14s %5.1f s  %4.1f hits  %s timeouts", id, r.Seconds, r.Hits, pct(r.Timeouts))
	end
	add("Side bias (side 1 win rate, pop mirror): %s", pct(BalanceSim.sideBias("pop", n)))

	add("")
	add("Starters (row beats column):")
	for _, a in Glassies.Starters do
		local row = {}
		for _, b in Glassies.Starters do
			table.insert(row, if a == b then "  -  " else string.format("%5s", pct(BalanceSim.matchup(a, b, n).WinRate)))
		end
		add("  %-6s %s", a, table.concat(row, " "))
	end

	add("")
	add("Aim: Perfect vs worst (pop mirror): %s", pct(BalanceSim.matchup("pop", "pop", n, { AimA = "perfect", AimB = "worst" }).WinRate))
	add("Aim: Perfect vs average (aim 0.8):  %s", pct(BalanceSim.matchup("pop", "pop", n, { AimA = "perfect", AimB = 0.8 }).WinRate))
	local special, perSpecial = BalanceSim.specialValue(math.max(20, n // 4))
	add("Special used vs never (all mirrors): %s", pct(special))
	local names = {}
	for id in perSpecial do
		table.insert(names, id)
	end
	table.sort(names)
	for _, id in names do
		add("  %-8s %s", id, pct(perSpecial[id]))
	end

	add("")
	add("Rarity ladder vs Common milk_bottle:")
	for _, id in { "pop", "pickle_jar", "mason_jar", "perfume", "rocket_pop", "glass_unicorn", "glass_dragon" } do
		local def = Glassies.get(id)
		add("  %-14s %-9s %s", id, def.Rarity, pct(BalanceSim.matchup(id, "milk_bottle", n).WinRate))
	end
	add("Stars: pop 5 stars vs pop 0 stars: %s", pct(BalanceSim.matchup("pop", "pop", n, { StarsA = 5 }).WinRate))

	add("")
	add("Power balance (equal stats, each glassy vs all others):")
	local rows, byPassive, bySpecial, byType = BalanceSim.powerTable(math.max(10, n // 8))
	for _, row in rows do
		add("  %-16s %-6s %-11s %-7s %s", row.Id, row.Type, row.Passive, row.Special, pct(row.WinRate))
	end
	for _, pair in { { "Types", byType }, { "Passives", byPassive }, { "Specials", bySpecial } } do
		local keys = {}
		for k in pair[2] do
			table.insert(keys, k)
		end
		table.sort(keys)
		local parts = {}
		for _, k in keys do
			table.insert(parts, string.format("%s %s", k, pct(pair[2][k].Sum / pair[2][k].N)))
		end
		add("  %s: %s", pair[1], table.concat(parts, ", "))
	end
	return table.concat(lines, "\n")
end

return setmetatable(BalanceSim, {
	__call = function(_, roundsPerMatchup: number?): string
		return BalanceSim.report(roundsPerMatchup)
	end,
})
