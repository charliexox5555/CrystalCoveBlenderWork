local Rules = if script
	then require(game.ReplicatedStorage.Shared.GauntletRules)
	else require("../shared/GauntletRules")
local G = if script
	then require(game.ReplicatedStorage.Shared.Config.Gauntlet)
	else require("../shared/Config/Gauntlet")
local Session = if script
	then require(game.ServerScriptService.Server.Dev.LoopLab.Session)
	else require("../server/Dev/LoopLab/Session")

return function(t, d)
	t.test("first run opens on an easy earnable rival", function()
		local c = Rules.newCollection()
		local run = Rules.newRun(c, 1)
		t.eq(run.Rival, G.FirstRival)
		t.ok(c.Owned[G.Starter], "starts owning the starter")
		t.ok(Rules.rivalHpScale(c, run, G.Starter) < 0.5, "first duel breaks fast")
	end)

	t.test("winning collects shards until the rival unlocks", function()
		local c = Rules.newCollection()
		local run = Rules.newRun(c, 1)
		local first = Rules.applyResult(c, run, true)
		t.eq(first.Shards, 1)
		t.eq(first.Progress, 1)
		t.eq(first.Unlocked, nil)
		t.eq(run.Rival, G.FirstRival, "rung 2 chases the closest unlock")
		local second = Rules.applyResult(c, run, true)
		t.eq(second.Unlocked, G.FirstRival)
		t.ok(c.Owned[G.FirstRival], "owned after enough shards")
		t.eq(c.Shards[G.FirstRival], nil, "shards are spent")
		t.ok(run.Rival ~= G.FirstRival, "the next rival is one you can still earn")
		t.eq(run.Unlocked[1], G.FirstRival)
	end)

	t.test("rivals are always earnable until the roster is complete", function()
		local c = Rules.newCollection()
		local run = Rules.newRun(c, 7)
		for _ = 1, 40 do
			if #Rules.locked(c) > 0 then
				t.ok(not c.Owned[run.Rival], "rival is still locked")
			end
			Rules.applyResult(c, run, true)
		end
		t.eq(#Rules.locked(c), 0, "forty wins finish the slice roster")
		t.ok(table.find(G.Roster, run.Rival) ~= nil, "rivals keep coming after that")
	end)

	t.test("a loss costs a heart and rematches the same rival", function()
		local c = Rules.newCollection()
		local run = Rules.newRun(c, 1)
		local rival = run.Rival
		local loss = Rules.applyResult(c, run, false)
		t.eq(loss.Hearts, G.Hearts - 1)
		t.eq(run.Rival, rival)
		t.eq(run.Rung, 1)
		t.ok(not run.Over)
		Rules.applyResult(c, run, false)
		local final = Rules.applyResult(c, run, false)
		t.ok(final.Over and run.Over, "no hearts ends the run")
		t.ok(not pcall(Rules.applyResult, c, run, true), "an ended run takes no results")
	end)

	t.test("collection and best survive across runs", function()
		local c = Rules.newCollection()
		local run = Rules.newRun(c, 3)
		for _ = 1, 4 do
			Rules.applyResult(c, run, true)
		end
		for _ = 1, G.Hearts do
			Rules.applyResult(c, run, false)
		end
		t.eq(c.Best, 4)
		t.ok(c.Coins > 0)
		local again = Rules.newRun(c, 4)
		t.eq(again.Hearts, G.Hearts)
		t.eq(again.Rung, 1)
		t.ok(c.Owned[G.FirstRival], "unlocks are kept")
		t.ok(
			Rules.rivalHpScale(c, again, G.Starter) >= G.RivalHp * G.CounterHp,
			"only the first ever duel is the easy one"
		)
	end)

	t.test("bosses pay double and counters soften the rival", function()
		local c = Rules.newCollection()
		local run = Rules.newRun(c, 2)
		c.Runs = 2
		run.Rung, run.Rival = G.BossEvery, "jam"
		t.ok(Rules.isCounter("pop", "jam"), "Fizzy beats Heavy")
		t.ok(not Rules.isCounter("prism", "jam"), "Sharp does not")
		t.ok(Rules.rivalHpScale(c, run, "pop") < Rules.rivalHpScale(c, run, "prism"))
		local boss = Rules.applyResult(c, run, true)
		t.eq(boss.Shards, G.BossShards)
	end)

	t.test("gauntlet duels resolve on the real swing with v5 radii and scaled HP", function()
		local s = Session.new("B", "pop", 311102, 0, {
			Rival = "glass_cup",
			HookGap = G.HookGap,
			PlayerHp = G.PlayerHp,
			RivalHp = G.FirstDuelHp,
			Radius = G.Radius,
		})
		local fighters = s.Sim.Fight.Fighters
		t.eq(s.Rival, "glass_cup")
		t.eq(fighters[1].Radius, G.Radius.pop)
		t.ok(fighters[2].MaxHp < fighters[1].MaxHp, "the first rival is fragile")
		s:launch(d.Balance.Motion.AimDefault, 0, 0)
		local now = 0
		while s.Phase ~= "Result" and now < 30 do
			now += 1 / 60
			s:step(1 / 60, now)
		end
		t.eq(s.Phase, "Result")
		t.ok(s.Reason ~= "Timeout", "no stall on the opening duel")
		t.ok(now < 12, "first shatter lands quickly: " .. now)
		local packet = s:packet()
		t.eq(packet.MaxHp[2], fighters[2].MaxHp, "client bars use the scaled HP")
	end)
end
