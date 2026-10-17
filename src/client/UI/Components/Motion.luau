-- Shared UI motion: button feedback, window open/close, tab slide, staggered tiles, number tick-up, toasts.
-- Everything is TweenService based (no per-frame work) and falls back to instant changes when the player
-- turns on reduced motion (PlayerGui attribute "ReducedMotion" or Roblox's own setting).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.Parent.Theme)
local UiAudio = require(script.Parent.UiAudio)
local Lighting = game:GetService("Lighting")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config.UiMotion)
local Motion = {}
local bound = setmetatable({}, { __mode = "k" })
local counters = setmetatable({}, { __mode = "k" })

Motion.Tuning = {
	WindowFrom = 0.9,
	WindowOpen = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	WindowClose = TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	WindowCloseScale = 0.92,
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

-- Primary gem buttons (green/amber/play) get a slow shine sweep and a faint breathing pulse.
local function idleShine(button, art)
	local path = art:GetAttribute("AssetPath")
	if
		art:FindFirstChild("ShineGradient")
		or button.Name:match("Tab$")
		or not (path and (path:find("gem_emerald") or path:find("gem_amber") or path:find("gem_play")))
	then
		return
	end
	local cfg = Config.Shine
	local gradient = Instance.new("UIGradient")
	gradient.Name, gradient.Rotation, gradient.Offset = "ShineGradient", 22, Vector2.new(-1.3, 0)
	local base, w = Color3.fromRGB(214, 214, 214), cfg.Width / 2
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, base),
		ColorSequenceKeypoint.new(math.clamp(0.5 - w, 0.01, 0.49), base),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(math.clamp(0.5 + w, 0.51, 0.99), base),
		ColorSequenceKeypoint.new(1, base),
	})
	gradient.Parent = art
	local pulse = Instance.new("UIScale")
	pulse.Name = "PulseScale"
	pulse.Parent = button
	task.spawn(function()
		task.wait(math.random() * cfg.Every)
		while button:IsDescendantOf(game) do
			if not Motion.reduced() and button.Visible and button.AbsoluteSize.X > 0 and button.Active then
				gradient.Offset = Vector2.new(-1.3, 0)
				TweenService:Create(
					gradient,
					TweenInfo.new(cfg.Seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
					{ Offset = Vector2.new(1.3, 0) }
				):Play()
			end
			task.wait(cfg.Every)
		end
	end)
	TweenService:Create(
		pulse,
		TweenInfo.new(Config.Pulse.Seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1 + Config.Pulse.Scale }
	):Play()
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
	if art and art:IsA("ImageLabel") then
		idleShine(button, art)
	end
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
-- Menu ambience: blur + FOV pull-in while any window is open (skipped during matches), restored exactly.
local ambience = { Count = 0 }
local function ambienceOn()
	local gui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if gui and gui:GetAttribute("InMatch") then
		return false
	end
	ambience.Count += 1
	if ambience.Count > 1 then
		return true
	end
	local camera = workspace.CurrentCamera
	local blur = Lighting:FindFirstChild("UiBlur") or Instance.new("BlurEffect")
	blur.Name, blur.Size, blur.Parent = "UiBlur", 0, Lighting
	ambience.Blur, ambience.BaseFov, ambience.Camera = blur, camera and camera.FieldOfView, camera
	if ambience.Tweens then
		for _, t in ambience.Tweens do
			t:Cancel()
		end
	end
	ambience.Tweens = {
		TweenService:Create(
			blur,
			TweenInfo.new(Config.Blur.InSeconds, Enum.EasingStyle.Quad),
			{ Size = Config.Blur.Size }
		),
	}
	if camera then
		table.insert(
			ambience.Tweens,
			TweenService:Create(
				camera,
				TweenInfo.new(Config.Fov.InSeconds, Enum.EasingStyle.Quad),
				{ FieldOfView = ambience.BaseFov + Config.Fov.Delta }
			)
		)
	end
	for _, t in ambience.Tweens do
		t:Play()
	end
	return true
end
local function ambienceOff()
	ambience.Count = math.max(0, ambience.Count - 1)
	if ambience.Count > 0 then
		return
	end
	for _, t in ambience.Tweens or {} do
		t:Cancel()
	end
	local blur, camera, base = ambience.Blur, ambience.Camera, ambience.BaseFov
	if camera and base and camera.Parent then
		TweenService:Create(camera, TweenInfo.new(Config.Fov.OutSeconds, Enum.EasingStyle.Quad), { FieldOfView = base })
			:Play()
		task.delay(Config.Fov.OutSeconds + 0.02, function()
			if ambience.Count == 0 then
				camera.FieldOfView = base -- exact restore even if a tween was interrupted
			end
		end)
	end
	if blur then
		local out =
			TweenService:Create(blur, TweenInfo.new(Config.Blur.OutSeconds, Enum.EasingStyle.Quad), { Size = 0 })
		out:Play()
		out.Completed:Connect(function()
			if ambience.Count == 0 and blur.Parent then
				blur:Destroy()
			end
		end)
	end
end
-- Properties that fade an element out, by class (only the ones that exist on it are tweened).
local FADE = {
	Frame = { "BackgroundTransparency" },
	TextLabel = { "BackgroundTransparency", "TextTransparency", "TextStrokeTransparency" },
	TextButton = { "BackgroundTransparency", "TextTransparency", "TextStrokeTransparency" },
	ImageLabel = { "BackgroundTransparency", "ImageTransparency" },
	ImageButton = { "BackgroundTransparency", "ImageTransparency" },
	ViewportFrame = { "BackgroundTransparency", "ImageTransparency" },
	ScrollingFrame = { "BackgroundTransparency" },
}
local function fadeOut(panel, info)
	local count = 0
	for _, object in panel:GetDescendants() do
		local props = FADE[object.ClassName]
		if props then
			local goal = {}
			for _, prop in props do
				if object[prop] < 1 then
					goal[prop] = 1
				end
			end
			if next(goal) then
				count += 1
				if count > 700 then
					return
				end
				TweenService:Create(object, info, goal):Play()
			end
		end
	end
end

-- Window pop: quick scale-in with a light Back ease; closing scales down a touch while everything fades.
-- No backdrop dim (Config.Dim = 0); the menu ambience (blur + FOV) is the only background change.
function Motion.windowIn(gui, panel, instant)
	local T = Motion.Tuning
	local scale = panel:FindFirstChild("OpenScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name, scale.Parent = "OpenScale", panel
	end
	local reduced = instant or Motion.reduced()
	local ambient = ambienceOn()
	local released = false
	local function release()
		if ambient and not released then
			released = true
			ambienceOff()
		end
	end
	gui.Destroying:Connect(release)
	if reduced then
		scale.Scale = 1
	else
		scale.Scale = T.WindowFrom
		TweenService:Create(scale, T.WindowOpen, { Scale = 1 }):Play()
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
			release()
			if reduced or Motion.reduced() then
				done()
				return
			end
			TweenService:Create(scale, T.WindowClose, { Scale = T.WindowCloseScale }):Play()
			fadeOut(panel, T.WindowClose)
			task.delay(T.WindowClose.Time + 0.02, done)
		end,
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
