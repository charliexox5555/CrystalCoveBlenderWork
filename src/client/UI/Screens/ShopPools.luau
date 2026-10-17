local Pools = {}
local Item = require(script.Parent.Parent.Components.ItemPresentation)
local PrizeCard = require(script.Parent.Parent.Components.PrizeCard)
local Motion = require(script.Parent.Parent.Components.Motion)
local MIN_CARD, MIN_COLUMNS, MAX_COLUMNS = 150, 3, 6 -- cards stay square; phones get 3 columns, wide windows up to 6
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
-- "View all" list: every prize as the same square card the carousel shows, with its exact odds.
function Pools.grid(self, root, kind, category)
	self.PoolCategory = category or "Glassies"
	clear(self, root)
	local list = entries(self, kind)
	local layout = root.UIGridLayout
	local function fit()
		local width = root.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local columns = math.clamp(math.floor(width / MIN_CARD), MIN_COLUMNS, MAX_COLUMNS)
		local gap = math.floor(width * 0.02)
		local cell = math.floor((width - gap * (columns - 1)) / columns) - 1
		local rows = math.max(1, math.ceil(#list / columns))
		layout.CellSize, layout.CellPadding = UDim2.fromOffset(cell, cell), UDim2.fromOffset(gap, gap)
		root.CanvasSize = UDim2.fromOffset(0, rows * (cell + gap))
	end
	table.insert(self.PoolConnections[root], root:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
	fit()
	local cards = {}
	for i, entry in list do
		local def = Item.definition(self.PoolCategory, entry.Id)
		local card = PrizeCard.new(root, function()
			self.Message.Text = if entry.Chance
				then def.Name .. " · " .. string.format("%.4g%%", entry.Chance * 100) .. " per " .. kind .. " opening"
				else def.Name
		end)
		card.Root.Name, card.Root.LayoutOrder, card.Root.AnchorPoint = def.Id, i, Vector2.zero
		local portrait = Item.portrait(card.Area, self.PoolCategory, def.Id, UDim2.fromScale(1, 1), UDim2.new())
		PrizeCard.set(card, def, entry.Chance, portrait, 4)
		card.Root:SetAttribute("ExactChance", entry.Chance)
		card.Root:SetAttribute("PreviewOnly", false)
		table.insert(self.PoolConnections[root], card.Connection)
		table.insert(cards, card.Root)
	end
	Motion.stagger(cards)
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
