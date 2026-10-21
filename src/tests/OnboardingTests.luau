local Rules = if script
	then require(game.ServerScriptService.Server.Data.OnboardingRules)
	else require("../server/Data/OnboardingRules")
local Pendulum = if script
	then require(game.ServerScriptService.Server.Simulation.Pendulum)
	else require("../server/Simulation/Pendulum")
local Schema = if script
	then require(game.ServerScriptService.Server.Data.ProfileSchema)
	else require("../server/Data/ProfileSchema")
local Roster = if script
	then require(game.ReplicatedStorage.Shared.Config.ReleaseRoster)
	else require("../shared/Config/ReleaseRoster")
return function(t, d)
	-- The Kiln pool as KilnService builds it (release glassies without the starters).
	local available = {}
	for _, id in Roster.Ids do
		local def = d.Glassies.ById[id]
		if def and def.Rarity ~= "Starter" then
			available[id] = true
		end
	end
	local starters = { pop = true, jam = true, prism = true }
	t.test("welcome opens: one Common, Uncommon and Rare, three types, none owned", function()
		for seed = 1, 40 do
			local picks = Rules.welcomePicks(starters, available, d.Rng.new(seed))
			t.eq(#picks, 3)
			local rarities, types, seen = {}, {}, {}
			for _, id in picks do
				local def = d.Glassies.ById[id]
				t.ok(not starters[id] and not seen[id], "never owned, never repeated")
				seen[id] = true
				rarities[def.Rarity] = true
				types[def.Type] = true
			end
			t.ok(rarities.Common and rarities.Uncommon and rarities.Rare, "one of each rarity")
			t.ok(types.Heavy and types.Fizzy and types.Sharp, "one of each type")
		end
	end)
	t.test("welcome opens differ between players (same rarity shape, different glassies)", function()
		local trios = {}
		local count = 0
		for seed = 1, 300 do
			local picks = Rules.welcomePicks(starters, available, d.Rng.new(seed))
			table.sort(picks)
			local key = table.concat(picks, ",")
			if not trios[key] then
				trios[key] = true
				count += 1
			end
		end
		t.ok(count >= 40, "distinct trios " .. count)
	end)
	t.test("welcome opens fall back when a rarity is all owned", function()
		local owned = table.clone(starters)
		for id in available do
			if d.Glassies.ById[id].Rarity == "Common" then
				owned[id] = true
			end
		end
		local picks = Rules.welcomePicks(owned, available, d.Rng.new(3))
		t.eq(#picks, 3)
		for _, id in picks do
			t.ok(not owned[id], "still never owned")
		end
	end)
	t.test("first-win open: Rare or Epic, never owned, roughly 70/30", function()
		local counts = { Rare = 0, Epic = 0 }
		local rng = d.Rng.new(9)
		for _ = 1, 2000 do
			local id = Rules.winPick(starters, available, rng)
			local rarity = d.Glassies.ById[id].Rarity
			t.ok(rarity == "Rare" or rarity == "Epic", "rarity " .. rarity)
			counts[rarity] += 1
		end
		t.ok(math.abs(counts.Rare / 2000 - 0.7) < 0.05, "Rare share " .. counts.Rare / 2000)
	end)
	t.test("new profiles start at Welcome; players who have played skip", function()
		t.eq(Rules.initial({ Stats = { MatchWins = 0, MatchLosses = 0 }, Flags = {} }), "Welcome")
		t.eq(Rules.initial({ Stats = { MatchWins = 0, MatchLosses = 2 }, Flags = {} }), "Done")
		t.eq(Rules.initial({ Stats = { MatchWins = 0, MatchLosses = 0 }, Flags = { WelcomePullUsed = true } }), "Done")
	end)
	t.test("assisted first match: the planned side wins every round on the real swing (3-1)", function()
		local human = 1
		for round = 1, 4 do
			for seed = 1, 6 do
				local assist = Rules.assist(round, human)
				local sim = Pendulum.new({
					A = { Id = "pop", Aim = 0.9, AimYaw = 0.4 },
					B = { Id = "glass_duck", Aim = 0.9, AimYaw = -0.3 },
					Rng = d.Rng.new(seed * 31 + round),
					SweetSpot = 0.9,
					Assist = assist,
				}, seed * 31 + round)
				local steps = 0
				while not sim.Fight.Over and steps < 60 * 120 do
					Pendulum.step(sim, 1 / 60)
					steps += 1
				end
				t.ok(sim.Fight.Over, "the round ends")
				t.eq(sim.Fight.Winner, assist.Winner)
				t.eq(assist.Winner, if round == d.Balance.Onboarding.BotRound then 2 else 1)
			end
		end
	end)
	t.test("tutorial funnel: 12 steps in order, from joining to the second match", function()
		t.eq(#Rules.Funnel, 12)
		local events = {
			"Joined",
			"WelcomeOpened",
			"Collected",
			"DailyClaimed",
			"FirstMatchStarted",
			"FirstFightStarted",
			"FirstRoundFinished",
			"FirstMatchWon",
			"WinOpened",
			"Collected",
			"SecondMatchStarted",
			"SecondMatchFinished",
		}
		local progress = 0
		for index, event in events do
			t.eq(Rules.funnelStep(progress, event), index)
			progress = index
		end
		-- Everything after the last step is ignored, and repeats never log twice.
		t.eq(Rules.funnelStep(progress, "SecondMatchStarted"), nil)
		t.eq(Rules.funnelStep(5, "FirstMatchStarted"), nil)
		-- "Collected" means the welcome opening before the daily step, the win opening after it.
		t.eq(Rules.funnelStep(2, "Collected"), 3)
		t.eq(Rules.funnelStep(9, "Collected"), 10)
		-- A dropped client signal does not stall the funnel.
		t.eq(Rules.funnelStep(2, "DailyClaimed"), 4)
		t.eq(Rules.funnelStep(0, "Nonsense"), nil)
		t.ok(table.find(Rules.Steps, "Win") == table.find(Rules.Steps, "Match") + 1, "Win claim follows the match")
	end)
	t.test("tutorial funnel: new profiles start at 0, finished players stay out", function()
		t.eq(Schema.new(0).Onboarding.Funnel, 0)
		local old = Schema.new(0)
		old.Onboarding = { Step = "Done" } -- finished before the funnel existed
		t.eq(Schema.reconcile(old, 0).Onboarding.Funnel, #Rules.Funnel)
		local veteran = Schema.new(0)
		veteran.Onboarding = nil
		veteran.Stats.MatchWins = 3
		t.eq(Schema.reconcile(veteran, 0).Onboarding.Funnel, #Rules.Funnel)
		local midway = Schema.new(0)
		midway.Onboarding = { Step = "Arena", Funnel = 4 }
		t.eq(Schema.reconcile(midway, 0).Onboarding.Funnel, 4)
	end)
	t.test("no playing around a claim card: Welcome and Win open their claim instead of queuing", function()
		t.eq(Rules.claimBeforePlay("Welcome"), "OpenWelcome")
		t.eq(Rules.claimBeforePlay("Win"), "OpenWin")
		for _, step in { "Daily", "Arena", "Match", "Done" } do
			t.eq(Rules.claimBeforePlay(step), nil)
		end
	end)
	t.test("the first solo bot match is assisted from Daily, Arena or Match, never before or after", function()
		for _, step in Rules.Steps do
			local expected = step == "Daily" or step == "Arena" or step == "Match"
			t.eq(Rules.isFirstMatch(step), expected)
		end
		-- Every step a player can queue from is either assisted or has a claim to open first, except Done.
		for _, step in Rules.Steps do
			t.ok(step == "Done" or Rules.isFirstMatch(step) or Rules.claimBeforePlay(step) ~= nil, step)
		end
	end)
end
