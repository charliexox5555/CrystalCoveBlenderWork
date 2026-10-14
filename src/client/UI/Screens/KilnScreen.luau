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
	local self =
		setmetatable({ Data = data, Pull = pull, Refresh = refresh, Close = close, Closed = false, Serial = 0 }, Screen)
	self:Odds(data)
	return self
end
function Screen:Page(name, title)
	self.Serial += 1
	if self.Window then
		self.Window:Destroy()
	end
	self.Window = Window.new(name, title, self.Close)
	self.Portrait = nil
	return self.Window.Content
end
function Screen:Odds(data)
	local parent = self:Page("KilnScreen", "THE KILN • ODDS")
	self.Data, self.Busy = data, false
	U.text(
		parent,
		"Status",
		if #data.Odds == 0 then "Warming up • New glassies are coming" else "Every possible glassy is listed below",
		UDim2.fromScale(1, 0.12),
		UDim2.new()
	)
	local list = U.make("ScrollingFrame", parent, {
		Name = "Odds",
		BackgroundColor3 = Theme.Colors.Inset,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0.46),
		Position = UDim2.fromScale(0, 0.14),
		ScrollBarThickness = 5,
	})
	U.corner(list, Theme.Radius.Tag)
	local old = list:FindFirstChild("Rows")
	if old then
		old:Destroy()
	end
	local rows = U.make("Frame", list, { Name = "Rows", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local canvas = math.max(1, #data.Odds * 0.36)
	list.CanvasSize = UDim2.fromScale(0, canvas)
	for i, odds in data.Odds do
		local def = Glassies.get(odds.Id)
		local prototype = U.prototype(list, "OddsRow", odds.Id)
		if prototype then
			prototype.Parent = rows
		end
		local row = U.make("Frame", rows, { Name = odds.Id, BackgroundTransparency = 1 })
		row.Size, row.Position = UDim2.fromScale(0.98, 0.34 / canvas), UDim2.fromScale(0, (i - 1) * 0.36 / canvas)
		U.text(row, "Name", def.Name, UDim2.fromScale(0.64, 0.55), UDim2.fromScale(0.02, 0)).TextXAlignment =
			Enum.TextXAlignment.Left
		local rarity = U.text(
			row,
			"Rarity",
			def.Rarity,
			UDim2.fromScale(0.64, 0.4),
			UDim2.fromScale(0.02, 0.57),
			Theme.Fonts.Caption
		)
		rarity.TextXAlignment, rarity.TextColor3 = Enum.TextXAlignment.Left, Theme.Rarity[def.Rarity].Top
		U.text(
			row,
			"Chance",
			string.format("%.4f%%", odds.Chance * 100),
			UDim2.fromScale(0.3, 1),
			UDim2.fromScale(0.68, 0)
		)
	end
	local empty = U.text(
		list,
		"Empty",
		"The Kiln opens when new glassies arrive.\nYour coins are safe. Try a clash!",
		UDim2.fromScale(0.94, 0.9),
		UDim2.fromScale(0.03, 0.04),
		Theme.Fonts.Caption
	)
	empty.TextWrapped, empty.Visible = true, #data.Odds == 0
	U.text(
		parent,
		"RainbowOdds",
		string.format(
			"Rainbow variant: %.2f%% per pull • Coins %s",
			Balance.Growth.RainbowChance * 100,
			tostring(data.Coins)
		),
		UDim2.fromScale(1, 0.1),
		UDim2.fromScale(0, 0.61),
		Theme.Fonts.Caption
	)
	for i, count in { 1, 10 } do
		local welcome = count == 1 and data.Welcome > 0
		local cost = if welcome then 0 elseif count == 1 then data.Cost else data.TenCost
		local button = Button.new(
			parent,
			"Pull" .. count,
			if welcome then "WELCOME • FREE" else "PULL ×" .. count .. " • " .. cost,
			"Green",
			UDim2.fromScale(0.48, 0.2),
			UDim2.fromScale((i - 1) * 0.52, 0.73)
		)
		local enabled = #data.Odds > 0 and data.Coins >= cost
		button.Active, button.TextTransparency = enabled, if enabled then 0 else 0.5
		self.Window:Connect(button, function()
			if enabled and not self.Busy then
				self.Busy = true
				button.Text = "BLOWING..."
				self.Pull(count, data.Quote)
			end
		end)
	end
	self.Message =
		U.text(parent, "Message", "", UDim2.fromScale(1, 0.06), UDim2.fromScale(0, 0.94), Theme.Fonts.Caption)
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
	local result = self.Results[self.At]
	if not result then
		self.Refresh()
		return
	end
	local def = Glassies.get(result.Id)
	local parent = self:Page("KilnRevealScreen", "BLOWING GLASS • " .. self.At .. " / " .. #self.Results)
	local serial = self.Serial
	local bubble = U.make("Frame", parent, {
		Name = "MoltenBubble",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromScale(0.04, 0.08),
		BackgroundColor3 = Theme.Buttons.Yellow.Bottom,
		BackgroundTransparency = 0.12,
	})
	bubble.Visible = true
	bubble.Size = UDim2.fromScale(0.04, 0.08)
	U.corner(bubble, UDim.new(1, 0))
	U.make("UIAspectRatioConstraint", bubble, { AspectRatio = 1 })
	U.make("UIStroke", bubble, { Color = Theme.Colors.Highlight, Thickness = 3, Transparency = 0.2 })
	TweenService:Create(
		bubble,
		TweenInfo.new(0.65, Enum.EasingStyle.Back),
		{ Size = UDim2.fromScale(0.25, 0.5), BackgroundColor3 = Color3.fromHex(def.Tint) }
	):Play()
	local nextButton = Button.new(
		parent,
		"Next",
		if self.At == #self.Results then "BACK TO ODDS" else "NEXT",
		"Green",
		UDim2.fromScale(0.46, 0.2),
		UDim2.fromScale(0.27, 0.79)
	)
	nextButton.Visible = false
	self.Window:Connect(nextButton, function()
		self.At += 1
		self:Reveal()
	end)
	local skip = Button.new(parent, "Skip", "SKIP", "Blue", UDim2.fromScale(0.16, 0.17), UDim2.fromScale(0.83, 0))
	skip.Visible = #self.Results > 1
	self.Window:Connect(skip, self.Refresh)
	self.Portrait = Portrait.new(parent, result.Id, UDim2.fromScale(0.6, 0.56), UDim2.fromScale(0.2, 0))
	self.Portrait.Visible = false
	local reward = U.text(parent, "Reward", "", UDim2.fromScale(1, 0.16), UDim2.fromScale(0, 0.6), Theme.Fonts.Heading)
	reward.TextColor3 = Theme.Colors.Highlight
	task.delay(0.8, function()
		if self.Closed or self.Serial ~= serial then
			return
		end
		bubble.Visible = false
		self.Portrait.Visible = true
		self.Window.Title.Text = def.Rarity:upper() .. " • " .. def.Name
		self.Window.Panel.UIStroke.UIGradient.Color =
			ColorSequence.new(Theme.Rarity[def.Rarity].Top, Theme.Rarity[def.Rarity].Bottom)
		reward.Text = if result.Duplicate then "DUPLICATE → ★" .. result.Stars else "NEW GLASSY!"
		if result.Rainbow then
			reward.Text ..= " • RAINBOW!"
		end
		if result.BonusCoins > 0 then
			reward.Text ..= " • +" .. result.BonusCoins .. " COINS"
		end
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
