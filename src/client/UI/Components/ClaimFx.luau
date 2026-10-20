-- Reward claim celebration for Daily and Playtime cells (decision 99): the cell punches up and settles, a glow
-- flashes behind it, sparkles shoot out, the claimed check pops in, and a free pull shows its icon rising with a
-- "FREE … !" tag. The coins themselves fly to the wallet through CurrencyGain (LobbyController.GainOrigin).
-- Reduced motion: only the sound and the check.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Assets = require(RS.Shared.Config.UIAssets)
local Theme = require(script.Parent.Parent.Theme)
local Motion = require(script.Parent.Motion)
local UiAudio = require(script.Parent.UiAudio)
local Visuals = require(script.Parent.Parent.Screens.RewardVisuals)
local Fx = {}

local SPARKLE = "screens/daily_rewards/sparkle"
local GLOW = "screens/playtime_rewards/glow"
local SPARKS = 12
local PULL_TEXT = { Glassies = "FREE KILN PULL!", Finishers = "FREE FINISHER CRATE!", Rideables = "FREE FLYER CRATE!" }

local function overlay()
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.DisplayOrder, gui.ResetOnSpawn = "ClaimFx", 55, false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets -- same space as the reward screens
	gui.Parent = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	task.delay(2.5, function()
		gui:Destroy()
	end)
	return gui
end

local function image(gui, key, at, size, color)
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency, img.Image = 1, Assets[key] or ""
	img.ImageColor3 = color or Color3.new(1, 1, 1)
	img.AnchorPoint, img.Position = Vector2.new(0.5, 0.5), UDim2.fromOffset(at.X, at.Y)
	img.Size = UDim2.fromOffset(size, size)
	img.Parent = gui
	return img
end

-- Screen centre of a GuiObject, in the reward screens' inset space.
function Fx.center(object)
	return object.AbsolutePosition + object.AbsoluteSize / 2
end

-- `cell` is the claimed Day/Playtime cell; `reward` its bundle; `color` the screen's accent.
function Fx.celebrate(cell, reward, color)
	color = color or Theme.Palette.amberLight
	UiAudio.play("Sparkle")
	local mark = cell:FindFirstChild("ClaimedMark")
	if Motion.reduced() then
		return
	end
	local at, size = Fx.center(cell), cell.AbsoluteSize
	-- 1. The cell punches up and settles (from its centre).
	Motion.center(cell)
	-- One UIScale per object (the open stagger's EntranceScale may already be there).
	local scale = cell:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "EntranceScale" -- the name Motion.stagger reuses
	end
	scale.Parent, scale.Scale = cell, 1
	local up = TweenService:Create(
		scale,
		TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Scale = 1.14 }
	)
	up.Completed:Connect(function()
		TweenService
			:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end)
	up:Play()
	local gui = overlay()
	-- 2. Glow flash behind the cell.
	local glow = image(gui, GLOW, at, math.max(size.X, size.Y) * 1.2, color)
	glow.ZIndex, glow.ImageTransparency = 0, 0.15
	local s = math.max(size.X, size.Y) * 2.2
	TweenService
		:Create(
			glow,
			TweenInfo.new(0.6, Enum.EasingStyle.Quad),
			{ Size = UDim2.fromOffset(s, s), ImageTransparency = 1 }
		)
		:Play()
	-- 3. Sparkles shoot out and spin away.
	for i = 1, SPARKS do
		local spark = image(gui, SPARKLE, at, math.random(18, 34), if i % 3 == 0 then Color3.new(1, 1, 1) else color)
		spark.ZIndex = 3
		local angle = (i / SPARKS) * math.pi * 2 + math.random() * 0.4
		local reach = math.max(size.X, size.Y) * (0.55 + math.random() * 0.45)
		local goal = at + Vector2.new(math.cos(angle), math.sin(angle)) * reach
		TweenService
			:Create(
				spark,
				TweenInfo.new(0.55 + math.random() * 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{
					Position = UDim2.fromOffset(goal.X, goal.Y),
					Rotation = math.random(-180, 180),
					ImageTransparency = 1,
				}
			)
			:Play()
	end
	-- 4. The check pops in once the screen shows the claimed state.
	task.delay(0.12, function()
		if mark and mark.Parent and mark:IsA("GuiObject") then
			Motion.center(mark)
			local pop = mark:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			pop.Parent, pop.Scale = mark, 0.2
			TweenService
				:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
				:Play()
		end
	end)
	-- 5. A free pull rises out of the cell with its name.
	if reward and reward.Pull then
		local icon = image(gui, "", at, size.X * 0.2)
		icon.Image = Visuals.icon(reward)
		icon.ZIndex = 4
		local rise = at - Vector2.new(0, size.Y * 0.75)
		TweenService:Create(icon, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(rise.X, rise.Y),
			Size = UDim2.fromOffset(size.X * 0.75, size.X * 0.75),
		}):Play()
		local tag = Instance.new("TextLabel")
		tag.BackgroundTransparency, tag.Text = 1, PULL_TEXT[reward.Pull] or "FREE PULL!"
		tag.FontFace, tag.TextColor3, tag.TextScaled = Theme.Fonts.Heading, Color3.new(1, 1, 1), true
		tag.AnchorPoint = Vector2.new(0.5, 0)
		tag.Position = UDim2.fromOffset(rise.X, rise.Y + size.X * 0.4)
		tag.Size = UDim2.fromOffset(size.X * 1.6, size.X * 0.22)
		tag.TextTransparency, tag.ZIndex = 1, 4
		tag:SetAttribute("TextFit", false)
		local stroke = Instance.new("UIStroke")
		stroke.Color, stroke.Thickness, stroke.Transparency = Theme.Palette.lead, 3, 1
		stroke.Parent = tag
		tag.Parent = gui
		TweenService:Create(tag, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.25), { Transparency = 0 }):Play()
		task.delay(1.4, function()
			if icon.Parent then
				local info = TweenInfo.new(0.4)
				TweenService:Create(icon, info, { ImageTransparency = 1 }):Play()
				TweenService:Create(tag, info, { TextTransparency = 1 }):Play()
				TweenService:Create(stroke, info, { Transparency = 1 }):Play()
			end
		end)
	end
end

-- A refused claim gives a small shake.
function Fx.refuse(cell)
	UiAudio.play("Error")
	if Motion.reduced() then
		return
	end
	local rest = cell.Position
	local step = TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true)
	local tween = TweenService:Create(cell, step, { Position = rest + UDim2.fromOffset(6, 0) })
	tween.Completed:Connect(function()
		cell.Position = rest
	end)
	tween:Play()
end

return Fx
