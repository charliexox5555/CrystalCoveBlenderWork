-- Unit tests for Formula and Rng.

return function(t, deps)
	local Balance, Formula, Rng, Glassies = deps.Balance, deps.Formula, deps.Rng, deps.Glassies

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

	t.test("stats scale with rarity, stars and rainbow", function()
		local pop = Glassies.get("pop")
		local base = Formula.stats(pop)
		local starred = Formula.stats(pop, { Stars = 5 })
		local capped = Formula.stats(pop, { Stars = 99 })
		local rainbow = Formula.stats(pop, { Rainbow = true })
		t.ok(starred.HP > base.HP, "stars add HP")
		t.eq(capped.HP, starred.HP, "stars cap at MaxStars")
		t.ok(rainbow.Power >= base.Power, "rainbow bonus")
		t.near(Formula.statMultiplier("Common"), 1, 1e-9, "common is 1x")
	end)

	t.test("duplicates become stars, then overflow", function()
		local g = Balance.Growth
		t.eq(Formula.starsFromDuplicates(0), 0, "no duplicates")
		t.eq(Formula.starsFromDuplicates(g.DuplicatesPerStar), 1, "one star")
		local stars, overflow = Formula.starsFromDuplicates(g.MaxStars * g.DuplicatesPerStar + 2)
		t.eq(stars, g.MaxStars, "capped")
		t.eq(overflow, 2, "overflow")
	end)

	t.test("crit chance grows with Swing and caps", function()
		t.ok(Formula.critChance(20) > Formula.critChance(5), "more Swing, more crits")
		t.ok(Formula.critChance(10_000) <= Balance.Fight.CritMax + 1e-9, "cap")
		t.near(Formula.critChance(0, 0.1), Balance.Fight.CritBase + 0.1, 1e-9, "bonus adds")
	end)

	t.test("Kiln odds add up to 1 and match the rolls", function()
		local total = 0
		for _, entry in Formula.kilnOdds() do
			total += entry.Chance
			t.ok(Glassies.get(entry.Id).Rarity == entry.Rarity, entry.Id .. " rarity")
		end
		t.near(total, 1, 1e-9, "per-glassy odds sum")
		local rng = Rng.new(99)
		local counts, n = {}, 20000
		for _ = 1, n do
			local id = Formula.rollKiln(rng)
			local rarity = Glassies.get(id).Rarity
			counts[rarity] = (counts[rarity] or 0) + 1
			t.ok(rarity ~= "Starter", "starters never come out of the Kiln")
		end
		for _, entry in Formula.crateOdds() do
			t.near((counts[entry.Rarity] or 0) / n, entry.Chance, 0.012, entry.Rarity .. " roll rate")
		end
	end)

	t.test("each glassy is less likely than any glassy of a lower rarity", function()
		local byRarity = {}
		for _, entry in Formula.kilnOdds() do
			byRarity[entry.Rarity] = entry.Chance
		end
		local order = Formula.crateOdds()
		for i = 2, #order do
			t.ok(
				byRarity[order[i].Rarity] < byRarity[order[i - 1].Rarity],
				order[i].Rarity .. " glassies are rarer than " .. order[i - 1].Rarity
			)
		end
	end)
end
