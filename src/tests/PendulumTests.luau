local Pendulum = if script
	then require(game.ServerScriptService.Server.Simulation.Pendulum)
	else require("../server/Simulation/Pendulum")

return function(t, d)
	local function new(seed)
		return Pendulum.new({
			A = { Id = "pop", Aim = 0.9, AimYaw = 0.4 },
			B = { Id = "prism", Aim = 0.9, AimYaw = -0.3 },
			Rng = d.Rng.new(seed),
			SweetSpot = 0.9,
		}, seed)
	end
	t.test("strings stay fixed, velocity tangent, bodies below the bar and contacts separated", function()
		local sim = new(101)
		for _ = 1, 1200 do
			Pendulum.step(sim, 1 / d.Balance.Motion.StepRate)
			for _, b in sim.Bodies do
				t.near(b.P.Magnitude, d.Balance.Motion.StringLength, 0.00001)
				t.near(b.P.Unit:Dot(b.V), 0, 0.0001)
				t.ok(b.P.Y < 0, "never wraps over the bar")
				t.ok(b.V.Magnitude < 100, "no unstable impulses")
			end
			local radius = (sim.Fight.Fighters[1].Radius + sim.Fight.Fighters[2].Radius) * d.Balance.Motion.GlassyScale
			t.ok(
				(Pendulum.center(sim, 1) - Pendulum.center(sim, 2)).Magnitude >= radius - 0.08,
				"no persistent overlap"
			)
		end
		t.ok(sim.Fight.Hits > 0, "the glassies meet")
	end)
	t.test("a seeded replay reproduces motion, HP and event order", function()
		local a, b = new(42), new(42)
		for _ = 1, 600 do
			Pendulum.step(a, 1 / 60)
			Pendulum.step(b, 1 / 60)
			local ea, eb = Pendulum.events(a), Pendulum.events(b)
			t.eq(#ea, #eb)
			for i, e in ea do
				t.eq(e.Type, eb[i].Type)
				t.eq(e.Time, eb[i].Time)
			end
		end
		for side = 1, 2 do
			t.eq(a.Bodies[side].P, b.Bodies[side].P)
			t.eq(a.Fight.Fighters[side].Hp, b.Fight.Fighters[side].Hp)
		end
	end)
	t.test("frozen bodies lose energy and stop driving", function()
		local sim = new(202)
		sim.Fight.Fighters[1].FrozenUntil = 100
		sim.Fight.Fighters[2].FrozenUntil = 100
		for _ = 1, 180 do
			Pendulum.step(sim, 1 / 60)
		end
		for _, b in sim.Bodies do
			t.ok(b.V.Magnitude < 2, "frozen swing settles")
		end
	end)
end
