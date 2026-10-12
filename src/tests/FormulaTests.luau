-- Unit tests for Formula, BattleLogic and Rng.

return function(t, deps)
	local Balance, Formula, BattleLogic, Rng, Glassies = deps.Balance, deps.Formula, deps.BattleLogic, deps.Rng, deps.Glassies

	local function constant(x: number)
		return function()
			return x
		end
	end

	t.test("Rng is deterministic and in [0, 1)", function()
		local a, b = Rng.new(7), Rng.new(7)
		for _ = 1, 1000 do
			local x = a()
			t.eq(x, b(), "same seed, same sequence")
			t.ok(x >= 0 and x < 1, "range")
		end
	end)

	t.test("type triangle", function()
		t.eq(Formula.typeMultiplier("Heavy", "Sharp"), Balance.Types.Strong, "Heavy > Sharp")
		t.eq(Formula.typeMultiplier("Sharp", "Fizzy"), Balance.Types.Strong, "Sharp > Fizzy")
		t.eq(Formula.typeMultiplier("Fizzy", "Heavy"), Balance.Types.Strong, "Fizzy > Heavy")
		t.eq(Formula.typeMultiplier("Sharp", "Heavy"), Balance.Types.Weak, "Sharp < Heavy")
		t.eq(Formula.typeMultiplier("Fizzy", "Fizzy"), 1, "mirror")
	end)

	t.test("meter zones are symmetric with Perfect in the middle", function()
		t.eq(Formula.zoneAt(0.5, 10), "Perfect", "centre")
		t.eq(Formula.zoneAt(0, 10), "Weak", "left edge")
		t.eq(Formula.zoneAt(1, 10), "Weak", "right edge")
		t.eq(Formula.zoneAt(0.42, 10), Formula.zoneAt(0.58, 10), "symmetry")
		local b = Formula.meterBounds(10_000)
		t.ok(b.Perfect < b.Great and b.Great < b.Good and b.Good <= 0.5, "bounds ordered and fit the bar")
		t.ok(Formula.meterBounds(120).Perfect > Formula.meterBounds(0).Perfect, "Swing widens Perfect")
	end)

	t.test("needle ping-pongs", function()
		local s = Balance.Meter.SweepTime
		t.near(Formula.needlePosition(0), 0, 1e-9, "start")
		t.near(Formula.needlePosition(s), 1, 1e-9, "far end")
		t.near(Formula.needlePosition(s * 1.5), 0.5, 1e-9, "coming back")
		t.near(Formula.needlePosition(s * 2), 0, 1e-9, "back at start")
	end)

	t.test("release validation clamps and times out", function()
		local m = Balance.Meter
		t.near(Formula.validateRelease(0.2, 0.9) :: number, 0.9 - m.LatencyAllowance, 1e-9, "too-early claim clamped")
		t.near(Formula.validateRelease(0.8, 0.9) :: number, 0.8, 1e-9, "claim inside allowance trusted")
		t.near(Formula.validateRelease(5, 0.9) :: number, 0.9, 1e-9, "future claim clamped to server time")
		t.eq(Formula.validateRelease(1.6, m.MaxHoldTime + m.LatencyAllowance + 0.01), nil, "held too long")
		t.eq(Formula.zoneFromRelease(nil, 10), "Weak", "timeout is Weak")
	end)

	t.test("crit chance is capped", function()
		t.near(Formula.critChance(0), Balance.Damage.CritBase, 1e-9, "base")
		t.eq(Formula.critChance(10_000), Balance.Damage.CritMax, "cap")
	end)

	t.test("stats scale with rarity, level, stars and Rainbow", function()
		local pop = Glassies.get("pop")
		local s1 = Formula.stats(pop, { Level = 1 })
		t.eq(s1.Power, math.floor(pop.Base.Power * Balance.Rarities.Starter.StatMultiplier + 0.5), "level 1 power")
		local s50 = Formula.stats(pop, { Level = 50 })
		t.near(s50.HP / s1.HP, Formula.levelMultiplier(50), 0.02, "level 50 multiplier")
		t.ok(Formula.stats(pop, { Level = 1, Stars = 2 }).HP > s1.HP, "stars add stats")
		t.ok(Formula.stats(pop, { Level = 1, Rainbow = true }).HP > s1.HP, "Rainbow adds stats")
	end)

	t.test("damage uses swing, type and variance", function()
		local attacker = { Power = 40, Swing = 0, Type = "Fizzy" }
		-- rng 0.5: no crit (chance 0.05), variance exactly 1.0
		local dmg, crit = Formula.damage(attacker, "Heavy", "Perfect", constant(0.5))
		t.eq(crit, false, "no crit")
		t.eq(dmg, math.floor(40 * Balance.Meter.Multipliers.Perfect * Balance.Types.Strong + 0.5), "perfect + strong")
		local weak = Formula.damage(attacker, "Sharp", "Weak", constant(0.5))
		t.ok(weak < dmg, "weak swing into a bad matchup hits softer")
		local _, crit2 = Formula.damage(attacker, "Fizzy", "Good", constant(0))
		t.eq(crit2, true, "rng 0 always crits")
	end)

	t.test("skilled NPCs hit more Perfects", function()
		local rng = Rng.new(3)
		local low, high = 0, 0
		for _ = 1, 10_000 do
			if Formula.npcZone(0, rng) == "Perfect" then
				low += 1
			end
			if Formula.npcZone(1, rng) == "Perfect" then
				high += 1
			end
		end
		t.ok(high > low * 3, "skill 1 hits far more Perfects than skill 0")
	end)

	t.test("XP and level ups", function()
		t.eq(Formula.xpToNext(1), Balance.Xp.ToNextBase + Balance.Xp.ToNextPerLevel, "xp to level 2")
		local level, xp, gained = Formula.applyXp(1, 0, Formula.xpToNext(1) + Formula.xpToNext(2) + 5)
		t.eq(level, 3, "two level ups")
		t.eq(xp, 5, "leftover xp")
		t.eq(gained, 2, "levels gained")
		local maxLevel = Formula.applyXp(49, 0, 1e9)
		t.eq(maxLevel, Balance.Growth.MaxLevel, "capped at max level")
		t.ok(Formula.xpForBattle(10, false) < Formula.xpForBattle(10, true), "losing gives less XP")
	end)

	t.test("catch chance rises as HP drops and respects the cap", function()
		local full = Formula.catchChance("Common", 100, 100)
		local low = Formula.catchChance("Common", 10, 100)
		t.ok(full > 0, "possible at full HP")
		t.ok(low > full, "easier when low")
		t.ok(Formula.catchChance("Rare", 10, 100, "Golden") > Formula.catchChance("Rare", 10, 100, "Basic"), "golden cork")
		t.ok(Formula.catchChance("Common", 0, 100, "Golden") <= Balance.Catch.MaxChance, "cap")
		t.ok(Formula.catchChance("Legendary", 10, 100) < Formula.catchChance("Common", 10, 100), "rarer is harder")
	end)

	t.test("crate odds add to 1 and rolls follow them", function()
		local total = 0
		for _, entry in Formula.crateOdds() do
			total += entry.Chance
		end
		t.near(total, 1, 1e-9, "odds total")
		local rng = Rng.new(11)
		local counts = {}
		local n = 100_000
		for _ = 1, n do
			local r = Formula.rollRarity(rng)
			counts[r] = (counts[r] or 0) + 1
		end
		t.near(counts.Common / n, 0.6, 0.01, "Common rate")
		t.near(counts.Epic / n, 0.04, 0.005, "Epic rate")
		t.eq(counts.Starter, nil, "starters never roll")
	end)

	t.test("clash: both take damage, cork deals none", function()
		local a = BattleLogic.newFighter(Glassies.get("pop"), { Level = 10 })
		local b = BattleLogic.newFighter(Glassies.get("jam"), { Level = 10 })
		local r = BattleLogic.resolveClash(a, b, "Good", "Good", constant(0.5))
		t.ok(r.DamageToA > 0 and r.DamageToB > 0, "both hit")
		t.eq(a.HP, a.MaxHP - r.DamageToA, "A hp updated")
		local r2 = BattleLogic.resolveClash(a, b, "Cork", "Good", constant(0.5))
		t.eq(r2.DamageToB, 0, "corking side deals no damage")
	end)

	t.test("double KO leaves one survivor on 1 HP", function()
		local a = BattleLogic.newFighter(Glassies.get("pop"), { Level = 10 }, 1)
		local b = BattleLogic.newFighter(Glassies.get("jam"), { Level = 10 }, 1)
		local r = BattleLogic.resolveClash(a, b, "Good", "Good", constant(0.5))
		t.eq(r.Clutch, true, "clutch")
		t.ok(r.Winner ~= nil, "has a winner")
		t.eq(math.max(r.HpA, r.HpB), 1, "survivor on 1 HP")
		t.eq(math.min(r.HpA, r.HpB), 0, "loser on 0 HP")
	end)
end
