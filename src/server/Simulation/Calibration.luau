-- Studio: require(game.ServerScriptService.Server.Simulation.Calibration).run(30, 100)
local Shared = if script then game.ReplicatedStorage.Shared else nil
local Balance = if Shared then require(Shared.Config.Balance) else require("../../shared/Config/Balance")
local Rules = if Shared then require(Shared.FightRules) else require("../../shared/FightRules")
local Rng = if Shared then require(Shared.Rng) else require("../../shared/Rng")
local Pendulum = if script then require(script.Parent.Pendulum) else require("./Pendulum")
local Calibration = {}

local function percentile(values, p)
	if #values == 0 then
		return 0
	end
	table.sort(values)
	return values[math.clamp(math.ceil(#values * p), 1, #values)]
end

function Calibration.round(a, b, seed, opts)
	local o = opts or {}
	local rng = Rng.new(seed)
	local sweet = Rules.rollSweetSpot(rng)
	local function setup(id, aim, yaw)
		return {
			Id = id,
			Aim = aim or Rules.botAim(sweet, 0.45, rng),
			AimYaw = yaw or (rng() * 2 - 1) * Balance.Motion.AimYawMax,
		}
	end
	local sim =
		Pendulum.new({ A = setup(a, o.AimA, o.YawA), B = setup(b, o.AimB, o.YawB), SweetSpot = sweet, Rng = rng }, seed)
	local log = {}
	while not sim.Fight.Over do
		Pendulum.step(sim, 1 / Balance.Motion.StepRate)
		for _, e in Pendulum.events(sim) do
			table.insert(log, e)
		end
	end
	sim.Log = log
	return sim
end

function Calibration.run(count, firstSeed)
	count, firstSeed = count or 30, firstSeed or 100
	local roster = { "pop", "jam", "prism", "lemonade_bottle", "hot_sauce", "milk_bottle", "glass_cup", "pickle_jar" }
	local summary = {
		Rounds = count,
		Seconds = 0,
		Hits = 0,
		Misses = 0,
		Timeouts = 0,
		MaxRadiusError = 0,
		Powers = {},
		Landed = {},
		RoundsLog = {},
	}
	local speeds, shares, lengths = {}, {}, {}
	for i = 1, count do
		local a, b = roster[(i - 1) % #roster + 1], roster[(i + 1) % #roster + 1]
		local sim = Calibration.round(a, b, firstSeed + i)
		local f, m = sim.Fight, sim.Metrics
		summary.Seconds += f.Time
		summary.Hits += f.Hits
		summary.Misses += m.Misses
		summary.Timeouts += if f.Reason == "Timeout" then 1 else 0
		summary.MaxRadiusError = math.max(summary.MaxRadiusError, m.MaxRadiusError)
		table.insert(lengths, f.Time)
		for _, speed in m.Speeds do
			table.insert(speeds, speed)
		end
		for _, share in m.Shares do
			table.insert(shares, share)
		end
		for id, n in m.Powers do
			summary.Powers[id] = (summary.Powers[id] or 0) + n
			summary.Landed[id] = (summary.Landed[id] or 0) + (m.Landed[id] or 0)
		end
		table.insert(
			summary.RoundsLog,
			{ Seed = firstSeed + i, A = a, B = b, Time = f.Time, Hits = f.Hits, Winner = f.Winner }
		)
		if script and i % 3 == 0 then
			task.wait()
		end
	end
	summary.HitsPerSecond = summary.Hits / summary.Seconds
	summary.MissChance = summary.Misses / math.max(1, summary.Hits + summary.Misses)
	summary.EncounterInterval = summary.Seconds / math.max(1, summary.Hits + summary.Misses)
	summary.SpeedP10, summary.SpeedMedian, summary.SpeedP90 =
		percentile(speeds, 0.1), percentile(speeds, 0.5), percentile(speeds, 0.9)
	summary.ShareP10, summary.ShareMedian, summary.ShareP90 =
		percentile(shares, 0.1), percentile(shares, 0.5), percentile(shares, 0.9)
	summary.RoundP10, summary.RoundMedian, summary.RoundP90 =
		percentile(lengths, 0.1), percentile(lengths, 0.5), percentile(lengths, 0.9)
	return summary
end

return Calibration
