--!strict
-- UI design tokens. These match the "crisp glass" Figma mockups:
-- https://www.figma.com/design/r3guIIk5deo7vNxLzJN0RZ
-- Every screen and component reads styling from here. To reskin, change this file.

local Theme = {}

local hex = Color3.fromHex

-- Colours -------------------------------------------------------------------------------------
Theme.Colors = {
	-- Panels: dark frosted glass with a thin cyan -> violet edge
	PanelTop = hex("#1E2A6E"),
	PanelBottom = hex("#141344"),
	PanelTransparency = 0.08,
	Inset = hex("#0E1240"), -- search boxes, details panel, slots pill
	InsetTransparency = 0.5,
	EdgeA = hex("#6FE3FF"),
	EdgeB = hex("#A06BFF"),
	Shadow = hex("#05071C"),

	Text = hex("#FFFFFF"),
	TextMuted = hex("#C9D2F5"),
	TextDark = hex("#1A1E4A"),
	Highlight = hex("#FFE45C"), -- selection glow, PERFECT!, evolution hints
	Damage = hex("#C2183A"), -- outline on damage numbers
}

-- Buttons: each colour has exactly one meaning everywhere
Theme.Buttons = {
	Green = { Top = hex("#A6FF7A"), Bottom = hex("#2FCB3A") }, -- buy / claim / equip
	Red = { Top = hex("#FF9A9A"), Bottom = hex("#E5263F") }, -- close / cancel
	Yellow = { Top = hex("#FFF27A"), Bottom = hex("#FFB800") }, -- special / limited
	Blue = { Top = hex("#9FE0FF"), Bottom = hex("#2F8BFF") }, -- neutral
	Purple = { Top = hex("#E0B0FF"), Bottom = hex("#8C3CFF") }, -- fuse / evolve
}

-- Rarity: Top/Bottom for tile tint and edge gradients
Theme.Rarity = {
	Starter = { Top = hex("#CCFFF7"), Bottom = hex("#2FD6C3") },
	Common = { Top = hex("#EEF2F7"), Bottom = hex("#A9B4C2") },
	Uncommon = { Top = hex("#C8F9D2"), Bottom = hex("#4ED36E") },
	Rare = { Top = hex("#CFE8FF"), Bottom = hex("#4A9EFF") },
	Epic = { Top = hex("#EBD6FF"), Bottom = hex("#A25CFF") },
	Legendary = { Top = hex("#FFF3BF"), Bottom = hex("#FFB92E") },
	Mythic = { Top = hex("#FFB3E6"), Bottom = hex("#6FE3FF") }, -- animate this gradient
}

Theme.Types = {
	Heavy = hex("#FF8A3D"),
	Sharp = hex("#5CD6FF"),
	Fizzy = hex("#FF6EC7"),
}

-- Power meter zones (layout comes from Formula.meterBounds)
Theme.Meter = {
	Weak = { Top = hex("#FF8A95"), Bottom = hex("#E5263F") },
	Good = { Top = hex("#9FE0FF"), Bottom = hex("#2F8BFF") },
	Great = { Top = hex("#B6FF8A"), Bottom = hex("#2FCB3A") },
	Perfect = { Top = hex("#FFF7A8"), Bottom = hex("#FFD000") },
}

-- Shape ----------------------------------------------------------------------------------------
Theme.Radius = {
	Tag = UDim.new(0.05, 0),
	Button = UDim.new(0.12, 0),
	Tile = UDim.new(0.08, 0),
	Panel = UDim.new(0.04, 0),
	Bar = UDim.new(0.12, 0),
}

Theme.Stroke = {
	Edge = 2, -- panels and tiles (gradient edge)
	Button = 1.5, -- thin light edge on buttons
	ButtonTransparency = 0.65,
	PopUp = 2, -- only on pop-up text over the 3D scene
}

-- Type -----------------------------------------------------------------------------------------
-- Montserrat is in Roblox's font library. If a weight ever looks wrong, BuilderSans is the backup.
Theme.Fonts = {
	Body = Font.fromName("Montserrat", Enum.FontWeight.Bold),
	Heading = Font.fromName("Montserrat", Enum.FontWeight.ExtraBold),
	PopUp = Font.fromName("Montserrat", Enum.FontWeight.Heavy, Enum.FontStyle.Italic),
	Caption = Font.fromName("Montserrat", Enum.FontWeight.Medium),
}

Theme.TextSize = {
	Small = 14,
	Body = 18,
	Label = 20,
	Heading = 28,
	Title = 44,
	PopUp = 96,
}

-- Motion ---------------------------------------------------------------------------------------
Theme.Motion = {
	PanelOpen = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	PanelOpenScaleFrom = 0.95,
	ButtonPress = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	ButtonPressScale = 0.96,
}

-- Compact battle skin, derived from the same crisp-glass palette.
Theme.Battle = {
	PanelTop = Theme.Colors.PanelTop:Lerp(Theme.Colors.Shadow, 0.65),
	PanelBottom = Theme.Colors.PanelBottom:Lerp(Theme.Colors.Shadow, 0.55),
	PanelTransparency = 0.2,
	EdgeTransparency = 0.45,
	HpTop = hex("#9CF6BC"),
	HpBottom = hex("#38D98B"),
}

return Theme
