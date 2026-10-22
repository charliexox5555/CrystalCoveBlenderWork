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

-- "Compact" (short phone screens), "TV" (console / ten-foot) or "Regular". Components call it as
-- `ResponsiveController:Class()` to pick a phone layout for content they build themselves.
function Controller:Class()
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1366, 768)
	if GuiService:IsTenFootInterface() then
		return "TV"
	end
	-- A camera that isn't sized yet (first frames after joining) is not a phone.
	if size.X > 50 and size.Y > 50 and math.min(size.X, size.Y) < Tuning.CompactShortSide then
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

function Controller:Init(controllers)
	self.Controllers = controllers
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
	self:PhoneLayout(gui, panel)
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

-- Phone layouts for screens whose authored rows are too small to tap: [screen][child][property] = phone value.
-- They are applied (or taken back) on every fit, so a window built while the class read differently heals itself.
local PHONE_LAYOUTS = {
	-- Shop: the five tabs shared a short row with the coin/Marble pills (~14 px tall on a phone). The pills move up
	-- into the title strip, like the SHOP banner, and the tabs take the whole row.
	KilnScreen = {
		Tabs = { Position = UDim2.fromScale(0.035, 0.09), Size = UDim2.fromScale(0.93, 0.115) },
		Coins = { Position = UDim2.fromScale(0.545, -0.005) },
		Marbles = { Position = UDim2.fromScale(0.72, -0.005) },
	},
	SettingsScreen = {},
}
-- Settings rows on phones (creator: shrink, don't cut). Slider rows: the helper line drops below the value pill and
-- takes the row's width. Toggle rows have no room beside the switch for a 9 px helper, so the helper goes and the
-- name gets its height (two lines if it needs them); the icon still says what the row is.
for _, row in { "Master", "Music", "SFX" } do
	PHONE_LAYOUTS.SettingsScreen["Content.Rows." .. row .. ".Helper"] =
		{ Position = UDim2.fromScale(0.2, 0.38), Size = UDim2.fromScale(0.75, 0.16) }
end
for _, row in { "BotPlay", "AutoCast", "LargeEffects", "ReducedMotion", "HideCosmetics" } do
	PHONE_LAYOUTS.SettingsScreen["Content.Rows." .. row .. ".Helper"] = { Visible = false }
	-- Centred at the authored height, so every name keeps the same size; the longest one gets two lines.
	PHONE_LAYOUTS.SettingsScreen["Content.Rows." .. row .. ".Label"] = if row == "HideCosmetics"
		then { Position = UDim2.fromScale(0.17, 0.12), Size = UDim2.fromScale(0.5, 0.76) }
		else { Position = UDim2.fromScale(0.17, 0.29), Size = UDim2.fromScale(0.5, 0.42) }
end

local function find(panel, path)
	local object = panel
	for part in string.gmatch(path, "[^%.]+") do
		object = object and object:FindFirstChild(part)
	end
	return object
end

function Controller:PhoneLayout(gui, panel)
	local layout = PHONE_LAYOUTS[gui.Name]
	if not layout then
		return
	end
	local class = self:Class()
	local compact = class == "Compact"
	panel:SetAttribute("ResponsiveClass", class) -- read by UI audits
	self.Layouts = self.Layouts or setmetatable({}, { __mode = "k" }) -- [child] = { Home = {}, Set = {} }
	for name, props in layout do
		local child = find(panel, name)
		if not child then
			continue
		end
		local state = self.Layouts[child]
		if not state then
			state = { Home = {}, Set = {} }
			self.Layouts[child] = state
		end
		for prop, phone in props do
			-- A value we didn't set is the screen's own (the Shop resizes its tab row for the Marbles tab).
			if state.Set[prop] == nil or child[prop] ~= state.Set[prop] then
				state.Home[prop] = child[prop]
			end
			local value = if compact then phone else state.Home[prop]
			child[prop] = value
			state.Set[prop] = value
		end
	end
end

-- Content added later (the Shop's Marbles tab resizes the tab row) gets the layout again.
function Controller:WatchLayout(gui, panel)
	local tabs = PHONE_LAYOUTS[gui.Name] and panel:FindFirstChild("Tabs")
	if tabs then
		table.insert(
			self.Connections[gui],
			tabs.ChildAdded:Connect(function()
				task.defer(self.PhoneLayout, self, gui, panel)
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
	self:WatchLayout(gui, panel)
	fit()
end

-- Touch: the coin/Marble counters sit where the thumbstick appears; put them top right instead.
-- PLAY keeps a finger-sized minimum, so on short screens it grows up into its "joins the nearest free arena" hint;
-- lift the hint clear of it.
function Controller:FitPlayHint(gui)
	local hint, play = gui:FindFirstChild("Hint"), gui:FindFirstChild("PlayButton")
	if not hint or not play or not hint:IsA("GuiObject") or not play:IsA("GuiObject") then
		return
	end
	self.HintHome = self.HintHome or hint.Position
	hint.Position = self.HintHome
	task.defer(function()
		local gap = math.max(4, math.floor(play.AbsoluteSize.Y * 0.08)) -- the button's art fills its whole box
		local overlap = hint.AbsolutePosition.Y + hint.AbsoluteSize.Y + gap - play.AbsolutePosition.Y
		if overlap > 0 then
			hint.Position = self.HintHome - UDim2.fromOffset(0, math.ceil(overlap))
		end
	end)
end

-- The smallest phones (Galaxy A06: 280 px under the top bar) shrink the Shop / Inventory buttons below a finger and
-- cut "Inventory"; grow them back towards their size on a 320 px-tall screen. The offer tiles follow (DealsController).
function Controller:FitNavigation(gui)
	local nav = gui:FindFirstChild("Navigation")
	if not nav or not nav:IsA("GuiObject") then
		return
	end
	self.NavHome = self.NavHome or nav.Size
	local height = gui.AbsoluteSize.Y
	local factor = if height > 1 then math.clamp(Tuning.NavReferenceHeight / height, 1, Tuning.NavMaxScale) else 1
	local home = self.NavHome
	local size = UDim2.new(home.X.Scale * factor, home.X.Offset, home.Y.Scale * factor, home.Y.Offset)
	if nav.Size ~= size then
		nav.Size = size
		local deals = self.Controllers and self.Controllers.DealsController
		if deals and deals.PlaceTiles then
			task.defer(deals.PlaceTiles)
		end
	end
end

-- Phones: the PLAY word fills its gem edge to edge; a slightly shorter text box gives it some air (creator).
function Controller:FitPlayLabel(gui)
	local play = gui:FindFirstChild("PlayButton")
	local label = play and play:FindFirstChild("Label")
	if not label or not label:IsA("GuiObject") then
		return
	end
	self.PlayLabelHome = self.PlayLabelHome or { label.Position, label.Size }
	local home = self.PlayLabelHome
	if self:Class() == "Compact" then
		local shrink = Tuning.CompactPlayText
		local h = home[2].Y.Scale * shrink
		label.Size = UDim2.fromScale(home[2].X.Scale, h)
		label.Position = UDim2.fromScale(home[1].X.Scale, home[1].Y.Scale + (home[2].Y.Scale - h) / 2)
	else
		label.Position, label.Size = home[1], home[2]
	end
end

function Controller:FitLobbyHud(gui)
	self:FitNavigation(gui)
	self:FitPlayHint(gui)
	self:FitPlayLabel(gui)
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
			-- Either way: the Marble "+" can also reach past the frame (it keeps a finger-sized minimum).
			if content > -math.huge and math.abs(right - content) > 1 then
				currency.Position = UDim2.new(1 - Tuning.EdgeMargin, math.floor(right - content), Tuning.EdgeMargin, 0)
			end
		end)
		-- The "+" is added (and grows) after the HUD is built; slide again when it does.
		if not self.CurrencyWatch then
			local function refit()
				if self:Touch() then
					task.defer(self.FitLobbyHud, self, gui)
				end
			end
			local function watch(child)
				if child.Name == "MarblePlus" and child:IsA("GuiObject") then
					child:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
					refit()
				end
			end
			self.CurrencyWatch = currency.DescendantAdded:Connect(watch)
			for _, child in currency:GetDescendants() do
				watch(child)
			end
		end
	else
		currency.AnchorPoint, currency.Position = self.CurrencyHome.Anchor, self.CurrencyHome.Position
		if self:Class() == "TV" then
			-- Keep the counters inside the TV safe area (overscan), like the windows.
			local home = self.CurrencyHome.Position
			currency.Position = UDim2.new(
				home.X.Scale + (1 - Tuning.SafeWidth) / 2,
				home.X.Offset,
				home.Y.Scale - (1 - Tuning.SafeHeight) / 2,
				home.Y.Offset
			)
		end
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

-- Player billboards are sized in studs: grown everywhere so the chip and HP line read, more on short phone screens.
function Controller:FitBillboard(gui)
	if gui:GetAttribute("ResponsiveScaled") then
		return
	end
	local camera = workspace.CurrentCamera
	local short = camera and math.min(camera.ViewportSize.X, camera.ViewportSize.Y) or 720
	local factor = math.clamp(
		Tuning.BillboardReferenceHeight / math.max(1, short),
		Tuning.BillboardMinScale,
		Tuning.BillboardMaxScale
	)
	if factor > 1.01 then
		gui:SetAttribute("ResponsiveScaled", true)
		local size = gui.Size
		gui.Size =
			UDim2.new(size.X.Scale * factor, size.X.Offset * factor, size.Y.Scale * factor, size.Y.Offset * factor)
		-- Grow upwards: the bottom edge stays where it was, clear of the avatar's head.
		gui.StudsOffset += Vector3.yAxis * size.Y.Scale * (factor - 1) / 2
		-- Phones: the HP line reads at a smaller size than the name and hearts (creator).
		local hp = gui:FindFirstChild("Body") and gui.Body:FindFirstChild("HpAmount")
		if hp and self:Class() == "Compact" then
			local h = hp.Size.Y.Scale * Tuning.CompactHpText
			hp.Position = UDim2.new(hp.Position.X.Scale, 0, hp.Position.Y.Scale + (hp.Size.Y.Scale - h) / 2, 0)
			hp.Size = UDim2.new(hp.Size.X.Scale, 0, h, 0)
		end
	end
end

function Controller:Added(gui)
	if gui:IsA("BillboardGui") and gui.Name:match("^FightPlayer%d$") then
		task.defer(self.FitBillboard, self, gui)
	elseif gui:IsA("ScreenGui") then
		if gui.Name == "LobbyHUD" then
			task.defer(self.FitLobbyHud, self, gui)
			-- Its size is only known once laid out (and changes with the top bar inset).
			gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				self:FitNavigation(gui)
			end)
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
