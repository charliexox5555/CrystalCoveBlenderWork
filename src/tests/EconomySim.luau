-- Economy simulator: how fast players earn coins, pull the Kiln and fill their collection.
--   Outside Studio: lune run tools/economy_sim
--   In Studio:      print(require(game.ServerStorage.Tests.EconomySim)())
-- Inputs: Balance.Match.Rewards, Balance.Economy, Balance.Rarities, Balance.EconomyModel.

local Deps = if script then require(script.Parent.Deps) else require("./Deps")
local Balance, Formula, Glassies, Rng = Deps.Balance, Deps.Formula, Deps.Glassies, Deps.Rng
local MatchLogic = Deps.MatchLogic

local EconomySim = {}

-- Expected rounds in a first-to-lose-3-hearts match between two players with win rate p.
function EconomySim.expectedRounds(p: number): number
	local q = 1 - p
	local hearts = Balance.Match.Hearts
	-- Sum over the round in which someone takes their `hearts`-th round win.
	local total = 0
	for rounds = hearts, 2 * hearts - 1 do
		local ways = 1
		local k = rounds - hearts -- rounds the eventual loser won
		for i = 1, k do
			ways = ways * (hearts - 1 + i) / i
		end
		total += rounds * ways * (p ^ hearts * q ^ k + q ^ hearts * p ^ k)
	end
	return total
end

function EconomySim.matchSeconds(): number
	local m, e = Balance.Match, Balance.EconomyModel
	-- Round 1 picks from a fresh hand; later rounds have the shorter pick (decision 122).
	local perRound = m.RollSecondsLater + m.AimSeconds + m.CountdownSeconds + e.RoundSecondsEstimate + m.RoundEndSeconds
	return EconomySim.expectedRounds(0.5) * perRound + (m.RollSeconds - m.RollSecondsLater) + e.SecondsBetweenMatches
end

-- Coins from one match, drawn at random for a player with the model's win rate.
local function playMatch(rng: () -> number): (number, boolean)
	local e, r = Balance.EconomyModel, Balance.Match.Rewards
	local hearts = Balance.Match.Hearts
	local won, lost = 0, 0
	while won < hearts and lost < hearts do
		if rng() < e.WinRate then
			won += 1
		else
			lost += 1
		end
	end
	local win = won == hearts
	-- Same rule as MatchLogic.rewards: a win pays a flat amount, a loss pays for damage dealt.
	local coins = if win
		then r.MatchWinCoins
		else MatchLogic.lossCoins(won, lost * e.LossChipPerRound * (0.75 + 0.5 * rng()), e.PerfectsPerMatch)
	return coins, win
end

local function median(list: { number }): number
	if #list == 0 then
		return math.huge
	end
	table.sort(list)
	return list[(#list + 1) // 2]
end

function EconomySim.simulate(seed: number?)
	local e, econ = Balance.EconomyModel, Balance.Economy
	local matchSeconds = EconomySim.matchSeconds()
	local kilnTotal = 0
	for _, def in Glassies.ReleaseList do
		if Balance.Rarities[def.Rarity].CrateWeight > 0 then
			kilnTotal += 1
		end
	end
	local firsts = { Rare = {}, Epic = {}, Legendary = {}, Mythic = {} }
	local uniqueDay7, uniqueDay30, pullsDay1, pullsDay30, coinsDay1 = {}, {}, {}, {}, {}
	for player = 1, e.Players do
		local rng = Rng.new((seed or 77) + player * 7919)
		local coins, pulls, owned, seen = econ.WelcomeKilnPulls * econ.KilnCoinCost, 0, {}, {}
		local unique = 0
		for day = 1, e.Days do
			local t, firstWin = 0, false
			local gifts = 1
			coins += econ.DailyQuestCoins * e.QuestsCompletedPerDay
			-- Daily Rewards calendar (decisions 99, 115): claimed every day in the sim; a free Kiln pull counts as one
			-- pull's coins. A Daily glassy (Day 2 Epic, Day 7 Legendary) counts as that rarity's first at the day's start.
			local calendar = econ.DailyRewards[(day - 1) % #econ.DailyRewards + 1]
			coins += (calendar.Coins or 0) + (if calendar.Pull == "Glassies" then econ.KilnCoinCost else 0)
			if calendar.Item and calendar.Item.Category == "Glassies" then
				local rarity = Glassies.get(calendar.Item.Id).Rarity
				if firsts[rarity] and not seen[rarity] then
					seen[rarity] = true
					table.insert(firsts[rarity], (day - 1) * e.SessionMinutes)
				end
			end
			while t + matchSeconds <= e.SessionMinutes * 60 do
				t += matchSeconds
				local got, win = playMatch(rng)
				coins += got
				if win and not firstWin then
					firstWin = true
					coins += econ.FirstWinOfDayCoins
				end
				local gift = econ.PlaytimeGifts[gifts]
				while gift and t >= gift.Minutes * 60 do
					coins += gift.Coins
					if gift.RotatingPull and gift.RotatingPull[day % #gift.RotatingPull + 1] == "Glassies" then
						coins += econ.KilnCoinCost
					end
					gifts += 1
					gift = econ.PlaytimeGifts[gifts]
				end
				while coins >= econ.KilnCoinCost do
					coins -= econ.KilnCoinCost
					pulls += 1
					local id = Formula.rollKiln(rng)
					local rarity = Glassies.get(id).Rarity
					if not owned[id] then
						owned[id] = true
						unique += 1
					end
					if firsts[rarity] and not seen[rarity] then
						seen[rarity] = true
						table.insert(firsts[rarity], (day - 1) * e.SessionMinutes + t / 60)
					end
				end
			end
			if day == 1 then
				table.insert(pullsDay1, pulls)
				table.insert(coinsDay1, coins)
			elseif day == 7 then
				table.insert(uniqueDay7, unique)
			end
		end
		table.insert(uniqueDay30, unique)
		table.insert(pullsDay30, pulls)
	end
	local result = {
		MatchSeconds = matchSeconds,
		KilnGlassies = kilnTotal,
		PullsDay1 = median(pullsDay1),
		PullsDay30 = median(pullsDay30),
		UniqueDay7 = median(uniqueDay7),
		UniqueDay30 = median(uniqueDay30),
		FirstMinutes = {},
		FirstShare = {},
	}
	for rarity, list in firsts do
		result.FirstShare[rarity] = #list / e.Players
		-- Median over everyone: players who never got one count as "never".
		while #list < e.Players do
			table.insert(list, math.huge)
		end
		result.FirstMinutes[rarity] = median(list)
	end
	return result
end

local function minutes(m: number): string
	if m == math.huge then
		return "not within the sim (median player never)"
	elseif m < 90 then
		return string.format("%d min", math.floor(m + 0.5))
	end
	return string.format("%.1f h of play", m / 60)
end

-- Level pacing (LevelRules, decision 104) for the model's player: same win rate and bot share as the coin sim.
function EconomySim.levels(seed: number?): { [string]: number }
	local e = Balance.EconomyModel
	local Levels = if script then require(game.ReplicatedStorage.Shared.LevelRules) else require("../shared/LevelRules")
	local rng = Rng.new(seed or 104)
	local perDay = e.SessionMinutes * 60 / EconomySim.matchSeconds()
	local total, matches, out = 0, 0, { ToLv5 = 0, ToLv10 = 0 }
	for day = 1, e.Days do
		for _ = 1, math.floor(perDay * day) - math.floor(perDay * (day - 1)) do
			local won, lost = 0, 0
			while won < Balance.Match.Hearts and lost < Balance.Match.Hearts do
				if rng() < e.WinRate then
					won += 1
				else
					lost += 1
				end
			end
			total += Levels.matchXp({
				Won = won == Balance.Match.Hearts,
				RoundsWon = won,
				Perfects = e.PerfectsPerMatch,
				VsBot = rng() < e.BotMatchShare,
			})
			matches += 1
			local level = Levels.level(total)
			if level >= 5 and out.ToLv5 == 0 then
				out.ToLv5 = matches
			end
			if level >= 10 and out.ToLv10 == 0 then
				out.ToLv10 = matches
			end
		end
		if day == 1 or day == 7 or day == e.Days then
			out["Day" .. day] = Levels.level(total)
		end
	end
	out.PerDay = perDay
	return out
end

function EconomySim.report(): string
	local e, econ = Balance.EconomyModel, Balance.Economy
	local r = EconomySim.simulate()
	local matchesPerHour = 3600 / r.MatchSeconds
	local lines = {}
	local function add(fmt: string, ...)
		table.insert(lines, string.format(fmt, ...))
	end
	add(
		"Glass Clash economy report (%d players, %d min a day for %d days, %d%% wins, %d%% bot matches)",
		e.Players,
		e.SessionMinutes,
		e.Days,
		e.WinRate * 100,
		e.BotMatchShare * 100
	)
	add("")
	add(
		"Match length ~%.1f min (%.2f rounds), %.1f matches per hour",
		r.MatchSeconds / 60,
		EconomySim.expectedRounds(0.5),
		matchesPerHour
	)
	add("Kiln: %d coins a pull, %d glassies inside", econ.KilnCoinCost, r.KilnGlassies)
	add("Pulls on day 1: %d   by day 30: %d", r.PullsDay1, r.PullsDay30)
	add("Unique glassies (of %d in the Kiln): day 7 %d, day 30 %d", r.KilnGlassies, r.UniqueDay7, r.UniqueDay30)
	local lv = EconomySim.levels()
	add(
		"Levels: Lv %d after day 1, Lv %d by day 7, Lv %d by day %d; Lv 5 after %d matches, Lv 10 after %d",
		lv.Day1,
		lv.Day7,
		lv["Day" .. e.Days],
		e.Days,
		lv.ToLv5,
		lv.ToLv10
	)
	add("")
	add("Median play time to a player's first:")
	for _, rarity in { "Rare", "Epic", "Legendary", "Mythic" } do
		add(
			"  %-9s %s  (%d%% of players get one within %d days)",
			rarity,
			minutes(r.FirstMinutes[rarity]),
			math.floor(r.FirstShare[rarity] * 100 + 0.5),
			e.Days
		)
	end
	add("")
	add("Kiln odds shown to players:")
	for _, entry in Formula.crateOdds() do
		add("  %-9s %.2f%%", entry.Rarity, entry.Chance * 100)
	end
	return table.concat(lines, "\n")
end

return setmetatable(EconomySim, {
	__call = function(): string
		return EconomySim.report()
	end,
})
