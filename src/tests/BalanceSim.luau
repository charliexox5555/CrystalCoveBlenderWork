-- Prints a balance report. In Studio: print(require(game.ServerStorage.Tests.BalanceSim)())
-- Outside Studio: lune run tools/balance_sim

local Deps = if script then require(script.Parent.Deps) else require("./Deps")
local Sim = if script then require(script.Parent.Sim) else require("./Sim")

return function(runs: number?): string
	local n = runs or 3000
	local Glassies, Trainers = Deps.Glassies, Deps.Trainers
	local lines = { string.format("Balance report (%d battles per matchup, skill 0.5 unless noted)", n) }
	local function row(label: string, r)
		table.insert(lines, string.format("  %-38s win %5.1f%%  avg clashes %.2f", label, r.WinRateA * 100, r.AvgClashes))
	end

	table.insert(lines, "Starters, level 10:")
	for _, a in Glassies.Starters do
		for _, b in Glassies.Starters do
			row(a .. " vs " .. b, Sim.match({ Id = a, Level = 10, Skill = 0.5 }, { Id = b, Level = 10, Skill = 0.5 }, n, 1))
		end
	end

	table.insert(lines, "Starters vs Zone 1 trainers at the trainer's level (boss: at level 12):")
	for _, tr in Trainers.List do
		if tr.Zone == "recycling_yard" then
			for _, starter in Glassies.Starters do
				local playerLevel = if tr.IsBoss then 12 else tr.Level
				local glassy = Trainers.glassyFor(tr, Glassies.get(starter).Type)
				row(
					string.format("%s L%d vs %s's %s L%d", starter, playerLevel, tr.Id, glassy, tr.Level),
					Sim.match({ Id = starter, Level = playerLevel, Skill = 0.5 }, { Id = glassy, Level = tr.Level, Skill = tr.Skill }, n, 2)
				)
			end
		end
	end

	table.insert(lines, "Rarity at level 20:")
	for _, id in { "milk_bottle", "mason_jar", "perfume", "jack_o_glass", "glass_sword", "galaxy_orb" } do
		row(id .. " vs milk_bottle", Sim.match({ Id = id, Level = 20, Skill = 0.5 }, { Id = "milk_bottle", Level = 20, Skill = 0.5 }, n, 3))
	end

	table.insert(lines, "Timing skill (pop vs pop, level 10):")
	for _, skill in { 0, 0.25, 0.75, 1 } do
		row(string.format("skill %.2f vs skill 0.5", skill), Sim.match({ Id = "pop", Level = 10, Skill = skill }, { Id = "pop", Level = 10, Skill = 0.5 }, n, 4))
	end

	table.insert(lines, "Progression (always fighting same-level opponents):")
	for _, level in { 5, 15, 25, 35, 50 } do
		table.insert(lines, string.format("  wins to reach level %-2d  %d", level, Sim.winsToLevel(level)))
	end

	local report = table.concat(lines, "\n")
	return report
end
