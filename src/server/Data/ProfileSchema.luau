-- Serializable profile shape and mutations; testable without Roblox services.
local Shared = if script then game.ReplicatedStorage.Shared else nil
local Balance = if Shared then require(Shared.Config.Balance) else require("../../shared/Config/Balance")
local Glassies = if Shared then require(Shared.Config.Glassies) else require("../../shared/Config/Glassies")
local Formula = if Shared then require(Shared.Formula) else require("../../shared/Formula")
local Schema = {}
local RoundCosmetics = if Shared then require(Shared.RoundCosmeticRules) else require("../../shared/RoundCosmeticRules")
local DailyStore = if Shared then require(Shared.DailyStoreRules) else require("../../shared/DailyStoreRules")
local Rules = if script then require(script.Parent.OnboardingRules) else require("./OnboardingRules")
local Boards = if script then require(script.Parent.LeaderboardRules) else require("./LeaderboardRules")
local Levels = if Shared then require(Shared.LevelRules) else require("../../shared/LevelRules")
local BadgeRules = if script then require(script.Parent.BadgeRules) else require("./BadgeRules")

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
		-- Total XP (decision 104); the level is derived from it by LevelRules. Everyone starts at Lv 1 / 0 XP.
		Xp = 0,
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
			WinStreak = 0,
			BestStreak = 0,
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
		-- Daily Rewards calendar (decision 99): Index = days claimed in the current 7-day cycle, LastDay = UTC day of
		-- the last claim. Free pull tickets per crate category, spent in the Shop with the odds shown.
		Calendar = { Index = 0, LastDay = -1 },
		-- First session (decision 100): Welcome -> Daily -> Arena -> Match -> Win -> Done (OnboardingRules); Funnel = the
		-- last tutorial funnel step logged (0 = none).
		Onboarding = { Step = "Welcome", Funnel = 0 },
		FreePulls = { Glassies = 0, Finishers = 0, Rideables = 0 },
		Flags = { WelcomePullUsed = false, GroupRewardClaimed = false },
		CodesRedeemed = {},
		ProcessedReceipts = {},
		-- Robux spent (decision 101): all time, this week (Week = LeaderboardRules.weekKey), game passes recorded.
		Spend = Boards.newSpend(),
		RecentMatches = {},
		-- Daily Featured store: today's locked offers, open Robux intents, bundle purchases.
		Store = { Version = 0, Day = -1, Offers = {}, Intents = {}, Bundles = {} },
		-- Badges (decision 118, BadgeRules): earned by the rules, awarded once Roblox confirmed.
		Badges = { Earned = {}, Awarded = {} },
	}
	-- No starter glassies (decision 102): the welcome opens are a new player's first three.
	RoundCosmetics.reconcile(data)
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
	-- Profiles from before onboarding: players who already played skip it (the default would start it).
	if type(data.Onboarding) ~= "table" then
		local played = type(data.Stats) == "table"
			and (tonumber(data.Stats.MatchWins) or 0) + (tonumber(data.Stats.MatchLosses) or 0) > 0
		local welcomed = type(data.Flags) == "table" and data.Flags.WelcomePullUsed == true
		data.Onboarding = { Step = if played or welcomed then "Done" else "Welcome" }
		-- Players who skip onboarding never enter the funnel.
		data.Onboarding.Funnel = if played or welcomed then #Rules.Funnel else 0
	end
	-- Profiles from before the funnel: anyone already done stays out of it.
	if data.Onboarding.Funnel == nil and data.Onboarding.Step == "Done" then
		data.Onboarding.Funnel = #Rules.Funnel
	end
	if type(data.Glassies) == "table" then
		for _, owned in data.Glassies do
			if type(owned) == "table" and owned.Count == nil then
				owned.Count = 1 + integer(owned.Stars, 0) * Balance.Growth.DuplicatesPerStar
			end
		end
	end
	fill(data, Schema.new(now))
	RoundCosmetics.migrateSkins(data, now)
	data.Version = Balance.Data.Version
	data.Coins, data.Marbles, data.Trophies =
		integer(data.Coins, 0), integer(data.Marbles, 0), integer(data.Trophies, 0)
	data.Xp = integer(data.Xp, 0)
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
	data.Flags.GroupRewardClaimed = data.Flags.GroupRewardClaimed == true -- group reward (decision 114)
	data.Onboarding.Funnel = math.min(#Rules.Funnel, integer(data.Onboarding.Funnel, 0))
	for category in data.FreePulls do
		data.FreePulls[category] = integer(data.FreePulls[category], 0)
	end
	data.Calendar.Index = math.min(7, integer(data.Calendar.Index, 0))
	data.Calendar.LastDay = if type(data.Calendar.LastDay) == "number" then math.floor(data.Calendar.LastDay) else -1
	Boards.reconcile(data)
	RoundCosmetics.reconcile(data)
	DailyStore.reconcile(data)
	BadgeRules.reconcile(data)
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
	return {
		Id = id,
		Count = owned.Count,
		Duplicate = duplicate,
		Stars = stars,
		Rainbow = owned.Rainbow,
		BonusCoins = bonus,
	}
end

-- Grant one store item (a glassy copy or a cosmetic copy) and return its result.
function Schema.grantItem(data, category, id, now)
	if category == "Glassies" then
		return Schema.grant(data, id, false, now)
	end
	return RoundCosmetics.grant(data, category, id)
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
	if observed and observed.Eligible == false then
		return true -- remember the result without currency, stats or welcome eligibility
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
	-- XP (decision 104): written back into `observed` so the caller can show it.
	local xp = Levels.matchXp({
		Won = match.Winner == side,
		RoundsWon = observed.RoundWins,
		Perfects = observed.Perfects,
		VsBot = observed.VsBot,
		Forfeited = observed.Forfeited,
	})
	local levels
	data.Xp, levels = Levels.add(data.Xp, xp)
	observed.XpGained, observed.LevelsGained = xp, levels
	RoundCosmetics.reconcile(data)
	return true
end

-- What another player may see of this profile (read-only profile view, decision 104): level, a few stats and
-- what they own. Nothing about currency, purchases, codes or settings.
function Schema.publicView(data)
	local glassies = {}
	for id, owned in data.Glassies or {} do
		if Glassies.ById[id] and type(owned) == "table" then
			glassies[id] =
				{ Count = integer(owned.Count, 1), Stars = integer(owned.Stars, 0), Rainbow = owned.Rainbow == true }
		end
	end
	local stats, cosmetics = data.Stats or {}, data.Cosmetics or {}
	return {
		Level = Levels.view(data.Xp),
		Stats = {
			MatchWins = integer(stats.MatchWins, 0),
			MatchLosses = integer(stats.MatchLosses, 0),
			BestStreak = integer(stats.BestStreak, 0),
		},
		Glassies = glassies,
		Cosmetics = {
			Finishers = Schema.copy(cosmetics.Finishers or {}),
			Rideables = Schema.copy(cosmetics.Rideables or {}),
			EquippedFinishers = cosmetics.EquippedFinishers,
			EquippedRideables = cosmetics.EquippedRideables,
		},
	}
end

-- Playtest grant (Config/Testing): once per wave while enabled; returns the Marbles added.
function Schema.testerGrant(data, config)
	if not config or not config.Enabled or type(config.Wave) ~= "string" or (config.Amount or 0) <= 0 then
		return 0
	end
	data.Flags.TesterGrants = if type(data.Flags.TesterGrants) == "table" then data.Flags.TesterGrants else {}
	if data.Flags.TesterGrants[config.Wave] then
		return 0
	end
	data.Flags.TesterGrants[config.Wave] = true
	data.Marbles += math.floor(config.Amount)
	return math.floor(config.Amount)
end

function Schema.welcomePulls(data)
	return if not data.Flags.WelcomePullUsed and data.Stats.MatchWins + data.Stats.MatchLosses > 0
		then Balance.Economy.WelcomeKilnPulls
		else 0
end

function Schema.snapshot(data)
	return Schema.copy({
		Coins = data.Coins,
		Marbles = data.Marbles,
		Trophies = data.Trophies,
		Level = Levels.view(data.Xp),
		Glassies = data.Glassies,
		Cosmetics = data.Cosmetics,
		Stats = data.Stats,
		Daily = data.Daily,
		WelcomePulls = Schema.welcomePulls(data),
		Version = data.Version,
	})
end

function Schema.spendMarbles(data, amount)
	if type(amount) ~= "number" or amount ~= amount or amount == math.huge or amount < 0 or amount % 1 ~= 0 then
		return false
	end
	if data.Marbles < amount then
		return false
	end
	data.Marbles -= amount
	return true
end

return Schema
