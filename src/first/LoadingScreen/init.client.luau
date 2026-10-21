--!strict
-- Glass Clash loading screen (ReplicatedFirst, so it is the first thing a player sees). Roblox's default screen is
-- replaced by the clash show (Clash), while the Essential tier preloads (Preload, Shared.Config.LoadTiers): the
-- first-minute UI, fonts and the spawn area. It closes when that is done and the game has loaded, with guards so
-- nobody gets stuck: SKIP shows after SKIP_AFTER seconds and the screen closes by itself after MAX_SECONDS. Then
-- the Soon and Later tiers load in the background (Preload.release).
-- When it is gone it sets the local Player attribute ClientLoaded = true (OnboardingController waits for it).
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")
local Art = require(script:WaitForChild("Art"))
local Clash = require(script:WaitForChild("Clash"))
local Preload = require(script:WaitForChild("Preload"))

local MIN_SECONDS = 2.4
local MIN_SHOW = 1.6 -- the clash is on screen at least this long (the first hit lands at ~1 s)
local SKIP_AFTER = 10
local MAX_SECONDS = 30
local W, H = 1920, 1080

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local started = os.clock()

local function at(x: number, y: number): UDim2
	return UDim2.fromScale(x / W, y / H)
end

local function size(w: number, h: number): UDim2
	return UDim2.fromScale(w / W, h / H)
end

local function make(class: string, parent: Instance, props: { [string]: any }): any
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end

local function stroke(parent: Instance, thickness: number, color: Color3?)
	return make("UIStroke", parent, { Thickness = thickness, Color = color or Art.Colors.lead })
end

local function corner(parent: Instance, radius: UDim?)
	return make("UICorner", parent, { CornerRadius = radius or UDim.new(0.5, 0) })
end

-- Screen ---------------------------------------------------------------------------------------------------------
local gui = make("ScreenGui", playerGui, {
	Name = "LoadingScreen",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 10000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local root = make("Frame", gui, {
	Name = "Root",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Art.Colors.smoke,
	BorderSizePixel = 0,
})
local backdrop = make("ImageLabel", root, {
	Name = "Backdrop",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Image = Art.Images.backdrop,
	ScaleType = Enum.ScaleType.Crop,
	ImageTransparency = 1,
})
-- Tapping anywhere swings the glassies again.
local tap = make("TextButton", root, {
	Name = "Tap",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 1,
})
-- Everything else sits in a 16:9 stage laid out in 1920x1080 design pixels.
local stage = make("Frame", root, {
	Name = "Stage",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 2,
})
make("UIAspectRatioConstraint", stage, { AspectRatio = 16 / 9, AspectType = Enum.AspectType.FitWithinMaxSize })

local title = make("TextLabel", stage, {
	Name = "Title",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = at(960, 132),
	Size = size(1100, 150),
	BackgroundTransparency = 1,
	Text = "GLASS CLASH",
	FontFace = Art.Heading,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	ZIndex = 9,
})
make("UIGradient", title, {
	Rotation = 90,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Art.Colors.cream),
		ColorSequenceKeypoint.new(0.55, Art.Colors.amberLight),
		ColorSequenceKeypoint.new(1, Art.Colors.amber),
	}),
})
stroke(title, 6)

local status = make("TextLabel", stage, {
	Name = "Status",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = at(960, 926), -- clear of the bar's outline on short phone screens
	Size = size(900, 44),
	BackgroundTransparency = 1,
	Text = "Joining...",
	FontFace = Art.Heading,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	ZIndex = 9,
})
stroke(status, 3)

local bar = make("Frame", stage, {
	Name = "Bar",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = at(960, 992),
	Size = size(800, 44),
	BackgroundColor3 = Art.Colors.smoke2,
	BorderSizePixel = 0,
	ZIndex = 9,
})
corner(bar)
stroke(bar, 4)
local fill = make("Frame", bar, {
	Name = "Fill",
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	ZIndex = 10,
})
corner(fill)
make("UIGradient", fill, {
	Rotation = 90,
	Color = ColorSequence.new(Art.Colors.amberLight, Art.Colors.amber),
})
make("Frame", fill, {
	Name = "Shine",
	Position = UDim2.fromScale(0.02, 0.16),
	Size = UDim2.fromScale(0.96, 0.2),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.55,
	BorderSizePixel = 0,
	ZIndex = 11,
})
-- Lead lines split the bar into ten glass panes.
for i = 1, 9 do
	make("Frame", bar, {
		Name = "Lead" .. i,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(i / 10, 0),
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = Art.Colors.lead,
		BorderSizePixel = 0,
		ZIndex = 12,
	})
end
local percent = make("TextLabel", stage, {
	Name = "Percent",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = at(960, 1044),
	Size = size(240, 38),
	BackgroundTransparency = 1,
	Text = "0%",
	FontFace = Art.Heading,
	TextScaled = true,
	TextColor3 = Art.Colors.amberLight,
	ZIndex = 9,
})
stroke(percent, 3)

local skip = make("TextButton", stage, {
	Name = "Skip",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = at(1860, 1000),
	Size = size(190, 66),
	BackgroundColor3 = Art.Colors.lead,
	Text = "SKIP",
	FontFace = Art.Heading,
	TextScaled = true,
	TextColor3 = Art.Colors.amberLight,
	AutoButtonColor = true,
	Visible = false,
	ZIndex = 20,
})
corner(skip, UDim.new(0.3, 0))
make("UIStroke", skip, {
	Thickness = 3,
	Color = Art.Colors.amber,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
})
make("UIPadding", skip, {
	PaddingTop = UDim.new(0.2, 0),
	PaddingBottom = UDim.new(0.2, 0),
})

-- The quick dip at the end: fade to smoke, drop the screen, fade the lobby in.
local veil = make("Frame", gui, {
	Name = "Veil",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Art.Colors.smoke,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 50,
})

ReplicatedFirst:RemoveDefaultLoadingScreen()

-- Show ------------------------------------------------------------------------------------------------------------
-- The Essential tier starts now, beside the screen's own art; it doesn't need the whole game to have loaded (its
-- first wait is for ReplicatedStorage.Shared, so the art gets a head start).
task.spawn(Preload.start)
-- The screen's own art first (small, a few seconds at most), then the clash starts.
do
	local own = {}
	for _, id in Art.Images do
		-- ImageLabels, not id strings: a bare string reports Failure at once and the show would start on blanks.
		local label = Instance.new("ImageLabel")
		label.Image = id
		table.insert(own, label)
	end
	local ready = false
	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, own)
		ready = true
	end)
	while not ready and os.clock() - started < 4 do
		task.wait()
	end
end
TweenService:Create(backdrop, TweenInfo.new(0.4), { ImageTransparency = 0 }):Play()
stage.Visible = true
local showStarted = os.clock()
local show = Clash.new(stage)
tap.Activated:Connect(function()
	show:Poke()
end)

local shown, target, closing = 0, 0, false
task.spawn(function()
	local lines, index = Art.Lines, math.random(1, #Art.Lines)
	while not closing do
		task.wait(2.2)
		if closing or status.Text == "Joining..." then
			continue
		end
		index = index % #lines + 1
		status.Text = lines[index]
	end
end)

local skipped = false
skip.Activated:Connect(function()
	skipped = true
end)

-- Progress bar eases toward the real progress.
local barConnection = game:GetService("RunService").RenderStepped:Connect(function(dt)
	shown += (target - shown) * math.min(1, dt * 6)
	fill.Size = UDim2.fromScale(math.clamp(shown, 0, 1), 1)
	percent.Text = string.format("%d%%", math.floor(shown * 100 + 0.5))
end)

status.Text = Art.Lines[1]

-- The bar is the Essential tier only; it never runs backwards when the spawn area adds jobs.
while true do
	local elapsed = os.clock() - started
	local done, total = Preload.progress()
	if total > 0 then
		target = math.max(target, done / total)
	end
	local loaded = Preload.essentialDone() and game:IsLoaded()
	if elapsed > SKIP_AFTER and not skip.Visible and not loaded then
		skip.Visible = true
	end
	if
		(loaded and elapsed >= MIN_SECONDS and os.clock() - showStarted >= MIN_SHOW)
		or skipped
		or elapsed >= MAX_SECONDS
	then
		break
	end
	task.wait(0.05)
end

-- Close -----------------------------------------------------------------------------------------------------------
closing = true
target = 1
local settle = os.clock()
while shown < 0.985 and os.clock() - settle < 0.5 do
	task.wait()
end
status.Text = "Let's clash!"
task.wait(0.35)
local dip = TweenService:Create(veil, TweenInfo.new(0.25), { BackgroundTransparency = 0 })
dip:Play()
dip.Completed:Wait()
show:Destroy()
barConnection:Disconnect()
root:Destroy()
player:SetAttribute("LoadSeconds", math.floor((os.clock() - started) * 100) / 100)
player:SetAttribute("ClientLoaded", true)
Preload.release()
if game:GetService("RunService"):IsStudio() then
	task.spawn(function()
		Preload.publishReport()
		local waited = os.clock()
		while player:GetAttribute("LoadStage") ~= "Done" and os.clock() - waited < 300 do
			task.wait(1)
		end
		Preload.publishReport()
	end)
end
local rise = TweenService:Create(veil, TweenInfo.new(0.45), { BackgroundTransparency = 1 })
rise:Play()
rise.Completed:Wait()
gui:Destroy()
