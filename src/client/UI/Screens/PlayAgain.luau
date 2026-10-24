-- PLAY AGAIN (decision 124): one big button after a match that requeues in one tap. It sits above the lobby's
-- PLAY button and pops in with a small bounce and an idle pulse; PlayAgainController decides when it shows.
local TweenService = game:GetService("TweenService")
local Kit = require(script.Parent.Parent.Components.MatchKit)
local Screen = {}
Screen.__index = Screen

function Screen.new(onPress)
	local self = setmetatable({}, Screen)
	self.Gui = Kit.gui("PlayAgain", 15)
	self.Gui.Enabled = false
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

function Screen:Show()
	if self.Gui.Enabled then
		return
	end
	self.Gui.Enabled = true
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
