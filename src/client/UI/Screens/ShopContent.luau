-- Bind the editable shop shell to the server's single-use odds quote.
local RS = game:GetService("ReplicatedStorage")
local Glassies = require(RS.Shared.Config.Glassies)
local Balance = require(RS.Shared.Config.Balance)
local Portrait = require(script.Parent.Parent.Components.GlassyPortrait)
local S = require(script.Parent.Parent.Components.StainedGlass)
local Shop = {}
function Shop.bind(self, data)
	local c = self:Page("KilnScreen", "SHOP")
	self.Data, self.Busy = data, false
	local p = self.Window.Panel
	p.Coins.CoinsAmount.Text = tostring(data.Coins)
	p.Marbles.MarblesAmount.Text = tostring(data.Marbles or 0)
	local totals = {}
	for _, odds in data.Odds do
		local r = Glassies.get(odds.Id).Rarity
		totals[r] = (totals[r] or 0) + odds.Chance
	end
	for _, r in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } do
		local row = c.OddsPane.RarityRows[r]
		row.Chance.Text = string.format("%.4g%%", (totals[r] or 0) * 100)
	end
	c.OddsPane.RainbowOdds.Text = string.format("Rainbow variant: %.2f%%", Balance.Growth.RainbowChance * 100)
	c.OddsPane.PoolOdds.Text =
		string.format("%d glassies available · rarity chance ÷ glassies in that rarity", #data.Odds)
	for _, child in c.Pool:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	-- The strip scrolls through the real installed pool, never advertises unavailable art.
	self.PoolIds = {}
	local canvas = math.max(1, #data.Odds * 0.195)
	c.Pool.CanvasSize = UDim2.fromScale(canvas, 0)
	c.Pool.UIListLayout.Padding = UDim.new(0.025 / canvas, 0)
	for i, odds in data.Odds do
		table.insert(self.PoolIds, odds.Id)
		do
			local tile = c.Pool.Templates.GlassyTile:Clone()
			local d = Glassies.get(odds.Id)
			tile.Name, tile.Visible, tile.LayoutOrder, tile.Parent = d.Id, true, i, c.Pool
			tile.Size = UDim2.fromScale(0.17 / canvas, 1)
			S.setAsset(tile.Artwork, "tile/tile_" .. S.rarity(d.Rarity))
			tile:FindFirstChild("Name").Text = d.Name
			local chance = string.format("%.4g%%", odds.Chance * 100)
			tile:SetAttribute("ExactChance", odds.Chance)
			Portrait.new(tile, d.Id, tile.Portrait.Size, tile.Portrait.Position)
			S.bindSlices(tile)
			-- Selecting a pool tile shows its exact per-glassy chance beside the pull buttons.
			self.Window:Connect(tile.Open, function()
				c.Message.Text = d.Name .. " · " .. chance .. " per pull"
			end)
		end
	end
	self.Message = c.Message
	self.Message.Text = if #data.Odds == 0 then "The Kiln is warming up. Your coins are safe." else ""
	for _, name in { "FlyersTab", "FinishersTab", "MarblesTab" } do
		local tab = p.Tabs[name]
		tab.Active, tab.Selectable = true, true
		self.Window:Connect(tab, function()
			self.Message.Text = (
				if name == "FlyersTab" then "Flyers" elseif name == "FinishersTab" then "Finishers" else "Marble packs"
			) .. " are coming later · The Kiln is open"
		end)
	end
	self.Window:Connect(p.Tabs.KilnTab, function()
		self.Message.Text = "Choose a glassy to see its odds, or pull from The Kiln"
	end)
	for _, count in { 1, 10 } do
		local free = count == 1 and data.Welcome > 0
		local cost = if free then 0 elseif count == 1 then data.Cost else data.TenCost
		local button = c.Hero["Pull" .. count]
		S.buttonText(button, if free then "WELCOME · FREE" else "PULL ×" .. count .. " · " .. cost)
		local enabled = #data.Odds > 0 and data.Coins >= cost
		button.Active, button.Selectable = true, true
		button.Label.TextTransparency = if enabled then 0 else 0.5
		self.Window:Connect(button, function()
			if not enabled then
				self.Message.Text = if #data.Odds == 0
					then "The Kiln is warming up"
					else "Need " .. math.max(0, cost - data.Coins) .. " more coins · play clashes and quests"
				return
			end
			if enabled and not self.Busy then
				self.Busy = true
				S.buttonText(button, "BLOWING...")
				self.Pull(count, data.Quote)
			end
		end)
	end
	local cheapest = if data.Welcome > 0 then 0 else data.Cost
	if #data.Odds > 0 and data.Coins < cheapest then
		self.Message.Text = "Need " .. (cheapest - data.Coins) .. " more coins · play clashes and quests"
	end
end
return Shop
