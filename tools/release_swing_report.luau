-- Real deterministic pendulum coverage; unlike BalanceSim this uses attack geometry and 3D apexes.
local fs = require("@lune/fs")
local process = require("@lune/process")
local json = require("@lune/serde")
local G = require("../src/shared/Config/Glassies")
local B = require("../src/shared/Config/Balance")
local C = require("../src/server/Simulation/Calibration")
local report = { Rounds = 0, Seconds = 0, Hits = 0, Timeouts = 0, MaxRadiusError = 0, Kits = {} }
for i, def in G.ReleaseList do
	local row = { Id = def.Id, Seconds = 0, Hits = 0, Casts = 0, Landed = 0, Wins = 0 }
	for n = 1, 2 do
		local foe = G.ReleaseList[(i + n * 7 - 1) % 24 + 1].Id
		local sim = C.round(def.Id, foe, 12000 + i * 31 + n)
		row.Seconds += sim.Fight.Time
		row.Hits += sim.Fight.Hits
		row.Casts += sim.Metrics.Powers[def.Id] or 0
		row.Landed += sim.Metrics.Landed[def.Id] or 0
		row.Wins += if sim.Fight.Winner == 1 then 1 else 0
		report.Rounds += 1
		report.Seconds += sim.Fight.Time
		report.Hits += sim.Fight.Hits
		report.Timeouts += if sim.Fight.Reason == "Timeout" then 1 else 0
		report.MaxRadiusError = math.max(report.MaxRadiusError, sim.Metrics.MaxRadiusError)
	end
	row.Seconds /= 2
	row.Hits /= 2
	table.insert(report.Kits, row)
end
report.MeanSeconds = report.Seconds / report.Rounds
report.HitsPerSecond = report.Hits / report.Seconds
fs.writeFile(
	process.args[1] or "docs/testing/combat_release/release_swing_report.json",
	json.encode("json", report, true)
)
print(json.encode("json", report))
