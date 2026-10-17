-- Marble shop: a grid of Marble packs (Config/MarbleShop) opened from the "+" on the HUD and shop
-- Marble counters. Reuses the shop window's stained-glass frame; packs are bought through
-- StoreService (BuyMarblePack -> intent -> Robux prompt -> idempotent receipt).
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Remotes = require(RS.Shared.Remotes)
local Rules = require(RS.Shared.DailyStoreRules)
local U = require(script.Parent.Util)
local S = require(script.Parent.StainedGlass)
local Gem = require(script.Parent.GemButton)
local Motion = require(script.Parent.Motion)
local Theme = require(script.Parent.Parent.Theme)
local MarbleShop = {}
local ROBUX = utf8.char(0xE002)
local tints = {
	Color3.new(1, 1, 1),
	Theme.Palette.rubyLight,
	Theme.Palette.amberLight,
	Theme.Palette.emeraldLight,
	Color3.fromRGB(190, 170, 255),
	Color3.fromRGB(170, 230, 255),
}
local current

-- Original pile illustration: a pyramid of tinted marbles that grows with the pack.
local function pile(parent, step)
	local art = U.make("Frame", parent, {
		Name = "Art",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.1),
		Size = UDim2.fromScale(0.86, 0.44),
	})
	S.aspect(art, 1.6).AspectType = Enum.AspectType.FitWithinMaxSize
	if step >= 4 then
		local glow = S.image(art, "Glow", "kiln/glow", UDim2.fromScale(1, 1.2))
		glow.AnchorPoint, glow.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.55)
		glow.ImageTransparency = 0.45
	end
	local width = math.min(0.42, 0.9 / step, (1 / (0.7 * (step - 1) + 1)) / 1.6)
	local height = width * 1.6
	local n = 0
	for row = 0, step - 1 do
		local count = step - row
		for i = 0, count - 1 do
			n += 1
			local x = 0.5 + (i - (count - 1) / 2) * width * 0.92
			local y = 1 - row * height * 0.7
			local marble = S.image(art, "Marble" .. n, "icon/marble", UDim2.fromScale(width, height))
			marble.AnchorPoint, marble.Position = Vector2.new(0.5, 1), UDim2.fromScale(x, y)
			marble.ZIndex = 2 + row
			if marble:IsA("ImageLabel") then
				marble.ImageColor3 = tints[(n * 7 + row) % #tints + 1]
			end
		end
	end
	return art
end

local function card(grid, pack, order, say)
	local frame = U.make("Frame", grid, { Name = "Pack_" .. pack.Id, BackgroundTransparency = 1, LayoutOrder = order })
	local back = S.image(frame, "Artwork", "panel/pane_dark", UDim2.fromScale(1, 1))
	back:FindFirstChildOfClass("UIAspectRatioConstraint"):Destroy()
	pile(frame, pack.Art)
	if pack.Bonus > 0 then
		local tag = U.make("ImageLabel", frame, {
			Name = "Bonus",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(0.97, 0.03),
			Size = UDim2.fromScale(0.5, 0.11),
			ZIndex = 10,
		})
		U.make("UIAspectRatioConstraint", tag, { AspectRatio = 3.75, DominantAxis = Enum.DominantAxis.Height })
		local label =
			U.text(tag, "Label", "", UDim2.fromScale(0.74, 0.62), UDim2.fromScale(0.13, 0.19), Theme.Fonts.Caption)
		label.ZIndex, label.UITextSizeConstraint.MinTextSize = 11, 1
		S.tag(tag, "+" .. pack.Bonus .. "% BONUS", if pack.Bonus >= 25 then "amber" else "emerald")
	end
	local amount = U.text(
		frame,
		"Amount",
		string.format("%d", pack.Marbles):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""),
		UDim2.fromScale(0.9, 0.13),
		UDim2.fromScale(0.05, 0.56),
		Theme.Fonts.Heading
	)
	amount.UITextSizeConstraint.MaxTextSize = Theme.TextSize.Heading
	local name = U.text(
		frame,
		"PackName",
		pack.Name,
		UDim2.fromScale(0.9, 0.08),
		UDim2.fromScale(0.05, 0.69),
		Theme.Fonts.Caption
	)
	name.TextColor3 = Theme.Palette.amberLight
	name.UITextSizeConstraint.MaxTextSize = Theme.TextSize.Small
	local text = if pack.Available then ROBUX .. " " .. pack.RobuxPrice else "COMING SOON"
	local button = Gem.new(
		frame,
		"Buy",
		text,
		if pack.Available then "Green" else "Blue",
		UDim2.fromScale(0.8, 0.17),
		UDim2.fromScale(0.1, 0.8)
	)
	button.Label.TextTransparency = if pack.Available then 0 else 0.3
	return frame,
		button.Activated:Connect(function()
			if pack.Available then
				say("Opening the Robux purchase…")
				Remotes.BuyMarblePack:FireServer(pack.Id)
			else
				say("Marble packs open soon")
			end
		end)
end

function MarbleShop.isOpen()
	return current ~= nil
end

function MarbleShop.open()
	if current then
		return current
	end
	local template = game.StarterGui:FindFirstChild("KilnScreen")
	if not template then
		return nil
	end
	local self = { Connections = {} }
	current = self
	local gui = U.screen("MarbleShop", 30)
	gui:ClearAllChildren()
	self.Gui = gui
	local panel = template.Panel:Clone()
	panel.Size = UDim2.fromScale(0.86, 0.86)
	for _, name in { "Tabs", "Coins" } do
		local child = panel:FindFirstChild(name)
		if child then
			child:Destroy()
		end
	end
	panel.Content:ClearAllChildren()
	panel.Parent = gui
	S.setAsset(panel.TitleBanner, "panel/title_sapphire")
	panel.Title.Text = "MARBLES"
	local content = panel.Content
	local intro = U.text(
		content,
		"Intro",
		"Marbles pay for Pick Any in matches and other Marble items. Odds are always shown before any opening.",
		UDim2.fromScale(0.96, 0.07),
		UDim2.fromScale(0.02, 0),
		Theme.Fonts.Caption
	)
	intro.TextColor3 = Theme.Colors.TextMuted
	intro.UITextSizeConstraint.MaxTextSize = Theme.TextSize.Small
	local grid = U.make("Frame", content, {
		Name = "Packs",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.09),
		Size = UDim2.fromScale(1, 0.83),
	})
	U.make("UIGridLayout", grid, {
		CellSize = UDim2.fromScale(0.315, 0.47),
		CellPadding = UDim2.fromScale(0.0275, 0.06),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})
	local message =
		U.text(content, "Message", "", UDim2.fromScale(0.96, 0.06), UDim2.fromScale(0.02, 0.935), Theme.Fonts.Caption)
	message.UITextSizeConstraint.MaxTextSize = Theme.TextSize.Small
	local function say(text)
		message.Text = text
	end
	for order, pack in Rules.marblePacks() do
		local _, connection = card(grid, pack, order, say)
		table.insert(self.Connections, connection)
	end
	local amount = panel.Marbles:FindFirstChild("MarblesAmount")
	local function wallet(value)
		if amount and type(value) == "number" then
			amount.Text = tostring(value)
		end
	end
	local hud = Players.LocalPlayer.PlayerGui:FindFirstChild("LobbyHUD")
	local hudAmount = hud and hud:FindFirstChild("MarblesAmount", true)
	wallet(hudAmount and tonumber(hudAmount.Text) or 0)
	table.insert(
		self.Connections,
		Remotes.ProfileSnapshot.OnClientEvent:Connect(function(profile)
			if type(profile) == "table" then
				wallet(profile.Marbles)
			end
		end)
	)
	table.insert(
		self.Connections,
		Remotes.StoreResult.OnClientEvent:Connect(function(result)
			if type(result) == "table" and type(result.Message) == "string" then
				say(result.Message)
			end
		end)
	)
	table.insert(self.Connections, panel.Close.Activated:Connect(MarbleShop.close))
	panel.Close.Active, panel.Close.Selectable = true, true
	S.bindSlices(gui)
	Motion.windowIn(gui, panel)
	Remotes.RequestProfile:FireServer()
	return self
end

function MarbleShop.close()
	local self = current
	current = nil
	if not self then
		return
	end
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	self.Gui:Destroy()
end

-- Adds a "+" to a Marble counter plaque that opens the shop. Safe to call more than once.
function MarbleShop.attachPlus(plaque)
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
		MarbleShop.open()
	end)
	return button
end

return MarbleShop
