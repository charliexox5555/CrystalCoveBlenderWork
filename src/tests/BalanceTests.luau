-- Balance targets (GAME_DESIGN 3.7). Uses the FightModel stand-in for the swing, so these check
-- the RULES; re-check them in Studio once the real swing exists (see Balance.SimModel).

return function(t, deps)
	-- Preserve the legacy-model regression gates. That stand-in has no range, moving targets or
	-- swept attacks; release geometry/rounds are validated separately by ReleaseKitTests/report.
	local releaseEnabled = deps.Balance.CombatRelease.Enabled
	deps.Balance.CombatRelease.Enabled = false
	local Glassies = deps.Glassies
	local BalanceSim = if script then require(script.Parent.BalanceSim) else require("./BalanceSim")
	local N = 120

	t.test("mirror rounds last 15-45 s with 6-40 hits and almost no timeouts", function()
		for _, id in { "pop", "jam", "prism", "milk_bottle", "glass_dragon", "glass_sword" } do
			local r = BalanceSim.matchup(id, id, N)
			t.between(r.Seconds, 15, 45, id .. " round seconds")
			t.between(r.Hits, 6, 40, id .. " hits")
			t.ok(r.Timeouts < 0.05, id .. " timeouts " .. r.Timeouts)
		end
	end)

	t.test("no side bias", function()
		t.between(BalanceSim.sideBias("pop", 300), 0.42, 0.58, "side 1 win rate")
	end)

	t.test("starter type triangle: each starter beats one and loses to one", function()
		t.between(BalanceSim.matchup("pop", "jam", N).WinRate, 0.52, 0.85, "pop > jam")
		t.between(BalanceSim.matchup("jam", "prism", N).WinRate, 0.52, 0.9, "jam > prism")
		t.between(BalanceSim.matchup("prism", "pop", N).WinRate, 0.5, 0.85, "prism > pop")
	end)

	t.test("aim matters but doesn't decide everything", function()
		t.between(
			BalanceSim.matchup("pop", "pop", N * 2, { AimA = "perfect", AimB = "worst" }).WinRate,
			0.53,
			0.75,
			"perfect vs worst"
		)
	end)

	t.test("luck keeps it exciting: comebacks, lead changes, misses", function()
		local luck = BalanceSim.suspense(20)
		t.between(luck.Comebacks, 0.35, 0.8, "winner was behind at some point")
		t.ok(luck.LeadChanges >= 1, "the lead changes at least once a round on average")
		t.between(luck.Powers, 1.2, 3, "powers per glassy per round")
		t.between(luck.PowerMisses, 0.2, 0.5, "aimed powers miss sometimes")
	end)

	t.test("rarity and stars help without deciding the fight", function()
		local mythic = BalanceSim.matchup("galaxy_orb", "lemonade_bottle", N).WinRate -- both Fizzy
		t.between(mythic, 0.6, 0.95, "Mythic vs Common")
		t.between(BalanceSim.matchup("pop", "pop", N, { StarsA = 5 }).WinRate, 0.6, 0.98, "5 stars vs 0")
	end)

	t.test("every glassy is fair at equal stats (40-60% vs the field)", function()
		local rows = BalanceSim.powerTable(10)
		t.eq(#rows, #Glassies.ReleaseList, "all 24 release glassies rated")
		for _, row in rows do
			t.between(row.WinRate, 0.38, 0.62, row.Id .. " win rate vs the field")
		end
	end)
	deps.Balance.CombatRelease.Enabled = releaseEnabled
end
