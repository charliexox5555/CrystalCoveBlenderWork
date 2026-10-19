-- Square prize card for the shop's odds carousel: rarity frame, portrait area, name plaque, odds chip.
-- Mockup: Figma "Prize Card — square" (docs/ui/prize_card_square.png). Pure layout; the carousel owns motion.
local RS = game:GetService("ReplicatedStorage")
local Frames = require(RS.Shared.Config.PrizeCardAssets)
local Theme = require(script.Parent.Parent.Theme)
local S = require(script.Parent.StainedGlass)
local PrizeCard = {}

local function make(class, parent, properties)
	local object = Instance.new(class)
	for key, value in properties do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function label(parent, name, font, size, position, zindex)
	local text = make("TextLabel", parent, {
		Name = name,
		BackgroundTransparency = 1,
		Size = size,
		Position = position,
		FontFace = font,
		TextScaled = true,
		TextColor3 = Theme.Colors.TextDark,
		ZIndex = zindex,
	})
	make("UITextSizeConstraint", text, { MinTextSize = Theme.TextFit.MinSmall, MaxTextSize = 28 })
	text:SetAttribute("FitMin", Theme.TextFit.MinSmall) -- small card: readable floor, two lines, then "…"
	return text
end

-- Returns a card whose Root is square (height-driven UIAspectRatioConstraint 1:1).
function PrizeCard.new(parent, activated)
	local root = make("Frame", parent, {
		Name = "Prize",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromScale(1, 1),
	})
	make("UIAspectRatioConstraint", root, { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height })
	local frame = make("ImageLabel", root, {
		Name = "RarityFrame",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Stretch, -- the art is square and so is the card, so nothing stretches
		ZIndex = 1,
	})
	local area = make("Frame", root, {
		Name = "PortraitArea",
		BackgroundTransparency = 1, -- the item sits straight on the card's own dark pane
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.108, 0.108),
		Size = UDim2.fromScale(0.784, 0.512),
		ZIndex = 2,
	})
	local plaque = make("ImageLabel", root, {
		Name = "NamePlaque",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.1, 0.615),
		Size = UDim2.fromScale(0.8, 0.2),
		ZIndex = 3,
	})
	S.setAsset(plaque, "tile/name_plaque")
	local name = label(root, "Name", Theme.Fonts.Body, UDim2.fromScale(0.64, 0.115), UDim2.fromScale(0.18, 0.66), 4)
	local chip = make("ImageLabel", root, {
		Name = "OddsChip",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.3, 0.8),
		Size = UDim2.fromScale(0.4, 0.1067),
		ZIndex = 5,
	})
	local chance =
		-- Fills the odds chip's flat middle: odds must stay readable on the small carousel cards.
		label(root, "Chance", Theme.Fonts.Heading, UDim2.fromScale(0.34, 0.095), UDim2.fromScale(0.33, 0.806), 6)
	chance.TextColor3 = Theme.Colors.Text
	make("UIStroke", chance, { Color = Theme.Palette.lead, Thickness = 1.5, LineJoinMode = Enum.LineJoinMode.Round })
	local open = make("TextButton", root, {
		Name = "Open",
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 8,
	})
	local card = { Root = root, Frame = frame, Area = area, Name = name, Chip = chip, Chance = chance, Open = open }
	if activated then
		card.Connection = open.Activated:Connect(function()
			activated(card)
		end)
	end
	return card
end

-- Shows one prize. `portrait` is a (cached) ViewportFrame; it is parented, never rebuilt.
function PrizeCard.set(card, def, chance, portrait, digits)
	local key = S.rarity(def.Rarity)
	card.Frame.Image = Frames[key]
	card.Name.Text = def.Name
	card.Chance.Text = string.format("%." .. (digits or 3) .. "g%%", chance * 100)
	local colour = S.Rarity[def.Rarity] or "milk"
	S.setAsset(card.Chip, "tag/tag_" .. colour)
	card.Chance.TextColor3 = if colour == "milk" then Theme.Colors.TextDark else Theme.Colors.Text
	card.Chance.UIStroke.Enabled = colour ~= "milk"
	portrait.ZIndex = 3 -- above the area even under ZIndexBehavior.Global
	portrait.Parent = card.Area
end

function PrizeCard.destroy(card)
	if card.Connection then
		card.Connection:Disconnect()
	end
	card.Root:Destroy()
end
return PrizeCard
