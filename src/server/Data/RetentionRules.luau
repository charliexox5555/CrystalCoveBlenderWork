-- Pure, serializable daily bookkeeping. Client-supplied progress/time is never accepted.
local Shared = if script then game.ReplicatedStorage.Shared else nil
local Balance = if Shared then require(Shared.Config.Balance) else require("../../shared/Config/Balance")
local Content = if Shared then require(Shared.Config.Retention) else require("../../shared/Config/Retention")
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
			amount = gift.Coins
		end
	end
	if not amount then
		return false, "Unknown reward"
	end
	data.Coins += amount
	return true, "Claimed +" .. amount .. " coins", amount
end
function Rules.redeem(data, input, studio)
	if type(input) ~= "string" or #input > 32 then
		return false, "Enter a valid code"
	end
	local code = string.upper(input:match("^%s*(.-)%s*$"))
	if not code:match("^[A-Z0-9_]+$") then
		return false, "Enter a valid code"
	end
	local def = Content.Codes[code]
	if not def or (def.StudioOnly and not studio) then
		return false, "That code is not active"
	end
	if data.CodesRedeemed[code] then
		return false, "Already redeemed"
	end
	local amount = if def.Reward == "QuestCoins" then Balance.Economy.DailyQuestCoins else 0
	data.CodesRedeemed[code] = true
	data.Coins += amount
	return true, "Code redeemed: +" .. amount .. " coins", amount
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
		table.insert(
			gifts,
			{
				Id = i,
				Seconds = def.Minutes * 60,
				Coins = def.Coins,
				Claimed = daily.PlaytimeClaimed["gift_" .. i] == true,
			}
		)
	end
	return {
		Quests = quests,
		Gifts = gifts,
		PlaytimeSeconds = daily.PlaytimeSeconds,
		Streak = daily.Streak,
		Day = daily.Day,
		ResetAt = (daily.Day + 1) * Balance.Data.DaySeconds,
		FirstWinClaimed = daily.FirstWinDay == daily.Day,
		FreeMarbles = false,
		TestCodes = studio,
		GroupConfigured = Content.GroupId > 0,
	}
end
return Rules
