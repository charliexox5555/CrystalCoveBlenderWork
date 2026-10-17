local RS = game.ReplicatedStorage
local G = require(RS.Shared.Config.Glassies)
local C = require(RS.Shared.Config.RoundCosmetics)
local Glassy = require(script.Parent.GlassyPortrait)
local Cosmetic = require(script.Parent.CosmeticPortrait)
local P = {}
function P.definition(category, id)
	return if category == "Glassies" then G.get(id) else C.ByCategory[category][id]
end
function P.portrait(parent, category, id, size, position, name)
	name = name or "Portrait"
	local slot = parent:FindFirstChild(name)
	if category == "Glassies" then
		return Glassy.new(parent, id, size, position, name)
	end
	return Cosmetic.new(
		parent,
		category,
		id,
		size or slot and slot.Size or UDim2.fromScale(1, 1),
		position or slot and slot.Position or UDim2.new(),
		name
	)
end
function P.crate(parent, category, currency, size, position, name)
	local U = require(script.Parent.Util)
	local source = if category == "Glassies"
		then game.StarterGui.KilnScreen.Panel.Content.GlassiesPage.CoinKiln:FindFirstChild("KilnPortrait", true)
		else nil
	local viewport = U.make("ViewportFrame", parent, {
		Name = name or "CratePortrait",
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(190, 205, 225),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -2),
	})
	for _, child in viewport:GetChildren() do
		if child:IsA("WorldModel") or child:IsA("Camera") then
			child:Destroy()
		end
	end
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local Machine = require(script.Parent.Parent.Parent.Presentation.CrateMachine)
	local machine = if category ~= "Glassies" then Machine.template(category, currency) else nil
	local crates = RS.Assets:FindFirstChild("Crates")
	local model = machine or crates and crates:FindFirstChild(category)
	if model then
		model = model:Clone()
		model.Parent = world
		if machine then
			-- Invisible marker so the camera fit leaves room for the lid to pop up during the opening.
			local pose, size = model:GetBoundingBox()
			local headroom = Instance.new("Part")
			headroom.Name, headroom.Transparency, headroom.Size = "FrameHeadroom", 1, Vector3.one * 0.1
			headroom.Anchored, headroom.CanCollide, headroom.CanQuery = true, false, false
			headroom.CFrame = CFrame.new(
				pose.Position
					+ Vector3.yAxis * (size.Y / 2 + require(RS.Shared.Config.CrateMachines).Opening.LidLiftStuds)
			)
			headroom.Parent = world
		end
	elseif source then
		local original = source:FindFirstChildOfClass("WorldModel")
		if original then
			for _, obj in original:GetChildren() do
				obj:Clone().Parent = world
			end
		end
	end
	for _, p in world:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("CurrencyTint") then
			p.Color = if currency == "Marbles" then Color3.fromHex("#93BCFF") else Color3.fromHex("#FFD98A")
		end
	end
	local rotation =
		CFrame.lookAt(if category == "Glassies" then Vector3.new(1.2, 0.4, 4) else Vector3.new(-3, 2, -8), Vector3.zero)
	Glassy.fitOnResize(viewport, rotation, 35, 1.04)
	if machine then
		Machine.attachViewport(viewport, model)
	end
	return viewport, world
end
return P
