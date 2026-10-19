-- Play / Client (Studio MCP execute_luau): runs every standard finisher the way the inventory/shop preview does
-- (a WorldModel inside a ViewportFrame, camera-facing, preview audio), plus the portrait still, and checks that
-- each preview ends on time, leaves nothing behind and stays inside the portrait's fitted radius.
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Client = Players.LocalPlayer.PlayerScripts.Client
local FX = require(Client.Presentation.FinisherFX)
local Audio = require(Client.Presentation.FinisherAudio)
local Still = require(Client.UI.Components.FinisherStill)
local Balance = require(game.ReplicatedStorage.Shared.Config.Balance).CosmeticPresentation
local fitRadius = Balance.FinisherRadius + Balance.FinisherCoreSize / 2
local gui = Instance.new("ScreenGui")
gui.Name = "FinisherPreviewQA"
gui.Parent = Players.LocalPlayer.PlayerGui
local lines = {}
for _, id in { "glass_burst", "party_burst", "bubble_bloom", "brick_boom", "starfall" } do
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromOffset(320, 320)
	viewport.Parent = gui
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, 24), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local before = #SoundService:GetChildren()
	local root = FX.emit(world, id, Vector3.zero, false, camera.CFrame.Rotation)
	Audio.preview(root, id)
	local maxReach, sounds = 0, 0
	local t0 = os.clock()
	while root.Parent and os.clock() - t0 < FX.duration(id) + 1 do
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then
				maxReach = math.max(maxReach, d.Position.Magnitude + d.Size.Magnitude / 2)
			end
		end
		sounds = math.max(sounds, #SoundService:GetChildren() - before)
		task.wait(0.05)
	end
	local ended = os.clock() - t0
	local stillModel = Instance.new("Model")
	stillModel.Parent = world
	local built = Still.build(stillModel, id)
	local stillParts = #stillModel:GetDescendants()
	viewport:Destroy()
	table.insert(
		lines,
		string.format(
			"%s: ended %.2f s (show %.2f), max reach %.1f studs (fit radius %.1f), peak preview sounds %d, still %s (%d instances), world after %s",
			id,
			ended,
			FX.duration(id),
			maxReach,
			fitRadius,
			sounds,
			tostring(built),
			stillParts,
			tostring(world.Parent)
		)
	)
end
gui:Destroy()
return table.concat(lines, "\n")
