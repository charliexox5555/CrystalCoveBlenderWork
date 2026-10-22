-- Badge rules (decision 118, docs/design/BADGES.md). Pure and Lune-tested: what a player has earned and what is still
-- due. BadgeService only talks to Roblox. The profile keeps two sets:
--   Badges.Earned[key]  = true once the rule fired (kept even while the award fails or the badge has no id yet)
--   Badges.Awarded[key] = true once Roblox confirmed the award (or the player already owned it)
-- so a badge is never awarded twice and a failed award is simply due again on the next check.
local Shared = if script then game.ReplicatedStorage.Shared else nil
local Config = if Shared then require(Shared.Config.Badges) else require("../../shared/Config/Badges")
local Levels = if Shared then require(Shared.LevelRules) else require("../../shared/LevelRules")
local Rules = {}

local function set(value)
	local out = {}
	if type(value) == "table" then
		for key, flag in value do
			if Config.ByKey[key] and flag == true then
				out[key] = true
			end
		end
	end
	return out
end

-- Profile shape: unknown keys and non-true values are dropped.
function Rules.reconcile(data)
	local badges = if type(data.Badges) == "table" then data.Badges else {}
	data.Badges = { Earned = set(badges.Earned), Awarded = set(badges.Awarded) }
	return data.Badges
end

-- Marks a badge earned; true when it is new.
function Rules.earn(data, key)
	if not Config.ByKey[key] or type(data.Badges) ~= "table" then
		return false
	end
	if data.Badges.Earned[key] then
		return false
	end
	data.Badges.Earned[key] = true
	return true
end

function Rules.markAwarded(data, key)
	if Config.ByKey[key] and type(data.Badges) == "table" then
		data.Badges.Earned[key], data.Badges.Awarded[key] = true, true
	end
end

-- Badges that follow from the saved profile, so they also reach players who got there before badges existed:
-- Welcome (any profile, i.e. the first join), Level 10, and the Daily week (Day 7 claimed, or Midnight owned).
function Rules.fromState(data)
	local new = {}
	local function check(key, met)
		if met and Rules.earn(data, key) then
			table.insert(new, key)
		end
	end
	check("Welcome", true)
	check("Level10", Levels.level(data.Xp) >= Config.Level)
	local calendar = if type(data.Calendar) == "table" then data.Calendar else {}
	local owned = type(data.Glassies) == "table" and data.Glassies[Config.WeekGlassy] ~= nil
	check("DailyWeek", (tonumber(calendar.Index) or 0) >= Config.WeekDays or owned)
	return new
end

-- A round was won. Only a win over another player counts (the creator: "not against a bot"); a bot side has no player.
function Rules.roundWon(winnerIsPlayer, loserIsPlayer)
	return if winnerIsPlayer == true and loserIsPlayer == true then "FirstWin" else nil
end

-- A Kiln opening (any Kiln, any currency): the rarities that came out.
function Rules.pulled(rarities)
	for _, rarity in rarities or {} do
		if Config.FindRarities[rarity] then
			return "LegendaryFind"
		end
	end
	return nil
end

-- Earned, not yet awarded, in award order. `skip` holds keys to leave out (Studio's per-server mock awards);
-- `needId` = false lets a badge without a Roblox id through (Studio only, so the flow can be tried before ids exist).
function Rules.due(data, skip, needId)
	local out = {}
	if type(data.Badges) ~= "table" then
		return out
	end
	for _, key in Config.Order do
		local def = Config.ByKey[key]
		if
			data.Badges.Earned[key]
			and not data.Badges.Awarded[key]
			and not (skip and skip[key])
			and (needId == false or type(def.Id) == "number")
		then
			table.insert(out, key)
		end
	end
	return out
end

return Rules
