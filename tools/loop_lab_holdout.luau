-- Fresh seeds and edge aims for a proposed private-stage spacing. No production config mutation.
local Session = require("../src/server/Dev/LoopLab/Session")
local C = require("../src/shared/Config/LoopLab")
local B = require("../src/shared/Config/Balance")
local gap = tonumber(require("@lune/process").args[1]) or C.HookGap or B.Motion.HookGap
local function p(values, fraction)
	table.sort(values)
	return values[math.ceil(#values * fraction)] or 0
end
for _, aim in
	{ { B.Motion.AimMin, -B.Motion.AimYawMax }, { B.Motion.AimDefault, 0 }, { B.Motion.AimMax, B.Motion.AimYawMax } }
do
	local times, gaps, timeouts, long, power = {}, {}, 0, 0, 0
	for _, id in C.Roster do
		for rival = 1, #C.Roster do
			for _, offset in { 6, 12 } do
				local seed = C.Seed + ((rival - 1 - C.Seed) % #C.Roster) + offset
				local s = Session.new("B", id, seed, 0)
				local original = (s.Sim.Hooks[2] - s.Sim.Hooks[1]).Magnitude
				for side, hook in s.Sim.Hooks do
					s.Sim.Hooks[side] = hook * (gap / original)
				end
				s:launch(aim[1], aim[2], 0)
				local now, last, longest = 0, 0, 0
				while s.Phase ~= "Result" and now < 45 do
					now += C.Step
					s:step(C.Step, now)
					for _, e in s:packet().Events do
						if e.Type == "Hit" then
							longest = math.max(longest, e.Time - last)
							last = e.Time
						end
					end
				end
				assert(s.Phase == "Result", "fixture did not finish")
				table.insert(times, s.Sim.Fight.Time)
				table.insert(gaps, math.max(longest, s.Sim.Fight.Time - last))
				timeouts += if s.Reason == "Timeout" then 1 else 0
				long += if s.Sim.Fight.Time > 25 then 1 else 0
				power += if s.FirstPowerSeconds then 1 else 0
			end
		end
	end
	print(
		string.format(
			"gap %.1f aim %.2f/yaw %.2f: n%d fight median %.2fs/p90 %.2fs/max %.2fs; max contact-gap median %.2fs/p90 %.2fs; timeout%d >25s%d powers%d",
			gap,
			aim[1],
			aim[2],
			#times,
			p(times, 0.5),
			p(times, 0.9),
			p(times, 1),
			p(gaps, 0.5),
			p(gaps, 0.9),
			timeouts,
			long,
			power
		)
	)
end
