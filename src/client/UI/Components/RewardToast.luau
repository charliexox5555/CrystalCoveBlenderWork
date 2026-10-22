-- A small, quiet reward notice (decision 115): pictures and numbers, no sentence, e.g. [coin] +75 [clock].
-- Used when a Playtime gift collects itself. It slides in at the top left, under the Roblox top bar (inside the core
-- UI safe insets, clear of the fight headline in the middle and the CAST button at the bottom right), holds, and
-- slides out; several notices queue. Reduced motion fades instead of sliding.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Parent.Theme)
local Motion = require(script.Parent.Motion)
local UiAudio = require(script.Parent.UiAudio)
local Toast = {}

local HOLD, SLIDE = 2.4, 0.25
local HEIGHT, ICON = 40, 30
local queue, running = {}, false

local function gui()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = pg:FindFirstChild("RewardToast")
	if not screen then
		screen = Instance.new("ScreenGui")
		screen.Name, screen.ResetOnSpawn, screen.DisplayOrder = "RewardToast", false, 40
		screen.ScreenInsets, screen.ZIndexBehavior = Enum.ScreenInsets.CoreUISafeInsets, Enum.ZIndexBehavior.Sibling
		screen.Parent = pg
	end
	return screen
end

-- chips: { { Image = id, Text = "+75" }, ... }; tag: an optional small picture at the end (the playtime clock).
local function build(chips, tag)
	local pill = Instance.new("Frame")
	pill.Name = "Toast"
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(0, HEIGHT)
	pill.BackgroundColor3, pill.BackgroundTransparency = Theme.Palette.lead, 0.18
	pill.BorderSizePixel = 0
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.Transparency = Theme.Palette.amberLight, 2, 0.1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = pill
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 10)
	pad.Parent = pill
	local list = Instance.new("UIListLayout")
	list.FillDirection, list.VerticalAlignment = Enum.FillDirection.Horizontal, Enum.VerticalAlignment.Center
	list.Padding, list.SortOrder = UDim.new(0, 6), Enum.SortOrder.LayoutOrder
	list.Parent = pill
	local order = 0
	local function image(id, size, transparency)
		order += 1
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency, img.Image, img.ScaleType = 1, id or "", Enum.ScaleType.Fit
		img.Size, img.LayoutOrder, img.ImageTransparency = UDim2.fromOffset(size, size), order, transparency or 0
		img.Parent = pill
	end
	for _, chip in chips do
		image(chip.Image, ICON)
		order += 1
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency, label.Text, label.LayoutOrder = 1, chip.Text, order
		label.FontFace, label.TextSize, label.TextColor3 = Theme.Fonts.Heading, 24, Theme.Colors.Text
		label.AutomaticSize, label.Size = Enum.AutomaticSize.X, UDim2.fromOffset(0, HEIGHT)
		label:SetAttribute("TextFit", false) -- a fixed small size; the pill grows with it
		local outline = Instance.new("UIStroke")
		outline.Color, outline.Thickness = Theme.Colors.Shadow, 1.5
		outline.Parent = label
		label.Parent = pill
	end
	if tag then
		image(tag, 22, 0.25)
	end
	return pill
end

local function play(entry)
	local screen = gui()
	local pill = build(entry.Chips, entry.Tag)
	local reduced = Motion.reduced()
	local shown, hidden = UDim2.fromOffset(12, 10), UDim2.new(0, -12, 0, 10)
	pill.AnchorPoint = Vector2.new(0, 0)
	pill.Position = if reduced then shown else hidden
	pill.Parent = screen
	if not reduced then
		-- Start fully off screen to the left once the pill has measured itself.
		task.wait()
		pill.Position = UDim2.new(0, -pill.AbsoluteSize.X - 12, 0, 10)
	end
	local fade = {}
	for _, d in pill:GetDescendants() do
		if d:IsA("ImageLabel") then
			fade[d] = { ImageTransparency = d.ImageTransparency }
		elseif d:IsA("TextLabel") then
			fade[d] = { TextTransparency = 0 }
		end
	end
	if reduced then
		pill.BackgroundTransparency = 1
		for d in fade do
			if d:IsA("ImageLabel") then
				d.ImageTransparency = 1
			else
				d.TextTransparency = 1
			end
		end
		TweenService:Create(pill, TweenInfo.new(SLIDE), { BackgroundTransparency = 0.18 }):Play()
		for d, goal in fade do
			TweenService:Create(d, TweenInfo.new(SLIDE), goal):Play()
		end
	else
		TweenService:Create(pill, TweenInfo.new(SLIDE, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = shown,
		}):Play()
	end
	UiAudio.play("Sparkle")
	task.wait(SLIDE + HOLD)
	local out = if reduced
		then TweenService:Create(pill, TweenInfo.new(SLIDE), { BackgroundTransparency = 1 })
		else TweenService:Create(pill, TweenInfo.new(SLIDE, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0, -pill.AbsoluteSize.X - 12, 0, 10),
		})
	if reduced then
		for d in fade do
			TweenService:Create(
				d,
				TweenInfo.new(SLIDE),
				if d:IsA("ImageLabel") then { ImageTransparency = 1 } else { TextTransparency = 1 }
			):Play()
		end
	end
	out:Play()
	task.wait(SLIDE)
	pill:Destroy()
end

-- Where a toast sits (in the core UI safe-inset space the HUD and CurrencyGain use), for coin bursts.
function Toast.origin(): Vector2
	return Vector2.new(12 + HEIGHT * 1.5, 10 + HEIGHT / 2)
end

function Toast.show(chips, tag)
	if #chips == 0 then
		return
	end
	table.insert(queue, { Chips = chips, Tag = tag })
	if running then
		return
	end
	running = true
	task.spawn(function()
		while #queue > 0 do
			local ok, err = pcall(play, table.remove(queue, 1))
			if not ok then
				warn("RewardToast:", err)
			end
		end
		running = false
	end)
end

return Toast
