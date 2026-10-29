-- The arena layer (decision 122): twists, the Heat, PUSH, glints, Last Glass, and the real swing's half.
local Pendulum = if script
	then require(game.ServerScriptService.Server.Simulation.Pendulum)
	else require("../server/Simulation/Pendulum")

return function(t, d)
	local Rules, Arena, A = d.FightRules, d.ArenaRules, d.Balance.Arena
	local previousArena = A.Enabled
	A.Enabled = true -- dormant arena package remains covered, explicitly opt-in

	local function fight(opts: { [string]: any }?)
		local o = opts or {}
		return Rules.new({
			A = { Id = o.A or "pop", LastGlass = o.LastGlassA, CastPolicy = "player" },
			B = { Id = o.B or "jam", CastPolicy = "player" },
			Rng = d.Rng.new(o.Seed or 3),
			Twist = o.Twist,
			CastsManaged = o.Managed,
		})
	end

	local function find(events, kind)
		for _, e in events do
			if e.Type == kind then
				return e
			end
		end
		return nil
	end

	t.test("twists roll from the table and never repeat back to back", function()
		local rng = d.Rng.new(9)
		local last
		for _ = 1, 300 do
			local twist = Arena.rollTwist(rng, last)
			t.ok(A.Twists[twist] ~= nil, "known twist " .. twist)
			t.ok(twist ~= last, "no repeat")
			last = twist
		end
		t.eq(Arena.twist(fight({ Twist = "Nope" })), "Calm", "unknown twist falls back to Calm")
		t.eq(find(Rules.drainEvents(fight({ Twist = "Magnet" })), "Twist").Kind, "Magnet", "announced")
	end)

	t.test("the Heat warms up, then melts down at overtime", function()
		local s = fight({ Managed = true })
		local stages = {}
		while s.Time < d.Balance.Fight.OvertimeAt + 0.5 and not s.Over do
			Rules.tick(s, 0.05)
			for _, e in Rules.drainEvents(s) do
				if e.Type == "Heat" then
					stages[e.Stage] = e.Time
				end
			end
		end
		t.near(stages[1], A.Heat.WarmAt, 0.06, "HEATING UP")
		t.near(stages[2], d.Balance.Fight.OvertimeAt, 0.06, "MELTDOWN")
		t.ok(Rules.swingMultiplier(s, 1) > 1, "meltdown swings higher")
	end)

	t.test("PUSH has charges, a cooldown and a recharge, and nothing while frozen", function()
		local s = fight({ Managed = true })
		t.ok(Rules.requestPush(s, 1), "first push")
		t.ok(not Rules.requestPush(s, 1), "cooldown")
		Rules.tick(s, A.Push.Cooldown + 0.01)
		t.ok(Rules.requestPush(s, 1), "second push")
		Rules.tick(s, A.Push.Cooldown + 0.01)
		t.ok(Rules.requestPush(s, 1), "third push")
		Rules.tick(s, A.Push.Cooldown + 0.01)
		t.ok(not Rules.requestPush(s, 1), "out of charges")
		t.eq(#Arena.drainImpulses(s), 3, "three shoves for the swing")
		Rules.tick(s, A.Push.RechargeSeconds)
		t.eq(Arena.pushCharges(s, 1), 1, "one charge came back")
		t.eq(Arena.pushCharges(s, 2), A.Push.Charges, "the other side is untouched")
		s.Fighters[2].FrozenUntil = s.Time + 2
		t.ok(not Rules.requestPush(s, 2), "frozen")
		t.ok(not Rules.requestPush(s, 3), "bad side")
	end)

	t.test("Smash boosts the next hit only; Bubble blocks the next damage only", function()
		local plain = fight({ Seed = 5, Managed = true })
		Rules.hit(plain, 20, 0.5)
		local base = find(Rules.drainEvents(plain), "Hit").Damage[2]
		local s = fight({ Seed = 5, Managed = true })
		Rules.drainEvents(s)
		s.Arena.Glints = { { Id = 1, Kind = "Smash", Point = { 0, 0, 0 }, Until = 9 } }
		t.ok(Rules.grabGlint(s, 1, 1), "grabbed")
		t.ok(not Rules.grabGlint(s, 2, 1), "only once")
		Rules.hit(s, 20, 0.5)
		t.near(find(Rules.drainEvents(s), "Hit").Damage[2], base * A.Glints.Kinds.Smash.DamageMult, 1e-6, "smash")
		t.ok(not s.Fighters[1].GlintSmash, "used up")

		s.Arena.Glints = { { Id = 2, Kind = "Bubble", Point = { 0, 0, 0 }, Until = 9 } }
		Rules.grabGlint(s, 2, 2)
		local hp = s.Fighters[2].Hp
		Rules.hit(s, 20, 0.5)
		local events = Rules.drainEvents(s)
		t.eq(s.Fighters[2].Hp, hp, "bubble ate the hit")
		t.ok(find(events, "GlintBlock") ~= nil, "block shown")
		Rules.hit(s, 20, 0.5)
		t.ok(s.Fighters[2].Hp < hp, "the next hit lands")
	end)

	t.test("a Bomb pops on the other glass after its fuse; Patch heals; Frost slows", function()
		local s = fight({ Managed = true })
		s.Arena.Glints = {
			{ Id = 1, Kind = "Bomb", Point = { 0, 0, 0 }, Until = 9 },
			{ Id = 2, Kind = "Patch", Point = { 0, 0, 0 }, Until = 9 },
			{ Id = 3, Kind = "Frost", Point = { 0, 0, 0 }, Until = 9 },
		}
		Rules.grabGlint(s, 1, 1)
		local hp = s.Fighters[2].Hp
		Rules.tick(s, A.Glints.Kinds.Bomb.Fuse - 0.1)
		t.eq(s.Fighters[2].Hp, hp, "still fusing")
		Rules.tick(s, 0.2)
		local pop = find(Rules.drainEvents(s), "BombPop")
		t.ok(pop ~= nil and pop.Side == 2, "popped on the foe")
		t.near(hp - s.Fighters[2].Hp, s.Fighters[2].MaxHp * A.Glints.Kinds.Bomb.Damage, 0.5, "bomb damage")
		s.Fighters[2].Hp = s.Fighters[2].MaxHp * 0.5
		Rules.grabGlint(s, 2, 2)
		t.near(s.Fighters[2].Hp, s.Fighters[2].MaxHp * (0.5 + A.Glints.Kinds.Patch.Heal), 1e-6, "patched")
		local before = Rules.swingMultiplier(s, 2)
		Rules.grabGlint(s, 1, 3)
		-- Release kits floor every slow at CombatRelease.SlowFloor.
		local floor = d.Balance.CombatRelease.SlowFloor
		t.near(Rules.swingMultiplier(s, 2), math.max(floor, before * A.Glints.Kinds.Frost.SwingMult), 1e-6, "frosted")
	end)

	t.test("a clash right after a PUSH or a Zoom hits harder, and a frosted glass is brittle", function()
		local function hit(prepare)
			local s = fight({ Seed = 8, Managed = true })
			Rules.drainEvents(s)
			prepare(s)
			Rules.hit(s, 20, 0.5)
			return find(Rules.drainEvents(s), "Hit").Damage[2]
		end
		local base = hit(function() end)
		t.near(
			hit(function(s)
				Rules.requestPush(s, 1)
			end),
			base * A.Push.HitMult,
			1e-6,
			"push window"
		)
		local late = hit(function(s)
			Rules.requestPush(s, 1)
			Rules.tick(s, A.Push.HitSeconds + 0.05)
		end)
		t.ok(late < base * A.Push.HitMult - 1e-6, "the push window closes")
		t.near(
			hit(function(s)
				s.Arena.Glints = { { Id = 1, Kind = "Zoom", Point = { 0, 0, 0 }, Until = 9 } }
				Rules.grabGlint(s, 1, 1)
			end),
			base * A.Glints.Kinds.Zoom.DamageMult,
			1e-6,
			"zoom window"
		)
		t.near(
			hit(function(s)
				s.Arena.Glints = { { Id = 1, Kind = "Frost", Point = { 0, 0, 0 }, Until = 9 } }
				Rules.grabGlint(s, 1, 1)
			end),
			base * A.Glints.Kinds.Frost.Brittle,
			1e-6,
			"brittle"
		)
	end)

	t.test("Last Glass starts the round with a thin shield that soaks some damage, then pops", function()
		local s = fight({ LastGlassA = true, Managed = true })
		local grab = find(Rules.drainEvents(s), "GlintGrab")
		t.ok(grab ~= nil and grab.Side == 1 and grab.LastGlass, "shown from the release")
		local f = s.Fighters[1]
		local pool = f.MaxHp * A.LastGlassShield
		t.near(f.GlassShield, pool, 1e-9, "pool")
		local plain = fight({ Seed = 3, Managed = true })
		Rules.hit(plain, 20, 0.5)
		local full = find(Rules.drainEvents(plain), "Hit").Damage[1]
		Rules.hit(s, 20, 0.5)
		local first = find(Rules.drainEvents(s), "Hit").Damage[1]
		t.near(first, math.max(0, full - pool), 1e-6, "the shield soaked the hit")
		local popped = false
		for _ = 1, 6 do
			Rules.hit(s, 20, 0.5)
			popped = popped or find(Rules.drainEvents(s), "GlintBlock") ~= nil
		end
		t.ok(f.GlassShield <= 0 and (popped or first > 0), "used up")
	end)

	t.test("matches roll a twist each round, keep last pick and aim, and flag Last Glass and On Fire", function()
		local Logic = d.MatchLogic
		local collection = { pop = {}, jam = {}, prism = {}, crescent_axe = {} }
		local m = Logic.new({ { Collection = collection }, { Collection = collection, IsBot = true } }, d.Rng.new(12))
		Logic.startRound(m)
		local first = m.Twist
		t.ok(A.Twists[first] ~= nil, "round 1 twist")
		local pick = m.Sides[1].Offers[2]
		Logic.pick(m, 1, pick)
		Logic.setAim(m, 1, 1.1, 0.2)
		Logic.autoPick(m, 2)
		t.eq(Logic.fightSetup(m).Twist, first, "twist reaches the fight")
		Logic.endRound(m, 1)
		Logic.startRound(m)
		t.ok(m.Twist ~= first, "a different twist next round")
		t.eq(Logic.autoPick(m, 1), pick, "keeps last round's glassy")
		t.near(Logic.autoAim(m, 1), 1.1, 1e-9, "keeps last round's aim")
		t.near(m.Sides[1].AimYaw, 0.2, 1e-9, "and yaw")
		Logic.autoPick(m, 2)
		Logic.endRound(m, 1)
		Logic.startRound(m)
		Logic.autoPick(m, 1)
		Logic.autoPick(m, 2)
		local setup = Logic.fightSetup(m)
		t.ok(setup.A.OnFire, "two round wins in a row")
		t.ok(not setup.B.OnFire, "loser is not on fire")
		t.ok(setup.B.LastGlass, "one heart left vs three")
		t.ok(not setup.A.LastGlass, "the leader gets no help")
		Logic.endRound(m, 2)
		t.eq(m.Sides[1].Streak, 0, "a loss ends the streak")
	end)

	t.test("the stand-in simulator spawns and settles glints without positions", function()
		local s = fight()
		local spawned, grabbed = 0, 0
		while s.Time < 20 and not s.Over do
			Rules.tick(s, 0.05)
			for _, e in Rules.drainEvents(s) do
				grabbed += if e.Type == "GlintGrab" then 1 else 0
			end
			spawned = s.Arena.GlintSerial
		end
		t.ok(spawned >= 4, "glints keep coming")
		t.ok(grabbed >= 1, "some get grabbed")
	end)

	t.test("on the real swing glints sit in the clash zone and get grabbed; bumpers bounce", function()
		local function run(twist, seed)
			local sim = Pendulum.new({
				A = { Id = "pop", Aim = 0.9, AimYaw = 0.3 },
				B = { Id = "jam", Aim = 0.9, AimYaw = -0.2 },
				Rng = d.Rng.new(seed),
				SweetSpot = 0.9,
				Twist = twist,
			}, seed)
			local counts, points = {}, {}
			while not sim.Fight.Over do
				Pendulum.step(sim, 1 / d.Balance.Motion.StepRate)
				for _, e in Pendulum.events(sim) do
					counts[e.Type] = (counts[e.Type] or 0) + 1
					if e.Type == "GlintSpawn" then
						table.insert(points, e.Point)
					end
				end
			end
			return counts, points, sim
		end
		local counts, points, sim = run("Calm", 41)
		t.ok((counts.GlintSpawn or 0) >= 2, "glints spawn")
		t.ok((counts.GlintGrab or 0) >= 1, "glints get grabbed")
		t.ok((counts.Push or 0) >= 1, "simulator sides push")
		for _, p in points do
			t.ok(math.abs(p[1]) <= A.Glints.SpreadX + 1e-6 and p[2] < -5, "between the glassies, below the bar")
		end
		t.ok(sim.Fight.Time < d.Balance.Fight.RoundTimeout, "ends before the timeout")
		local bumps = run("Bumpers", 42)
		t.ok((bumps.Bump or 0) >= 1, "bumpers bounce")
		local again = run("Bumpers", 42)
		t.eq(again.Bump, bumps.Bump, "deterministic")
		t.eq(again.Hit, bumps.Hit, "deterministic hits")
	end)
	A.Enabled = previousArena
end
