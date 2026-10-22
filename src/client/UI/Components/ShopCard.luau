-- Shared shop card: a large art panel (item fills it, name on a band at the bottom), optional
-- pills in the corners and a wide price button underneath. Used by the daily offers and the
-- Marble packs so every purchasable card reads the same way.
local U = require(script.Parent.Util)
local S = require(script.Parent.StainedGlass)
local Gem = require(script.Parent.GemButton)
local Theme = require(script.Parent.Parent.Theme)
local Card = {}
local ROBUX = utf8.char(0xE002)
Card.ROBUX = ROBUX
local GREY = Color3.fromRGB(150, 150, 165)

local function pill(parent, name, anchorX, x)
	local tag = U.make("ImageLabel", parent, {
		Name = name,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(anchorX, 0),
		Position = UDim2.fromScale(x, 0.04),
		Size = UDim2.fromScale(0.62, 0.15),
		ZIndex = 8,
		Visible = false,
	})
	-- Wide and tall enough for "UNCOMMON ★" at the readable minimum (the 3.75:1 pill cut it to "UNCOMM…").
	U.make("UIAspectRatioConstraint", tag, { DominantAxis = Enum.DominantAxis.Height }).AspectRatio = 5.2
	local label = U.text(tag, "Label", "", UDim2.fromScale(0.8, 0.66), UDim2.fromScale(0.1, 0.17), Theme.Fonts.Caption)
	label.ZIndex, label.UITextSizeConstraint.MinTextSize = 9, Theme.TextFit.MinSmall
	label:SetAttribute("FitMin", Theme.TextFit.MinSmall)
	label.UITextSizeConstraint.MaxTextSize = Theme.TextSize.Small
	return tag
end

-- Builds the card inside `frame` (any size). Returns parts for the caller to fill.
function Card.new(frame)
	local art = S.image(frame, "Art", "panel/pane_viewport", UDim2.fromScale(1, 0.78))
	local aspect = art:FindFirstChildOfClass("UIAspectRatioConstraint")
	if aspect then
		aspect:Destroy()
	end
	art.ClipsDescendants = true
	local glow = S.image(art, "Glow", "kiln/glow", UDim2.fromScale(0.9, 0.9))
	glow.AnchorPoint, glow.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.45)
	glow.ImageTransparency, glow.ZIndex = 0.55, 1
	local band = U.make("Frame", art, {
		Name = "Band",
		BorderSizePixel = 0,
		BackgroundColor3 = Theme.Palette.lead,
		BackgroundTransparency = 0.25,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.2),
		ZIndex = 6,
	})
	local name =
		-- 0.72 tall: DenkOne's descenders (g, y) hang below its text bounds and were cut by the buy button.
		U.text(band, "ItemName", "", UDim2.fromScale(0.92, 0.72), UDim2.fromScale(0.04, 0.06), Theme.Fonts.Heading)
	name.ZIndex, name.UITextSizeConstraint.MaxTextSize = 7, 26
	U.make("UIStroke", name, { Thickness = 1.5, Color = Theme.Palette.lead })
	local button = Gem.new(frame, "Buy", "…", "Green", UDim2.fromScale(1, 0.2), UDim2.fromScale(0, 0.8))
	button.Label.UITextSizeConstraint.MaxTextSize = 30
	-- On short cards (phones) the button's 44 px minimum is taller than its 20% slot and covered the name band:
	-- pin it to the bottom and give the art whatever height is left. The anchor is centred (presses scale from the
	-- middle), so its centre sits half its drawn height above the card's bottom.
	button.AnchorPoint, button.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.9)
	local function pin()
		local y = -math.floor(button.AbsoluteSize.Y / 2)
		if button.Position ~= UDim2.new(0.5, 0, 1, y) then
			button.Position = UDim2.new(0.5, 0, 1, y)
		end
	end
	button:GetPropertyChangedSignal("AbsoluteSize"):Connect(pin)
	task.defer(pin)
	local function relayout()
		local minimum = button:FindFirstChildOfClass("UISizeConstraint")
		local height = frame.AbsoluteSize.Y
		local short = height > 0 and height < 100
		-- A full-width button stays easy to tap a little under 44 px; it leaves the art room to show the item.
		if minimum then
			minimum.MinSize = Vector2.new(minimum.MinSize.X, if short then 34 else 44)
		end
		band.Size = UDim2.fromScale(1, if short then 0.34 else 0.2)
		local used = button.AbsoluteSize.Y
		if height > 0 and used > height * 0.2 + 1 then
			art.Size = UDim2.new(1, 0, 0, math.max(1, math.floor(height - used - 2)))
		else
			art.Size = UDim2.fromScale(1, 0.78)
		end
	end
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	button:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	task.defer(relayout)
	return {
		Frame = frame,
		Art = art,
		Glow = glow,
		Name = name,
		Rarity = pill(art, "RarityPill", 0, 0.03),
		Corner = pill(art, "CornerPill", 1, 0.97),
		Button = button,
	}
end

-- Pill text/colour, or hidden when text is nil.
function Card.pill(tag, text, colour)
	tag.Visible = text ~= nil
	if text then
		S.tag(tag, text, colour)
	end
end

-- Tints the art panel and glow toward an accent colour (rarity or pack tier).
function Card.accent(card, colour)
	local base = Color3.new(1, 1, 1)
	card.Art.ImageColor3 = base:Lerp(colour, 0.35)
	card.Glow.ImageColor3 = colour
end

-- kind: "robux" (green), "coins" (amber), "sold" (grey SOLD OUT), "soon" (dim blue).
function Card.button(card, kind, text)
	local button = card.Button
	local gem = if kind == "coins" then "amber" elseif kind == "robux" then "emerald" else "sapphire"
	S.setAsset(button.Artwork, "button/gem_" .. gem)
	button.Artwork.ImageColor3 = if kind == "sold" then GREY else Color3.new(1, 1, 1)
	S.buttonText(button, text)
	button.Label.TextTransparency = if kind == "soon" then 0.3 else 0
end

return Card
