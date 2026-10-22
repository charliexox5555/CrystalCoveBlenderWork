-- Roster V2 launch powers (decision 88): new shapes and field extensions.
local Pendulum = if script
	then require(game.ServerScriptService.Server.Simulation.Pendulum)
	else require("../server/Simulation/Pendulum")

return function(t, deps)
	local Rules, Balance = deps.FightRules, deps.Balance
	local function fight(a, b, policyA)
		return Rules.new({
			A = { Id = a, CastPolicy = policyA },
			B = { Id = b },
			Rng = function()
				return 0.01
			end,
			ReleaseKits = true,
			CastsManaged = true,
		})
	end
	local function drain(state, kind)
		local out = {}
		for _, e in Rules.drainEvents(state) do
			if not kind or e.Type == kind then
				table.insert(out, e)
			end
		end
		return out
	end

	t.test("every launch glassy has a definition, kit and geometry", function()
		for _, id in
			{
				"fishbowl",
				"cookie_jar",
				"glass_top",
				"bubble_wand",
				"piggy_bank",
				"light_bulb",
				"potion_flask",
				"honey_bear",
				"crystal_ball",
				"grizzly_guardian",
				"glass_unicorn",
				"glass_phoenix",
			}
		do
			local s = fight(id, "pop")
			t.ok(s.Fighters[1].Signature ~= nil, id .. " kit")
			t.ok(s.Fighters[1].Radius > 0, id .. " geometry")
			t.ok(deps.Glassies.isRelease(id), id .. " is in the live roster (installed at v4)")
		end
	end)

	t.test("Fishbowl's heavy trigger starts a projectile, not an armed counter", function()
		local s = fight("fishbowl", "jam")
		s.Fighters[2].Power = 60
		Rules.hit(s, 30, 0)
		t.eq(#s.PendingCasts, 1)
		t.eq(s.PendingCasts[1].Shape, "projectile")
	end)

	t.test("Piggy Bank waits until half full and reads its savings at cast", function()
		local s = fight("piggy_bank", "pop", "player")
		local f, kit = s.Fighters[1], Balance.CombatRelease.Kits.piggy_bank
		f.Signature.Stored = f.MaxHp * kit.StoreCap * (kit.ReadyAt - 0.1)
		Rules.turnaround(s, 1)
		t.eq(Rules.ready(s, 1), nil, "not Ready below ReadyAt")
		f.Signature.Stored = f.MaxHp * kit.StoreCap * (kit.ReadyAt + 0.01)
		Rules.turnaround(s, 1)
		t.ok(Rules.ready(s, 1) ~= nil, "Ready at half")
		f.Signature.Stored = f.MaxHp * kit.StoreCap -- kept filling while Ready
		Rules.requestCast(s, 1)
		Rules.tick(s, 0.01)
		t.near(s.PendingCasts[1].Params.Damage, math.min(kit.Damage, f.MaxHp * kit.StoreCap / f.Power), 1e-9)
		t.eq(f.Signature.Stored, 0)
	end)

	t.test("Potion Flask cycles brews and arms its contact brews", function()
		local s = fight("potion_flask", "pop")
		local sig = s.Fighters[1].Signature
		local first = (sig.CycleCount + sig.CycleOffset) % 3 + 1
		for _ = 1, 3 do
			Rules.turnaround(s, 1)
		end
		local shape = Balance.CombatRelease.Kits.potion_flask.Cycle[first].Shape
		if shape == "heal" then
			t.eq(s.PendingCasts[1].Params.Brew, first)
		else
			t.ok(sig.Armed ~= nil, "contact brew armed")
			t.eq(sig.Armed.Kit.Brew, first)
		end
		t.eq(sig.CycleCount, 1)
	end)

	t.test("Light Bulb's armed clash drains the foe's charge, but not a Ready foe", function()
		local s = fight("light_bulb", "jam")
		for _ = 1, Balance.CombatRelease.Kits.light_bulb.Every do
			Rules.hit(s, 10, 0.5)
		end
		t.ok(s.Fighters[1].Signature.Armed ~= nil, "armed once charged")
		s.Fighters[2].Signature.Charge = 1
		s.Fighters[2].Signature.BusyUntil = -1
		Rules.hit(s, 10, 0.5)
		local drains = drain(s, "SignatureStatus")
		local found = false
		for _, e in drains do
			found = found or e.Kind == "Drain"
		end
		t.ok(found, "drain event")
		t.eq(s.Fighters[2].Signature.Charge, 0)
	end)

	t.test("Grizzly's guard roars back instantly when it blocks", function()
		local s = fight("grizzly_guardian", "pop")
		for _ = 1, 3 do
			Rules.hit(s, 4, 0.5)
		end
		Rules.turnaround(s, 1) -- received charge releases at the next turnaround
		local guard = s.PendingCasts[1]
		t.eq(guard and guard.Shape, "guard")
		Rules.tick(s, guard.Params.Windup + 0.01)
		t.ok(s.Fighters[1].Signature.GuardUntil > s.Time)
		Rules.drainEvents(s)
		Rules.hit(s, 10, 0.5)
		local riposte = false
		for _, e in drain(s, "CastStart") do
			riposte = riposte or e.Shape == "pulse"
		end
		t.ok(riposte, "riposte pulse started")
	end)

	t.test("Glass Unicorn's empowered clash pierces a guard", function()
		local s = fight("glass_unicorn", "jam")
		s.Fighters[2].Signature.GuardUntil = 10
		s.Fighters[1].Signature.ContactBonus = 0.3
		Rules.drainEvents(s)
		Rules.hit(s, 10, 0.5)
		local pierced = false
		for _, e in drain(s, "SignatureStatus") do
			pierced = pierced or e.Kind == "Pierce"
		end
		t.ok(pierced)
		t.eq(s.Fighters[2].Signature.GuardUntil, -1)
	end)

	t.test("Glass Unicorn's dash pays +ContactBonus on the next clash, or fades with a BoostFade", function()
		local kit = Balance.CombatRelease.Kits.glass_unicorn
		local function dash()
			local s = fight("glass_unicorn", "jam")
			for _ = 1, kit.Every do
				Rules.turnaround(s, 1)
			end
			t.eq(s.PendingCasts[1] and s.PendingCasts[1].Shape, "boost")
			Rules.tick(s, kit.Windup + 0.01)
			t.ok(s.Fighters[1].Signature.BoostUntil > s.Time, "boosting")
			Rules.drainEvents(s)
			return s
		end
		local function kinds(s)
			local out = {}
			for _, e in drain(s) do
				out[e.Type .. ":" .. tostring(e.Kind or e.Shape)] = true
			end
			return out
		end
		-- Landed: the clash is boosted and no fade follows.
		local s = dash()
		local plain = fight("glass_unicorn", "jam")
		Rules.hit(s, 20, 0.5)
		Rules.hit(plain, 20, 0.5)
		local hit = kinds(s)
		t.ok(hit["SignatureContact:armed_contact"], "payoff event")
		local dealt = s.Fighters[2].MaxHp - s.Fighters[2].Hp
		local plainDealt = plain.Fighters[2].MaxHp - plain.Fighters[2].Hp
		t.near(dealt / plainDealt, 1 + kit.ContactBonus, 1e-6)
		Rules.tick(s, kit.Duration + 0.1)
		t.ok(not kinds(s)["SignatureStatus:BoostFade"], "no fade after a landed dash")
		-- Whiffed: the boost runs out and says so.
		s = dash()
		Rules.tick(s, kit.Duration + 0.1)
		t.ok(kinds(s)["SignatureStatus:BoostFade"], "fade after a whiffed dash")
		t.ok(s.Fighters[1].Signature.BoostUntil < s.Time, "boost over")
	end)

	t.test("Glass Phoenix is reborn once at low HP and its feathers become a volley", function()
		local s = fight("glass_phoenix", "pop")
		local f = s.Fighters[1]
		f.Hp = f.MaxHp * 0.31
		Rules.hit(s, 20, 0)
		t.ok(f.Signature.Reborn, "rebirth triggered")
		t.ok(#s.PendingCasts >= 1 and s.PendingCasts[#s.PendingCasts].Params.IsRebirth, "flare cast")
		t.eq(f.Signature.Kit.Shape, "volley", "phase 2 feathers")
		local before = f.Hp
		Rules.tick(s, Balance.CombatRelease.Kits.glass_phoenix.Rebirth.Windup + 0.01)
		t.ok(f.Hp > before, "self-heal on release")
	end)

	t.test("zones, spins and dashes resolve in the real swing", function()
		for _, pair in
			{
				{ "bubble_wand", "jam" },
				{ "crystal_ball", "pop" },
				{ "honey_bear", "prism" },
				{ "glass_top", "pop" },
				{ "glass_unicorn", "jam" },
			}
		do
			local sim = Pendulum.new({
				A = { Id = pair[1], CastPolicy = "smart" },
				B = { Id = pair[2], CastPolicy = "smart" },
				Rng = deps.Rng.new(9),
			}, 9)
			local releases = 0
			while not sim.Fight.Over do
				Pendulum.step(sim, 1 / Balance.Motion.StepRate)
				for _, e in Pendulum.events(sim) do
					if e.Side == 1 and (e.Type == "CastRelease" or e.Type == "SignatureStatus") then
						releases += 1
					end
				end
			end
			t.ok(releases > 0, pair[1] .. " released in a real round")
		end
	end)
end
