local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Glassies = require(RS.Shared.Config.Glassies)
local Balance = require(RS.Shared.Config.Balance)
local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Parent.Components.Util)
local Window = require(script.Parent.Parent.Components.Window)
local Button = require(script.Parent.Parent.Components.Button)
local Portrait = require(script.Parent.Parent.Components.GlassyPortrait)
local Screen = {}
Screen.__index = Screen

function Screen.new(data, close, pull, refresh)
	local self = setmetatable({ Data = data, Pull = pull, Refresh = refresh, Closed = false, Serial = 0 }, Screen)
	self.Window = Window.new("KilnScreen", "THE KILN • ODDS", close)
	self:Odds(data)
	return self
end

function Screen:Clear()
	self.Serial += 1
	self.Window.Content:ClearAllChildren()
end

function Screen:Odds(data)
	self:Clear()
	self.Data, self.Busy = data, false
	self.Window.Title.Text = "THE KILN • ODDS"
	local parent = self.Window.Content
	local status = if #data.Odds == 0
		then "Warming up • New glassies are coming"
		else "Every possible glassy is listed below"
	U.text(parent, "Status", status, UDim2.new(1, 0, 0, 28), UDim2.new())
	local list = U.make("ScrollingFrame", parent, {
		Name = "Odds",
		BackgroundColor3 = Theme.Colors.Inset,
		BackgroundTransparency = Theme.Colors.InsetTransparency,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -136),
		Position = UDim2.fromOffset(0, 32),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 5,
	})
	U.corner(list, Theme.Radius.Tag)
	U.make("UIListLayout", list, { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
	for i, odds in data.Odds do
		local def = Glassies.get(odds.Id)
		local row = U.make(
			"Frame",
			list,
			{ Name = odds.Id, BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 52), LayoutOrder = i }
		)
		U.text(row, "Name", def.Name, UDim2.new(0.68, -12, 0, 28), UDim2.fromOffset(10, 0)).TextXAlignment =
			Enum.TextXAlignment.Left
		local rarity = U.text(
			row,
			"Rarity",
			def.Rarity,
			UDim2.new(0.65, -12, 0, 22),
			UDim2.fromOffset(10, 28),
			Theme.Fonts.Caption
		)
		rarity.TextXAlignment, rarity.TextColor3 = Enum.TextXAlignment.Left, Theme.Rarity[def.Rarity].Top
		U.text(
			row,
			"Chance",
			string.format("%.4f%%", odds.Chance * 100),
			UDim2.new(0.32, -10, 1, 0),
			UDim2.new(0.68, 0, 0, 0)
		)
	end
	if #data.Odds == 0 then
		local label = U.text(
			list,
			"Empty",
			"The Kiln opens when new glassies arrive.\nYour coins are safe. Try a clash!",
			UDim2.new(1, -24, 0, 100),
			UDim2.fromOffset(12, 12),
			Theme.Fonts.Caption
		)
		label.TextWrapped = true
	end
	U.text(
		parent,
		"RainbowOdds",
		string.format(
			"Rainbow variant: %.2f%% per pull • Coins %s",
			Balance.Growth.RainbowChance * 100,
			tostring(data.Coins)
		),
		UDim2.new(1, 0, 0, 24),
		UDim2.new(0, 0, 1, -98),
		Theme.Fonts.Caption
	)
	for i, count in { 1, 10 } do
		local welcome = count == 1 and data.Welcome > 0
		local cost = if welcome then 0 elseif count == 1 then data.Cost else data.TenCost
		local text = if welcome then "WELCOME • FREE" else "PULL ×" .. count .. " • " .. cost
		local button = Button.new(
			parent,
			"Pull" .. count,
			text,
			"Green",
			UDim2.new(0.48, 0, 0, 48),
			UDim2.new((i - 1) * 0.52, 0, 1, -68)
		)
		local enabled = #data.Odds > 0 and data.Coins >= cost
		button.Active, button.AutoButtonColor, button.BackgroundTransparency =
			enabled, false, if enabled then 0 else 0.6
		if not enabled then
			button.TextTransparency = 0.5
		end
		button.Activated:Connect(function()
			if enabled and not self.Busy then
				self.Busy = true
				button.Text = "BLOWING..."
				self.Pull(count, data.Quote)
			end
		end)
	end
	self.Message = U.text(parent, "Message", "", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 1, -20), Theme.Fonts.Caption)
end

function Screen:Result(data)
	if data.Error then
		self.Busy = false
		if self.Message then
			self.Message.Text = data.Error
		end
		return
	end
	self.Results, self.At = data.Results, 1
	self:Reveal()
end

function Screen:Reveal()
	self:Clear()
	local serial, result = self.Serial, self.Results[self.At]
	if not result then
		self.Refresh()
		return
	end
	local def, parent = Glassies.get(result.Id), self.Window.Content
	self.Window.Title.Text = "BLOWING GLASS • " .. self.At .. " / " .. #self.Results
	local bubble = U.make("Frame", parent, {
		Name = "MoltenBubble",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Theme.Buttons.Yellow.Bottom,
		BackgroundTransparency = 0.12,
	})
	U.corner(bubble, UDim.new(1, 0))
	U.make("UIAspectRatioConstraint", bubble, { AspectRatio = 1 })
	U.make("UIStroke", bubble, { Color = Theme.Colors.Highlight, Thickness = 3, Transparency = 0.2 })
	TweenService:Create(
		bubble,
		TweenInfo.new(0.65, Enum.EasingStyle.Back),
		{ Size = UDim2.fromScale(0.3, 0.6), BackgroundColor3 = Color3.fromHex(def.Tint) }
	):Play()
	local nextButton = Button.new(
		parent,
		"Next",
		if self.At == #self.Results then "BACK TO ODDS" else "NEXT",
		"Green",
		UDim2.new(0.46, 0, 0, 48),
		UDim2.new(0.27, 0, 1, -52)
	)
	nextButton.Visible = false
	nextButton.Activated:Connect(function()
		self.At += 1
		self:Reveal()
	end)
	if #self.Results > 1 then
		local skip = Button.new(parent, "Skip", "SKIP", "Blue", UDim2.fromOffset(84, 44), UDim2.new(1, -88, 0, 0))
		skip.Activated:Connect(self.Refresh)
	end
	task.delay(0.8, function()
		if self.Closed or self.Serial ~= serial then
			return
		end
		bubble:Destroy()
		self.Window.Title.Text = def.Rarity:upper() .. " • " .. def.Name
		self.Window.Panel.UIStroke.UIGradient.Color =
			ColorSequence.new(Theme.Rarity[def.Rarity].Top, Theme.Rarity[def.Rarity].Bottom)
		self.Portrait = Portrait.new(parent, result.Id, UDim2.new(0.6, 0, 1, -108), UDim2.fromScale(0.2, 0))
		local text = if result.Duplicate then "DUPLICATE → ★" .. result.Stars else "NEW GLASSY!"
		if result.Rainbow then
			text ..= " • RAINBOW!"
		end
		if result.BonusCoins > 0 then
			text ..= " • +" .. result.BonusCoins .. " COINS"
		end
		U.text(parent, "Reward", text, UDim2.new(1, 0, 0, 38), UDim2.new(0, 0, 1, -98), Theme.Fonts.Heading).TextColor3 =
			Theme.Colors.Highlight
		nextButton.Visible = true
	end)
end

function Screen:Step(dt)
	local p = self.Portrait
	if p and p.Parent then
		for _, part in p.WorldModel:GetChildren() do
			if part:IsA("BasePart") then
				part:PivotTo(part:GetPivot() * CFrame.Angles(0, dt * 0.4, 0))
			end
		end
	end
end

function Screen:Destroy()
	self.Closed = true
	self.Window:Destroy()
end
return Screen
