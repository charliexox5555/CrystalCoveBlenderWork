-- Real-swing equal-stat win rate of one glassy against every other glassy (rarity multipliers set to 1,
-- like BalanceSim.powerTable), to check a fairness result directly instead of through FightModel.
--   lune run tools/calibration_fairness <id> [rounds per opponent=16]
local serde = require("@lune/serde")
local process = require("@lune/process")
local Balance = require("../src/shared/Config/Balance")
local Glassies = require("../src/shared/Config/Glassies")
local Rng = require("../src/shared/Rng")
local Pendulum = require("../src/server/Simulation/Pendulum")

local id = process.args[1] or "prism_blade"
local N = tonumber(process.args[2]) or 16
local M = Balance.Motion
for _, info in Balance.Rarities do
	info.StatMultiplier = 1
end

local wins, total, rows = 0, 0, {}
for _, def in Glassies.List do
	if def.Id ~= id then
		local w = 0
		for i = 1, N do
			local seed = 12000 + i * 7919 + #def.Id * 31
			local rng = Rng.new(seed)
			local sweet = M.AimMin + M.SweetSpotWidth + (M.AimMax - M.AimMin - 2 * M.SweetSpotWidth) * rng()
			local swap = i % 2 == 0
			local first, second = if swap then def.Id else id, if swap then id else def.Id
			local sim = Pendulum.new({
				A = { Id = first, Aim = sweet, AimYaw = (rng() * 2 - 1) * M.AimYawMax },
				B = { Id = second, Aim = sweet, AimYaw = (rng() * 2 - 1) * M.AimYawMax },
				SweetSpot = sweet,
				Rng = rng,
			}, seed)
			while not sim.Fight.Over do
				Pendulum.step(sim, 1 / M.StepRate)
				Pendulum.events(sim)
			end
			if sim.Fight.Winner == (if swap then 2 else 1) then
				w += 1
			end
		end
		wins += w
		total += N
		table.insert(rows, { Opponent = def.Id, WinRate = w / N })
	end
end
print(
	serde.encode("json", { Id = id, RoundsPerOpponent = N, WinRate = wins / total, Rounds = total, Rows = rows }, true)
)
