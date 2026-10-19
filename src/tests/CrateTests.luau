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
	t.test("Marble crates hold every cosmetic; Coin crates every rarity with a Coin weight (decision 95)", function()
		local B = require(if script then game.ReplicatedStorage.Shared.Config.Balance else "../shared/Config/Balance")
		for _, category in { "Finishers", "Rideables" } do
			local coins, marbles = R.odds(category, "Coins"), R.odds(category, "Marbles")
			t.eq(#marbles, #C[category], category .. " Marble pool is complete")
			local inMarbles, a, b, expected = {}, 0, 0, 0
			for _, entry in marbles do
				t.ok(entry.Chance > 0)
				inMarbles[entry.Id] = true
				b += entry.Chance
			end
			for _, def in C[category] do
				if (B.Crates.CoinWeights[def.Rarity] or 0) > 0 then
					expected += 1
				end
			end
			t.eq(#coins, expected, category .. " Coin pool = items whose rarity has a Coin weight")
			for _, entry in coins do
				t.ok(entry.Chance > 0 and inMarbles[entry.Id], entry.Id)
				a += entry.Chance
			end
			t.ok(math.abs(a - 1) < 0.000001 and math.abs(b - 1) < 0.000001)
			-- Marbles improve every high-rarity tail: P(rarity >= r) is higher for each r above Common.
			for _, r in { "Uncommon", "Rare", "Epic", "Legendary" } do
				local floor, ca, ma = B.Rarities[r].Order, 0, 0
				for _, e in coins do
					ca += if B.Rarities[e.Rarity].Order >= floor then e.Chance else 0
				end
				for _, e in marbles do
					ma += if B.Rarities[e.Rarity].Order >= floor then e.Chance else 0
				end
				if ma > 0 then
					t.ok(ma > ca, category .. " Marbles improve the " .. r .. "+ tail")
				end
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
