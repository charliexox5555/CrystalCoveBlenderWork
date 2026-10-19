-- Glassy motion (workstream E): the manifest converter and the generated Config/GlassyMotion.
local Convert = if script
	then require(game.ReplicatedStorage.Shared.GlassyMotionConvert)
	else require("../shared/GlassyMotionConvert")
local Config = if script
	then require(game.ReplicatedStorage.Shared.Config.GlassyMotion)
	else require("../shared/Config/GlassyMotion")

return function(t, deps)
	local manifest = {
		glassies = {
			toy = {
				version = "v4",
				parts = {
					{ name = "Body", role = "Body" },
					{ name = "Plain", role = "Detail" },
					{
						name = "Tail",
						role = "Detail",
						pivot_roblox = { 0.1, -1, 0 },
						axis_roblox = { 0, 2, 0 },
						idle = { type = "sway", amp_deg = 10, period_s = 0.5, phase = 0 },
						hit = { type = "none" },
						follows = "Fish",
					},
					{
						name = "Fish",
						role = "Detail",
						pivot_roblox = { 0, -1, 0 },
						axis_roblox = { 0, 1, 0 },
						idle = { type = "spin", deg_per_s = 24 },
						idle_layers = { { type = "bob", amp_studs = 0.05, period_s = 2, phase = 0 } },
						hit = { type = "hop", studs = 0.06, freq_hz = 4, damping = 0.3 },
						lod_keep = true,
						material = "Neon",
					},
					{
						name = "Chip",
						role = "Detail",
						pivot_roblox = { 0, -1, 0 },
						idle = { type = "static" },
						hit = { type = "none" },
						follows = "Missing",
					},
				},
			},
			still = { parts = { { name = "Body", role = "Body" } } },
		},
	}

	t.test("converter keeps moving parts, parents before followers", function()
		local config = Convert.config({ manifest })
		t.ok(config.Glassies.still == nil, "a glassy with no moving parts is left out")
		local parts = config.Glassies.toy.Parts
		local names = {}
		for _, p in parts do
			table.insert(names, p.Name)
		end
		t.eq(
			table.concat(names, ","),
			"Fish,Tail",
			"static parts without a moving parent are dropped; Fish before Tail"
		)
		t.eq(parts[1].Idle[1].Type, "spin")
		t.eq(parts[1].Idle[1].DegPerS, 24)
		t.eq(parts[1].Idle[2].AmpStuds, 0.05, "idle_layers are merged after the main idle")
		t.eq(parts[1].Hit.Studs, 0.06)
		t.ok(parts[1].Lod and parts[1].Neon, "lod_keep and Neon carry over")
		t.eq(parts[2].Follows, "Fish")
		t.ok(parts[2].Hit == nil, "hit type none is dropped")
		t.eq(parts[2].Axis[2], 1, "axes are normalised")
		t.eq(#Convert.validate(config), 0)
	end)

	t.test("validate catches broken entries", function()
		local bad = {
			Glassies = {
				x = {
					Parts = {
						{ Name = "A", Axis = { 0, 2, 0 }, Idle = { { Type = "warp" } }, Follows = "B" },
						{ Name = "B", Axis = { 0, 1, 0 }, Idle = { { Type = "sway", AmpDeg = 1 } } },
					},
				},
			},
		}
		local problems = Convert.validate(bad)
		t.ok(#problems >= 4, "follows order, axis length, unknown type and missing Period are all reported")
	end)

	t.test("serialize round-trips plain data deterministically", function()
		local a = Convert.serialize({ b = 1, a = { 1, 2.5, "x" }, c = { d = true } })
		local b = Convert.serialize({ c = { d = true }, a = { 1, 2.5, "x" }, b = 1 })
		t.eq(a, b)
	end)

	t.test("generated GlassyMotion config is valid and only names real glassies", function()
		local problems = Convert.validate(Config)
		t.eq(#problems, 0, table.concat(problems, "; "))
		local count = 0
		for id, g in Config.Glassies do
			count += 1
			t.ok(deps.Glassies.ById[id] ~= nil, "unknown glassy " .. id)
			t.ok(#g.Parts > 0, id .. " has moving parts")
		end
		t.ok(count >= 24, "the 24 release glassies (and launch glassies) have motion")
	end)
end
