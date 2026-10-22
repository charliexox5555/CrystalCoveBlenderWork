-- Robux offer popups (decision 116): the Starter Pack, the Daily Glassy (odds before every purchase) and Need
-- Marbles. Stained Glass panes built in code from MatchKit, pictures first (kids don't read): item pictures, Marble
-- piles, big prices; words stay short. Each popup is modal (an invisible blocker, no dark backdrop), closes with its
-- diamond, B or Escape, and comes back to wherever the player was.
local RS = game:GetService("ReplicatedStorage")
local Glassies = require(RS.Shared.Config.Glassies)
local Theme = require(script.Parent.Parent.Theme)
local S = require(script.Parent.Parent.Components.StainedGlass)
local Kit = require(script.Parent.Parent.Components.MatchKit)
local Motion = require(script.Parent.Parent.Components.Motion)
local GamepadNav = require(script.Parent.Parent.Components.GamepadNav)
local Presentation = require(script.Parent.Parent.Components.ItemPresentation)

-- A picture that can't be built (an item whose art isn't installed yet) must not break the popup or tile.
local function safe(fn, ...)
	local ok, result = pcall(fn, ...)
	return if ok then result else nil
end
local TouchGate = require(script.Parent.Parent.TouchGate)
local Screens = {}

local ROBUX = utf8.char(0xE002)
Screens.ROBUX = ROBUX
local CARD = {
	Common = "common",
	Uncommon = "uncommon",
	Rare = "rare",
	Epic = "epic",
	Legendary = "legendary",
	Mythic = "mythic",
}
local RARITY_TEXT = {
	Rare = Theme.Palette.sapphireLight,
	Epic = Theme.Palette.amethystLight,
	Legendary = Theme.Palette.amberLight,
	Mythic = Theme.Palette.rubyLight,
}

-- Odds as Roblox's paid random items policy asks: rounded to four decimal places below the first non-zero digit
-- (8.5714%, 0.5%, 60%), shown with ROUNDED_NOTE wherever a rounded value appears.
function Screens.percent(p)
	local v = p * 100
	if v <= 0 then
		return "0%"
	end
	local decimals = math.max(0, 4 - math.floor(math.log10(v)))
	local text = string.format("%." .. decimals .. "f", v)
	if text:find("%.") then
		text = text:gsub("0+$", ""):gsub("%.$", "")
	end
	return text .. "%"
end
Screens.ROUNDED_NOTE = "Probabilities are rounded; total of displayed individual probabilities may not equal 100%."

function Screens.duration(seconds)
	seconds = math.max(0, math.floor(seconds))
	local d, h, m, s = seconds // 86400, seconds % 86400 // 3600, seconds % 3600 // 60, seconds % 60
	if d > 0 then
		return string.format("%dd %dh", d, h)
	elseif h > 0 then
		return string.format("%dh %dm", h, m)
	end
	return string.format("%dm %02ds", m, s)
end

local Popup = {}
Popup.__index = Popup

-- A modal pane: blocker, pane_dark panel (aspect), title banner and close diamond. `close` runs once.
local function popup(name, title, tint, aspect, width, close)
	local self = setmetatable({ Closed = false, Connections = {}, OnClose = close }, Popup)
	self.Gui = Kit.gui(name, 32)
	local block = Instance.new("TextButton")
	block.Name, block.Size, block.BackgroundTransparency, block.Text = "Block", UDim2.fromScale(1, 1), 1, ""
	block.AutoButtonColor, block.Active, block.Parent = false, true, self.Gui
	local panel = Instance.new("ImageLabel")
	panel.Name, panel.AnchorPoint, panel.Position = "Panel", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	panel.Size, panel.BackgroundTransparency, panel.Parent = UDim2.fromScale(width, 0.76), 1, self.Gui
	S.setAsset(panel, "panel/pane_dark")
	S.aspect(panel, aspect)
	self.Panel = panel
	local banner =
		Kit.icon(panel, "Banner", "panel/title_" .. tint, UDim2.fromScale(0.56, 0.17), UDim2.fromScale(0.5, 0.0))
	banner.AnchorPoint, banner.ZIndex = Vector2.new(0.5, 0.5), 3
	local label = Kit.label(banner, "Title", title, UDim2.fromScale(0.8, 0.56), UDim2.fromScale(0.1, 0.2))
	label.ZIndex = 4
	local closeButton = Instance.new("ImageButton")
	closeButton.Name, closeButton.BackgroundTransparency, closeButton.Image = "Close", 1, ""
	closeButton.AnchorPoint, closeButton.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.975, 0.03)
	closeButton.Size, closeButton.ZIndex, closeButton.Parent = UDim2.fromScale(0.11, 0.11), 5, panel
	S.setAsset(closeButton, "button/close_diamond")
	S.aspect(closeButton, 1)
	local x = Kit.icon(closeButton, "X", "icon/close_x", UDim2.fromScale(0.46, 0.46), UDim2.fromScale(0.5, 0.5))
	x.AnchorPoint, x.ZIndex = Vector2.new(0.5, 0.5), 6
	Motion.button(closeButton)
	self.CloseButton = closeButton
	self:Connect(closeButton.Activated, function()
		self:Close()
	end)
	self.Nav = GamepadNav.push(panel, {
		Close = function()
			self:Close()
		end,
	})
	TouchGate.acquire(self)
	-- A clean stage: the lobby HUD keeps only the wallet while a popup is open (bought Marbles fly into it).
	local hud = game.Players.LocalPlayer.PlayerGui:FindFirstChild("LobbyHUD")
	self.Hidden = {}
	for _, child in hud and hud:GetChildren() or {} do
		if child:IsA("GuiObject") and child.Name ~= "Currency" and child.Visible then
			self.Hidden[child] = true
			child.Visible = false
		end
	end
	Kit.popIn(panel)
	return self
end

function Popup:Connect(signal, fn)
	table.insert(self.Connections, signal:Connect(fn))
end

function Popup:Close()
	if self.Closed then
		return
	end
	self.Closed = true
	self.Nav.Pop()
	TouchGate.release(self)
	for child in self.Hidden or {} do
		-- Tiles that went away meanwhile (the Starter Pack once bought) stay hidden.
		if child.Parent and not child:GetAttribute("DealHidden") then
			child.Visible = true
		end
	end
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	if self.Ticker then
		task.cancel(self.Ticker)
	end
	local gui = self.Gui
	gui.Name = gui.Name .. "_Closing"
	gui.Block.Active = false
	Kit.popOut(self.Panel, function()
		gui:Destroy()
	end)
	if self.OnClose then
		self.OnClose()
	end
end

-- A pyramid of Marbles that grows with the amount (same look as the Marble packs).
function Screens.pile(parent, step, size, position)
	local art = Kit.frame(parent, "Pile", size, position, Vector2.new(0.5, 0.5))
	S.aspect(art, 1.4).AspectType = Enum.AspectType.FitWithinMaxSize
	local tints = {
		Color3.new(1, 1, 1),
		Theme.Palette.rubyLight,
		Theme.Palette.amberLight,
		Theme.Palette.emeraldLight,
		Theme.Palette.amethystLight,
		Theme.Palette.aquaLight,
	}
	local width = math.min(0.46, 0.92 / step, (1 / (0.7 * (step - 1) + 1)) / 1.4)
	local height, n = width * 1.4, 0
	for row = 0, step - 1 do
		local count = step - row
		for i = 0, count - 1 do
			n += 1
			local marble = S.image(art, "Marble" .. n, "icon/marble", UDim2.fromScale(width, height))
			marble.AnchorPoint = Vector2.new(0.5, 1)
			marble.Position = UDim2.fromScale(0.5 + (i - (count - 1) / 2) * width * 0.92, 1 - row * height * 0.7)
			marble.ZIndex = 3 + row
			if marble:IsA("ImageLabel") then
				marble.ImageColor3 = tints[(n * 7 + row) % #tints + 1]
			end
		end
	end
	return art
end

-- One prize card: rarity frame, the item's picture and a short name on a plaque.
local function itemCard(parent, name, category, id, rarity, size, position)
	local card = Kit.icon(parent, name, "card/card_" .. (CARD[rarity] or "epic"), size, position)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	local def = Presentation.definition(category, id)
	local picture =
		safe(Presentation.portrait, card, category, id, UDim2.fromScale(0.8, 0.6), UDim2.fromScale(0.1, 0.1), "Picture")
	if picture and picture:IsA("GuiObject") then
		picture.ZIndex = 3
	end
	local label = Kit.label(
		card,
		"ItemName",
		def and def.Name or id,
		UDim2.fromScale(0.86, 0.15),
		UDim2.fromScale(0.07, 0.75),
		{ MaxSize = 22, Small = true }
	)
	label.ZIndex = 4
	return card
end

-- Robux price button (emerald gem with the Robux glyph).
local function buyButton(panel, price, size, position)
	local button = Kit.gem(panel, "Buy", ROBUX .. " " .. tostring(price), "emerald", size, position)
	button.Label.FontFace = Theme.Fonts.Heading
	return button
end

local function setBuy(button, state, price, waitText)
	if state == "buy" then
		S.setAsset(button.Artwork, "button/gem_emerald")
		button.Label.Text = ROBUX .. " " .. tostring(price)
		Kit.enable(button, true)
	elseif state == "soon" then
		S.setAsset(button.Artwork, "button/gem_sapphire")
		button.Label.Text = "SOON"
		Kit.enable(button, false)
	else
		S.setAsset(button.Artwork, "button/gem_sapphire")
		button.Label.Text = waitText or "OWNED"
		Kit.enable(button, false)
	end
end

----------------------------------------------------------------------------------------------------------------------
-- Starter Pack: the three exclusives + a Marble pile, an honest "worth" (the parts at their own prices), the price.
function Screens.starter(view, serverNow, buy, close)
	local self = popup("StarterPackScreen", "STARTER PACK", "amber", 1.75, 0.66, close)
	local panel, state = self.Panel, view.Starter
	-- Timer under the banner (only while the window runs).
	local timer = Kit.label(panel, "Timer", "", UDim2.fromScale(0.5, 0.07), UDim2.fromScale(0.25, 0.1), {
		Color = Theme.Palette.amberLight,
		MaxSize = 26,
	})
	-- Three exclusive cards + the Marble card in a row.
	local row = Kit.frame(panel, "Items", UDim2.fromScale(0.92, 0.5), UDim2.fromScale(0.04, 0.19))
	for i, item in state.Items do
		local card = itemCard(
			row,
			"Item" .. i,
			item.Category,
			item.Id,
			item.Rarity or "Epic",
			UDim2.fromScale(0.23, 1),
			UDim2.fromScale(0.125 + (i - 1) * 0.25, 0.5)
		)
		card.LayoutOrder = i
	end
	local marbles = Kit.icon(row, "Marbles", "card/card_rare", UDim2.fromScale(0.23, 1), UDim2.fromScale(0.875, 0.5))
	marbles.AnchorPoint = Vector2.new(0.5, 0.5)
	Screens.pile(marbles, 4, UDim2.fromScale(0.78, 0.55), UDim2.fromScale(0.5, 0.42)).ZIndex = 3
	Kit.label(marbles, "Amount", "x" .. state.Marbles, UDim2.fromScale(0.86, 0.15), UDim2.fromScale(0.07, 0.75), {
		MaxSize = 26,
	}).ZIndex =
		4
	-- "EXCLUSIVE" ribbon over the items (a tag, pictures do the rest).
	local ribbon =
		Kit.tag(panel, "Exclusive", "ONLY HERE", "ruby", UDim2.fromScale(0.2, 0.065), UDim2.fromScale(0.04, 0.165))
	ribbon.ZIndex = 6
	-- Worth (struck through) -> price; the -% tag is rounded down (OfferRules.starterValue).
	local value = state.Value or { Total = 0, Off = 0 }
	Kit.label(panel, "WorthCaption", "WORTH", UDim2.fromScale(0.22, 0.05), UDim2.fromScale(0.1, 0.725), {
		Font = Theme.Fonts.Caption,
		Color = Theme.Palette.milkDark,
		MaxSize = 20,
		Small = true,
	})
	Kit.label(
		panel,
		"Worth",
		"<s>" .. ROBUX .. " " .. tostring(value.Total) .. "</s>",
		UDim2.fromScale(0.22, 0.09),
		UDim2.fromScale(0.1, 0.775),
		{ RichText = true, Color = Theme.Palette.milkDark, MaxSize = 40 }
	)
	if value.Off > 0 then
		local off = Kit.tag(
			panel,
			"Off",
			"-" .. value.Off .. "%",
			"ruby",
			UDim2.fromScale(0.2, 0.12),
			UDim2.fromScale(0.34, 0.75)
		)
		off.Rotation = -6
		off.Label.UITextSizeConstraint.MaxTextSize = 44
		off.Label.FontFace = Theme.Fonts.Heading
	end
	local button = buyButton(panel, state.Price, UDim2.fromScale(0.34, 0.15), UDim2.fromScale(0.74, 0.8))
	self.Buy = button
	self.Nav.SetFirst(button)
	local function render(current)
		local s = current.Starter
		if s.Bought then
			setBuy(button, "owned", s.Price, "YOURS!")
		elseif s.Available then
			setBuy(button, "buy", s.Price)
		else
			setBuy(button, "soon", s.Price)
		end
	end
	render(view)
	self.Render = render
	self:Connect(button.Activated, function()
		if button.Active then
			buy("Starter", button)
		end
	end)
	-- Countdown, ticking locally from the server's clock.
	local offset = serverNow - workspace:GetServerTimeNow()
	self.Ticker = task.spawn(function()
		while not self.Closed do
			local ends = state.EndsAt
			timer.Text = if ends
				then "ENDS IN " .. Screens.duration(ends - (workspace:GetServerTimeNow() + offset))
				else ""
			task.wait(1)
		end
	end)
	return self
end

-- Bought: the cards bounce, the button reads YOURS! and the popup closes by itself a moment later.
function Screens.celebrate(popupSelf)
	if not popupSelf or popupSelf.Closed then
		return
	end
	local items = popupSelf.Panel:FindFirstChild("Items")
	for _, card in items and items:GetChildren() or {} do
		if card:IsA("GuiObject") then
			Motion.bump(card, 0.2)
		end
	end
	if popupSelf.Buy then
		setBuy(popupSelf.Buy, "owned", 0, "YOURS!")
	end
	task.delay(2.2, function()
		popupSelf:Close()
	end)
end

----------------------------------------------------------------------------------------------------------------------
-- Daily Glassy: the Kiln picture, the odds by rarity (and DETAILS with every glassy) shown before buying.
function Screens.dailyGlassy(view, serverNow, buy, close)
	local self = popup("DailyGlassyScreen", "DAILY GLASSY", "amethyst", 1.55, 0.6, close)
	local panel, state = self.Panel, view.DailyGlassy
	local art = Kit.frame(panel, "Art", UDim2.fromScale(0.4, 0.62), UDim2.fromScale(0.04, 0.16))
	local glow = Kit.icon(art, "Glow", "kiln/glow", UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5))
	glow.AnchorPoint, glow.ImageColor3, glow.ImageTransparency =
		Vector2.new(0.5, 0.5), Theme.Palette.amethystLight, 0.35
	local kiln = safe(
		Presentation.crate,
		art,
		"Glassies",
		"Marbles",
		UDim2.fromScale(0.9, 0.9),
		UDim2.fromScale(0.05, 0.02),
		"Kiln"
	)
	if kiln and kiln:IsA("GuiObject") then
		kiln.ZIndex = 3
	end
	Kit.label(art, "Once", "1 A DAY", UDim2.fromScale(0.8, 0.14), UDim2.fromScale(0.1, 0.88), {
		Color = Theme.Palette.amberLight,
		MaxSize = 26,
	}).ZIndex =
		4
	-- Odds column: one row per rarity, with each glassy's own chance (Roblox's odds rules: all outcomes, before buying).
	local list = Kit.frame(panel, "Odds", UDim2.fromScale(0.5, 0.58), UDim2.fromScale(0.47, 0.15))
	Kit.label(list, "Header", "ODDS", UDim2.fromScale(1, 0.13), UDim2.fromScale(0, 0), {
		Color = Theme.Palette.aquaLight,
		MaxSize = 26,
	})
	local rows = state.Rarities or {}
	for i, row in rows do
		local y = 0.15 + (i - 1) * (0.84 / math.max(4, #rows))
		local plate = Kit.icon(
			list,
			"Row" .. row.Rarity,
			"panel/odds_row_" .. CARD[row.Rarity],
			UDim2.fromScale(1, 0.84 / math.max(4, #rows) - 0.02),
			UDim2.fromScale(0, y)
		)
		plate.UIAspectRatioConstraint:Destroy()
		Kit.label(plate, "Rarity", string.upper(row.Rarity), UDim2.fromScale(0.33, 0.7), UDim2.fromScale(0.075, 0.15), {
			XAlign = Enum.TextXAlignment.Left,
			Color = RARITY_TEXT[row.Rarity],
			MaxSize = 24,
		})
		Kit.label(
			plate,
			"Chance",
			Screens.percent(row.Chance),
			UDim2.fromScale(0.22, 0.7),
			UDim2.fromScale(0.4, 0.15),
			{
				MaxSize = 26,
			}
		)
		Kit.label(
			plate,
			"Each",
			#row.Pool .. " × " .. Screens.percent(row.Chance / #row.Pool),
			UDim2.fromScale(0.34, 0.6),
			UDim2.fromScale(0.63, 0.2),
			{ Font = Theme.Fonts.Caption, MaxSize = 18, Small = true, Color = Theme.Palette.milk }
		)
	end
	Kit.label(panel, "Rounded", Screens.ROUNDED_NOTE, UDim2.fromScale(0.5, 0.075), UDim2.fromScale(0.47, 0.725), {
		Font = Theme.Fonts.Caption,
		Color = Theme.Palette.milkDark,
		MaxSize = 14,
		Small = true,
		Outline = false,
	})
	local details = Kit.gem(panel, "Details", "DETAILS", "aqua", UDim2.fromScale(0.22, 0.1), UDim2.fromScale(0.6, 0.85))
	local button = buyButton(panel, state.Price, UDim2.fromScale(0.3, 0.14), UDim2.fromScale(0.85, 0.85))
	self.Buy = button
	self.Nav.SetFirst(button)
	local offset = serverNow - workspace:GetServerTimeNow()
	local function render(current)
		state = current.DailyGlassy
		if state.Available then
			setBuy(button, "buy", state.Price)
		elseif state.BoughtToday then
			setBuy(
				button,
				"wait",
				state.Price,
				Screens.duration(state.NextReset - (workspace:GetServerTimeNow() + offset))
			)
		else
			setBuy(button, "soon", state.Price)
		end
	end
	render(view)
	self.Render = render
	self.Ticker = task.spawn(function()
		while not self.Closed do
			task.wait(1)
			if state.BoughtToday then
				render({ DailyGlassy = state })
			end
		end
	end)
	self:Connect(button.Activated, function()
		if button.Active then
			buy("DailyGlassy", button)
		end
	end)
	self:Connect(details.Activated, function()
		Screens.oddsDetails(rows)
	end)
	return self
end

-- Every glassy and its exact chance (the "Details" list the paid random items policy asks for).
function Screens.oddsDetails(rows)
	local self = popup("DailyGlassyOdds", "ALL ODDS", "aqua", 1.3, 0.52)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name, scroll.BackgroundTransparency, scroll.BorderSizePixel = "List", 1, 0
	scroll.Position, scroll.Size = UDim2.fromScale(0.05, 0.14), UDim2.fromScale(0.9, 0.76)
	Kit.label(self.Panel, "Rounded", Screens.ROUNDED_NOTE, UDim2.fromScale(0.9, 0.05), UDim2.fromScale(0.05, 0.915), {
		Font = Theme.Fonts.Caption,
		Color = Theme.Palette.milkDark,
		MaxSize = 16,
		Small = true,
		Outline = false,
	})
	scroll.ScrollBarThickness, scroll.AutomaticCanvasSize = 6, Enum.AutomaticSize.Y
	scroll.CanvasSize, scroll.Parent = UDim2.new(), self.Panel
	local layout = Instance.new("UIGridLayout")
	layout.CellSize, layout.CellPadding = UDim2.new(0.31, 0, 0, 0), UDim2.new(0.02, 0, 0, 6)
	layout.SortOrder, layout.Parent = Enum.SortOrder.LayoutOrder, scroll
	local function fit()
		layout.CellSize = UDim2.new(0.31, 0, 0, math.max(56, math.floor(scroll.AbsoluteSize.X * 0.31 * 0.42)))
	end
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	local order = 0
	for i = #rows, 1, -1 do
		local row = rows[i]
		for _, id in row.Pool do
			order += 1
			local cell = Kit.icon(scroll, "Cell" .. order, "panel/odds_row_" .. CARD[row.Rarity], UDim2.new())
			cell.UIAspectRatioConstraint:Destroy()
			cell.ScaleType, cell.LayoutOrder = Enum.ScaleType.Stretch, order
			local picture = safe(
				Presentation.portrait,
				cell,
				"Glassies",
				id,
				UDim2.fromScale(0.3, 0.9),
				UDim2.fromScale(0.02, 0.05),
				"Picture"
			)
			if picture and picture:IsA("GuiObject") then
				picture.ZIndex = 3
			end
			Kit.label(cell, "Name", Glassies.get(id).Name, UDim2.fromScale(0.64, 0.45), UDim2.fromScale(0.34, 0.06), {
				XAlign = Enum.TextXAlignment.Left,
				MaxSize = 20,
				Small = true,
			})
			Kit.label(
				cell,
				"Chance",
				Screens.percent(row.Chance / #row.Pool),
				UDim2.fromScale(0.64, 0.42),
				UDim2.fromScale(0.34, 0.52),
				{ XAlign = Enum.TextXAlignment.Left, MaxSize = 20, Small = true, Color = RARITY_TEXT[row.Rarity] }
			)
		end
	end
	return self
end

----------------------------------------------------------------------------------------------------------------------
-- Need Marbles: how many more, and the cheapest offer that covers it with one BUY. `more` (nil in a match) opens the
-- Marble page instead.
function Screens.needMarbles(shortfall, suggestion, buy, more, close)
	local self = popup("NeedMarblesScreen", "NEED MARBLES", "sapphire", 1.45, 0.5, close)
	local panel = self.Panel
	local line = Kit.marbleLine(panel, "Shortfall", UDim2.fromScale(0.8, 0.12), UDim2.fromScale(0.1, 0.13))
	line:Set("{M}" .. shortfall .. " more", Theme.Palette.rubyLight)
	local card = Kit.icon(panel, "Offer", "card/card_rare", UDim2.fromScale(0.36, 0.52), UDim2.fromScale(0.5, 0.53))
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	self.Card = card
	local function fill(s)
		for _, child in card:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		if not s then
			Kit.label(card, "None", "SOON", UDim2.fromScale(0.8, 0.2), UDim2.fromScale(0.1, 0.4))
			return
		end
		-- Same pile as the pack's own card (its Art step); Daily Marbles uses the Marbles page's step 3.
		local step = 3
		for _, pack in require(RS.Shared.Config.MarbleShop).Packs do
			if s.Kind == "Pack" and pack.Id == s.Id then
				step = math.max(2, pack.Art)
			end
		end
		Screens.pile(card, step, UDim2.fromScale(0.8, 0.55), UDim2.fromScale(0.5, 0.42)).ZIndex = 3
		Kit.label(card, "Amount", "x" .. s.Marbles, UDim2.fromScale(0.86, 0.16), UDim2.fromScale(0.07, 0.74), {
			MaxSize = 30,
		}).ZIndex =
			4
		if s.Kind == "DailyMarbles" then
			local tag = Kit.tag(card, "Daily", "TODAY", "amber", UDim2.fromScale(0.6, 0.12), UDim2.fromScale(0.2, 0.04))
			tag.ZIndex = 5
		end
	end
	fill(suggestion)
	local button = buyButton(
		panel,
		suggestion and suggestion.Price or 0,
		UDim2.fromScale(0.36, 0.14),
		UDim2.fromScale(if more then 0.7 else 0.5, 0.88)
	)
	self.Buy = button
	if not suggestion then
		setBuy(button, "soon", 0)
	end
	self.Nav.SetFirst(button)
	self:Connect(button.Activated, function()
		if button.Active and suggestion then
			buy(suggestion, button)
		end
	end)
	if more then
		local packs = Kit.gem(panel, "More", "MORE", "sapphire", UDim2.fromScale(0.3, 0.12), UDim2.fromScale(0.3, 0.88))
		self:Connect(packs.Activated, function()
			self:Close()
			more()
		end)
	end
	return self
end

return Screens
