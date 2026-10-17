local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local B = require(RS.Shared.Config.Balance).Match
local Glassies = require(RS.Shared.Config.Glassies)
local Powers = require(RS.Shared.CombatText)
local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Parent.Components.Util)
local S = require(script.Parent.Parent.Components.StainedGlass)
local Portrait = require(script.Parent.Parent.Components.GlassyPortrait)
local HandRoll = require(script.Parent.Parent.Components.HandRoll)
local Screen = {}
Screen.__index = Screen
local messages = {
	stale = "Selection changed. Please try again.",
	price_changed = "Price updated. Please choose again.",
	phase = "Selection has ended.",
	too_late = "Too late to reroll this round.",
	restricted = "Rerolls are unavailable.",
	insufficient_marbles = "Not enough Marbles.",
	nothing_new = "Your hand already contains your whole collection.",
	picked = "Your glassy is already locked in.",
	not_owned = "That glassy is not in your inventory.",
	data_unavailable = "Your inventory is unavailable. Please try again.",
}
local function renderCard(card, id)
	local d = Glassies.get(id)
	S.setAsset(card.Artwork, "card/card_" .. S.rarity(d.Rarity))
	card:FindFirstChild("Name").Text = d.Name
	if card.Portrait:GetAttribute("GlassyId") ~= id then
		Portrait.new(card, id, card.Portrait.Size, card.Portrait.Position)
	end
	S.tag(card.TypeTag, d.Type, S.Types[d.Type])
	S.tag(card.RarityTag, d.Rarity, S.Rarity[d.Rarity])
	local power = Powers.special(d)
	card.Power.Text = power.Name .. ": " .. power.Description
	if not card.Power:GetAttribute("Inset") then
		-- Keep the description clear of the card frame's side and bottom borders (done once per card).
		card.Power:SetAttribute("Inset", true)
		local size, position, anchor = card.Power.Size, card.Power.Position, card.Power.AnchorPoint
		local width = size.X.Scale * 0.86
		card.Power.Size = UDim2.new(width, size.X.Offset, size.Y.Scale, size.Y.Offset)
		card.Power.Position = UDim2.new(
			position.X.Scale + (0.5 - anchor.X) * (size.X.Scale - width),
			position.X.Offset,
			position.Y.Scale - 0.015,
			position.Y.Offset
		)
	end
	S.bindSlices(card)
end
function Screen:Connect(button, callback, group)
	table.insert(group or self.Connections, button.Activated:Connect(callback))
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
	self.Gui = U.screen("RollScreen", 15)
	self.Panel = self.Gui.Roll
	local scale = U.make("UIScale", self.Panel, { Name = "OpenScale", Scale = 1 })
	scale.Scale = Theme.Selection.OpenScale
	TweenService:Create(scale, TweenInfo.new(Theme.Selection.OpenSeconds, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	self.Title, self.Message = self.Panel.Title, self.Panel.Message
	for side = 1, 2 do
		local p = self.Panel["Player" .. side]
		p.OwnerName.Text = data.Names and data.Names[side] or (if side == 1 then "YOU" else "OPPONENT")
		S.hearts(p.Hearts, data.Hearts and data.Hearts[side] or 3)
	end
	self:Connect(self.Panel.PickAny, function()
		self:OpenPicker()
	end)
	self:Connect(self.Panel.Reroll, function()
		self:RerollNow()
	end)
	self:Connect(self.Panel.PickAnyChooser.Cancel, function()
		self.Panel.PickAnyChooser.Visible, self.Modal = false, false
		self:Controls()
	end)
	self:Connect(self.Panel.ViewOdds, function()
		self:OpenPicker(true)
	end)
	self.Panel.Confirm.Visible = false -- retained authored template, never used for spending
	self.MarblesRequested = Instance.new("BindableEvent")
	self.MarblesRequested.Name, self.MarblesRequested.Parent = "MarblesRequested", self.Gui
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
function Screen:NeedMarbles(action, cost)
	local shortfall = math.max(0, cost - (self.OfferData.Marbles or 0))
	self.Gui:SetAttribute("RequestedMarbles", shortfall)
	self.MarblesRequested:Fire(action, shortfall)
	if self.OnMarblesRequested then
		self.OnMarblesRequested(action, shortfall)
	end
	self.Message.Text = "Need " .. shortfall .. " more Marbles. Marble packs aren't available yet."
end
function Screen:Confirm() end -- compatibility for old Studio helpers; no purchase confirmation
function Screen:ConfirmReroll()
	self:RerollNow()
end

function Screen:Controls()
	local data = self.OfferData
	if not data then
		return
	end
	local ready = self:Ready() and not self.Modal
	self.Panel.PickAny.Visible = not data.Picked
	self.Panel.PickAny.Active, self.Panel.PickAny.Selectable = ready, ready
	S.buttonText(
		self.Panel.PickAny,
		"PICK ANY • " .. (if (data.PickAnyCost or 0) == 0 then "FREE" else tostring(data.PickAnyCost))
	)
	self.Panel.Reroll.Visible = data.PaidRandomAllowed == true and not data.Picked
	self.Panel.Reroll.Active, self.Panel.Reroll.Selectable = ready, ready
	S.buttonText(self.Panel.Reroll, "REROLL • " .. tostring(data.RerollCost or 3))
	self.Panel.Wallet.Text = tostring(data.Marbles or 0) .. " MARBLES"
	local count = 0
	for _ in data.Collection do
		count += 1
	end
	self.Panel.RerollOdds.Visible = data.PaidRandomAllowed == true
	self.Panel.ViewOdds.Visible = data.PaidRandomAllowed == true
	self.Panel.ViewOdds.Active, self.Panel.ViewOdds.Selectable = ready, ready
	self.Panel.RerollOdds.Text = string.format(
		"Reroll: 3 distinct owned glassies • each %.2f%% • the same hand can return",
		math.min(3, count) / math.max(1, count) * 100
	)
	for i = 1, 3 do
		local c = self.Panel.Cards["Card" .. i]
		c.Select.Active, c.Select.Selectable = ready, ready
	end
end
function Screen:Offers(data)
	if self.Dead then
		return
	end
	self.OfferData = data
	if data.Deadline then
		self.Data.Deadline = data.Deadline
	end
	self.Busy = false
	self.Panel.Confirm.Visible = false
	self.Panel.PickAnyChooser.Visible = false
	self.Modal = false
	self.ConfirmAction = nil
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
			if card:FindFirstChild("SelectedCheck") then
				card.SelectedCheck.Visible = data.Picked == id
			end
			self:Connect(card.Select, function()
				if self:Ready() and not self.Modal then
					self.Busy = true
					self:Controls()
					self.Pick(id)
				end
			end, self.CardConnections)
		end
	end
	if data.Animate and not data.Picked and not self.Animation then
		self.Animation = HandRoll.new(self.Panel, data.Offers, data.Collection, function(card, id)
			renderCard(card, id)
		end)
		self.AnimationStarted = workspace:GetServerTimeNow()
		self.Gui:SetAttribute("RollAnimationCount", (self.Gui:GetAttribute("RollAnimationCount") or 0) + 1)
	end
	self.Message.Text = if data.Picked
		then "LOCKED • " .. Glassies.get(data.Picked).Name
		elseif data.Message then messages[data.Message] or data.Message
		else "Pick a glassy. This hand stays with you all match."
	self:Controls()
end

function Screen:Wallet(amount)
	if self.OfferData then
		self.OfferData.Marbles = amount
		self:Controls()
	end
end
function Screen:OpenPicker(oddsOnly)
	if not self:Ready() then
		return
	end
	for _, c in self.PickerConnections do
		c:Disconnect()
	end
	self.PickerConnections = {}
	local chooser = self.Panel.PickAnyChooser
	for _, tile in chooser.Grid.Tiles:GetChildren() do
		if tile:IsA("GuiObject") then
			tile:Destroy()
		end
	end
	local ids = {}
	for id in self.OfferData.Collection do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Glassies.get(a).Name < Glassies.get(b).Name
	end)
	local cost = self.OfferData.PickAnyCost or 0
	chooser.Title.Text = if oddsOnly
		then "REROLL ODDS • OWNED GLASSIES"
		else "PICK ANY • " .. (if cost == 0 then "FREE THIS MATCH" else cost .. " MARBLES")
	local layout = chooser.Grid.Tiles.UIGridLayout
	local function resize()
		layout.CellSize = UDim2.new(0.18, 0, 0, math.max(90, chooser.Grid.AbsoluteSize.Y * 0.58))
		layout.CellPadding = UDim2.new(0.02, 0, 0, 12)
		chooser.Grid.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12)
	end
	table.insert(self.PickerConnections, layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize))
	table.insert(self.PickerConnections, chooser.Grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))

	for i, id in ids do
		local def = Glassies.get(id)
		local tile = chooser.Grid.Templates.GlassyTile:Clone()
		tile.Name, tile.LayoutOrder, tile.Visible, tile.Parent = id, i, true, chooser.Grid.Tiles
		S.setAsset(tile.Artwork, "tile/tile_" .. S.rarity(def.Rarity))
		tile:FindFirstChild("Name").Text = def.Name
		Portrait.new(tile, id, tile.Portrait.Size, tile.Portrait.Position)
		tile.SelectedOutline.Visible = false
		S.bindSlices(tile)
		if oddsOnly then
			local odds = U.text(
				tile,
				"InclusionOdds",
				string.format("%.2f%%", math.min(3, #ids) / #ids * 100),
				UDim2.fromScale(0.8, 0.12),
				UDim2.fromScale(0.1, 0.82),
				Theme.Fonts.Caption
			)
			odds.TextColor3 = Theme.Colors.Highlight
			tile.Open.Active, tile.Open.Selectable = false, false
		else
			self:Connect(tile.Open, function()
				self:ChooseAny(id)
			end, self.PickerConnections)
		end
	end
	chooser.Visible = true
	resize()
	self.Modal = true
	self:Controls()
end
function Screen:ChooseAny(id)
	local data = self.OfferData
	if not self:Ready() or not data.Collection[id] then
		return
	end
	local cost = data.PickAnyCost or 0
	if (data.Marbles or 0) < cost then
		self:NeedMarbles("PickAny", cost)
		return
	end
	self.Busy = true
	self.Panel.PickAnyChooser.Visible, self.Modal = false, false
	self:Controls()
	if self.PickAny then
		self.PickAny(id, data)
	end
end
function Screen:RerollNow()
	local data = self.OfferData
	if not self:Ready() or self.Modal then
		return
	end
	if not data.PaidRandomAllowed then
		self.Message.Text = messages.restricted
		return
	end
	if not data.CanReroll then
		self.Message.Text = messages.nothing_new
		return
	end
	if self.Data.Deadline - workspace:GetServerTimeNow() < B.RerollReserveSeconds then
		self.Message.Text = messages.too_late
		return
	end
	if (data.Marbles or 0) < data.RerollCost then
		self:NeedMarbles("Reroll", data.RerollCost)
		return
	end
	self.Busy = true
	self:Controls()
	self.Reroll(data)
end
function Screen:Render(now)
	self.Title.Text = "CHOOSE YOUR GLASSY • " .. math.max(0, math.ceil(self.Data.Deadline - now))
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
	for _, group in { self.Connections, self.CardConnections, self.PickerConnections } do
		for _, c in group do
			c:Disconnect()
		end
	end
	self.Gui:Destroy()
end
return Screen
