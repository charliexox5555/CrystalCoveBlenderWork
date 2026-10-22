-- Marbles page of the shop window: a scrolling page with the Marble packs (Config/MarbleShop) on top
-- and Daily Marbles (decision 116) below them, on the shared ShopCard. The "+" on the HUD and shop-window
-- Marble counters opens the shop on this page. Packs are bought through StoreService (BuyMarblePack ->
-- intent -> Robux prompt -> receipt); Daily Marbles through DealsController.
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Remotes = require(RS.Shared.Remotes)
local Rules = require(RS.Shared.DailyStoreRules)
local U = require(script.Parent.Util)
local S = require(script.Parent.StainedGlass)
local Motion = require(script.Parent.Motion)
local Card = require(script.Parent.ShopCard)
local Theme = require(script.Parent.Parent.Theme)
local MarbleShop = {}
MarbleShop.__index = MarbleShop
MarbleShop.TabRequest = "ShopTabRequest" -- PlayerGui attribute: the tab the shop opens on next
local tints = {
	Color3.new(1, 1, 1),
	Theme.Palette.rubyLight,
	Theme.Palette.amberLight,
	Theme.Palette.emeraldLight,
	Theme.Palette.amethystLight,
	Theme.Palette.aquaLight,
}
local tiers = {
	Theme.Palette.aquaLight,
	Theme.Palette.sapphireLight,
	Theme.Palette.emeraldLight,
	Theme.Palette.amethystLight,
	Theme.Palette.amberLight,
	Theme.Palette.rubyLight,
	Theme.Palette.milkLight,
}

local function commas(n)
	local text = tostring(n)
	while true do
		local next, count = text:gsub("^(%d+)(%d%d%d)", "%1,%2")
		text = next
		if count == 0 then
			return text
		end
	end
end

-- Original pile illustration: a pyramid of tinted marbles that grows with the pack.
local function pile(parent, step)
	local art = U.make("Frame", parent, {
		Name = "Pile",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.43),
		Size = UDim2.fromScale(0.9, 0.7),
		ZIndex = 3,
	})
	S.aspect(art, 1.4).AspectType = Enum.AspectType.FitWithinMaxSize
	local width = math.min(0.46, 0.92 / step, (1 / (0.7 * (step - 1) + 1)) / 1.4)
	local height = width * 1.4
	local n = 0
	for row = 0, step - 1 do
		local count = step - row
		for i = 0, count - 1 do
			n += 1
			local x = 0.5 + (i - (count - 1) / 2) * width * 0.92
			local y = 1 - row * height * 0.7
			local marble = S.image(art, "Marble" .. n, "icon/marble", UDim2.fromScale(width, height))
			marble.AnchorPoint, marble.Position = Vector2.new(0.5, 1), UDim2.fromScale(x, y)
			marble.ZIndex = 3 + row
			if marble:IsA("ImageLabel") then
				marble.ImageColor3 = tints[(n * 7 + row) % #tints + 1]
			end
		end
	end
	return art
end

local Assets = require(RS.Shared.Config.UIAssets)
local function picture(parent, name, path, size, position)
	local image = U.make("ImageLabel", parent, {
		Name = name,
		BackgroundTransparency = 1,
		Image = Assets[path] or "",
		ScaleType = Enum.ScaleType.Fit,
		Size = size,
		Position = position or UDim2.new(),
	})
	return image
end

local function deals()
	local ok, controller = pcall(require, script.Parent.Parent.Parent.Controllers.DealsController)
	return if ok then controller else nil
end

local function duration(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h, m = seconds // 3600, seconds % 3600 // 60
	return if h > 0 then string.format("%dh %dm", h, m) else string.format("%dm %02ds", m, seconds % 60)
end

-- Daily Marbles (decision 116): one buy a day, and each buy makes the next one bigger (a missed day keeps your
-- place). Big card on the left, the seven-step ladder on the right.
function MarbleShop:Daily(canvas)
	local header = U.text(
		canvas,
		"DailyHeader",
		"DAILY MARBLES",
		UDim2.fromScale(0.5, 0.045),
		UDim2.fromScale(0.02, 0.6),
		Theme.Fonts.Heading
	)
	header.TextXAlignment = Enum.TextXAlignment.Left
	local frame = U.make("Frame", canvas, {
		Name = "DailyCard",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.02, 0.65),
		Size = UDim2.fromScale(0.3, 0.33),
	})
	local card = Card.new(frame)
	-- Lower and smaller than the pack piles so the stack stays under the TODAY / bonus tags.
	local stack = pile(card.Art, 3)
	stack.Position, stack.Size = UDim2.fromScale(0.5, 0.52), UDim2.fromScale(0.85, 0.56)
	Card.accent(card, Theme.Palette.amberLight)
	Card.pill(card.Rarity, "TODAY", "amber")
	local strip = U.make("Frame", canvas, {
		Name = "Ladder",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.34, 0.67),
		Size = UDim2.fromScale(0.64, 0.29),
	})
	U.make("UIListLayout", strip, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0.01, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local cells = {}
	for i, amount in require(RS.Shared.Config.Offers).DailyMarbles.Amounts do
		local cell = picture(strip, "Day" .. i, "screens/daily_rewards/cell_locked", UDim2.fromScale(0.13, 1))
		cell.LayoutOrder = i
		U.make("UIAspectRatioConstraint", cell, { AspectRatio = 0.72 })
		local day = U.text(
			cell,
			"Day",
			"DAY " .. i,
			UDim2.fromScale(0.8, 0.16),
			UDim2.fromScale(0.1, 0.06),
			Theme.Fonts.Heading
		)
		day.UITextSizeConstraint.MaxTextSize = 20
		local icon = S.image(cell, "Marble", "icon/marble", UDim2.fromScale(0.55, 0.4))
		icon.AnchorPoint, icon.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		local value = U.text(
			cell,
			"Amount",
			"x" .. amount,
			UDim2.fromScale(0.86, 0.18),
			UDim2.fromScale(0.07, 0.74),
			Theme.Fonts.Heading
		)
		value.UITextSizeConstraint.MaxTextSize = 22
		U.make("UIStroke", value, { Thickness = 1.5, Color = Theme.Palette.lead })
		cells[i] = cell
	end
	local note = U.text(
		canvas,
		"LadderNote",
		"",
		UDim2.fromScale(0.64, 0.035),
		UDim2.fromScale(0.34, 0.955),
		Theme.Fonts.Caption
	)
	note.TextColor3 = Theme.Palette.amberLight
	self.DailyCard, self.Ladder, self.LadderNote = card, cells, note
	table.insert(
		self.Connections,
		card.Button.Activated:Connect(function()
			local state = self.Deals and self.Deals.DailyMarbles
			local controller = deals()
			if state and state.Available and controller then
				self.Say("Opening the Robux purchase…")
				controller:Buy("DailyMarbles", card.Button)
			end
		end)
	)
end

function MarbleShop:ShowDaily(view)
	self.Deals = view
	local state = view.DailyMarbles
	local card = self.DailyCard
	if not card or not state then
		return
	end
	card.Name.Text = "x" .. state.Next .. " Marbles"
	Card.pill(card.Corner, if state.Bonus > 0 then "+" .. state.Bonus .. "%" else nil, "emerald")
	if state.Available then
		Card.button(card, "robux", Card.ROBUX .. " " .. state.Price)
	elseif state.BoughtToday then
		Card.button(card, "sold", "")
	else
		Card.button(card, "soon", "COMING SOON")
	end
	for i, cell in self.Ladder do
		-- Steps already bought are claimed; the step the next buy is on glows today, or waits for tomorrow.
		local path = if i < state.Step
			then "screens/daily_rewards/cell_claimed"
			elseif i == state.Step and state.Available then "screens/daily_rewards/cell_today"
			elseif i == #self.Ladder then "screens/daily_rewards/cell_day7"
			else "screens/daily_rewards/cell_locked"
		cell.Image = Assets[path] or ""
		cell.ImageTransparency = if i <= state.Step then 0 else 0.25
	end
	self.LadderNote.Text = if state.Step == #self.Ladder and state.Done >= #self.Ladder
		then "Top step: x" .. state.Next .. " every day"
		else "Each day you buy, tomorrow gives more"
	self:Step()
end

-- Builds the Marbles page inside `page`: a scrolling page with the packs on top and Daily Marbles below them
-- (creator, 2026-10-22).
-- `say` shows a status line. Returns a CrateViews-style view.
function MarbleShop.page(page, say)
	local self = setmetatable({ Page = page, Connections = {}, Cards = {}, Say = say, Packs = {} }, MarbleShop)
	local canvas = U.make("ScrollingFrame", page, {
		Name = "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromScale(0, 1.75),
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarImageColor3 = Theme.Palette.aquaLight,
	})
	self.Canvas = canvas
	self:Daily(canvas)
	local header = U.text(
		canvas,
		"Header",
		"MARBLE PACKS",
		UDim2.fromScale(0.5, 0.045),
		UDim2.fromScale(0.02, 0),
		Theme.Fonts.Heading
	)
	header.TextXAlignment = Enum.TextXAlignment.Left
	local note = U.text(
		canvas,
		"Note",
		"Marbles pay for Pick Any and other Marble items",
		UDim2.fromScale(0.46, 0.035),
		UDim2.fromScale(0.52, 0.005),
		Theme.Fonts.Caption
	)
	note.TextXAlignment, note.TextColor3 = Enum.TextXAlignment.Right, Theme.Palette.amberLight
	note.UITextSizeConstraint.MaxTextSize = Theme.TextSize.Small
	local grid = U.make("Frame", canvas, {
		Name = "Packs",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.02, 0.05),
		Size = UDim2.fromScale(0.96, 0.54),
	})
	U.make("UIGridLayout", grid, {
		-- Four across: seven packs in two rows.
		CellSize = UDim2.fromScale(0.235, 0.47),
		CellPadding = UDim2.fromScale(0.018, 0.05),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})
	for order, pack in Rules.marblePacks() do
		local frame =
			U.make("Frame", grid, { Name = "Pack_" .. pack.Id, BackgroundTransparency = 1, LayoutOrder = order })
		local card = Card.new(frame)
		pile(card.Art, pack.Art)
		card.Name.Text = commas(pack.Marbles) .. " Marbles"
		Card.accent(card, tiers[pack.Art] or Theme.Palette.aquaLight)
		-- Short tags: four cards to a row leave no room for "MARBLE BUCKET" next to "+23% BONUS" (ui-audit).
		Card.pill(card.Rarity, string.upper((pack.Name:gsub("^Marble ", ""))), "sapphire")
		Card.pill(
			card.Corner,
			if pack.Bonus > 0 then "+" .. pack.Bonus .. "%" else nil,
			if pack.Bonus >= 25 then "amber" else "emerald"
		)
		self.Packs[pack.Id] = { Card = card, Pack = pack }
		self:ShowPack(pack.Id)
		table.insert(self.Cards, frame)
		table.insert(
			self.Connections,
			card.Button.Activated:Connect(function()
				if self:PackOnSale(pack.Id) then
					say("Opening the Robux purchase…")
					Remotes.BuyMarblePack:FireServer(pack.Id)
				else
					say("This pack is coming soon")
				end
			end)
		)
	end
	table.insert(
		self.Connections,
		Remotes.StoreResult.OnClientEvent:Connect(function(result)
			if
				type(result) == "table"
				and (result.Kind == "Marbles" or result.Kind == "DailyMarbles")
				and type(result.Message) == "string"
			then
				say(result.Message)
			end
		end)
	)
	table.insert(
		self.Connections,
		page:GetPropertyChangedSignal("Visible"):Connect(function()
			if page.Visible then
				Motion.stagger(self.Cards)
			end
		end)
	)
	local controller = deals()
	if controller then
		self.Unwatch = controller:Watch(function(view)
			if self.Canvas.Parent then
				self.Held = view.Held or {}
				self:ShowDaily(view)
				for id in self.Packs do
					self:ShowPack(id)
				end
			end
		end)
	end
	return self
end

-- A pack is on sale when it has a product and the server isn't holding it back (dashboard price != config).
function MarbleShop:PackOnSale(id)
	local entry = self.Packs[id]
	local pack = entry and entry.Pack
	if not pack or not pack.Available then
		return false
	end
	for _, config in require(RS.Shared.Config.MarbleShop).Packs do
		if config.Id == id and self.Held and self.Held[tostring(config.ProductId)] then
			return false
		end
	end
	return true
end

function MarbleShop:ShowPack(id)
	local entry = self.Packs[id]
	if self:PackOnSale(id) then
		Card.button(entry.Card, "robux", Card.ROBUX .. " " .. commas(entry.Pack.RobuxPrice))
	else
		Card.button(entry.Card, "soon", "COMING SOON")
	end
end

-- CrateViews interface. Step keeps the Daily Marbles countdown ticking.
function MarbleShop:Wallet() end
function MarbleShop:Step()
	local state = self.Deals and self.Deals.DailyMarbles
	if not state or not state.BoughtToday or not self.DailyCard then
		return
	end
	local now = os.clock()
	if self.LastTick and now - self.LastTick < 1 then
		return
	end
	self.LastTick = now
	local controller = deals()
	local serverNow = if controller then controller:Now() else workspace:GetServerTimeNow()
	S.buttonText(self.DailyCard.Button, "TOMORROW " .. duration(state.NextReset - serverNow))
end
function MarbleShop:Destroy()
	if self.Unwatch then
		self.Unwatch()
	end
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	self.Connections = {}
end

-- Adds a "+" to a Marble counter plaque. Clicking it asks the shop to show the Marbles page,
-- then calls `onOpen` (open the shop, or switch tab if it is already open).
function MarbleShop.attachPlus(plaque, onOpen)
	if not plaque or plaque:FindFirstChild("MarblePlus") then
		return plaque and plaque:FindFirstChild("MarblePlus")
	end
	local button = Instance.new("ImageButton")
	button.Name, button.BackgroundTransparency = "MarblePlus", 1
	-- Mostly past the plaque's right end, so the 44 px button never covers the amount.
	button.AnchorPoint, button.Position = Vector2.new(0.2, 0.5), UDim2.fromScale(0.97, 0.5)
	button.Size, button.ZIndex = UDim2.fromScale(0.36, 1.25), (plaque.ZIndex or 1) + 3
	S.setAsset(button, "hud/hex_emerald")
	S.aspect(button, 300 / 340)
	local label =
		U.text(button, "Label", "+", UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, 0.06), Theme.Fonts.Heading)
	label.ZIndex = button.ZIndex + 1
	label.UITextSizeConstraint.MaxTextSize = 40
	U.make("UIStroke", label, { Thickness = 2, Color = Theme.Palette.lead })
	U.make("UISizeConstraint", button, { MinSize = Vector2.new(44, 44) }) -- 44 px tap target (ui-audit, Galaxy A06)
	button.Parent = plaque
	Motion.button(button)
	-- The amount ends where the button starts, so the 44 px "+" never covers "10,000" (HUD and Shop header, any screen).
	local amount = plaque:FindFirstChild("MarblesAmount")
	if amount and amount:IsA("GuiObject") then
		local home = amount.Size
		local function fit()
			local full = home.X.Scale * plaque.AbsoluteSize.X + home.X.Offset
			local room = button.AbsolutePosition.X - 2 - amount.AbsolutePosition.X
			amount.Size = if room > 0 and room < full
				then UDim2.new(0, math.floor(room), home.Y.Scale, home.Y.Offset)
				else home
		end
		button:GetPropertyChangedSignal("AbsolutePosition"):Connect(fit)
		button:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		plaque:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		task.defer(fit)
	end
	button.Activated:Connect(function()
		Players.LocalPlayer.PlayerGui:SetAttribute(MarbleShop.TabRequest, "Marbles")
		if onOpen then
			onOpen()
		end
	end)
	return button
end

return MarbleShop
