local Pendulum = if script
	then require(game.ServerScriptService.Server.Simulation.Pendulum)
	else require("../server/Simulation/Pendulum")
local Geometry = if script
	then require(game.ServerScriptService.Server.Simulation.AttackGeometry)
	else require("../server/Simulation/AttackGeometry")
local Turnaround = if script
	then require(game.ServerScriptService.Server.Simulation.Turnaround)
	else require("../server/Simulation/Turnaround")
local V = if script then Vector3 else require("@lune/roblox").Vector3

return function(t, deps)
	local Rules = deps.FightRules
	local function fight(a, b)
		return Rules.new({
			A = { Id = a },
			B = { Id = b },
			Rng = function()
				return 0.99
			end,
			ReleaseKits = true,
			CastsManaged = true,
		})
	end
	local function lastHit(state)
		local hit
		for _, e in Rules.drainEvents(state) do
			if e.Type == "Hit" then
				hit = e
			end
		end
		return hit
	end
	t.test("Pop spends exactly three body contacts on the current clash", function()
		local s = fight("pop", "pop")
		Rules.hit(s, 10, 0.5)
		t.eq(s.Fighters[1].Signature.Charge, 1)
		Rules.hit(s, 10, 0.5)
		local ordinary = lastHit(s).Damage[2]
		Rules.hit(s, 10, 0.5)
		local third = lastHit(s).Damage[2]
		t.near(third, ordinary * (1 + deps.Balance.CombatRelease.Kits.pop.ContactBonus), 1e-6)
		t.eq(s.Fighters[1].Signature.Charge, 0)
		Rules.hit(s, 10, 0.5)
		t.near(lastHit(s).Damage[2], ordinary, 1e-6)
	end)
	t.test("Jam guard mitigates one body hit and leaves ranged damage unchanged", function()
		local s = fight("jam", "prism")
		Rules.turnaround(s, 1)
		Rules.turnaround(s, 1)
		Rules.tick(s, 0.16)
		t.ok(s.Fighters[1].Signature.GuardUntil > s.Time)
		s.Fighters[2].Signature.NextReady = 0
		Rules.tick(s, 0.01)
		Rules.tick(s, 0.46)
		local cast = Rules.drainCasts(s)[1]
		t.ok(Rules.releaseCast(s, cast, { 0, 0, 0 }, { 1, 0, 0 }))
		local before = s.Fighters[1].Hp
		Rules.resolveAbility(s, cast.Id, true, { 1, 0, 0 })
		t.near(
			before - s.Fighters[1].Hp,
			s.Fighters[2].Power * cast.Params.Damage * deps.Formula.typeMultiplier("Sharp", "Heavy"),
			1e-6
		)
		t.ok(s.Fighters[1].Signature.GuardUntil > s.Time, "ray did not consume guard")
		Rules.hit(s, 10, 0.5)
		local reduced = lastHit(s).Damage[1]
		Rules.hit(s, 10, 0.5)
		local normal = lastHit(s).Damage[1]
		t.near(reduced, normal * (1 - deps.Balance.CombatRelease.Kits.jam.Mitigation), 1e-6)
	end)
	t.test("Briar grows on turnarounds and spends its bonus only once", function()
		local s = fight("briar_flask", "jam")
		for _ = 1, 3 do
			Rules.turnaround(s, 1)
		end
		t.eq(s.Fighters[1].Signature.Charge, 3)
		Rules.hit(s, 10, 0.5)
		local bloom = lastHit(s).Damage[2]
		t.eq(s.Fighters[1].Signature.Charge, 0)
		Rules.hit(s, 10, 0.5)
		local ordinary = lastHit(s).Damage[2]
		t.near(bloom, ordinary * (1 + deps.Balance.CombatRelease.Kits.briar_flask.ContactBonus), 1e-6)
	end)
	t.test("Arc shots cannot refill contact charge or resolve twice", function()
		local s = fight("arc_coil", "jam")
		for _ = 1, 3 do
			Rules.hit(s, 10, 0.5)
		end
		Rules.tick(s, 0.36)
		local cast = Rules.drainCasts(s)[1]
		t.ok(cast ~= nil)
		t.ok(not Rules.resolveAbility(s, cast.Id, true, nil), "no result before release")
		Rules.releaseCast(s, cast, { 0, 0, 0 }, { 1, 0, 0 })
		local hp = s.Fighters[2].Hp
		t.ok(Rules.resolveAbility(s, cast.Id, false, nil))
		t.eq(s.Fighters[2].Hp, hp, "miss did no damage")
		t.eq(s.Fighters[1].Signature.Charge, 0, "ability did not count as body contact")
		t.ok(not Rules.resolveAbility(s, cast.Id, true, { 1, 0, 0 }), "duplicate cast result rejected")
	end)
	t.test("lethal contact cancels windup and later offensive results", function()
		local s = fight("crescent_axe", "pop")
		Rules.turnaround(s, 1)
		Rules.turnaround(s, 1)
		t.eq(#s.PendingCasts, 1)
		s.Fighters[1].Hp = 1
		Rules.hit(s, 20, 0.5)
		t.ok(s.Over)
		t.eq(#s.PendingCasts, 0)
		Rules.tick(s, 1)
		t.eq(#Rules.drainCasts(s), 0)
	end)
	t.test("3D turnaround detector rejects jitter, tiny excursions and collision rebounds", function()
		local d = Turnaround.new(-7)
		t.ok(not Turnaround.step(d, 0.1, 0.1, -0.1, -6.9, -10))
		Turnaround.step(d, 0.2, 0.2, 2, -6.5, -10)
		t.ok(Turnaround.step(d, 0.6, 0.1, -0.1, -6, -10))
		t.ok(not Turnaround.step(d, 0.7, 0.1, -0.1, -6, -10), "debounced")
		local c = Turnaround.new(-7)
		Turnaround.step(c, 1, 0, 2, -6.5, 0.9)
		t.ok(not Turnaround.step(c, 1.05, 0.1, -0.1, -6, 1), "collision exclusion")
	end)
	t.test("bounded ray and relative sweep miss out of plane and catch a crossing target", function()
		t.ok(Geometry.segmentSphere(V.zero, V.new(4, 0, 0), V.new(2, 0, 0), 0.2))
		t.ok(not Geometry.segmentSphere(V.zero, V.new(4, 0, 0), V.new(5, 0, 0), 0.2))
		t.ok(not Geometry.segmentSphere(V.zero, V.new(4, 0, 0), V.new(2, 0, 2), 0.2))
		t.ok(Geometry.movingSphere(V.new(-1, 0, 0), V.new(1, 0, 0), V.new(0, -2, 0), V.new(0, 2, 0), 0.2))
		t.ok(not Geometry.movingSphere(V.new(-1, 0, 0), V.new(1, 0, 0), V.new(0, -2, 3), V.new(0, 2, 3), 0.2))
	end)
	t.test("first six seeded native-style swings use unique bounded casts and fixed strings", function()
		local releases, contacts = 0, 0
		for i, pair in { { "pop", "crescent_axe" }, { "jam", "arc_coil" }, { "prism", "briar_flask" } } do
			local sim = Pendulum.new({
				A = { Id = pair[1], Aim = 0.9, AimYaw = 0.3 },
				B = { Id = pair[2], Aim = 0.85, AimYaw = -0.2 },
				Rng = deps.Rng.new(900 + i),
				ReleaseKits = true,
			}, 900 + i)
			local seen = {}
			for _ = 1, 3600 do
				Pendulum.step(sim, 1 / 60)
				for _, e in Pendulum.events(sim) do
					if e.Type == "CastRelease" then
						releases += 1
					end
					if e.Type == "CastContact" then
						t.ok(not seen[e.CastId], "one contact per cast")
						seen[e.CastId] = true
						contacts += 1
					end
				end
				if sim.Fight.Over then
					break
				end
			end
			t.ok(sim.Fight.Over, "round resolved")
			t.ok(sim.Metrics.MaxRadiusError < 0.00001, "string length preserved")
		end
		t.ok(releases > 0 and contacts > 0, "real geometry processed casts")
	end)
	t.test("release pools contain 36 identities and preserve owned dormant data", function()
		t.eq(#deps.Glassies.ReleaseList, 36, "24 + 12 launch glassies")
		t.eq(
			#deps.Glassies.List,
			43 + #deps.Glassies.SeasonalIds,
			"24 release + 13 dormant + 6 new launch definitions + seasonal"
		)
		local odds = deps.Formula.kilnOdds()
		t.eq(#odds, 33, "21 + 12 launch glassies in the Kiln")
		for _, e in odds do
			t.ok(deps.Glassies.isRelease(e.Id))
		end
		local owned = { perfume = { Count = 1, Stars = 3 } }
		t.eq(#deps.Glassies.visible(owned), 37, "36 release + owned legacy perfume")
		t.eq(owned.perfume.Stars, 3)
		t.ok(table.find(deps.MatchLogic.ownedIds(owned), "perfume") ~= nil, "legacy ownership not excluded")
	end)
end
