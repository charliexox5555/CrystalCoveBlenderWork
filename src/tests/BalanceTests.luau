-- Balance targets from GAME_DESIGN. If one fails after a tuning change, either fix the numbers
-- or (with the user's OK) update the target here and in GAME_DESIGN.

return function(t, deps)
	local Sim = if script then require(script.Parent.Sim) else require("./Sim")
	local Glassies, Trainers = deps.Glassies, deps.Trainers
	local RUNS = 1500

	t.test("even fights last 4-6.5 clashes and are fair", function()
		for _, id in Glassies.Starters do
			local r = Sim.match({ Id = id, Level = 10, Skill = 0.5 }, { Id = id, Level = 10, Skill = 0.5 }, RUNS, 101)
			t.between(r.AvgClashes, 4, 6.5, id .. " mirror length")
			t.between(r.WinRateA, 0.42, 0.58, id .. " mirror fairness")
		end
	end)

	t.test("type advantage matters but doesn't decide everything", function()
		-- Fizzy (pop) beats Heavy (jam); Heavy beats Sharp (prism); Sharp beats Fizzy
		for _, pair in { { "pop", "jam" }, { "jam", "prism" }, { "prism", "pop" } } do
			local r = Sim.match({ Id = pair[1], Level = 10, Skill = 0.5 }, { Id = pair[2], Level = 10, Skill = 0.5 }, RUNS, 202)
			t.between(r.WinRateA, 0.6, 0.9, pair[1] .. " vs " .. pair[2])
		end
	end)

	t.test("Zone 1 trainers are beatable at their level", function()
		for _, tr in Trainers.List do
			if tr.Zone == "recycling_yard" and not tr.IsBoss then
				for _, starter in Glassies.Starters do
					local r = Sim.match({ Id = starter, Level = tr.Level, Skill = 0.5 }, { Id = tr.Glassy, Level = tr.Level, Skill = tr.Skill }, RUNS, 303)
					t.ok(r.WinRateA >= 0.6, string.format("%s vs %s win rate %.2f", starter, tr.Id, r.WinRateA))
				end
			end
		end
	end)

	t.test("the Zone 1 boss is a real challenge but fair for every starter", function()
		-- Players reach Rusty at about the top of the zone's level range.
		local boss = Trainers.ById.rusty
		local playerLevel = deps.Zones.ById[boss.Zone].LevelRange[2]
		for _, starter in Glassies.Starters do
			local bossGlassy = Trainers.glassyFor(boss, Glassies.get(starter).Type)
			local r = Sim.match({ Id = starter, Level = playerLevel, Skill = 0.5 }, { Id = bossGlassy, Level = boss.Level, Skill = boss.Skill }, RUNS, 404)
			t.between(r.WinRateA, 0.3, 0.65, starter .. " vs Rusty's " .. bossGlassy)
		end
	end)

	t.test("rarity matters at equal level", function()
		local r = Sim.match({ Id = "galaxy_orb", Level = 20, Skill = 0.5 }, { Id = "milk_bottle", Level = 20, Skill = 0.5 }, RUNS, 505)
		t.ok(r.WinRateA >= 0.85, "Mythic beats Common")
	end)

	t.test("first evolution within ~30 minutes of wins", function()
		t.between(Sim.winsToLevel(15), 18, 35, "wins to level 15")
		t.ok(Sim.winsToLevel(35) <= 90, "wins to level 35")
	end)
end
