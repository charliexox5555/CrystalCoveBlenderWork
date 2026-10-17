-- Marbles page of the shop window: a grid of Marble packs (Config/MarbleShop) on the shared
-- ShopCard. The "+" on the HUD and shop-window Marble counters opens the shop on this page.
-- Packs are bought through StoreService (BuyMarblePack -> intent -> Robux prompt -> receipt).
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

-- Builds the pack grid inside `page`; `say` shows a status line. Returns a CrateViews-style view.
function MarbleShop.page(page, say)
	local self = setmetatable({ Page = page, Connections = {}, Cards = {} }, MarbleShop)
	local header = U.text(
		page,
		"Header",
		"MARBLE PACKS",
		UDim2.fromScale(0.5, 0.075),
		UDim2.fromScale(0.02, 0),
		Theme.Fonts.Heading
	)
	header.TextXAlignment = Enum.TextXAlignment.Left
	local note = U.text(
		page,
		"Note",
		"Marbles pay for Pick Any and other Marble items",
		UDim2.fromScale(0.46, 0.06),
		UDim2.fromScale(0.52, 0.01),
		Theme.Fonts.Caption
	)
	note.TextXAlignment, note.TextColor3 = Enum.TextXAlignment.Right, Theme.Palette.amberLight
	note.UITextSizeConstraint.MaxTextSize = Theme.TextSize.Small
	local grid = U.make("Frame", page, {
		Name = "Packs",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.02, 0.09),
		Size = UDim2.fromScale(0.96, 0.9),
	})
	U.make("UIGridLayout", grid, {
		CellSize = UDim2.fromScale(0.315, 0.47),
		CellPadding = UDim2.fromScale(0.0275, 0.05),
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
		Card.pill(card.Rarity, string.upper(pack.Name), "sapphire")
		Card.pill(
			card.Corner,
			if pack.Bonus > 0 then "+" .. pack.Bonus .. "% BONUS" else nil,
			if pack.Bonus >= 25 then "amber" else "emerald"
		)
		if pack.Available then
			Card.button(card, "robux", Card.ROBUX .. " " .. commas(pack.RobuxPrice))
		else
			Card.button(card, "soon", "COMING SOON")
		end
		table.insert(self.Cards, frame)
		table.insert(
			self.Connections,
			card.Button.Activated:Connect(function()
				if pack.Available then
					say("Opening the Robux purchase…")
					Remotes.BuyMarblePack:FireServer(pack.Id)
				else
					say("Marble packs open soon")
				end
			end)
		)
	end
	table.insert(
		self.Connections,
		Remotes.StoreResult.OnClientEvent:Connect(function(result)
			if type(result) == "table" and result.Kind == "Marbles" and type(result.Message) == "string" then
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
	return self
end

-- CrateViews interface.
function MarbleShop:Wallet() end
function MarbleShop:Step() end
function MarbleShop:Destroy()
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
	button.AnchorPoint, button.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.97, 0.5)
	button.Size, button.ZIndex = UDim2.fromScale(0.36, 1.25), (plaque.ZIndex or 1) + 3
	S.setAsset(button, "hud/hex_emerald")
	S.aspect(button, 300 / 340)
	local label =
		U.text(button, "Label", "+", UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, 0.06), Theme.Fonts.Heading)
	label.ZIndex = button.ZIndex + 1
	label.UITextSizeConstraint.MaxTextSize = 40
	U.make("UIStroke", label, { Thickness = 2, Color = Theme.Palette.lead })
	U.make("UISizeConstraint", button, { MinSize = Vector2.new(30, 30) })
	button.Parent = plaque
	Motion.button(button)
	button.Activated:Connect(function()
		Players.LocalPlayer.PlayerGui:SetAttribute(MarbleShop.TabRequest, "Marbles")
		if onOpen then
			onOpen()
		end
	end)
	return button
end

return MarbleShop
