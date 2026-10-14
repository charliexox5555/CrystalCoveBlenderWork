local Pendulum = if script
	then require(game.ServerScriptService.Server.Simulation.Pendulum)
	else require("../server/Simulation/Pendulum")
local Codec = if script
	then require(game.ReplicatedStorage.Shared.SnapshotCodec)
	else require("../shared/SnapshotCodec")

return function(t, d)
	t.test("binary fight snapshots round-trip within display precision", function()
		local sim = Pendulum.new({
			A = { Id = "jam", Aim = 1.0, AimYaw = 0.3 },
			B = { Id = "prism", Aim = 0.8, AimYaw = -0.2 },
			Rng = d.Rng.new(7),
			SweetSpot = 0.9,
		}, 7)
		for _ = 1, 900 do
			Pendulum.step(sim, 1 / d.Balance.Motion.StepRate)
		end
		local snapshot = Pendulum.snapshot(sim)
		snapshot.R.Shield[2], snapshot.R.Rage[1], snapshot.R.Effect[2][1] = true, true, 1.237
		local sentAt = 1792014658.62613
		local packet = Codec.encode(4321, snapshot, sentAt)
		t.eq(buffer.len(packet), Codec.Size, "fixed size")
		t.ok(Codec.Size <= 160, "well under the unreliable remote budget")
		local key, out = Codec.decode(packet)
		t.eq(key, 4321, "fight key")
		t.near(out.SentAt, sentAt, 1e-6, "server send time keeps full precision")
		t.near(out.T, snapshot.T, 1e-4, "fight time")
		for side = 1, 2 do
			for i = 1, 10 do
				t.near(out.B[side][i], snapshot.B[side][i], 1e-4, "body value " .. i)
			end
			t.near(out.R.Hp[side], snapshot.R.Hp[side], 1e-3, "hp")
			t.near(out.R.Power[side], snapshot.R.Power[side], 1e-4, "power glow")
			for _, flag in { "Rage", "Shield", "Frozen", "Pump", "Slam" } do
				t.eq(out.R[flag][side], snapshot.R[flag][side], flag .. " flag side " .. side)
			end
			for i = 1, 5 do
				t.near(out.R.Effect[side][i], snapshot.R.Effect[side][i], 0.006, "effect timer")
			end
		end
	end)

	t.test("malformed packets are rejected", function()
		local key, out = Codec.decode(buffer.create(3))
		t.eq(key, nil, "no key")
		t.eq(out, nil, "no snapshot")
	end)
end
