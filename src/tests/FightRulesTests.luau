-- Unit tests for FightRules (damage, powers, specials, shatter and timeout rules).

return function(t, deps)
	local Balance, FightRules, Rng = deps.Balance, deps.FightRules, deps.Rng
	local F = Balance.Fight

	local function fight(idA: string, idB: string, opts: { [string]: any }?)
		local o = opts or {}
		return FightRules.new({
			A = { Id = idA, Aim = o.AimA, AutoSpecial = o.AutoA },
			B = { Id = idB, Aim = o.AimB, AutoSpecial = o.AutoB },
			Rng = o.Rng or Rng.new(o.Seed or 1),
			SweetSpot = o.SweetSpot,
		})
	end

	local function charge(state, side: number)
		local f = state.Fighters[side]
		f.Charge, f.SpecialReady = 1, true
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
		local s = fight("pop", "pop", { Rng = function()
			return 0.99 -- no crits, top of the variance range
		end })
		FightRules.hit(s, 10, 0.5)
		local slow = s.Fighters[2].MaxHp - s.Fighters[2].Hp
		t.ok(s.Fighters[1].Hp < s.Fighters[1].MaxHp and slow > 0, "both damaged")
		local s2 = fight("pop", "pop", { Rng = function()
			return 0.99
		end })
		FightRules.hit(s2, 30, 0.5)
		t.ok(s2.Fighters[2].MaxHp - s2.Fighters[2].Hp > slow, "faster hit, more damage")
	end)

	t.test("the glassy that moved into the hit deals more", function()
		local s = fight("pop", "pop", { Rng = function()
			return 0.99
		end })
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
		t.near(s.Fighters[1].Charge, F.PerfectCharge, 1e-9, "perfect charge")
		t.eq(count(FightRules.drainEvents(s), "PerfectRelease"), 1, "event")
		local rng = Rng.new(5)
		for _ = 1, 200 do
			local spot = FightRules.rollSweetSpot(rng)
			t.ok(spot - Balance.Motion.SweetSpotWidth >= Balance.Motion.AimMin - 1e-9, "band fits low")
			t.ok(spot + Balance.Motion.SweetSpotWidth <= Balance.Motion.AimMax + 1e-9, "band fits high")
			t.ok(FightRules.isPerfect(FightRules.botAim(spot, 1, rng), spot), "skill-1 bots aim perfectly")
		end
	end)

	t.test("specials need charge, fire once, and charge over time", function()
		local s = fight("pop", "jam")
		local ok, why = FightRules.useSpecial(s, 1)
		t.ok(not ok and why == "charging", "not ready at start")
		for _ = 1, 400 do
			FightRules.tick(s, 0.1)
			if s.Fighters[1].SpecialReady then
				break
			end
		end
		t.ok(s.Fighters[1].SpecialReady, "charges with time")
		t.ok(FightRules.useSpecial(s, 1), "fires")
		local again, reason = FightRules.useSpecial(s, 1)
		t.ok(not again and reason == "used", "once per round")
		t.ok(not FightRules.useSpecial(s, 3), "bad side")
	end)

	t.test("shield blocks hit damage and beam", function()
		local s = fight("jam", "prism")
		charge(s, 1)
		charge(s, 2)
		t.ok(FightRules.useSpecial(s, 1), "shield up")
		t.ok(FightRules.isShielded(s, 1), "shielded")
		FightRules.useSpecial(s, 2) -- beam
		FightRules.hit(s, 25, 0.5)
		t.eq(s.Fighters[1].Hp, s.Fighters[1].MaxHp, "no damage through shield")
		FightRules.tick(s, 3)
		t.ok(not FightRules.isShielded(s, 1), "shield ends")
	end)

	t.test("beam deals a fraction of max HP; glaze heals and clears cracks", function()
		local s = fight("prism", "milk_bottle")
		charge(s, 1)
		FightRules.useSpecial(s, 1)
		local foe = s.Fighters[2]
		t.near(foe.MaxHp - foe.Hp, foe.MaxHp * 0.08, 1e-6, "beam damage")
		foe.Bleeds = { { PerSecond = 5, Remaining = 3 } }
		charge(s, 2)
		FightRules.useSpecial(s, 2)
		t.near(foe.Hp, foe.MaxHp, 1e-6, "healed back to full (capped)")
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
		charge(s, 1)
		FightRules.useSpecial(s, 1)
		t.ok(FightRules.knockbackMultiplier(s, 2) > 1, "slam knocks back")
		FightRules.hit(s, 20, 0.5)
		t.near(s.Fighters[2].MaxHp - s.Fighters[2].Hp, normal * 3.5, 0.5, "slam damage")
		t.eq(FightRules.knockbackMultiplier(s, 2), 1, "slam used up")

		local f = fight("crystal_ball", "pop")
		charge(f, 1)
		FightRules.useSpecial(f, 1)
		t.ok(FightRules.isFrozen(f, 2) and not FightRules.isFrozen(f, 1), "freeze hits the other side")
		local p = fight("water_jug", "pop")
		charge(p, 1)
		FightRules.useSpecial(p, 1)
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
		local s = fight("pop", "pop", { Rng = function()
			return 0.5
		end })
		s.Fighters[2].Hp = 1
		FightRules.hit(s, 20, 0.5)
		t.ok(s.Over and s.Winner == 1 and s.Reason == "Shatter", "shatter")
		local events = FightRules.drainEvents(s)
		t.eq(count(events, "Shatter"), 1, "one shatter event")
		t.eq(count(events, "End"), 1, "one end event")
		FightRules.hit(s, 20, 0.5)
		t.eq(#FightRules.drainEvents(s), 0, "nothing after the end")

		local d = fight("pop", "pop", { Rng = function()
			return 0.5
		end })
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

	t.test("bots fire their special on their own", function()
		local s = fight("pop", "prism", { AutoB = true })
		local fired = false
		for _ = 1, 2000 do
			FightRules.tick(s, 0.05)
			for _, e in FightRules.drainEvents(s) do
				fired = fired or (e.Type == "Special" and e.Side == 2)
			end
			if fired or s.Over then
				break
			end
		end
		t.ok(fired, "bot used its special")
		t.ok(not s.Fighters[1].SpecialUsed, "player's special untouched")
	end)

	t.test("snapshot carries HP, charge and effects", function()
		local s = fight("jam", "pop")
		local snap = FightRules.snapshot(s)
		t.eq(snap.Hp[1], s.Fighters[1].MaxHp, "hp")
		t.eq(snap.Shield[1], false, "no shield")
		t.eq(#snap.Charge, 2, "charge per side")
	end)
end
