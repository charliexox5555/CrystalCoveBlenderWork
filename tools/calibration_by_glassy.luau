-- Per-glassy real-swing contact statistics (mirror matches, both aiming at the sweet spot, random yaw).
--   lune run tools/calibration_by_glassy [rounds=40]
-- Prints radius, amplitude and the measured encounter interval, pass-by (miss) share, hits/s, median
-- hit speed and median share for each glassy, to check whether FightModel should depend on them.
local serde = require("@lune/serde")
local process = require("@lune/process")
local Balance = require("../src/shared/Config/Balance")
local Glassies = require("../src/shared/Config/Glassies")
local Rules = require("../src/shared/FightRules")
local Formula = require("../src/shared/Formula")
local Rng = require("../src/shared/Rng")
local Pendulum = require("../src/server/Simulation/Pendulum")

local N = tonumber(process.args[1]) or 40
local M = Balance.Motion

local function median(values)
	if #values == 0 then
		return 0
	end
	table.sort(values)
	return values[math.ceil(#values / 2)]
end

local rows = {}
for _, def in Glassies.List do
	local seconds, hits, misses, speeds, shares = 0, 0, 0, {}, {}
	for i = 1, N do
		local seed = 9000 + i * 7919
		local rng = Rng.new(seed)
		local sweet = M.AimMin + M.SweetSpotWidth + (M.AimMax - M.AimMin - 2 * M.SweetSpotWidth) * rng()
		local sim = Pendulum.new({
			A = { Id = def.Id, Aim = sweet, AimYaw = (rng() * 2 - 1) * M.AimYawMax },
			B = { Id = def.Id, Aim = sweet, AimYaw = (rng() * 2 - 1) * M.AimYawMax },
			SweetSpot = sweet,
			Rng = rng,
		}, seed)
		while not sim.Fight.Over do
			Pendulum.step(sim, 1 / M.StepRate)
			Pendulum.events(sim)
		end
		seconds += sim.Fight.Time
		hits += sim.Fight.Hits
		misses += sim.Metrics.Misses
		for _, s in sim.Metrics.Speeds do
			table.insert(speeds, s)
		end
		for _, s in sim.Metrics.Shares do
			table.insert(shares, s)
		end
	end
	local stats = Formula.stats(def, { Stars = 0 })
	table.insert(rows, {
		Id = def.Id,
		Type = def.Type,
		Radius = def.Radius,
		Swing = stats.Swing,
		Amplitude = Rules.targetAmplitude(stats.Swing),
		RoundSeconds = seconds / N,
		HitsPerSecond = hits / seconds,
		MissChance = misses / math.max(1, hits + misses),
		EncounterInterval = seconds / math.max(1, hits + misses),
		SpeedMedian = median(speeds),
	})
end
table.sort(rows, function(a, b)
	return a.Radius < b.Radius
end)
print(serde.encode("json", { Rounds = N, Rows = rows }, true))
