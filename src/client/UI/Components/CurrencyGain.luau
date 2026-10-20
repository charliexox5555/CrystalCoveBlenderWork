-- Wallet gain animation: coin/Marble icons burst out of the reward (a springy pop to a ring around it), hang for a
-- beat, then fly into the HUD counter. Each landing bumps the counter and sends out an aura pulse in the currency's
-- colour; the last one lands with a bigger pulse and a sparkle. More gained = more icons (capped). Decreases never
-- come through here. Reduced motion: no flight, the counter just ticks.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Assets = require(RS.Shared.Config.UIAssets)
local Theme = require(script.Parent.Parent.Theme)
local Motion = require(script.Parent.Motion)
local UiAudio = require(script.Parent.UiAudio)
local Gain = {}

local MIN_ICONS, MAX_ICONS = 4, 16
local ICON_SIZE = 54
local BURST_SECONDS = 0.34
local BURST_RADIUS = { 70, 150 }
local HANG = { 0.06, 0.2 }
local FLY_SECONDS = 0.5
local STAGGER = 0.035
local GLOW = "screens/playtime_rewards/glow" -- soft radial glow, tinted per currency

local kinds = {
	Coins = { Icon = "icon/coin", Glow = Theme.Palette.amberLight },
	Marbles = { Icon = "icon/marble", Glow = Theme.Palette.aquaLight },
}

function Gain.iconCount(amount)
	return math.clamp(math.floor(math.sqrt(math.max(0, amount)) / 2) + 3, MIN_ICONS, MAX_ICONS)
end

-- An expanding, fading glow ring at `at` (screen point inside `gui`).
local function aura(gui, at, size, color, strength)
	local ring = Instance.new("ImageLabel")
	ring.Name, ring.BackgroundTransparency, ring.Image = "GainAura", 1, Assets[GLOW] or ""
	ring.ImageColor3, ring.ImageTransparency = color, 1 - strength
	ring.AnchorPoint, ring.Position = Vector2.new(0.5, 0.5), UDim2.fromOffset(at.X, at.Y)
	ring.Size = UDim2.fromOffset(size * 0.5, size * 0.5)
	ring.ZIndex = 0
	ring.Parent = gui
	local info = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = UDim2.fromOffset(size * 1.6, size * 1.6), ImageTransparency = 1 }):Play()
	task.delay(0.55, function()
		ring:Destroy()
	end)
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
	local auraSize = pill.AbsoluteSize.Y * 2.6
	-- A flash where the reward came from.
	aura(gui, center, ICON_SIZE * 3, spec.Glow, 0.75)
	for i = 1, count do
		local icon = Instance.new("ImageLabel")
		icon.Name, icon.Image, icon.BackgroundTransparency = "GainIcon", image, 1
		icon.Size = UDim2.fromOffset(ICON_SIZE * 0.3, ICON_SIZE * 0.3)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromOffset(center.X, center.Y)
		icon.Rotation = math.random(-40, 40)
		icon.ZIndex = 2
		icon.Parent = gui
		-- Even spread round the burst with a little jitter, so the pop reads as a fountain, not a clump.
		local angle = (i / count) * math.pi * 2 + (math.random() - 0.5) * 0.6
		local radius = BURST_RADIUS[1] + math.random() * (BURST_RADIUS[2] - BURST_RADIUS[1])
		local out = center + Vector2.new(math.cos(angle), math.sin(angle) * 0.75 - 0.35) * radius
		local hang = HANG[1] + math.random() * (HANG[2] - HANG[1])
		task.delay((i - 1) * STAGGER, function()
			if not icon.Parent then
				return
			end
			-- 1. Jump out with overshoot.
			TweenService
				:Create(icon, TweenInfo.new(BURST_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false), {
					Position = UDim2.fromOffset(out.X, out.Y),
					Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
					Rotation = math.random(-15, 15),
				})
				:Play()
			task.wait(BURST_SECONDS + hang)
			if not icon.Parent then
				return
			end
			-- 2. Fly into the counter, speeding up and shrinking.
			local fly =
				TweenService:Create(icon, TweenInfo.new(FLY_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = UDim2.fromOffset(target.X, target.Y),
					Size = UDim2.fromOffset(ICON_SIZE * 0.45, ICON_SIZE * 0.45),
					Rotation = 0,
				})
			fly.Completed:Connect(function()
				icon:Destroy()
				arrived += 1
				land()
				local last = arrived == count
				Motion.bump(pill, if last then 0.16 else 0.08)
				if arrived == 1 or last or arrived % 3 == 0 then
					aura(gui, target, auraSize * (if last then 1.5 else 1), spec.Glow, if last then 0.9 else 0.6)
				end
				UiAudio.play(if arrived == 1 then "Success" elseif last then "Sparkle" else "Hover")
				if last then
					task.delay(0.6, function()
						gui:Destroy()
					end)
				end
			end)
			fly:Play()
		end)
	end
	-- Glow: the number flashes the currency colour while icons are landing, then settles back.
	local total = count * STAGGER + BURST_SECONDS + HANG[2] + FLY_SECONDS
	local base = label.TextColor3
	label.TextColor3 = spec.Glow
	task.delay(total + 0.4, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(0.4), { TextColor3 = base }):Play()
		end
	end)
	-- Never leave the effect gui behind if an icon tween is interrupted.
	task.delay(total + 1.5, function()
		if gui.Parent then
			gui:Destroy()
		end
		land()
	end)
end

return Gain
