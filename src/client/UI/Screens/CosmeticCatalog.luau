-- Inventory uses the same authored owned/unowned grid and detail shell as Glassies.
local RS = game.ReplicatedStorage
local C = require(RS.Shared.Config.RoundCosmetics)
local Rules = require(RS.Shared.RoundCosmeticRules)
local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Parent.Components.Util)
local Button = require(script.Parent.Parent.Components.GemButton)
local S = require(script.Parent.Parent.Components.StainedGlass)
local Portrait = require(script.Parent.Parent.Components.CosmeticPortrait)
local Sections = require(script.Parent.Parent.Components.InventorySections)
local FX = require(script.Parent.Parent.Parent.Presentation.FinisherFX)
local FinisherAudio = require(script.Parent.Parent.Parent.Presentation.FinisherAudio)
local Tuning = require(RS.Shared.Config.Balance).CosmeticPresentation
local Motion = require(script.Parent.Parent.Components.Motion)
local Catalog = {}
Catalog.__index = Catalog
local function entrySignature(profile, category, id, equipped)
	return id .. ":" .. Rules.count(profile, category, id) .. ":" .. tostring(id == equipped)
end
function Catalog.new(parent, profile, category)
	local self = setmetatable({ Category = category, Connections = {}, Tiles = {}, TileEntries = {} }, Catalog)
	local old = parent:FindFirstChild("CosmeticPage")
	if old then
		old.Visible = false
	end
	self.Root = U.make(
		"Frame",
		parent,
		{ Name = "CosmeticInventory", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }
	)
	self.Root.Visible = true
	local source = game.StarterGui.CollectionScreen.Panel.Content
	self.Grid = self.Root:FindFirstChild("Cards")
	if not self.Grid then
		self.Grid = source.Grid:Clone()
		self.Grid.Name = "Cards"
		self.Grid.Parent = self.Root
	end
	self.Grid.Visible = true
	self.Info = self.Root:FindFirstChild("Details")
	if not self.Info then
		self.Info = source.InfoPane:Clone()
		self.Info.Name = "Details"
		self.Info.Parent = self.Root
	end
	self.Info.Visible = true
	require(script.Parent.Parent.Components.SquareItemPreview).apply(self.Info)
	local keep = {
		PaneArtwork = true,
		InfoName = true,
		RarityTag = true,
		ViewportPane = true,
		InfoPortrait = true,
		Ownership = true,
	}
	for _, child in self.Info:GetChildren() do
		if child:IsA("GuiObject") then
			child.Visible = keep[child.Name] == true
		end
	end
	self.Name = self.Info.InfoName
	self.Info.RarityTag.Visible = false
	self.Rarity = U.text(
		self.Info,
		"CosmeticRarity",
		"",
		UDim2.fromScale(0.92, 0.06),
		UDim2.fromScale(0.04, 0.15),
		Theme.Fonts.Heading
	)
	self.Status = self.Info.Ownership
	self.Status.Position, self.Status.Size = UDim2.fromScale(0.04, 0.65), UDim2.fromScale(0.92, 0.065)
	self.Description = U.text(self.Info, "Description", "", UDim2.fromScale(0.92, 0.13), UDim2.fromScale(0.04, 0.5))
	self.Description.TextWrapped = true
	self.Equip =
		Button.new(self.Info, "Equip", "EQUIP", "Green", UDim2.fromScale(0.92, 0.1), UDim2.fromScale(0.04, 0.86))
	self.Preview =
		Button.new(self.Info, "Preview", "PREVIEW", "Blue", UDim2.fromScale(0.92, 0.1), UDim2.fromScale(0.04, 0.73))
	for _, button in { self.Equip, self.Preview } do
		U.make("UISizeConstraint", button, { MinSize = Vector2.new(44, 44) })
	end
	table.insert(
		self.Connections,
		self.Equip.Activated:Connect(function()
			if self.Owned then
				require(RS.Shared.Remotes).EquipRoundCosmetic:FireServer(
					self.Category,
					if self.Equipped then "" else self.Selected
				)
			end
		end)
	)
	table.insert(
		self.Connections,
		self.Preview.Activated:Connect(function()
			self:PreviewSelected()
		end)
	)
	self:Refresh(profile)
	return self
end
function Catalog:FitPreview()
	if self.Previewing and self.Portrait then
		Portrait.fitEffect(self.Portrait, Tuning.FinisherRadius + Tuning.FinisherCoreSize / 2)
	end
end
function Catalog:PreviewSelected()
	if self.Category == "Finishers" and self.World then
		self.Previewing = true
		self:FitPreview()
		for _, child in self.World:GetChildren() do
			child:Destroy()
		end
		local effect =
			FX.emit(self.World, self.Selected, Vector3.zero, false, self.Portrait.CurrentCamera.CFrame.Rotation)
		if typeof(effect) == "Instance" then
			FinisherAudio.preview(effect, self.Selected)
		end
		require(script.Parent.Parent.Components.StainedGlass).buttonText(self.Preview, "PREVIEW AGAIN")
		-- When the burst is over, put the still icon back instead of leaving an empty pane.
		local id, token = self.Selected, {}
		self.PreviewToken = token
		task.delay(FX.duration(id) + 0.4, function()
			if self.PreviewToken == token and self.Selected == id and self.Previewing and self.Root.Parent then
				self:Detail(id)
			end
		end)
		return effect
	elseif self.Portrait then
		local model = self.World:FindFirstChildOfClass("Model")
		if model then
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.pi / 2, 0))
		end
	end
end
-- Snapshots arrive every few seconds: an unchanged profile leaves tiles, portraits and a running preview
-- alone, and a real change only rebuilds the tiles whose item changed.
function Catalog:Refresh(profile)
	self.Profile = profile or { Cosmetics = {}, Stats = {} }
	local equipped = (self.Profile.Cosmetics or {})["Equipped" .. self.Category]
	local parts = {}
	for _, def in C.catalog(self.Category) do
		table.insert(parts, entrySignature(self.Profile, self.Category, def.Id, equipped))
	end
	local sig = table.concat(parts, "|")
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
	local owned, missing = {}, {}
	for _, def in C.catalog(self.Category) do
		table.insert(if Rules.count(self.Profile, self.Category, def.Id) > 0 then owned else missing, def)
	end
	self.Tiles = {}
	local fresh = {}
	for _, section in { { owned, self.Grid.Tiles, false }, { missing, self.Grid.UnownedTiles, true } } do
		for i, def in section[1] do
			local entry = self.TileEntries[def.Id]
			if entry and entry.Unowned ~= section[3] then
				entry.Connection:Disconnect()
				entry.Tile:Destroy()
				entry = nil
			end
			if entry then
				local tile = entry.Tile
				tile.Parent, tile.LayoutOrder = section[2], i
				entry.Count.Text = "×" .. Rules.count(self.Profile, self.Category, def.Id)
				entry.Badge.Visible = def.Id == equipped
			else
				entry = self:AddTile(def, section[2], i, section[3], equipped)
				self.TileEntries[def.Id] = entry
				table.insert(fresh, entry.Tile)
			end
			self.Tiles[def.Id] = entry.Tile
		end
	end
	Sections.layout(self.Grid, #owned, #missing)
	Motion.stagger(fresh)
	local id = self.Selected or (owned[1] or missing[1]).Id
	if self.Selected == nil or self.SelectedSignature ~= entrySignature(self.Profile, self.Category, id, equipped) then
		self:Detail(id)
	else
		for key, tile in self.Tiles do
			tile.SelectedOutline.Visible = key == id
		end
	end
end
function Catalog:AddTile(def, root, order, unowned, equipped)
	local tile = self.Grid.Templates[if unowned then "UnownedGlassyTile" else "GlassyTile"]:Clone()
	tile.Name, tile.Visible, tile.LayoutOrder, tile.Parent = def.Id, true, order, root
	tile:SetAttribute("Unowned", unowned)
	S.setAsset(tile.Artwork, "tile/tile_" .. S.rarity(def.Rarity))
	tile:FindFirstChild("Name").Text = def.Name
	tile.Unknown.Visible = false
	local viewport = Portrait.new(tile, self.Category, def.Id, tile.Portrait.Size, tile.Portrait.Position, "Portrait")
	viewport.ImageTransparency = if unowned then 0.5 else 0
	local count = U.text(
		tile,
		"Count",
		"×" .. Rules.count(self.Profile, self.Category, def.Id),
		UDim2.fromScale(0.3, 0.12),
		UDim2.fromScale(0.6, 0.085),
		Theme.Fonts.Heading
	)
	-- Count sits in the tile's top corner so the plaque keeps its full width for the name.
	count.Visible, count.TextXAlignment = not unowned, Enum.TextXAlignment.Right
	count.TextColor3, count.ZIndex = Theme.Colors.Text, 3
	U.make("UIStroke", count, { Color = Theme.Palette.lead, Thickness = 1.5 })
	-- Keep text inside the plaque's flat middle (its pointed ends are ~14% each side).
	local label = tile:FindFirstChild("Name")
	label.TextScaled, label.AnchorPoint, label.TextXAlignment = true, Vector2.zero, Enum.TextXAlignment.Center
	label.Size, label.Position = UDim2.fromScale(0.66, 0.16), UDim2.fromScale(0.17, 0.815) -- taller box = readable text on phones
	-- Always shrink to fit the plaque (the unowned template relies on a late async fit that can lag behind).
	label:SetAttribute("FitSingleLine", true) -- S.bindSlices fits it to both width and height
	local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
	if limit then
		limit.MinTextSize, limit.MaxTextSize = 1, 20
	end
	local badge = U.text(
		tile,
		"Equipped",
		"✓ EQUIPPED",
		UDim2.fromScale(0.46, 0.09),
		UDim2.fromScale(0.12, 0.09),
		Theme.Fonts.Caption
	)
	badge.TextColor3, badge.Visible = Theme.Palette.emeraldLight, def.Id == equipped
	badge.TextXAlignment = Enum.TextXAlignment.Left
	badge:SetAttribute("FitSingleLine", true)
	badge.UITextSizeConstraint.MinTextSize = 1
	tile.SelectedOutline.Visible = def.Id == self.Selected
	S.bindSlices(tile)
	return {
		Tile = tile,
		Unowned = unowned,
		Count = count,
		Badge = badge,
		Connection = tile.Open.Activated:Connect(function()
			self:Detail(def.Id)
		end),
	}
end
function Catalog:Detail(id)
	local def = C.ByCategory[self.Category][id]
	if not def then
		return
	end
	self.Selected, self.Previewing = id, false
	self.SelectedSignature =
		entrySignature(self.Profile, self.Category, id, (self.Profile.Cosmetics or {})["Equipped" .. self.Category])
	if self.PreviewResize then
		self.PreviewResize:Disconnect()
		self.PreviewResize = nil
	end
	local count = Rules.count(self.Profile, self.Category, id)
	self.Owned = count > 0
	self.Equipped = (self.Profile.Cosmetics or {})["Equipped" .. self.Category] == id
	self.Name.Text, self.Description.Text = def.Name, def.Description
	self.Description.Visible = true
	S.tag(self.Info.RarityTag, def.Rarity, S.Rarity[def.Rarity])
	self.Rarity.Text, self.Rarity.TextColor3, self.Rarity.Visible =
		string.upper(def.Rarity), Theme.Rarity[def.Rarity].Top, true
	self.Status.Text = if count > 0
		then "OWNED: " .. count .. (if self.Equipped then " · EQUIPPED" else "")
		elseif def.Seasonal then "SEASONAL · NOT AVAILABLE YET"
		else "UNOWNED · OPEN A CRATE"
	self.Status.Visible = true
	local default = self.Equipped and def.Matches == 0
	S.buttonText(
		self.Equip,
		if default
			then "DEFAULT"
			elseif self.Equipped then "UNEQUIP"
			elseif self.Owned then "EQUIP"
			elseif def.Seasonal then "SEASONAL ITEM"
			else "FIND IN THE SHOP"
	)
	self.Equip.Visible = true
	self.Equip.Active, self.Equip.Selectable = self.Owned and not default, self.Owned and not default
	S.buttonText(self.Preview, if self.Category == "Finishers" then "PREVIEW EFFECT" else "TURN PREVIEW")
	self.Preview.Visible = true
	local slot = self.Info.InfoPortrait
	self.Portrait, self.World = Portrait.new(self.Info, self.Category, id, slot.Size, slot.Position, "InfoPortrait")
	self.Portrait.Visible = true
	self.PreviewResize = self.Portrait:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:FitPreview()
	end)
	for key, tile in self.Tiles do
		tile.SelectedOutline.Visible = key == id
	end
end
function Catalog:Destroy()
	if self.PreviewResize then
		self.PreviewResize:Disconnect()
		self.PreviewResize = nil
	end
	for _, c in self.Connections do
		c:Disconnect()
	end
	for _, entry in self.TileEntries do
		entry.Connection:Disconnect()
	end
	self.Root:Destroy()
end
return Catalog
