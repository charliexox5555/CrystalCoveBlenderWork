local Shared = if script then game.ReplicatedStorage.Shared else nil
local Rules = if Shared then require(Shared.RoundCosmeticRules) else require("../shared/RoundCosmeticRules")
local Schema = if script
	then require(game.ServerScriptService.Server.Data.ProfileSchema)
	else require("../server/Data/ProfileSchema")
return function(t)
	t.test("new and legacy profiles own only free starter round cosmetics", function()
		local data = Schema.new(1)
		t.eq(data.Cosmetics.EquippedRideables, "skyboard")
		t.eq(data.Cosmetics.EquippedFinishers, "glass_burst")
		t.eq(#data.Cosmetics.Rideables, 1)
		t.eq(#data.Cosmetics.Finishers, 1)
		data.Cosmetics = { ShatterFx = { "default", "confetti" }, EquippedShatterFx = "confetti", Fills = { "soda" } }
		Schema.reconcile(data, 2)
		t.eq(data.Cosmetics.EquippedShatterFx, "confetti")
		t.eq(data.Cosmetics.Fills[1], "soda")
		t.eq(data.Cosmetics.EquippedRideables, "skyboard")
	end)
	t.test("completed matches no longer auto grant crate cosmetics and existing items stay owned", function()
		local data = Schema.new(0)
		Schema.recordMatch(
			data,
			"abandon",
			{ Over = true, Winner = 1 },
			1,
			{ Coins = 0, Trophies = 0 },
			{ Eligible = false }
		)
		t.eq(#data.Cosmetics.Rideables, 1)
		Schema.recordMatch(
			data,
			"done",
			{ Over = true, Winner = 2 },
			1,
			{ Coins = 0, Trophies = 0 },
			{ Eligible = true }
		)
		t.eq(data.Stats.MatchLosses, 1)
		t.eq(table.find(data.Cosmetics.Rideables, "cloud_cushion"), nil)
		t.eq(table.find(data.Cosmetics.Finishers, "party_burst"), nil)
		Schema.recordMatch(
			data,
			"done",
			{ Over = true, Winner = 2 },
			1,
			{ Coins = 0, Trophies = 0 },
			{ Eligible = true }
		)
		t.eq(Rules.matches(data), 1)
		data.Stats.MatchWins = 9
		Rules.reconcile(data)
		t.eq(#data.Cosmetics.Rideables, 1)
		t.eq(#data.Cosmetics.Finishers, 1)
		table.insert(data.Cosmetics.Finishers, "party_burst")
		Rules.reconcile(data)
		t.eq(Rules.count(data, "Finishers", "party_burst"), 1)
	end)
	t.test("equipping validates category identity ownership and does not spend currency", function()
		local data = Schema.new(0)
		data.Coins, data.Marbles = 555, 4
		for _, args in
			{
				{ "Rideables", "rocket_skiff" },
				{ "Finishers", "prism_ray" },
				{ "Glassies", "pop" },
				{ "Rideables", {} },
				{ false, "skyboard" },
				{ "Rideables", string.rep("a", 100) },
			}
		do
			t.eq(Rules.equip(data, args[1], args[2]), false)
		end
		t.eq(Rules.equip(data, "Rideables", "skyboard"), true)
		data.Stats.MatchWins = 5
		Rules.grant(data, "Rideables", "rocket_skiff")
		t.eq(Rules.equip(data, "Rideables", "rocket_skiff"), true)
		t.eq(data.Cosmetics.EquippedRideables, "rocket_skiff")
		t.eq(data.Coins, 555)
		t.eq(data.Marbles, 4)
	end)
	t.test("round cosmetic snapshots do not alias saved ownership and repair invalid equipment", function()
		local data = Schema.new(0)
		data.Cosmetics.EquippedFinishers = "starfall"
		Rules.reconcile(data)
		t.eq(data.Cosmetics.EquippedFinishers, "glass_burst")
		local snapshot = Schema.snapshot(data)
		table.insert(snapshot.Cosmetics.Finishers, "starfall")
		t.eq(#data.Cosmetics.Finishers, 1)
		t.eq(snapshot.Cosmetics.EquippedRideables, "skyboard")
	end)
end
