-- Edit/MCP only. Copies the creator's lobby kilns (Workspace.Kilns.Kiln / MarbleKiln, read only) into
-- ReplicatedStorage.Assets.Kilns.{Coins,Marbles} for the shop preview and the Glassy opening.
-- Copies keep the creator's colours, face -Z like the crate machines and pivot at the floor centre.
-- ReplicatedStorage.Assets.Crates.Glassies (the older preview kiln) is left untouched as a fallback.
assert(not game:GetService("RunService"):IsRunning(), "Install in Edit")
local RS = game.ReplicatedStorage
assert(not RS.Assets:FindFirstChild("Kilns"), "Already installed; remove Assets.Kilns to rebuild")
local sources = { Coins = workspace.Kilns.Kiln, Marbles = workspace.Kilns.MarbleKiln }
local folder = Instance.new("Folder")
folder.Name = "Kilns"
folder:SetAttribute("Source", "Workspace.Kilns")
local report = {}
for currency, source in sources do
	local visuals = assert(source:FindFirstChild("VisualsV2"), "Expected VisualsV2 in " .. source:GetFullName())
	local model = Instance.new("Model")
	model.Name = currency
	-- World kilns face +Z around their prompt pivot; turn them to face -Z like the crate machines.
	local toLocal = CFrame.Angles(0, math.pi, 0) * source:GetPivot():Inverse()
	local count = 0
	for _, part in visuals:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			local copy = part:Clone()
			for _, child in copy:GetChildren() do
				if not child:IsA("SpecialMesh") then
					child:Destroy()
				end
			end
			copy.CFrame = toLocal * part.CFrame
			copy.Anchored, copy.CanCollide, copy.CanTouch, copy.CanQuery = true, false, false, false
			copy:SetAttribute("CurrencyTint", nil)
			copy.Parent = model
			count += 1
		end
	end
	local box, size = model:GetBoundingBox()
	local floor = Vector3.new(box.Position.X, box.Position.Y - size.Y / 2, box.Position.Z)
	for _, part in model:GetChildren() do
		part.CFrame = part.CFrame - floor
	end
	model.WorldPivot = CFrame.identity
	model:SetAttribute("Currency", currency)
	model:SetAttribute("FrontFaces", "-Z")
	model:SetAttribute("SourceModel", source:GetFullName())
	model.Parent = folder
	report[currency] = count
end
folder.Parent = RS.Assets
return report
