-- Same quoted crate structure for Glassies, Finishers and Flyers.
local S = require(script.Parent.Parent.Components.StainedGlass)
local Pools = require(script.Parent.ShopPools)
local CratePanel = require(script.Parent.Parent.Components.CrateShopPanel)
local FeaturedOffers = require(script.Parent.Parent.Components.FeaturedOffers)
local Shop = {}
local lastPullAt = -math.huge
local pullRate = require(game.ReplicatedStorage.Shared.Config.Balance).Data.KilnRateSeconds
local tabs = { Featured = "amber", Glassies = "aqua", Finishers = "amethyst", Flyers = "ruby" }
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
	c.PoolPage.Visible = false
	self.Message.Text = if name == "Featured"
		then ""
		elseif
			self.Data.PaidRandomAllowed == true
		then "Same items in both crates · Marbles improve high-rarity odds · duplicates add copies"
		else "Open with Coins · duplicates add copies"
	self.Window.Gui:SetAttribute("ShopTab", name)
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
	local tab = self.Tab or "Featured"
	local c = self:Page("KilnScreen", "SHOP")
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
			local free = category == "Glassies" and currency == "Coins" and count == 1 and (data.Welcome or 0) > 0
			local cost = if free then 0 elseif count == 10 then offer.TenCost else offer.Cost
			if #offer.Odds == 0 then
				self.Message.Text = "This crate is warming up"
				return
			end
			if (self.Data[currency] or 0) < cost then
				self.Message.Text = "Need " .. (cost - (self.Data[currency] or 0)) .. " more " .. string.lower(currency)
				if currency == "Marbles" then
					self.Window.Gui:SetAttribute("MarbleStoreRequested", true)
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
				tostring(profile.Coins), tostring(profile.Marbles or 0)
		end
		for _, view in self.CrateViews or {} do
			view:Wallet(self.Data, self.Data.Welcome)
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
