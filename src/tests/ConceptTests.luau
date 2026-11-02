local Pendulum = if script
	then require(game.ServerScriptService.Server.Simulation.Pendulum)
	else require("../server/Simulation/Pendulum")

return function(t, d)
	local C = d.Balance.Concepts.Kits

	-- A real-swing round; `fighter` plays the concept kit against a plain rival that has lots of HP.
	local function run(fighter, rival, seconds, seed)
		local setup = {
			A = { Id = fighter, Aim = d.Balance.Motion.AimDefault, CastPolicy = "auto" },
			B = { Id = rival, Aim = d.Balance.Motion.AimDefault, CastPolicy = "auto" },
			SweetSpot = -10,
			Rng = d.Rng.new(seed or 11),
		}
		local sim = Pendulum.new(setup, seed or 11)
		if seconds then
			sim.Fight.Fighters[1].MaxHp, sim.Fight.Fighters[1].Hp = 1e6, 1e6
			sim.Fight.Fighters[2].MaxHp, sim.Fight.Fighters[2].Hp = 1e6, 1e6
		end
		local log, limit = {}, seconds or d.Balance.Fight.RoundTimeout + 1
		while not sim.Fight.Over and sim.Fight.Time < limit do
			Pendulum.step(sim, 1 / 60)
			for _, e in Pendulum.events(sim) do
				if e.Type == "Concept" then
					log[e.Action] = log[e.Action] or {}
					table.insert(log[e.Action], e)
				end
			end
		end
		return log, sim
	end

	t.test("Pop's pressure blasts its cap, sooner each time", function()
		local log = run("pop", "fishbowl", 30)
		t.ok(log.Blast and #log.Blast >= 2, "several blasts in a round")
		t.eq(log.Pressure[1].Needed, C.pop.Pressure[1])
		local last = log.Pressure[#log.Pressure]
		t.ok(last.Needed < C.pop.Pressure[1], "the fuse gets shorter")
	end)

	t.test("Jam's blobs glue the rival, then let go", function()
		local log, sim = run("jam", "fishbowl", 30)
		t.ok(log.Glue and #log.Glue >= 2, "glued more than once")
		t.ok(log.GlueTick and #log.GlueTick > 2, "being stuck hurts")
		t.ok(log.GlueEnd ~= nil, "it lets go")
		t.ok(sim.Concept[1].Count <= C.jam.Blobs)
	end)

	t.test("Prism's shots split further every time", function()
		local log = run("prism", "fishbowl", 30)
		t.ok(log.Rays and #log.Rays >= 5, "fires on a steady beat")
		for i, shot in log.Rays do
			t.eq(#shot.Rays, C.prism.Rays[math.min(i, #C.prism.Rays)])
		end
		t.ok(log.RaysHit ~= nil, "rays can land")
	end)

	t.test("Cup winds up and really swings faster", function()
		local log, sim = run("glass_cup", "fishbowl", 30)
		t.eq(sim.Concept[1].Stacks, C.glass_cup.MaxStacks)
		t.ok(#log.Wind == C.glass_cup.MaxStacks, "one wind per stack, then capped")
		t.ok(sim.Fight.Hits > 5, "still clashes at speed: " .. sim.Fight.Hits)
	end)

	t.test("Jug floods the pen and sends a wave", function()
		local log, sim = run("water_jug", "fishbowl", 30)
		t.ok(log.Tide and #log.Tide >= 4, "the water rises")
		t.ok(log.Wave and #log.Wave >= 1, "full water sends a wave")
		t.ok(log.WaveHit ~= nil or log.WaveDodge ~= nil, "a wave resolves")
		t.ok(sim.Concept.Water ~= nil)
	end)

	t.test("Ketchup squeezes more each time and bursts at full splats", function()
		local log = run("ketchup_bottle", "fishbowl", 30)
		t.ok(log.Squeeze and #log.Squeeze >= 3)
		for i, squeeze in log.Squeeze do
			t.eq(#squeeze.Drops, C.ketchup_bottle.Drops[math.min(i, #C.ketchup_bottle.Drops)])
		end
		t.ok(log.Burst and #log.Burst >= 1, "splats burst")
	end)

	t.test("Milk refills itself, but never past full or as a revive", function()
		local _, damaged = run("milk_bottle", "fishbowl", 1)
		local f = damaged.Fight.Fighters[1]
		f.Hp = f.MaxHp * 0.5
		t.near(d.FightRules.conceptHeal(damaged.Fight, 1, f.MaxHp * 2), f.MaxHp * 0.5, 1e-6)
		f.Hp = 0
		t.eq(d.FightRules.conceptHeal(damaged.Fight, 1, 10), 0, "no revive")
		local log, sim = run("milk_bottle", "pop", nil, 21)
		t.ok(log.TopUp and #log.TopUp >= 1, "pours during a round")
		for _, e in log.TopUp do
			t.ok(e.Time < d.Balance.Fight.OvertimeAt, "no pour in overtime")
		end
		t.ok(sim.Fight.Over, "a refill cannot hold a round open")
	end)
	t.test("Pickles fall in growing drops", function()
		local log = run("pickle_jar", "fishbowl", 30)
		t.ok(log.Rain and #log.Rain >= 4)
		for i, drop in log.Rain do
			t.eq(#drop.Drops, C.pickle_jar.Drops[math.min(i, #C.pickle_jar.Drops)])
		end
		t.ok(log.PickleHit ~= nil, "a pickle can land")
	end)
	t.test("Lemonade adds slices that really cut", function()
		local log, sim = run("lemonade_bottle", "fishbowl", 40)
		t.eq(sim.Concept[1].Stacks, C.lemonade_bottle.MaxSlices)
		t.ok(log.ZestHit ~= nil, "slices land")
	end)
	t.test("Mason swarm grows with clashes and hunts the rival", function()
		local log = run("mason_jar", "fishbowl", 30)
		t.ok(log.Flies and #log.Flies >= 3)
		t.eq(log.Flies[1].Count, 1)
		t.eq(log.Flies[#log.Flies].Count, C.mason_jar.MaxPerClash)
		t.ok(log.FlyHit ~= nil, "flies sting")
	end)
	t.test("Tumbler cubes stay until something swings into them", function()
		local log, sim = run("crystal_tumbler", "fishbowl", 40)
		t.ok(log.Cube and #log.Cube >= 3)
		t.ok(log.CubeHit ~= nil, "a cube can be hit")
		t.ok(#sim.Concept[1].Cubes <= C.crystal_tumbler.MaxCubes, "capped")
	end)
	t.test("Hot Sauce aura grows and burns in range", function()
		local log, sim = run("hot_sauce", "fishbowl", 40)
		t.eq(sim.Concept[1].Stacks, C.hot_sauce.MaxHeat)
		t.ok(log.Burn ~= nil, "burns when close")
	end)
	t.test("rounds run long enough to see abilities, and always end", function()
		local total, rounds = 0, 0
		local ids = { "pop", "jam", "prism", "glass_cup", "water_jug", "ketchup_bottle", "milk_bottle", "hot_sauce" }
		for i, a in ids do
			for j, b in ids do
				local _, sim = run(a, b, nil, i * 100 + j)
				t.ok(sim.Fight.Over, a .. " vs " .. b .. " finishes")
				total += sim.Fight.Time
				rounds += 1
			end
		end
		local mean = total / rounds
		t.ok(mean >= 22 and mean <= 45, "mean round length " .. mean)
	end)
end
