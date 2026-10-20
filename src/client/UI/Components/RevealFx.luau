-- Crate / Kiln reveal juice, scaled by rarity (KilnOpening). UI only.
--   Tier 0 Common/Uncommon: soft glow + a few sparkles.
--   Tier 1 Rare: + rotating light rays.
--   Tier 2 Epic: + bigger burst and an "EPIC!" banner slam.
--   Tier 3 Legendary: + a build-up glow before the reveal, a flash and a gold banner.
--   Tier 4 Mythic: + rainbow rays/banner and shockwave rings.
-- Reduced motion keeps the glow and banner but drops the movement.
local RS = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Audio = require(RS.Shared.Config.Audio)
local Assets = require(RS.Shared.Config.UIAssets)
local Theme = require(script.Parent.Parent.Theme)
local Motion = require(script.Parent.Motion)
local Fx = {}

local RAYS = "screens/daily_rewards/glow_burst"
local GLOW = "screens/playtime_rewards/glow"
local SPARKLE = "screens/daily_rewards/sparkle"
local TIER = { Starter = 0, Common = 0, Uncommon = 0, Rare = 1, Epic = 2, Legendary = 3, Mythic = 4 }
local SOUNDS = {
	[0] = { "Tinkle" },
	[1] = { "ChimeCluster" },
	[2] = { "MagicPoof", "ChimeCluster" },
	[3] = { "SoftBoom", "FN_SunChime" },
	[4] = { "HL_EclipseBoom", "FN_SunChime", "FallingShimmer" },
}
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Theme.Palette.rubyLight),
	ColorSequenceKeypoint.new(0.2, Theme.Palette.amberLight),
	ColorSequenceKeypoint.new(0.4, Theme.Palette.emeraldLight),
	ColorSequenceKeypoint.new(0.6, Theme.Palette.aquaLight),
	ColorSequenceKeypoint.new(0.8, Theme.Palette.sapphireLight),
	ColorSequenceKeypoint.new(1, Theme.Palette.amethystLight),
})

function Fx.tier(rarity)
	return TIER[rarity] or 0
end

function Fx.color(rarity)
	return (Theme.Rarity[rarity] or Theme.Rarity.Common).Top
end

local function sound(key, volume, parent)
	local id = Audio[key]
	if not id then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId, s.Volume = id, volume or 0.5
	s.Parent = parent or SoundService
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
	task.delay(8, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

function Fx.playTier(tier, parent)
	for i, key in SOUNDS[tier] or SOUNDS[0] do
		task.delay((i - 1) * 0.08, function()
			sound(key, if i == 1 then 0.6 else 0.4, parent)
		end)
	end
end

local function image(parent, key, z)
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency, img.Image = 1, Assets[key] or ""
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.ZIndex = z or 0
	img.Parent = parent
	return img
end

local function rainbow(object)
	local gradient = Instance.new("UIGradient")
	gradient.Color, gradient.Rotation = RAINBOW, 0
	gradient.Parent = object
	if not Motion.reduced() then
		TweenService:Create(gradient, TweenInfo.new(2.4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
			Rotation = 360,
		}):Play()
	end
	return gradient
end

-- Effects behind one revealed card. `holder` is the frame the card lives in (same Scale space);
-- `card` is already at its final Position/Size. Returns the created objects (destroyed with the holder).
function Fx.behindCard(holder, card, rarity, big)
	local tier = Fx.tier(rarity)
	local color = Fx.color(rarity)
	local pos = card.Position
	local w = card.Size.X.Scale
	local reduced = Motion.reduced()
	-- Sized from the card: the single-pull hero gets the full show, a 10-pull card a compact one.
	local factor = if big then 1 else 0.6
	-- Soft glow for every tier.
	local glow = image(holder, GLOW, card.ZIndex - 2)
	glow.Position, glow.ImageColor3, glow.ImageTransparency = pos, color, if big then 0.35 else 0.55
	local g = w * (1.3 + tier * 0.15) * factor
	glow.Size = UDim2.fromScale(g, g)
	glow.SizeConstraint = Enum.SizeConstraint.RelativeXX
	if tier == 4 then
		rainbow(glow)
	end
	-- Rotating rays from Rare up.
	if tier >= 1 then
		local rays = image(holder, RAYS, card.ZIndex - 1)
		rays.Position, rays.ImageColor3 = pos, color
		rays.SizeConstraint = Enum.SizeConstraint.RelativeXX
		local s = w * (1.5 + tier * 0.25) * factor
		rays.Size = UDim2.fromScale(s * 0.3, s * 0.3)
		rays.ImageTransparency = if tier >= 3 then (if big then 0.05 else 0.25) else 0.4
		if tier == 4 then
			rainbow(rays)
		end
		if reduced then
			rays.Size = UDim2.fromScale(s, s)
		else
			TweenService:Create(rays, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(s, s),
			}):Play()
			TweenService:Create(
				rays,
				TweenInfo.new(if tier >= 3 then 6 else 9, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
				{
					Rotation = 360,
				}
			):Play()
		end
	end
	if reduced then
		return
	end
	-- Sparkle burst.
	local count = if big then 6 + tier * 5 else 3 + tier * 2
	for i = 1, count do
		local spark = image(holder, SPARKLE, card.ZIndex + 1)
		spark.Position = pos
		spark.SizeConstraint = Enum.SizeConstraint.RelativeXX
		local size = w * (0.06 + math.random() * 0.06)
		spark.Size = UDim2.fromScale(size, size)
		spark.ImageColor3 = if i % 3 == 0 then Color3.new(1, 1, 1) else color
		local angle = (i / count) * math.pi * 2 + math.random() * 0.5
		local reach = w * (0.7 + math.random() * (0.4 + tier * 0.15))
		TweenService
			:Create(spark, TweenInfo.new(0.7 + math.random() * 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Position = pos + UDim2.fromScale(math.cos(angle) * reach, math.sin(angle) * reach * 1.6),
				Rotation = math.random(-200, 200),
				ImageTransparency = 1,
			})
			:Play()
		task.delay(1.3, function()
			spark:Destroy()
		end)
	end
	-- Mythic shockwave rings.
	if tier == 4 then
		for r = 0, 2 do
			task.delay(r * 0.16, function()
				local ring = image(holder, GLOW, card.ZIndex - 1)
				ring.Position, ring.SizeConstraint = pos, Enum.SizeConstraint.RelativeXX
				ring.Size, ring.ImageTransparency = UDim2.fromScale(w * 0.5, w * 0.5), 0.1
				rainbow(ring)
				TweenService:Create(ring, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {
					Size = UDim2.fromScale(w * 3.2, w * 3.2),
					ImageTransparency = 1,
				}):Play()
				task.delay(0.85, function()
					ring:Destroy()
				end)
			end)
		end
	end
end

-- "EPIC!" / "LEGENDARY!" / "MYTHIC!" slam over the rewards (Epic and up).
function Fx.banner(holder, rarity, y)
	local tier = Fx.tier(rarity)
	if tier < 2 then
		return
	end
	local label = Instance.new("TextLabel")
	label.Name, label.BackgroundTransparency = "RarityBanner", 1
	label.Text = string.upper(rarity) .. "!"
	label.FontFace, label.TextScaled = Theme.Fonts.Heading, true
	label.TextColor3 = if tier == 4 then Color3.new(1, 1, 1) else Fx.color(rarity)
	label.AnchorPoint, label.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, y or 0.04)
	label.Size, label.ZIndex = UDim2.fromScale(0.5, 0.12), 20
	label:SetAttribute("TextFit", false)
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness = Theme.Palette.lead, 4
	stroke.Parent = label
	if tier == 4 then
		rainbow(label)
	end
	label.Parent = holder
	if Motion.reduced() then
		return label
	end
	local scale = Instance.new("UIScale")
	scale.Scale, scale.Parent = 2.4, label
	label.TextTransparency, stroke.Transparency = 1, 1
	TweenService:Create(scale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	TweenService:Create(label, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
	TweenService:Create(stroke, TweenInfo.new(0.15), { Transparency = 0 }):Play()
	-- A gentle breathing pulse while it stays.
	task.delay(0.4, function()
		if scale.Parent then
			TweenService
				:Create(scale, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
					Scale = 1.06,
				})
				:Play()
		end
	end)
	return label
end

-- Legendary/Mythic build-up before the reveal: the screen takes on the rarity colour and pulses faster.
function Fx.anticipate(gui, rarity, seconds)
	local tier = Fx.tier(rarity)
	if tier < 3 then
		return nil
	end
	local veil = Instance.new("Frame")
	veil.Name, veil.BorderSizePixel = "RevealVeil", 0
	veil.BackgroundColor3 = if tier == 4 then Color3.new(1, 1, 1) else Fx.color(rarity)
	veil.BackgroundTransparency, veil.Size, veil.ZIndex = 1, UDim2.fromScale(1, 1), 50
	veil.Active = false
	if tier == 4 then
		rainbow(veil)
	end
	veil.Parent = gui
	sound(if tier == 4 then "CosmicRiser" else "MagicRiser", 0.5)
	if not Motion.reduced() then
		TweenService:Create(veil, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 0.72,
		}):Play()
	end
	return {
		-- The reveal moment: a bright flash that clears.
		Flash = function()
			if not veil.Parent then
				return
			end
			veil.BackgroundTransparency = if Motion.reduced() then 0.85 else 0.2
			TweenService:Create(veil, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
			task.delay(0.65, function()
				veil:Destroy()
			end)
		end,
		Destroy = function()
			veil:Destroy()
		end,
	}
end

return Fx
