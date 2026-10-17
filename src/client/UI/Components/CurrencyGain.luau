-- Wallet gain animation: a burst of coin/Marble icons flies into the HUD counter, which then ticks up
-- with a bump and a glow. More gained = more icons (capped). Decreases never come through here.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Assets = require(RS.Shared.Config.UIAssets)
local Theme = require(script.Parent.Parent.Theme)
local Motion = require(script.Parent.Motion)
local UiAudio = require(script.Parent.UiAudio)
local Gain = {}

local MIN_ICONS, MAX_ICONS = 3, 14
local ICON_SIZE = 44
local FLY_SECONDS = 0.62
local STAGGER = 0.05

local kinds = {
	Coins = { Icon = "icon/coin", Glow = Theme.Palette.amberLight },
	Marbles = { Icon = "icon/marble", Glow = Theme.Palette.aquaLight },
}

function Gain.iconCount(amount)
	return math.clamp(math.floor(math.sqrt(math.max(0, amount)) / 2) + 2, MIN_ICONS, MAX_ICONS)
end

-- `label` is the HUD counter TextLabel; `onFirst` runs when the first icon lands (the counter should tick then);
-- `origin` is an optional screen position (defaults to the middle of the screen).
function Gain.play(kind, amount, label, onFirst, origin)
	local spec = kinds[kind]
	local landed = false
	local function land()
		if landed then
			return
		end
		landed = true
		onFirst()
	end
	if not spec or amount <= 0 or not label or not label.Parent or Motion.reduced() then
		land()
		return
	end
	local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.DisplayOrder, gui.ResetOnSpawn = "CurrencyGainFx", 60, false
	-- Same inset as the HUD, so the HUD's AbsolutePosition values line up with this gui.
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = pg
	-- The counter's pill: icons fly to the icon end on the left of the number.
	local pill = label.Parent
	local target = pill.AbsolutePosition + Vector2.new(pill.AbsoluteSize.Y * 0.5, pill.AbsoluteSize.Y * 0.5)
	local size = if gui.AbsoluteSize.X > 0 then gui.AbsoluteSize else workspace.CurrentCamera.ViewportSize
	local center = origin or (size / 2)
	local count = Gain.iconCount(amount)
	local image = Assets[spec.Icon]
	local arrived = 0
	for i = 1, count do
		local icon = Instance.new("ImageLabel")
		icon.Name, icon.Image, icon.BackgroundTransparency = "GainIcon", image, 1
		icon.Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		local angle = math.random() * math.pi * 2
		local start = center + Vector2.new(math.cos(angle), math.sin(angle)) * (30 + math.random() * 50)
		icon.Position = UDim2.fromOffset(start.X, start.Y)
		icon.Rotation = math.random(-25, 25)
		icon.ImageTransparency = 1
		icon.Parent = gui
		task.delay((i - 1) * STAGGER, function()
			if not icon.Parent then
				return
			end
			-- Pop out from the burst point, then fly to the counter.
			TweenService:Create(icon, TweenInfo.new(0.12), { ImageTransparency = 0 }):Play()
			local fly = TweenService:Create(
				icon,
				TweenInfo.new(FLY_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{
					Position = UDim2.fromOffset(target.X, target.Y),
					Size = UDim2.fromOffset(ICON_SIZE * 0.55, ICON_SIZE * 0.55),
					Rotation = 0,
				}
			)
			fly.Completed:Connect(function()
				icon:Destroy()
				arrived += 1
				land()
				Motion.bump(pill, 0.06)
				UiAudio.play(if arrived == 1 then "Success" else "Hover")
				if arrived == count then
					gui:Destroy()
				end
			end)
			fly:Play()
		end)
	end
	-- Glow: the number flashes the currency colour while icons are landing, then settles back.
	local base = label.TextColor3
	label.TextColor3 = spec.Glow
	task.delay(count * STAGGER + FLY_SECONDS + 0.35, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(0.4), { TextColor3 = base }):Play()
		end
	end)
	-- Never leave the effect gui behind if an icon tween is interrupted.
	task.delay(count * STAGGER + FLY_SECONDS + 1.5, function()
		if gui.Parent then
			gui:Destroy()
		end
		land()
	end)
end

return Gain
