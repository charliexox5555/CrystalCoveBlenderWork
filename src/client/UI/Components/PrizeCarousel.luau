-- Five reusable slots; no user-scroll input, no per-frame model recreation.
local Item = require(script.Parent.ItemPresentation)
local U = require(script.Parent.Util)
local Theme = require(script.Parent.Parent.Theme)
local S = require(script.Parent.StainedGlass)
local Carousel = {}
Carousel.__index = Carousel
function Carousel.new(root, category, odds, template, selected)
	local self = setmetatable(
		{ Root = root, Category = category, Odds = odds, Slots = {}, Connections = {}, Offset = 0 },
		Carousel
	)
	root.ClipsDescendants = true
	root.Active = false
	for _, child in root:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i = 1, 5 do
		local tile = template:Clone()
		tile.Name = "Prize" .. i
		tile.Visible = true
		tile.Size = UDim2.fromScale(0.31, 0.98)
		tile.AnchorPoint = Vector2.new(0.5, 0.5)
		tile.Parent = root
		local aspect = tile:FindFirstChildOfClass("UIAspectRatioConstraint")
		if aspect then
			aspect:Destroy()
		end
		tile.SelectedOutline.Visible = false
		for _, object in { tile.Artwork, tile.NamePlaque, tile.Portrait } do
			local constraint = object:FindFirstChildOfClass("UIAspectRatioConstraint")
			if constraint then
				constraint:Destroy()
			end
		end
		tile.Artwork.Size, tile.Artwork.Position = UDim2.fromScale(1, 1), UDim2.new()
		tile.Artwork.AnchorPoint = Vector2.zero
		tile.Artwork.ScaleType = Enum.ScaleType.Stretch
		tile.Portrait.ZIndex = 2
		local oddsLabel =
			U.text(tile, "Chance", "", UDim2.fromScale(0.95, 0.12), UDim2.fromScale(0.025, 0.87), Theme.Fonts.Caption)
		tile:FindFirstChild("Name").Size = UDim2.fromScale(0.95, 0.17)
		tile:FindFirstChild("Name").Position = UDim2.fromScale(0.025, 0.73)
		tile:FindFirstChild("Name").AnchorPoint = Vector2.zero
		tile:FindFirstChild("Name").ZIndex = 3
		oddsLabel.ZIndex = 3
		oddsLabel.TextColor3 = Color3.fromRGB(45, 35, 65)
		tile.NamePlaque.AnchorPoint = Vector2.new(0.5, 0.5)
		tile.NamePlaque.Size, tile.NamePlaque.Position = UDim2.fromScale(0.99, 0.3), UDim2.fromScale(0.5, 0.85)
		tile.Portrait.Size, tile.Portrait.Position = UDim2.fromScale(0.92, 0.64), UDim2.fromScale(0.5, 0.34)
		local slot = { Object = tile, Chance = oddsLabel }
		table.insert(self.Slots, slot)
		table.insert(
			self.Connections,
			tile.Open.Activated:Connect(function()
				if slot.Entry then
					selected(slot.Entry)
				end
			end)
		)
	end
	self:Step(0)
	return self
end
function Carousel:Step(dt)
	if #self.Odds == 0 then
		return
	end
	self.Offset = (self.Offset + dt * 0.32) % #self.Odds
	local whole = math.floor(self.Offset)
	for i, slot in self.Slots do
		local entry = self.Odds[(whole + i - 1) % #self.Odds + 1]
		local tile = slot.Object
		tile.Position = UDim2.fromScale((i - 1 - self.Offset % 1) * 0.34 + 0.155, 0.49)
		if not slot.Entry or slot.Entry.Id ~= entry.Id then
			slot.Entry = entry
			local def = Item.definition(self.Category, entry.Id)
			tile:FindFirstChild("Name").Text = def.Name
			slot.Chance.Text = string.format("%.3g%%", entry.Chance * 100)
			S.setAsset(tile.Artwork, "tile/tile_" .. S.rarity(def.Rarity))
			tile.Artwork.ScaleType = Enum.ScaleType.Stretch
			Item.portrait(tile, self.Category, entry.Id)
		end
	end
end
function Carousel:Destroy()
	for _, c in self.Connections do
		c:Disconnect()
	end
	for _, slot in self.Slots do
		slot.Object:Destroy()
	end
end
return Carousel
