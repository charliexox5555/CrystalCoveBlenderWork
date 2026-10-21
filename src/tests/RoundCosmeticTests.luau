local Shared = if script then game.ReplicatedStorage.Shared else nil
local Rules = if Shared then require(Shared.RoundCosmeticRules) else require("../shared/RoundCosmeticRules")
local Schema = if script
	then require(game.ServerScriptService.Server.Data.ProfileSchema)
	else require("../server/Data/ProfileSchema")
return function(t)
	t.test("seasonal cosmetics persist ownership, validate equipment and preserve the base roster", function()
		local data = Schema.new(0)
		t.eq(data.Cosmetics.Skins, nil, "the Skins category is retired")
		for category, id in { Rideables = "lantern_skiff", Finishers = "lantern_eclipse" } do
			t.eq(Rules.equip(data, category, id), false)
			Rules.grant(data, category, id)
			t.eq(Rules.equip(data, category, id), true)
		end
		local frozen = Rules.loadout(data)
		t.eq(frozen.Skins, nil)
		local saved = Schema.copy(data)
		Schema.reconcile(saved, 1)
		t.eq(saved.Cosmetics.Counts.Finishers.lantern_eclipse, 1)
		t.eq(Rules.equip(data, "Skins", "hollowlight"), false)
		t.eq(Rules.equip(data, "Finishers", "hollowlight"), false)
		t.eq(data.Coins, 0)
		t.eq(data.Marbles, 0)
		t.eq(data.Glassies.hollowlight, nil, "cosmetics never add a combat glassy")
	end)
	t.test("every finisher has a timed cue set built only from the sound bank", function()
		local Config = if script then game.ReplicatedStorage.Shared.Config else nil
		local C = if Config then require(Config.RoundCosmetics) else require("../shared/Config/RoundCosmetics")
		local Audio = if Config then require(Config.Audio) else require("../shared/Config/Audio")
		local Cues = if Config then require(Config.FinisherAudio) else require("../shared/Config/FinisherAudio")
		local Balance = if Config then require(Config.Balance) else require("../shared/Config/Balance")
		for _, def in C.catalog("Finishers") do
			-- Lantern Eclipse is the longer premium show; its cues must still land before it ends.
			local last = if def.Id == "lantern_eclipse" then Balance.CosmeticPresentation.Eclipse.Duration else 1.5
			local cues = Cues.Finishers[def.Id]
			t.ok(cues, def.Id .. " has cues")
			local impacts, phases = 0, {}
			for _, cue in cues do
				t.ok(Audio[cue.Sound] ~= nil, def.Id .. " uses bank sound " .. cue.Sound)
				t.ok(cue.Phase == "Rise" or cue.Phase == "Fly" or cue.Phase == "Burst", "known phase")
				t.ok(cue.At >= 0 and cue.At <= last, "cue lands inside the finisher")
				t.ok((cue.Volume or 1) <= 1.5, "volume stays limited")
				impacts += if cue.Priority == 1 then 1 else 0
				phases[cue.Phase] = true
			end
			t.eq(impacts, 1, def.Id .. " has exactly one impact cue")
			t.ok(phases.Rise and phases.Fly and phases.Burst, def.Id .. " has charge, movement and burst")
		end
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
	end)
	t.test("legacy Hollowlight skin owners migrate once to the standalone glassy", function()
		local owner = Schema.new(0)
		owner.Cosmetics.Skins = { "hollowlight" }
		owner.Cosmetics.Counts.Skins = { hollowlight = 0 / 0 }
		owner.Cosmetics.EquippedSkins = "hollowlight"
		owner.Coins = 42
		Schema.reconcile(owner, 5)
		t.eq(owner.Glassies.hollowlight.Count, 1)
		t.eq(owner.Glassies.hollowlight.Stars, 0)
		t.eq(owner.Glassies.pop, nil, "nothing else is granted")
		t.eq(owner.Coins, 42)
		t.eq(owner.Cosmetics.Skins, nil)
		t.eq(owner.Cosmetics.EquippedSkins, nil)
		t.eq(owner.Cosmetics.Counts.Skins, nil)
		t.eq(owner.Cosmetics.EquippedFinishers, "", "other equipment survives (basic finisher)")
		Schema.reconcile(owner, 6)
		t.eq(owner.Glassies.hollowlight.Count, 1, "repeated loads never duplicate")

		local counted = Schema.new(0)
		counted.Cosmetics.Counts.Skins = { hollowlight = 2 }
		Schema.reconcile(counted, 1)
		t.eq(counted.Glassies.hollowlight.Count, 1, "a positive saved count is ownership")

		local already = Schema.new(0)
		already.Glassies.hollowlight = { Count = 3, Stars = 1, Rainbow = false, FirstAt = 1 }
		already.Cosmetics.Skins = { "hollowlight" }
		Schema.reconcile(already, 2)
		t.eq(already.Glassies.hollowlight.Count, 3, "existing glassy copies are kept, not stacked")

		for _, legacy in
			{
				{ Skins = false, Counts = { Skins = "bad" }, EquippedSkins = "hollowlight" },
				{ Skins = {}, Counts = { Skins = { hollowlight = 0 } }, EquippedSkins = "hollowlight" },
				{ Skins = { "other" }, Counts = { Skins = { hollowlight = -1 / 0 } } },
			}
		do
			local data = Schema.new(0)
			for key, value in legacy do
				data.Cosmetics[key] = if key == "Counts" then nil else value
			end
			data.Cosmetics.Counts = legacy.Counts
			Schema.reconcile(data, 1)
			t.eq(data.Glassies.hollowlight, nil, "equipped, zero or malformed data grants nothing")
			t.eq(data.Cosmetics.Skins, nil)
			t.ok(type(data.Cosmetics.Counts) == "table" and data.Cosmetics.Counts.Finishers ~= nil)
		end
	end)
	t.test("new profiles start with no flyer and the basic finisher; legacy starters stay owned", function()
		local data = Schema.new(1)
		t.eq(data.Cosmetics.EquippedRideables, "")
		t.eq(data.Cosmetics.EquippedFinishers, "")
		t.eq(#data.Cosmetics.Rideables, 0)
		t.eq(#data.Cosmetics.Finishers, 0)
		local legacy = Schema.new(1)
		legacy.Cosmetics.Rideables, legacy.Cosmetics.EquippedRideables = { "skyboard" }, "skyboard"
		Rules.reconcile(legacy)
		t.eq(legacy.Cosmetics.EquippedRideables, "skyboard", "players who had the old starter keep it")
		t.eq(Rules.count(legacy, "Rideables", "skyboard"), 1)
		data.Cosmetics = { ShatterFx = { "default", "confetti" }, EquippedShatterFx = "confetti", Fills = { "soda" } }
		Schema.reconcile(data, 2)
		t.eq(data.Cosmetics.EquippedShatterFx, "confetti")
		t.eq(data.Cosmetics.Fills[1], "soda")
		t.eq(data.Cosmetics.EquippedRideables, "")
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
		t.eq(#data.Cosmetics.Rideables, 0)
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
		t.eq(#data.Cosmetics.Rideables, 0)
		t.eq(#data.Cosmetics.Finishers, 0)
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
		t.eq(Rules.equip(data, "Rideables", "skyboard"), false, "Skyboard is no longer a free starter")
		Rules.grant(data, "Rideables", "skyboard")
		t.eq(Rules.equip(data, "Rideables", "skyboard"), true)
		t.eq(Rules.equip(data, "Rideables", ""), true, "unequip back to no flyer")
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
		t.eq(data.Cosmetics.EquippedFinishers, "")
		local snapshot = Schema.snapshot(data)
		table.insert(snapshot.Cosmetics.Finishers, "starfall")
		t.eq(#data.Cosmetics.Finishers, 0)
		t.eq(snapshot.Cosmetics.EquippedRideables, "")
	end)
end
