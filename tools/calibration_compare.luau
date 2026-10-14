-- Compares the REAL swing (server Pendulum integrator) with the FightModel stand-in on the same
-- matchups and aim policy, so SimModel calibration questions can be answered with direct evidence.
--   lune run tools/calibration_compare [rounds=60]
-- Prints JSON: per matchup, mean round seconds / hits / timeouts / win rate for the real swing and for
-- FightModel under the current Balance.SimModel and under an optional candidate SimModel.
local serde = require("@lune/serde")
local process = require("@lune/process")
local Balance = require("../src/shared/Config/Balance")
local Rules = require("../src/shared/FightRules")
local Rng = require("../src/shared/Rng")
local Pendulum = require("../src/server/Simulation/Pendulum")
local FightModel = require("../src/tests/FightModel")

local N = tonumber(process.args[1]) or 60
local M = Balance.Motion

-- F1 measured candidate (docs/testing/F1_FIGHT.md); not adopted.
local CANDIDATE =
	{ HitInterval = 1.37, SpeedAtAmplitude = 24.5, SpeedSpread = 0.67, ShareSpread = 0.245, MissChance = 0.367 }

local function sweetFor(rng)
	return M.AimMin + M.SweetSpotWidth + (M.AimMax - M.AimMin - 2 * M.SweetSpotWidth) * rng()
end

local function real(a, b, n, yawMode)
	local out = { Seconds = 0, Hits = 0, Timeouts = 0, Wins = 0, Lengths = {} }
	for i = 1, n do
		local seed = 3000 + i * 7919
		local rng = Rng.new(seed)
		local sweet = sweetFor(rng)
		local function yaw()
			return if yawMode == "random" then (rng() * 2 - 1) * M.AimYawMax else 0
		end
		local swap = i % 2 == 0
		local first, second = if swap then b else a, if swap then a else b
		local sim = Pendulum.new({
			A = { Id = first, Aim = sweet, AimYaw = yaw() },
			B = { Id = second, Aim = sweet, AimYaw = yaw() },
			SweetSpot = sweet,
			Rng = rng,
		}, seed)
		while not sim.Fight.Over do
			Pendulum.step(sim, 1 / M.StepRate)
			Pendulum.events(sim)
		end
		local f = sim.Fight
		out.Seconds += f.Time
		out.Hits += f.Hits
		out.Timeouts += if f.Reason == "Timeout" then 1 else 0
		out.Wins += if f.Winner == (if swap then 2 else 1) then 1 else 0
		table.insert(out.Lengths, f.Time)
	end
	table.sort(out.Lengths)
	return {
		Seconds = out.Seconds / n,
		Median = out.Lengths[math.ceil(n / 2)],
		P90 = out.Lengths[math.ceil(n * 0.9)],
		Hits = out.Hits / n,
		Timeouts = out.Timeouts / n,
		WinRateA = out.Wins / n,
	}
end

local function model(a, b, n, sim)
	local saved = table.clone(Balance.SimModel)
	for k, v in sim or {} do
		Balance.SimModel[k] = v
	end
	local out = { Seconds = 0, Hits = 0, Timeouts = 0, Wins = 0, Lengths = {} }
	for i = 1, n do
		local rng = Rng.new(3000 + i * 7919)
		local sweet = sweetFor(rng)
		local swap = i % 2 == 0
		local first, second = if swap then b else a, if swap then a else b
		local state =
			FightModel.round(FightModel.setup(first, second, rng, { AimA = sweet, AimB = sweet, SweetSpot = sweet }))
		out.Seconds += state.Time
		out.Hits += state.Hits
		out.Timeouts += if state.Reason == "Timeout" then 1 else 0
		out.Wins += if state.Winner == (if swap then 2 else 1) then 1 else 0
		table.insert(out.Lengths, state.Time)
	end
	for k, v in saved do
		Balance.SimModel[k] = v
	end
	table.sort(out.Lengths)
	return {
		Seconds = out.Seconds / n,
		Median = out.Lengths[math.ceil(n / 2)],
		P90 = out.Lengths[math.ceil(n * 0.9)],
		Hits = out.Hits / n,
		Timeouts = out.Timeouts / n,
		WinRateA = out.Wins / n,
	}
end

local matchups = {
	{ "pop", "pop" },
	{ "jam", "jam" },
	{ "prism", "prism" },
	{ "milk_bottle", "milk_bottle" },
	{ "glass_sword", "glass_sword" },
	{ "glass_dragon", "glass_dragon" },
	{ "pop", "jam" },
	{ "jam", "prism" },
	{ "prism", "pop" },
}
local report = { Rounds = N, Rows = {} }
for _, m in matchups do
	table.insert(report.Rows, {
		Matchup = m[1] .. " v " .. m[2],
		RealYaw0 = real(m[1], m[2], N, "zero"),
		RealYawRandom = real(m[1], m[2], N, "random"),
		ModelBaseline = model(m[1], m[2], N),
		ModelCandidate = model(m[1], m[2], N, CANDIDATE),
	})
end
print(serde.encode("json", report, true))
