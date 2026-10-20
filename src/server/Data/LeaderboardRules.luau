-- Leaderboard rules (decision 101, Proposed). Pure and Lune-tested: the weekly key, Robux spend recording (receipts
-- and game passes), the stat a board shows for a profile, ordered-store row cleanup and number formatting.
local Rules = {}

local DAY = 86400
local WEEK = 7 * DAY
-- 1970-01-01 was a Thursday, so Monday 1969-12-29 00:00 UTC (-3 days) starts week 0.
local EPOCH_MONDAY = -3 * DAY

-- Week number since 1969-12-29 (weeks start Monday 00:00 UTC).
function Rules.weekIndex(now)
	return math.floor((now - EPOCH_MONDAY) / WEEK)
end

-- Ordered-store key for the week containing `now`, e.g. "W2911".
function Rules.weekKey(now)
	return "W" .. Rules.weekIndex(now)
end

-- When the week containing `now` ends (next Monday 00:00 UTC).
function Rules.weekEnds(now)
	return EPOCH_MONDAY + (Rules.weekIndex(now) + 1) * WEEK
end

local function whole(value)
	return type(value) == "number" and value == value and value > 0 and value < math.huge and value % 1 == 0
end

function Rules.newSpend()
	return { Total = 0, Week = "", WeekTotal = 0, Passes = {} }
end

-- Profile shape repair (ProfileSchema.reconcile).
function Rules.reconcile(data)
	local spend = type(data.Spend) == "table" and data.Spend or Rules.newSpend()
	spend.Total = if whole(spend.Total) then spend.Total else 0
	spend.WeekTotal = if whole(spend.WeekTotal) then spend.WeekTotal else 0
	spend.Week = if type(spend.Week) == "string" then spend.Week else ""
	spend.Passes = if type(spend.Passes) == "table" then spend.Passes else {}
	data.Spend = spend
	return spend
end

-- Adds `robux` to the all-time and this week's totals. The caller guarantees each purchase is recorded once (a
-- receipt only reaches "Granted" once per PurchaseId); returns false for a non-positive or non-whole amount.
function Rules.recordSpend(data, robux, now)
	if not whole(robux) then
		return false
	end
	local spend = Rules.reconcile(data)
	local week = Rules.weekKey(now)
	if spend.Week ~= week then
		spend.Week, spend.WeekTotal = week, 0
	end
	spend.Total += robux
	spend.WeekTotal += robux
	return true
end

-- A game pass can only be bought once: record its price the first time only.
function Rules.recordPass(data, passId, robux, now)
	local key = tostring(passId)
	local spend = Rules.reconcile(data)
	if type(passId) ~= "number" or spend.Passes[key] or not whole(robux) then
		return false
	end
	spend.Passes[key] = now
	return Rules.recordSpend(data, robux, now)
end

-- The Robux amount of a developer-product receipt (Roblox fills CurrencySpent; only Robux counts).
function Rules.receiptRobux(receipt)
	if type(receipt) ~= "table" then
		return 0
	end
	local currency = receipt.CurrencyType
	if currency ~= nil and tostring(currency) ~= "Enum.CurrencyType.Robux" and currency ~= "Robux" then
		return 0
	end
	return if whole(receipt.CurrencySpent) then receipt.CurrencySpent else 0
end

-- The value a board stat has for a profile right now (RobuxWeek is 0 once the week it was earned in has ended).
function Rules.statValue(data, stat, now)
	if stat == "MatchWins" or stat == "Shatters" then
		return data.Stats and data.Stats[stat] or 0
	elseif stat == "Trophies" then
		return data.Trophies or 0
	end
	local spend = type(data.Spend) == "table" and data.Spend or Rules.newSpend()
	if stat == "RobuxTotal" then
		return spend.Total or 0
	elseif stat == "RobuxWeek" then
		return if spend.Week == Rules.weekKey(now) then spend.WeekTotal or 0 else 0
	end
	return 0
end

-- Ordered-store name for a stat at `now`.
function Rules.storeName(prefix, stat, weekly, now)
	return prefix .. "_" .. stat .. if weekly then "_" .. Rules.weekKey(now) else ""
end

-- Cleans GetSortedAsync entries ({ key, value }) into ranked rows: real user ids, positive whole values, best first.
function Rules.rows(entries, limit)
	local rows = {}
	for _, entry in entries do
		local id = tonumber(entry.key)
		if id and id > 0 and id % 1 == 0 and whole(entry.value) then
			table.insert(rows, { UserId = id, Value = entry.value })
		end
	end
	table.sort(rows, function(a, b)
		return if a.Value == b.Value then a.UserId < b.UserId else a.Value > b.Value
	end)
	while #rows > limit do
		table.remove(rows)
	end
	for rank, row in rows do
		row.Rank = rank
	end
	return rows
end

local function commas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- Short display text: 1,234 below 100K, then 123K / 1.2M.
function Rules.format(value)
	value = math.max(0, math.floor(value or 0))
	if value >= 1e6 then
		return (string.format("%.1fM", value / 1e6):gsub("%.0M", "M"))
	elseif value >= 1e5 then
		return string.format("%dK", math.floor(value / 1e3))
	end
	return commas(value)
end

-- "Resets in 2d 5h" style text for the weekly board.
function Rules.resetText(now)
	local left = math.max(0, Rules.weekEnds(now) - now)
	local days, hours, minutes = left // DAY, (left % DAY) // 3600, (left % 3600) // 60
	if days > 0 then
		return string.format("RESETS IN %dD %dH", days, hours)
	elseif hours > 0 then
		return string.format("RESETS IN %dH %dM", hours, minutes)
	end
	return string.format("RESETS IN %dM", math.max(1, minutes))
end

return Rules
