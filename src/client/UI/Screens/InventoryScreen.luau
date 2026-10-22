local RS = game:GetService("ReplicatedStorage")
local Glassies = require(RS.Shared.Config.Glassies)
local Powers = require(RS.Shared.CombatText)
local Formula = require(RS.Shared.Formula)
local Window = require(script.Parent.Parent.Components.Window)
local Portrait = require(script.Parent.Parent.Components.GlassyPortrait)
local S = require(script.Parent.Parent.Components.StainedGlass)
local Catalog = require(script.Parent.CosmeticCatalog)
local Motion = require(script.Parent.Parent.Components.Motion)
local Theme = require(script.Parent.Parent.Theme)
local Screen = {}
Screen.__index = Screen

-- One string per glassy that changes what the tiles or the detail pane show.
local function entrySignature(profile, id)
	local owned = profile.Glassies[id]
	return id
		.. ":"
		.. (owned and owned.Count or 0)
		.. ":"
		.. (owned and owned.Stars or 0)
		.. ":"
		.. tostring(owned and owned.Rainbow or false)
end
local function signature(profile)
	local parts = {}
	for _, d in Glassies.visible(profile.Glassies) do
		table.insert(parts, entrySignature(profile, d.Id))
	end
	return table.concat(parts, "|")
end

-- Phone rows of the glassy info pane under the smaller preview: [label] = { top, height } (share of the pane).
-- The type / rarity tags get wider so "Uncommon" or "Legendary" shrink instead of being cut: [tag] = { x, width }.
local PHONE_TAGS = { TypeTag = { 0.06, 0.36 }, RarityTag = { 0.45, 0.43 } }
local PHONE_ROWS = {
	PassiveCaption = { 0.38, 0.04 },
	PassiveName = { 0.415, 0.045 },
	PassiveDescription = { 0.46, 0.16 },
	PowerCaption = { 0.625, 0.04 },
	PowerName = { 0.66, 0.045 },
	PowerDescription = { 0.705, 0.14 },
}

function Screen.new(profile, close)
	local self = setmetatable({ Index = false, Tiles = {}, TileById = {} }, Screen)
	self.Window = Window.new("CollectionScreen", "INVENTORY", close)
	self.Grid = self.Window.Content.Grid
	self.Info = self.Window.Content.InfoPane
	-- Phones (creator, 2026-10-22): a smaller 3D preview, so the passive and power descriptions get two lines each.
	local ok, responsive = pcall(require, script.Parent.Parent.Parent.Controllers.ResponsiveController)
	local phone = ok and responsive.Class ~= nil and responsive:Class() == "Compact"
	require(script.Parent.Parent.Components.SquareItemPreview).apply(self.Info, phone)
	if phone then
		for name, x in PHONE_TAGS do
			local tag = self.Info:FindFirstChild(name)
			if tag then
				tag.Position = UDim2.new(x[1], 0, tag.Position.Y.Scale, tag.Position.Y.Offset)
				tag.Size = UDim2.new(x[2], 0, 0.055, 0)
			end
		end
		for name, y in PHONE_ROWS do
			local label = self.Info:FindFirstChild(name)
			if label then
				label.Position = UDim2.new(label.Position.X.Scale, label.Position.X.Offset, y[1], 0)
				label.Size = UDim2.new(label.Size.X.Scale, label.Size.X.Offset, y[2], 0)
				if name:match("Description$") then
					-- The longest passives need a third line; the small floor keeps them whole instead of "…".
					label:SetAttribute("FitLines", 3)
					label:SetAttribute("FitMin", Theme.TextFit.MinSmall)
				end
			end
		end
	end
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
	self.Opened = true
	return self
end

-- Profile snapshots arrive every few seconds. Unchanged profiles leave every tile and portrait alone; a
-- real change only touches the tiles whose glassy changed (or moved between owned and unowned).
function Screen:Refresh(profile)
	self.Profile = profile
	if self.CosmeticView then
		self.CosmeticView:Refresh(profile)
	end
	if not profile then
		return
	end
	local sig = signature(profile)
	if sig == self.Signature and self.Selected then
		return
	end
	if not self.Signature then -- first build: drop any authored placeholder tiles
		for _, root in { self.Grid.Tiles, self.Grid.UnownedTiles } do
			for _, o in root:GetChildren() do
				if o:IsA("GuiObject") then
					o:Destroy()
				end
			end
		end
	end
	self.Signature = sig
	local ownedEntries, unownedEntries, wanted = {}, {}, {}
	for _, d in Glassies.visible(profile.Glassies) do
		local owned = profile.Glassies[d.Id]
		table.insert(if owned and owned.Count > 0 then ownedEntries else unownedEntries, d)
		wanted[d.Id] = true
	end
	for id, entry in self.TileById do
		if not wanted[id] then
			self:RemoveTile(id, entry)
		end
	end
	self.Tiles = {}
	local fresh = {}
	for _, section in { { ownedEntries, self.Grid.Tiles, false }, { unownedEntries, self.Grid.UnownedTiles, true } } do
		for i, d in section[1] do
			local entry = self.TileById[d.Id]
			if entry and entry.Unowned ~= section[3] then
				self:RemoveTile(d.Id, entry)
				entry = nil
			end
			if entry then
				entry.Tile.Parent, entry.Tile.LayoutOrder = section[2], i
				entry.Count.Text = "×" .. ((profile.Glassies[d.Id] or {}).Count or 0)
				table.insert(self.Tiles, entry.Tile)
			else
				self:AddTile(d, section[2], i, section[3])
				table.insert(fresh, self.TileById[d.Id].Tile)
			end
		end
	end
	self:LayoutSections(#ownedEntries, #unownedEntries)
	Motion.stagger(fresh)
	if not self.Selected or not Glassies.ById[self.Selected] then
		self.Selected = (ownedEntries[1] or unownedEntries[1]).Id
		self.SelectedSignature = nil
	end
	local selectedSignature = entrySignature(profile, self.Selected)
	if selectedSignature ~= self.SelectedSignature then
		self:Detail(self.Selected)
	end
end

function Screen:RemoveTile(id, entry)
	entry.Connection:Disconnect()
	entry.Tile:Destroy()
	self.TileById[id] = nil
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
			Catalog.new(self.Window.Content, self.Profile, if name == "Flyers" then "Rideables" else name)
	end
	self.Window.Gui:SetAttribute("InventoryCategory", name)
	if self.Opened then
		-- Tab switch: content slides in and the chosen tab pops (not on the first build).
		Motion.slideIn(if name == "Glassies" then self.Grid else self.CosmeticView.Root)
		if name == "Glassies" then
			Motion.slideIn(self.Info)
		end
		Motion.bump(self.Window.Panel.Tabs[name .. "Tab"])
	end
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
		UDim2.fromScale(0.3, 0.12),
		UDim2.fromScale(0.6, 0.085)
	)
	-- Count sits in the tile's top corner so the plaque keeps its full width for the name.
	count.Visible, count.ZIndex, count.TextXAlignment = not unowned, 3, Enum.TextXAlignment.Right
	count.TextColor3 = require(script.Parent.Parent.Theme).Colors.Text
	count.FontFace = require(script.Parent.Parent.Theme).Fonts.Heading
	U.make("UIStroke", count, { Color = require(script.Parent.Parent.Theme).Palette.lead, Thickness = 1.5 })
	-- Keep text inside the plaque's flat middle (its pointed ends are ~14% each side).
	local label = tile:FindFirstChild("Name")
	label.Size, label.Position = UDim2.fromScale(0.66, 0.16), UDim2.fromScale(0.17, 0.815) -- taller box = readable text on phones
	-- Always shrink to fit the plaque (the unowned template relies on a late async fit that can lag behind).
	-- Wrapped + scaled text always fits both width and height at once (the async single-line fit lagged on phones).
	label:SetAttribute("FitSingleLine", false)
	label.TextScaled, label.TextWrapped = true, true
	local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
	if limit then
		limit.MinTextSize, limit.MaxTextSize = Theme.TextFit.MinSmall, 20
	end
	label:SetAttribute("FitMin", Theme.TextFit.MinSmall) -- small plaque: readable floor, two lines, then "…"
	label.TextXAlignment = Enum.TextXAlignment.Center
	local installed = RS.Assets.Glassies:FindFirstChild(d.Id) ~= nil
	tile.Portrait.Visible, tile.Unknown.Visible = installed, not installed
	tile:SetAttribute("ArtworkPending", not installed)
	if installed then
		Portrait.new(tile, d.Id, tile.Portrait.Size, tile.Portrait.Position)
	end
	S.bindSlices(tile)
	table.insert(self.Tiles, tile)
	self.TileById[d.Id] = {
		Tile = tile,
		Unowned = unowned,
		Count = count,
		Connection = tile.Open.Activated:Connect(function()
			self:Detail(d.Id)
		end),
	}
end

function Screen:LayoutSections(ownedCount, unownedCount)
	require(script.Parent.Parent.Components.InventorySections).layout(self.Grid, ownedCount, unownedCount)
end

function Screen:Detail(id)
	if not Glassies.ById[id] then
		return
	end
	self.Selected = id
	self.SelectedSignature = entrySignature(self.Profile, id)
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
	if not p.Ownership:GetAttribute("Grown") then
		-- The authored line is only ~9px tall on phone-sized windows; give it room (once).
		p.Ownership:SetAttribute("Grown", true)
		local size, position = p.Ownership.Size, p.Ownership.Position
		local taller = size.Y.Scale * 1.6
		p.Ownership.Size = UDim2.new(size.X.Scale, size.X.Offset, taller, size.Y.Offset)
		p.Ownership.Position = UDim2.new(
			position.X.Scale,
			position.X.Offset,
			position.Y.Scale - (taller - size.Y.Scale) / 2,
			position.Y.Offset
		)
	end
	p.Ownership.Text = if owned then "OWNED • x" .. owned.Count else "UNOWNED • BASE STATS"
	if owned and not Glassies.isRelease(id) then
		p.Ownership.Text = (
			if Glassies.isSeasonal(id)
				then "SEASONAL • OWNED x"
				elseif Glassies.isDaily(id) then "DAILY • OWNED x"
				elseif Glassies.isStarterPack(id) then "STARTER PACK • OWNED x"
				else "LEGACY • OWNED x"
		) .. owned.Count
	end
	local installed = RS.Assets.Glassies:FindFirstChild(id) ~= nil
	p.InfoPortrait.Visible, p.UnknownPortrait.Visible, p.ArtworkPending.Visible =
		installed, not installed, not installed
	if installed then
		self.DetailPortrait = Portrait.new(p, id, p.InfoPortrait.Size, p.InfoPortrait.Position, "InfoPortrait", true) -- live: one pane
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
	for _, entry in self.TileById do
		entry.Connection:Disconnect()
	end
	self.Window:Destroy()
end
return Screen
