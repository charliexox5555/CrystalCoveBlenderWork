-- Shared UI motion: button feedback, window open/close, tab slide, staggered tiles, number tick-up, toasts.
-- Everything is TweenService based (no per-frame work) and falls back to instant changes when the player
-- turns on reduced motion (PlayerGui attribute "ReducedMotion" or Roblox's own setting).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.Parent.Theme)
local UiAudio = require(script.Parent.UiAudio)
local Motion = {}
local bound = setmetatable({}, { __mode = "k" })
local counters = setmetatable({}, { __mode = "k" })

Motion.Tuning = {
	WindowFrom = 0.9,
	WindowOpen = TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	WindowClose = TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	WindowCloseScale = 0.94,
	DimTransparency = 0.5,
	DimSeconds = 0.2,
	HoverScale = 1.045,
	PressScale = 0.94,
	HoverTween = TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	PressTween = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	PressTint = Color3.fromRGB(215, 215, 225),
	TileFrom = 0.8,
	TileTween = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	TileStep = 0.03,
	TileMaxDelay = 0.36,
	SlidePixels = 18,
	SlideTween = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	CountSeconds = 0.45,
	ToastRise = 22,
	ToastIn = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	ToastOut = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
}

function Motion.reduced()
	local gui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if gui and gui:GetAttribute("ReducedMotion") == true then
		return true
	end
	local ok, value = pcall(function()
		return UserSettings():GetService("UserGameSettings").ReducedMotion
	end)
	return ok and value == true
end

function Motion.center(object)
	if object.AnchorPoint == Vector2.new(0.5, 0.5) then
		return
	end
	local p, s, a = object.Position, object.Size, object.AnchorPoint
	object.Position = UDim2.new(
		p.X.Scale + s.X.Scale * (0.5 - a.X),
		p.X.Offset + s.X.Offset * (0.5 - a.X),
		p.Y.Scale + s.Y.Scale * (0.5 - a.Y),
		p.Y.Offset + s.Y.Offset * (0.5 - a.Y)
	)
	object.AnchorPoint = Vector2.new(0.5, 0.5)
end

local function accepts(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.ButtonA
end

-- Hover grows with a little overshoot, press shrinks and darkens the glass, release springs back.
function Motion.button(button)
	if not button:IsA("GuiButton") then
		return
	end
	Motion.center(button)
	if bound[button] then
		return
	end
	bound[button] = true
	local target = if button.Name == "Open" then button.Parent else button
	Motion.center(target)
	local scale = target:FindFirstChild("InteractionScale") or Instance.new("UIScale")
	scale.Name, scale.Parent = "InteractionScale", target
	local art = button:FindFirstChild("Artwork")
	local rest = if art and art:IsA("ImageLabel") then art.ImageColor3 else nil
	local hovering, pressing, tween, tint = false, false, nil, nil
	local T = Motion.Tuning
	local function refresh()
		if tween then
			tween:Cancel()
		end
		if tint then
			tint:Cancel()
		end
		local value = if not button.Active
			then 1
			elseif pressing then T.PressScale
			elseif hovering then T.HoverScale
			else 1
		if Motion.reduced() then
			scale.Scale = value
			return
		end
		tween = TweenService:Create(scale, if pressing then T.PressTween else T.HoverTween, { Scale = value })
		tween:Play()
		if rest then
			tint = TweenService:Create(art, T.PressTween, { ImageColor3 = if pressing then T.PressTint else rest })
			tint:Play()
		end
	end
	button.MouseEnter:Connect(function()
		hovering = true
		if UserInputService.MouseEnabled and button.Active then
			UiAudio.play("Hover")
		end
		refresh()
	end)
	button.MouseLeave:Connect(function()
		hovering, pressing = false, false
		refresh()
	end)
	button.SelectionGained:Connect(function()
		hovering = true
		refresh()
	end)
	button.SelectionLost:Connect(function()
		hovering, pressing = false, false
		refresh()
	end)
	button.InputBegan:Connect(function(input)
		if accepts(input) then
			pressing = true
			refresh()
		end
	end)
	button.InputEnded:Connect(function(input)
		if accepts(input) then
			pressing = false
			refresh()
		end
	end)
	button.Activated:Connect(function()
		if not button.Active then
			return
		end
		UiAudio.play(if button.Name == "Close" then "Close" elseif button.Name:match("Tab$") then "Tab" else "Click")
	end)
	button:GetPropertyChangedSignal("Active"):Connect(refresh)
end

-- Window: dimmed backdrop + scale-in with overshoot. Returns { Close = function(done) }.
-- `instant` (a refresh of a window that was just closed) skips the animation and sound.
function Motion.windowIn(gui, panel, instant)
	local T = Motion.Tuning
	local scale = panel:FindFirstChild("OpenScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name, scale.Parent = "OpenScale", panel
	end
	local dimGui = Instance.new("ScreenGui")
	dimGui.Name, dimGui.ResetOnSpawn = gui.Name .. "Dim", false
	dimGui.DisplayOrder, dimGui.ScreenInsets = gui.DisplayOrder - 1, Enum.ScreenInsets.None
	dimGui.IgnoreGuiInset = true
	local dim = Instance.new("Frame")
	dim.Name, dim.Size, dim.BorderSizePixel = "Dim", UDim2.fromScale(1, 1), 0
	dim.BackgroundColor3, dim.BackgroundTransparency = Theme.Palette.lead, 1
	dim.Active = false
	dim.Parent = dimGui
	dimGui.Parent = gui.Parent
	gui.Destroying:Connect(function()
		dimGui:Destroy()
	end)
	local reduced = instant or Motion.reduced()
	if reduced then
		scale.Scale, dim.BackgroundTransparency = 1, T.DimTransparency
	else
		scale.Scale = T.WindowFrom
		TweenService:Create(scale, T.WindowOpen, { Scale = 1 }):Play()
		TweenService
			:Create(
				dim,
				TweenInfo.new(T.DimSeconds, Enum.EasingStyle.Quad),
				{ BackgroundTransparency = T.DimTransparency }
			)
			:Play()
	end
	if not instant then
		UiAudio.play("Open")
	end
	local closing = false
	return {
		Close = function(done)
			if closing then
				return
			end
			closing = true
			if reduced or Motion.reduced() then
				dimGui:Destroy()
				done()
				return
			end
			TweenService:Create(scale, T.WindowClose, { Scale = T.WindowCloseScale }):Play()
			TweenService:Create(dim, T.WindowClose, { BackgroundTransparency = 1 }):Play()
			task.delay(T.WindowClose.Time + 0.02, function()
				dimGui:Destroy()
				done()
			end)
		end,
		Dim = dimGui,
	}
end

-- Content slides a few pixels into place (tab switches). The rest position is remembered on the object.
function Motion.slideIn(object, pixels)
	local rest = object:GetAttribute("RestPosition")
	if typeof(rest) ~= "UDim2" then
		rest = object.Position
		object:SetAttribute("RestPosition", rest)
	end
	if Motion.reduced() then
		object.Position = rest
		return
	end
	local dy = pixels or Motion.Tuning.SlidePixels
	object.Position = UDim2.new(rest.X.Scale, rest.X.Offset, rest.Y.Scale, rest.Y.Offset + dy)
	TweenService:Create(object, Motion.Tuning.SlideTween, { Position = rest }):Play()
end

-- Quick bump on a selected tab or badge.
function Motion.bump(object, amount)
	if Motion.reduced() then
		return
	end
	local scale = object:FindFirstChild("BumpScale") or Instance.new("UIScale")
	scale.Name, scale.Parent, scale.Scale = "BumpScale", object, 1 + (amount or 0.08)
	TweenService:Create(scale, Motion.Tuning.HoverTween, { Scale = 1 }):Play()
end

-- Tiles pop in one after another (scale with overshoot), capped so big grids don't drag.
function Motion.stagger(objects)
	if Motion.reduced() then
		return
	end
	local T = Motion.Tuning
	for index, object in objects do
		if not object.Parent then
			continue
		end
		local scale = object:FindFirstChild("EntranceScale") or Instance.new("UIScale")
		scale.Name, scale.Parent, scale.Scale = "EntranceScale", object, T.TileFrom
		task.delay(math.min((index - 1) * T.TileStep, T.TileMaxDelay), function()
			if scale.Parent then
				TweenService:Create(scale, T.TileTween, { Scale = 1 }):Play()
			end
		end)
	end
end

-- Currency labels count to their new value. The first call sets the text directly.
function Motion.countTo(label, value, format)
	format = format or tostring
	local state = counters[label]
	if not state then
		local number = Instance.new("NumberValue")
		number.Value = value
		state = { Number = number, Format = format }
		counters[label] = state
		number.Changed:Connect(function(current)
			label.Text = state.Format(math.round(current))
		end)
		label.Destroying:Connect(function()
			number:Destroy()
			counters[label] = nil
		end)
		label.Text = format(value)
		return
	end
	state.Format = format
	if state.Tween then
		state.Tween:Cancel()
	end
	if Motion.reduced() or state.Number.Value == value then
		state.Number.Value = value
		label.Text = format(value)
		return
	end
	local info = TweenInfo.new(Motion.Tuning.CountSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	state.Tween = TweenService:Create(state.Number, info, { Value = value })
	state.Tween:Play()
	Motion.bump(label, 0.12)
end

-- Notice text rises and fades in, holds, then fades out and calls `done`.
function Motion.toast(label, hold, done)
	local rest = label.Position
	local function finish()
		if done then
			done()
		end
	end
	if Motion.reduced() then
		task.delay(hold, finish)
		return
	end
	local T = Motion.Tuning
	label.Position = UDim2.new(rest.X.Scale, rest.X.Offset, rest.Y.Scale, rest.Y.Offset + T.ToastRise)
	label.TextTransparency = 1
	TweenService:Create(label, T.ToastIn, { Position = rest, TextTransparency = 0 }):Play()
	task.delay(hold, function()
		if label.Parent then
			TweenService:Create(label, T.ToastOut, { TextTransparency = 1 }):Play()
		end
		task.delay(T.ToastOut.Time, finish)
	end)
end

return Motion
