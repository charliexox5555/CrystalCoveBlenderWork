local RS = game:GetService("ReplicatedStorage")
local Glassies = require(RS.Shared.Config.Glassies)
local Powers = require(RS.Shared.Config.Powers)
local Formula = require(RS.Shared.Formula)
local Window = require(script.Parent.Parent.Components.Window)
local Portrait = require(script.Parent.Parent.Components.GlassyPortrait)
local S = require(script.Parent.Parent.Components.StainedGlass)
local Screen = {}
Screen.__index = Screen

function Screen.new(profile, close)
	local self = setmetatable({ Index = false, Tiles = {}, TileConnections = {} }, Screen)
	self.Window = Window.new("CollectionScreen", "INVENTORY", close)
	self.Grid = self.Window.Content.Grid
	self.Info = self.Window.Content.InfoPane
	self:Refresh(profile)
	return self
end

function Screen:Refresh(profile)
	self.Profile = profile
	if not profile then
		return
	end
	for _, c in self.TileConnections do
		c:Disconnect()
	end
	self.TileConnections = {}
	self.Tiles = {}
	for _, root in { self.Grid.Tiles, self.Grid.UnownedTiles } do
		for _, o in root:GetChildren() do
			if o:IsA("GuiObject") then
				o:Destroy()
			end
		end
	end
	local ownedEntries, unownedEntries = {}, {}
	for _, d in Glassies.List do
		local owned = profile.Glassies[d.Id]
		table.insert(if owned and owned.Count > 0 then ownedEntries else unownedEntries, d)
	end
	for _, section in { { ownedEntries, self.Grid.Tiles, false }, { unownedEntries, self.Grid.UnownedTiles, true } } do
		for i, d in section[1] do
			self:AddTile(d, section[2], i, section[3])
		end
	end
	self:LayoutSections(#ownedEntries, #unownedEntries)
	if not self.Selected or not Glassies.ById[self.Selected] then
		self.Selected = (ownedEntries[1] or unownedEntries[1]).Id
	end
	if self.Selected then
		self:Detail(self.Selected)
	end
end

function Screen:AddTile(d, root, order, unowned)
	local tile = self.Grid.Templates[if unowned then "UnownedGlassyTile" else "GlassyTile"]:Clone()
	tile.Name, tile.LayoutOrder, tile.Visible, tile.Parent = d.Id, order, true, root
	tile:SetAttribute("Unowned", unowned)
	S.setAsset(tile.Artwork, "tile/tile_" .. S.rarity(d.Rarity))
	tile.NamePlaque.Visible = true
	tile:FindFirstChild("Name").Text = d.Name
	local installed = RS.Assets.Glassies:FindFirstChild(d.Id) ~= nil
	tile.Portrait.Visible, tile.Unknown.Visible = installed, not installed
	tile:SetAttribute("ArtworkPending", not installed)
	if installed then
		Portrait.new(tile, d.Id, tile.Portrait.Size, tile.Portrait.Position)
	end
	S.bindSlices(tile)
	table.insert(self.Tiles, tile)
	table.insert(
		self.TileConnections,
		tile.Open.Activated:Connect(function()
			self:Detail(d.Id)
		end)
	)
end

function Screen:LayoutSections(ownedCount, unownedCount)
	local grid = self.Grid
	local height, gap = grid:GetAttribute("SectionTileHeight"), grid:GetAttribute("SectionTileGap")
	local header = grid:GetAttribute("SectionHeaderHeight")
	local sectionGap = grid:GetAttribute("SectionGap")
	local function area(count, root)
		local layout = root.UIGridLayout
		local columns = math.max(
			1,
			math.floor(
				(1 + layout.CellPadding.X.Scale) / (layout.CellSize.X.Scale + layout.CellPadding.X.Scale) + 0.001
			)
		)
		local rows = math.ceil(count / columns)
		return if count == 0
			then grid:GetAttribute("SectionEmptyHeight")
			else rows * height + math.max(0, rows - 1) * gap
	end
	local ownedHeight = area(ownedCount, grid.Tiles)
	local unownedHeight = area(unownedCount, grid.UnownedTiles)
	local divider = header + ownedHeight + sectionGap
	local total = math.max(1, divider + header + unownedHeight + grid:GetAttribute("SectionBottomPadding"))
	grid.CanvasSize = UDim2.fromScale(0, total)
	for _, entry in
		{
			{ "Owned", grid.Tiles, ownedCount, 0, ownedHeight },
			{ "Unowned", grid.UnownedTiles, unownedCount, divider, unownedHeight },
		}
	do
		local name, root, count, y, sectionHeight = table.unpack(entry)
		local title = grid[name .. "Header"]
		title.Position, title.Size = UDim2.fromScale(0, y / total), UDim2.fromScale(1, header / total)
		title.Label.Text = name:upper() .. "  ·  " .. count
		root.Position, root.Size = UDim2.fromScale(0, (y + header) / total), UDim2.fromScale(1, sectionHeight / total)
		local layout = root.UIGridLayout
		layout.CellSize = UDim2.fromScale(layout.CellSize.X.Scale, height / sectionHeight)
		layout.CellPadding = UDim2.fromScale(layout.CellPadding.X.Scale, gap / sectionHeight)
		root.Visible = count > 0
		local empty = grid[name .. "Empty"]
		empty.Visible = count == 0
		empty.Position, empty.Size = root.Position, root.Size
	end
	grid:SetAttribute("OwnedCount", ownedCount)
	grid:SetAttribute("UnownedCount", unownedCount)
end

function Screen:Detail(id)
	if not Glassies.ById[id] then
		return
	end
	self.Selected = id
	local d = Glassies.get(id)
	local owned = self.Profile.Glassies[id]
	local stats = Formula.stats(d, owned)
	local passive, power = Powers.passive(d.Passive), Powers.special(d.Special)
	local p = self.Info
	p.InfoName.Text = d.Name
	S.tag(p.TypeTag, d.Type, S.Types[d.Type])
	S.tag(p.RarityTag, d.Rarity, S.Rarity[d.Rarity])
	local stars = math.clamp((owned and owned.Stars) or 0, 0, 5)
	local starLabel = p:FindFirstChild("Stars")
	if starLabel then
		starLabel.Visible = owned ~= nil
		starLabel.Text = string.rep("★", stars) .. string.rep("☆", 5 - stars)
	end
	p.Ownership.Text = if owned then "OWNED • x" .. owned.Count else "UNOWNED • BASE STATS"
	local installed = RS.Assets.Glassies:FindFirstChild(id) ~= nil
	p.InfoPortrait.Visible, p.UnknownPortrait.Visible, p.ArtworkPending.Visible =
		installed, not installed, not installed
	if installed then
		self.DetailPortrait = Portrait.new(p, id, p.InfoPortrait.Size, p.InfoPortrait.Position, "InfoPortrait")
	end
	p.PassiveName.Text = d.PassiveName or passive.Name
	p.PassiveDescription.Text = passive.Description
	p.PowerName.Text = d.SpecialName or power.Name
	p.PowerDescription.Text = power.Description
	local maxima = { Power = 0, HP = 0, Swing = 0 }
	for _, def in Glassies.List do
		local s = Formula.stats(def, self.Profile.Glassies[def.Id])
		for key in maxima do
			maxima[key] = math.max(maxima[key], s[key])
		end
	end
	for key, maximum in maxima do
		p[key .. "Amount"].Text = tostring(stats[key])
		local mask = p[key .. "Track"].FillMask
		local fraction = math.clamp(stats[key] / math.max(1, maximum), 0.001, 1)
		mask.Size = UDim2.fromScale(fraction, 1)
		mask.Fill.Size = UDim2.fromScale(1 / fraction, 1)
	end
	for _, tile in self.Tiles do
		tile.SelectedOutline.Visible = tile.Name == id
	end
end

function Screen:Step(dt)
	-- Portraits stay upright and centered; interactive controls retain their animation.
end
function Screen:Destroy()
	for _, c in self.TileConnections do
		c:Disconnect()
	end
	self.Window:Destroy()
end
return Screen
