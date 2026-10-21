-- Pure, serializable daily bookkeeping. Client-supplied progress/time is never accepted.
local Shared = if script then game.ReplicatedStorage.Shared else nil
local Balance = if Shared then require(Shared.Config.Balance) else require("../../shared/Config/Balance")
local Content = if Shared then require(Shared.Config.Retention) else require("../../shared/Config/Retention")
local Grant = if script then require(script.Parent.RewardGrant) else require("./RewardGrant")
local Formula = if Shared then require(Shared.Formula) else require("../../shared/Formula")
local Rules = {}
local function natural(value)
	return if type(value) == "number"
			and value == value
			and math.abs(value) < math.huge
		then math.max(0, math.floor(value))
		else 0
end
function Rules.day(now)
	return math.floor(now / Balance.Data.DaySeconds)
end
function Rules.ensure(data, now)
	local day = Rules.day(now)
	local daily = data.Daily
	if daily.Day ~= day then
		daily.Day, daily.Quests, daily.PlaytimeClaimed, daily.PlaytimeSeconds = day, {}, {}, 0
	end
	if natural(daily.Streak) == 0 or daily.LastClaimDay ~= day then
		daily.Streak = if daily.LastClaimDay == day - 1 and natural(daily.Streak) > 0
			then natural(daily.Streak) + 1
			else 1
		daily.LastClaimDay = day
	end
	for _, def in Content.Quests do
		local q = daily.Quests[def.Id]
		if type(q) ~= "table" then
			q = {}
			daily.Quests[def.Id] = q
		end
		q.Progress, q.Claimed = math.min(def.Goal, natural(q.Progress)), q.Claimed == true
	end
	daily.PlaytimeSeconds = natural(daily.PlaytimeSeconds)
	return daily
end
function Rules.advance(data, seconds, now)
	local daily = Rules.ensure(data, now)
	daily.PlaytimeSeconds = math.min(
		Balance.Economy.PlaytimeGifts[#Balance.Economy.PlaytimeGifts].Minutes * 60,
		daily.PlaytimeSeconds + natural(seconds)
	)
end
function Rules.match(data, match, side, observed, now)
	if observed.Eligible == false then
		return 0
	end
	local daily = Rules.ensure(data, now)
	for _, def in Content.Quests do
		local q = daily.Quests[def.Id]
		q.Progress = math.min(def.Goal, q.Progress + natural(observed[def.Observed]))
	end
	local won = match.Winner == side
	if won and natural(observed.RoundWins) > 0 then
		data.Stats.WinStreak = natural(data.Stats.WinStreak) + 1
		data.Stats.BestStreak = math.max(natural(data.Stats.BestStreak), data.Stats.WinStreak)
		if daily.FirstWinDay ~= daily.Day then
			daily.FirstWinDay = daily.Day
			data.Coins += Balance.Economy.FirstWinOfDayCoins
			return Balance.Economy.FirstWinOfDayCoins
		end
	elseif not won then
		data.Stats.WinStreak = 0
	end
	return 0
end
-- A playtime gift's bundle on a UTC day: coins and XP plus, for a RotatingPull gift, that day's free pull ticket.
function Rules.giftReward(gift, day)
	local reward = {}
	if (gift.Coins or 0) > 0 then
		reward.Coins = gift.Coins
	end
	if (gift.Xp or 0) > 0 then
		reward.Xp = gift.Xp
	end
	if gift.RotatingPull then
		reward.Pull = gift.RotatingPull[day % #gift.RotatingPull + 1]
	end
	return reward
end

-- Playtime gifts collect themselves (decision 115): every gift whose time is reached is granted once per UTC day.
-- Returns the list of gifts granted now: { { Id, Reward, Item }, ... } (empty when nothing new).
function Rules.collectGifts(data, now)
	local daily = Rules.ensure(data, now)
	local granted = {}
	for i, gift in Balance.Economy.PlaytimeGifts do
		local key = "gift_" .. i
		if not daily.PlaytimeClaimed[key] and daily.PlaytimeSeconds >= gift.Minutes * 60 then
			daily.PlaytimeClaimed[key] = true
			local reward = Rules.giftReward(gift, daily.Day)
			table.insert(granted, { Id = i, Reward = reward, Item = Grant.apply(data, reward, now) })
		end
	end
	return granted
end

-- A Daily glassy day gives another copy until the glassy is at max stars, then its WhenMaxed bundle (decision 115).
local function maxed(data, item)
	local owned = item and item.Category == "Glassies" and data.Glassies[item.Id]
	if not owned then
		return false
	end
	local stars = Formula.starsFromDuplicates(owned.Count - 1)
	return stars >= Balance.Growth.MaxStars
end

-- What a calendar day gives this player now: the bundle without its WhenMaxed note, or WhenMaxed when it applies.
function Rules.dailyReward(data, def)
	if def.WhenMaxed and maxed(data, def.Item) then
		return table.clone(def.WhenMaxed)
	end
	local reward = table.clone(def)
	reward.WhenMaxed = nil
	return reward
end

-- Daily Rewards calendar (decision 99): one claim per UTC day; a missed day keeps your place. Index counts the days
-- claimed in the current 7-day cycle; the claim after Day 7 starts a new cycle at Day 1.
function Rules.calendar(data, now)
	local day = Rules.day(now)
	local cal = data.Calendar
	local claimedToday = cal.LastDay == day
	local count = if claimedToday or cal.Index < #Balance.Economy.DailyRewards then cal.Index else 0
	local rewards = {}
	for i, def in Balance.Economy.DailyRewards do
		rewards[i] = Rules.dailyReward(data, def)
	end
	return {
		Count = count,
		Next = if claimedToday then nil else count + 1,
		ClaimedToday = claimedToday,
		ResetAt = (day + 1) * Balance.Data.DaySeconds,
		Rewards = rewards,
	}
end

function Rules.claimDaily(data, now)
	local view = Rules.calendar(data, now)
	if view.ClaimedToday then
		return false, "Come back tomorrow for Day " .. (view.Count % #view.Rewards + 1)
	end
	local reward = view.Rewards[view.Next]
	data.Calendar.Index, data.Calendar.LastDay = view.Next, Rules.day(now)
	local item = Grant.apply(data, reward, now)
	return true, "Day " .. view.Next .. ": " .. Grant.describe(reward), reward, item
end

function Rules.claim(data, kind, id, now)
	local daily = Rules.ensure(data, now)
	local amount
	if kind == "Quest" and type(id) == "string" then
		for _, def in Content.Quests do
			if def.Id == id then
				local q = daily.Quests[id]
				if q.Claimed then
					return false, "Already claimed"
				end
				if q.Progress < def.Goal then
					return false, "Keep clashing to finish this quest"
				end
				q.Claimed = true
				amount = Balance.Economy.DailyQuestCoins
				break
			end
		end
	elseif kind == "Daily" then
		return Rules.claimDaily(data, now)
	elseif kind == "Gift" and type(id) == "number" and id % 1 == 0 then
		local gift = Balance.Economy.PlaytimeGifts[id]
		if gift then
			local key = "gift_" .. id
			if daily.PlaytimeClaimed[key] then
				return false, "Already claimed"
			end
			if daily.PlaytimeSeconds < gift.Minutes * 60 then
				return false, "This gift is not ready yet"
			end
			daily.PlaytimeClaimed[key] = true
			local reward = Rules.giftReward(gift, daily.Day)
			local item = Grant.apply(data, reward, now)
			return true, "Playtime gift: " .. Grant.describe(reward), reward, item
		end
	end
	if not amount then
		return false, "Unknown reward"
	end
	data.Coins += amount
	return true, "Claimed +" .. amount .. " coins", amount
end
function Rules.redeem(data, input, studio, now)
	if type(input) ~= "string" or #input > 32 then
		return false, "Enter a valid code"
	end
	local code = string.upper(input:match("^%s*(.-)%s*$"))
	if not code:match("^[A-Z0-9_]+$") then
		return false, "Enter a valid code"
	end
	local def = Content.Codes[code]
	if not def or (def.StudioOnly and not studio) or (def.Starts and (now or 0) < def.Starts) then
		return false, "That code doesn't exist"
	end
	if data.CodesRedeemed[code] then
		return false, "Already redeemed"
	end
	if def.Expires and (now or 0) >= def.Expires then
		return false, "That code has expired"
	end
	if not Grant.valid(def.Reward) then
		return false, "That code doesn't exist"
	end
	data.CodesRedeemed[code] = true
	local item = Grant.apply(data, def.Reward, now or 0)
	local got = Grant.describe(def.Reward)
	return true, "Code redeemed! " .. string.upper(got:sub(1, 1)) .. got:sub(2), def.Reward, item
end
function Rules.view(data, now, studio)
	local daily = Rules.ensure(data, now)
	local quests, gifts = {}, {}
	for _, def in Content.Quests do
		local q = daily.Quests[def.Id]
		table.insert(quests, {
			Id = def.Id,
			Name = def.Name,
			Goal = def.Goal,
			Progress = q.Progress,
			Claimed = q.Claimed,
			Coins = Balance.Economy.DailyQuestCoins,
		})
	end
	for i, def in Balance.Economy.PlaytimeGifts do
		table.insert(gifts, {
			Id = i,
			Seconds = def.Minutes * 60,
			Coins = def.Coins,
			Reward = Rules.giftReward(def, daily.Day),
			Claimed = daily.PlaytimeClaimed["gift_" .. i] == true,
		})
	end
	return {
		Quests = quests,
		Gifts = gifts,
		PlaytimeSeconds = daily.PlaytimeSeconds,
		Streak = daily.Streak,
		Day = daily.Day,
		ResetAt = (daily.Day + 1) * Balance.Data.DaySeconds,
		FirstWinClaimed = daily.FirstWinDay == daily.Day,
		Calendar = Rules.calendar(data, now),
		FreePulls = data.FreePulls,
		FreeMarbles = false,
		TestCodes = studio,
		GroupConfigured = Content.GroupId > 0,
	}
end
return Rules
