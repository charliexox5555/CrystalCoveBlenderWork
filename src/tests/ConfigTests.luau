-- Checks that content config is consistent and safe.

return function(t, deps)
	local Balance, Glassies, Trainers, Zones, Cosmetics = deps.Balance, deps.Glassies, deps.Trainers, deps.Zones, deps.Cosmetics

	t.test("glassies have valid type, rarity, stats and tint", function()
		for _, g in Glassies.List do
			t.ok(Balance.Types.Beats[g.Type] ~= nil, g.Id .. " has unknown type " .. tostring(g.Type))
			t.ok(Balance.Rarities[g.Rarity] ~= nil, g.Id .. " has unknown rarity " .. tostring(g.Rarity))
			t.ok(g.Base.Power > 0 and g.Base.HP > 0 and g.Base.Swing > 0, g.Id .. " needs positive stats")
			t.ok(string.match(g.Tint, "^#%x%x%x%x%x%x$") ~= nil, g.Id .. " tint must be #RRGGBB")
			t.ok(g.Asset ~= nil and g.Asset ~= "", g.Id .. " needs an asset folder name")
		end
	end)

	t.test("evolutions point at existing, stronger forms", function()
		for _, g in Glassies.List do
			if g.EvolvesTo then
				local target = Glassies.ById[g.EvolvesTo.Id]
				t.ok(target ~= nil, g.Id .. " evolves into missing " .. g.EvolvesTo.Id)
				t.eq(target.Type, g.Type, g.Id .. " evolution keeps its type")
				t.ok(target.Base.Power > g.Base.Power and target.Base.HP > g.Base.HP, g.Id .. " evolution must be stronger")
				t.ok(g.EvolvesTo.Level > 1 and g.EvolvesTo.Level <= Balance.Growth.MaxLevel, g.Id .. " evolution level")
			end
		end
	end)

	t.test("starters exist and use the Starter rarity", function()
		t.eq(#Glassies.Starters, 3, "three starters")
		local types = {}
		for _, id in Glassies.Starters do
			local g = Glassies.get(id)
			t.eq(g.Rarity, "Starter", id .. " rarity")
			types[g.Type] = true
		end
		t.ok(types.Heavy and types.Sharp and types.Fizzy, "one starter of each type")
	end)

	t.test("no alcohol in names or descriptions", function()
		local banned = { "beer", "wine", "champagne", "vodka", "whisk", "rum ", "liquor", "sake", "cocktail", "booze", "tequila", "gin " }
		for _, g in Glassies.List do
			local text = string.lower(g.Id .. " " .. g.Name .. " " .. g.Description .. " ")
			for _, word in banned do
				t.ok(string.find(text, word, 1, true) == nil, g.Id .. " mentions '" .. word .. "'")
			end
		end
	end)

	t.test("wild spawns match glassy WildZones", function()
		for _, zone in Zones.List do
			for id, weight in zone.WildSpawns do
				local g = Glassies.ById[id]
				t.ok(g ~= nil, zone.Id .. " spawns missing glassy " .. id)
				t.ok(weight > 0, zone.Id .. " weight for " .. id)
				t.ok(table.find(g.WildZones, zone.Id) ~= nil, id .. " should list " .. zone.Id .. " in WildZones")
			end
		end
		for _, g in Glassies.List do
			for _, zoneId in g.WildZones do
				local zone = Zones.ById[zoneId]
				t.ok(zone ~= nil, g.Id .. " lists missing zone " .. zoneId)
				t.ok(zone.WildSpawns[g.Id] ~= nil, zoneId .. " should spawn " .. g.Id)
			end
		end
	end)

	t.test("trainers reference real glassies and zones; one boss per zone", function()
		local bosses = {}
		for _, tr in Trainers.List do
			t.ok(Glassies.ById[tr.Glassy] ~= nil, tr.Id .. " uses missing glassy " .. tr.Glassy)
			t.ok(Zones.ById[tr.Zone] ~= nil, tr.Id .. " in missing zone " .. tr.Zone)
			t.between(tr.Skill, 0, 1, tr.Id .. " skill")
			if tr.IsBoss then
				bosses[tr.Zone] = (bosses[tr.Zone] or 0) + 1
				t.ok(tr.Badge ~= nil, tr.Id .. " boss needs a badge")
				t.ok(tr.Team ~= nil, tr.Id .. " boss needs a Team")
				for _, ty in { "Heavy", "Fizzy", "Sharp" } do
					local g = Glassies.ById[tr.Team[ty]]
					t.ok(g ~= nil and g.Type == ty, tr.Id .. " team needs a " .. ty .. " glassy")
				end
			end
		end
		for _, zone in Zones.List do
			if zone.Enabled then
				t.eq(bosses[zone.Id] or 0, 1, zone.Id .. " boss count")
			end
		end
	end)

	t.test("crate weights add up to 100%", function()
		local total = 0
		for _, info in Balance.Rarities do
			total += info.CrateWeight
		end
		t.near(total, 100, 1e-6, "crate weight total")
	end)

	t.test("cosmetic ids are unique", function()
		for _, list in { Cosmetics.ShatterFx, Cosmetics.Fills } do
			local seen = {}
			for _, item in list do
				t.ok(not seen[item.Id], "duplicate cosmetic " .. item.Id)
				seen[item.Id] = true
			end
		end
	end)
end
