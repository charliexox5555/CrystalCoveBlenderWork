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
	local root = self.Grid.Tiles
	for _, o in root:GetChildren() do
		if o:IsA("GuiObject") then
			o:Destroy()
		end
	end
	local entries = {}
	for _, d in Glassies.List do
		if profile.Glassies[d.Id] then
			table.insert(entries, d)
		end
	end
	for i, d in entries do
		local tile = self.Grid.Templates.GlassyTile:Clone()
		tile.Name, tile.LayoutOrder, tile.Visible, tile.Parent = d.Id, i, true, root
		S.setAsset(tile.Artwork, "tile/tile_" .. S.rarity(d.Rarity))
		tile.NamePlaque.Visible = true
		tile:FindFirstChild("Name").Text = d.Name
		Portrait.new(tile, d.Id, tile.Portrait.Size, tile.Portrait.Position)
		S.bindSlices(tile)
		table.insert(self.Tiles, tile)
		table.insert(
			self.TileConnections,
			tile.Open.Activated:Connect(function()
				self:Detail(d.Id)
			end)
		)
	end
	-- Only the data-dependent canvas height changes; the authored grid geometry stays editable.
	local layout = root.UIGridLayout
	local columns = math.max(1, math.floor(1 / (layout.CellSize.X.Scale + layout.CellPadding.X.Scale) + 0.05))
	local rows = math.max(1, math.ceil(#entries / columns))
	-- Keep authored row height and gaps. Only normalize them against the scroll canvas.
	self.CellHeight = self.CellHeight or layout.CellSize.Y.Scale * self.Grid.CanvasSize.Y.Scale
	self.CellGap = self.CellGap or layout.CellPadding.Y.Scale * self.Grid.CanvasSize.Y.Scale
	local canvas = math.max(1, rows * (self.CellHeight + self.CellGap) + 0.01)
	self.Grid.CanvasSize = UDim2.fromScale(0, canvas)
	layout.CellSize = UDim2.fromScale(layout.CellSize.X.Scale, self.CellHeight / canvas)
	layout.CellPadding = UDim2.fromScale(layout.CellPadding.X.Scale, self.CellGap / canvas)

	if not self.Selected or not profile.Glassies[self.Selected] then
		self.Selected = entries[1] and entries[1].Id
	end
	if self.Selected then
		self:Detail(self.Selected)
	end
end

function Screen:Detail(id)
	if not self.Profile.Glassies[id] then
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
	local stars = math.clamp(owned.Stars or 0, 0, 5)
	local starLabel = p:FindFirstChild("Stars")
	if starLabel then
		starLabel.Text = string.rep("★", stars) .. string.rep("☆", 5 - stars)
	end
	self.DetailPortrait = Portrait.new(p, id, p.InfoPortrait.Size, p.InfoPortrait.Position, "InfoPortrait")
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
	local v = self.DetailPortrait
	if v and v.Parent then
		for _, part in v.WorldModel:GetChildren() do
			if part:IsA("BasePart") then
				part:PivotTo(part:GetPivot() * CFrame.Angles(0, dt * 0.35, 0))
			end
		end
	end
end
function Screen:Destroy()
	for _, c in self.TileConnections do
		c:Disconnect()
	end
	self.Window:Destroy()
end
return Screen
