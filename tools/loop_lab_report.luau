-- Fixed default-aim fixtures for the private six-glassy lab, not a production balance or player study.
local Session = require("../src/server/Dev/LoopLab/Session")
local C = require("../src/shared/Config/LoopLab")
local B = require("../src/shared/Config/Balance")
local function percentile(values, p)
	table.sort(values)
	return values[math.max(1, math.ceil(#values * p))] or 0
end
local fights, impacts, powers, timeouts = {}, {}, {}, 0
print("36 private lab fixtures: default aim, isolated 60% HP, existing automatic powers")
for _, id in C.Roster do
	local durations, wins = {}, 0
	for rivalIndex = 1, #C.Roster do
		local seed = C.Seed + ((rivalIndex - 1 - C.Seed) % #C.Roster)
		local session = Session.new("B", id, seed, 0)
		session:launch(B.Motion.AimDefault, 0, 0)
		local now = 0
		while session.Phase ~= "Result" and now < 100 do
			now += C.Step
			session:step(C.Step, now)
		end
		assert(session.Phase == "Result", "unresolved fixture: " .. id)
		table.insert(durations, session.Sim.Fight.Time)
		table.insert(fights, session.Sim.Fight.Time)
		if session.FirstImpactSeconds then
			table.insert(impacts, session.FirstImpactSeconds)
		end
		if session.FirstPowerSeconds then
			table.insert(powers, session.FirstPowerSeconds)
		end
		wins += if session.Winner == 1 then 1 else 0
		timeouts += if session.Reason == "Timeout" then 1 else 0
		if session.Sim.Fight.Time > 20 then
			print(
				string.format(
					"  Slow fixture %s vs %s: %.2fs, %d contacts, %s, seed %d",
					id,
					session.Rival,
					session.Sim.Fight.Time,
					session.Contacts,
					session.Reason,
					seed
				)
			)
		end
	end
	print(
		string.format(
			"%s: fight median %.2fs, p90 %.2fs, %d/6 wins",
			id,
			percentile(durations, 0.5),
			percentile(durations, 0.9),
			wins
		)
	)
end
print(
	string.format(
		"All: fight median %.2fs / p90 %.2fs; first impact %.2fs / %.2fs (%d/36); first power %.2fs / %.2fs (%d/36); %d timeouts; transition %.2fs",
		percentile(fights, 0.5),
		percentile(fights, 0.9),
		percentile(impacts, 0.5),
		percentile(impacts, 0.9),
		#impacts,
		percentile(powers, 0.5),
		percentile(powers, 0.9),
		#powers,
		timeouts,
		C.ContinueSeconds
	)
)
