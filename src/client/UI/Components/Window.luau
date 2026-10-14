local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Util)
local Panel = require(script.Parent.Panel)
local Button = require(script.Parent.Button)
local Window = {}
Window.__index = Window

function Window.new(name, title, close)
	local self = setmetatable({ Connections = {} }, Window)
	self.Gui = U.make("ScreenGui", Players.LocalPlayer.PlayerGui, {
		Name = name,
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	self.Panel = Panel.new(self.Gui, "Panel", UDim2.fromScale(0.94, 0.94), UDim2.fromScale(0.03, 0.03))
	self.Panel.Active = true
	local scale = U.make("UIScale", self.Panel, { Scale = Theme.Motion.PanelOpenScaleFrom })
	TweenService:Create(scale, Theme.Motion.PanelOpen, { Scale = 1 }):Play()
	self.Title =
		U.text(self.Panel, "Title", title, UDim2.new(1, -88, 0, 44), UDim2.fromOffset(16, 4), Theme.Fonts.Heading)
	self.Title.TextXAlignment = Enum.TextXAlignment.Left
	self.Title.UITextSizeConstraint.MaxTextSize = Theme.TextSize.Heading
	self:Connect(Button.new(self.Panel, "Close", "X", "Red", UDim2.fromOffset(48, 44), UDim2.new(1, -60, 0, 6)), close)
	self.Content = U.make(
		"Frame",
		self.Panel,
		{
			Name = "Content",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -24, 1, -64),
			Position = UDim2.fromOffset(12, 56),
		}
	)
	return self
end

function Window:Connect(button, callback)
	U.make("UISizeConstraint", button, { MinSize = Vector2.new(44, 44) })
	table.insert(self.Connections, button.Activated:Connect(callback))
end

function Window:Destroy()
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	self.Gui:Destroy()
end

return Window
