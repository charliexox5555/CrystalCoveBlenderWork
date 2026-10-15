-- UI binding only. Coin pulls keep the existing quote flow; new offerings are visual previews.
local RS = game:GetService("ReplicatedStorage")
local Glassies = require(RS.Shared.Config.Glassies)
local Balance = require(RS.Shared.Config.Balance)
local S = require(script.Parent.Parent.Components.StainedGlass)
local Pools = require(script.Parent.ShopPools)
local Shop = {}
local TABS = { Featured = "amber", Glassies = "aqua", Finishers = "amethyst", Flyers = "ruby" }

function Shop.select(self, name)
	if not TABS[name] then
		return
	end
	self.Tab, self.PoolKind = name, nil
	local p, c = self.Window.Panel, self.Window.Content
	for tab, tint in TABS do
		c[tab .. "Page"].Visible = tab == name
		S.setAsset(p.Tabs[tab .. "Tab"].Artwork, "tab/tab_" .. tint .. (tab == name and "_active" or "_idle"))
	end
	c.PoolPage.Visible = false
	self.Message.Text = if name == "Glassies" then "Coin Kiln is open · Marble Kiln coming soon" else ""
	self.Window.Gui:SetAttribute("ShopTab", name)
end

function Shop.showPool(self, kind)
	Shop.select(self, "Glassies")
	self.PoolKind = kind
	local c = self.Window.Content
	c.GlassiesPage.Visible, c.PoolPage.Visible = false, true
	c.PoolPage.Title.Text = if kind == "Coins" then "COIN KILN · ALL GLASSIES" else "MARBLE KILN · SAMPLE PREVIEW"
	Pools.grid(self, c.PoolPage.Grid, kind)
	if kind == "Marbles" then
		self.Message.Text = "Marble Kiln coming soon · sample glassies only"
	end
end

function Shop.bind(self, data)
	local tab = self.Tab or "Featured"
	local c = self:Page("KilnScreen", "SHOP")
	self.Data, self.Busy, self.PoolConnections = data, false, {}
	local p = self.Window.Panel
	p.Coins.CoinsAmount.Text, p.Marbles.MarblesAmount.Text = tostring(data.Coins), tostring(data.Marbles or 0)
	self.Message = c.Message
	self.SelectTab = function(_, name)
		Shop.select(self, name)
	end
	self.ShowPool = function(_, kind)
		Shop.showPool(self, kind)
	end
	for name in TABS do
		self.Window:Connect(p.Tabs[name .. "Tab"], function()
			Shop.select(self, name)
		end)
	end
	self.Window:Connect(c.FeaturedPage.Showcase.Explore, function()
		Shop.select(self, "Glassies")
	end)
	self.Window:Connect(c.PoolPage.Back, function()
		Shop.select(self, "Glassies")
	end)
	local coin, marble = c.GlassiesPage.CoinKiln, c.GlassiesPage.MarbleKiln
	coin.OddsPane.RainbowOdds.Text = string.format("Rainbow: %.2f%%", Balance.Growth.RainbowChance * 100)
	local totals = {}
	for _, odds in data.Odds do
		local rarity = Glassies.get(odds.Id).Rarity
		totals[rarity] = (totals[rarity] or 0) + odds.Chance
	end
	for _, rarity in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } do
		coin.OddsPane.RarityRows[rarity].Chance.Text = string.format("%.4g%%", (totals[rarity] or 0) * 100)
		marble.OddsPane.RarityRows[rarity].Chance.Text = "—"
	end
	Pools.strip(self, coin.Pool, "Coins")
	Pools.strip(self, marble.Pool, "Marbles")
	self.Window:Connect(coin.ViewAll, function()
		Shop.showPool(self, "Coins")
	end)
	self.Window:Connect(marble.ViewAll, function()
		Shop.showPool(self, "Marbles")
	end)
	for _, count in { 1, 10 } do
		local free = count == 1 and data.Welcome > 0
		local cost = if free then 0 elseif count == 1 then data.Cost else data.TenCost
		local b = coin["Pull" .. count]
		S.buttonText(b, if free then "WELCOME · FREE" else "OPEN " .. count .. " · " .. cost)
		local enabled = #data.Odds > 0 and data.Coins >= cost
		b.Active, b.Selectable, b.Label.TextTransparency = true, true, if enabled then 0 else 0.45
		self.Window:Connect(b, function()
			if self.Busy then
				return
			end
			if not enabled then
				self.Message.Text = if #data.Odds == 0
					then "The Kiln is warming up"
					else "Need " .. math.max(0, cost - data.Coins) .. " more coins · play clashes and quests"
				return
			end
			self.Busy = true
			S.buttonText(b, "BLOWING...")
			self.Pull(count, data.Quote)
		end)
	end
	-- No prices, odds, purchases or new remotes are invented for the Marble/daily previews.
	for _, count in { 1, 10 } do
		local b = marble["Pull" .. count]
		b.Active, b.Selectable = false, false
	end
	Shop.select(self, tab)
end
return Shop
