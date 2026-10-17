local Players = game:GetService("Players")

local Theme = require(script.Parent.Parent.Theme)
local U = require(script.Parent.Util)
local Panel = require(script.Parent.Panel)
local Button = require(script.Parent.Button)
local Motion = require(script.Parent.Motion)
local S = require(script.Parent.StainedGlass)
local Window = {}
Window.__index = Window
-- Windows closed this frame, by screen name. A new window of the same kind opening straight after (a refresh)
-- replaces it instantly instead of playing a close and an open animation back to back.
local closing = {}
local bannerTints = { RewardsScreen = "amber", IndexScreen = "aqua", RollInfoScreen = "amethyst" }

-- Screens without an authored cut-glass frame (Rewards, Index, power info) borrow the Inventory window's art,
-- title banner and close diamond, so every menu opens in the same Stained Glass window.
local function dress(panel, name)
	if panel:GetAttribute("StainedGlass") then
		return
	end
	local starter = game.StarterGui:FindFirstChild("CollectionScreen")
	local source = starter and starter:FindFirstChild("Panel")
	if not source then
		return
	end
	panel.BackgroundTransparency = 1
	for _, child in panel:GetChildren() do
		if child:IsA("UIGradient") or child:IsA("UIStroke") or child:IsA("UICorner") then
			child:Destroy()
		end
	end
	panel.AnchorPoint, panel.Position, panel.Size =
		Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.86, 0.9)
	U.make("UIAspectRatioConstraint", panel, { AspectRatio = 1.7727272727, DominantAxis = Enum.DominantAxis.Width })
	for _, part in { "WindowArtwork", "TitleBanner", "Title", "Close" } do
		local old = panel:FindFirstChild(part)
		if old then
			old:Destroy()
		end
		source[part]:Clone().Parent = panel
	end
	U.make("Frame", panel, {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = source.Content.Size,
		Position = source.Content.Position,
	})
	panel.WindowArtwork.ZIndex = 0 -- always behind the content, whatever the child order
	panel.TitleBanner.ZIndex, panel.Title.ZIndex, panel.Close.ZIndex = 3, 4, 5
	S.setAsset(panel.TitleBanner, "panel/title_" .. (bannerTints[name] or "sapphire"))
	panel:SetAttribute("StainedGlass", true)
	S.bindSlices(panel)
end

function Window.new(name, title, close)
	local self = setmetatable({ Connections = {} }, Window)
	local previous = closing[name]
	local refresh = previous ~= nil and previous.Gui.Parent ~= nil and os.clock() - previous.At < 0.1
	if previous then
		closing[name] = nil
		if previous.Gui.Parent then
			previous.Gui:Destroy()
		end
	end
	self.Gui = U.screen(name, 20)
	-- Menus never darken the world: the authored full-screen "Backdrop" frames go clear (blur + FOV do the work).
	for _, child in self.Gui:GetChildren() do
		if
			child:IsA("Frame")
			and child.Name ~= "Panel"
			and child.Size.X.Scale >= 0.95
			and child.Size.Y.Scale >= 0.9
		then
			child.BackgroundTransparency = 1
		end
	end
	self.Panel = Panel.new(self.Gui, "Panel", UDim2.fromScale(0.94, 0.94), UDim2.fromScale(0.03, 0.03))
	dress(self.Panel, name)
	self.Panel.Active = true
	self.Motion = Motion.windowIn(self.Gui, self.Panel, refresh)
	self.Title = U.text(
		self.Panel,
		"Title",
		title,
		UDim2.fromScale(0.8, 0.12),
		UDim2.fromScale(0.025, 0.015),
		Theme.Fonts.Heading
	)
	if not self.Panel:GetAttribute("StainedGlass") then
		self.Title.TextXAlignment = Enum.TextXAlignment.Left
	end
	if not self.Panel:GetAttribute("StainedGlass") then
		self.Title.UITextSizeConstraint.MaxTextSize = Theme.TextSize.Heading
	end
	self:Connect(
		Button.new(self.Panel, "Close", "X", "Red", UDim2.fromScale(0.085, 0.13), UDim2.fromScale(0.895, 0.015)),
		close
	)
	if self.Panel:GetAttribute("StainedGlass") then
		self.Panel.Close.Label.Visible = false
	end
	self.Content = U.make("Frame", self.Panel, {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.95, 0.82),
		Position = UDim2.fromScale(0.025, 0.16),
	})
	if self.Panel:GetAttribute("StainedGlass") then
		return self
	end
	local position, size = self.Content.Position, self.Content.Size
	local function resize()
		local height = math.max(1, self.Panel.AbsoluteSize.Y)
		local top = math.max(
			position.Y.Scale,
			(self.Panel.Close.AbsolutePosition.Y - self.Panel.AbsolutePosition.Y + self.Panel.Close.AbsoluteSize.Y + 8)
				/ height
		)
		self.Content.Position = UDim2.fromScale(position.X.Scale, top)
		self.Content.Size = UDim2.fromScale(size.X.Scale, math.min(size.Y.Scale, math.max(0.1, 1 - top - 0.02)))
	end
	table.insert(self.Connections, self.Panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))
	resize()
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
	local gui = self.Gui
	if not self.Motion or not gui.Parent then
		gui:Destroy()
		return
	end
	-- Free the name right away so a new window of the same kind never reuses this closing one.
	local base = gui.Name
	closing[base] = { Gui = gui, At = os.clock() }
	gui.Name = base .. "_Closing"
	self.Panel.Active = false
	self.Motion.Close(function()
		if closing[base] and closing[base].Gui == gui then
			closing[base] = nil
		end
		gui:Destroy()
	end)
end

return Window
