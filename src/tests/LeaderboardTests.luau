local Rules = if script
	then require(game.ServerScriptService.Server.Data.LeaderboardRules)
	else require("../server/Data/LeaderboardRules")
local Schema = if script
	then require(game.ServerScriptService.Server.Data.ProfileSchema)
	else require("../server/Data/ProfileSchema")
local Config = if script
	then require(game.ReplicatedStorage.Shared.Config.Leaderboards)
	else require("../shared/Config/Leaderboards")
return function(t)
	-- Monday 2026-10-19 00:00 UTC.
	local monday = 1792368000
	t.test("leaderboards: weeks start Monday 00:00 UTC", function()
		t.eq(Rules.weekKey(monday), Rules.weekKey(monday + 7 * 86400 - 1))
		t.ok(Rules.weekKey(monday - 1) ~= Rules.weekKey(monday), "Sunday 23:59 is last week")
		t.eq(Rules.weekEnds(monday), monday + 7 * 86400)
		t.eq(Rules.weekEnds(monday + 3 * 86400 + 5), monday + 7 * 86400)
		t.eq(Rules.resetText(monday + 5 * 86400), "RESETS IN 2D 0H")
		t.eq(Rules.resetText(monday + 7 * 86400 - 600), "RESETS IN 10M")
	end)
	t.test("leaderboards: Robux spend adds up and the weekly total resets", function()
		local data = Schema.new(monday)
		t.eq(data.Spend.Total, 0)
		t.ok(Rules.recordSpend(data, 99, monday + 10), "first purchase")
		t.ok(Rules.recordSpend(data, 400, monday + 20), "second purchase")
		t.eq(Rules.statValue(data, "RobuxTotal", monday + 30), 499)
		t.eq(Rules.statValue(data, "RobuxWeek", monday + 30), 499)
		-- Next week: the weekly stat reads 0 until they spend again, then starts over.
		local nextWeek = monday + 7 * 86400 + 60
		t.eq(Rules.statValue(data, "RobuxWeek", nextWeek), 0)
		Rules.recordSpend(data, 25, nextWeek)
		t.eq(Rules.statValue(data, "RobuxWeek", nextWeek), 25)
		t.eq(Rules.statValue(data, "RobuxTotal", nextWeek), 524)
		-- Junk amounts are ignored.
		for _, bad in { 0, -5, 1.5, 0 / 0, math.huge, "10" } do
			t.eq(Rules.recordSpend(data, bad :: any, nextWeek), false)
		end
		t.eq(data.Spend.Total, 524)
	end)
	t.test("leaderboards: a game pass counts once", function()
		local data = Schema.new(monday)
		t.ok(Rules.recordPass(data, 123, 250, monday), "first time")
		t.eq(Rules.recordPass(data, 123, 250, monday + 5), false)
		t.eq(Rules.recordPass(data, "123" :: any, 250, monday + 5), false)
		t.eq(data.Spend.Total, 250)
	end)
	t.test("leaderboards: receipt Robux comes from CurrencySpent", function()
		t.eq(Rules.receiptRobux({ CurrencySpent = 199, CurrencyType = "Robux" }), 199)
		t.eq(Rules.receiptRobux({ CurrencySpent = 199 }), 199)
		t.eq(Rules.receiptRobux({ CurrencySpent = 199, CurrencyType = "Tix" }), 0)
		t.eq(Rules.receiptRobux({ CurrencySpent = -1 }), 0)
		t.eq(Rules.receiptRobux(nil), 0)
	end)
	t.test("leaderboards: board stats and profile repair", function()
		local data = Schema.new(monday)
		data.Stats.MatchWins = 12
		t.eq(Rules.statValue(data, "MatchWins", monday), 12)
		data.Spend = { Total = "lots", WeekTotal = -3 }
		local fixed = Schema.reconcile(data, monday)
		t.eq(fixed.Spend.Total, 0)
		t.eq(fixed.Spend.WeekTotal, 0)
		t.eq(type(fixed.Spend.Passes), "table")
		local legacy = Schema.new(monday)
		legacy.Spend = nil
		t.eq(Schema.reconcile(legacy, monday).Spend.Total, 0)
	end)
	t.test("leaderboards: ordered-store rows are cleaned and ranked", function()
		local rows = Rules.rows({
			{ key = "5", value = 10 },
			{ key = "-1", value = 99 }, -- Studio test players
			{ key = "abc", value = 50 },
			{ key = "7", value = 30 },
			{ key = "3", value = 30 },
			{ key = "9", value = 0 },
		}, 2)
		t.eq(#rows, 2)
		t.eq(rows[1].UserId, 3)
		t.eq(rows[2].UserId, 7)
		t.eq(rows[2].Rank, 2)
		t.eq(Rules.storeName("GC", "RobuxWeek", true, monday), "GC_RobuxWeek_" .. Rules.weekKey(monday))
		t.eq(Rules.storeName("GC", "MatchWins", false, monday), "GC_MatchWins")
	end)
	t.test("leaderboards: number formatting", function()
		t.eq(Rules.format(0), "0")
		t.eq(Rules.format(1234), "1,234")
		t.eq(Rules.format(99999), "99,999")
		t.eq(Rules.format(123456), "123K")
		t.eq(Rules.format(1200000), "1.2M")
		t.eq(Rules.format(3000000), "3M")
	end)
	t.test("leaderboards: config has left, middle and right boards with known stats", function()
		local slots, known =
			{}, { MatchWins = true, RobuxWeek = true, RobuxTotal = true, Trophies = true, Shatters = true }
		for _, board in Config.Boards do
			t.ok(known[board.Stat], board.Id .. " stat")
			slots[board.Slot] = board.Stat
		end
		t.eq(slots.Left, "RobuxWeek")
		t.eq(slots.Middle, "MatchWins")
		t.eq(slots.Right, "RobuxTotal")
	end)
end
