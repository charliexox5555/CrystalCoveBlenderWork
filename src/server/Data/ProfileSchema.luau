-- Serializable profile shape and mutations; testable without Roblox services.
local Shared = if script then game.ReplicatedStorage.Shared else nil
local Balance = if Shared then require(Shared.Config.Balance) else require("../../shared/Config/Balance")
local Glassies = if Shared then require(Shared.Config.Glassies) else require("../../shared/Config/Glassies")
local Formula = if Shared then require(Shared.Formula) else require("../../shared/Formula")
local Schema = {}

function Schema.copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, child in value do
		out[key] = Schema.copy(child)
	end
	return out
end

function Schema.new(now)
	local data = {
		Version = Balance.Data.Version,
		Coins = 0,
		Marbles = 0,
		Trophies = 0,
		Glassies = {},
		Cosmetics = { ShatterFx = { "default" }, EquippedShatterFx = "default", Fills = {} },
		Stats = {
			MatchWins = 0,
			MatchLosses = 0,
			RoundWins = 0,
			Shatters = 0,
			Perfects = 0,
			KilnPulls = 0,
			GlassyUses = {},
		},
		Daily = {
			Streak = 0,
			LastClaimDay = 0,
			Quests = {},
			FirstWinDay = 0,
			PlaytimeClaimed = {},
			Day = 0,
			PlaytimeSeconds = 0,
		},
		Flags = { WelcomePullUsed = false, GroupRewardClaimed = false },
		CodesRedeemed = {},
		ProcessedReceipts = {},
		RecentMatches = {},
	}
	for _, id in Glassies.Starters do
		data.Glassies[id] = { Stars = 0, Rainbow = false, Count = 1, FirstAt = now }
	end
	return data
end

local function fill(target, template)
	for key, value in template do
		if target[key] == nil then
			target[key] = Schema.copy(value)
		elseif type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = Schema.copy(value)
			else
				fill(target[key], value)
			end
		end
	end
end

local function integer(value, fallback)
	return if type(value) == "number"
			and value == value
			and math.abs(value) < math.huge
		then math.max(0, math.floor(value))
		else fallback
end

function Schema.reconcile(data, now)
	assert(type(data.Version) ~= "number" or data.Version <= Balance.Data.Version, "Profile belongs to a newer schema")
	if type(data.Glassies) == "table" then
		for _, owned in data.Glassies do
			if type(owned) == "table" and owned.Count == nil then
				owned.Count = 1 + integer(owned.Stars, 0) * Balance.Growth.DuplicatesPerStar
			end
		end
	end
	fill(data, Schema.new(now))
	data.Version = Balance.Data.Version
	data.Coins, data.Marbles, data.Trophies =
		integer(data.Coins, 0), integer(data.Marbles, 0), integer(data.Trophies, 0)
	for id, owned in data.Glassies do
		if Glassies.ById[id] then
			if type(owned) ~= "table" then
				owned = {}
				data.Glassies[id] = owned
			end
			owned.Count =
				math.max(1, integer(owned.Count, 1 + integer(owned.Stars, 0) * Balance.Growth.DuplicatesPerStar))
			owned.Stars = Formula.starsFromDuplicates(owned.Count - 1)
			owned.Rainbow = owned.Rainbow == true
			owned.FirstAt = if type(owned.FirstAt) == "number" and owned.FirstAt > 0 then owned.FirstAt else now
		end
	end
	for key, default in Schema.new(now).Stats do
		if type(default) == "number" then
			data.Stats[key] = integer(data.Stats[key], 0)
		end
	end
	data.Flags.WelcomePullUsed = data.Flags.WelcomePullUsed == true
	return data
end

function Schema.grant(data, id, rainbow, now)
	assert(Glassies.ById[id], "Unknown glassy")
	local owned = data.Glassies[id]
	local duplicate = owned ~= nil
	local previousOverflow = 0
	if owned then
		local _, overflow = Formula.starsFromDuplicates(owned.Count - 1)
		previousOverflow = overflow
		owned.Count += 1
		owned.Rainbow = owned.Rainbow or rainbow
	else
		owned = { Count = 1, Stars = 0, Rainbow = rainbow == true, FirstAt = now }
		data.Glassies[id] = owned
	end
	local stars, overflow = Formula.starsFromDuplicates(owned.Count - 1)
	owned.Stars = stars
	local bonus = (overflow - previousOverflow) * Balance.Growth.DuplicateCoinsAtMaxStars
	data.Coins += bonus
	return { Id = id, Duplicate = duplicate, Stars = stars, Rainbow = owned.Rainbow, BonusCoins = bonus }
end

function Schema.recordMatch(data, id, match, side, rewards, observed)
	if table.find(data.RecentMatches, id) then
		return false
	end
	assert(match.Over, "Cannot reward an unfinished match")
	table.insert(data.RecentMatches, id)
	while #data.RecentMatches > Balance.Data.RecentMatches do
		table.remove(data.RecentMatches, 1)
	end
	data.Coins += rewards.Coins
	data.Trophies = math.max(0, data.Trophies + rewards.Trophies)
	local stats = data.Stats
	if match.Winner == side then
		stats.MatchWins += 1
	else
		stats.MatchLosses += 1
	end
	observed = observed or {}
	stats.RoundWins += observed.RoundWins or 0
	stats.Shatters += observed.Shatters or 0
	stats.Perfects += observed.Perfects or 0
	for glassyId in observed.Used or {} do
		stats.GlassyUses[glassyId] = (stats.GlassyUses[glassyId] or 0) + 1
	end
	return true
end

function Schema.welcomePulls(data)
	return if not data.Flags.WelcomePullUsed and data.Stats.MatchWins + data.Stats.MatchLosses > 0
		then Balance.Economy.WelcomeKilnPulls
		else 0
end

function Schema.snapshot(data)
	return Schema.copy({
		Coins = data.Coins,
		Trophies = data.Trophies,
		Glassies = data.Glassies,
		Stats = data.Stats,
		Daily = data.Daily,
		WelcomePulls = Schema.welcomePulls(data),
		Version = data.Version,
	})
end

return Schema
