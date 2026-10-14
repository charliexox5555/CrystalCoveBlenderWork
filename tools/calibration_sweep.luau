-- Fits FightModel's SimModel to real-swing measurements.
--   lune run tools/calibration_sweep <byglassy.json> <compare.json> [rounds=20]
-- byglassy.json: output of tools/calibration_by_glassy (real mirrors, all glassies).
-- compare.json:  output of tools/calibration_compare (real cross-matchup win rates, RealYawRandom).
-- Prints the best parameter sets by mean relative error on mirror round length and hits, plus win-rate
-- error on the starter triangle. Only SimModel (the stand-in) is varied; Fight/Powers stay untouched.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local Balance = require("../src/shared/Config/Balance")
local Rng = require("../src/shared/Rng")
local FightModel = require("../src/tests/FightModel")

local mirrors = serde.decode("json", fs.readFile(process.args[1])).Rows
local compare = serde.decode("json", fs.readFile(process.args[2])).Rows
local N = tonumber(process.args[3]) or 20
local M = Balance.Motion

local function run(a, b, n)
	local seconds, hits, wins = 0, 0, 0
	for i = 1, n do
		local rng = Rng.new(9000 + i * 7919)
		local sweet = M.AimMin + M.SweetSpotWidth + (M.AimMax - M.AimMin - 2 * M.SweetSpotWidth) * rng()
		local swap = i % 2 == 0
		local first, second = if swap then b else a, if swap then a else b
		local s =
			FightModel.round(FightModel.setup(first, second, rng, { AimA = sweet, AimB = sweet, SweetSpot = sweet }))
		seconds += s.Time
		hits += s.Hits
		wins += if s.Winner == (if swap then 2 else 1) then 1 else 0
	end
	return seconds / n, hits / n, wins / n
end

local function score(params)
	local saved = table.clone(Balance.SimModel)
	for k, v in params do
		Balance.SimModel[k] = v
	end
	local secErr, hitErr, worst, worstId = 0, 0, 0, ""
	for _, row in mirrors do
		local s, h = run(row.Id, row.Id, N)
		local realHits = row.HitsPerSecond * row.RoundSeconds
		local e = math.abs(s - row.RoundSeconds) / row.RoundSeconds
		secErr += e
		hitErr += math.abs(h - realHits) / realHits
		if e > worst then
			worst, worstId = e, row.Id
		end
	end
	local winErr = 0
	for _, row in compare do
		local a, b = row.Matchup:match("^(%S+) v (%S+)$")
		if a ~= b then
			local _, _, w = run(a, b, N * 2)
			winErr += math.abs(w - row.RealYawRandom.WinRateA)
		end
	end
	for k, v in saved do
		Balance.SimModel[k] = v
	end
	return {
		Params = params,
		SecondsErr = secErr / #mirrors,
		HitsErr = hitErr / #mirrors,
		WinErr = winErr / 3,
		Worst = worstId .. string.format(" %.0f%%", worst * 100),
		Total = secErr / #mirrors + 0.5 * hitErr / #mirrors + winErr / 3,
	}
end

local results = {}
table.insert(results, score({})) -- current baseline
table.insert(
	results,
	score({ HitInterval = 1.37, SpeedAtAmplitude = 24.5, SpeedSpread = 0.67, ShareSpread = 0.245, MissChance = 0.367 })
)
results[1].Params, results[2].Params = { Label = "baseline" }, { Label = "F1 candidate" }
for _, interval in { 1.28, 1.36 } do
	for _, speed in { 24.5, 27, 29.5 } do
		for _, missAt in { 0.55, 0.6 } do
			for _, perR in { 0.35, 0.42 } do
				for _, slowExp in { 1.5, 3 } do
					table.insert(
						results,
						score({
							HitInterval = interval,
							SpeedAtAmplitude = speed,
							SpeedSpread = 0.67,
							ShareSpread = 0.245,
							MissAtRadius = missAt,
							MissPerRadius = perR,
							MissSlowExponent = slowExp,
						})
					)
				end
			end
		end
	end
end
local baseline, candidate = results[1], results[2]
table.sort(results, function(x, y)
	return x.Total < y.Total
end)
local top = {}
for i = 1, 8 do
	top[i] = results[i]
end
print(serde.encode("json", { Rounds = N, Baseline = baseline, Candidate = candidate, Best = top }, true))
