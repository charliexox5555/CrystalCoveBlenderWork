local Schema = if script
	then require(game.ServerScriptService.Server.Data.ProfileSchema)
	else require("../server/Data/ProfileSchema")

return function(t, d)
	t.test("Marble debits reject invalid costs and insufficient funds", function()
		local data = Schema.new(0)
		data.Marbles = 9
		for _, cost in { -1, 0.5, math.huge, 0 / 0, "3", 10 } do
			t.eq(Schema.spendMarbles(data, cost), false)
			t.eq(data.Marbles, 9)
		end
		t.eq(Schema.spendMarbles(data, 3), true)
		t.eq(data.Marbles, 6)
		t.eq(Schema.snapshot(data).Marbles, 6)
	end)
	t.test("no-contest settlement is idempotent and cannot unlock progress or welcome pulls", function()
		for side = 1, 2 do
			local data = Schema.new(0)
			local match = { Over = true, Winner = 1 }
			local observed = { Eligible = false, Perfects = 1, Used = { pop = true } }
			t.eq(Schema.recordMatch(data, "abandon", match, side, { Coins = 90, Trophies = 20 }, observed), true)
			t.eq(Schema.recordMatch(data, "abandon", match, side, { Coins = 90, Trophies = 20 }, {}), false)
			t.eq(data.Coins, 0)
			t.eq(data.Trophies, 0)
			t.eq(data.Stats.MatchWins + data.Stats.MatchLosses + data.Stats.Perfects, 0)
			t.eq(data.Stats.GlassyUses.pop, nil)
			t.eq(Schema.welcomePulls(data), 0)
		end
	end)
	t.test("new profiles own three starters and snapshots omit private bookkeeping", function()
		local data = Schema.new(123)
		for _, id in d.Glassies.Starters do
			t.eq(data.Glassies[id].Count, 1)
			t.eq(data.Glassies[id].Stars, 0)
		end
		t.eq(Schema.welcomePulls(data), 0)
		local snapshot = Schema.snapshot(data)
		t.eq(snapshot.ProcessedReceipts, nil)
		t.eq(snapshot.RecentMatches, nil)
		t.eq(snapshot.Marbles, 0)
		snapshot.Coins = 999
		t.eq(data.Coins, 0, "snapshot cannot mutate server data")
	end)
	t.test("duplicate copies reach five stars then overflow at the configured coin amount", function()
		local data = Schema.new(0)
		for _ = 1, 5 do
			Schema.grant(data, "pop", false, 1)
		end
		t.eq(data.Glassies.pop.Stars, 5)
		t.eq(data.Coins, 0)
		local result = Schema.grant(data, "pop", true, 2)
		t.eq(result.BonusCoins, d.Balance.Growth.DuplicateCoinsAtMaxStars)
		t.eq(data.Glassies.pop.Rainbow, true)
		Schema.grant(data, "pop", false, 3)
		t.eq(data.Glassies.pop.Rainbow, true)
	end)
	t.test("match rewards apply once and grant only the observed fight stats", function()
		local data = Schema.new(0)
		local m = d.MatchLogic.new({ { Collection = {} }, { Collection = {}, IsBot = true } }, d.Rng.new(4))
		for _ = 1, 3 do
			d.MatchLogic.startRound(m)
			d.MatchLogic.endRound(m, 1)
		end
		local reward = d.MatchLogic.rewards(m, 1, 0)
		t.eq(
			Schema.recordMatch(
				data,
				"one",
				m,
				1,
				reward,
				{ Perfects = 2, RoundWins = 2, Shatters = 2, Used = { pop = true } }
			),
			true
		)
		t.eq(Schema.recordMatch(data, "one", m, 1, reward, {}), false)
		t.eq(data.Coins, reward.Coins)
		t.eq(data.Trophies, reward.Trophies)
		t.eq(data.Stats.MatchWins, 1)
		t.eq(data.Stats.RoundWins, 2)
		t.eq(data.Stats.Shatters, 2)
		t.eq(data.Stats.GlassyUses.pop, 1)
		t.eq(Schema.welcomePulls(data), 1)
		data.Flags.WelcomePullUsed = true
		t.eq(Schema.welcomePulls(data), 0)
	end)
	t.test("reconciliation preserves progress and legacy stars while filling the schema", function()
		local data = { Coins = 42, Glassies = { pop = { Stars = 3 } }, Custom = { Keep = true } }
		Schema.reconcile(data, 100)
		t.eq(data.Coins, 42)
		t.eq(data.Glassies.pop.Count, 4)
		t.eq(data.Glassies.pop.Stars, 3)
		t.eq(data.Custom.Keep, true)
		t.eq(data.Glassies.jam.Count, 1)
		local corrupt = { Coins = 0 / 0, Stats = "bad", Glassies = { pop = "bad" } }
		Schema.reconcile(corrupt, 200)
		t.eq(corrupt.Coins, 0)
		t.eq(corrupt.Glassies.pop.Count, 1)
	end)
	t.test("available Kiln pools normalize displayed odds and never roll missing art", function()
		local available = { milk_bottle = true, pickle_jar = true, hot_sauce = true }
		local total = 0
		for _, entry in d.Formula.kilnOdds(available) do
			total += entry.Chance
			t.ok(available[entry.Id])
		end
		t.near(total, 1, 0.000001)
		local rng = d.Rng.new(22)
		for _ = 1, 200 do
			t.ok(available[d.Formula.rollKiln(rng, available)])
		end
		t.eq(#d.Formula.kilnOdds({ pop = true, jam = true, prism = true }), 0)
		local ok = pcall(function()
			d.Formula.rollKiln(rng, {})
		end)
		t.eq(ok, false)
	end)
end
