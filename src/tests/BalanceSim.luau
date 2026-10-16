-- Balance simulator. Plays many rounds with FightRules + the FightModel stand-in and reports
-- win rates, round lengths and how much aim, specials, types and rarity matter.
--   Outside Studio: lune run tools/balance_sim [roundsPerMatchup]
--   In Studio:      print(require(game.ServerStorage.Tests.BalanceSim)())

local Deps = if script then require(script.Parent.Deps) else require("./Deps")
local FightModel = if script then require(script.Parent.FightModel) else require("./FightModel")
local Balance, Glassies, Rng = Deps.Balance, Deps.Glassies, Deps.Rng

local BalanceSim = {}

export type Result = {
	WinRate: number,
	Seconds: number,
	Hits: number,
	Timeouts: number,
	N: number,
	Comebacks: number, -- share of rounds where the winner was behind on HP after the opening hits
	LeadChanges: number, -- average times the HP lead swapped in a round
	Powers: number, -- average powers fired per glassy per round
	PowerMisses: number, -- share of aimed powers that missed
}

-- Suspense stats from one round's events.
local function suspense(state)
	local maxA, maxB = state.Fighters[1].MaxHp, state.Fighters[2].MaxHp
	local leader, changes, behind, hits = 0, 0, false, 0
	local powers, misses, aimed = 0, 0, 0
	for _, e in state.Events do
		if e.Type == "Hit" then
			hits += 1
			local fa, fb = e.Hp[1] / maxA, e.Hp[2] / maxB
			local now = if fa > fb then 1 elseif fb > fa then 2 else 0
			if now ~= 0 and leader ~= 0 and now ~= leader then
				changes += 1
			end
			if now ~= 0 then
				leader = now
			end
			if hits > 3 and now ~= 0 and now ~= state.Winner then
				behind = true
			end
		elseif e.Type == "Power" then
			powers += 1
			if e.Missed ~= nil or e.Id == "beam" or e.Id == "freeze" then
				aimed += 1
				if e.Missed then
					misses += 1
				end
			end
		end
	end
	return behind, changes, powers / 2, misses, aimed
end

-- opts: StarsA/B, AimA/B ("perfect" | "worst" | number), Seed
function BalanceSim.matchup(idA: string, idB: string, n: number, opts: { [string]: any }?): Result
	local o = opts or {}
	local wins, seconds, hits, timeouts = 0, 0, 0, 0
	local comebacks, leadChanges, powers, misses, aimed = 0, 0, 0, 0, 0
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
		}
		local b = {
			Id = idB,
			Stars = o.StarsB,
			Aim = aimFor(o.AimB, sweet),
		}
		local first, second = if swap then b else a, if swap then a else b
		local setup = {
			A = { Id = first.Id, Stars = first.Stars, Aim = first.Aim },
			B = { Id = second.Id, Stars = second.Stars, Aim = second.Aim },
			Rng = rng,
			SweetSpot = sweet,
		}
		local state = FightModel.round(setup)
		local behind, changes, p, m, a = suspense(state)
		comebacks += if behind then 1 else 0
		leadChanges += changes
		powers += p
		misses += m
		aimed += a
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
	return {
		WinRate = wins / n,
		Seconds = seconds / n,
		Hits = hits / n,
		Timeouts = timeouts / n,
		N = n,
		Comebacks = comebacks / n,
		LeadChanges = leadChanges / n,
		Powers = powers / n,
		PowerMisses = if aimed > 0 then misses / aimed else 0,
		Misses = misses,
		Aimed = aimed,
	}
end

-- Side bias: the same glassy on both sides, no side swapping.
function BalanceSim.sideBias(id: string, n: number): number
	local wins = 0
	for i = 1, n do
		local rng = Rng.new(5000 + i * 104729)
		local state = FightModel.round(FightModel.setup(id, id, rng, { AimA = 0.8, AimB = 0.8 }))
		if state.Winner == 1 then
			wins += 1
		end
	end
	return wins / n
end

function BalanceSim.byRarity(): { [string]: { string } }
	local groups = {}
	for _, def in Glassies.ReleaseList do
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
	for _, def in Glassies.ReleaseList do
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
		table.insert(rows, {
			Id = id,
			Rarity = def.Rarity,
			Type = def.Type,
			Passive = def.Passive,
			Special = def.Special,
			WinRate = rate,
		})
		addTo(byPassive, def.Passive, rate)
		addTo(bySpecial, def.Special, rate)
		addTo(byType, def.Type, rate)
	end
	table.sort(rows, function(x, y)
		return x.WinRate > y.WinRate
	end)
	return rows, byPassive, bySpecial, byType
end

-- Luck and suspense over every glassy as a mirror match.
function BalanceSim.suspense(n: number)
	local totals = { Comebacks = 0, LeadChanges = 0, Powers = 0 }
	local misses, aimed = 0, 0
	for _, def in Glassies.ReleaseList do
		local r = BalanceSim.matchup(def.Id, def.Id, n)
		for k in totals do
			totals[k] += r[k]
		end
		misses += r.Misses
		aimed += r.Aimed
	end
	for k in totals do
		totals[k] /= #Glassies.ReleaseList
	end
	totals.PowerMisses = if aimed > 0 then misses / aimed else 0
	return totals
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
	add("Mirror rounds (avg seconds / hits / timeouts / comebacks / lead changes / powers per glassy):")
	for _, id in { "pop", "jam", "prism", "milk_bottle", "glass_dragon" } do
		local r = BalanceSim.matchup(id, id, n)
		add(
			"  %-14s %5.1f s  %4.1f hits  %s timeouts  %s comebacks  %.1f lead changes  %.1f powers",
			id,
			r.Seconds,
			r.Hits,
			pct(r.Timeouts),
			pct(r.Comebacks),
			r.LeadChanges,
			r.Powers
		)
	end
	add("Side bias (side 1 win rate, pop mirror): %s", pct(BalanceSim.sideBias("pop", n)))

	add("")
	add("Starters (row beats column):")
	for _, a in Glassies.Starters do
		local row = {}
		for _, b in Glassies.Starters do
			table.insert(
				row,
				if a == b then "  -  " else string.format("%5s", pct(BalanceSim.matchup(a, b, n).WinRate))
			)
		end
		add("  %-6s %s", a, table.concat(row, " "))
	end

	add("")
	add(
		"Aim: Perfect vs worst (pop mirror): %s",
		pct(BalanceSim.matchup("pop", "pop", n, { AimA = "perfect", AimB = "worst" }).WinRate)
	)
	add(
		"Aim: Perfect vs average (aim 0.8):  %s",
		pct(BalanceSim.matchup("pop", "pop", n, { AimA = "perfect", AimB = 0.8 }).WinRate)
	)
	local luck = BalanceSim.suspense(math.max(20, n // 4))
	add(
		"Luck (all mirrors): %s comebacks, %.1f lead changes a round, %.1f powers per glassy, %s of aimed powers miss",
		pct(luck.Comebacks),
		luck.LeadChanges,
		luck.Powers,
		pct(luck.PowerMisses)
	)
	add("")
	add("Rarity ladder, all Fizzy, vs Common lemonade_bottle:")
	for _, id in { "milk_bottle", "pop", "hot_sauce", "potion_flask", "rocket_pop", "comet", "galaxy_orb" } do
		local def = Glassies.get(id)
		add("  %-14s %-9s %s", id, def.Rarity, pct(BalanceSim.matchup(id, "lemonade_bottle", n).WinRate))
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
