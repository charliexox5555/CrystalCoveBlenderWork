local Schema = if script
	then require(game.ServerScriptService.Server.Data.ProfileSchema)
	else require("../server/Data/ProfileSchema")
local Rules = if script
	then require(game.ServerScriptService.Server.Data.RetentionRules)
	else require("../server/Data/RetentionRules")
return function(t, d)
	local day = d.Balance.Data.DaySeconds
	t.test("abandoning an uncompleted match neither progresses quests nor resets a win streak", function()
		local data = Schema.new(100 * day)
		Rules.ensure(data, 100 * day)
		data.Stats.WinStreak, data.Stats.BestStreak = 4, 4
		for side = 1, 2 do
			t.eq(Rules.match(data, { Winner = 1 }, side, { Eligible = false, Perfects = 1 }, 100 * day), 0)
		end
		t.eq(data.Coins, 0)
		t.eq(data.Daily.Quests.perfects.Progress, 0)
		t.eq(data.Stats.WinStreak, 4)
	end)
	t.test("UTC rollover resets daily claims but preserves coins, codes and continuous streaks", function()
		local data = Schema.new(100 * day)
		Rules.ensure(data, 100 * day)
		data.Coins = 123
		data.CodesRedeemed.KEEP = true
		data.Daily.Quests.rounds.Progress = 3
		Rules.ensure(data, 100 * day + 99)
		t.eq(data.Daily.Streak, 1)
		t.eq(data.Daily.Quests.rounds.Progress, 3)
		Rules.ensure(data, 101 * day)
		t.eq(data.Daily.Streak, 2)
		t.eq(data.Daily.Quests.rounds.Progress, 0)
		t.eq(data.Coins, 123)
		t.eq(data.CodesRedeemed.KEEP, true)
		Rules.ensure(data, 103 * day)
		t.eq(data.Daily.Streak, 1)
		t.eq(data.Marbles, 0)
	end)
	t.test("observed matches progress quests and award first win only once; synthetic forfeits do not", function()
		local data = Schema.new(100 * day)
		Rules.match(data, { Winner = 1 }, 1, {}, 100 * day)
		t.eq(data.Coins, 0)
		local observed = { RoundWins = 2, Perfects = 2, HeavyShatters = 1 }
		Rules.match(data, { Winner = 1 }, 1, observed, 100 * day)
		t.eq(data.Coins, d.Balance.Economy.FirstWinOfDayCoins)
		Rules.match(data, { Winner = 1 }, 1, observed, 100 * day)
		t.eq(data.Coins, d.Balance.Economy.FirstWinOfDayCoins)
		t.eq(data.Daily.Quests.rounds.Progress, 3)
		t.eq(data.Stats.WinStreak, 2)
		t.eq(data.Stats.BestStreak, 2)
		Rules.match(data, { Winner = 2 }, 1, {}, 100 * day)
		t.eq(data.Stats.WinStreak, 0)
		t.eq(data.Stats.BestStreak, 2)
	end)
	t.test("daily quest claim rejects early and repeated grants", function()
		local data = Schema.new(100 * day)
		t.eq(Rules.claim(data, "Quest", "rounds", 100 * day), false)
		Rules.match(data, { Winner = 2 }, 1, { RoundWins = 3 }, 100 * day)
		t.eq(Rules.claim(data, "Quest", "rounds", 100 * day), true)
		t.eq(data.Coins, d.Balance.Economy.DailyQuestCoins)
		t.eq(Rules.claim(data, "Quest", "rounds", 100 * day), false)
		t.eq(data.Coins, d.Balance.Economy.DailyQuestCoins)
	end)
	t.test("playtime gift requires server time and resets once per UTC day", function()
		local data = Schema.new(100 * day)
		local gift = d.Balance.Economy.PlaytimeGifts[1]
		Rules.advance(data, gift.Minutes * 60 - 1, 100 * day)
		t.eq(Rules.claim(data, "Gift", 1, 100 * day), false)
		Rules.advance(data, 1, 100 * day)
		t.eq(Rules.claim(data, "Gift", 1, 100 * day), true)
		t.eq(data.Coins, gift.Coins)
		t.eq(Rules.claim(data, "Gift", 1, 100 * day), false)
		Rules.ensure(data, 101 * day)
		t.eq(data.Daily.PlaytimeSeconds, 0)
		t.eq(Rules.claim(data, "Gift", 1, 101 * day), false)
		Rules.advance(data, 0 / 0, 101 * day)
		t.eq(data.Daily.PlaytimeSeconds, 0)
	end)
	t.test("test code normalizes input, persists once and cannot grant in production", function()
		local data = Schema.new(0)
		t.eq(Rules.redeem(data, "STUDIOCLASH", false), false)
		t.eq(data.Coins, 0)
		t.eq(Rules.redeem(data, "  studioclash  ", true), true)
		t.eq(data.Coins, d.Balance.Economy.DailyQuestCoins)
		t.eq(Rules.redeem(data, "STUDIOCLASH", true), false)
		local reloaded = Schema.copy(data)
		Schema.reconcile(reloaded, 1)
		t.eq(Rules.redeem(reloaded, "STUDIOCLASH", true), false)
	end)
	t.test("malformed rewards, codes and premium reward paths grant nothing", function()
		local data = Schema.new(100 * day)
		for _, id in { 0, -1, 1.5, 0 / 0, math.huge, 999 } do
			t.eq(Rules.claim(data, "Gift", id, 100 * day), false)
		end
		t.eq(Rules.claim(data, "Marbles", "group", 100 * day), false)
		t.eq(Rules.claim(data, "Quest", {}, 100 * day), false)
		t.eq(Rules.redeem(data, {}, true), false)
		t.eq(Rules.redeem(data, string.rep("x", 33), true), false)
		t.eq(data.Coins, 0)
		t.eq(data.Marbles, 0)
		t.eq(Rules.view(data, 100 * day, false).FreeMarbles, false)
	end)
	t.test(
		"daily calendar: one claim per UTC day, a missed day keeps your place, Day 7 gives a free Kiln pull",
		function()
			local data = Schema.new(100 * day)
			local rewards = d.Balance.Economy.DailyRewards
			t.eq(Rules.calendar(data, 100 * day).Next, 1)
			t.eq(Rules.claim(data, "Daily", nil, 100 * day), true)
			t.eq(data.Coins, rewards[1].Coins)
			t.eq(Rules.claim(data, "Daily", nil, 100 * day + 3600), false)
			t.eq(Rules.calendar(data, 100 * day).Count, 1)
			t.eq(Rules.claim(data, "Daily", nil, 101 * day), true)
			-- three days away: no reset, the next claim is Day 3
			t.eq(Rules.calendar(data, 105 * day).Count, 2)
			t.eq(Rules.calendar(data, 105 * day).Next, 3)
			for offset = 5, 9 do
				t.eq(Rules.claim(data, "Daily", nil, (100 + offset) * day), true)
			end
			t.eq(data.Calendar.Index, 7)
			t.eq(data.FreePulls.Glassies, 1)
			local total = 0
			for _, r in rewards do
				total += r.Coins or 0
			end
			t.eq(data.Coins, total)
			t.eq(Rules.calendar(data, 109 * day).Count, 7)
			-- the next day starts a new week at Day 1
			t.eq(Rules.calendar(data, 110 * day).Count, 0)
			t.eq(Rules.calendar(data, 110 * day).Next, 1)
			t.eq(Rules.claim(data, "Daily", nil, 110 * day), true)
			t.eq(data.Calendar.Index, 1)
		end
	)
	t.test("playtime gifts: five steps to 60 min; the 60 min prize rotates Kiln, Finisher, Flyer by day", function()
		local gifts = d.Balance.Economy.PlaytimeGifts
		t.eq(#gifts, 5)
		t.eq(gifts[#gifts].Minutes, 60)
		local seen = {}
		for offset = 0, 2 do
			local now = (200 + offset) * day
			local data = Schema.new(now)
			Rules.advance(data, 60 * 60, now)
			t.eq(Rules.claim(data, "Gift", #gifts, now), true)
			local reward = Rules.view(data, now, false).Gifts[#gifts].Reward
			t.eq(data.FreePulls[reward.Pull], 1)
			seen[reward.Pull] = true
		end
		t.eq(seen.Glassies and seen.Finishers and seen.Rideables, true)
	end)
	t.test("codes: launch codes, every reward kind, expiry and Studio-only codes", function()
		local live = Schema.new(0)
		t.eq(Rules.redeem(live, "release", false, 1792000000), true)
		t.eq(live.Coins, 300)
		t.eq(Rules.redeem(live, "RELEASE", false, 1792000000), false)
		t.eq(Rules.redeem(live, "Halloween", false, 1792000000), true)
		t.eq(live.FreePulls.Finishers, 1)
		t.eq(Rules.redeem(Schema.new(0), "HALLOWEEN", false, 1794096000), false) -- expired Nov 8
		t.eq(Rules.redeem(live, "TESTMARBLES", false, 1792000000), false) -- Studio only
		t.eq(Rules.redeem(live, "NOTACODE", false, 1792000000), false)
		local studio = Schema.new(0)
		t.eq(Rules.redeem(studio, "TESTMARBLES", true, 1792000000), true)
		t.eq(studio.Marbles, 10)
		t.eq(Rules.redeem(studio, "TESTKILN", true, 1792000000), true)
		t.eq(Rules.redeem(studio, "TESTFLYER", true, 1792000000), true)
		t.eq(studio.FreePulls.Glassies, 1)
		t.eq(studio.FreePulls.Rideables, 1)
		t.eq(Rules.redeem(studio, "TESTITEM", true, 1792000000), true)
		t.eq(table.find(studio.Cosmetics.Finishers, "frost_pop") ~= nil, true)
		t.eq(Rules.redeem(studio, "TESTEXPIRED", true, 1792000000), false)
		t.eq(studio.Coins, 0)
	end)
	t.test("reward bundles reject malformed or dormant rewards", function()
		local Grant = if script
			then require(game.ServerScriptService.Server.Data.RewardGrant)
			else require("../server/Data/RewardGrant")
		for _, bad in
			{
				{},
				{ Coins = 0 },
				{ Coins = -5 },
				{ Coins = 1.5 },
				{ Coins = 0 / 0 },
				{ Pull = "Robux" },
				{ Pulls = 2 },
				{ Item = { Category = "Glassies", Id = "perfume" } },
				{ Item = { Category = "Finishers", Id = "nope" } },
				{ Gems = 5 },
			}
		do
			t.eq(Grant.valid(bad), false)
		end
		t.eq(Grant.valid({ Coins = 300 }), true)
		t.eq(Grant.valid({ Pull = "Finishers", Pulls = 2 }), true)
		t.eq(Grant.valid({ Item = { Category = "Glassies", Id = "fishbowl" } }), true)
		t.eq(Grant.describe({ Coins = 250, Pull = "Glassies" }), "+250 coins and a free Kiln pull")
	end)
	t.test("old profiles gain the calendar and free pull tickets", function()
		local old = Schema.new(0)
		old.Calendar, old.FreePulls = nil, nil
		Schema.reconcile(old, 1)
		t.eq(old.Calendar.Index, 0)
		t.eq(old.FreePulls.Finishers, 0)
	end)
end
