-- PLAY AGAIN (decision 124): one big button after a match that requeues in one tap. It sits above the lobby's
-- PLAY button and pops in with a small bounce and an idle pulse; PlayAgainController decides when it shows.
local TweenService = game:GetService("TweenService")
local Kit = require(script.Parent.Parent.Components.MatchKit)
local Theme = require(script.Parent.Parent.Theme)
local Balance = require(game.ReplicatedStorage.Shared.Config.Balance)
local Glassies = require(game.ReplicatedStorage.Shared.Config.Glassies)
local Item = require(script.Parent.Parent.Components.ItemPresentation)
local GamepadNav = require(script.Parent.Parent.Components.GamepadNav)
local Screen = {}
Screen.__index = Screen

function Screen.new(onPress, onDismiss)
	local self = setmetatable({}, Screen)
	self.OnDismiss = onDismiss
	self.Gui = Kit.gui("PlayAgain", 15)
	self.Gui.Enabled = false
	self.Title =
		Kit.label(self.Gui, "NextBattle", "ONE MORE CLASH?", UDim2.fromScale(0.6, 0.075), UDim2.fromScale(0.2, 0.53))
	self.Goal = Kit.label(
		self.Gui,
		"NextGlassy",
		"",
		UDim2.fromScale(0.6, 0.055),
		UDim2.fromScale(0.2, 0.83),
		{ Font = Theme.Fonts.Body, MaxSize = Theme.TextSize.Label }
	)
	self.Return = Kit.label(
		self.Gui,
		"ReturnGoal",
		"",
		UDim2.fromScale(0.7, 0.045),
		UDim2.fromScale(0.15, 0.91),
		{ Font = Theme.Fonts.Body, MaxSize = Theme.TextSize.Small, Small = true }
	)
	self.Button = Kit.gem(
		self.Gui,
		"PlayAgainButton",
		"PLAY AGAIN",
		"play",
		UDim2.fromScale(0.3, 0.15),
		UDim2.fromScale(0.5, 0.72)
	)
	self.Scale = Instance.new("UIScale")
	self.Scale.Parent = self.Button
	self.Connection = self.Button.Activated:Connect(onPress)
	return self
end

function Screen:Update(profile, rewardId)
	local def = type(rewardId) == "string" and Glassies.ById[rewardId]
	self.Title.Text = if def then "TRY YOUR NEW " .. string.upper(def.Name) .. "!" else "ONE MORE CLASH?"
	if self.RewardId ~= rewardId then
		if self.Portrait then
			self.Portrait:Destroy()
			self.Portrait = nil
		end
		self.RewardId = rewardId
		if def then
			self.Portrait = Item.portrait(
				self.Gui,
				"Glassies",
				rewardId,
				UDim2.fromScale(0.18, 0.2),
				UDim2.fromScale(0.41, 0.31),
				"NewGlassy"
			)
		end
	end
	local coins, cost = profile and profile.Coins or 0, Balance.Economy.KilnCoinCost
	self.Goal.Text = if coins >= cost
		then "KILN OPEN READY!"
		else string.format("NEXT KILN OPEN: %d / %d COINS", coins, cost)
	self.Goal.Visible = profile ~= nil
	local calendar = profile and profile.Retention and profile.Retention.Calendar
	self.Return.Text = if calendar and calendar.Count == 1 then "TOMORROW: FREE EPIC WHISKERS" else ""
end

function Screen:Show()
	if self.Gui.Enabled then
		return
	end
	self.Gui.Enabled = true
	self.Nav = GamepadNav.push(self.Gui, { First = self.Button, Close = self.OnDismiss })
	self.Scale.Scale = 0.4
	TweenService:Create(self.Scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	-- A slow breathing pulse so it reads as "press me" without flashing.
	self.Pulse = TweenService:Create(
		self.Scale,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 0.4),
		{ Scale = 1.07 }
	)
	self.Pulse:Play()
end

function Screen:Hide()
	if self.Nav then
		self.Nav.Pop()
		self.Nav = nil
	end
	if self.Pulse then
		self.Pulse:Cancel()
		self.Pulse = nil
	end
	self.Gui.Enabled = false
end

function Screen:Destroy()
	self:Hide()
	self.Connection:Disconnect()
	self.Gui:Destroy()
end

return Screen
