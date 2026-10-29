-- Settings (decision 99): applies the player's choices and drives StarterGui.SettingsScreen (design:
-- docs/ui/screens/SettingsScreen.md). Volumes set the AudioGroups sliders' SoundGroups; toggles are stamped on
-- PlayerGui as attributes that presentation code reads (LocalSettings, Motion.reduced). SettingsService saves.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Remotes = require(RS.Shared.Remotes)
local Settings = require(RS.Shared.Config.Settings)
local AudioGroups = require(script.Parent.Parent.AudioGroups)
local UiAudio = require(script.Parent.Parent.UI.Components.UiAudio)
local GamepadNav = require(script.Parent.Parent.UI.Components.GamepadNav)
local Motion = require(script.Parent.Parent.UI.Components.Motion)
local Controller = {}

local SEND_EVERY = 0.25 -- while dragging a slider, at most one save request per this many seconds
local KNOB_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local OFF_TEXT = Color3.fromHex("#B7B3CC")

function Controller:Init()
	self.Player = Players.LocalPlayer
	self.Values = Settings.normalize(nil)
	self.Sent = {}
end

function Controller:Apply()
	local v = self.Values
	AudioGroups.master().Volume = v.Master
	AudioGroups.music().Volume = v.Music
	AudioGroups.sfx().Volume = v.SFX
	local pg = self.Player:FindFirstChildOfClass("PlayerGui")
	if pg then
		pg:SetAttribute("LargeEffects", v.LargeEffects)
		pg:SetAttribute("AutoCast", v.AutoCast)
		pg:SetAttribute("HideCosmetics", v.HideCosmetics)
		-- Only force it on: off leaves Roblox's own Reduced Motion setting in charge (Motion.reduced).
		pg:SetAttribute("ReducedMotion", if v.ReducedMotion then true else nil)
	end
	self:Render(false)
end

-- Change one value locally (instant feedback) and ask the server to save it.
function Controller:Set(key, value, send)
	local updated = Settings.change(self.Values, key, value)
	if not updated then
		return
	end
	self.Values = updated
	self:Apply()
	if send then
		self.Sent[key] = os.clock()
		Remotes.SetSetting:FireServer(key, updated[key])
	end
end

-- Screen ---------------------------------------------------------------------------------------------------------

local function renderSlider(row, value)
	local slider = row:FindFirstChild("Slider")
	local track = slider and slider:FindFirstChild("Track")
	if not track then
		return
	end
	slider:SetAttribute("Value", value)
	local fill, knob = track:FindFirstChild("Fill"), track:FindFirstChild("Knob")
	if fill then
		fill.Size = UDim2.fromScale(value, fill.Size.Y.Scale)
		fill.Visible = value > 0
	end
	if knob then
		knob.Position = UDim2.new(value, 0, knob.Position.Y.Scale, knob.Position.Y.Offset)
	end
	local plaque = row:FindFirstChild("Value")
	local text = plaque and plaque:FindFirstChild("Text")
	if text then
		text.Text = math.round(value * 100) .. "%"
	end
	local icon = row:FindFirstChild("Icon")
	if icon then
		icon.ImageTransparency = if value <= 0 then 0.55 else 0
	end
end

local function renderToggle(row, on, animate)
	local toggle = row:FindFirstChild("Toggle")
	if not toggle then
		return
	end
	toggle:SetAttribute("On", on)
	local track, knob, state =
		toggle:FindFirstChild("Track"), toggle:FindFirstChild("Knob"), toggle:FindFirstChild("State")
	local image = toggle:GetAttribute(if on then "OnImage" else "OffImage")
	if track and type(image) == "string" then
		track.Image = image
	end
	if knob then
		local x = toggle:GetAttribute(if on then "KnobOnX" else "KnobOffX") or (if on then 0.76 else 0.24)
		local goal = UDim2.new(x, 0, knob.Position.Y.Scale, knob.Position.Y.Offset)
		if animate then
			TweenService:Create(knob, KNOB_TWEEN, { Position = goal }):Play()
		else
			knob.Position = goal
		end
	end
	if state then
		state.Text = if on then "ON" else "OFF"
		state.TextColor3 = if on then Color3.new(1, 1, 1) else OFF_TEXT
		state.Position = UDim2.new(if on then 0.38 else 0.62, 0, state.Position.Y.Scale, state.Position.Y.Offset)
	end
end

function Controller:Render(animate)
	local rows = self.Rows
	if not rows then
		return
	end
	for _, key in Settings.Sliders do
		local row = rows:FindFirstChild(key)
		if row and self.Dragging ~= key then
			renderSlider(row, self.Values[key])
		end
	end
	for _, key in Settings.Toggles do
		local row = rows:FindFirstChild(key)
		if row then
			renderToggle(row, self.Values[key], animate)
		end
	end
end

function Controller:WireSlider(row, key)
	local slider = row:FindFirstChild("Slider")
	local track = slider and slider:FindFirstChild("Track")
	if not (slider and slider:IsA("GuiButton") and track) then
		return
	end
	local function at(x)
		return math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
	end
	local function move(x, final)
		local value = at(x)
		local due = final or os.clock() - (self.Sent[key] or 0) >= SEND_EVERY
		self:Set(key, value, due)
		renderSlider(row, self.Values[key])
	end
	slider.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			self.Dragging, self.DragInput = key, input
			move(input.Position.X, false)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if self.Dragging ~= key then
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseMovement or (t == Enum.UserInputType.Touch and input == self.DragInput) then
			move(input.Position.X, false)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if self.Dragging ~= key then
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or (t == Enum.UserInputType.Touch and input == self.DragInput) then
			move(input.Position.X, true)
			self.Dragging, self.DragInput = nil, nil
		end
	end)
	-- Gamepad / keyboard selection: left and right step by 10%. On a controller, A grabs the slider first (the
	-- selection glows aqua and left / right stop moving between rows), then A or B lets go.
	slider.SelectionGained:Connect(function()
		self.Selected = key
	end)
	slider.SelectionLost:Connect(function()
		if self.Selected == key then
			self.Selected = nil
		end
		if self.Editing == key then
			self:Edit(nil)
		end
	end)
	slider.Activated:Connect(function()
		if GamepadNav.usingGamepad() and GuiService.SelectedObject == slider then
			self:Edit(if self.Editing == key then nil else key)
		end
	end)
	self.SliderButtons = self.SliderButtons or {}
	self.SliderButtons[key] = slider
end

-- Grab (key) or let go (nil) of a slider for controller stepping.
function Controller:Edit(key)
	local previous = self.Editing and self.SliderButtons[self.Editing]
	if previous then
		previous.SelectionBehaviorLeft, previous.SelectionBehaviorRight =
			Enum.SelectionBehavior.Escape, Enum.SelectionBehavior.Escape
	end
	self.Editing = key
	local slider = key and self.SliderButtons[key]
	if slider then
		slider.SelectionBehaviorLeft, slider.SelectionBehaviorRight =
			Enum.SelectionBehavior.Stop, Enum.SelectionBehavior.Stop
		GamepadNav.setEditing(function()
			self:Edit(nil)
		end)
	else
		GamepadNav.setEditing(nil)
	end
end

function Controller:WireToggle(row, key)
	local toggle = row:FindFirstChild("Toggle")
	if not (toggle and toggle:IsA("GuiButton")) then
		return
	end
	toggle.Activated:Connect(function()
		self:Set(key, not self.Values[key], true)
		renderToggle(row, self.Values[key], true)
		UiAudio.play("Tab")
	end)
end

-- Hover on a slider or toggle: only the row's icon reacts (grows a little and brightens); the controls themselves
-- don't scale (creator feedback). Their buttons opt out of the shared Motion.button hover.
local ICON_HOVER = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function hoverIcon(row, control)
	control:SetAttribute("NoHoverMotion", true)
	local icon = row:FindFirstChild("Icon")
	if not icon then
		return
	end
	-- Grow from the icon's centre (its authored anchor is a corner), and only a little so it stays in its slot.
	Motion.center(icon)
	local scale = icon:FindFirstChild("HoverScale") or Instance.new("UIScale")
	scale.Name, scale.Parent = "HoverScale", icon
	local function set(on)
		TweenService:Create(scale, ICON_HOVER, { Scale = if on then 1.07 else 1 }):Play()
		TweenService
			:Create(icon, ICON_HOVER, { ImageColor3 = if on then Color3.fromHex("#9BF3F8") else Color3.new(1, 1, 1) })
			:Play()
	end
	control.MouseEnter:Connect(function()
		set(true)
	end)
	control.MouseLeave:Connect(function()
		set(false)
	end)
	control.SelectionGained:Connect(function()
		set(true)
	end)
	control.SelectionLost:Connect(function()
		set(false)
	end)
end

function Controller:Wire(gui)
	local content = gui:FindFirstChild("Content", true)
	local rows = content and content:FindFirstChild("Rows")
	if not rows then
		warn("[GlassClash] SettingsScreen has no Content.Rows; settings still apply but the screen is not wired")
		return
	end
	self.Rows = rows
	-- Casting is automatic in classic combat. Keep the saved preference for compatibility,
	-- but do not show an obsolete combat-control toggle.
	local auto = rows:FindFirstChild("AutoCast")
	if auto and require(RS.Shared.Config.Balance).CombatRelease.Cast.ManualEnabled == false then
		auto.Visible = false
		for _, control in auto:GetDescendants() do
			if control:IsA("GuiButton") then
				control.Active, control.Selectable = false, false
			end
		end
	end
	for _, row in rows:GetChildren() do
		local control = row:FindFirstChild("Slider") or row:FindFirstChild("Toggle")
		if control and control:IsA("GuiButton") then
			hoverIcon(row, control)
			-- A scale bound before this ran (StainedGlass.bindSlices) is reset to rest.
			local bound = control:FindFirstChild("InteractionScale")
			if bound then
				bound.Scale = 1
			end
		end
	end
	for _, key in Settings.Sliders do
		local row = rows:FindFirstChild(key)
		if row then
			self:WireSlider(row, key)
		end
	end
	for _, key in Settings.Toggles do
		local row = rows:FindFirstChild(key)
		if row then
			self:WireToggle(row, key)
		end
	end
	UserInputService.InputBegan:Connect(function(input)
		local key = self.Selected
		if not key or not gui.Enabled then
			return
		end
		-- Keyboard arrows step a selected slider; the D-pad only while it is grabbed (else it moves between rows).
		local grabbed = self.Editing == key
		local step = if input.KeyCode == Enum.KeyCode.Left or (grabbed and input.KeyCode == Enum.KeyCode.DPadLeft)
			then -0.1
			elseif input.KeyCode == Enum.KeyCode.Right or (grabbed and input.KeyCode == Enum.KeyCode.DPadRight) then 0.1
			else 0
		if step ~= 0 then
			self:Set(key, math.clamp(self.Values[key] + step, 0, 1), true)
		end
	end)
	-- The left stick steps a grabbed slider too, a step every 0.2 s while held over.
	UserInputService.InputChanged:Connect(function(input)
		local key = self.Editing
		if not key or not gui.Enabled or input.KeyCode ~= Enum.KeyCode.Thumbstick1 then
			return
		end
		local x = input.Position.X
		if math.abs(x) > 0.6 and os.clock() - (self.StickStep or 0) > 0.2 then
			self.StickStep = os.clock()
			self:Set(key, math.clamp(self.Values[key] + (if x > 0 then 0.1 else -0.1), 0, 1), true)
		end
	end)
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not gui.Enabled and self.Editing then
			self:Edit(nil)
		end
	end)
	self:Render(false)
end

function Controller:Start()
	local pg = self.Player:WaitForChild("PlayerGui")
	AudioGroups.route({ workspace, SoundService, pg })
	self:Apply()
	Remotes.Settings.OnClientEvent:Connect(function(values)
		-- Keep a slider the player is holding under their finger; everything else follows the server's copy.
		local incoming = Settings.normalize(values)
		if self.Dragging then
			incoming[self.Dragging] = self.Values[self.Dragging]
		end
		self.Values = incoming
		self:Apply()
	end)
	Remotes.RequestSettings:FireServer()
	local gui = pg:WaitForChild("SettingsScreen", 30)
	if gui then
		self:Wire(gui)
	end
end

return Controller
