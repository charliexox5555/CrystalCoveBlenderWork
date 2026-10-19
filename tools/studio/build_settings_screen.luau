-- Edit mode (Studio MCP), with the Studio lock held. Rebuilds StarterGui.SettingsScreen as a compact Stained Glass
-- window (design only; nothing is wired yet). Re-runnable: the previous SettingsScreen is copied to
-- ServerStorage.UIBackup_Topbar first, then replaced. Only SettingsScreen is touched.
-- Close diamond, title banner and title are cloned from StarterGui.CollectionScreen.Panel so they match Inventory.
-- Element map, states and assets: docs/ui/screens/SettingsScreen.md. Art: tools/ui/settings_art.mjs.
assert(not game:GetService("RunService"):IsRunning(), "Run in Edit")
local StarterGui = game:GetService("StarterGui")
local ServerStorage = game:GetService("ServerStorage")

-- Image ids (Decal uploads resolved to textures). Keys match UIAssets "screens/settings/<key>"; each image's
-- AssetPath attribute names its UIAssets key.
local IMG = {
	window_settings = "rbxassetid://80745807985337",
	title = "rbxassetid://78271701322698", -- panel/title_aqua (kit)
	plaque = "rbxassetid://95988431808015", -- hud/label_plaque (kit), value readouts
	row_plate = "rbxassetid://98724888006039",
	section_rule = "rbxassetid://87454931589341",
	slider_track = "rbxassetid://108883153961201",
	slider_fill_aqua = "rbxassetid://131933425543030",
	slider_knob = "rbxassetid://106231438666779",
	toggle_on = "rbxassetid://119866084462346",
	toggle_off = "rbxassetid://97924136102909",
	toggle_knob = "rbxassetid://130946412636133",
	icon_master = "rbxassetid://116489759097215",
	icon_music = "rbxassetid://128441386984663",
	icon_sfx = "rbxassetid://77045510824948",
	icon_bot = "rbxassetid://75201543377719",
	icon_autocast = "rbxassetid://134988915857228",
	icon_effects = "rbxassetid://128977364740417",
	icon_motion = "rbxassetid://132131276091240",
	icon_cosmetics = "rbxassetid://121754588232337",
}
local C = {
	lead = Color3.fromHex("#1F1830"),
	white = Color3.fromHex("#FFFFFF"),
	milk = Color3.fromHex("#EEE7D9"),
	slate = Color3.fromHex("#B7B3CC"),
	aquaLight = Color3.fromHex("#9BF3F8"),
}
local HEADING = Font.new("rbxasset://fonts/families/DenkOne.json")
local BODY = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold)
local NUMBER = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy)
local PANEL_ASPECT = 1260 / 860 -- window_settings art
local KNOB_ON_X, KNOB_OFF_X = 0.76, 0.24 -- toggle knob centre on the track

-- Sections (content-frame fractions) and the rows in them. Values/states are design samples so both states show.
local SECTIONS = {
	{ Name = "Sound", Text = "SOUND", X = 0, Y = 0 },
	{ Name = "Gameplay", Text = "GAMEPLAY", X = 0.511, Y = 0 },
	{ Name = "Graphics", Text = "GRAPHICS & COMFORT", X = 0.511, Y = 0.411 },
}
local SLIDERS = {
	{ Name = "Master", Label = "Master", Helper = "All game sound", Icon = "icon_master", Y = 0.075, Value = 0.8 },
	{ Name = "Music", Label = "Music", Helper = "Lobby and battle songs", Icon = "icon_music", Y = 0.377, Value = 0.5 },
	{ Name = "SFX", Label = "SFX", Helper = "Hits, cracks and shatters", Icon = "icon_sfx", Y = 0.678, Value = 0 },
}
local TOGGLES = {
	{ Name = "BotPlay", Label = "Bot Play", Helper = "Bots join if nobody comes", Icon = "icon_bot", Y = 0.075, On = true },
	{ Name = "AutoCast", Label = "Auto-Cast Powers", Helper = "Powers fire by themselves", Icon = "icon_autocast", Y = 0.238, On = false },
	{ Name = "LargeEffects", Label = "Large Effects", Helper = "Turn off for smoother play", Icon = "icon_effects", Y = 0.486, On = true },
	{ Name = "ReducedMotion", Label = "Reduced Motion", Helper = "No camera shake or zooms", Icon = "icon_motion", Y = 0.649, On = false },
	{ Name = "HideCosmetics", Label = "Hide Others' Cosmetics", Helper = "Their flyers and finishers", Icon = "icon_cosmetics", Y = 0.812, On = false },
}
local COL_W, HEADER_H, TOGGLE_H, SLIDER_H = 0.489, 0.06, 0.148, 0.282

local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end
local function frame(name, pos, size, parent, z)
	return new("Frame", { Name = name, BackgroundTransparency = 1, Position = pos, Size = size, ZIndex = z or 2 }, parent)
end
local function image(name, key, props, parent)
	local img = new("ImageLabel", { Name = name, BackgroundTransparency = 1, Image = IMG[key], ZIndex = 2 }, parent)
	img:SetAttribute("AssetPath", "screens/settings/" .. key)
	for k, v in props do
		img[k] = v
	end
	return img
end
local function slice(img, rect, scale)
	img.ScaleType, img.SliceCenter, img.SliceScale = Enum.ScaleType.Slice, rect, scale
	return img
end
local function aspect(parent, ratio)
	return new("UIAspectRatioConstraint", { AspectRatio = ratio }, parent)
end
local function label(name, text, props, parent)
	local l = new("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Text = text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	}, parent)
	local max = props.Max or 26
	props.Max = nil
	local stroke = props.Stroke
	props.Stroke = nil
	for k, v in props do
		l[k] = v
	end
	new("UITextSizeConstraint", { MaxTextSize = max, MinTextSize = 10 }, l)
	if stroke then
		new("UIStroke", { Color = C.lead, Thickness = stroke, LineJoinMode = Enum.LineJoinMode.Round }, l)
	end
	return l
end
local function heading(name, text, props, parent)
	props.FontFace, props.TextColor3, props.Stroke = props.FontFace or HEADING, props.TextColor3 or C.white, props.Stroke or 2
	return label(name, text, props, parent)
end

-- Backup and replace --------------------------------------------------------------------------------------------
local old = StarterGui:FindFirstChild("SettingsScreen")
if old then
	local backups = ServerStorage:FindFirstChild("UIBackup_Topbar")
		or new("Folder", { Name = "UIBackup_Topbar" }, ServerStorage)
	local copy = old:Clone()
	copy.Name = "SettingsScreen_" .. os.date("!%Y%m%d_%H%M%S")
	copy.Enabled = false
	copy.Parent = backups
	old:Destroy()
end

local source = StarterGui:WaitForChild("CollectionScreen"):WaitForChild("Panel")
local gui = new("ScreenGui", {
	Name = "SettingsScreen",
	Enabled = false,
	ResetOnSpawn = false,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	DisplayOrder = 20,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, nil)
gui:SetAttribute("TopbarScreen", true)

-- Window: a bit smaller than Inventory (0.54 vs 0.7 of the screen width), nearly the same height.
local panel = new("Frame", {
	Name = "Panel",
	BackgroundTransparency = 1,
	Active = true,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromScale(0.54, 0.7),
}, gui)
panel:SetAttribute("StainedGlass", true)
local panelAspect = source.UIAspectRatioConstraint:Clone()
panelAspect.AspectRatio = PANEL_ASPECT
panelAspect.Parent = panel
aspect(
	image("WindowArtwork", "window_settings", { Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Fit, ZIndex = 0 }, panel),
	PANEL_ASPECT
)

-- Same pixel size as Inventory's banner, title and close diamond (0.25 / 0.055 of a 0.7-wide window).
local banner = source.TitleBanner:Clone()
banner.Image, banner.ZIndex = IMG.title, 3
banner:SetAttribute("AssetPath", "panel/title_aqua")
banner.Position, banner.Size = UDim2.fromScale(0.04, -0.05), UDim2.fromScale(0.32, 0.12)
banner.Parent = panel
local title = source.Title:Clone()
title.Text, title.ZIndex = "SETTINGS", 4
title.Position, title.Size = UDim2.fromScale(0.059, -0.041), UDim2.fromScale(0.275, 0.077)
for _, k in title:GetAttributes() do
	title:SetAttribute(k, nil)
end
title.Parent = panel
local close = source.Close:Clone()
close.ZIndex = 5
close.Position, close.Size = UDim2.fromScale(0.976, 0.035), UDim2.fromScale(0.071, 0.1)
close.Parent = panel

local content = frame("Content", UDim2.fromScale(0.045, 0.115), UDim2.fromScale(0.91, 0.84), panel)

-- Section headers: aqua title with a lead-edged aqua rule under it, full column width.
local sections = frame("Sections", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), content)
for _, s in SECTIONS do
	local h = frame(s.Name, UDim2.fromScale(s.X, s.Y), UDim2.fromScale(COL_W, HEADER_H), sections)
	heading("Label", s.Text, {
		Position = UDim2.fromScale(0.01, 0),
		Size = UDim2.fromScale(0.98, 0.74),
		TextColor3 = C.aquaLight,
		Max = 24,
	}, h)
	slice(
		image("Rule", "section_rule", { Position = UDim2.fromScale(0, 0.8), Size = UDim2.fromScale(1, 0.2) }, h),
		Rect.new(18, 8, 382, 24),
		0.28
	)
end

local rows = frame("Rows", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), content)
local function row(name, x, y, h, kind)
	local r = frame(name, UDim2.fromScale(x, y), UDim2.fromScale(COL_W, h), rows)
	r:SetAttribute("Setting", name)
	r:SetAttribute("Kind", kind)
	slice(
		image("Plate", "row_plate", { Size = UDim2.fromScale(1, 1), ZIndex = 1 }, r),
		Rect.new(30, 24, 570, 96),
		0.6
	)
	return r
end

-- Sliders: Rows.<Name>.{Icon, Label, Helper, Value(.Text), Slider.{Track.{Fill, Knob}}}.
-- Value 0..1 lives in the Slider's Value attribute; Fill width and Knob X both equal it (Scale, on the Track).
for _, s in SLIDERS do
	local r = row(s.Name, 0, s.Y, SLIDER_H, "Slider")
	local icon = image("Icon", s.Icon, {
		Position = UDim2.fromScale(0.035, 0.1),
		Size = UDim2.fromScale(0.15, 0.4),
		ScaleType = Enum.ScaleType.Fit,
		ImageTransparency = s.Value == 0 and 0.55 or 0, -- muted look at 0%
	}, r)
	aspect(icon, 1)
	heading("Label", s.Label, { Position = UDim2.fromScale(0.2, 0.09), Size = UDim2.fromScale(0.44, 0.23) }, r)
	label("Helper", s.Helper, {
		Position = UDim2.fromScale(0.2, 0.33),
		Size = UDim2.fromScale(0.46, 0.16),
		FontFace = BODY,
		TextColor3 = C.milk,
		Max = 18,
	}, r)
	local value = image("Value", "plaque", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.965, 0.1),
		Size = UDim2.fromScale(0.29, 0.27),
		ScaleType = Enum.ScaleType.Fit,
	}, r)
	value:SetAttribute("AssetPath", "hud/label_plaque")
	label("Text", math.round(s.Value * 100) .. "%", {
		Position = UDim2.fromScale(0.15, 0.14),
		Size = UDim2.fromScale(0.7, 0.72),
		FontFace = NUMBER,
		TextColor3 = C.lead,
		TextXAlignment = Enum.TextXAlignment.Center,
		Max = 26,
	}, value)

	-- TextButton so a later pass can take taps and drags anywhere along the bar.
	local slider = new("TextButton", {
		Name = "Slider",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.035, 0.56),
		Size = UDim2.fromScale(0.93, 0.36),
		ZIndex = 2,
	}, r)
	slider:SetAttribute("Value", s.Value)
	local track = slice(
		image("Track", "slider_track", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.94, 0.48),
		}, slider),
		Rect.new(30, 12, 570, 44),
		0.45
	)
	slice(
		image("Fill", "slider_fill_aqua", {
			Size = UDim2.fromScale(s.Value, 1),
			Visible = s.Value > 0, -- hide at 0%: the pointed ends can't shrink to nothing
			ZIndex = 3,
		}, track),
		Rect.new(30, 12, 570, 44),
		0.45
	)
	aspect(
		image("Knob", "slider_knob", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(s.Value, 0.5),
			Size = UDim2.fromScale(0.13, 2.7),
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 4,
		}, track),
		44 / 52
	)
end

-- Toggles: Rows.<Name>.{Icon, Label, Helper, Toggle.{Track, Knob, State}}.
-- ON: emerald track, knob right, "ON" on the left. OFF: slate track, knob left, "OFF" on the right.
-- The Toggle's On attribute is the state; OnImage/OffImage and KnobOnX/KnobOffX say how to draw each.
for _, t in TOGGLES do
	local r = row(t.Name, 0.511, t.Y, TOGGLE_H, "Toggle")
	aspect(
		image("Icon", t.Icon, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.03, 0.5),
			Size = UDim2.fromScale(0.13, 0.64),
			ScaleType = Enum.ScaleType.Fit,
		}, r),
		1
	)
	heading("Label", t.Label, { Position = UDim2.fromScale(0.17, 0.12), Size = UDim2.fromScale(0.5, 0.42), Max = 24 }, r)
	label("Helper", t.Helper, {
		Position = UDim2.fromScale(0.17, 0.56),
		Size = UDim2.fromScale(0.5, 0.3),
		FontFace = BODY,
		TextColor3 = C.milk,
		Max = 17,
	}, r)
	local toggle = new("TextButton", {
		Name = "Toggle",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.975, 0.5),
		Size = UDim2.fromScale(0.3, 0.76),
		ZIndex = 2,
	}, r)
	aspect(toggle, 128 / 56)
	toggle:SetAttribute("On", t.On)
	toggle:SetAttribute("OnImage", IMG.toggle_on)
	toggle:SetAttribute("OffImage", IMG.toggle_off)
	toggle:SetAttribute("KnobOnX", KNOB_ON_X)
	toggle:SetAttribute("KnobOffX", KNOB_OFF_X)
	image("Track", t.On and "toggle_on" or "toggle_off", {
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Fit,
	}, toggle)
	aspect(
		image("Knob", "toggle_knob", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(t.On and KNOB_ON_X or KNOB_OFF_X, 0.5),
			Size = UDim2.fromScale(0.32, 0.72),
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 4,
		}, toggle),
		1
	)
	heading("State", t.On and "ON" or "OFF", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(t.On and 0.38 or 0.62, 0.5),
		Size = UDim2.fromScale(0.4, 0.56),
		TextColor3 = t.On and C.white or C.slate,
		TextXAlignment = Enum.TextXAlignment.Center,
		Max = 28,
	}, toggle)
end

gui.Parent = StarterGui
return "SettingsScreen rebuilt (" .. #SLIDERS .. " sliders, " .. #TOGGLES .. " toggles)"
