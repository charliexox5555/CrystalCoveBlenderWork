-- Edit only: refine this pass's new triangular ray wings and new detail controls.
assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local source = game.ReplicatedStorage.Assets.Rideables.prism_ray
local backups = game.ServerStorage.LobbyBeforeNight_20261016
assert(not backups:FindFirstChild("PrismRayBeforeWingRefine"), "Already refined")
local old = source:Clone()
old.Name, old.Parent = "PrismRayBeforeWingRefine", backups
for _, p in source:GetChildren() do
	if p:GetAttribute("RideMotion") == "Wing" then
		local side = p:GetAttribute("WingSide")
		p.Size = Vector3.new(0.32, 3.5, 4)
		p.CFrame = CFrame.new(side * 2.5, -0.4, 0) * CFrame.Angles(0, 0, side * math.pi / 2)
	end
end
local display = workspace.Lobby.NightPolishV1.Showcase_prism_ray
for _, p in display:GetChildren() do
	if p:GetAttribute("RideMotion") == "Wing" then
		local side = p:GetAttribute("WingSide")
		p.Size = Vector3.new(0.32, 3.5, 4) * 0.65
		p.CFrame = display:GetPivot()
			* CFrame.new(Vector3.new(side * 2.5, -0.4, 0) * 0.65)
			* CFrame.Angles(0, 0, side * math.pi / 2)
	end
end
for _, parent in
	{
		game.StarterGui.CollectionScreen.Panel.Content,
		game.StarterGui.KilnScreen.Panel.Content.FlyersPage,
		game.StarterGui.KilnScreen.Panel.Content.FinishersPage,
	}
do
	local info = parent.CosmeticPage.Details
	info.Description.Position = UDim2.fromScale(0, 0.47)
	info.Ownership.Position = UDim2.fromScale(0, 0.66)
	info.Preview.Size, info.Preview.Position = UDim2.fromScale(1, 0.1), UDim2.fromScale(0.5, 0.8)
	info.Equip.Size, info.Equip.Position = UDim2.fromScale(1, 0.1), UDim2.fromScale(0.5, 0.93)
end
return { RayWings = "Triangular plan silhouette", ControlSpacing = "Updated only newly created cosmetic templates" }
