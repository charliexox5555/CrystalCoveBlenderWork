-- Payer economy simulator (decision 116): what Robux offers do to collection pace and power, next to a free player.
--   Outside Studio: lune run tools/economy_sim   (printed after the free-player report)
--   In Studio:      print(require(game.ServerStorage.Tests.PayerSim).report())
-- Everyone plays the EconomyModel's 40 min a day and spends coins in the Kiln as the free sim does. Payers also buy:
--   Starter     the Starter Pack on day 1 (49 R$)
--   Occasional  the Starter Pack + a Marble Handful (99 R$) on days 7 and 21
--   Daily       the Starter Pack + the Daily Glassy (9 R$) and Daily Marbles (49 R$) every day
--   Whale       Daily + a Marble Vault on days 1 and 15 + the daily store's Robux glassy every day
-- Marbles all go into Marble Kiln pulls (the most collection a Marble can buy). "Edge" = how much more HP the
-- player's best three glassies have than a free player's (rarity HP multiplier x stars), which is all rarity buys
-- in a fight (decision 86: ~55% Mythic vs Common at equal skill at most).

local Deps = if script then require(script.Parent.Deps) else require("./Deps")
local Balance, Formula, Glassies, Rng, MatchLogic = Deps.Balance, Deps.Formula, Deps.Glassies, Deps.Rng, Deps.MatchLogic
local function shared(path, file)
	if script then
		local node = game.ReplicatedStorage.Shared
		for _, name in path do
			node = node[name]
		end
		return require(node)
	end
	return require(file)
end
local Offers = shared({ "OfferRules" }, "../shared/OfferRules")
local OfferConfig = shared({ "Config", "Offers" }, "../shared/Config/Offers")
local MarbleShop = shared({ "Config", "MarbleShop" }, "../shared/Config/MarbleShop")
local DailyStore = shared({ "Config", "DailyStore" }, "../shared/Config/DailyStore")
local EconomySim = if script then require(script.Parent.EconomySim) else require("./EconomySim")

local PayerSim = {}
PayerSim.Personas = { "Free", "Starter", "Occasional", "Daily", "Whale" }

local function pack(id)
	for _, p in MarbleShop.Packs do
		if p.Id == id then
			return p
		end
	end
	error("no pack " .. id)
end

-- Marble Kiln pull: rarity by Balance.Crates.MarbleWeights over rarities with Kiln glassies, then uniform.
local marbleOdds = {}
do
	local total = 0
	for rarity, weight in Balance.Crates.MarbleWeights do
		if #Formula.kilnPool(rarity) > 0 then
			total += weight
		end
	end
	for rarity, weight in Balance.Crates.MarbleWeights do
		local pool = Formula.kilnPool(rarity)
		for _, id in pool do
			table.insert(marbleOdds, { Id = id, Chance = weight / total / #pool })
		end
	end
	table.sort(marbleOdds, function(a, b)
		return a.Id < b.Id
	end)
end
local dailyOdds = Offers.dailyGlassyOdds()
-- Daily store Robux glassy slot (whale): rarity by DailyStore.Weights.Robux, an unowned one preferred.
local storeOdds = {}
do
	local total = 0
	for rarity, weight in DailyStore.Weights.Robux do
		if weight > 0 and #Formula.kilnPool(rarity) > 0 then
			total += weight
		end
	end
	for rarity, weight in DailyStore.Weights.Robux do
		if weight > 0 and #Formula.kilnPool(rarity) > 0 then
			table.insert(storeOdds, { Rarity = rarity, Chance = weight / total })
		end
	end
	table.sort(storeOdds, function(a, b)
		return a.Rarity < b.Rarity
	end)
end
local function storePrice(rarity)
	local entry = DailyStore.RobuxProducts.Glassies[rarity]
	return (entry.Standard or entry.Featured).Price
end

local function median(list)
	table.sort(list)
	return list[(#list + 1) // 2] or 0
end

local function hp(id, owned)
	local stars = math.min(owned[id] - 1, Balance.Growth.MaxStars)
	return Balance.Rarities[Glassies.get(id).Rarity].StatMultiplier * (1 + Balance.Growth.StatPerStar * stars)
end
local function bestThree(owned)
	local values = {}
	for id in owned do
		table.insert(values, hp(id, owned))
	end
	table.sort(values, function(a, b)
		return a > b
	end)
	local sum, n = 0, math.min(3, #values)
	for i = 1, n do
		sum += values[i]
	end
	return if n > 0 then sum / n else 1
end

-- One player's 30 days. Returns { Robux, UniqueDay7, UniqueDay30, Legendary7, Mythic30, Edge30, Pulls30 }.
local function play(persona, seed)
	local e, econ = Balance.EconomyModel, Balance.Economy
	local rng = Rng.new(seed)
	local owned, unique = {}, 0
	local coins, marbles, robux, pulls = econ.KilnCoinCost * econ.WelcomeKilnPulls, 0, 0, 0
	local out = { Legendary7 = false, Mythic30 = false }
	local function gain(id)
		if owned[id] then
			owned[id] += 1
		else
			owned[id] = 1
			unique += 1
		end
		local rarity = Glassies.get(id).Rarity
		if rarity == "Mythic" then
			out.Mythic30 = true
		end
		return rarity
	end
	local matchSeconds = EconomySim.matchSeconds()
	local buys = persona ~= "Free"
	for day = 1, e.Days do
		-- Robux first thing in the day.
		if buys and day == 1 then
			robux += OfferConfig.StarterPack.Price
			marbles += OfferConfig.StarterPack.Marbles
			gain(OfferConfig.StarterPack.Items[1].Id)
		end
		if persona == "Occasional" and (day == 7 or day == 21) then
			local p = pack("handful")
			robux += p.Price
			marbles += p.Marbles
		end
		if persona == "Daily" or persona == "Whale" then
			robux += OfferConfig.DailyGlassy.Price + OfferConfig.DailyMarbles.Price
			gain(Offers.roll(dailyOdds, rng))
			local step = math.min(day, #OfferConfig.DailyMarbles.Amounts)
			marbles += OfferConfig.DailyMarbles.Amounts[step]
		end
		if persona == "Whale" then
			if day == 1 or day == 15 then
				local p = pack("vault")
				robux += p.Price
				marbles += p.Marbles
			end
			local rarity = storeOdds[#storeOdds].Rarity
			local draw, acc = rng(), 0
			for _, row in storeOdds do
				acc += row.Chance
				if draw < acc then
					rarity = row.Rarity
					break
				end
			end
			local pool, pick = Formula.kilnPool(rarity), nil
			for _, id in pool do
				if not owned[id] then
					pick = id
					break
				end
			end
			gain(pick or pool[math.floor(rng() * #pool) + 1])
			robux += storePrice(rarity)
		end
		while marbles >= Balance.Crates.Prices.Glassies.Marbles do
			marbles -= Balance.Crates.Prices.Glassies.Marbles
			pulls += 1
			gain(Offers.roll(marbleOdds, rng))
		end
		-- Free income, as in EconomySim: calendar, matches, first win, playtime gifts, all into Coin Kiln pulls.
		local calendar = econ.DailyRewards[(day - 1) % #econ.DailyRewards + 1]
		coins += (calendar.Coins or 0) + (if calendar.Pull == "Glassies" then econ.KilnCoinCost else 0)
		if calendar.Item and calendar.Item.Category == "Glassies" and (owned[calendar.Item.Id] or 0) < 6 then
			gain(calendar.Item.Id)
		end
		local t, gifts, firstWin = 0, 1, false
		while t + matchSeconds <= e.SessionMinutes * 60 do
			t += matchSeconds
			local won, lost = 0, 0
			while won < Balance.Match.Hearts and lost < Balance.Match.Hearts do
				if rng() < e.WinRate then
					won += 1
				else
					lost += 1
				end
			end
			if won == Balance.Match.Hearts then
				coins += Balance.Match.Rewards.MatchWinCoins + (if firstWin then 0 else econ.FirstWinOfDayCoins)
				firstWin = true
			else
				coins += MatchLogic.lossCoins(won, lost * e.LossChipPerRound, e.PerfectsPerMatch)
			end
			local gift = econ.PlaytimeGifts[gifts]
			while gift and t >= gift.Minutes * 60 do
				coins += gift.Coins + (if gift.RotatingPull and gift.RotatingPull[day % 3 + 1] == "Glassies"
					then econ.KilnCoinCost
					else 0)
				gifts += 1
				gift = econ.PlaytimeGifts[gifts]
			end
			while coins >= econ.KilnCoinCost do
				coins -= econ.KilnCoinCost
				pulls += 1
				gain(Formula.rollKiln(rng))
			end
		end
		if day == 7 then
			out.UniqueDay7, out.Best7 = unique, bestThree(owned)
			for id in owned do
				local r = Glassies.get(id).Rarity
				if (r == "Legendary" or r == "Mythic") and Glassies.isRelease(id) then
					out.Legendary7 = true
				end
			end
		end
	end
	out.Robux, out.UniqueDay30, out.Pulls30, out.Best30 = robux, unique, pulls, bestThree(owned)
	return out
end

function PayerSim.simulate(players, seed)
	players = players or 600
	local results = {}
	for _, persona in PayerSim.Personas do
		local robux, u7, u30, pulls, best, best7, leg, myth = {}, {}, {}, {}, {}, {}, 0, 0
		for i = 1, players do
			local r = play(persona, (seed or 116) + i * 7919)
			table.insert(robux, r.Robux)
			table.insert(u7, r.UniqueDay7)
			table.insert(u30, r.UniqueDay30)
			table.insert(pulls, r.Pulls30)
			table.insert(best, r.Best30)
			table.insert(best7, r.Best7)
			leg += if r.Legendary7 then 1 else 0
			myth += if r.Mythic30 then 1 else 0
		end
		results[persona] = {
			Robux = median(robux),
			UniqueDay7 = median(u7),
			UniqueDay30 = median(u30),
			Pulls30 = median(pulls),
			Best30 = median(best),
			Best7 = median(best7),
			Legendary7 = leg / players,
			Mythic30 = myth / players,
		}
	end
	local free, free7 = results.Free.Best30, results.Free.Best7
	for _, r in results do
		r.Edge30, r.Edge7 = r.Best30 / free - 1, r.Best7 / free7 - 1
	end
	return results
end

function PayerSim.report(): string
	local r = PayerSim.simulate()
	local kiln = 0
	for _, def in Glassies.ReleaseList do
		if Balance.Rarities[def.Rarity].CrateWeight > 0 then
			kiln += 1
		end
	end
	local lines = {
		"Payer report (600 players each, 40 min a day for 30 days; Marbles all into Marble Kiln pulls)",
		string.format(
			"%-11s %8s %8s %9s %9s %9s %10s %9s %9s",
			"persona",
			"R$/30d",
			"pulls",
			"unique7",
			"unique30",
			"Leg by7",
			"Mythic30",
			"edge d7",
			"edge d30"
		),
	}
	for _, persona in PayerSim.Personas do
		local x = r[persona]
		table.insert(
			lines,
			string.format(
				"%-11s %8d %8d %9d %9d %8d%% %9d%% %8.1f%% %8.1f%%",
				persona,
				x.Robux,
				x.Pulls30,
				x.UniqueDay7,
				x.UniqueDay30,
				math.floor(x.Legendary7 * 100 + 0.5),
				math.floor(x.Mythic30 * 100 + 0.5),
				x.Edge7 * 100,
				x.Edge30 * 100
			)
		)
	end
	table.insert(
		lines,
		string.format(
			"(Kiln holds %d glassies; unique counts include Daily and Starter glassies. HP edge = best three glassies' HP over a free player's; the cap is +%.1f%%: Mythic x5 stars.)",
			kiln,
			(Balance.Rarities.Mythic.StatMultiplier * (1 + Balance.Growth.StatPerStar * Balance.Growth.MaxStars) - 1)
				* 100
		)
	)
	return table.concat(lines, "\n")
end

return PayerSim
