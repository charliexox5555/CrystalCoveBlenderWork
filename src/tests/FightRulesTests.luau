-- Unit tests for FightRules (damage, powers, specials, shatter and timeout rules).

return function(t, deps)
	local Balance, FightRules, Rng = deps.Balance, deps.FightRules, deps.Rng
	local F = Balance.Fight

	local function fight(idA: string, idB: string, opts: { [string]: any }?)
		local o = opts or {}
		return FightRules.new({
			ReleaseKits = false, -- retained legacy rules regression; release kits have dedicated suites
			A = { Id = idA, Aim = o.AimA, AimYaw = o.YawA },
			B = { Id = idB, Aim = o.AimB },
			Rng = o.Rng or Rng.new(o.Seed or 1),
			SweetSpot = o.SweetSpot,
			PowerLands = o.PowerLands,
		})
	end

	local function fire(state, side: number)
		t.ok(FightRules.triggerPower(state, side), "power fires")
	end

	local function count(events, eventType: string): number
		local n = 0
		for _, e in events do
			if e.Type == eventType then
				n += 1
			end
		end
		return n
	end

	t.test("same seed and inputs give the same fight", function()
		local function play(seed: number)
			local s = fight("pop", "prism", { Seed = seed })
			local log = {}
			while not s.Over do
				FightRules.tick(s, 0.1)
				if s.Time % 1 < 0.1 then
					FightRules.hit(s, 20, 0.5)
				end
				table.insert(log, string.format("%.4f/%.4f", s.Fighters[1].Hp, s.Fighters[2].Hp))
			end
			return table.concat(log, ",") .. tostring(s.Winner)
		end
		t.eq(play(3), play(3), "deterministic")
	end)

	t.test("a hit damages both glassies; faster hits hurt more", function()
		local s = fight("pop", "pop", {
			Rng = function()
				return 0.99 -- no crits, top of the variance range
			end,
		})
		FightRules.hit(s, 10, 0.5)
		local slow = s.Fighters[2].MaxHp - s.Fighters[2].Hp
		t.ok(s.Fighters[1].Hp < s.Fighters[1].MaxHp and slow > 0, "both damaged")
		local s2 = fight("pop", "pop", {
			Rng = function()
				return 0.99
			end,
		})
		FightRules.hit(s2, 30, 0.5)
		t.ok(s2.Fighters[2].MaxHp - s2.Fighters[2].Hp > slow, "faster hit, more damage")
	end)

	t.test("the glassy that moved into the hit deals more", function()
		local s = fight("pop", "pop", {
			Rng = function()
				return 0.99
			end,
		})
		FightRules.hit(s, 20, 0.9)
		t.ok(s.Fighters[2].Hp < s.Fighters[1].Hp, "side 1 swung harder")
	end)

	t.test("bad inputs from the swing code are ignored", function()
		local s = fight("pop", "jam")
		FightRules.hit(s, 0 / 0, 0.5)
		FightRules.hit(s, math.huge, 0.5)
		FightRules.tick(s, 0 / 0)
		t.eq(s.Fighters[1].Hp, s.Fighters[1].MaxHp, "no damage from NaN/inf")
		t.eq(s.Time, 0, "no time from NaN")
	end)

	t.test("aim is clamped and Perfect Release is detected", function()
		t.eq(FightRules.clampAim(99), Balance.Motion.AimMax, "max")
		t.eq(FightRules.clampAim(0 / 0), Balance.Motion.AimDefault, "NaN -> default")
		t.eq(FightRules.clampAim("x"), Balance.Motion.AimDefault, "string -> default")
		local s = fight("pop", "jam", { AimA = 0.8, AimB = 1.25, SweetSpot = 0.8 })
		t.ok(s.Fighters[1].Perfect and not s.Fighters[2].Perfect, "only side 1 perfect")
		t.ok(
			s.Fighters[1].NextPowerAt <= F.PowerFirstMax - F.PerfectPowerAdvance + 1e-9,
			"perfect brings the first power sooner"
		)
		t.eq(FightRules.clampYaw(5), Balance.Motion.AimYawMax, "yaw clamped")
		t.eq(FightRules.clampYaw(0 / 0), 0, "NaN yaw -> 0")
		t.eq(s.Fighters[1].AimYaw, 0, "default yaw")
		t.eq(count(FightRules.drainEvents(s), "PerfectRelease"), 1, "event")
		local rng = Rng.new(5)
		for _ = 1, 200 do
			local spot = FightRules.rollSweetSpot(rng)
			t.ok(spot - Balance.Motion.SweetSpotWidth >= Balance.Motion.AimMin - 1e-9, "band fits low")
			t.ok(spot + Balance.Motion.SweetSpotWidth <= Balance.Motion.AimMax + 1e-9, "band fits high")
			t.ok(FightRules.isPerfect(FightRules.botAim(spot, 1, rng), spot), "skill-1 bots aim perfectly")
		end
	end)

	t.test("powers fire by themselves, repeat, and come sooner with hits", function()
		local s = fight("pop", "jam")
		local fired, firstAt = { 0, 0 }, nil
		while not s.Over and s.Time < 60 do
			FightRules.tick(s, 0.05)
			for _, e in FightRules.drainEvents(s) do
				if e.Type == "Power" then
					fired[e.Side] += 1
					firstAt = firstAt or e.Time
				end
			end
		end
		t.ok(
			firstAt ~= nil and firstAt >= F.PowerFirstMin - 0.05 and firstAt <= F.PowerFirstMax + 0.05,
			"first power in its window"
		)
		t.eq(fired[1], F.PowerMaxPerRound, "side 1 hits the per-round cap")
		t.eq(fired[2], F.PowerMaxPerRound, "side 2 hits the per-round cap")
		local again, why = FightRules.triggerPower(s, 1)
		t.ok(not again and (why == "max" or why == "over"), "capped")
		t.ok(not FightRules.triggerPower(fight("pop", "jam"), 3), "bad side")

		local h = fight("pop", "jam", { Seed = 4 })
		local before = h.Fighters[1].NextPowerAt
		FightRules.hit(h, 20, 0.5)
		t.near(h.Fighters[1].NextPowerAt, before - F.PowerHitAdvance, 1e-9, "a hit brings the power closer")
		t.between(FightRules.powerProgress(h, 1), 0, 1, "progress for the UI glow")
	end)

	t.test("aimed powers can miss", function()
		local miss = fight("prism", "pop", {
			PowerLands = function()
				return false
			end,
		})
		fire(miss, 1)
		local events = FightRules.drainEvents(miss)
		t.ok(events[#events].Missed == true, "beam missed")
		t.eq(miss.Fighters[2].Hp, miss.Fighters[2].MaxHp, "no damage on a miss")
		local land = fight("prism", "pop", {
			PowerLands = function()
				return true
			end,
		})
		fire(land, 1)
		t.ok(land.Fighters[2].Hp < land.Fighters[2].MaxHp, "beam landed")
		local self = fight("jam", "pop", {
			PowerLands = function()
				return false
			end,
		})
		fire(self, 1)
		t.ok(FightRules.isShielded(self, 1), "self powers (shield) never miss")
	end)

	t.test("rage hits much harder for a few seconds", function()
		local fixed = function()
			return 0.5
		end
		local base = fight("hot_sauce", "pop", { Rng = fixed })
		FightRules.hit(base, 20, 0.5)
		local normal = base.Fighters[2].MaxHp - base.Fighters[2].Hp
		local r = fight("hot_sauce", "pop", { Rng = fixed })
		fire(r, 1)
		FightRules.hit(r, 20, 0.5)
		t.near(r.Fighters[2].MaxHp - r.Fighters[2].Hp, normal * 1.75, 0.5, "rage damage")
		FightRules.tick(r, 3.1)
		t.ok(not FightRules.snapshot(r).Rage[1], "rage ends")
	end)

	t.test("shield blocks hit damage and beam", function()
		local s = fight("jam", "prism", {
			PowerLands = function()
				return true
			end,
		})
		fire(s, 1)
		t.ok(FightRules.isShielded(s, 1), "shielded")
		fire(s, 2) -- beam
		FightRules.hit(s, 25, 0.5)
		t.eq(s.Fighters[1].Hp, s.Fighters[1].MaxHp, "no damage through shield")
		FightRules.tick(s, 3)
		t.ok(not FightRules.isShielded(s, 1), "shield ends")
	end)

	t.test("beam deals a fraction of max HP; glaze heals and clears cracks", function()
		local s = fight("prism", "milk_bottle", {
			PowerLands = function()
				return true
			end,
		})
		fire(s, 1)
		local foe = s.Fighters[2]
		t.near(foe.MaxHp - foe.Hp, foe.MaxHp * deps.Powers.Specials.beam.Params.MaxHpFraction, 1e-6, "beam damage")
		foe.Bleeds = { { PerSecond = 5, Remaining = 3 } }
		local hpBefore = foe.Hp
		fire(s, 2)
		local heal = foe.MaxHp * deps.Powers.Specials.glaze.Params.HealFraction
		t.near(foe.Hp, math.min(foe.MaxHp, hpBefore + heal), 1e-6, "healed (capped at max)")
		fire(s, 2)
		fire(s, 2)
		t.ok(foe.Hp <= foe.MaxHp, "never above max")
		t.eq(#foe.Bleeds, 0, "cracks sealed")
	end)

	t.test("slam multiplies the next hit only; freeze and pump change the swing", function()
		local fixed = function()
			return 0.5
		end
		local base = fight("pop", "pop", { Rng = fixed })
		FightRules.hit(base, 20, 0.5)
		local normal = base.Fighters[2].MaxHp - base.Fighters[2].Hp
		local s = fight("pop", "pop", { Rng = fixed })
		fire(s, 1)
		t.ok(FightRules.knockbackMultiplier(s, 2) > 1, "slam knocks back")
		FightRules.hit(s, 20, 0.5)
		t.near(
			s.Fighters[2].MaxHp - s.Fighters[2].Hp,
			normal * deps.Powers.Specials.slam.Params.DamageMult,
			0.5,
			"slam damage"
		)
		t.eq(FightRules.knockbackMultiplier(s, 2), 1, "slam used up")

		local f = fight("crystal_ball", "pop", {
			PowerLands = function()
				return true
			end,
		})
		fire(f, 1)
		t.ok(FightRules.isFrozen(f, 2) and not FightRules.isFrozen(f, 1), "freeze hits the other side")
		local p = fight("water_jug", "pop")
		fire(p, 1)
		t.ok(FightRules.swingMultiplier(p, 1) > 1, "pump swings higher")
	end)

	t.test("passives: sturdy, sharp edge, sticky, thorns, second wind", function()
		local fixed = function()
			return 0.5
		end
		local s = fight("pop", "jam", { Rng = fixed })
		local m = fight("pop", "pop", { Rng = fixed })
		FightRules.hit(s, 20, 0.5)
		FightRules.hit(m, 20, 0.5)
		-- jam (Heavy, sturdy) takes less than pop would, even though pop has type advantage
		t.ok(s.Fighters[2].MaxHp - s.Fighters[2].Hp < (m.Fighters[2].MaxHp - m.Fighters[2].Hp) * 1.04, "sturdy")

		local b = fight("prism", "pop", { Rng = fixed })
		FightRules.hit(b, 20, 0.5)
		t.eq(#b.Fighters[2].Bleeds, 1, "sharp edge cracks")
		local hp = b.Fighters[2].Hp
		FightRules.tick(b, 1)
		t.ok(b.Fighters[2].Hp < hp, "cracks chip away")

		local k = fight("pickle_jar", "pop", { Rng = fixed })
		FightRules.hit(k, 20, 0.5)
		t.ok(FightRules.swingMultiplier(k, 2) < 1, "sticky slows the other glass")

		local th = fight("jack_o_glass", "pop", { Rng = fixed })
		FightRules.hit(th, 20, 0.5)
		t.eq(count(FightRules.drainEvents(th), "Passive"), 1, "thorns reflects")

		local w = fight("message_bottle", "pop", { Rng = fixed })
		w.Fighters[1].Hp = 1
		FightRules.hit(w, 20, 0.5)
		t.ok(not w.Over and w.Fighters[1].Hp > 1, "second wind saves once")
		w.Fighters[1].Hp = 1
		FightRules.hit(w, 20, 0.5)
		t.ok(w.Over and w.Winner == 2, "but only once")
	end)

	t.test("shatter, double KO and timeout end the round once", function()
		local s = fight("pop", "pop", {
			Rng = function()
				return 0.5
			end,
		})
		s.Fighters[2].Hp = 1
		FightRules.hit(s, 20, 0.5)
		t.ok(s.Over and s.Winner == 1 and s.Reason == "Shatter", "shatter")
		local events = FightRules.drainEvents(s)
		t.eq(count(events, "Shatter"), 1, "one shatter event")
		t.eq(count(events, "End"), 1, "one end event")
		FightRules.hit(s, 20, 0.5)
		t.eq(#FightRules.drainEvents(s), 0, "nothing after the end")

		local d = fight("pop", "pop", {
			Rng = function()
				return 0.5
			end,
		})
		d.Fighters[1].Hp, d.Fighters[2].Hp = 1, 2
		FightRules.hit(d, 20, 0.5)
		t.ok(d.Over and d.Reason == "DoubleKO" and d.Winner == 2, "more HP before the hit wins a double KO")
		t.eq(d.Fighters[2].Hp, 1, "winner hangs on at 1 HP")

		local o = fight("pop", "jam")
		o.Fighters[2].Hp = o.Fighters[2].MaxHp * 0.5
		while not o.Over do
			FightRules.tick(o, 1)
		end
		t.ok(o.Reason == "Timeout" and o.Winner == 1, "timeout goes to the higher HP fraction")
		t.near(o.Time, F.RoundTimeout, 1, "at RoundTimeout")
	end)

	t.test("snapshot carries HP, power glow and effects", function()
		local s = fight("jam", "pop")
		local snap = FightRules.snapshot(s)
		t.eq(snap.Hp[1], s.Fighters[1].MaxHp, "hp")
		t.eq(snap.Shield[1], false, "no shield")
		t.eq(#snap.Power, 2, "power progress per side")
	end)
end
