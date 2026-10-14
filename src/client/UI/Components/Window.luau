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
	self.Gui = U.screen(name, 20)
	self.Panel = Panel.new(self.Gui, "Panel", UDim2.fromScale(0.94, 0.94), UDim2.fromScale(0.03, 0.03))
	self.Panel.Active = true
	local scale = U.make("UIScale", self.Panel, { Scale = Theme.Motion.PanelOpenScaleFrom })
	TweenService:Create(scale, Theme.Motion.PanelOpen, { Scale = 1 }):Play()
	self.Title = U.text(
		self.Panel,
		"Title",
		title,
		UDim2.fromScale(0.8, 0.12),
		UDim2.fromScale(0.025, 0.015),
		Theme.Fonts.Heading
	)
	self.Title.TextXAlignment = Enum.TextXAlignment.Left
	self.Title.UITextSizeConstraint.MaxTextSize = Theme.TextSize.Heading
	self:Connect(
		Button.new(self.Panel, "Close", "X", "Red", UDim2.fromScale(0.085, 0.13), UDim2.fromScale(0.895, 0.015)),
		close
	)
	self.Content = U.make("Frame", self.Panel, {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.95, 0.82),
		Position = UDim2.fromScale(0.025, 0.16),
	})
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
