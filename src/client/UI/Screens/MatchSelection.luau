local RS = game:GetService("ReplicatedStorage")
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
	S.bindSlices(card)
end
function Screen:Connect(button, callback, group)
	table.insert(group or self.Connections, button.Activated:Connect(callback))
end
function Screen.new(data, pick, reroll, pickAny)
	local self = setmetatable({
		Data = data,
		Pick = pick,
		Reroll = reroll,
		PickAny = pickAny,
		Connections = {},
		CardConnections = {},
		PickerConnections = {},
	}, Screen)
	self.Gui = U.screen("RollScreen", 15)
	self.Panel = self.Gui.Roll
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
		self:ConfirmReroll()
	end)
	self:Connect(self.Panel.PickAnyChooser.Cancel, function()
		self.Panel.PickAnyChooser.Visible = false
		self.Modal = false
		self:Controls()
	end)
	self:Connect(self.Panel.Confirm.Cancel, function()
		self.Panel.Confirm.Visible = false
		self.Modal = self.Panel.PickAnyChooser.Visible
		self:Controls()
	end)
	self:Connect(self.Panel.Confirm.Accept, function()
		self:Confirm()
	end)
	return self
end
function Screen:Confirm()
	if self.ConfirmAction and not self.Busy and self.Panel.Confirm.Visible then
		local action = self.ConfirmAction
		self.ConfirmAction = nil
		self.Busy = true
		self.Panel.Confirm.Visible = false
		self.Panel.PickAnyChooser.Visible = false
		self.Modal = false
		self:Controls()
		action()
	end
end
function Screen:Controls()
	local data = self.OfferData
	if not data then
		return
	end
	local ready = not self.Busy and not self.Animation and not data.Picked and not self.Modal
	self.Panel.PickAny.Visible = not data.Picked
	self.Panel.PickAny.Active, self.Panel.PickAny.Selectable = ready, ready
	S.buttonText(
		self.Panel.PickAny,
		"PICK ANY • " .. (if (data.PickAnyCost or 0) == 0 then "FREE" else tostring(data.PickAnyCost))
	)
	self.Panel.Reroll.Visible = data.PaidRandomAllowed == true and data.CanReroll == true
	self.Panel.Reroll.Active, self.Panel.Reroll.Selectable = ready, ready
	S.buttonText(self.Panel.Reroll, "REROLL • " .. tostring(data.RerollCost or 3))
	self.Panel.Wallet.Text = tostring(data.Marbles or 0) .. " MARBLES"
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
			self:Connect(card.Select, function()
				if not self.Animation and not self.Busy and not self.Modal and not self.OfferData.Picked then
					self.Busy = true
					self:Controls()
					self.Pick(id)
				end
			end, self.CardConnections)
		end
	end
	if data.Animate and not data.Picked and not self.Animation then
		self.Animation = HandRoll.new(self.Panel, data.Offers, data.Collection, renderCard)
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
function Screen:OpenPicker()
	if not self.OfferData or self.Busy or self.Animation or self.OfferData.Picked then
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
	chooser.Title.Text = "PICK ANY • " .. (if cost == 0 then "FREE THIS MATCH" else cost .. " MARBLES")
	local rows = math.max(1, math.ceil(#ids / 5))
	local canvas = math.max(1, rows * 0.74)
	chooser.Grid.CanvasSize = UDim2.fromScale(0, canvas)
	local layout = chooser.Grid.Tiles.UIGridLayout
	layout.CellSize, layout.CellPadding = UDim2.fromScale(0.18, 0.70 / canvas), UDim2.fromScale(0.02, 0.04 / canvas)
	for i, id in ids do
		local def = Glassies.get(id)
		local tile = chooser.Grid.Templates.GlassyTile:Clone()
		tile.Name, tile.LayoutOrder, tile.Visible, tile.Parent = id, i, true, chooser.Grid.Tiles
		S.setAsset(tile.Artwork, "tile/tile_" .. S.rarity(def.Rarity))
		tile:FindFirstChild("Name").Text = def.Name
		Portrait.new(tile, id, tile.Portrait.Size, tile.Portrait.Position)
		tile.SelectedOutline.Visible = false
		S.bindSlices(tile)
		self:Connect(tile.Open, function()
			self:ChooseAny(id)
		end, self.PickerConnections)
	end
	chooser.Visible = true
	self.Modal = true
	self:Controls()
end
function Screen:ChooseAny(id)
	local data = self.OfferData
	if self.Busy or data.Picked or not data.Collection[id] then
		return
	end
	local cost = data.PickAnyCost or 0
	if (data.Marbles or 0) < cost then
		self.Message.Text = "Need " .. (cost - (data.Marbles or 0)) .. " more Marbles."
		return
	end
	local function send()
		if self.PickAny then
			self.PickAny(id, data)
		end
	end
	if cost == 0 then
		self.Busy = true
		self.Panel.PickAnyChooser.Visible = false
		self.Modal = false
		self:Controls()
		send()
	else
		local p = self.Panel.Confirm
		p.Title.Text = "PICK " .. Glassies.get(id).Name:upper()
		p.Body.Size = UDim2.fromScale(0.88, 0.40)
		p.Body.Text = "Choose this glassy for this round only?\nCost: " .. cost .. " Marbles."
		p.Odds.Visible = false
		p.Visible = true
		self.ConfirmAction = send
	end
end
function Screen:ConfirmReroll()
	local data = self.OfferData
	if not data or self.Busy or self.Animation or data.Picked or not data.CanReroll then
		return
	end
	local cost = data.RerollCost
	if (data.Marbles or 0) < cost then
		self.Message.Text = "Need " .. (cost - (data.Marbles or 0)) .. " more Marbles."
		return
	end
	local p = self.Panel.Confirm
	p.Title.Text = "REROLL • " .. cost .. " MARBLES"
	p.Body.Size = UDim2.fromScale(0.88, 0.14)
	p.Body.Text = "3 distinct glassies. This replaces your match hand.\nThe same hand can appear again."
	for _, o in p.Odds:GetChildren() do
		if o:IsA("GuiObject") then
			o:Destroy()
		end
	end
	local ids = {}
	for id in data.Collection do
		table.insert(ids, id)
	end
	table.sort(ids)
	local chance = math.min(3, #ids) / #ids * 100
	for _, id in ids do
		local l = U.text(
			p.Odds,
			id,
			Glassies.get(id).Name .. string.format(" • %.2f%% in your hand", chance),
			UDim2.new(1, -8, 0, 24),
			UDim2.new(),
			Theme.Fonts.Caption
		)
		l:SetAttribute("FitSingleLine", true)
		S.bindText(l)
	end
	p.Odds.Visible, p.Visible = true, true
	self.Modal = true
	self.ConfirmAction = function()
		self.Reroll(data)
	end
	self:Controls()
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
