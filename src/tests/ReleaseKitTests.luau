local Pendulum = if script
	then require(game.ServerScriptService.Server.Simulation.Pendulum)
	else require("../server/Simulation/Pendulum")
local Geometry = if script
	then require(game.ServerScriptService.Server.Simulation.AttackGeometry)
	else require("../server/Simulation/AttackGeometry")
local Visuals = if script
	then require(game.ReplicatedStorage.Shared.Config.CombatKitVisuals)
	else require("../shared/Config/CombatKitVisuals")
local V = if script then Vector3 else require("@lune/roblox").Vector3
return function(t, d)
	local R = d.FightRules
	local function fight(a, b)
		return R.new({
			A = { Id = a },
			B = { Id = b },
			ReleaseKits = true,
			CastsManaged = true,
			Rng = function()
				return 0.99
			end,
		})
	end
	local function timed(s, side)
		s.Fighters[side].Signature.NextReady = 0
		R.tick(s, 0.01)
		R.tick(s, s.Fighters[side].Signature.Kit.Windup + 0.01)
		return R.drainCasts(s)[1]
	end
	t.test("all 24 release identities have rules, geometry and truthful display copy", function()
		local count = 0
		for _, def in d.Glassies.ReleaseList do
			local s = fight(def.Id, "pop")
			t.ok(s.Fighters[1].Signature and Visuals[def.Id])
			t.eq(def.Description, Visuals[def.Id].Description)
			t.ok(s.Fighters[1].Radius > 0 and s.Fighters[1].BodyCenter > 0)
			count += 1
		end
		t.eq(count, 36)
	end)
	t.test("milk repairs once per threshold, cannot revive and low-health duck guards only one body hit", function()
		local s = fight("milk_bottle", "pop")
		local marks = s.Fighters[1].Signature.Kit.Thresholds
		s.Fighters[1].Hp = s.Fighters[1].MaxHp * (marks[1] - 0.01)
		R.hit(s, 10, 0.5)
		t.eq(s.Fighters[1].Signature.ThresholdIndex, 1)
		local before = s.Fighters[1].Hp
		R.tick(s, 0.5)
		t.ok(s.Fighters[1].Hp > before)
		R.hit(s, 10, 0.5)
		t.eq(#s.PendingCasts, 0, "no repeat above the next threshold")
		for _ = 1, 60 do
			R.tick(s, 0.1)
		end
		s.Fighters[1].Hp = s.Fighters[1].MaxHp * (marks[#marks] - 0.01)
		R.hit(s, 10, 0.5)
		t.ok(s.Fighters[1].Signature.Used, "last threshold used")
		R.tick(s, 0.5)
		s.Fighters[1].Hp = s.Fighters[1].MaxHp * 0.1
		R.hit(s, 10, 0.5)
		t.eq(#s.PendingCasts, 0, "no third repair")
		local lethal = fight("milk_bottle", "pop")
		lethal.Fighters[1].Hp = 1
		R.hit(lethal, 20, 0.5)
		R.tick(lethal, 1)
		t.ok(lethal.Over)
		t.eq(lethal.Fighters[1].Hp, 0)
		local duck = fight("glass_duck", "pop")
		duck.Fighters[1].Hp = duck.Fighters[1].MaxHp * 0.34
		R.hit(duck, 4, 0.5)
		R.tick(duck, 0.13)
		t.ok(duck.Fighters[1].Signature.GuardUntil > duck.Time)
		R.hit(duck, 4, 0.5)
		t.eq(duck.Fighters[1].Signature.GuardUntil, -1)
	end)
	t.test("splat requires a later clash; slow cannot stack or refresh through immunity", function()
		local s = fight("ketchup_bottle", "jam")
		for _ = 1, 3 do
			R.hit(s, 4, 0.5)
		end
		t.ok(s.Fighters[2].Signature.Mark)
		R.hit(s, 4, 0.5)
		t.eq(s.Fighters[2].Signature.Mark, nil)
		t.ok(s.ContactExtra[2] > 0)
		local slow = fight("pickle_jar", "jam")
		for _ = 1, 3 do
			R.hit(slow, 4, 0.5)
		end
		local untilTime = slow.Fighters[2].Signature.SlowUntil
		for _ = 1, 3 do
			R.hit(slow, 4, 0.5)
		end
		t.eq(slow.Fighters[2].Signature.SlowUntil, untilTime)
		t.between(R.swingMultiplier(slow, 2), d.Balance.CombatRelease.SlowFloor, 1)
	end)
	t.test("stored damage and contact storage release only at a later turnaround", function()
		for _, id in { "water_jug", "comet" } do
			local s = fight(id, "jam")
			for _ = 1, 3 do
				R.hit(s, 4, 0.5, 1, 2, 3)
			end
			t.eq(#R.drainCasts(s), 0)
			R.turnaround(s, 1)
			R.tick(s, 0.35)
			local c = R.drainCasts(s)[1]
			t.ok(c, "stored release " .. id)
			if id == "comet" then
				t.eq(c.Params.StoredOrigin[3], 3)
			end
		end
	end)
	t.test("mirror catches ranged once and return shots never reflect again", function()
		local s = fight("prism", "crystal_tumbler")
		s.Fighters[2].Signature.MirrorUntil = 10
		local c = timed(s, 1)
		R.releaseCast(s, c, { 0, 0, 0 }, { 1, 0, 0 })
		local before = s.Fighters[2].Hp
		R.resolveAbility(s, c.Id, true, { 1, 0, 0 })
		t.ok(s.Fighters[2].Signature.MirrorUntil < 0)
		t.near(
			before - s.Fighters[2].Hp,
			s.Fighters[1].Power * c.Params.Damage * d.Formula.typeMultiplier("Sharp", "Sharp") * 0.55,
			1e-6
		)
		R.tick(s, 0.26)
		local reflected = R.drainCasts(s)[1]
		t.ok(reflected and reflected.Params.Reflection)
		R.releaseCast(s, reflected, { 1, 0, 0 }, { -1, 0, 0 })
		R.resolveAbility(s, reflected.Id, true, { 0, 0, 0 })
		t.eq(#s.PendingCasts, 0)
	end)
	t.test("three-shot and three-pulse attacks share one budget and reject replay", function()
		for _, id in { "lemonade_bottle", "glass_dragon" } do
			local s = fight(id, "jam")
			local c = timed(s, 1)
			R.releaseCast(s, c, { 0, 0, 0 }, { 1, 0, 0 })
			local before = s.Fighters[2].Hp
			for pulse = 1, 3 do
				t.ok(R.resolveAbility(s, c.Id, true, { 1, 0, 0 }, pulse))
				t.ok(not R.resolveAbility(s, c.Id, true, { 1, 0, 0 }, pulse))
			end
			t.near(
				before - s.Fighters[2].Hp,
				s.Fighters[1].Power * c.Params.Damage * d.Formula.typeMultiplier(s.Fighters[1].Type, "Heavy"),
				1e-6
			)
			t.eq(s.AbilityResults[c.Id], nil)
		end
	end)
	t.test("returning blade sweeps both legs once, including an apex-crossing step", function()
		local Attacks = if script
			then require(game.ServerScriptService.Server.Simulation.SignatureAttacks)
			else require("../server/Simulation/SignatureAttacks")
		local Path = if script
			then require(game.ReplicatedStorage.Shared.AttackPath)
			else require("../shared/AttackPath")
		t.eq(Path.distance(0, "return"), 0)
		t.eq(Path.distance(0.5, "return"), 1)
		t.eq(Path.distance(1, "return"), 0)
		local s = fight("prism_blade", "jam")
		R.turnaround(s, 1)
		R.turnaround(s, 1)
		R.tick(s, 0.31)
		local c = R.drainCasts(s)[1]
		t.ok(c and c.Params.Path == "return")
		R.releaseCast(s, c, { 0, 0, 0 }, { 1, 0, 0 })
		local sim = { Fight = s }
		local target = V.new(3, 0, 0)
		Attacks.add(sim, c, V.zero, V.xAxis, target)
		local before = s.Fighters[2].Hp
		Attacks.step(sim, c.Params.Duration * 0.75, function()
			return target
		end)
		t.ok(c.Results[1] and c.Results[2], "both swept legs hit")
		t.near(
			before - s.Fighters[2].Hp,
			s.Fighters[1].Power * c.Params.Damage * d.Formula.typeMultiplier(s.Fighters[1].Type, "Heavy"),
			1e-6
		)
		t.ok(not R.resolveAbility(s, c.Id, true, { 3, 0, 0 }, 1), "no replay")
		Attacks.step(sim, c.Params.Duration, function()
			return target
		end)
		t.eq(#sim.ReleaseAttacks, 0)
	end)
	t.test("stored echo survives a turnaround refused by cooldown", function()
		local s = fight("comet", "jam")
		local sig = s.Fighters[1].Signature
		sig.HasCast, sig.LastReady, sig.BusyUntil = true, 0, -1
		sig.EchoPoint, sig.EchoUntil = { 1, 2, 3 }, 10
		R.turnaround(s, 1)
		t.eq(#s.PendingCasts, 0)
		t.ok(sig.EchoPoint)
		R.tick(s, d.Balance.CombatRelease.MinCastSeconds + 0.01)
		R.turnaround(s, 1)
		t.eq(#s.PendingCasts, 1)
		t.eq(sig.EchoPoint, nil)
	end)
	t.test("Hourglass heals on spin completion with two charges and an eight-second cooldown", function()
		local s = fight("hourglass", "jam")
		local f = s.Fighters[1]
		for _ = 1, 3 do
			R.turnaround(s, 1)
		end
		t.eq(#s.PendingCasts, 0, "healthy glass cannot charge a heal")
		f.Hp = f.MaxHp * 0.5
		local before = f.Hp
		for _ = 1, 3 do
			R.turnaround(s, 1)
		end
		t.eq(#s.PendingCasts, 1)
		R.tick(s, 0.84)
		t.near(f.Hp, before, 1e-6, "no premature heal")
		R.tick(s, 0.02)
		t.near(f.Hp - before, f.MaxHp * d.Balance.CombatRelease.Kits.hourglass.Heal, 1e-6)
		t.eq(#R.drainCasts(s), 0, "heal replaces ranged sand attack")
		R.tick(s, 1)
		for _ = 1, 6 do
			R.turnaround(s, 1)
		end
		t.eq(#s.PendingCasts, 0, "cooldown cannot be bypassed by repeated turns")
		R.tick(s, 6.15)
		R.turnaround(s, 1)
		R.tick(s, 0.86)
		t.near(f.Hp - before, f.MaxHp * 2 * d.Balance.CombatRelease.Kits.hourglass.Heal, 1e-6, "round healing budget")
		R.tick(s, 10)
		for _ = 1, 12 do
			R.turnaround(s, 1)
		end
		t.eq(#s.PendingCasts, 0, "at most two heals")
		t.eq(f.Signature.CastsStarted, 2)
	end)
	t.test("Hourglass cannot overheal, revive or finish a heal after overtime starts", function()
		local function armed()
			local s = fight("hourglass", "jam")
			s.Fighters[1].Hp = s.Fighters[1].MaxHp * 0.6
			for _ = 1, 3 do
				R.turnaround(s, 1)
			end
			return s
		end
		local full = armed()
		full.Fighters[1].Hp = full.Fighters[1].MaxHp * 0.99
		R.tick(full, 0.86)
		t.eq(full.Fighters[1].Hp, full.Fighters[1].MaxHp)
		local dead = armed()
		dead.Fighters[1].Hp = 0
		R.tick(dead, 0.86)
		t.eq(dead.Fighters[1].Hp, 0)
		t.ok(dead.Over)
		local overtime = armed()
		overtime.Time = d.Balance.Fight.OvertimeAt - 0.1
		local hp = overtime.Fighters[1].Hp
		R.tick(overtime, 0.2)
		t.eq(overtime.Fighters[1].Hp, hp)
		for _ = 1, 9 do
			R.turnaround(overtime, 1)
		end
		t.eq(#overtime.PendingCasts, 0)
	end)
	t.test("cone and fan are bounded in 3D", function()
		t.ok(Geometry.coneSphere(V.zero, V.xAxis, 5, 1, V.new(3, 0, 0), 0.2))
		t.ok(not Geometry.coneSphere(V.zero, V.xAxis, 5, 1, V.new(-1, 0, 0), 0.2))
		t.ok(not Geometry.coneSphere(V.zero, V.xAxis, 5, 1, V.new(3, 0, 3), 0.2))
		t.ok(not Geometry.coneSphere(V.zero, V.xAxis, 5, 1, V.new(6, 0, 0), 0.2))
		t.near(Geometry.fanDirection(V.xAxis, 2, 3, 0.5, V.yAxis).X, 1, 1e-6)
	end)
	t.test("mid-cast bootstrap preserves locked geometry and resolved pulse IDs", function()
		local sim = Pendulum.new(
			{ A = { Id = "lemonade_bottle" }, B = { Id = "jam" }, Rng = d.Rng.new(777), ReleaseKits = true },
			777
		)
		sim.Fight.Fighters[1].Signature.NextReady = 0
		R.tick(sim.Fight, 0.01)
		R.tick(sim.Fight, 0.4)
		local cast = R.drainCasts(sim.Fight)[1]
		R.releaseCast(sim.Fight, cast, { 1, 2, 3 }, { 1, 0, 0 })
		R.resolveAbility(sim.Fight, cast.Id, false, nil, 1)
		local events = Pendulum.presentation(sim)
		t.eq(#events, 1)
		t.eq(events[1].Origin[3], 3)
		t.eq(events[1].Resolved[1], true)
		R.resolveAbility(sim.Fight, cast.Id, false, nil, 2)
		R.resolveAbility(sim.Fight, cast.Id, false, nil, 3)
		t.eq(#Pendulum.presentation(sim), 0, "expired volley not replayed")
	end)
	t.test("all release kits complete deterministic swings with unique results and fixed strings", function()
		for i, def in d.Glassies.ReleaseList do
			local sim = Pendulum.new({
				A = { Id = def.Id, Aim = 0.9 },
				B = { Id = "jam", Aim = 0.85 },
				Rng = d.Rng.new(3000 + i),
				ReleaseKits = true,
			}, 3000 + i)
			local seen = {}
			for step = 1, 4600 do
				if script and step % 500 == 0 then
					task.wait()
				end
				Pendulum.step(sim, 1 / 60)
				for _, e in Pendulum.events(sim) do
					if e.Type == "CastContact" then
						local key = e.CastId .. ":" .. e.Pulse
						t.ok(not seen[key], def.Id .. " duplicated result")
						seen[key] = true
					end
				end
				if sim.Fight.Over then
					break
				end
			end
			t.ok(sim.Fight.Over, def.Id .. " did not settle")
			t.ok(sim.Metrics.MaxRadiusError < 0.00001, def.Id .. " string constraint")
		end
	end)
end
