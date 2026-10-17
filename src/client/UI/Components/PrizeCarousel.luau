-- Odds carousel: a pool of square prize cards that scroll left at a constant speed.
-- A card is rebound only after it has fully left the strip (it re-enters off the right edge), so nothing
-- pops or resets while scrolling. Portraits are built once per prize and re-parented, never rebuilt.
local Item = require(script.Parent.ItemPresentation)
local PrizeCard = require(script.Parent.PrizeCard)
local Carousel = {}
Carousel.__index = Carousel

Carousel.Speed = 0.35 -- cards per second
Carousel.GapScale = 0.06 -- gap between cards, as a fraction of card size
Carousel.MaxStep = 0.1 -- longest frame (seconds) the scroll will advance in one step

function Carousel.new(root, category, odds, selected)
	local self = setmetatable({
		Root = root,
		Category = category,
		Odds = odds,
		Selected = selected,
		Tiles = {},
		Free = {}, -- entry id -> idle portraits, ready to re-parent
		Built = {}, -- every portrait ever built, for cleanup
		Connections = {},
		Scroll = 0, -- in card pitches
		NextIndex = 0, -- sequence number the next card takes; the odds list repeats forever
		Pitch = 0,
	}, Carousel)
	root.ClipsDescendants = true
	root.Active = false
	for _, child in root:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.insert(
		self.Connections,
		root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:Layout()
		end)
	)
	self:Layout()
	return self
end

function Carousel:Portrait(entry, area)
	local free = self.Free[entry.Id]
	local portrait = free and table.remove(free)
	if not portrait then
		-- Built inside the card's portrait area so the camera fits that area's proportions.
		portrait = Item.portrait(area, self.Category, entry.Id, UDim2.fromScale(1, 1), UDim2.new())
		table.insert(self.Built, portrait)
	end
	return portrait
end

function Carousel:Bind(tile)
	local entry = self.Odds[tile.Index % #self.Odds + 1]
	if tile.Portrait then
		local free = self.Free[tile.Entry.Id]
		if not free then
			free = {}
			self.Free[tile.Entry.Id] = free
		end
		tile.Portrait.Parent = nil
		table.insert(free, tile.Portrait)
	end
	tile.Entry = entry
	tile.Portrait = self:Portrait(entry, tile.Card.Area)
	PrizeCard.set(tile.Card, Item.definition(self.Category, entry.Id), entry.Chance, tile.Portrait)
end

function Carousel:AddTile()
	local tile = { Index = self.NextIndex }
	self.NextIndex += 1
	tile.Card = PrizeCard.new(self.Root, function()
		self.Selected(tile.Entry)
	end)
	table.insert(self.Tiles, tile)
	self:Bind(tile)
	return tile
end

function Carousel:Place()
	local width = self.Root.AbsoluteSize.X
	for _, tile in self.Tiles do
		tile.Card.Root.Position = UDim2.new((tile.Index - self.Scroll) * self.Pitch / width, 0, 0.5, 0)
	end
end

-- Keeps enough cards to cover the strip plus one spare on each side; runs on resize.
function Carousel:Layout()
	local size = self.Root.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 or #self.Odds == 0 then
		return
	end
	self.Pitch = size.Y * (1 + Carousel.GapScale)
	local needed = math.ceil(size.X / self.Pitch) + 2
	while #self.Tiles < needed do
		self:AddTile()
	end
	self:Place()
end

function Carousel:Step(dt)
	if self.Pitch == 0 then
		self:Layout()
	end
	if self.Pitch == 0 then
		return
	end
	self.Scroll += math.min(dt, Carousel.MaxStep) * Carousel.Speed
	for _, tile in self.Tiles do
		if tile.Index - self.Scroll < -1 then -- fully left of the strip
			tile.Index = self.NextIndex
			self.NextIndex += 1
			self:Bind(tile)
		end
	end
	self:Place()
end

function Carousel:Destroy()
	for _, c in self.Connections do
		c:Disconnect()
	end
	for _, tile in self.Tiles do
		PrizeCard.destroy(tile.Card)
	end
	for _, portrait in self.Built do
		portrait:Destroy()
	end
end
return Carousel
