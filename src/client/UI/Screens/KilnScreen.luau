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
function Screen.new(data, close, pull, refresh, initialTab)
	local self =
		setmetatable({ Data = data, Pull = pull, Refresh = refresh, Close = close, Closed = false, Serial = 0 }, Screen)
	self.Tab = initialTab or "Featured"
	self:Odds(data)
	return self
end
function Screen:Page(name, title)
	self.Serial += 1
	require(script.Parent.ShopPools).destroy(self)
	if self.Window then
		self.Window:Destroy()
	end
	self.Window = Window.new(name, title, self.Close)
	self.Portrait = nil
	return self.Window.Content
end
function Screen:Odds(data)
	require(script.Parent.ShopContent).bind(self, data)
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
	-- Portraits stay upright and centered; interactive controls retain their animation.
end
function Screen:Destroy()
	self.Closed = true
	require(script.Parent.ShopPools).destroy(self)
	self.Window:Destroy()
end
return Screen
