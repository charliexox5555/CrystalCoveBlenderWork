-- Starter Pack exclusives (decision 117, the Daybreak set): Sunny the glass rooster, the Daybreak finisher and the
-- Dawn Kite flyer. Only the pack gives them: never in the Kiln, crates, the daily store or bot hands. Sunny is an
-- ordinary Epic (normal stats, kit on the 45-55% edge), and its crow is a three-sun volley that dazzles (slows).
local function shared(path: { string }, file: string)
	if script then
		local node = game.ReplicatedStorage.Shared
		for _, name in path do
			node = node[name]
		end
		return require(node)
	end
	return require(file)
end
local C = shared({ "Config", "RoundCosmetics" }, "../shared/Config/RoundCosmetics")
local Crates = shared({ "CrateRules" }, "../shared/CrateRules")
local DailyStoreRules = shared({ "DailyStoreRules" }, "../shared/DailyStoreRules")
local Shows = shared({ "Config", "FinisherShows" }, "../shared/Config/FinisherShows")
local FinisherAudio = shared({ "Config", "FinisherAudio" }, "../shared/Config/FinisherAudio")
local Families = shared({ "Config", "RideFamilies" }, "../shared/Config/RideFamilies")
local RideAnimations = shared({ "Config", "RideAnimations" }, "../shared/Config/RideAnimations")
local Geometry = shared({ "Config", "ReleaseGeometry" }, "../shared/Config/ReleaseGeometry")
local Cracks = shared({ "Config", "ReleaseCrackPaths" }, "../shared/Config/ReleaseCrackPaths")
local Motion = shared({ "Config", "GlassyMotion" }, "../shared/Config/GlassyMotion")
local Visuals = shared({ "Config", "CombatKitVisuals" }, "../shared/Config/CombatKitVisuals")
local Grant = if script
	then require(game.ServerScriptService.Server.Data.RewardGrant)
	else require("../server/Data/RewardGrant")

return function(t, d)
	local B, G = d.Balance, d.Glassies

	t.test("Sunny is an ordinary Epic Heavy outside the release roster, the Kiln and the daily store", function()
		t.eq(#G.StarterPackIds, 1)
		local def = G.get("sunny_rooster")
		t.ok(G.isStarterPack("sunny_rooster") and not G.isRelease("sunny_rooster") and not G.isDaily("sunny_rooster"))
		t.eq(def.Rarity, "Epic")
		t.eq(def.Type, "Heavy")
		t.ok(#def.Name <= 10, "name fits a tile")
		-- Same base stats as every Heavy (the type lean), so rarity alone sets its strength.
		for _, other in G.ReleaseList do
			if other.Type == "Heavy" and other.Rarity == "Epic" then
				t.ok(
					def.Base.Power * def.Base.HP <= other.Base.Power * other.Base.HP + 1e-6,
					"not stronger than " .. other.Id
				)
			end
		end
		for _, rarity in { "Rare", "Epic", "Legendary" } do
			t.ok(table.find(d.Formula.kilnPool(rarity), "sunny_rooster") == nil, "not in the " .. rarity .. " Kiln pool")
		end
		for _, ids in DailyStoreRules.catalog().Glassies do
			t.ok(table.find(ids, "sunny_rooster") == nil, "never in the daily store")
		end
		local found = false
		for _, v in G.visible({}) do
			found = found or v.Id == "sunny_rooster"
		end
		t.ok(found, "shown (locked) in the collection before it is owned")
		t.ok(Grant.valid({ Item = { Category = "Glassies", Id = "sunny_rooster" } }), "the pack can grant it")
	end)

	t.test("Sunny has everything a glassy needs in the fight and on screen", function()
		local kit = B.CombatRelease.Kits.sunny_rooster
		t.ok(kit ~= nil and kit.Shape == "volley" and kit.Pulses == 3, "Wake-Up Call is a three-sun volley")
		t.ok(kit.Slow and kit.Slow < 1 and kit.StatusSeconds > 0, "landed suns dazzle (slow)")
		t.ok(Geometry.sunny_rooster ~= nil and math.abs(Geometry.sunny_rooster.Radius - G.get("sunny_rooster").Radius) < 0.01)
		t.ok(Cracks.sunny_rooster ~= nil and #Cracks.sunny_rooster > 20, "crack paths")
		t.ok(Motion.Glassies.sunny_rooster ~= nil, "idle/hit motion")
		t.ok(Visuals.sunny_rooster ~= nil and Visuals.sunny_rooster.Name == "Wake-Up Call")
	end)

	t.test("Sunny's crow casts three suns, and a landed sun dazzles the foe", function()
		local R = d.FightRules
		local kit = B.CombatRelease.Kits.sunny_rooster
		local s = R.new({
			A = { Id = "sunny_rooster" },
			B = { Id = "jam" },
			Rng = function()
				return 0.01
			end,
			ReleaseKits = true,
			CastsManaged = true,
		})
		local cast
		for _ = 1, math.ceil((kit.First + kit.Jitter + kit.Windup + 1) / 0.05) do
			R.tick(s, 0.05)
			for _, c in R.drainCasts(s) do
				if c.Side == 1 and not cast then
					cast = c
				end
			end
			if cast then
				break
			end
		end
		t.ok(cast ~= nil and cast.Shape == "volley", "the crow casts as a volley")
		if not cast then
			return
		end
		t.ok(R.releaseCast(s, cast, { 0, 0, 0 }, { 1, 0, 0 }))
		local foe = s.Fighters[2]
		local hp = foe.Hp
		t.ok(R.resolveAbility(s, cast.Id, true, { 1, 0, 0 }, 1))
		t.ok(foe.Hp < hp, "a sun hurts")
		t.ok((foe.Signature.SlowUntil or -1) > s.Time, "and dazzles")
		t.ok(R.resolveAbility(s, cast.Id, false, nil, 2), "a missed sun resolves too")
	end)

	t.test("Daybreak and Dawn Kite are Epic pack exclusives, outside crates, bots and the daily store", function()
		local finisher, flyer = C.ByCategory.Finishers.daybreak, C.ByCategory.Rideables.dawn_kite
		t.ok(finisher and finisher.Rarity == "Epic" and finisher.StarterPack == true)
		t.ok(flyer and flyer.Rarity == "Epic" and flyer.StarterPack == true)
		t.ok(#finisher.Name <= 10 and #flyer.Name <= 12, "names fit their tiles")
		t.ok(C.isStarterPack("daybreak") and C.isStarterPack("dawn_kite") and not C.isStarterPack("starmane"))
		for category, id in { Finishers = "daybreak", Rideables = "dawn_kite" } do
			for _, def in C[category] do
				t.ok(def.Id ~= id, id .. " is not in the crate / bot list")
			end
			for _, currency in { "Coins", "Marbles" } do
				for _, e in Crates.odds(category, currency) do
					t.ok(e.Id ~= id, id .. " is not in a " .. currency .. " crate")
				end
			end
			for _, ids in DailyStoreRules.catalog()[category] do
				t.ok(table.find(ids, id) == nil, id .. " is never in the daily store")
			end
			t.ok(Grant.valid({ Item = { Category = category, Id = id } }), "the pack can grant " .. id)
		end
	end)

	t.test("Daybreak is a timed show with sound; Dawn Kite rides the HandleStand family with a loop", function()
		local show = Shows.Shows.daybreak
		t.ok(show ~= nil and show.Module == "Daybreak")
		t.ok(show.PeakAt > 0 and show.PeakAt < show.StillAt and show.StillAt < show.Duration, "gather, peak, linger")
		t.ok(show.Punch < 0, "Epic: an FOV punch on the peak (decision 91)")
		t.ok(FinisherAudio.Finishers.daybreak ~= nil and #FinisherAudio.Finishers.daybreak >= 6)
		t.eq(Families.Flyers.dawn_kite.Family, "HandleStand")
		local profile = RideAnimations.Motion.dawn_kite
		t.ok(profile ~= nil and profile.Sound and profile.Sound.Volume <= 0.1, "a quiet loop sound")
	end)
end
