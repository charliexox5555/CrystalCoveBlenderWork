local Runner = if script
	then require(game.ServerScriptService.Server.Simulation.MatchRunner)
	else require("../server/Simulation/MatchRunner")
local Guard = if script
	then require(game.ServerScriptService.Server.Util.RemoteGuard)
	else require("../server/Util/RemoteGuard")

return function(t, d)
	local function new()
		return Runner.new({
			{ Collection = { milk_bottle = {}, pickle_jar = {}, ketchup_bottle = {}, glass_cup = {} } },
			{ Collection = {} },
		}, d.Rng.new(42), 0)
	end
	t.test("picks and locks control phase transitions, with timeout defaults", function()
		local r = new()
		t.eq(r:Pick(1, "not_owned"), false)
		for side = 1, 2 do
			t.eq(r:Pick(side, r.Match.Sides[side].Offers[1]), true)
		end
		r:Step(0)
		t.eq(r.Phase, "Aiming")
		r:Aim(1, 0.9, 0.2)
		r:Step(d.Balance.Match.AimSeconds - 0.1)
		t.eq(r.Phase, "Aiming")
		r:Step(d.Balance.Match.AimSeconds)
		t.eq(r.Phase, "Countdown")
		t.eq(r.Match.Sides[2].Aim, d.Balance.Motion.AimDefault)
		r:Step(d.Balance.Match.AimSeconds + d.Balance.Match.CountdownSeconds - 0.1)
		t.eq(r.Phase, "Countdown")
		r:Step(d.Balance.Match.AimSeconds + d.Balance.Match.CountdownSeconds)
		t.eq(r.Phase, "Fighting")
		t.eq(r:Pick(1, "pop"), false)
		t.eq(r:FightEnded(1, d.Balance.Match.AimSeconds + d.Balance.Match.CountdownSeconds + 1), true)
		t.eq(
			r:FightEnded(1, d.Balance.Match.AimSeconds + d.Balance.Match.CountdownSeconds + 1),
			false,
			"duplicate end cannot remove another heart"
		)
		t.eq(r.Match.Sides[2].Hearts, 2)
		r:Step(
			d.Balance.Match.AimSeconds + d.Balance.Match.CountdownSeconds + 1 + d.Balance.Match.RoundEndSeconds - 0.1
		)
		t.eq(r.Phase, "RoundEnd")
		r:Step(d.Balance.Match.AimSeconds + d.Balance.Match.CountdownSeconds + 1 + d.Balance.Match.RoundEndSeconds)
		t.eq(r.Phase, "Rolling")
		t.eq(r.Match.Round, 2)
	end)
	t.test("selection and aiming wait their timers before safe automatic defaults", function()
		local m = d.Balance.Match
		local r = new()
		t.eq(r.Deadline, m.RollSeconds)
		r:Step(m.RollSeconds - 0.1)
		t.eq(r.Phase, "Rolling")
		r:Step(m.RollSeconds)
		t.eq(r.Phase, "Aiming")
		local aimEnd = m.RollSeconds + m.AimSeconds
		t.eq(r.Deadline, aimEnd)
		r:Step(aimEnd - 0.1)
		t.eq(r.Phase, "Aiming")
		r:Step(aimEnd)
		t.eq(r.Phase, "Countdown")
		t.eq(r.Match.Sides[1].Aim, d.Balance.Motion.AimDefault)
		r:Step(aimEnd + m.CountdownSeconds)
		t.eq(r.Phase, "Fighting")
		r:FightEnded(1, aimEnd + m.CountdownSeconds + 5)
		r:Step(aimEnd + m.CountdownSeconds + 5 + m.RoundEndSeconds)
		t.eq(r.Phase, "Rolling")
		t.near(
			r.Deadline,
			aimEnd + m.CountdownSeconds + 5 + m.RoundEndSeconds + m.RollSecondsLater,
			1e-6,
			"later rounds pick faster"
		)
	end)
	t.test("runner executes validated actions; service owns charging", function()
		local r = new()
		t.eq(r:Reroll(1), true)
		t.eq(r.Match.Sides[1].RerollsUsed, 1)
		local ok, reason = r:Reroll(1)
		t.eq(ok, true)
		t.eq(reason, nil)
		t.eq(r.Match.Sides[1].RerollsUsed, 2)
		r:PickAny(1, "milk_bottle")
		t.eq(r.Match.Sides[1].Pick, "milk_bottle")
		t.eq(r:PickAny(1, "pop"), false)
		r.Phase = "Aiming"
		t.eq(r:Reroll(1), false)
	end)
	t.test("three losses end the match and forfeit resolves through MatchLogic", function()
		local r = new()
		r:Forfeit(1, 0)
		t.eq(r.Phase, "MatchEnd")
		t.eq(r.Match.Winner, 2)
		t.eq(r.Match.Sides[1].Hearts, 0)
		t.eq(#r.Match.History, 3)
		r:Forfeit(1, 1)
		t.eq(#r.Match.History, 3)
	end)
	t.test("bot-only orchestration finishes without waiting for input", function()
		local r = Runner.new(
			{ { Collection = {}, IsBot = true, Skill = 0.4 }, { Collection = {}, IsBot = true, Skill = 0.4 } },
			d.Rng.new(55),
			0
		)
		for now = 0, 100 do
			r:Step(now)
			if r.Phase == "Fighting" then
				r:FightEnded(1, now)
			end
			if r.Phase == "MatchEnd" then
				break
			end
		end
		t.eq(r.Phase, "MatchEnd")
		t.eq(r.Match.Winner, 1)
		t.eq(#r.Match.History, 3)
	end)
	t.test("remote guards isolate actions and players and reject non-finite numbers", function()
		local now = 0
		local guard = Guard.new(function()
			return now
		end)
		t.eq(guard:Allow("a", "Aim", 0.05), true)
		t.eq(guard:Allow("a", "Aim", 0.05), false)
		t.eq(guard:Allow("a", "Pick", 0.25), true)
		t.eq(guard:Allow("b", "Aim", 0.05), true)
		now = 0.05
		t.eq(guard:Allow("a", "Aim", 0.05), true)
		for _, n in { 0 / 0, math.huge, -math.huge, "1", {} } do
			t.eq(Guard.finite(n), false)
		end
		t.eq(Guard.finite(0), true)
		guard:Remove("a")
		t.eq(guard.Last.a, nil)
	end)
end
