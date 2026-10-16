local S = require(script.Parent.Parent.Components.StainedGlass)
local Pools = {}
local Item = require(script.Parent.Parent.Components.ItemPresentation)
local U = require(script.Parent.Parent.Components.Util)
local function entries(self, kind)
	local category = self.PoolCategory or "Glassies"
	local offer = self.Data.Crates and self.Data.Crates[category] and self.Data.Crates[category][kind]
	return offer and offer.Odds or (if category == "Glassies" and kind == "Coins" then self.Data.Odds else {})
end
local function clear(self, root)
	for _, connection in self.PoolConnections[root] or {} do
		connection:Disconnect()
	end
	self.PoolConnections[root] = {}
	for _, child in root:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end
local function tile(self, root, entry, index, kind)
	local result = root.Templates.GlassyTile:Clone()
	local category = self.PoolCategory or "Glassies"
	local def = Item.definition(category, entry.Id)
	result.Name, result.Visible, result.LayoutOrder, result.Parent = def.Id, true, index, root
	S.setAsset(result.Artwork, "tile/tile_" .. S.rarity(def.Rarity))
	local name = result:FindFirstChild("Name")
	name.Text = def.Name
	name.UITextSizeConstraint.MinTextSize = 1
	name.AnchorPoint, name.Position, name.Size = Vector2.zero, UDim2.fromScale(0.04, 0.75), UDim2.fromScale(0.92, 0.12)
	result.NamePlaque.AnchorPoint, result.NamePlaque.Position, result.NamePlaque.Size =
		Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.855), UDim2.fromScale(0.95, 0.27)
	local plaqueAspect = result.NamePlaque:FindFirstChildOfClass("UIAspectRatioConstraint")
	if plaqueAspect then
		plaqueAspect:Destroy()
	end
	result.NamePlaque.ScaleType = Enum.ScaleType.Stretch
	result.SelectedOutline.Visible = false
	Item.portrait(result, category, def.Id, result.Portrait.Size, result.Portrait.Position)
	local chance = U.text(
		result,
		"Chance",
		string.format("%.4g%%", entry.Chance * 100),
		UDim2.fromScale(0.95, 0.12),
		UDim2.fromScale(0.025, 0.87)
	)
	chance.TextColor3, chance.ZIndex = require(script.Parent.Parent.Theme).Palette.lead, 3
	result:SetAttribute("ExactChance", entry.Chance)
	result:SetAttribute("PreviewOnly", false)
	table.insert(
		self.PoolConnections[root],
		result.Open.Activated:Connect(function()
			self.Message.Text = if entry.Chance
				then def.Name .. " · " .. string.format("%.4g%%", entry.Chance * 100) .. " per " .. kind .. " opening"
				else def.Name
		end)
	)
	S.bindSlices(result)
	return result
end
function Pools.strip(self, root, kind)
	clear(self, root)
	local list = entries(self, kind)
	local canvas = math.max(1, #list * 0.32)
	root.CanvasSize = UDim2.fromScale(canvas, 0)
	root.UIListLayout.Padding = UDim.new(0.025 / canvas, 0)
	for i, entry in list do
		local t = tile(self, root, entry, i, kind)
		t.Size = UDim2.fromScale(0.295 / canvas, 1)
	end
end
function Pools.grid(self, root, kind, category)
	self.PoolCategory = category or "Glassies"
	clear(self, root)
	local list = entries(self, kind)
	local rows = math.max(1, math.ceil(#list / 3))
	local canvas = math.max(1, rows * 0.49)
	root.CanvasSize = UDim2.fromScale(0, canvas)
	root.UIGridLayout.CellSize, root.UIGridLayout.CellPadding =
		UDim2.fromScale(0.31, 0.46 / canvas), UDim2.fromScale(0.025, 0.03 / canvas)
	for i, entry in list do
		tile(self, root, entry, i, kind)
	end
end
function Pools.destroy(self)
	for _, list in self.PoolConnections or {} do
		for _, connection in list do
			connection:Disconnect()
		end
	end
	self.PoolConnections = {}
end
return Pools
