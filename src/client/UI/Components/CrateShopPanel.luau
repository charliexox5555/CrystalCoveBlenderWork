local U = require(script.Parent.Util)
local Button = require(script.Parent.GemButton)
local Theme = require(script.Parent.Parent.Theme)
local Item = require(script.Parent.ItemPresentation)
local Carousel = require(script.Parent.PrizeCarousel)
local S = require(script.Parent.StainedGlass)
local Panel = {}
Panel.__index = Panel
local titles = { Glassies = "Kiln", Finishers = "Burst Capsule", Rideables = "Sky Capsule" }
-- An OPEN label shorter than this (px) can't fit two readable lines (phones): "OPEN 1 · 300" on one line instead.
-- The pane header already names the currency.
local TWO_LINES = 28
local function setOpenText(button, text, short)
	button:SetAttribute("OpenText", text)
	button:SetAttribute("OpenShort", short)
	local label = button:FindFirstChild("Label") or button
	local height = label.AbsoluteSize.Y
	S.buttonText(button, if height > 0 and height < TWO_LINES then short else text)
end
function Panel.new(parent, category, offers, callbacks)
	local self =
		setmetatable({ Category = category, Offers = offers, Panels = {}, Carousels = {}, Connections = {} }, Panel)
	local root = U.make("ScrollingFrame", parent, {
		Name = "CrateShop",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	})
	self.Root = root
	root.Visible = true
	for _, name in { "CoinsCrate", "MarblesCrate" } do
		local pane = root:FindFirstChild(name)
		if pane then
			pane.Visible = false
		end
	end
	for _, currency in { "Coins", "Marbles" } do
		local offer = offers and offers[currency]
		if not offer then
			continue
		end
		local color = if currency == "Coins" then Theme.Palette.amber else Theme.Palette.sapphireLight
		local pane = U.make("Frame", root, {
			Name = currency .. "Crate",
			BackgroundColor3 = Theme.Colors.Inset,
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
		})
		U.make("UIStroke", pane, { Color = color, Thickness = 2, Transparency = 0.15 })
		pane.Visible = true
		U.text(
			pane,
			"Title",
			string.upper(currency) .. " · " .. string.upper(titles[category]),
			UDim2.fromScale(0.94, 0.07),
			UDim2.fromScale(0.03, 0.02),
			Theme.Fonts.Heading
		)
		-- Reused template objects keep their authored layout, so set the geometry explicitly.
		local crate = Item.crate(
			pane,
			category,
			currency,
			UDim2.fromScale(0.41, 0.3),
			UDim2.fromScale(0.025, 0.105),
			nil,
			nil,
			true
		)
		crate.Size, crate.Position = UDim2.fromScale(0.41, 0.3), UDim2.fromScale(0.025, 0.105)
		local odds = U.make("Frame", pane, {
			Name = "Odds",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.53, 0.3),
			Position = UDim2.fromScale(0.45, 0.105),
		})
		odds.Size, odds.Position = UDim2.fromScale(0.53, 0.3), UDim2.fromScale(0.45, 0.105)
		local totals = {}
		for _, entry in offer.Odds do
			totals[entry.Rarity] = (totals[entry.Rarity] or 0) + entry.Chance
		end
		local row = 0
		for _, rarity in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } do
			if not totals[rarity] then
				continue
			end
			local label = U.text(
				odds,
				rarity,
				rarity,
				UDim2.fromScale(0.59, 0.145),
				UDim2.fromScale(0, row * 0.16),
				Theme.Fonts.Heading
			)
			label.TextColor3, label.TextXAlignment = Theme.Rarity[rarity].Top, Enum.TextXAlignment.Left
			local chance = U.text(
				odds,
				rarity .. "Chance",
				string.format("%.3g%%", totals[rarity] * 100),
				UDim2.fromScale(0.4, 0.145),
				UDim2.fromScale(0.6, row * 0.16),
				Theme.Fonts.Caption
			)
			chance.TextXAlignment = Enum.TextXAlignment.Right
			row += 1
		end
		local previewTitle = U.text(
			pane,
			"PreviewTitle",
			"PRIZE PREVIEW",
			UDim2.fromScale(0.6, 0.055),
			UDim2.fromScale(0.025, 0.42),
			Theme.Fonts.Heading
		)
		previewTitle.Size, previewTitle.Position = UDim2.fromScale(0.6, 0.055), UDim2.fromScale(0.025, 0.42)
		local view = Button.new(
			pane,
			"ViewAll",
			"VIEW ALL  ›",
			"Blue",
			UDim2.fromScale(0.31, 0.065),
			UDim2.fromScale(0.665, 0.415)
		)
		view.AnchorPoint, view.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.82, 0.4475)
		table.insert(
			self.Connections,
			view.Activated:Connect(function()
				callbacks.ViewAll(category, currency)
			end)
		)
		local strip = U.make("Frame", pane, {
			Name = "Prizes",
			Size = UDim2.fromScale(0.95, 0.3),
			Position = UDim2.fromScale(0.025, 0.485),
			BackgroundTransparency = 1,
		})
		strip.Size, strip.Position = UDim2.fromScale(0.95, 0.3), UDim2.fromScale(0.025, 0.485)
		table.insert(
			self.Carousels,
			Carousel.new(strip, category, offer.Odds, function(entry)
				callbacks.Inspect(category, currency, entry)
			end)
		)
		local buttons = {}
		for i, count in { 1, 10 } do
			local cost = if count == 1 then offer.Cost else offer.TenCost
			local b = Button.new(
				pane,
				"Open" .. count,
				"OPEN " .. count .. "\n" .. cost .. " " .. string.upper(currency),
				if currency == "Coins" then "Yellow" else "Blue",
				UDim2.fromScale(0.455, 0.17),
				UDim2.fromScale(0.025 + (i - 1) * 0.495, 0.8)
			)
			U.make("UISizeConstraint", b, { MinSize = Vector2.new(44, 44) })
			setOpenText(
				b,
				"OPEN " .. count .. "\n" .. cost .. " " .. string.upper(currency),
				"OPEN " .. count .. " · " .. cost
			)
			table.insert(
				self.Connections,
				b:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
					local text, short = b:GetAttribute("OpenText"), b:GetAttribute("OpenShort")
					if text and short then
						setOpenText(b, text, short)
					end
				end)
			)
			table.insert(
				self.Connections,
				b.Activated:Connect(function()
					callbacks.Open(category, currency, count, offer)
				end)
			)
			buttons[count] = b
		end
		self.Panels[currency] = { Object = pane, Buttons = buttons }
	end
	local function layout()
		local narrow = root.AbsoluteSize.X < root.AbsoluteSize.Y * 1.15
		local both = self.Panels.Marbles ~= nil
		root.ScrollingEnabled = narrow and both
		if narrow and both then
			local height = math.max(360, root.AbsoluteSize.X * 0.94)
			root.CanvasSize = UDim2.fromOffset(0, height * 2 + 20)
			self.Panels.Coins.Object.Size = UDim2.new(1, -8, 0, height)
			self.Panels.Coins.Object.Position = UDim2.fromOffset(2, 2)
			self.Panels.Marbles.Object.Size = UDim2.new(1, -8, 0, height)
			self.Panels.Marbles.Object.Position = UDim2.fromOffset(2, height + 14)
		else
			root.CanvasSize = UDim2.new()
			for currency, pane in self.Panels do
				pane.Object.Size = UDim2.fromScale(if both then 0.485 else 0.99, 0.985)
				pane.Object.Position = UDim2.fromScale(if currency == "Marbles" then 0.512 else 0.003, 0.005)
			end
		end
	end
	table.insert(self.Connections, root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout))
	layout()
	return self
end
-- frees: free single Coin pulls per category (welcome pull + reward tickets, decision 99).
function Panel:Wallet(data, frees, welcome)
	for currency, pane in self.Panels do
		for count, button in pane.Buttons do
			local offer = self.Offers[currency]
			local free = currency == "Coins" and count == 1 and ((frees or {})[self.Category] or 0) > 0
			local cost = if free then 0 elseif count == 1 then offer.Cost else offer.TenCost
			local text = if free
					and self.Category == "Glassies"
					and (welcome or 0) > 0
				then "WELCOME · FREE"
				elseif free then "OPEN 1\nFREE"
				else "OPEN " .. count .. "\n" .. cost .. " " .. string.upper(currency)
			local short = if free
					and self.Category == "Glassies"
					and (welcome or 0) > 0
				then "WELCOME · FREE"
				elseif free then "OPEN 1 · FREE"
				else "OPEN " .. count .. " · " .. cost
			setOpenText(button, text, short)
			local label = button:FindFirstChild("Label") or button
			label.TextTransparency = if (data[currency] or 0) >= cost then 0 else 0.28
			button.Active, button.Selectable = true, true
		end
	end
end
function Panel:Step(dt)
	if not self.Root.Parent or not self.Root.Parent.Visible then
		return
	end
	for _, carousel in self.Carousels do
		carousel:Step(dt)
	end
end
function Panel:Destroy()
	for _, c in self.Connections do
		c:Disconnect()
	end
	for _, carousel in self.Carousels do
		carousel:Destroy()
	end
	self.Root:Destroy()
end
return Panel
