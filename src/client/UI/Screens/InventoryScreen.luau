local RS = game:GetService("ReplicatedStorage")
local Glassies = require(RS.Shared.Config.Glassies)
local Powers = require(RS.Shared.CombatText)
local Formula = require(RS.Shared.Formula)
local Window = require(script.Parent.Parent.Components.Window)
local Portrait = require(script.Parent.Parent.Components.GlassyPortrait)
local S = require(script.Parent.Parent.Components.StainedGlass)
local Catalog = require(script.Parent.CosmeticCatalog)
local Screen = {}
Screen.__index = Screen

function Screen.new(profile, close)
	local self = setmetatable({ Index = false, Tiles = {}, TileConnections = {} }, Screen)
	self.Window = Window.new("CollectionScreen", "INVENTORY", close)
	self.Grid = self.Window.Content.Grid
	self.Info = self.Window.Content.InfoPane
	require(script.Parent.Parent.Components.SquareItemPreview).apply(self.Info)
	local cosmeticPage = self.Window.Content:FindFirstChild("CosmeticPage")
	if cosmeticPage then
		cosmeticPage.Visible = false
	end
	self.Tab = "Glassies"
	for _, name in { "Glassies", "Finishers", "Flyers" } do
		local tab = self.Window.Panel.Tabs[name .. "Tab"]
		tab.Active, tab.Interactable, tab.Selectable = true, true, true
		self.Window:Connect(tab, function()
			self:SelectTab(name)
		end)
	end
	self:Refresh(profile)
	return self
end

function Screen:Refresh(profile)
	self.Profile = profile
	if self.CosmeticView then
		self.CosmeticView:Refresh(profile)
	end
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
	for _, d in Glassies.visible(profile.Glassies) do
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

function Screen:SelectTab(name)
	local tints = { Glassies = "aqua", Flyers = "ruby", Finishers = "amethyst" }
	if not tints[name] then
		return
	end
	if self.CosmeticView then
		self.CosmeticView:Destroy()
		self.CosmeticView = nil
	end
	self.Tab = name
	for tab, tint in tints do
		S.setAsset(
			self.Window.Panel.Tabs[tab .. "Tab"].Artwork,
			"tab/tab_" .. tint .. (if tab == name then "_active" else "_idle")
		)
	end
	self.Grid.Visible, self.Info.Visible = name == "Glassies", name == "Glassies"
	if name ~= "Glassies" then
		self.CosmeticView =
			Catalog.new(self.Window.Content, self.Profile, if name == "Flyers" then "Rideables" else "Finishers")
	end
	self.Window.Gui:SetAttribute("InventoryCategory", name)
end

function Screen:AddTile(d, root, order, unowned)
	local tile = self.Grid.Templates[if unowned then "UnownedGlassyTile" else "GlassyTile"]:Clone()
	tile.Name, tile.LayoutOrder, tile.Visible, tile.Parent = d.Id, order, true, root
	tile:SetAttribute("Unowned", unowned)
	S.setAsset(tile.Artwork, "tile/tile_" .. S.rarity(d.Rarity))
	tile.NamePlaque.Visible = true
	tile:FindFirstChild("Name").Text = d.Name
	local U = require(script.Parent.Parent.Components.Util)
	local count = U.text(
		tile,
		"Count",
		"×" .. ((self.Profile.Glassies[d.Id] or {}).Count or 0),
		UDim2.fromScale(0.22, 0.14),
		UDim2.fromScale(0.73, 0.82)
	)
	count.Visible, count.ZIndex = not unowned, 3
	count.TextColor3 = require(script.Parent.Parent.Theme).Palette.lead
	tile:FindFirstChild("Name").Size = UDim2.fromScale(0.63, 0.13)
	tile:FindFirstChild("Name").Position = UDim2.fromScale(0.08, 0.83)
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
	require(script.Parent.Parent.Components.InventorySections).layout(self.Grid, ownedCount, unownedCount)
end

function Screen:Detail(id)
	if not Glassies.ById[id] then
		return
	end
	self.Selected = id
	local d = Glassies.get(id)
	local owned = self.Profile.Glassies[id]
	local stats = Formula.stats(d, owned)
	local passive, power = Powers.passive(d), Powers.special(d)
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
	if owned and not Glassies.isRelease(id) then
		p.Ownership.Text = "LEGACY • OWNED x" .. owned.Count
	end
	local installed = RS.Assets.Glassies:FindFirstChild(id) ~= nil
	p.InfoPortrait.Visible, p.UnknownPortrait.Visible, p.ArtworkPending.Visible =
		installed, not installed, not installed
	if installed then
		self.DetailPortrait = Portrait.new(p, id, p.InfoPortrait.Size, p.InfoPortrait.Position, "InfoPortrait")
	end
	p.PassiveName.Text = passive.Name
	p.PassiveDescription.Text = passive.Description
	p.PowerName.Text = power.Name
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
function Screen:UpdateProfile(profile)
	self.Profile = profile
	if self.CosmeticView then
		self.CosmeticView:Refresh(profile)
	end
end
function Screen:Destroy()
	if self.CosmeticView then
		self.CosmeticView:Destroy()
	end
	for _, c in self.TileConnections do
		c:Disconnect()
	end
	self.Window:Destroy()
end
return Screen
