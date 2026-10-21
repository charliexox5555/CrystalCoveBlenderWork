-- Crown Hill economy check (decision 105): what time on the hill earns compared with normal matches.
--   Outside Studio: lune run tools/economy_sim   (printed after the main economy report)
--   In Studio:      print(require(game.ServerStorage.Tests.HillEconomySim).report())
-- Inputs: Config.Hill, Balance.Match, Balance.EconomyModel. Same 50% win rate as the main sim.

local Deps = if script then require(script.Parent.Deps) else require("./Deps")
local Balance, Rng, MatchLogic = Deps.Balance, Deps.Rng, Deps.MatchLogic
local Hill = if script then require(game.ReplicatedStorage.Shared.Config.Hill) else require("../shared/Config/Hill")
local HillRules = if script then require(game.ReplicatedStorage.Shared.HillRules) else require("../shared/HillRules")

local Sim = {}

-- One sudden-death hill fight, start to the next fight.
function Sim.fightSeconds(): number
	local m, e = Balance.Match, Balance.EconomyModel
	return m.RollSeconds
		+ m.AimSeconds
		+ m.CountdownSeconds
		+ e.RoundSecondsEstimate
		+ m.RoundEndSeconds
		+ Hill.GapSeconds
end

-- Normal play: coins per minute from matches at the model's win rate (same rules as EconomySim's playMatch).
function Sim.normalPerMinute(rng: () -> number): number
	local e, r, m = Balance.EconomyModel, Balance.Match.Rewards, Balance.Match
	local perRound = m.RollSeconds + m.AimSeconds + m.CountdownSeconds + e.RoundSecondsEstimate + m.RoundEndSeconds
	local coins, seconds = 0, 0
	for _ = 1, 20000 do
		local won, lost = 0, 0
		while won < m.Hearts and lost < m.Hearts do
			if rng() < e.WinRate then
				won += 1
			else
				lost += 1
			end
		end
		seconds += (won + lost) * perRound + e.SecondsBetweenMatches
		coins += if won == m.Hearts
			then r.MatchWinCoins
			else MatchLogic.lossCoins(won, lost * e.LossChipPerRound, e.PerfectsPerMatch)
	end
	return coins / (seconds / 60)
end

-- `minutes` on the hill in one day: queue, challenge, defend. `ahead` = average line length in front of you.
-- Returns coins (after the daily cap), fights, crowns, retires.
function Sim.day(rng: () -> number, minutes: number, ahead: number, day: number)
	local fight = Sim.fightSeconds()
	local profile = HillRules.newProfile()
	local now = day * 86400
	local t, fights, crowns, retires, coins = 0, 0, 0, 0, 0
	local winRate = Balance.EconomyModel.WinRate
	local ticksPerFight = math.floor((fight - Hill.GapSeconds) / Hill.Coins.TickSeconds)
	while t + fight <= minutes * 60 do
		-- Wait in line: the fights in front of you (a random 0..2*ahead).
		t += math.floor(rng() * (2 * ahead + 1)) * fight
		if t + fight > minutes * 60 then
			break
		end
		t += fight
		fights += 1
		if rng() >= winRate then
			coins += HillRules.pay(profile, "Loss", now + t)
			continue
		end
		coins += HillRules.pay(profile, "Take", now + t)
		crowns += 1
		local reign = 0
		while t + fight <= minutes * 60 do
			t += fight
			fights += 1
			for _ = 1, ticksPerFight do
				coins += HillRules.pay(profile, "Tick", now + t)
			end
			if rng() >= winRate then
				coins += HillRules.pay(profile, "Loss", now + t)
				break
			end
			reign += 1
			coins += HillRules.pay(profile, "Defence", now + t)
			if reign >= Hill.ReignCap then
				coins += HillRules.pay(profile, "Retire", now + t)
				retires += 1
				break
			end
		end
	end
	return coins, fights, crowns, retires, t / 60
end

function Sim.report(seed: number?): string
	local rng = Rng.new(seed or 105)
	local e = Balance.EconomyModel
	local normal = Sim.normalPerMinute(rng)
	local lines = {
		"Crown Hill economy (decision 105): sudden death, "
			.. Hill.ReignCap
			.. "-defence cap, daily cap "
			.. Hill.Coins.DailyCap,
		string.format("Hill fight ~%d s; normal play earns %.1f coins/min from matches", Sim.fightSeconds(), normal),
	}
	for _, case in
		{
			{ "15 min on the hill, empty line", 15, 0 },
			{ "15 min on the hill, ~1 ahead in line", 15, 1 },
			{ "40 min on the hill (whole session), empty line", e.SessionMinutes, 0 },
		}
	do
		local days, coins, fights, crowns, retires, minutes = 4000, 0, 0, 0, 0, 0
		for day = 1, days do
			local c, f, cr, r, m = Sim.day(rng, case[2], case[3], day)
			coins += c
			fights += f
			crowns += cr
			retires += r
			minutes += m
		end
		local perMinute = coins / math.max(minutes, 1e-6)
		-- The session's other minutes are normal play; compare the day's match coins with an all-normal day.
		local hillDay = coins / days + (e.SessionMinutes - case[2]) * normal
		local normalDay = e.SessionMinutes * normal
		table.insert(
			lines,
			string.format(
				"  %s: %.1f coins/min on the hill (%.2fx normal), %.0f coins/day there, %.1f crowns/day, %.0f%% of reigns retire; day total %+.0f%% vs all-normal",
				case[1],
				perMinute,
				perMinute / normal,
				coins / days,
				crowns / days,
				100 * retires / math.max(crowns, 1),
				100 * (hillDay / normalDay - 1)
			)
		)
	end
	return table.concat(lines, "\n")
end

return Sim
