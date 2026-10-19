-- Seasonal Hollowlight: roster isolation and the Lantern Seeds kit (plant -> bloom -> wisps).
return function(t, d)
	local R, G, B = d.FightRules, d.Glassies, d.Balance
	local kit = B.CombatRelease.Kits.hollowlight
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
	local function clash(s)
		R.hit(s, 2, 0.5)
		R.tick(s, 0.05)
	end

	t.test("hollowlight is a seasonal Epic outside the release roster with ordinary Epic stats", function()
		local def = G.get("hollowlight")
		t.ok(G.isSeasonal("hollowlight") and not G.isRelease("hollowlight"))
		t.eq(def.Rarity, "Epic")
		t.eq(#G.ReleaseList, 36)
		for _, other in G.ReleaseList do
			t.ok(other.Id ~= "hollowlight")
		end
		local power, hp = def.Base.Power, def.Base.HP
		t.eq(power * hp, 20 * 112, "Heavy budget")
		t.ok(G.get("pop").Passive ~= nil, "Pop keeps its own definition")
	end)

	t.test("each clash plants one seed up to the cap and the bar shows seed progress", function()
		local s = fight("hollowlight", "jam")
		for i = 1, kit.MaxSeeds + 2 do
			clash(s)
			t.eq(s.Fighters[1].Signature.Seeds, math.min(i, kit.MaxSeeds))
		end
		t.eq(R.powerProgress(s, 1), 1)
		t.eq(#R.drainCasts(s), 0, "planting alone never fires")
	end)

	t.test("a full set blooms on turnaround into one wisp per seed that always lands", function()
		local s = fight("hollowlight", "jam")
		for _ = 1, kit.MaxSeeds do
			clash(s)
		end
		R.turnaround(s, 2)
		t.eq(#s.PendingCasts, 0, "the foe's turnaround does not bloom")
		R.turnaround(s, 1)
		t.eq(s.Fighters[1].Signature.Seeds, 0)
		R.tick(s, kit.Windup + 0.01)
		local cast = R.drainCasts(s)[1]
		t.ok(cast and cast.Shape == "bloom")
		t.eq(cast.Params.Pulses, kit.MaxSeeds)
		t.ok(R.releaseCast(s, cast, { 0, 0, 0 }, { 1, 0, 0 }))
		local foe = s.Fighters[2]
		local before = foe.Hp
		for pulse = 1, kit.MaxSeeds do
			t.ok(R.resolveAbility(s, cast.Id, true, { 0, 0, 0 }, pulse))
		end
		t.ok(not R.resolveAbility(s, cast.Id, true, { 0, 0, 0 }, 1), "each wisp lands once")
		local expected = s.Fighters[1].Power
			* kit.SeedDamage
			* kit.MaxSeeds
			* d.Formula.typeMultiplier("Heavy", "Heavy")
		t.near(before - foe.Hp, expected, 0.001)
	end)

	t.test("a heavy hit knocks one seed loose, light taps do not, and seeds fade", function()
		local s = fight("hollowlight", "jam")
		clash(s)
		clash(s)
		local pumpkin = s.Fighters[1]
		t.eq(pumpkin.Signature.Seeds, 2)
		R.tick(s, 0)
		local light = pumpkin.MaxHp * kit.KnockThreshold * 0.5
		d.SignatureRules.damaged(s, pumpkin, light, "body", function() end)
		t.eq(pumpkin.Signature.Seeds, 2)
		d.SignatureRules.damaged(s, pumpkin, pumpkin.MaxHp * kit.KnockThreshold, "body", function() end)
		t.eq(pumpkin.Signature.Seeds, 1)
		R.tick(s, kit.SeedSeconds + 0.1)
		t.eq(pumpkin.Signature.Seeds, 0, "seeds fade after SeedSeconds")
		R.turnaround(s, 1)
		R.tick(s, kit.Windup + 0.01)
		t.eq(#R.drainCasts(s), 0, "nothing to bloom")
	end)
end
