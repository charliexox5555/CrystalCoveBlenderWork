-- Player levels (LevelRules, decision 104) and their profile fields.
local Levels = if script then require(game.ReplicatedStorage.Shared.LevelRules) else require("../shared/LevelRules")
local Schema = if script
	then require(game.ServerScriptService.Server.Data.ProfileSchema)
	else require("../server/Data/ProfileSchema")

return function(t, d)
	local L = d.Balance.Levels

	t.test("levels: XP per match follows Balance.Levels", function()
		t.eq(Levels.matchXp({ Won = true, RoundsWon = 3, Perfects = 1 }), L.WinXp + 3 * L.RoundWonXp + L.PerfectXp)
		t.eq(Levels.matchXp({ Won = false, RoundsWon = 1 }), L.LossXp + L.RoundWonXp)
		t.eq(
			Levels.matchXp({ Won = true, RoundsWon = 3, VsBot = true }),
			math.floor((L.WinXp + 3 * L.RoundWonXp) * L.BotScale + 0.5)
		)
		t.eq(Levels.matchXp({ Won = false, RoundsWon = 2, Forfeited = true }), 0)
		-- Junk counts are ignored rather than trusted.
		t.eq(Levels.matchXp({ Won = false, RoundsWon = -4 :: any, Perfects = 0 / 0 }), L.LossXp)
	end)

	t.test("levels: the curve is exact at every level boundary", function()
		t.eq(Levels.totalFor(1), 0)
		t.eq(Levels.totalFor(2), L.BaseXp)
		for level = 1, 400 do
			local start = Levels.totalFor(level)
			local view = Levels.view(start)
			t.eq(view.Level, level, "start of level " .. level)
			t.eq(view.Xp, 0)
			t.eq(view.XpNext, Levels.need(level))
			if level > 1 then
				local before = Levels.view(start - 1)
				t.eq(before.Level, level - 1, "just before level " .. level)
				t.eq(before.Xp, Levels.need(level - 1) - 1)
			end
		end
		t.eq(Levels.view(nil).Level, 1)
		t.eq(Levels.view(-50).Total, 0)
		t.eq(Levels.view(0 / 0).Level, 1)
	end)

	t.test("levels: pacing matches the creator's targets", function()
		-- Two normal three-round bot wins reach Lv 2; the introductory bot duel is one round.
		local botWin = Levels.matchXp({ Won = true, RoundsWon = 3, VsBot = true })
		t.eq(Levels.level(botWin), 1)
		t.eq(Levels.level(2 * botWin), 2)
		-- The economy model's player (Balance.EconomyModel): about Lv 5 after the first session, Lv 10 after about 2.4 hours of
		-- matches, and still climbing at day 30.
		local Sim = if script then require(script.Parent.EconomySim) else require("./EconomySim")
		local pace = Sim.levels()
		t.between(pace.Day1, 4, 5, "level after day 1")
		t.between(
			pace.ToLv10 * Sim.matchSeconds() / 60,
			90,
			160,
			"minutes to Lv 10; shorter matches preserve time pacing"
		)
		t.ok(pace["Day" .. d.Balance.EconomyModel.Days] > pace.Day7, "still climbing")
		-- No cap, and each level keeps getting a little longer.
		t.ok(Levels.need(60) > Levels.need(59))
		t.eq(Levels.level(Levels.totalFor(500)), 500)
	end)

	t.test("levels: adding XP reports levels gained", function()
		local total, gained = Levels.add(0, L.BaseXp - 1)
		t.eq(total, L.BaseXp - 1)
		t.eq(gained, 0)
		total, gained = Levels.add(total, Levels.need(1) + Levels.need(2))
		t.eq(gained, 2)
		t.eq(Levels.level(total), 3)
	end)

	t.test("levels: profiles start at Lv 1 and old profiles get 0 XP", function()
		local data = Schema.new(0)
		t.eq(data.Xp, 0)
		t.eq(Schema.snapshot(data).Level.Level, 1)
		local old = Schema.new(0)
		old.Xp = nil
		old.Stats.MatchWins = 40 -- no back-fill from past wins
		Schema.reconcile(old, 0)
		t.eq(old.Xp, 0)
		old.Xp = 12.7
		Schema.reconcile(old, 0)
		t.eq(old.Xp, 12)
	end)

	t.test("levels: a recorded match grants XP once; a no-contest grants none", function()
		local data = Schema.new(0)
		local match = { Over = true, Winner = 1 }
		local observed = { Eligible = true, RoundWins = 3, Perfects = 1, VsBot = false }
		t.eq(Schema.recordMatch(data, "m1", match, 1, { Coins = 0, Trophies = 0 }, observed), true)
		local expected = Levels.matchXp({ Won = true, RoundsWon = 3, Perfects = 1 })
		t.eq(data.Xp, expected)
		t.eq(observed.XpGained, expected)
		t.eq(observed.LevelsGained, Levels.level(expected) - 1)
		t.eq(Schema.recordMatch(data, "m1", match, 1, { Coins = 0, Trophies = 0 }, { RoundWins = 3 }), false)
		t.eq(data.Xp, expected, "replayed match id")
		Schema.recordMatch(data, "m2", match, 2, { Coins = 0, Trophies = 0 }, { Eligible = false, RoundWins = 0 })
		t.eq(data.Xp, expected, "no contest")
		Schema.recordMatch(data, "m3", match, 2, { Coins = 0, Trophies = 0 }, { RoundWins = 2, Forfeited = true })
		t.eq(data.Xp, expected, "forfeit")
	end)

	t.test("levels: the public view shows level, stats and items but no currency", function()
		local data = Schema.new(0)
		data.Coins, data.Marbles, data.Xp = 500, 40, Levels.totalFor(7) + 3
		data.Stats.MatchWins, data.Stats.MatchLosses, data.Stats.BestStreak = 9, 3, 4
		Schema.grant(data, "pop", false, 0)
		local view = Schema.publicView(data)
		t.eq(view.Level.Level, 7)
		t.eq(view.Level.Xp, 3)
		t.eq(view.Stats.MatchWins, 9)
		t.eq(view.Stats.BestStreak, 4)
		t.eq(view.Glassies.pop.Count, 1)
		t.eq(view.Coins, nil)
		t.eq(view.Marbles, nil)
		t.eq(view.Stats.Shatters, nil)
		t.ok(type(view.Cosmetics.Finishers) == "table")
		-- A copy: changing the view never touches the profile.
		view.Glassies.pop.Count = 99
		t.eq(data.Glassies.pop.Count, 1)
	end)
end
