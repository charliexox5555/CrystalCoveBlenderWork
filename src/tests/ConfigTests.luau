-- Checks that content config is consistent and safe.

return function(t, deps)
	local Balance, Glassies, Powers, Cosmetics = deps.Balance, deps.Glassies, deps.Powers, deps.Cosmetics

	t.test("glassies have valid type, rarity, stats, powers and tint", function()
		for _, g in Glassies.List do
			t.ok(Balance.Types.Beats[g.Type] ~= nil, g.Id .. " has unknown type " .. tostring(g.Type))
			t.ok(Balance.Rarities[g.Rarity] ~= nil, g.Id .. " has unknown rarity " .. tostring(g.Rarity))
			t.ok(g.Base.Power > 0 and g.Base.HP > 0 and g.Base.Swing > 0, g.Id .. " needs positive stats")
			t.ok(Powers.Passives[g.Passive] ~= nil, g.Id .. " has unknown passive " .. tostring(g.Passive))
			t.ok(Powers.Specials[g.Special] ~= nil, g.Id .. " has unknown special " .. tostring(g.Special))
			t.ok(string.match(g.Tint, "^#%x%x%x%x%x%x$") ~= nil, g.Id .. " tint must be #RRGGBB")
			t.ok(g.Asset ~= nil and g.Asset ~= "", g.Id .. " needs an asset folder name")
			t.between(g.Radius, 0.3, 1.1, g.Id .. " radius")
			t.ok(g.ClinkPitch > 0, g.Id .. " clink pitch")
		end
	end)

	t.test("two of the biggest glassies still hang apart on the stand", function()
		local biggest = 0
		for _, g in Glassies.List do
			biggest = math.max(biggest, g.Radius)
		end
		local scaled = biggest * Balance.Motion.GlassyScale
		t.ok(scaled * 2 < Balance.Motion.HookGap, "two radius-" .. scaled .. " glassies overlap at rest")
	end)

	t.test("power stat products are close across types (fair base stats)", function()
		for _, g in Glassies.List do
			local product = g.Base.Power * g.Base.HP
			t.between(product, 2100, 2350, g.Id .. " Power x HP")
		end
	end)

	t.test("starters exist, use the Starter rarity and cover all types", function()
		t.eq(#Glassies.Starters, 3, "three starters")
		local types = {}
		for _, id in Glassies.Starters do
			local g = Glassies.get(id)
			t.eq(g.Rarity, "Starter", id .. " rarity")
			types[g.Type] = true
		end
		t.ok(types.Heavy and types.Sharp and types.Fizzy, "one starter of each type")
		t.ok(#Glassies.Starters >= Balance.Match.RollChoices, "new players can fill a whole roll")
	end)

	t.test("every Kiln rarity has glassies", function()
		for name, info in Balance.Rarities do
			if info.CrateWeight > 0 then
				local found = false
				for _, g in Glassies.List do
					found = found or g.Rarity == name
				end
				t.ok(found, "no glassies for Kiln rarity " .. name)
			end
		end
	end)

	t.test("every power is used and has a description", function()
		local used = {}
		for _, g in Glassies.List do
			used[g.Passive] = true
			used[g.Special] = true
		end
		for _, list in { Powers.Passives, Powers.Specials } do
			for id, def in list do
				t.eq(def.Id, id, "power id matches key")
				t.ok(#def.Description > 10, id .. " description")
				t.ok(used[id], id .. " is not used by any glassy")
			end
		end
	end)

	t.test("no alcohol in names or descriptions", function()
		local banned = {
			"beer",
			"wine",
			"champagne",
			"vodka",
			"whisk",
			"rum ",
			"liquor",
			"sake",
			"cocktail",
			"booze",
			"tequila",
			"gin ",
		}
		local function check(id: string, text: string)
			text = string.lower(text .. " ")
			for _, word in banned do
				t.ok(string.find(text, word, 1, true) == nil, id .. " mentions '" .. word .. "'")
			end
		end
		for _, g in Glassies.List do
			check(
				g.Id,
				g.Id
					.. " "
					.. g.Name
					.. " "
					.. g.Description
					.. " "
					.. (g.PassiveName or "")
					.. " "
					.. (g.SpecialName or "")
			)
		end
		for _, list in { Powers.Passives, Powers.Specials } do
			for id, def in list do
				check(id, def.Name .. " " .. def.Description)
			end
		end
	end)

	t.test("Kiln weights add up to 100%", function()
		local total = 0
		for _, info in Balance.Rarities do
			total += info.CrateWeight
		end
		t.near(total, 100, 1e-6, "Kiln weight total")
	end)

	t.test("rarity multipliers rise with rarity", function()
		local list = {}
		for name, info in Balance.Rarities do
			if info.Order >= 1 then
				table.insert(list, info)
			end
			t.ok(name ~= "", "rarity name")
		end
		table.sort(list, function(a, b)
			return a.Order < b.Order
		end)
		for i = 2, #list do
			t.ok(list[i].StatMultiplier > list[i - 1].StatMultiplier, "multiplier order")
		end
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

	t.test("marble packs get better value as they grow", function()
		local packs = Balance.Economy.MarblePacks
		for i = 2, #packs do
			t.ok(
				packs[i].Marbles / packs[i].Robux >= packs[i - 1].Marbles / packs[i - 1].Robux,
				"pack " .. i .. " value"
			)
		end
	end)
end
