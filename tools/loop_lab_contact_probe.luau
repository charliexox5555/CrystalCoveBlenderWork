-- Private geometry probe: change only hook spacing on disposable real-swing fixtures.
local Session = require("../src/server/Dev/LoopLab/Session")
local C = require("../src/shared/Config/LoopLab")
local B = require("../src/shared/Config/Balance")
local Pendulum = require("../src/server/Simulation/Pendulum")
for _, fixture in { { "glass_cup", 291029 }, { "ketchup_bottle", 291027 } } do
	for _, gap in { 4.5, 5, 5.5, 6, 6.5, 7, 7.5 } do
		local s = Session.new("B", fixture[1], fixture[2], 0)
		local originalGap = (s.Sim.Hooks[2] - s.Sim.Hooks[1]).Magnitude
		for side, hook in s.Sim.Hooks do
			s.Sim.Hooks[side] = hook * (gap / originalGap)
		end
		s:launch(B.Motion.AimDefault, 0, 0)
		local now, previous, longest, hits = 0, 0, 0, {}
		local nearest, pose = math.huge, ""
		while s.Phase ~= "Result" and now < 45 do
			now += C.Step
			s:step(C.Step, now)
			if gap == 6 and now > 15 then
				local distance = (Pendulum.center(s.Sim, 1) - Pendulum.center(s.Sim, 2)).Magnitude
				if distance < nearest then
					nearest = distance
					local a, b = s.Sim.Bodies[1], s.Sim.Bodies[2]
					pose = string.format(
						"t%.2f X velocities %.2f/%.2f Z positions %.2f/%.2f",
						now,
						a.V.X,
						b.V.X,
						a.P.Z,
						b.P.Z
					)
				end
			end
			local packet = s:packet()
			for _, e in packet.Events do
				if e.Type == "Hit" then
					longest = math.max(longest, e.Time - previous)
					previous = e.Time
					table.insert(hits, string.format("%.1f", e.Time))
				end
			end
		end
		longest = math.max(longest, s.Sim.Fight.Time - previous)
		if gap == 6 then
			print(
				string.format(
					"After15s: nearest %.3f vs radius %.3f; %s",
					nearest,
					(s.Sim.Fight.Fighters[1].Radius + s.Sim.Fight.Fighters[2].Radius) * B.Motion.GlassyScale,
					pose
				)
			)
		end
		print(
			string.format(
				"%s vs %s gap %.1f: %.2fs %s, %d hits, max contact gap %.2fs [%s]",
				s.Id,
				s.Rival,
				gap,
				s.Sim.Fight.Time,
				s.Reason,
				s.Contacts,
				longest,
				table.concat(hits, ",")
			)
		)
	end
end
