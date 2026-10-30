local Session = if script
	then require(game.ServerScriptService.Server.Dev.LoopLab.Session)
	else require("../server/Dev/LoopLab/Session")
local C = if script then require(game.ReplicatedStorage.Shared.Config.LoopLab) else require("../shared/Config/LoopLab")
return function(t, d)
	t.test("continuous play starts the next duel without an aiming or replay gate", function()
		local s = Session.new("B", "pop", 42, 0)
		s:launch(0.7, 0.1, 0)
		s.NextId = "jam"
		s:finish(10, "test")
		local following = s:next(11.25, 43)
		t.eq(following.Mode, "B")
		t.eq(following.Id, "jam")
		t.eq(following.Phase, "Flight")
		t.eq(following.Shots, 1)
		t.eq(following.Trace[1].Aim, 0.7)
		t.eq(s.Id, "pop", "queued switch does not change the current duel")
	end)
	t.test("private loop rejects malformed launches and launches outside its aim phase", function()
		local s = Session.new("A", "pop", 42, 0)
		t.ok(not s:launch(0 / 0, 0, 0))
		t.ok(not s:launch(1, math.huge, 0))
		t.ok(not s:launch("bad", 0, 0))
		t.ok(s:launch(0.8, 0, 0))
		t.ok(not s:launch(1, 0, 0))
		t.eq(s.Shots, 1)
	end)
	t.test("repeated clashes preserve duel HP and signature state between launches", function()
		local s = Session.new("A", "pop", 12, 0)
		local fighter = s.Sim.Fight.Fighters[1]
		local signature = fighter.Signature
		local now = 0
		s:launch(0.8, 0, now)
		while s.Phase ~= "Aim" and s.Phase ~= "Result" and now < 8 do
			now += C.Step
			s:step(C.Step, now)
		end
		t.eq(s.Phase, "Aim")
		local hp = fighter.Hp
		t.ok(s:launch(0.9, 0.1, now))
		t.eq(s.Sim.Fight.Fighters[1], fighter)
		t.eq(fighter.Signature, signature)
		t.eq(fighter.Hp, hp)
		t.eq(s.Shots, 2)
	end)
	t.test("auto duel requires only one launch and resolves using the real swing", function()
		local s = Session.new("B", "jam", 12, 0)
		s:launch(0.8, 0, 0)
		local now = 0
		while s.Phase ~= "Result" and now < 45 do
			now += C.Step
			s:step(C.Step, now)
		end
		t.eq(s.Phase, "Result")
		t.eq(s.Shots, 1)
		t.ok(s.Contacts > 0)
		t.ok(s.Winner == 1 or s.Winner == 2)
	end)
	t.test("both prototypes clamp inputs and safely finish unattended play", function()
		for _, mode in { "A", "B" } do
			local s = Session.new(mode, "prism", 3, 0)
			s:launch(999, -999, 0)
			t.eq(s.Trace[1].Aim, d.Balance.Motion.AimMax)
			t.eq(s.Trace[1].Yaw, -d.Balance.Motion.AimYawMax)
			local now = 0
			while s.Phase ~= "Result" and now < 100 do
				now += C.Step
				s:step(C.Step, now)
			end
			t.eq(s.Phase, "Result")
			t.ok(s.Shots <= C.MaxShots)
		end
	end)
end
