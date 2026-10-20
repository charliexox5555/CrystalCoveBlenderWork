-- Glassy selection: three cards, the title with its timer, and the Pick Any / Reroll buttons float straight over
-- the arena (no backing frame). The camera is held on the arena middle by MatchCamera, so nothing here follows anything.
local RS = game:GetService("ReplicatedStorage")
local B = require(RS.Shared.Config.Balance).Match
local Glassies = require(RS.Shared.Config.Glassies)
local Powers = require(RS.Shared.CombatText)
local Theme = require(script.Parent.Parent.Theme)
local S = require(script.Parent.Parent.Components.StainedGlass)
local Portrait = require(script.Parent.Parent.Components.GlassyPortrait)
local HandRoll = require(script.Parent.Parent.Components.HandRoll)
local Kit = require(script.Parent.Parent.Components.MatchKit)
local Motion = require(script.Parent.Parent.Components.Motion)
local UiAudio = require(script.Parent.Parent.Components.UiAudio)
local Window = require(script.Parent.Parent.Components.Window)
local Confirm = require(script.Parent.Parent.Components.PickAnyConfirm)
local Screen = {}
Screen.__index = Screen
local messages = {
	stale = "Selection changed. Please try again.",
	price_changed = "Price updated. Please choose again.",
	phase = "Selection has ended.",
	too_late = "Too late to reroll this round.",
	restricted = "Rerolls are unavailable.",
	insufficient_marbles = "Not enough {M}Marbles.",
	nothing_new = "Your hand already contains your whole collection.",
	picked = "Your glassy is already locked in.",
	not_owned = "That glassy is not in your inventory.",
	data_unavailable = "Your inventory is unavailable. Please try again.",
}
local CARD_RATIO = 920 / 1240
local IDLE = "Pick a glassy. This hand stays with you all match."

-- One tall card. HandRoll builds the same card for its spinning reels, so it lives in one place.
local function buildCard(parent, name)
	local card = Kit.frame(parent, name, UDim2.fromScale(0.3, 1))
	S.aspect(card, CARD_RATIO)
	local art = Instance.new("ImageLabel")
	art.Name, art.Size, art.BackgroundTransparency, art.Parent = "Artwork", UDim2.fromScale(1, 1), 1, card
	S.setAsset(art, "card/card_common")
	Kit.label(card, "Name", "", UDim2.fromScale(0.88, 0.1), UDim2.fromScale(0.06, 0.665), { MaxSize = 45, Outline = 2 })
	-- Empty portrait slot; renderCard fills it (Portrait.new reuses a viewport with this name).
	local portrait = Instance.new("ViewportFrame")
	portrait.Name, portrait.AnchorPoint, portrait.BackgroundTransparency = "Portrait", Vector2.new(0.5, 0.5), 1
	portrait.Size, portrait.Position, portrait.Parent = UDim2.fromScale(0.86, 0.59), UDim2.fromScale(0.5, 0.36), card
	S.aspect(portrait, 1)
	Kit.tag(card, "TypeTag", "", "milk", UDim2.fromScale(0.35, 0.055), UDim2.fromScale(0.1, 0.79))
	Kit.tag(card, "RarityTag", "", "milk", UDim2.fromScale(0.37, 0.055), UDim2.fromScale(0.53, 0.79))
	local power = Kit.label(
		card,
		"Power",
		"",
		UDim2.fromScale(0.72, 0.1),
		UDim2.fromScale(0.14, 0.855),
		{ Font = Theme.Fonts.Body, MaxSize = 18, Outline = false }
	)
	power.TextWrapped = true
	local outline = Instance.new("ImageLabel")
	outline.Name, outline.BackgroundTransparency, outline.ZIndex, outline.Visible = "SelectedOutline", 1, 4, false
	outline.Size, outline.Position, outline.Parent =
		UDim2.fromScale(1.0435, 1.0323), UDim2.fromScale(-0.02175, -0.01615), card
	S.setAsset(outline, "card/selected_outline")
	local check = Kit.label(
		card,
		"SelectedCheck",
		"LOCKED",
		UDim2.fromScale(0.5, 0.07),
		UDim2.fromScale(0.25, 0.035),
		{ Color = Theme.Palette.emeraldLight, MaxSize = 22 }
	)
	check.ZIndex, check.Visible = 4, false
	-- Named "Open" so the shared button motion grows the whole card on hover and shrinks it on press.
	local button = Instance.new("TextButton")
	button.Name, button.Size, button.BackgroundTransparency, button.Text = "Open", UDim2.fromScale(1, 1), 1, ""
	button.AutoButtonColor, button.ZIndex, button.Parent = false, 5, card
	Motion.button(button)
	return card
end

local function renderCard(card, id)
	local d = Glassies.get(id)
	S.setAsset(card.Artwork, "card/card_" .. S.rarity(d.Rarity))
	card:FindFirstChild("Name").Text = d.Name
	if card.Portrait:GetAttribute("GlassyId") ~= id then
		Portrait.new(card, id, card.Portrait.Size, card.Portrait.Position)
		Portrait.fitOnResize(card.Portrait)
	end
	S.tag(card.TypeTag, d.Type, S.Types[d.Type])
	S.tag(card.RarityTag, d.Rarity, S.Rarity[d.Rarity])
	local power = Powers.special(d)
	card.Power.Text = power.Name .. ": " .. power.Description
end

local function playerChip(parent, side, data)
	local right = side == 2
	local chip = Kit.frame(
		parent,
		"Player" .. side,
		UDim2.fromScale(0.22, 0.1),
		UDim2.fromScale(if right then 0.98 else 0.02, 0.03),
		Vector2.new(if right then 1 else 0, 0)
	)
	local x = if right then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
	local name = Kit.label(
		chip,
		"OwnerName",
		data.Names and data.Names[side] or (if side == 1 then "YOU" else "OPPONENT"),
		UDim2.fromScale(1, 0.5),
		UDim2.new(),
		{ XAlign = x, Color = Theme.Sides[side], MaxSize = 30 }
	)
	name.ZIndex = 2
	Kit.hearts(
		chip,
		"Hearts",
		data.Hearts and data.Hearts[side] or 3,
		UDim2.fromScale(1, 0.42),
		UDim2.fromScale(0, 0.56),
		right
	)
	return chip
end

function Screen:Connect(button, callback, group)
	table.insert(group or self.Connections, button.Activated:Connect(callback))
end

function Screen:Say(text, color)
	self.MessageLine:Set(text, color or Theme.Colors.Text)
end

function Screen.new(data, pick, reroll, pickAny, onMarblesRequested)
	local self = setmetatable({
		Data = data,
		Pick = pick,
		Reroll = reroll,
		PickAny = pickAny,
		OnMarblesRequested = onMarblesRequested,
		Connections = {},
		CardConnections = {},
		PickerConnections = {},
	}, Screen)
	self.Gui = Kit.gui("RollScreen", 15)
	local panel = Kit.frame(self.Gui, "Roll", UDim2.fromScale(1, 1))
	self.Panel = panel
	-- Title with the timer in gold, floating over the arena.
	self.Title = Kit.label(
		panel,
		"Title",
		"",
		UDim2.fromScale(0.56, 0.1),
		UDim2.fromScale(0.22, 0.03),
		{ RichText = true, MaxSize = Theme.TextSize.Title, Outline = 2.5 }
	)
	for side = 1, 2 do
		playerChip(panel, side, data)
	end
	-- Cards, message and odds line stack above the bottom button row (its gems start at y 0.85) with a gap.
	local cards = Kit.frame(panel, "Cards", UDim2.fromScale(0.9, 0.6), UDim2.fromScale(0.05, 0.15))
	local layout = Instance.new("UIListLayout")
	layout.FillDirection, layout.Padding = Enum.FillDirection.Horizontal, UDim.new(0.03, 0)
	layout.HorizontalAlignment, layout.VerticalAlignment =
		Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = cards
	for i = 1, 3 do
		local card = buildCard(cards, "Card" .. i)
		card.LayoutOrder, card.Visible = i, false
	end
	Kit.frame(panel, "ReelLayer", UDim2.fromScale(1, 1))
	self.MessageLine = Kit.marbleLine(panel, "Message", UDim2.fromScale(0.8, 0.045), UDim2.fromScale(0.1, 0.756))
	self.OddsNote = Kit.label(
		panel,
		"RerollOdds",
		"",
		UDim2.fromScale(0.8, 0.03),
		UDim2.fromScale(0.1, 0.806),
		{ Font = Theme.Fonts.Caption, Color = Theme.Palette.milkDark, MaxSize = 15, Outline = 1.5 }
	)
	-- Bottom row: Pick Any, our Marble wallet, Reroll, odds.
	self.PickAnyButton =
		Kit.gem(panel, "PickAny", "PICK ANY", "aqua", UDim2.fromScale(0.27, 0.13), UDim2.fromScale(0.27, 0.915), 0)
	self.RerollButton =
		Kit.gem(panel, "Reroll", "REROLL", "amber", UDim2.fromScale(0.27, 0.13), UDim2.fromScale(0.73, 0.915), 3)
	self.OddsButton =
		Kit.gem(panel, "ViewOdds", "ODDS", "sapphire", UDim2.fromScale(0.12, 0.09), UDim2.fromScale(0.925, 0.915))
	local plaque = Kit.icon(
		panel,
		"Wallet",
		"hud/currency_plaque",
		UDim2.fromScale(0.17, 0.1),
		UDim2.fromScale(0.5, 0.915),
		Vector2.new(0.5, 0.5)
	)
	local chip, _, amount = Kit.marbleChip(plaque, "Marbles", 0, UDim2.fromScale(0.6, 0.62), UDim2.fromScale(0.2, 0.19))
	self.WalletPlaque, self.WalletAmount = plaque, amount
	chip.ZIndex = 2
	self:Connect(self.PickAnyButton, function()
		self:OpenPicker()
	end)
	self:Connect(self.RerollButton, function()
		self:RerollNow()
	end)
	self:Connect(self.OddsButton, function()
		self:OpenPicker(true)
	end)
	for _, button in { self.PickAnyButton, self.RerollButton, self.OddsButton } do
		Kit.enable(button, false)
	end
	self.RerollButton.Visible, self.OddsButton.Visible = false, false
	Kit.popIn(panel)
	return self
end

function Screen:Ready()
	return self.OfferData
		and not self.Dead
		and not self.Busy
		and not self.Animation
		and not self.OfferData.Picked
		and workspace:GetServerTimeNow() < self.Data.Deadline
end

-- Not enough Marbles: say how many more with our icon, shake the wallet and play the error cue.
function Screen:NeedMarbles(action, cost)
	local shortfall = math.max(0, cost - (self.OfferData.Marbles or 0))
	self.Gui:SetAttribute("RequestedMarbles", shortfall)
	if self.OnMarblesRequested then
		self.OnMarblesRequested(action, shortfall)
	end
	self:Say("Need {M}" .. shortfall .. " more Marbles", Theme.Palette.rubyLight)
	Motion.bump(self.WalletPlaque, 0.18)
	UiAudio.play("Error")
end

-- A little "-N [marble]" floats up from the wallet whenever a mid-round spend goes through.
function Screen:FloatSpend(amount)
	local note = Kit.marbleLine(
		self.Panel,
		"Spend",
		UDim2.fromScale(0.2, 0.06),
		UDim2.fromScale(0.5, 0.86),
		Vector2.new(0.5, 0.5)
	)
	note.Frame.ZIndex = 6
	note:Set("-{M}" .. amount, Theme.Palette.amberLight)
	local rise = game:GetService("TweenService")
	rise:Create(note.Frame, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0.5, 0.78) }):Play()
	task.delay(0.7, function()
		if note.Frame.Parent then
			Kit.fade(note.Frame, TweenInfo.new(0.4))
		end
	end)
	task.delay(1.2, function()
		note.Frame:Destroy()
	end)
	UiAudio.play("Success")
end

function Screen:Confirm()
	-- Dev/QA helper: answers Yes on an open Pick Any confirmation.
	if self.Dialog and not self.Dialog.Closed then
		self.Dialog:Finish(self.Dialog.Yes)
	end
end
function Screen:ConfirmReroll()
	self:RerollNow()
end

function Screen:Controls()
	local data = self.OfferData
	if not data then
		return
	end
	local ready = self:Ready() and not self.Modal
	self.PickAnyButton.Visible = not data.Picked
	Kit.enable(self.PickAnyButton, ready)
	Kit.setCost(self.PickAnyButton, data.PickAnyCost or 0)
	self.RerollButton.Visible = data.PaidRandomAllowed == true and not data.Picked
	Kit.enable(self.RerollButton, ready)
	Kit.setCost(self.RerollButton, data.RerollCost or 3)
	Motion.countTo(self.WalletAmount, data.Marbles or 0)
	local count = 0
	for _ in data.Collection do
		count += 1
	end
	self.OddsNote.Visible = data.PaidRandomAllowed == true and not data.Picked
	self.OddsButton.Visible = data.PaidRandomAllowed == true and not data.Picked
	Kit.enable(self.OddsButton, ready)
	self.OddsNote.Text = string.format(
		"Reroll: 3 distinct owned glassies • each %.2f%% • the same hand can return",
		math.min(3, count) / math.max(1, count) * 100
	)
	for i = 1, 3 do
		self.Panel.Cards["Card" .. i].Open.Active = ready
	end
end

function Screen:Offers(data)
	if self.Dead then
		return
	end
	local previous = self.OfferData and self.OfferData.Marbles
	self.OfferData = data
	-- The new hand can arrive before the wallet update; either one shows the spend once.
	if self.Spending and previous and data.Marbles and data.Marbles < previous then
		self.Spending = false
		self:FloatSpend(previous - data.Marbles)
	end
	if data.Deadline then
		self.Data.Deadline = data.Deadline
	end
	self.Busy = false
	self.Modal = self.Chooser ~= nil
	if data.Message then
		self.Spending = false -- the server refused it; no spend is coming
	end
	if (data.Picked or data.Animate) and self.Animation then
		self.Animation:Destroy()
		self.Animation = nil
	end
	for _, c in self.CardConnections do
		c:Disconnect()
	end
	self.CardConnections = {}
	for i = 1, 3 do
		local card, id = self.Panel.Cards["Card" .. i], data.Offers[i]
		card.Visible = id ~= nil
		if id then
			renderCard(card, id)
			card.SelectedOutline.Visible = data.Picked == id
			card.SelectedCheck.Visible = data.Picked == id
			self:Connect(card.Open, function()
				if self:Ready() and not self.Modal then
					self.Busy = true
					self:Controls()
					self.Pick(id)
				end
			end, self.CardConnections)
		end
	end
	if data.Animate and not data.Picked and not self.Animation then
		self.Animation = HandRoll.new(self.Panel, data.Offers, data.Collection, buildCard, renderCard)
		self.AnimationStarted = workspace:GetServerTimeNow()
		self.Gui:SetAttribute("RollAnimationCount", (self.Gui:GetAttribute("RollAnimationCount") or 0) + 1)
	end
	if data.Picked then
		self:Say("LOCKED • " .. Glassies.get(data.Picked).Name, Theme.Palette.emeraldLight)
	else
		self:Say(if data.Message then messages[data.Message] or data.Message else IDLE)
	end
	self:Controls()
end

function Screen:Wallet(amount)
	if self.OfferData then
		local spent = (self.OfferData.Marbles or 0) - amount
		self.OfferData.Marbles = amount
		if spent > 0 and self.Spending then
			self:FloatSpend(spent)
		end
		self.Spending = false
		self:Controls()
	end
end

function Screen:CloseChooser()
	for _, c in self.PickerConnections do
		c:Disconnect()
	end
	self.PickerConnections = {}
	if self.Chooser then
		self.Chooser:Destroy()
		self.Chooser = nil
	end
	self.Modal = false
	self:Controls()
end

-- The list of everything the player owns. With oddsOnly it just shows each glassy's reroll chance.
function Screen:OpenPicker(oddsOnly)
	if not self:Ready() or self.Chooser then
		return
	end
	local data = self.OfferData
	local window = Window.new("PickAnyScreen", if oddsOnly then "REROLL ODDS" else "PICK ANY", function()
		self:CloseChooser()
	end)
	self.Chooser = window
	local content = window.Content
	local ids = {}
	for id in data.Collection do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Glassies.get(a).Name < Glassies.get(b).Name
	end)
	local cost = data.PickAnyCost or 0
	local header = Kit.marbleLine(content, "Header", UDim2.fromScale(1, 0.1), UDim2.fromScale(0, -0.03))
	header:Set(
		if oddsOnly
			then string.format(
				"Reroll picks 3 different glassies you own. Each has a %.2f%% chance.",
				math.min(3, #ids) / math.max(1, #ids) * 100
			)
			elseif cost == 0 then "Choose any glassy you own. FREE this match!"
			else "Choose any glassy you own. Costs {M}" .. cost .. " Marbles."
	)
	local grid = Instance.new("ScrollingFrame")
	grid.Name, grid.Size, grid.Position = "Grid", UDim2.fromScale(1, 0.9), UDim2.fromScale(0, 0.09)
	grid.BackgroundTransparency, grid.BorderSizePixel, grid.ScrollBarThickness = 1, 0, 6
	grid.CanvasSize, grid.AutomaticCanvasSize = UDim2.new(), Enum.AutomaticSize.Y
	grid.Parent = content
	local cells = Instance.new("UIGridLayout")
	cells.SortOrder, cells.HorizontalAlignment = Enum.SortOrder.LayoutOrder, Enum.HorizontalAlignment.Center
	cells.Parent = grid
	local function resize()
		local width = math.max(1, grid.AbsoluteSize.X - 12)
		local columns = math.clamp(math.floor(width / 150), 3, 6)
		local gap = 10
		local cellWidth = math.floor((width - gap * (columns - 1)) / columns)
		cells.CellSize = UDim2.fromOffset(cellWidth, math.floor(cellWidth / 0.8333))
		cells.CellPadding = UDim2.fromOffset(gap, gap)
	end
	table.insert(self.PickerConnections, grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))
	resize()
	for i, id in ids do
		local def = Glassies.get(id)
		local tile = Kit.frame(grid, id, UDim2.fromScale(1, 1))
		tile.LayoutOrder = i
		local art = Instance.new("ImageLabel")
		art.Name, art.Size, art.BackgroundTransparency, art.Parent = "Artwork", UDim2.fromScale(1, 1), 1, tile
		S.setAsset(art, "tile/tile_" .. S.rarity(def.Rarity))
		local portrait = Portrait.new(tile, id, UDim2.fromScale(0.84, 0.66), UDim2.fromScale(0.08, 0.07))
		S.aspect(portrait, 1)
		Portrait.fitOnResize(portrait)
		local plaque =
			Kit.icon(tile, "NamePlaque", "tile/name_plaque", UDim2.fromScale(0.89, 0.17), UDim2.fromScale(0.055, 0.81))
		plaque.ZIndex = 1
		local name = Kit.label(
			tile,
			"Name",
			def.Name,
			UDim2.fromScale(0.7, 0.12),
			UDim2.fromScale(0.15, 0.835),
			{ MaxSize = 22, Outline = 1.5 }
		)
		name.ZIndex = 2
		local open = Instance.new("TextButton")
		open.Name, open.Size, open.BackgroundTransparency, open.Text = "Open", UDim2.fromScale(1, 1), 1, ""
		open.AutoButtonColor, open.ZIndex, open.Parent = false, 5, tile
		Motion.button(open)
		if oddsOnly then
			open.Active = false
			local odds = Kit.label(
				tile,
				"InclusionOdds",
				string.format("%.2f%%", math.min(3, #ids) / #ids * 100),
				UDim2.fromScale(0.8, 0.12),
				UDim2.fromScale(0.1, 0.02),
				{ Color = Theme.Colors.Highlight, MaxSize = 20 }
			)
			odds.ZIndex = 3
		else
			self:Connect(open, function()
				self:ChooseAny(id)
			end, self.PickerConnections)
		end
	end
	self.Modal = true
	self:Controls()
end

-- Picking from the list asks first: nothing is sent until the player answers Yes.
function Screen:ChooseAny(id)
	local data = self.OfferData
	if not self:Ready() or not data.Collection[id] or (self.Dialog and not self.Dialog.Closed) then
		return
	end
	local cost = data.PickAnyCost or 0
	if (data.Marbles or 0) < cost then
		self:NeedMarbles("PickAny", cost)
		return
	end
	local function yes()
		if not self:Ready() then
			return
		end
		self.Busy, self.Spending = true, cost > 0
		self:CloseChooser()
		if self.PickAny then
			self.PickAny(id, data)
		end
	end
	self.Dialog = Confirm.new({ Id = id, Cost = cost, Marbles = data.Marbles, OnYes = yes })
	self.Dialog.Yes = yes
end

function Screen:RerollNow()
	local data = self.OfferData
	if not self:Ready() or self.Modal then
		return
	end
	if not data.PaidRandomAllowed then
		self:Say(messages.restricted)
		return
	end
	if not data.CanReroll then
		self:Say(messages.nothing_new)
		return
	end
	if self.Data.Deadline - workspace:GetServerTimeNow() < B.RerollReserveSeconds then
		self:Say(messages.too_late)
		return
	end
	if (data.Marbles or 0) < data.RerollCost then
		self:NeedMarbles("Reroll", data.RerollCost)
		return
	end
	self.Busy, self.Spending = true, data.RerollCost > 0
	self:Controls()
	self.Reroll(data)
end

function Screen:Render(now)
	local seconds = math.max(0, math.ceil(self.Data.Deadline - now))
	if seconds ~= self.LastSeconds then
		self.LastSeconds = seconds
		local color = if seconds <= 5 then "#FF8EA0" else "#FFD98A"
		self.Title.Text = 'CHOOSE YOUR GLASSY <font color="' .. color .. '">' .. seconds .. "</font>"
	end
	if self.Animation and self.Animation:Step(now - self.AnimationStarted) then
		self.Animation:Destroy()
		self.Animation = nil
		self:Controls()
	end
end

function Screen:Destroy()
	self.Dead = true
	if self.Animation then
		self.Animation:Destroy()
	end
	if self.Dialog then
		self.Dialog:Close()
	end
	if self.Chooser then
		self.Chooser:Destroy()
		self.Chooser = nil
	end
	for _, group in { self.Connections, self.CardConnections, self.PickerConnections } do
		for _, c in group do
			c:Disconnect()
		end
	end
	-- Same quick pop-out as every other window; the name is freed so the next round's screen never reuses it.
	local gui = self.Gui
	gui.Name = "RollScreen_Closing"
	self.Panel.Active = false
	Kit.popOut(self.Panel, function()
		gui:Destroy()
	end)
end

return Screen
