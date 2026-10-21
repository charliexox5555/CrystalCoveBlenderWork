-- One reward bundle for Daily Rewards, Playtime gifts and codes (decisions 99, 115), pure and Lune-tested:
--   { Coins = n?, Marbles = n?, Xp = n?, Pull = "Glassies"|"Finishers"|"Rideables"?, Pulls = n?, Item = { Category, Id }? }
-- A Pull is a free pull ticket (data.FreePulls), spent in the normal Shop so the odds are always shown first.
local Shared = if script then game.ReplicatedStorage.Shared else nil
local Glassies = if Shared then require(Shared.Config.Glassies) else require("../../shared/Config/Glassies")
local Cosmetics = if Shared
	then require(Shared.Config.RoundCosmetics)
	else require("../../shared/Config/RoundCosmetics")
local Roster = if Shared then require(Shared.Config.ReleaseRoster) else require("../../shared/Config/ReleaseRoster")
local Schema = if script then require(script.Parent.ProfileSchema) else require("./ProfileSchema")
local Levels = if Shared then require(Shared.LevelRules) else require("../../shared/LevelRules")
local Grant = {}

Grant.PullCategories = { Glassies = true, Finishers = true, Rideables = true }
local PULL_NAMES = { Glassies = "free Kiln pull", Finishers = "free Finisher crate", Rideables = "free Flyer crate" }

local function count(value)
	return type(value) == "number" and value == value and value >= 1 and value < 1e7 and value % 1 == 0
end

local function itemName(item)
	if item.Category == "Glassies" then
		-- Released glassies, the seasonal Hollowlight and the Daily glassies only; dormant definitions are never granted.
		local def = (Roster.ById[item.Id] or item.Id == "hollowlight" or Glassies.isDaily(item.Id))
			and Glassies.ById[item.Id]
		return def and def.Name
	end
	local def = Cosmetics.ByCategory[item.Category] and Cosmetics.ByCategory[item.Category][item.Id]
	return def and def.Name
end

-- A bundle is valid when every field it has is well formed and it gives at least one thing.
function Grant.valid(reward)
	if type(reward) ~= "table" then
		return false
	end
	local any = false
	for key, value in reward do
		if key == "Coins" or key == "Marbles" or key == "Pulls" or key == "Xp" then
			if not count(value) then
				return false
			end
			any = any or key ~= "Pulls"
		elseif key == "Pull" then
			if not Grant.PullCategories[value] then
				return false
			end
			any = true
		elseif key == "Item" then
			if type(value) ~= "table" or type(value.Id) ~= "string" or not itemName(value) then
				return false
			end
			any = true
		else
			return false
		end
	end
	return any and (reward.Pulls == nil or reward.Pull ~= nil)
end

function Grant.describe(reward)
	local parts = {}
	if reward.Coins then
		table.insert(parts, "+" .. reward.Coins .. " coins")
	end
	if reward.Marbles then
		table.insert(parts, "+" .. reward.Marbles .. " Marbles")
	end
	if reward.Xp then
		table.insert(parts, "+" .. reward.Xp .. " XP")
	end
	if reward.Pull then
		local n = reward.Pulls or 1
		table.insert(parts, (if n > 1 then n .. "× " else "a ") .. PULL_NAMES[reward.Pull])
	end
	if reward.Item then
		table.insert(parts, itemName(reward.Item) or "an item")
	end
	return table.concat(parts, " and ")
end

-- Applies a valid bundle. Returns the result list for items (same shape as Shop grants) for the client.
function Grant.apply(data, reward, now)
	assert(Grant.valid(reward), "Invalid reward")
	data.Coins += reward.Coins or 0
	data.Marbles += reward.Marbles or 0
	if reward.Xp then
		data.Xp = Levels.add(data.Xp, reward.Xp)
	end
	if reward.Pull then
		data.FreePulls[reward.Pull] = (data.FreePulls[reward.Pull] or 0) + (reward.Pulls or 1)
	end
	if reward.Item then
		return {
			Category = reward.Item.Category,
			Result = Schema.grantItem(data, reward.Item.Category, reward.Item.Id, now),
		}
	end
	return nil
end

return Grant
