-- Classic combat regression: server rules, automatic kit payoffs and short intro orchestration.
local Pendulum = if script
	then require(game.ServerScriptService.Server.Simulation.Pendulum)
	else require("../server/Simulation/Pendulum")
local Runner = if script
	then require(game.ServerScriptService.Server.Simulation.MatchRunner)
	else require("../server/Simulation/MatchRunner")

return function(t, d)
	local B, Rules, Arena = d.Balance, d.FightRules, d.ArenaRules
	t.test("first-win unlock is offered next match, with ownership checks and no duplicate cards", function()
		local Logic = d.MatchLogic
		local collection = { pop = {}, jam = {}, prism = {}, glass_dragon = {} }
		for _, id in { "glass_dragon", "unowned", "not_a_glassy" } do
			local m = Logic.new({ { Collection = collection, FirstOffer = id }, { Collection = {} } }, d.Rng.new(10))
			Logic.startRound(m)
			local offers, seen = m.Sides[1].Offers, {}
			t.eq(#offers, B.Match.RollChoices)
			for _, offer in offers do
				t.ok(collection[offer] ~= nil and not seen[offer], "owned unique hand")
				seen[offer] = true
			end
			if collection[id] then
				t.eq(offers[1], id, "new prize is available and the safe default")
			end
			t.eq(m.Sides[1].PickAnyUsed, 0, "normal free pick remains available")
		end
	end)
	t.test("saved replay reward survives reconnect only while it is a valid owned glassy", function()
		local Schema = if script
			then require(game.ServerScriptService.Server.Data.ProfileSchema)
			else require("../server/Data/ProfileSchema")
		local profile = Schema.new(0)
		Schema.grant(profile, "pop", false, 0)
		profile.Onboarding.ReplayGlassy = "pop"
		t.eq(Schema.reconcile(profile, 0).Onboarding.ReplayGlassy, "pop")
		for _, invalid in { "glass_dragon", "not_a_glassy", {} } do
			profile.Onboarding.ReplayGlassy = invalid
			t.eq(Schema.reconcile(profile, 0).Onboarding.ReplayGlassy, nil)
		end
	end)
	t.test("classic defaults reject arena inputs and never roll random modifiers", function()
		t.eq(B.Arena.Enabled, false)
		t.eq(B.CombatRelease.Cast.ManualEnabled, false)
		for _, twist in { "Bumpers", "Windy", "GlintRain" } do
			local s = Rules.new({
				A = { Id = "pop", CastPolicy = "player", LastGlass = true },
				B = { Id = "jam", CastPolicy = "bot" },
				Twist = twist,
				Rng = d.Rng.new(17),
			})
			t.eq(Arena.twist(s), "Calm")
			t.eq(s.Arena, nil)
			t.ok(not Rules.requestPush(s, 1), "stale/exploited PUSH is rejected")
			t.eq(#Arena.drainImpulses(s), 0)
			t.eq(#Arena.drainRequests(s), 0)
			t.eq(s.Fighters[1].GlassShield, nil, "no hidden Last Glass bonus")
		end
		local calls = 0
		t.eq(
			Arena.rollTwist(function()
				calls += 1
				return 0.5
			end),
			"Calm"
		)
		t.eq(calls, 0, "disabled twists do not consume gameplay RNG")
	end)
	t.test("both player and bot powers auto-cast without a tutorial timing penalty", function()
		local s = Rules.new({
			A = { Id = "prism", CastPolicy = "player" },
			B = { Id = "prism", CastPolicy = "bot" },
			Rng = d.Rng.new(23),
			CastsManaged = true,
			Assist = { CastSeconds = { [1] = 4 } },
		})
		for _, f in s.Fighters do
			t.eq(f.Signature.Policy, "auto")
			f.Signature.NextReady = 0
		end
		Rules.tick(s, 0.01)
		t.ok(Rules.ready(s, 1) ~= nil)
		t.near(Rules.ready(s, 1).AutoAt - s.Time, B.CombatRelease.Cast.AutoSeconds, 0.001)
		t.ok(not Rules.requestCast(s, 1), "manual CAST cannot bypass auto timing")
		while s.Time < B.CombatRelease.Cast.AutoSeconds + 0.1 do
			Rules.tick(s, 0.01)
		end
		t.eq(Rules.ready(s, 1), nil)
		t.eq(Rules.ready(s, 2), nil)
		t.eq(#s.PendingCasts, 2, "both signature powers fire")
		for _, cast in s.PendingCasts do
			t.eq(cast.Manual, false)
		end
	end)
	t.test("real swings retain powers and shatters without pickup/push events", function()
		local banned = {
			Twist = true,
			Heat = true,
			GlintSpawn = true,
			GlintGrab = true,
			GlintBlock = true,
			Push = true,
			PushCharge = true,
			Bump = true,
			BombArm = true,
			BombPop = true,
			Gust = true,
		}
		local powers = 0
		for seed, pair in { { "prism", "jam" }, { "pop", "pickle_jar" }, { "glass_dragon", "glass_unicorn" } } do
			local sim = Pendulum.new({
				A = { Id = pair[1], CastPolicy = "player", Aim = 0.9 },
				B = { Id = pair[2], CastPolicy = "bot", Aim = 0.9 },
				Rng = d.Rng.new(seed),
				SweetSpot = 0.9,
				Twist = "Bumpers",
			}, seed)
			local steps = 0
			while not sim.Fight.Over and steps < B.Motion.StepRate * (B.Fight.RoundTimeout + 2) do
				Pendulum.step(sim, 1 / B.Motion.StepRate)
				for _, e in Pendulum.events(sim) do
					t.ok(not banned[e.Type], "no extra arena event " .. e.Type)
					if e.Type == "CastStart" or e.Type == "SignatureArmed" then
						powers += 1
					end
				end
				steps += 1
			end
			t.ok(sim.Fight.Over, "classic round resolves")
			t.ok(sim.Fight.Hits > 0, "physical contacts remain")
			t.eq(sim.Posts, nil, "no bumper collision geometry")
		end
		t.ok(powers > 0, "unique powers still activate")
	end)
	t.test("one-round introductory runner ends after the first shatter", function()
		local r = Runner.new({
			{ Collection = {}, Hearts = B.Onboarding.Hearts },
			{ Collection = {}, Hearts = B.Onboarding.Hearts, IsBot = true, Skill = 0.1 },
		}, d.Rng.new(42), 0, { RollSeconds = B.Onboarding.RollSeconds })
		t.eq(r.Match.Sides[1].Hearts, 1)
		t.eq(r.Match.Sides[2].Hearts, 1)
		t.eq(r.Deadline, B.Onboarding.RollSeconds)
		r:Step(B.Onboarding.RollSeconds)
		r:Step(B.Onboarding.RollSeconds + B.Match.AimSeconds)
		r:Step(B.Onboarding.RollSeconds + B.Match.AimSeconds + B.Match.CountdownSeconds)
		t.eq(r.Phase, "Fighting")
		local at = B.Onboarding.RollSeconds + B.Match.AimSeconds + B.Match.CountdownSeconds + 18
		r:FightEnded(1, at)
		r:Step(at + B.Match.RoundEndSeconds)
		t.eq(r.Phase, "MatchEnd")
		t.eq(#r.Match.History, 1)
		t.eq(B.Match.Hearts, 3, "normal PvP still has three hearts")
	end)
	t.test("a first-pick allowance cannot extend every later round", function()
		local r = Runner.new(
			{ { Collection = {} }, { Collection = {}, IsBot = true } },
			d.Rng.new(99),
			0,
			{ RollSeconds = 40 }
		)
		t.eq(r.Deadline, 40)
		r.Phase = "Fighting"
		r:FightEnded(1, 50)
		r:Step(50 + B.Match.RoundEndSeconds)
		t.eq(r.Phase, "Rolling")
		t.eq(r.Deadline, 50 + B.Match.RoundEndSeconds + B.Match.RollSecondsLater)
	end)
end
