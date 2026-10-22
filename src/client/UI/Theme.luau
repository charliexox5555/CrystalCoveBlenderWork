--!strict
-- Stained Glass tokens (DECISIONS 49). Editable templates own their styling.
-- https://www.figma.com/design/r3guIIk5deo7vNxLzJN0RZ
-- Every screen and component reads styling from here. To reskin, change this file.

local Theme = {}

local hex = Color3.fromHex
Theme.Style = "StainedGlass"
Theme.Palette = {
	lead = hex("#1F1830"),
	smoke = hex("#261D3B"),
	smoke2 = hex("#332854"),
	viewport = hex("#3B2F5E"),
	ruby = hex("#E23A55"),
	rubyLight = hex("#FF8EA0"),
	rubyDark = hex("#9E1D38"),
	amber = hex("#F5A524"),
	amberLight = hex("#FFD98A"),
	amberDark = hex("#B26E0B"),
	emerald = hex("#22B573"),
	emeraldLight = hex("#86EDB8"),
	emeraldDark = hex("#11703F"),
	aqua = hex("#1FC2D3"),
	aquaLight = hex("#9BF3F8"),
	aquaDark = hex("#0F7C88"),
	sapphire = hex("#2E6BE6"),
	sapphireLight = hex("#93BCFF"),
	sapphireDark = hex("#1A409C"),
	amethyst = hex("#8B4FE0"),
	amethystLight = hex("#CDAAFF"),
	amethystDark = hex("#57299F"),
	milk = hex("#EEE7D9"),
	milkLight = hex("#FFFFFF"),
	milkDark = hex("#B9AE99"),
	slate = hex("#7C7896"),
}

-- Colours -------------------------------------------------------------------------------------
Theme.Colors = {
	-- Panels: dark frosted glass with a thin cyan -> violet edge
	PanelTop = hex("#332854"),
	PanelBottom = hex("#261D3B"),
	PanelTransparency = 0.08,
	Inset = hex("#261D3B"), -- search boxes, details panel, slots pill
	InsetTransparency = 0.5,
	EdgeA = hex("#1FC2D3"),
	EdgeB = hex("#8B4FE0"),
	Shadow = hex("#1F1830"),

	Text = hex("#FFFFFF"),
	TextMuted = hex("#EEE7D9"),
	TextDark = hex("#1F1830"),
	Highlight = hex("#F5A524"), -- selection glow, PERFECT!, evolution hints
	Damage = hex("#1F1830"), -- outline on damage numbers
	Heart = hex("#E23A55"), -- glass hearts (lives) everywhere
}

-- Buttons: each colour has exactly one meaning everywhere
Theme.Buttons = {
	Green = { Top = hex("#86EDB8"), Bottom = hex("#22B573") }, -- buy / claim / equip
	Red = { Top = hex("#FF8EA0"), Bottom = hex("#E23A55") }, -- close / cancel
	Yellow = { Top = hex("#FFD98A"), Bottom = hex("#F5A524") }, -- special / limited
	Blue = { Top = hex("#93BCFF"), Bottom = hex("#2E6BE6") }, -- neutral
	Purple = { Top = hex("#CDAAFF"), Bottom = hex("#8B4FE0") }, -- fuse / evolve
}

-- Rarity: Top/Bottom for tile tint and edge gradients
Theme.Rarity = {
	Starter = { Top = hex("#FFFFFF"), Bottom = hex("#EEE7D9") },
	Common = { Top = hex("#FFFFFF"), Bottom = hex("#EEE7D9") },
	Uncommon = { Top = hex("#86EDB8"), Bottom = hex("#22B573") },
	Rare = { Top = hex("#93BCFF"), Bottom = hex("#2E6BE6") },
	Epic = { Top = hex("#CDAAFF"), Bottom = hex("#8B4FE0") },
	Legendary = { Top = hex("#FFD98A"), Bottom = hex("#F5A524") },
	Mythic = { Top = hex("#FF8EA0"), Bottom = hex("#1FC2D3") }, -- animate this gradient
}

-- Arena sides match the queue pad glows (A blue, B orange) so a glassy, its HUD panel and its pad read as one.
Theme.Sides = {
	hex("#4FB8FF"),
	hex("#FF9F43"),
}

Theme.Types = {
	Heavy = hex("#F5A524"),
	Sharp = hex("#8B4FE0"),
	Fizzy = hex("#1FC2D3"),
}

-- Power meter zones (layout comes from Formula.meterBounds)
Theme.Meter = {
	Weak = { Top = hex("#FF8EA0"), Bottom = hex("#E23A55") },
	Good = { Top = hex("#93BCFF"), Bottom = hex("#2E6BE6") },
	Great = { Top = hex("#86EDB8"), Bottom = hex("#22B573") },
	Perfect = { Top = hex("#FFD98A"), Bottom = hex("#F5A524") },
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
-- Approved Roblox font-library families.
Theme.Fonts = {
	Body = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy),
	Heading = Font.new("rbxasset://fonts/families/DenkOne.json"),
	PopUp = Font.new("rbxasset://fonts/families/DenkOne.json"),
	Caption = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold),
}

Theme.TextSize = {
	Small = 14,
	Body = 18,
	Label = 20,
	Heading = 28,
	Title = 44,
	PopUp = 96,
}

-- Text fit policy (Components/TextFit): shrink to Min, then wrap to Lines, then end with "…".
-- Min is the smallest size a kid can read on a phone; MinSmall is for tags, chips and counters.
Theme.TextFit = {
	Min = 12,
	MinSmall = 10,
	-- Last floor before "…": text shrinks this far rather than be cut ("Un…" reads worse than a small word, creator).
	-- 9 is Roblox's own readability floor for MinTextSize; below it a cut is the lesser evil.
	MinWord = 9,
	Lines = 2, -- one-line text (names, buttons) may use two lines before it is cut
	BodyLines = 3, -- descriptions
	-- Cut-glass art isn't rectangular: keep text inside the inner face (fractions of the art's box).
	GemInset = Vector2.new(0.1, 0.17),
}

-- Motion ---------------------------------------------------------------------------------------
Theme.Motion = {
	PanelOpen = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	PanelOpenScaleFrom = 0.95,
	ButtonPress = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	ButtonPressScale = 0.96,
	ButtonHoverScale = 1.035,
}

-- Presentation timing only; the server has already awarded the opening before playback starts.
Theme.Kiln = {
	SpinSeconds = 4.2,
	ReelStagger = 0.045,
	ReelSteps = 36,
	LandHold = 0.55,
	FireSeconds = 1.4,
	ChargeSeconds = 1.05,
	ReleaseSeconds = 0.35,
	LaunchAfterglow = 0.45,
	PressureAtlasFramePixels = 128,
	CardFlight = 0.9,
	CardStagger = 0.055,
	CollectFlight = 0.65,
	CollectStagger = 0.035,
	CollectPulse = 0.24,
	TickInterval = 0.075,
	SparkCount = 22,
}
Theme.Selection = {
	CardSeconds = 0.65,
	CardGap = 0.08,
	RollSteps = 12,
	LandHold = 0.22,
	LandPulseSeconds = 0.22,
	LandPulseScale = 0.06,
	RollTilt = -4,
	TickVolume = 0.06,
	OpenSeconds = 0.24,
	OpenScale = 0.95,
}

-- Compatibility colours for the auxiliary Aim/Results screens.
Theme.Battle = {
	PanelTop = Theme.Colors.PanelTop:Lerp(Theme.Colors.Shadow, 0.65),
	PanelBottom = Theme.Colors.PanelBottom:Lerp(Theme.Colors.Shadow, 0.55),
	PanelTransparency = 0.2,
	EdgeTransparency = 0.45,
	HpTop = hex("#86EDB8"),
	HpBottom = hex("#22B573"),
}

return Theme
