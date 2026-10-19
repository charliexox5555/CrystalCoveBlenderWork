-- Optional cast (decision 85): Ready holds, manual vs. auto release, arming kits, bots.
local Pendulum = if script
	then require(game.ServerScriptService.Server.Simulation.Pendulum)
	else require("../server/Simulation/Pendulum")
local CastTiming = if script
	then require(game.ReplicatedStorage.Shared.CastTiming)
	else require("../shared/CastTiming")

return function(t, deps)
	local Rules, Balance = deps.FightRules, deps.Balance
	local C = Balance.CombatRelease.Cast
	local function fight(a, b, policyA, policyB)
		return Rules.new({
			A = { Id = a, CastPolicy = policyA },
			B = { Id = b, CastPolicy = policyB },
			Rng = function()
				return 0.99
			end,
			ReleaseKits = true,
			CastsManaged = true,
		})
	end
	local function events(state, kind)
		local out = {}
		for _, e in Rules.drainEvents(state) do
			if e.Type == kind then
				table.insert(out, e)
			end
		end
		return out
	end

	t.test("a player's timer power waits Ready until CAST is pressed", function()
		local s = fight("prism", "jam", "player", nil)
		s.Fighters[1].Signature.NextReady = 0
		Rules.tick(s, 0.01)
		local ready = Rules.ready(s, 1)
		t.ok(ready ~= nil, "Ready after the trigger")
		t.eq(#s.PendingCasts, 0, "nothing cast yet")
		t.eq(#events(s, "SignatureReady"), 1)
		t.ok(Rules.requestCast(s, 1), "request accepted")
		t.ok(not Rules.requestCast(s, 1), "second press ignored")
		Rules.tick(s, 0.01)
		t.eq(Rules.ready(s, 1), nil)
		t.eq(#s.PendingCasts, 1)
		t.eq(s.PendingCasts[1].Manual, true)
	end)

	t.test("an ignored Ready power casts by itself after AutoSeconds", function()
		local s = fight("prism", "jam", "player", nil)
		s.Fighters[1].Signature.NextReady = 0
		Rules.tick(s, 0.01)
		Rules.drainEvents(s)
		for _ = 1, math.ceil(C.AutoSeconds / 0.05) + 1 do
			Rules.tick(s, 0.05)
		end
		local starts = events(s, "CastStart")
		t.ok(#starts >= 1, "auto cast happened")
		t.eq(starts[1].Manual, false)
		t.eq(starts[1].Held, true)
	end)

	t.test("sides without a policy still cast at once", function()
		local s = fight("prism", "jam", nil, nil)
		s.Fighters[1].Signature.NextReady = 0
		Rules.tick(s, 0.01)
		t.eq(Rules.ready(s, 1), nil)
		t.eq(#s.PendingCasts, 1)
	end)

	t.test("Pop arms on CAST and pays off on the next contact only", function()
		local s = fight("pop", "pop", "player", nil)
		Rules.hit(s, 10, 0.5)
		Rules.hit(s, 10, 0.5)
		Rules.hit(s, 10, 0.5)
		t.ok(Rules.ready(s, 1) ~= nil, "third contact makes it Ready")
		Rules.drainEvents(s)
		Rules.hit(s, 10, 0.5)
		local plain
		for _, e in Rules.drainEvents(s) do
			if e.Type == "Hit" then
				plain = e.Damage[2]
			end
		end
		Rules.requestCast(s, 1)
		Rules.tick(s, 0.01)
		t.eq(#events(s, "SignatureArmed"), 1)
		t.ok(Rules.knockbackMultiplier(s, 2, true) > 1, "armed contact pushes harder")
		Rules.hit(s, 10, 0.5)
		local boosted
		for _, e in Rules.drainEvents(s) do
			if e.Type == "Hit" then
				boosted = e.Damage[2]
			end
		end
		t.ok(boosted > plain * 1.3, "armed contact deals bonus damage")
		t.eq(s.Fighters[1].Signature.Armed, nil)
	end)

	t.test("an arm that never meets a contact fades", function()
		local s = fight("pop", "pop", "player", nil)
		for _ = 1, 3 do
			Rules.hit(s, 10, 0.5)
		end
		Rules.requestCast(s, 1)
		Rules.tick(s, 0.01)
		for _ = 1, math.ceil(C.ArmedSeconds / 0.1) + 1 do
			Rules.tick(s, 0.1)
		end
		t.eq(s.Fighters[1].Signature.Armed, nil)
		t.eq(s.Fighters[1].Signature.Charge, 0)
	end)

	t.test("Ready is cancelled at the shatter", function()
		local s = fight("prism", "jam", "player", nil)
		s.Fighters[1].Signature.NextReady = 0
		Rules.tick(s, 0.01)
		s.Fighters[1].Hp = 0.01
		Rules.hit(s, 40, 0)
		Rules.tick(s, 0.01)
		t.eq(Rules.ready(s, 1), nil)
	end)

	t.test("CastTiming reads braces, strikes and arms", function()
		t.eq(CastTiming.kind("guard"), "brace")
		t.eq(CastTiming.kind("ray"), "strike")
		t.eq(CastTiming.kind("contact", true), "arm")
		t.ok(CastTiming.good("brace", 2.2, 6, 1.5, { Windup = 0.15 }), "contact due soon")
		t.ok(not CastTiming.good("brace", 9, 0.2, 1.5, { Windup = 0.15 }), "far and drifting")
		t.ok(CastTiming.good("strike", 5, 2, 1.5, { Windup = 0.4, Range = 6 }))
		t.ok(not CastTiming.good("strike", 14, -2, 1.5, { Windup = 0.4, Range = 6 }))
	end)

	t.test("bots and smart tools press CAST in the real swing", function()
		local sim = Pendulum.new({
			A = { Id = "prism", CastPolicy = "smart" },
			B = { Id = "jam", CastPolicy = "bot", CastSkill = 0.5 },
			Rng = deps.Rng.new(4),
		}, 4)
		local manual = { 0, 0 }
		while not sim.Fight.Over do
			Pendulum.step(sim, 1 / Balance.Motion.StepRate)
			for _, e in Pendulum.events(sim) do
				if (e.Type == "CastStart" or e.Type == "SignatureArmed") and e.Manual then
					manual[e.Side] += 1
				end
			end
		end
		t.ok(manual[1] > 0, "smart side cast by hand")
		t.ok(manual[2] > 0, "bot side cast by hand")
	end)
end
