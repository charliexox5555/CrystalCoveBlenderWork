local Shared = if script then game.ReplicatedStorage.Shared else nil
local Rules = if Shared then require(Shared.RoundCosmeticRules) else require("../shared/RoundCosmeticRules")
local Schema = if script
	then require(game.ServerScriptService.Server.Data.ProfileSchema)
	else require("../server/Data/ProfileSchema")
return function(t)
	t.test("seasonal cosmetics persist ownership, validate equipment and preserve the base roster", function()
		local data = Schema.new(0)
		t.eq(data.Cosmetics.EquippedSkins, "")
		t.eq(#data.Cosmetics.Skins, 0)
		for category, id in { Skins = "hollowlight", Rideables = "lantern_skiff", Finishers = "lantern_eclipse" } do
			t.eq(Rules.equip(data, category, id), false)
			Rules.grant(data, category, id)
			t.eq(Rules.equip(data, category, id), true)
		end
		local frozen = Rules.loadout(data)
		t.eq(frozen.Skins, "hollowlight")
		local saved = Schema.copy(data)
		Schema.reconcile(saved, 1)
		t.eq(saved.Cosmetics.EquippedSkins, "hollowlight")
		t.eq(saved.Cosmetics.Counts.Finishers.lantern_eclipse, 1)
		t.eq(Rules.equip(data, "Skins", ""), true)
		t.eq(data.Cosmetics.EquippedSkins, "")
		t.eq(frozen.Skins, "hollowlight", "current match stays frozen")
		t.eq(Rules.equip(data, "Finishers", "hollowlight"), false)
		data.Glassies.pop = nil
		t.eq(Rules.equip(data, "Skins", "hollowlight"), false)
		t.eq(data.Coins, 0)
		t.eq(data.Marbles, 0)
		t.eq(data.Glassies.hollowlight, nil, "a skin never adds a combat glassy")
	end)
	t.test("seasonal looks never enter ordinary paid or coin crate pools", function()
		local Crates = if script
			then require(game.ReplicatedStorage.Shared.CrateRules)
			else require("../shared/CrateRules")
		for _, category in { "Rideables", "Finishers" } do
			for _, currency in { "Coins", "Marbles" } do
				for _, entry in Crates.odds(category, currency) do
					t.ok(entry.Id ~= "lantern_skiff" and entry.Id ~= "lantern_eclipse")
				end
			end
		end
		t.eq(#Crates.odds("Skins", "Marbles"), 0)
	end)
	t.test("seasonal legacy profiles repair malformed counts without granting free items", function()
		local data = Schema.new(0)
		data.Cosmetics.Skins = { "hollowlight" }
		data.Cosmetics.Counts.Skins.hollowlight = 0 / 0
		data.Cosmetics.EquippedSkins = "hollowlight"
		Schema.reconcile(data, 1)
		t.eq(data.Cosmetics.Counts.Skins.hollowlight, 1)
		local other = Schema.new(0)
		other.Cosmetics.Skins = false
		other.Cosmetics.Counts.Skins = "bad"
		other.Cosmetics.EquippedSkins = "hollowlight"
		Schema.reconcile(other, 1)
		t.eq(other.Cosmetics.EquippedSkins, "")
		t.eq(Rules.count(other, "Skins", "hollowlight"), 0)
	end)
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
