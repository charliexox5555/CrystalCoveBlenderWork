local R = if script then require(game.ReplicatedStorage.Shared.CrateRules) else require("../shared/CrateRules")
local C = if script
	then require(game.ReplicatedStorage.Shared.Config.RoundCosmetics)
	else require("../shared/Config/RoundCosmetics")
local O = if script
	then require(game.ReplicatedStorage.Shared.RoundCosmeticRules)
	else require("../shared/RoundCosmeticRules")
local Schema = if script
	then require(game.ServerScriptService.Server.Data.ProfileSchema)
	else require("../server/Data/ProfileSchema")
return function(t)
	t.test("both cosmetic currencies expose identical complete pools with normalized exact odds", function()
		for _, category in { "Finishers", "Rideables" } do
			local coins, marbles = R.odds(category, "Coins"), R.odds(category, "Marbles")
			t.eq(#coins, #C[category])
			t.eq(#marbles, #coins)
			local a, b = 0, 0
			for i, entry in coins do
				t.eq(entry.Id, marbles[i].Id)
				t.ok(entry.Chance > 0 and marbles[i].Chance > 0)
				a += entry.Chance
				b += marbles[i].Chance
			end
			t.ok(math.abs(a - 1) < 0.000001 and math.abs(b - 1) < 0.000001)
			for first = 2, #coins do
				local ca, ma = 0, 0
				for i = first, #coins do
					ca += coins[i].Chance
					ma += marbles[i].Chance
				end
				t.ok(ma > ca, "Marbles improve high-rarity tails")
			end
		end
	end)
	t.test("missing artwork cannot be rolled and probabilities renormalize", function()
		local odds = R.odds("Finishers", "Marbles", { glass_burst = true, starfall = true })
		t.eq(#odds, 2)
		t.ok(math.abs(odds[1].Chance + odds[2].Chance - 1) < 0.000001)
		t.eq(#R.odds("Finishers", "Coins", {}), 0)
	end)
	t.test("approved cosmetic prices and legacy glassy discount remain correct", function()
		t.eq(R.cost("Finishers", "Coins", 1), 300)
		t.eq(R.cost("Finishers", "Marbles", 10), 300)
		t.eq(R.cost("Rideables", "Coins", 10), 10000)
		t.eq(R.cost("Rideables", "Marbles", 1), 100)
		t.eq(R.cost("Glassies", "Coins", 10), 2700)
		t.eq(R.cost("Finishers", "Robux", 1), nil)
		t.eq(R.cost("Bad", "Coins", 1), nil)
		t.eq(R.cost("Finishers", "Coins", 2), nil)
	end)
	t.test("old ownership migrates to counts, duplicates accumulate and snapshots stay independent", function()
		local data = Schema.new(1)
		table.insert(data.Cosmetics.Rideables, "rocket_skiff")
		O.reconcile(data)
		t.eq(O.count(data, "Rideables", "rocket_skiff"), 1)
		local reward = O.grant(data, "Rideables", "rocket_skiff")
		t.eq(reward.Count, 2)
		t.eq(reward.Duplicate, true)
		local fresh = O.grant(data, "Finishers", "starfall")
		t.eq(fresh.Count, 1)
		t.eq(fresh.Duplicate, false)
		local snapshot = Schema.snapshot(data)
		snapshot.Cosmetics.Counts.Rideables.rocket_skiff = 999
		t.eq(O.count(data, "Rideables", "rocket_skiff"), 2)
		Schema.reconcile(data, 2)
		t.eq(O.count(data, "Rideables", "rocket_skiff"), 2)
	end)
	t.test("selection follows quoted probabilities at boundaries", function()
		local odds = { { Id = "a", Chance = 0.75 }, { Id = "b", Chance = 0.25 } }
		t.eq(
			R.roll(odds, function()
				return 0
			end),
			"a"
		)
		t.eq(
			R.roll(odds, function()
				return 0.749
			end),
			"a"
		)
		t.eq(
			R.roll(odds, function()
				return 0.75
			end),
			"b"
		)
		t.eq(
			R.roll(odds, function()
				return 1
			end),
			"b"
		)
	end)
end
