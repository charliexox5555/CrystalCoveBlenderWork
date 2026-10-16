-- Pure probability/price rules shared by quote display, server rolls and tests.
local B = if script then require(script.Parent.Config.Balance) else require("./Config/Balance")
local C = if script then require(script.Parent.Config.RoundCosmetics) else require("./Config/RoundCosmetics")
local R = {}
function R.cost(category, currency, count)
	local prices = B.Crates.Prices[category]
	if not prices or not prices[currency] or (count ~= 1 and count ~= 10) then
		return nil
	end
	if category == "Glassies" and currency == "Coins" and count == 10 then
		return B.Economy.KilnTenPullCost
	end
	return prices[currency] * count
end
function R.odds(category, currency, available, glassyOdds)
	if not B.Crates.Prices[category] or (currency ~= "Coins" and currency ~= "Marbles") then
		return {}
	end
	if category == "Glassies" and currency == "Coins" then
		return glassyOdds or {}
	end
	local list = if category == "Glassies" then glassyOdds or {} else C[category]
	local buckets, weights = {}, {}
	for _, def in list do
		if not available or available[def.Id] then
			buckets[def.Rarity] = buckets[def.Rarity] or {}
			table.insert(buckets[def.Rarity], def.Id)
		end
	end
	local configured = if currency == "Marbles" then B.Crates.MarbleWeights else B.Crates.CoinWeights
	local total = 0
	for rarity, ids in buckets do
		weights[rarity] = configured[rarity] or 0
		total += weights[rarity]
	end
	if total <= 0 then
		return {}
	end
	local out = {}
	for rarity, ids in buckets do
		for _, id in ids do
			table.insert(out, { Id = id, Rarity = rarity, Chance = weights[rarity] / total / #ids })
		end
	end
	table.sort(out, function(a, b)
		local x, y = B.Rarities[a.Rarity].Order, B.Rarities[b.Rarity].Order
		return if x == y then a.Id < b.Id else x < y
	end)
	return out
end
function R.roll(odds, rng)
	assert(#odds > 0, "Empty crate")
	local draw = math.clamp(rng(), 0, 1)
	local ceiling = 0
	for _, entry in odds do
		ceiling += entry.Chance
		if draw < ceiling then
			return entry.Id
		end
	end
	return odds[#odds].Id
end
return R
