--!strict
-- Glass vs Glass loading screen (ReplicatedFirst, so it is the first thing a player sees). Simple on purpose
-- (decision 123, like Blade Ball's): a black screen, a little white pen where two glass balls clink (Mini), the
-- name and a thin loading bar. Everything is Frames and a built-in font, so it is on screen in the first frame
-- with nothing to download. It closes when the Essential tier (Preload, Shared.Config.LoadTiers: the first-minute
-- UI, fonts and the spawn area) and the game have loaded, with guards so nobody gets stuck: SKIP shows after
-- SKIP_AFTER seconds and the screen closes by itself after MAX_SECONDS. Then the Soon and Later tiers load in the
-- background (Preload.release).
-- When it is gone it sets the local Player attribute ClientLoaded = true (OnboardingController waits for it).
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Mini = require(script:WaitForChild("Mini"))
local Preload = require(script:WaitForChild("Preload"))

local MIN_SECONDS = 1.2 -- long enough to see one clink, never a flash of a screen
local SKIP_AFTER = 10
local MAX_SECONDS = 30
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
local FONT = Font.new("rbxasset://fonts/families/DenkOne.json")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local started = os.clock()

local function make(class: string, parent: Instance, props: { [string]: any }): any
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end

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
	BackgroundColor3 = BLACK,
	BorderSizePixel = 0,
})
ReplicatedFirst:RemoveDefaultLoadingScreen()

-- The little pen, a square sized off the shorter screen side so it fits phones in either orientation.
local box = make("Frame", root, {
	Name = "Pen",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.44),
	Size = UDim2.fromScale(0.34, 0.34),
	SizeConstraint = Enum.SizeConstraint.RelativeYY,
	BackgroundTransparency = 1,
})
local show = Mini.new(box)

make("TextLabel", root, {
	Name = "Title",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.7),
	Size = UDim2.fromScale(0.5, 0.06),
	BackgroundTransparency = 1,
	Text = "GLASS VS GLASS",
	FontFace = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
})
local track = make("Frame", root, {
	Name = "Bar",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.79),
	Size = UDim2.new(0.3, 0, 0, 4),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.8,
	BorderSizePixel = 0,
})
local fill = make("Frame", track, {
	Name = "Fill",
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
})
local skip = make("TextButton", root, {
	Name = "Skip",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.88),
	Size = UDim2.fromScale(0.12, 0.05),
	BackgroundTransparency = 1,
	Text = "SKIP",
	FontFace = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	TextTransparency = 0.3,
	Visible = false,
})
-- The quick dip at the end: fade to black, drop the screen, fade the lobby in.
local veil = make("Frame", gui, {
	Name = "Veil",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = BLACK,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 50,
})

-- The Essential tier starts now; the screen is already up, so nothing waits on it to draw.
task.spawn(Preload.start)

local skipped = false
skip.Activated:Connect(function()
	skipped = true
end)

-- The bar eases toward the real progress and never runs backwards when the spawn area adds jobs.
local shown, target = 0, 0
local barConnection = RunService.RenderStepped:Connect(function(dt)
	shown += (target - shown) * math.min(1, dt * 6)
	fill.Size = UDim2.fromScale(math.clamp(shown, 0, 1), 1)
end)

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
	if (loaded and elapsed >= MIN_SECONDS) or skipped or elapsed >= MAX_SECONDS then
		break
	end
	task.wait(0.05)
end

-- Close -----------------------------------------------------------------------------------------------------------
target = 1
local settle = os.clock()
while shown < 0.985 and os.clock() - settle < 0.4 do
	task.wait()
end
local dip = TweenService:Create(veil, TweenInfo.new(0.2), { BackgroundTransparency = 0 })
dip:Play()
dip.Completed:Wait()
show:Destroy()
barConnection:Disconnect()
root:Destroy()
player:SetAttribute("LoadSeconds", math.floor((os.clock() - started) * 100) / 100)
player:SetAttribute("ClientLoaded", true)
Preload.release()
if RunService:IsStudio() then
	task.spawn(function()
		Preload.publishReport()
		local waited = os.clock()
		while player:GetAttribute("LoadStage") ~= "Done" and os.clock() - waited < 300 do
			task.wait(1)
		end
		Preload.publishReport()
	end)
end
local rise = TweenService:Create(veil, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
rise:Play()
rise.Completed:Wait()
gui:Destroy()
