-- Device fitting (decision 106): one place that adapts the authored screens to the device instead of every screen
-- doing it. Numbers in Config/Responsive.
-- * Windows (a ScreenGui with a Panel that keeps an aspect ratio) fit the safe area with their title banner and
--   close diamond on screen. Short phone screens get bigger windows, TVs stay clear of the overscan border.
-- * Touch: the lobby currency moves to the top right, out of the thumbstick's way.
-- * Fight on short screens: a smaller headline, bigger player billboards.
-- * Phones always play in landscape.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RS = game:GetService("ReplicatedStorage")
local Tuning = require(RS.Shared.Config.Responsive)
local Controller = {}

-- "Compact" (short phone screens), "TV" (console / ten-foot) or "Regular".
function Controller:Class()
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1366, 768)
	if GuiService:IsTenFootInterface() then
		return "TV"
	end
	if math.min(size.X, size.Y) < Tuning.CompactShortSide then
		return "Compact"
	end
	return "Regular"
end

function Controller:Touch()
	local ok, preferred = pcall(function()
		return UIS.PreferredInput
	end)
	if ok and typeof(preferred) == "EnumItem" then
		return preferred == Enum.PreferredInput.Touch
	end
	return UIS.TouchEnabled and not UIS.MouseEnabled and not UIS.GamepadEnabled
end

function Controller:Init()
	self.Player = Players.LocalPlayer
	self.Windows = setmetatable({}, { __mode = "k" }) -- [Panel] = { Size, Position, Up, Down }
	self.Connections = {}
end

-- How far the panel's own decorations (title banner, close diamond, drop art) reach past its top and bottom, as a
-- share of the panel height. Measured once from the authored layout.
local function reach(panel)
	local top, bottom = panel.AbsolutePosition.Y, panel.AbsolutePosition.Y + panel.AbsoluteSize.Y
	local up, down = 0, 0
	for _, child in panel:GetChildren() do
		if child:IsA("GuiObject") and child.Visible then
			up = math.max(up, top - child.AbsolutePosition.Y)
			down = math.max(down, child.AbsolutePosition.Y + child.AbsoluteSize.Y - bottom)
		end
	end
	local height = math.max(1, panel.AbsoluteSize.Y)
	return math.clamp(up / height, 0, 0.4), math.clamp(down / height, 0, 0.4)
end

function Controller:FitWindow(gui)
	local panel = gui:FindFirstChild("Panel")
	local aspect = panel and panel:FindFirstChildOfClass("UIAspectRatioConstraint")
	if not panel or not aspect or not panel:IsA("GuiObject") then
		return
	end
	local entry = self.Windows[panel]
	if not entry then
		if panel.AbsoluteSize.Y < 2 then
			return -- not laid out yet; the AbsoluteSize signal below brings us back
		end
		local up, down = reach(panel)
		entry = { Size = panel.Size, Position = panel.Position, Anchor = panel.AnchorPoint, Up = up, Down = down }
		self.Windows[panel] = entry
		panel.Destroying:Connect(function()
			self.Windows[panel] = nil
		end)
	end
	local class = self:Class()
	local area = gui.AbsoluteSize
	if area.X < 2 or area.Y < 2 then
		return
	end
	local width, height -- the largest box the panel may use, in pixels
	if class == "Compact" then
		width, height = area.X * Tuning.CompactWidth, area.Y * Tuning.CompactHeight
	else
		local parent = area
		width = entry.Size.X.Scale * parent.X + entry.Size.X.Offset
		height = entry.Size.Y.Scale * parent.Y + entry.Size.Y.Offset
		if class == "TV" then
			width = math.min(width, area.X * Tuning.SafeWidth)
			height = math.min(height, area.Y * Tuning.SafeHeight)
		end
	end
	-- Leave room for what pokes out above and below, so banners and close buttons never leave the screen.
	local margin = area.Y * Tuning.EdgeMargin * 2
	height = math.min(height, (area.Y - margin) / (1 + entry.Up + entry.Down))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Size = UDim2.fromOffset(math.floor(width), math.floor(height))
	-- The aspect constraint decides the final box; centre that box with its decorations on screen.
	local shown = math.min(height, width / math.max(0.01, aspect.AspectRatio))
	panel.Position = UDim2.new(0.5, 0, 0.5, math.floor(shown * (entry.Up - entry.Down) / 2))
end

-- Phone layouts for screens whose authored rows are too small to tap (applied before the window is fitted).
local PHONE_LAYOUTS = {
	-- Shop: the five tabs shared a short row with the coin/Marble pills (~14 px tall on a phone). The pills move up
	-- into the title strip, like the SHOP banner, and the tabs take the whole row.
	KilnScreen = function(panel)
		local tabs, coins, marbles =
			panel:FindFirstChild("Tabs"), panel:FindFirstChild("Coins"), panel:FindFirstChild("Marbles")
		if not tabs or not coins or not marbles then
			return
		end
		tabs.Position, tabs.Size = UDim2.fromScale(0.035, 0.09), UDim2.fromScale(0.93, 0.115)
		coins.Position = UDim2.fromScale(0.545, -0.005)
		marbles.Position = UDim2.fromScale(0.72, -0.005)
	end,
}

function Controller:PhoneLayout(gui, panel)
	local layout = PHONE_LAYOUTS[gui.Name]
	if not layout or self:Class() ~= "Compact" then
		return
	end
	layout(panel)
	-- Content added later (the Shop's Marbles tab resizes the tab row) gets the phone layout again.
	local tabs = panel:FindFirstChild("Tabs")
	if tabs then
		table.insert(
			self.Connections[gui],
			tabs.ChildAdded:Connect(function()
				task.defer(layout, panel)
			end)
		)
	end
end

function Controller:WatchWindow(gui)
	if self.Connections[gui] then
		return
	end
	local panel = gui:FindFirstChild("Panel") or gui:WaitForChild("Panel", 2)
	if not panel or not panel:IsA("GuiObject") or not panel:FindFirstChildOfClass("UIAspectRatioConstraint") then
		return
	end
	local fitting = false
	local function fit()
		if fitting then
			return
		end
		fitting = true
		task.defer(function()
			fitting = false
			if gui.Parent and gui.Enabled then
				self:FitWindow(gui)
			end
		end)
	end
	self.Connections[gui] = {
		gui:GetPropertyChangedSignal("Enabled"):Connect(fit),
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit),
		panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if not self.Windows[panel] then
				fit()
			end
		end),
		gui.Destroying:Connect(function()
			for _, connection in self.Connections[gui] or {} do
				connection:Disconnect()
			end
			self.Connections[gui] = nil
		end),
	}
	self:PhoneLayout(gui, panel)
	fit()
end

-- Touch: the coin/Marble counters sit where the thumbstick appears; put them top right instead.
function Controller:FitLobbyHud(gui)
	local currency = gui:FindFirstChild("Currency")
	if not currency or not currency:IsA("GuiObject") then
		return
	end
	if not self.CurrencyHome then
		self.CurrencyHome = { Position = currency.Position, Anchor = currency.AnchorPoint }
	end
	if self:Touch() then
		currency.AnchorPoint = Vector2.new(1, 0)
		currency.Position = UDim2.fromScale(1 - Tuning.EdgeMargin, Tuning.EdgeMargin)
		-- The frame is wider than its pills (they sit on its left); slide it so the pills meet the edge.
		task.defer(function()
			local right = currency.AbsolutePosition.X + currency.AbsoluteSize.X
			local content = -math.huge
			for _, child in currency:GetDescendants() do
				-- Only what is drawn: invisible spacer and gain-label frames reach past the pills.
				local drawn = child:IsA("GuiObject")
					and child.Visible
					and (
						child.BackgroundTransparency < 1
						or (child:IsA("ImageLabel") or child:IsA("ImageButton")) and child.ImageTransparency < 1
						or (child:IsA("TextLabel") or child:IsA("TextButton"))
							and child.TextTransparency < 1
							and child.Text ~= ""
					)
				if drawn then
					content = math.max(content, child.AbsolutePosition.X + child.AbsoluteSize.X)
				end
			end
			if content > -math.huge and right - content > 1 then
				currency.Position = UDim2.new(1 - Tuning.EdgeMargin, math.floor(right - content), Tuning.EdgeMargin, 0)
			end
		end)
	else
		currency.AnchorPoint, currency.Position = self.CurrencyHome.Anchor, self.CurrencyHome.Position
	end
end

-- Short screens: the PULL BACK / countdown headline would cover the swing. The FightHud ScreenGui stays and each
-- fight rebuilds its children, so watch for the headline itself.
function Controller:FitHeadline(headline)
	if headline:IsA("GuiObject") and self:Class() == "Compact" then
		headline.Size = UDim2.fromScale(headline.Size.X.Scale, Tuning.CompactHeadline)
	end
end

function Controller:FitFightHud(gui)
	if self.Connections[gui] then
		return
	end
	self.Connections[gui] = {
		gui.ChildAdded:Connect(function(child)
			if child.Name == "Headline" then
				task.defer(self.FitHeadline, self, child)
			end
		end),
	}
	local headline = gui:FindFirstChild("Headline")
	if headline then
		self:FitHeadline(headline)
	end
end

-- Player billboards are sized in studs, so their text is unreadable in a short phone viewport.
function Controller:FitBillboard(gui)
	if gui:GetAttribute("ResponsiveScaled") then
		return
	end
	local camera = workspace.CurrentCamera
	local short = camera and math.min(camera.ViewportSize.X, camera.ViewportSize.Y) or 720
	local factor = math.clamp(Tuning.BillboardReferenceHeight / math.max(1, short), 1, Tuning.BillboardMaxScale)
	if factor > 1.01 then
		gui:SetAttribute("ResponsiveScaled", true)
		local size = gui.Size
		gui.Size =
			UDim2.new(size.X.Scale * factor, size.X.Offset * factor, size.Y.Scale * factor, size.Y.Offset * factor)
	end
end

function Controller:Added(gui)
	if gui:IsA("BillboardGui") and gui.Name:match("^FightPlayer%d$") then
		task.defer(self.FitBillboard, self, gui)
	elseif gui:IsA("ScreenGui") then
		if gui.Name == "LobbyHUD" then
			task.defer(self.FitLobbyHud, self, gui)
		elseif gui.Name == "FightHud" then
			task.defer(self.FitFightHud, self, gui)
		elseif not gui.Name:match("^Topbar") then
			task.spawn(self.WatchWindow, self, gui)
		end
	end
end

function Controller:Refresh()
	local pg = self.Player:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return
	end
	for _, gui in pg:GetChildren() do
		if gui:IsA("ScreenGui") then
			if gui.Name == "LobbyHUD" then
				self:FitLobbyHud(gui)
			elseif gui.Enabled and self.Connections[gui] then
				self:FitWindow(gui)
			end
		end
	end
end

function Controller:Start()
	local pg = self.Player:WaitForChild("PlayerGui")
	-- Portrait is not designed for; phones turn the game to landscape (decision 106).
	-- Roblox copies StarterGui's setting over it when the first character loads, so keep putting it back.
	local function landscape()
		if pg.ScreenOrientation ~= Enum.ScreenOrientation.LandscapeSensor then
			pg.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
		end
	end
	landscape()
	pg:GetPropertyChangedSignal("ScreenOrientation"):Connect(landscape)
	self.Player.CharacterAdded:Connect(function()
		task.defer(landscape)
	end)
	pg.ChildAdded:Connect(function(gui)
		self:Added(gui)
	end)
	for _, gui in pg:GetChildren() do
		self:Added(gui)
	end
	local function watchCamera(camera)
		if self.CameraConnection then
			self.CameraConnection:Disconnect()
		end
		self.CameraConnection = camera
			and camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				self:Refresh()
			end)
	end
	watchCamera(workspace.CurrentCamera)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		watchCamera(workspace.CurrentCamera)
	end)
	local function input()
		local hud = pg:FindFirstChild("LobbyHUD")
		if hud then
			self:FitLobbyHud(hud)
		end
	end
	UIS.LastInputTypeChanged:Connect(input)
	pcall(function()
		UIS:GetPropertyChangedSignal("PreferredInput"):Connect(input)
	end)
end

return Controller
