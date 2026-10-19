-- Fullscreen preview of a limited bundle, opened from the bundle card's VIEW button:
-- BundlePreview.open(bundleId[, view]) / BundlePreview.close() / BundlePreview.isOpen().
-- Left: a "<glassy> ONLY" card and a "COMPLETE BUNDLE" card with owned states and Robux buy buttons.
-- Right: the player's avatar riding the bundle's flyer on a pedestal, its glassy swinging on a lantern
-- post and the bundle's finisher replaying with sound. The stage (Presentation/BundleStage) lives in the
-- world above the lobby and the camera looks at it while open, because ViewportFrames do not render
-- particles, beams, trails or lights. Other ScreenGuis, movement and touch controls are switched off
-- while open and handed back on close. Server-authoritative: this only sends purchase requests.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local Remotes = require(RS.Shared.Remotes)
local DailyStore = require(RS.Shared.Config.DailyStore)
local Config = require(RS.Shared.Config.BundlePreview)
local Theme = require(script.Parent.Parent.Theme)
local Components = script.Parent.Parent.Components
local U = require(Components.Util)
local S = require(Components.StainedGlass)
local Motion = require(Components.Motion)
local UiAudio = require(Components.UiAudio)
local Gem = require(Components.GemButton)
local Item = require(Components.ItemPresentation)
local TouchGate = require(script.Parent.Parent.TouchGate)
local BundleStage = require(script.Parent.Parent.Parent.Presentation.BundleStage)
local BundlePreview = {}
local current = nil

local ROBUX = utf8.char(0xE002)
local TAU = math.pi * 2
local P = Theme.Palette
local kindNames = { Glassies = "GLASSY", Rideables = "FLYER", Finishers = "FINISHER" }

-- ── Store adapter ───────────────────────────────────────────────────────────────────────────────
-- Everything this screen knows about prices, ownership and purchases goes through here, so a change in
-- the store's remotes or view fields is a one-line change.
local Store = {}
function Store.request()
	Remotes.RequestStore:FireServer()
end
function Store.onView(callback)
	return Remotes.StoreOffers.OnClientEvent:Connect(callback)
end
function Store.onResult(callback)
	return Remotes.StoreResult.OnClientEvent:Connect(callback)
end
-- The bundle entry from a StoreOffers view: { Id, Name, Items = { {Category, Id, Owned} }, AllOwned,
-- RobuxPrice, Available }.
function Store.bundle(view, bundleId)
	for _, entry in type(view) == "table" and view.Bundles or {} do
		if entry.Id == bundleId then
			return entry
		end
	end
	return nil
end
-- The item sold on its own: a one-item bundle entry (e.g. "hollowlight_glassy") with the same item.
-- Returns { Id?, Owned, RobuxPrice?, Available }; no entry or no product shows COMING SOON.
function Store.single(view, item)
	for _, entry in type(view) == "table" and view.Bundles or {} do
		local only = entry.Items and #entry.Items == 1 and entry.Items[1]
		if only and only.Category == item.Category and only.Id == item.Id then
			return {
				Id = entry.Id,
				Owned = only.Owned or 0,
				RobuxPrice = entry.RobuxPrice,
				Available = entry.Available == true,
			}
		end
	end
	return { Owned = item.Owned or 0, Available = false }
end
function Store.buyBundle(bundleId)
	Remotes.BuyStoreBundle:FireServer(bundleId)
end
function Store.buySingle(offer)
	Remotes.BuyStoreBundle:FireServer(offer.Id)
end

-- ── Helpers ─────────────────────────────────────────────────────────────────────────────────────
local function configBundle(bundleId)
	for _, bundle in DailyStore.Bundles do
		if bundle.Id == bundleId then
			return bundle
		end
	end
	return nil
end

local function itemOf(bundle, category)
	for _, item in bundle and bundle.Items or {} do
		if item.Category == category then
			return item
		end
	end
	return nil
end

local function label(parent, name, text, size, position, font, maxSize, colour)
	local l = U.text(parent, name, text, size, position, font or Theme.Fonts.Caption)
	l.UITextSizeConstraint.MaxTextSize = maxSize or Theme.TextSize.Small
	l.UITextSizeConstraint.MinTextSize = Theme.TextFit.MinSmall
	l:SetAttribute("FitMin", Theme.TextFit.MinSmall)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = colour or Theme.Colors.Text
	return l
end

local function stroke(l, thickness)
	U.make("UIStroke", l, { Color = P.lead, Thickness = thickness or 1.5, Transparency = 0.2 })
	return l
end

local function pane(parent, name, size, position)
	local frame = U.make("Frame", parent, { Name = name, BackgroundTransparency = 1, Size = size, Position = position })
	local art = S.image(frame, "Artwork", "panel/pane_dark", UDim2.fromScale(1, 1))
	local aspect = art:FindFirstChildOfClass("UIAspectRatioConstraint")
	if aspect then
		aspect:Destroy()
	end
	return frame
end

local function tag(parent, name, size, position)
	local t = S.image(parent, name, "tag/tag_amber", size, position)
	S.aspect(t, 3.75).DominantAxis = Enum.DominantAxis.Height
	local l = U.text(t, "Label", "", UDim2.fromScale(0.78, 0.62), UDim2.fromScale(0.11, 0.19), Theme.Fonts.Caption)
	l.UITextSizeConstraint.MaxTextSize, l.UITextSizeConstraint.MinTextSize = Theme.TextSize.Body, 6
	l.ZIndex = t.ZIndex + 1
	return t
end

local function setButton(button, text, gem, enabled)
	S.buttonText(button, text)
	S.setAsset(button.Artwork, "button/gem_" .. gem)
	button.Active, button.AutoButtonColor = enabled, false
	button.Label.TextTransparency = if enabled then 0 else 0.3
	button.Artwork.ImageTransparency = if enabled then 0 else 0.25
end

-- ── Screen ──────────────────────────────────────────────────────────────────────────────────────
local Screen = {}
Screen.__index = Screen

function Screen.new(bundleId, view)
	local def = configBundle(bundleId)
	if not def then
		return nil
	end
	local self = setmetatable({ Id = bundleId, Def = def, Connections = {}, Tiles = {}, Focus = "Overview" }, Screen)
	self.Player = Players.LocalPlayer
	self.Gui = U.screen("BundlePreview", 30)
	self:BuildUi()
	self:TakeOver()
	self.Stage = BundleStage.new({
		Glassy = (itemOf(def, "Glassies") or {}).Id,
		Flyer = (itemOf(def, "Rideables") or {}).Id,
		Finisher = (itemOf(def, "Finishers") or {}).Id,
	})
	self:StartCamera()
	self:Connect(Store.onView(function(v)
		self:Apply(v)
	end))
	self:Connect(Store.onResult(function(result)
		if type(result) == "table" and type(result.Message) == "string" then
			self.Message.Text = result.Message
		end
	end))
	local pg = self.Player:WaitForChild("PlayerGui")
	for _, attribute in { "InMatch", "Watching", "ResultsOpen" } do
		self:Connect(pg:GetAttributeChangedSignal(attribute):Connect(function()
			if pg:GetAttribute(attribute) then
				BundlePreview.close(true)
			end
		end))
	end
	self:Apply(view)
	self:RequestView()
	self:Intro()
	return self
end

function Screen:Connect(connection)
	table.insert(self.Connections, connection)
	return connection
end

-- The store's request remote is rate limited; ask again until a view arrives.
function Screen:RequestView()
	task.spawn(function()
		for _ = 1, 4 do
			if not self.Gui.Parent or self.View then
				return
			end
			Store.request()
			task.wait(0.8)
		end
	end)
end

function Screen:BuildUi()
	local gui, def = self.Gui, self.Def
	local root = U.make("Frame", gui, { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	self.Root = root
	-- Darken behind the cards and the header so the 3D stage reads on the right.
	local shade = U.make("Frame", root, {
		Name = "Shade",
		BackgroundColor3 = P.lead,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 80),
		Position = UDim2.fromOffset(0, -80),
	})
	self.ShadeGradient = U.make("UIGradient", shade, {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.4, 0.2),
			NumberSequenceKeypoint.new(0.52, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})
	local band = U.make("Frame", root, {
		Name = "HeaderShade",
		BackgroundColor3 = P.lead,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0.18, 80),
		Position = UDim2.fromOffset(0, -80),
	})
	U.make("UIGradient", band, {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.6, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})

	-- Header: name, tagline, LIMITED TIME pill + countdown, close.
	self.Title = stroke(
		label(
			root,
			"Title",
			def.Name,
			UDim2.fromScale(0.5, 0.085),
			UDim2.fromScale(0.03, 0.02),
			Theme.Fonts.Heading,
			Theme.TextSize.Title
		),
		2
	)
	self.Tagline = label(
		root,
		"Tagline",
		def.Tagline or "",
		UDim2.fromScale(0.4, 0.04),
		UDim2.fromScale(0.032, 0.105),
		nil,
		Theme.TextSize.Body,
		P.amberLight
	)
	local timer = U.make("Frame", root, {
		Name = "Timer",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.9, 0.07),
		Size = UDim2.fromScale(0.42, 0.06),
	})
	U.make("UIListLayout", timer, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	self.Pill = tag(timer, "Pill", UDim2.fromScale(1, 1), UDim2.new())
	self.Pill.LayoutOrder = 1
	S.tag(self.Pill, Config.LimitedText, "amber")
	self.Countdown = stroke(
		label(timer, "Countdown", "", UDim2.fromScale(0.5, 1), UDim2.new(), Theme.Fonts.Heading, Theme.TextSize.Heading)
	)
	self.Countdown.LayoutOrder, self.Countdown.TextXAlignment = 2, Enum.TextXAlignment.Left
	local close = game.StarterGui.KilnScreen.Panel.Close:Clone()
	close.AnchorPoint, close.Position, close.Size =
		Vector2.new(0.5, 0.5), UDim2.fromScale(0.955, 0.07), UDim2.fromScale(0.07, 0.11)
	close.Label.Visible = false
	close.Parent = root
	Motion.button(close)
	S.bindSlices(close)
	self.Close = close
	self:Connect(close.Activated:Connect(function()
		BundlePreview.close()
	end))

	-- Left column: single-item card, bundle card, purchase messages.
	local cards = U.make("Frame", root, {
		Name = "Cards",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.38, 0.8),
		Position = UDim2.fromScale(0.03, 0.16),
	})
	self.Cards = cards
	self.CardsScale = U.make("UIScale", cards, { Scale = 1 })
	local glassy, flyer, finisher = itemOf(def, "Glassies"), itemOf(def, "Rideables"), itemOf(def, "Finishers")
	local single = pane(cards, "Single", UDim2.fromScale(1, 0.37), UDim2.new())
	self.Single = single
	if glassy then
		local gdef = Item.definition(glassy.Category, glassy.Id)
		local name = gdef and gdef.Name or glassy.Id
		stroke(
			label(
				single,
				"Heading",
				string.upper(name) .. " ONLY",
				UDim2.fromScale(0.9, 0.13),
				UDim2.fromScale(0.05, 0.06),
				Theme.Fonts.Heading,
				Theme.TextSize.Heading
			)
		)
		self:Tile(single, "Tile", glassy, UDim2.fromScale(0.3, 0.7), UDim2.fromScale(0.05, 0.24), false)
		stroke(
			label(
				single,
				"ItemName",
				name,
				UDim2.fromScale(0.58, 0.16),
				UDim2.fromScale(0.37, 0.24),
				Theme.Fonts.Heading,
				Theme.TextSize.Heading
			)
		)
		local rarity = tag(single, "Rarity", UDim2.fromScale(0.5, 0.12), UDim2.fromScale(0.37, 0.43))
		S.tag(
			rarity,
			string.upper(gdef and gdef.Rarity or "") .. " GLASSY",
			S.Rarity[gdef and gdef.Rarity or ""] or "milk"
		)
		self.SingleStatus = label(
			single,
			"Status",
			"",
			UDim2.fromScale(0.58, 0.1),
			UDim2.fromScale(0.37, 0.58),
			nil,
			Theme.TextSize.Small,
			P.amberLight
		)
		self.SingleBuy =
			Gem.new(single, "Buy", "LOADING…", "Green", UDim2.fromScale(0.57, 0.22), UDim2.fromScale(0.37, 0.71))
		self:Connect(self.SingleBuy.Activated:Connect(function()
			self:BuySingle()
		end))
	end
	local bundle = pane(cards, "Bundle", UDim2.fromScale(1, 0.55), UDim2.fromScale(0, 0.39))
	self.BundleCard = bundle
	stroke(
		label(
			bundle,
			"Heading",
			"COMPLETE BUNDLE",
			UDim2.fromScale(0.6, 0.09),
			UDim2.fromScale(0.05, 0.04),
			Theme.Fonts.Heading,
			Theme.TextSize.Heading
		)
	)
	self.OwnedCount = label(
		bundle,
		"OwnedCount",
		"",
		UDim2.fromScale(0.34, 0.07),
		UDim2.fromScale(0.61, 0.05),
		nil,
		Theme.TextSize.Small,
		P.emeraldLight
	)
	self.OwnedCount.TextXAlignment = Enum.TextXAlignment.Right
	local row = U.make("Frame", bundle, {
		Name = "Tiles",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.9, 0.5),
		Position = UDim2.fromScale(0.05, 0.15),
	})
	U.make("UIListLayout", row, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0.05, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	for index, item in { glassy, flyer, finisher } do
		if item then
			local t = self:Tile(row, "Tile" .. index, item, UDim2.fromScale(0.29, 0.78), UDim2.new(), true)
			t.LayoutOrder = index
		end
	end
	self.BundleBuy =
		Gem.new(bundle, "Buy", "LOADING…", "Yellow", UDim2.fromScale(0.9, 0.2), UDim2.fromScale(0.05, 0.765))
	self:Connect(self.BundleBuy.Activated:Connect(function()
		self:BuyBundle()
	end))
	self.Message = label(
		cards,
		"Message",
		"",
		UDim2.fromScale(1, 0.05),
		UDim2.fromScale(0, 0.95),
		nil,
		Theme.TextSize.Small,
		P.amberLight
	)

	-- Right: the stage hit area (drag / zoom), and its controls.
	local area = U.make("Frame", root, {
		Name = "StageArea",
		BackgroundTransparency = 1,
		Active = true,
		Size = UDim2.fromScale(0.54, 0.71),
		Position = UDim2.fromScale(0.44, 0.15),
	})
	self.Area = area
	local bar = U.make("Frame", root, {
		Name = "StageBar",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.54, 0.085),
		Position = UDim2.fromScale(0.44, 0.885),
	})
	self.Bar = bar
	local touch = UIS.TouchEnabled and not UIS.MouseEnabled
	self.Hint = label(
		bar,
		"Hint",
		if touch then "Drag to spin · Pinch to zoom" else "Drag to spin · Scroll to zoom",
		UDim2.fromScale(0.36, 0.6),
		UDim2.fromScale(0, 0.2),
		nil,
		Theme.TextSize.Small,
		P.milk
	)
	self.Reset = Gem.new(bar, "Reset", "RESET VIEW", "Blue", UDim2.fromScale(0.26, 1), UDim2.fromScale(0.38, 0))
	self:Connect(self.Reset.Activated:Connect(function()
		self:SetFocus("Overview")
	end))
	self.Combat = Gem.new(
		bar,
		"CombatPreview",
		"COMBAT PREVIEW · SOON",
		"Blue",
		UDim2.fromScale(0.34, 1),
		UDim2.fromScale(0.66, 0)
	)
	setButton(self.Combat, "COMBAT PREVIEW · SOON", "sapphire", Config.CombatPreviewEnabled)

	-- Black cover for the camera cut on open and close; ignores insets so it covers the top bar too.
	local fade = Instance.new("ScreenGui")
	fade.Name, fade.DisplayOrder, fade.ResetOnSpawn = "BundlePreviewFade", 31, false
	fade.ScreenInsets = Enum.ScreenInsets.None
	local cover = U.make("Frame", fade, {
		Name = "Cover",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Active = false,
	})
	fade.Parent = gui.Parent
	self.Fade, self.Cover = fade, cover

	self:Connect(root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:Layout()
	end))
	self:Layout()
end

-- A rarity tile with the item's portrait; clicking it points the stage camera at that item.
function Screen:Tile(parent, name, item, size, position, named)
	local def = Item.definition(item.Category, item.Id)
	local frame = U.make("Frame", parent, { Name = name, BackgroundTransparency = 1, Size = size, Position = position })
	S.aspect(frame, 400 / 480).DominantAxis = Enum.DominantAxis.Height
	local art =
		S.image(frame, "Artwork", "tile/tile_" .. S.rarity(def and def.Rarity or "Common"), UDim2.fromScale(1, 1))
	art.ZIndex = 1
	local portrait = Item.portrait(
		frame,
		item.Category,
		item.Id,
		UDim2.fromScale(0.84, 0.66),
		UDim2.fromScale(0.5, 0.42),
		"Portrait"
	)
	portrait.AnchorPoint, portrait.Position, portrait.ZIndex = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.42), 2
	local outline = S.image(
		frame,
		"Selected",
		"tile/selected_outline",
		UDim2.fromScale(1.08, 1.067),
		UDim2.fromScale(-0.04, -0.033)
	)
	outline.ZIndex, outline.Visible = 3, false
	local kind = label(
		frame,
		"Kind",
		kindNames[item.Category] or "",
		UDim2.fromScale(0.8, 0.12),
		UDim2.fromScale(0.1, 0.8),
		nil,
		Theme.TextSize.Small,
		P.milkLight
	)
	kind.TextXAlignment, kind.ZIndex = Enum.TextXAlignment.Center, 4
	stroke(kind, 1)
	local owned = label(
		frame,
		"Owned",
		"",
		UDim2.fromScale(0.9, 0.12),
		UDim2.fromScale(0.05, 0.05),
		nil,
		Theme.TextSize.Small,
		P.emeraldLight
	)
	owned.TextXAlignment, owned.ZIndex = Enum.TextXAlignment.Center, 4
	stroke(owned, 1)
	if named then
		local n = stroke(
			label(
				frame,
				"ItemName",
				def and def.Name or item.Id,
				UDim2.fromScale(1.12, 0.2),
				UDim2.fromScale(-0.06, 1.03),
				nil,
				Theme.TextSize.Body
			)
		)
		n.TextXAlignment = Enum.TextXAlignment.Center
	end
	-- Named "Open" so Motion scales the whole tile on hover/press.
	local hit = U.make("TextButton", frame, {
		Name = "Open",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Selectable = true,
	})
	Motion.button(hit)
	self:Connect(hit.Activated:Connect(function()
		self:SetFocus(item.Category)
	end))
	table.insert(self.Tiles, { Frame = frame, Item = item, Outline = outline, Owned = owned })
	return frame
end

-- Landscape: cards left, stage right. Portrait phones: stage on top, cards below.
function Screen:Layout()
	local size = self.Root.AbsoluteSize
	if size.X <= 1 then
		return
	end
	local portrait = size.X < size.Y
	if portrait then
		self.Title.Size, self.Title.Position = UDim2.fromScale(0.94, 0.05), UDim2.fromScale(0.03, 0.075)
		self.Tagline.Position = UDim2.fromScale(0.032, 0.125)
		self.Root.Timer.Position, self.Root.Timer.Size = UDim2.fromScale(0.86, 0.035), UDim2.fromScale(0.8, 0.04)
		self.Close.Position, self.Close.Size = UDim2.fromScale(0.93, 0.035), UDim2.fromScale(0.11, 0.06)
		self.Area.Position, self.Area.Size = UDim2.fromScale(0.03, 0.17), UDim2.fromScale(0.94, 0.33)
		self.Bar.Position, self.Bar.Size = UDim2.fromScale(0.03, 0.505), UDim2.fromScale(0.94, 0.045)
		self.Cards.Position, self.Cards.Size = UDim2.fromScale(0.03, 0.56), UDim2.fromScale(0.94, 0.43)
		self.ShadeGradient.Rotation = -90
	else
		self.Title.Size, self.Title.Position = UDim2.fromScale(0.5, 0.085), UDim2.fromScale(0.03, 0.02)
		self.Tagline.Position = UDim2.fromScale(0.032, 0.105)
		self.Root.Timer.Position, self.Root.Timer.Size = UDim2.fromScale(0.9, 0.07), UDim2.fromScale(0.42, 0.06)
		self.Close.Position, self.Close.Size = UDim2.fromScale(0.955, 0.07), UDim2.fromScale(0.07, 0.11)
		self.Area.Position, self.Area.Size = UDim2.fromScale(0.44, 0.15), UDim2.fromScale(0.54, 0.71)
		self.Bar.Position, self.Bar.Size = UDim2.fromScale(0.44, 0.885), UDim2.fromScale(0.54, 0.085)
		self.Cards.Position, self.Cards.Size = UDim2.fromScale(0.03, 0.16), UDim2.fromScale(0.38, 0.8)
		self.ShadeGradient.Rotation = 0
	end
	-- Short phone cards: the buy button needs the room; the tile already shows OWNED.
	if self.SingleStatus then
		local cardHeight = size.Y * (if portrait then 0.43 else 0.8) * 0.37
		self.SingleStatus.Visible = cardHeight >= 170
	end
end

-- ── Store state ─────────────────────────────────────────────────────────────────────────────────
function Screen:Apply(view)
	local bundle = Store.bundle(view, self.Id)
	if not bundle then
		return
	end
	self.View, self.Bundle = view, bundle
	local owned = {}
	local count = 0
	for _, item in bundle.Items or {} do
		owned[item.Category .. ":" .. item.Id] = item.Owned or 0
		count += if (item.Owned or 0) > 0 then 1 else 0
	end
	for _, entry in self.Tiles do
		local n = owned[entry.Item.Category .. ":" .. entry.Item.Id] or 0
		entry.Owned.Text = if n > 0 then "OWNED" else ""
	end
	self.OwnedCount.Text = count .. " of " .. #(bundle.Items or {}) .. " owned"
	if bundle.AllOwned then
		setButton(self.BundleBuy, "COLLECTION OWNED", "sapphire", false)
	elseif bundle.Available and bundle.RobuxPrice then
		setButton(self.BundleBuy, "GET SET · " .. ROBUX .. " " .. bundle.RobuxPrice, "amber", true)
	else
		setButton(self.BundleBuy, "COMING SOON", "sapphire", false)
	end
	local glassy = itemOf(bundle, "Glassies")
	if glassy and self.SingleBuy then
		local offer = Store.single(view, glassy)
		self.SingleStatus.Text = if offer.Owned > 0 then "OWNED ×" .. offer.Owned else "NEW FOR YOU"
		self.SingleStatus.TextColor3 = if offer.Owned > 0 then P.emeraldLight else P.amberLight
		if offer.Owned > 0 then
			setButton(self.SingleBuy, "OWNED", "sapphire", false)
		elseif offer.Available and offer.RobuxPrice then
			setButton(self.SingleBuy, ROBUX .. " " .. offer.RobuxPrice, "emerald", true)
		else
			setButton(self.SingleBuy, "COMING SOON", "sapphire", false)
		end
	end
	if type(view.Message) == "string" then
		self.Message.Text = view.Message
	end
end

function Screen:BuyBundle()
	local bundle = self.Bundle
	if bundle and bundle.Available and not bundle.AllOwned then
		self.Message.Text = ""
		Store.buyBundle(self.Id)
	end
end

function Screen:BuySingle()
	local glassy = itemOf(self.Bundle, "Glassies")
	local offer = glassy and Store.single(self.View, glassy)
	if offer and offer.Id and offer.Available and offer.Owned == 0 then
		self.Message.Text = ""
		Store.buySingle(offer)
	end
end

function Screen:UpdateCountdown()
	local endsAt = self.Def.EndsAt
	local left = if type(endsAt) == "number" then endsAt - workspace:GetServerTimeNow() else nil
	if left and left > 0 then
		local days, hours, minutes = left // 86400, left % 86400 // 3600, left % 3600 // 60
		self.Countdown.Text = if days > 0
			then string.format("Ends in %dd %dh", days, hours)
			else string.format("Ends in %dh %02dm", hours, minutes)
		self.Countdown.Visible = true
	else
		self.Countdown.Visible = false
	end
end

-- ── Take over / hand back the view ──────────────────────────────────────────────────────────────
function Screen:TakeOver()
	local pg = self.Gui.Parent
	self.HiddenGuis = {}
	for _, gui in pg:GetChildren() do
		if gui:IsA("ScreenGui") and gui ~= self.Gui and gui.Name ~= "BundlePreviewFade" and gui.Enabled then
			gui.Enabled = false
			self.HiddenGuis[gui] = true
		end
	end
	local camera = workspace.CurrentCamera
	self.OldCamera =
		{ Type = camera.CameraType, Subject = camera.CameraSubject, FOV = camera.FieldOfView, CFrame = camera.CFrame }
	camera.CameraType, camera.FieldOfView = Enum.CameraType.Scriptable, Config.Camera.FieldOfView
	local playerModule = self.Player:FindFirstChild("PlayerScripts")
		and self.Player.PlayerScripts:FindFirstChild("PlayerModule")
	local ok, controls = pcall(function()
		return playerModule and require(playerModule):GetControls()
	end)
	self.Controls = ok and controls or nil
	if self.Controls then
		self.Controls:Disable()
	end
	TouchGate.acquire(self)
end

function Screen:HandBack()
	for gui in self.HiddenGuis or {} do
		if gui.Parent and not gui.Enabled then
			gui.Enabled = true
		end
	end
	self.HiddenGuis = {}
	local pg = self.Player:FindFirstChild("PlayerGui")
	local busy = pg and (pg:GetAttribute("InMatch") or pg:GetAttribute("Watching"))
	local old = self.OldCamera
	if old and not busy then
		local camera = workspace.CurrentCamera
		if old.Type == Enum.CameraType.Scriptable then
			local humanoid = self.Player.Character and self.Player.Character:FindFirstChildOfClass("Humanoid")
			old = { Type = Enum.CameraType.Custom, Subject = humanoid or old.Subject, FOV = 70, CFrame = old.CFrame }
		end
		camera.CameraType, camera.CameraSubject, camera.FieldOfView = old.Type, old.Subject, old.FOV
		camera.CFrame = old.CFrame
	end
	self.OldCamera = nil
	if self.Controls and not busy then
		self.Controls:Enable()
	end
	TouchGate.release(self)
end

-- ── Orbit camera ────────────────────────────────────────────────────────────────────────────────
-- Eases the orbit onto a subject: pivot on its bounding-box centre, its starting angles and a fitted
-- distance (zoom back to 1). RESET VIEW is SetFocus("Overview").
function Screen:SetFocus(kind)
	local focus = Config.Focus[kind] or Config.Focus.Overview
	self.Focus = if Config.Focus[kind] then kind else "Overview"
	local box = self.Stage:Focus(self.Focus) or { Center = self.Stage:World(Vector3.new(0, 5, 0)), Radius = 8 }
	-- Turn the short way round from wherever the orbit is now.
	local yaw = focus.Yaw
	if self.Cam then
		yaw += math.round((self.Cam.Yaw - yaw) / TAU) * TAU
	end
	self.Goal = { At = box.Center, Radius = box.Radius, Fill = focus.Fill, Yaw = yaw, Pitch = focus.Pitch, Zoom = 1 }
	self.LastInput = os.clock()
	for _, entry in self.Tiles do
		entry.Outline.Visible = entry.Item.Category == kind
	end
	if kind == "Finishers" then
		self.Stage:ReplayEclipse(Config.EclipseLead)
	end
end

function Screen:StartCamera()
	local C = Config.Camera
	self:SetFocus("Overview")
	local goal = self.Goal
	-- Start a little wider and swing in.
	self.Cam = {
		At = goal.At,
		Radius = goal.Radius,
		Fill = goal.Fill,
		Zoom = 1.45,
		Yaw = goal.Yaw - 0.5,
		Pitch = math.min(goal.Pitch + 0.1, C.MaxPitch),
	}
	local function inArea(position)
		local p, s = self.Area.AbsolutePosition, self.Area.AbsoluteSize
		local inset = GuiService:GetGuiInset()
		local x, y = position.X - inset.X, position.Y - inset.Y
		return x >= p.X and y >= p.Y and x <= p.X + s.X and y <= p.Y + s.Y
	end
	local function zoom(factor)
		self.Goal.Zoom = math.clamp(self.Goal.Zoom * factor, C.MinZoom, C.MaxZoom)
		self.LastInput = os.clock()
	end
	self:Connect(self.Area.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseButton2 then
			self.Drag = { Input = "Mouse", Last = input.Position }
		elseif kind == Enum.UserInputType.Touch and not self.Pinching then
			self.Drag = { Input = input, Last = input.Position }
		end
	end))
	self:Connect(self.Area.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			zoom(1 - input.Position.Z * C.WheelStep)
		end
	end))
	self:Connect(UIS.InputChanged:Connect(function(input)
		local drag = self.Drag
		if not drag or self.Pinching then
			return
		end
		local mouse = drag.Input == "Mouse" and input.UserInputType == Enum.UserInputType.MouseMovement
		if mouse or input == drag.Input then
			local delta = input.Position - drag.Last
			drag.Last = input.Position
			self.Goal.Yaw -= delta.X * C.DragSpeed
			self.Goal.Pitch = math.clamp(self.Goal.Pitch + delta.Y * C.DragSpeed, C.MinPitch, C.MaxPitch)
			self.LastInput = os.clock()
		end
	end))
	self:Connect(UIS.InputEnded:Connect(function(input)
		local drag = self.Drag
		if not drag then
			return
		end
		local kind = input.UserInputType
		if
			(
				drag.Input == "Mouse"
				and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseButton2)
			) or input == drag.Input
		then
			self.Drag = nil
		end
	end))
	self:Connect(UIS.TouchPinch:Connect(function(positions, scale, _, state)
		if state == Enum.UserInputState.Begin then
			if positions[1] and inArea(positions[1]) then
				self.Pinching, self.PinchStart, self.Drag = true, self.Goal.Zoom, nil
			end
		elseif state == Enum.UserInputState.Change and self.Pinching then
			self.Goal.Zoom = math.clamp(self.PinchStart / math.max(scale, 0.05), C.MinZoom, C.MaxZoom)
			self.LastInput = os.clock()
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			self.Pinching = false
		end
	end))
	local nextCountdown = 0
	RunService:BindToRenderStep("BundlePreview", Enum.RenderPriority.Camera.Value + 1, function(dt)
		self:StepCamera(dt)
		self.Stage:Step()
		local now = os.clock()
		if now >= nextCountdown then
			nextCountdown = now + Config.CountdownRefreshSeconds
			self:UpdateCountdown()
		end
	end)
	self.Bound = true
end

function Screen:StepCamera(dt)
	local C, goal, cam = Config.Camera, self.Goal, self.Cam
	if self.Focus == "Overview" and not self.Drag and os.clock() - (self.LastInput or 0) > C.IdleSeconds then
		goal.Yaw += C.AutoSpin * dt
	end
	local k = 1 - math.exp(-C.Smooth * dt)
	cam.At = cam.At:Lerp(goal.At, k)
	for _, key in { "Radius", "Fill", "Zoom", "Yaw", "Pitch" } do
		cam[key] += (goal[key] - cam[key]) * k
	end
	local camera = workspace.CurrentCamera
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	local viewport = camera.ViewportSize
	local vw, vh = math.max(viewport.X, 1), math.max(viewport.Y, 1)
	local area, areaSize = self.Area.AbsolutePosition, self.Area.AbsoluteSize
	local tanV = math.tan(math.rad(camera.FieldOfView) / 2)
	local tanH = tanV * vw / vh
	-- Fit the subject to the stage area (not the whole screen), so the distance stays steady while orbiting.
	local tanArea = math.min(tanV * areaSize.Y / vh, tanH * areaSize.X / vw)
	local distance = cam.Radius / math.max(cam.Fill * tanArea, 0.01) * cam.Zoom
	-- Orbit straight at the pivot, then slide the camera sideways (a lens shift) so the pivot lands on the
	-- centre of the stage area beside the cards; the view never turns away from the subject.
	local inset = GuiService:GetGuiInset()
	local center = area + areaSize / 2 + inset
	local nx = center.X / vw * 2 - 1
	local ny = 1 - center.Y / vh * 2
	local rotation = CFrame.Angles(0, cam.Yaw, 0) * CFrame.Angles(-cam.Pitch, 0, 0)
	local eye = cam.At
		+ rotation.LookVector * -distance
		- rotation.RightVector * (nx * distance * tanH)
		- rotation.UpVector * (ny * distance * tanV)
	camera.CFrame = CFrame.new(eye) * rotation
	camera.Focus = CFrame.new(cam.At)
end

-- ── Open / close ────────────────────────────────────────────────────────────────────────────────
function Screen:Intro()
	UiAudio.play("Open")
	local cards, scale = self.Cards, self.CardsScale
	local position = cards.Position
	if Motion.reduced() then
		self.Cover.BackgroundTransparency = 1
		return
	end
	local tiles = {}
	for _, entry in self.Tiles do
		table.insert(tiles, entry.Frame)
	end
	Motion.stagger(tiles)
	cards.Position = position - UDim2.fromScale(0.04, 0)
	scale.Scale = Theme.Motion.PanelOpenScaleFrom
	TweenService:Create(scale, Theme.Motion.PanelOpen, { Scale = 1 }):Play()
	TweenService
		:Create(cards, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = position })
		:Play()
	self.Cover.BackgroundTransparency = 0
	TweenService:Create(
		self.Cover,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	):Play()
end

function Screen:Destroy(instant)
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	local function teardown()
		if self.Bound then
			RunService:UnbindFromRenderStep("BundlePreview")
			self.Bound = false
		end
		for _, connection in self.Connections do
			connection:Disconnect()
		end
		self.Connections = {}
		if self.Stage then
			self.Stage:Destroy()
			self.Stage = nil
		end
		self:HandBack()
		self.Gui:Destroy()
	end
	if instant or not self.Fade.Parent then
		teardown()
		self.Fade:Destroy()
		return
	end
	self.Root.Active = false
	local out = TweenService:Create(
		self.Cover,
		TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 0 }
	)
	out.Completed:Once(function()
		teardown()
		local back = TweenService:Create(self.Cover, TweenInfo.new(0.22), { BackgroundTransparency = 1 })
		back.Completed:Once(function()
			self.Fade:Destroy()
		end)
		back:Play()
	end)
	out:Play()
end

-- ── Public ──────────────────────────────────────────────────────────────────────────────────────
function BundlePreview.open(bundleId, view)
	if current and not current.Destroyed then
		if current.Id == bundleId then
			return current
		end
		current:Destroy(true)
	end
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if pg and (pg:GetAttribute("InMatch") or pg:GetAttribute("Watching") or pg:GetAttribute("ResultsOpen")) then
		return nil
	end
	current = Screen.new(bundleId, view)
	return current
end

function BundlePreview.close(instant)
	if current then
		current:Destroy(instant)
		current = nil
	end
end

function BundlePreview.isOpen()
	return current ~= nil and not current.Destroyed
end

return BundlePreview
