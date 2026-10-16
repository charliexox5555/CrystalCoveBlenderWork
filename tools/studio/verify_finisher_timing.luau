-- Play/Client: cosmetic timing, bounded geometry and cancellation; no combat simulation.
local FX = require(game.Players.LocalPlayer.PlayerScripts.Client.Presentation.FinisherFX)
local C = require(game.ReplicatedStorage.Shared.Config.RoundCosmetics)
local root = Instance.new("Folder")
root.Name, root.Parent = "FinisherTimingCheck", workspace
local humanoid = game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
local health = humanoid.Health
local checks, effects = 0, {}
local function check(value, message)
	assert(value, message)
	checks += 1
end
local function bounded()
	for _, effect in effects do
		check(#effect:GetChildren() <= 20, "At most twenty full-detail parts")
		for _, p in effect:GetChildren() do
			check(
				p:IsA("BasePart") and p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery,
				"Nonphysical geometry"
			)
		end
	end
end
local ok, problem = pcall(function()
	for i, def in C.Finishers do
		effects[def.Id] = FX.emit(root, def.Id, Vector3.new(i * 25, 210, 3000), false, CFrame.identity)
		local reduced = FX.emit(root, def.Id, Vector3.new(i * 25, 240, 3000), true, CFrame.identity)
		check(#reduced:GetChildren() <= 8, "Reduced-detail budget")
	end
	local nova = effects.starfall
	check(nova.BurstCore.Transparency == 1 and nova.Shockwave.Transparency == 1, "Nova holds flash until collapse")
	check(nova.NovaRay.Transparency == 1, "Nova rays wait for convergence")
	bounded()
	task.wait(0.2)
	check(nova.BurstCore.Size.X < 0.4, "Nova has no premature explosion")
	check((nova.StarGem.Position - Vector3.new(125, 210, 3000)).Magnitude < 1, "Stars converge before release")
	task.wait(0.32)
	check(nova.BurstCore.Size.X > 1 and nova.NovaRay.Size.X > 1, "Convergence releases core and rays")
	check((nova.StarGem.Position - Vector3.new(125, 210, 3000)).Magnitude > 1, "Stars burst outward")
	local confetti = effects.party_burst.BurstPiece
	local block = effects.brick_boom.BurstPiece
	local confettiY, blockY = confetti.Position.Y, block.Position.Y
	task.wait(0.48)
	check(confetti.Position.Y < confettiY, "Confetti tumbles down after launch")
	check(block.Position.Y < blockY, "Heavy blocks fall after the toss")
	local popCount = 0
	for _, p in effects.bubble_bloom:GetChildren() do
		if p.Name == "BubblePop" then
			popCount += 1
		end
	end
	check(popCount == 3, "Three bounded bubble pop ripples")
	bounded()
	check(humanoid.Health == health, "Effects preserve real avatar health")
	-- Destroy while delayed flash/pop/fall callbacks are still pending.
	local cancelled = FX.emit(root, "starfall", Vector3.zero, false, CFrame.identity)
	cancelled:Destroy()
	local cancelledBubble = FX.emit(root, "bubble_bloom", Vector3.zero, false, CFrame.identity)
	cancelledBubble:Destroy()
	task.wait(1.5)
	check(#root:GetChildren() == 0, "Effects expire and cancelled callbacks create no leftovers")
end)
root:Destroy()
assert(ok, problem)
return { Passed = checks, MaxFullDetailParts = 20, MaxReducedDetailParts = 8, AvatarHealth = humanoid.Health }
