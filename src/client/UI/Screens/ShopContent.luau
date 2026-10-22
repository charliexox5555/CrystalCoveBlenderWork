-- Same quoted crate structure for Glassies, Finishers and Flyers.
local S = require(script.Parent.Parent.Components.StainedGlass)
local U = require(script.Parent.Parent.Components.Util)
local Theme = require(script.Parent.Parent.Theme)
local Pools = require(script.Parent.ShopPools)
local CratePanel = require(script.Parent.Parent.Components.CrateShopPanel)
local FeaturedOffers = require(script.Parent.Parent.Components.FeaturedOffers)
local MarbleShop = require(script.Parent.Parent.Components.MarbleShop)
local Shop = {}
local lastPullAt = -math.huge
local pullRate = require(game.ReplicatedStorage.Shared.Config.Balance).Data.KilnRateSeconds
local tabs = { Featured = "amber", Glassies = "aqua", Finishers = "amethyst", Flyers = "ruby", Marbles = "aqua" }
-- The Marbles tab reuses the aqua tab art, tinted toward sapphire.
local MARBLE_TINT = Color3.fromRGB(150, 175, 255)
local categories = { Glassies = "Glassies", Finishers = "Finishers", Flyers = "Rideables" }
function Shop.select(self, name)
	if not tabs[name] then
		return
	end
	self.Tab, self.PoolKind = name, nil
	local p, c = self.Window.Panel, self.Window.Content
	for tab, tint in tabs do
		c[tab .. "Page"].Visible = tab == name
		S.setAsset(p.Tabs[tab .. "Tab"].Artwork, "tab/tab_" .. tint .. (if tab == name then "_active" else "_idle"))
	end
	p.Tabs.MarblesTab.Artwork.ImageColor3 = MARBLE_TINT
	c.PoolPage.Visible = false
	self.Message.Text = if name == "Featured" or name == "Marbles"
		then ""
		elseif
			self.Data.PaidRandomAllowed == true
		then "Same items in both crates · Marbles improve high-rarity odds · duplicates add copies"
		else "Open with Coins · duplicates add copies"
	self.Window.Gui:SetAttribute("ShopTab", name)
end
-- Fifth tab + page for Marble packs, cloned from the authored Flyers tab and Featured page.
function Shop.addMarblesTab(panel, content)
	local row = panel.Tabs
	if not row:FindFirstChild("MarblesTab") then
		local tab = row.FlyersTab:Clone()
		tab.Name, tab.Label.Text = "MarblesTab", "Marbles"
		local order = 0
		for _, child in row:GetChildren() do
			if child:IsA("GuiObject") then
				order = math.max(order, child.LayoutOrder)
			end
		end
		tab.LayoutOrder = order + 1
		tab.Parent = row
		row.Size = UDim2.new(0.585, 0, row.Size.Y.Scale, row.Size.Y.Offset)
		for _, child in row:GetChildren() do
			if child:IsA("GuiButton") then
				child.Size = UDim2.new(0.18, 0, child.Size.Y.Scale, child.Size.Y.Offset)
			end
		end
	end
	if not content:FindFirstChild("MarblesPage") then
		local page = Instance.new("Frame")
		page.Name, page.BackgroundTransparency = "MarblesPage", 1
		page.Position, page.Size = content.FeaturedPage.Position, content.FeaturedPage.Size
		page.Visible, page.Parent = false, content
	end
end

function Shop.deals()
	local ok, controller = pcall(require, script.Parent.Parent.Parent.Controllers.DealsController)
	return if ok then controller else nil
end

-- Starter Pack tile on the right side of the open Shop (decision 116), like the HUD tile; gone once bought or over.
function Shop.starterSide(self)
	local deals = Shop.deals()
	local panel = self.Window and self.Window.Panel
	if not deals or not panel then
		return
	end
	local Kit = require(script.Parent.Parent.Components.MatchKit)
	local Presentation = require(script.Parent.Parent.Components.ItemPresentation)
	local side = Instance.new("ImageButton")
	side.Name, side.BackgroundTransparency, side.Image = "StarterSide", 1, ""
	side.AnchorPoint, side.Position, side.Size =
		Vector2.new(0, 0.5), UDim2.fromScale(1.005, 0.56), UDim2.fromScale(0.15, 0.36)
	side.ZIndex, side.Visible, side.Parent = 8, false, panel
	S.aspect(side, 0.72)
	local art = Kit.icon(side, "Artwork", "card/card_legendary", UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5))
	art.AnchorPoint, art.ZIndex = Vector2.new(0.5, 0.5), 8
	art.UIAspectRatioConstraint:Destroy()
	local title = Kit.label(side, "Title", "STARTER", UDim2.fromScale(0.84, 0.12), UDim2.fromScale(0.08, 0.05), {
		Color = Theme.Palette.amberLight,
		MaxSize = 24,
	})
	title.ZIndex = 10
	local price = Kit.gem(
		side,
		"Price",
		utf8.char(0xE002) .. " 49",
		"emerald",
		UDim2.fromScale(0.9, 0.2),
		UDim2.fromScale(0.5, 0.86)
	)
	price.ZIndex, price.Active = 10, false
	for _, part in price:GetDescendants() do
		if part:IsA("GuiObject") then
			part.ZIndex = 10
		end
	end
	local timer = Kit.label(side, "Timer", "", UDim2.fromScale(0.84, 0.09), UDim2.fromScale(0.08, 0.66), {
		Color = Theme.Palette.milkLight,
		MaxSize = 18,
		Small = true,
	})
	timer.ZIndex = 10
	require(script.Parent.Parent.Components.Motion).button(side)
	-- Room beside the window: where the window fills the screen, it shrinks a little (keeping its left edge) so the
	-- tile sits next to it instead of over the content. Phones skip the side tile (the HUD tile stays in the lobby).
	local responsive = (function()
		local ok, controller = pcall(require, script.Parent.Parent.Parent.Controllers.ResponsiveController)
		return if ok then controller else nil
	end)()
	local compact = responsive ~= nil and responsive.Class ~= nil and responsive:Class() == "Compact"
	local placed
	local function makeRoom()
		local gui = self.Window.Gui
		if not side.Visible or not gui or placed == panel.Size then
			return
		end
		local area, origin = gui.AbsoluteSize, gui.AbsolutePosition
		local left = panel.AbsolutePosition.X - origin.X
		local w, h, tile = panel.AbsoluteSize.X, panel.AbsoluteSize.Y, side.AbsoluteSize.X
		-- TV: stay inside the same 88% safe width ResponsiveController keeps windows in (ui-audit, Xbox).
		local limit = if game:GetService("GuiService"):IsTenFootInterface() then area.X * 0.93 else area.X - 12
		if w < 2 or left + w + tile <= limit then
			return
		end
		local f = math.clamp((limit - left) / (w + tile), 0.6, 1)
		local y = panel.Position.Y
		placed = UDim2.fromOffset(math.floor(w * f), math.floor(h * f))
		panel.Size = placed
		panel.Position = UDim2.new(0, math.floor(left + w * f / 2), y.Scale, y.Offset)
	end
	table.insert(
		self.Window.Connections,
		panel:GetPropertyChangedSignal("Size"):Connect(function()
			task.defer(makeRoom)
		end)
	)
	local function clamp()
		task.defer(makeRoom)
	end
	table.insert(
		self.Window.Connections,
		side.Activated:Connect(function()
			deals:OpenStarter()
		end)
	)
	local unwatch = deals:Watch(function(view)
		local state = view.Starter
		side.Visible = side.Parent ~= nil and state.Visible and not compact
		if state.Visible and not side:FindFirstChild("Picture") then
			for _, item in state.Items or {} do
				if item.Category == "Glassies" then
					local ok, picture = pcall(
						Presentation.portrait,
						side,
						"Glassies",
						item.Id,
						UDim2.fromScale(0.76, 0.46),
						UDim2.fromScale(0.12, 0.17),
						"Picture"
					)
					if ok and typeof(picture) == "Instance" and picture:IsA("GuiObject") then
						picture.ZIndex = 9
					end
				end
			end
		end
		local ends = state.EndsAt
		timer.Text = if ends then require(script.Parent.DealScreens).duration(ends - deals:Now()) else ""
		task.defer(clamp)
	end)
	table.insert(self.Window.Connections, { Disconnect = unwatch })
end

function Shop.showPool(self, currency, category)
	category = category or categories[self.Tab] or "Glassies"
	local tab = if category == "Rideables" then "Flyers" else category
	Shop.select(self, tab)
	self.PoolKind, self.PoolCategory = currency, category
	local c = self.Window.Content
	c[tab .. "Page"].Visible = false
	c.PoolPage.Visible = true
	c.PoolPage.Title.Text = string.upper(currency .. " · " .. tab .. " · EXACT ITEM ODDS")
	Pools.grid(self, c.PoolPage.Grid, currency, category)
end
function Shop.bind(self, data)
	local pg = game.Players.LocalPlayer.PlayerGui
	local tab = pg:GetAttribute(MarbleShop.TabRequest) or self.Tab or "Featured"
	pg:SetAttribute(MarbleShop.TabRequest, nil)
	local c = self:Page("KilnScreen", "SHOP")
	Shop.addMarblesTab(self.Window.Panel, c)
	self.Data, self.Busy, self.PoolConnections = data, false, {}
	self.Message = c.Message
	self.CrateViews = {}
	local legacy = { Glassies = { Coins = { Odds = data.Odds or {}, Cost = data.Cost, TenCost = data.TenCost } } }
	local crates = data.Crates or legacy
	local callbacks = {
		ViewAll = function(category, currency)
			Shop.showPool(self, currency, category)
		end,
		Inspect = function(category, currency, entry)
			local def = require(script.Parent.Parent.Components.ItemPresentation).definition(category, entry.Id)
			self.Message.Text = def.Name
				.. " · "
				.. string.format("%.4g%%", entry.Chance * 100)
				.. " per "
				.. currency
				.. " opening"
		end,
		Open = function(category, currency, count, offer)
			if self.Busy then
				return
			end
			if os.clock() - lastPullAt < pullRate then
				self.Message.Text = "One moment…"
				return
			end
			local frees = data.Free or { Glassies = data.Welcome }
			local free = currency == "Coins" and count == 1 and (frees[category] or 0) > 0
			local cost = if free then 0 elseif count == 10 then offer.TenCost else offer.Cost
			if #offer.Odds == 0 then
				self.Message.Text = "This crate is warming up"
				return
			end
			if (self.Data[currency] or 0) < cost then
				local short = cost - (self.Data[currency] or 0)
				self.Message.Text = "Need " .. short .. " more " .. string.lower(currency)
				if currency == "Marbles" then
					-- Need Marbles (decision 116): one-tap buy of the cheapest offer that covers it; MORE opens the page.
					self.Window.Gui:SetAttribute("MarbleStoreRequested", true)
					local deals = Shop.deals()
					if deals then
						deals:NeedMarbles(short, function()
							Shop.select(self, "Marbles")
						end)
					else
						Shop.select(self, "Marbles")
					end
				end
				return
			end
			lastPullAt = os.clock()
			self.Busy = true
			self.PendingCategory = category
			self.PendingCurrency = currency
			self.SelectedPoolOdds = offer.Odds
			self:Pending(category)
			self.Pull(count, data.Quote, category, currency)
		end,
	}
	for tabName, category in categories do
		local page = c[tabName .. "Page"]
		for _, child in page:GetChildren() do
			if child:IsA("GuiObject") then
				child.Visible = false
			end
		end
		if crates[category] then
			self.CrateViews[category] = CratePanel.new(page, category, crates[category], callbacks)
		end
	end
	-- Daily offers + featured bundle; stepped and destroyed with the crate panels.
	self.CrateViews.Featured = FeaturedOffers.new(c.FeaturedPage, self.Message)
	self.CrateViews.Marbles = MarbleShop.page(c.MarblesPage, function(text)
		self.Message.Text = text
	end)
	MarbleShop.attachPlus(self.Window.Panel:FindFirstChild("Marbles"))
	Shop.starterSide(self)
	-- A "+" (here or on the HUD) while the shop is open switches to the Marbles page.
	table.insert(
		self.Window.Connections,
		pg:GetAttributeChangedSignal(MarbleShop.TabRequest):Connect(function()
			local requested = pg:GetAttribute(MarbleShop.TabRequest)
			if requested then
				pg:SetAttribute(MarbleShop.TabRequest, nil)
				Shop.select(self, requested)
			end
		end)
	)
	self.UpdateProfile = function(_, profile)
		if not profile then
			return
		end
		self.Profile = profile
		if self.CrateViews and self.CrateViews.Featured then
			self.CrateViews.Featured.Profile = profile
		end
		self.Data.Coins, self.Data.Marbles = profile.Coins, profile.Marbles or 0
		local p = self.Window.Panel
		if p:FindFirstChild("Coins") then
			p.Coins.CoinsAmount.Text, p.Marbles.MarblesAmount.Text =
				U.commas(profile.Coins), U.commas(profile.Marbles or 0)
		end
		for _, view in self.CrateViews or {} do
			view:Wallet(self.Data, self.Data.Free or { Glassies = self.Data.Welcome }, self.Data.Welcome)
		end
	end
	self:UpdateProfile(self.Profile or data)
	self.SelectTab = function(_, name)
		Shop.select(self, name)
	end
	self.ShowPool = function(_, kind)
		Shop.showPool(self, kind)
	end
	for name in tabs do
		self.Window:Connect(self.Window.Panel.Tabs[name .. "Tab"], function()
			Shop.select(self, name)
		end)
	end
	self.Window:Connect(c.PoolPage.Back, function()
		Shop.select(self, if self.PoolCategory == "Rideables" then "Flyers" else self.PoolCategory or "Glassies")
	end)
	Shop.select(self, tab)
	if data.Error then
		self.Message.Text = data.Error
	end
end
return Shop
