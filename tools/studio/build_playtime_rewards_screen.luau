-- Edit mode (Studio MCP), with the Studio lock held. Rebuilds StarterGui.PlaytimeRewardsScreen as a wide Stained Glass
-- window (design only; nothing is wired yet): a progress bar with milestone gems over five reward cells
-- (10, 20, 30, 45, 60 min).
-- Re-runnable: the previous PlaytimeRewardsScreen is copied to ServerStorage.UIBackup_Topbar first, then replaced.
-- Only PlaytimeRewardsScreen is touched. Close diamond, title banner and title are cloned from
-- StarterGui.CollectionScreen.Panel so they match Inventory.
-- Element map, states and assets: docs/ui/screens/PlaytimeRewardsScreen.md. Art: tools/ui/playtime_rewards_art.py.
-- The build shows a sample of 23 minutes played: 10 claimed, 20 ready, 30 next (6:48 left), 45 and 60 locked.
assert(not game:GetService("RunService"):IsRunning(), "Run in Edit")
local StarterGui = game:GetService("StarterGui")
local ServerStorage = game:GetService("ServerStorage")

-- Image ids (Decal uploads resolved to textures). Keys match UIAssets "screens/playtime_rewards/<key>" unless a kit
-- path is given; each image's AssetPath attribute names its UIAssets key.
local IMG = {
	window = "rbxassetid://117328170402465",
	cell_open = "rbxassetid://92846045397361",
	cell_ready = "rbxassetid://109813909526428",
	cell_locked = "rbxassetid://74505075426783",
	cell_best = "rbxassetid://117752506007054",
	cell_dim = "rbxassetid://85314916298071",
	cell_outline = "rbxassetid://105222766204706",
	bar_track = "rbxassetid://79949151437952",
	bar_fill = "rbxassetid://80964919944478",
	gem_on = "rbxassetid://123522265045482",
	gem_off = "rbxassetid://82694150596352",
	gem_best_on = "rbxassetid://121430822606586",
	gem_best_off = "rbxassetid://84282126147749",
	glow = "rbxassetid://92846222472557",
	icon_check = "rbxassetid://91723893736830",
	icon_clock = "rbxassetid://109458855076082",
	icon_lock = "rbxassetid://103789030449627",
	time_tag = "rbxassetid://75404031875632",
}
local KIT = {
	["panel/title_aqua"] = "rbxassetid://78271701322698",
	["hud/label_plaque"] = "rbxassetid://95988431808015",
	["tag/tag_aqua"] = "rbxassetid://108197537091964",
	["button/gem_emerald"] = "rbxassetid://108061531278853",
	["icon/coin"] = "rbxassetid://139764505735042",
	["icon/marble"] = "rbxassetid://126376968177419",
}
local C = {
	lead = Color3.fromHex("#1F1830"),
	white = Color3.fromHex("#FFFFFF"),
	milk = Color3.fromHex("#EEE7D9"),
	slate = Color3.fromHex("#B7B3CC"),
	slateDim = Color3.fromHex("#8C88A3"),
	aquaLight = Color3.fromHex("#9BF3F8"),
	emeraldLight = Color3.fromHex("#86EDB8"),
}
local HEADING = Font.new("rbxasset://fonts/families/DenkOne.json")
local BODY = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold)
local NUMBER = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy)

-- Sample state for the design build (game state later). Stages are the creator's: 10, 20, 30, 45, 60 minutes.
local PLAYED_MIN, NEXT_LEFT = 23, "6:48"
local REWARDS = {
	{ Min = 10, Icon = "icon/coin", Amount = "x50", State = "Claimed" },
	{ Min = 20, Icon = "icon/coin", Amount = "x75", State = "Ready" },
	{ Min = 30, Icon = "icon/coin", Amount = "x100", State = "Next" },
	{ Min = 45, Icon = "icon/marble", Amount = "x1", State = "Locked" },
	{ Min = 60, Icon = "icon/marble", Amount = "x3", State = "Locked", Best = true },
}
local COUNT = #REWARDS

-- Geometry (panel fractions). Cell centres and marker gems share COLUMN_X so each gem sits over its cell.
local PANEL_ASPECT = 2.0 -- window art 1400x700
local ROW_X, ROW_W = 0.05, 0.92 -- reward row
local COLUMN_X = {}
for i = 1, COUNT do
	COLUMN_X[i] = ROW_X + ROW_W * (i - 0.5) / COUNT
end
-- Track: 0 min sits at BAR_X0 (under the clock); it ends just past the last gem, which the fill reaches at 60.
local BAR_X0, BAR_X1, BAR_Y, BAR_H = 0.058, COLUMN_X[COUNT] + 0.045, 0.33, 0.065
local CELL_ASPECT = 200 / 310

-- Panel x of a play time: piecewise between marker centres (stages are not evenly spaced in time, but their gems
-- are), 0 min at the bar's start, the whole track once the last stage is reached.
local function timeToX(minutes: number): number
	if minutes >= REWARDS[COUNT].Min then
		return BAR_X1
	end
	local prevMin, prevX = 0, BAR_X0
	for i, r in REWARDS do
		if minutes <= r.Min then
			return prevX + (COLUMN_X[i] - prevX) * (minutes - prevMin) / (r.Min - prevMin)
		end
		prevMin, prevX = r.Min, COLUMN_X[i]
	end
	return BAR_X1
end

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
	local img = new("ImageLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Image = IMG[key] or KIT[key],
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 2,
	}, parent)
	img:SetAttribute("AssetPath", IMG[key] and "screens/playtime_rewards/" .. key or key)
	for k, v in props do
		img[k] = v
	end
	return img
end
local function aspect(inst, ratio)
	new("UIAspectRatioConstraint", { AspectRatio = ratio }, inst)
	return inst
end
local function text(name, value, font, props, parent)
	local label = new("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Text = value,
		FontFace = font,
		TextScaled = true,
		TextColor3 = C.white,
		ZIndex = 2,
	}, parent)
	local max = props.Max or 40
	props.Max = nil
	local stroke = props.Stroke
	props.Stroke = nil
	for k, v in props do
		label[k] = v
	end
	new("UITextSizeConstraint", { MaxTextSize = max, MinTextSize = 8 }, label)
	if stroke then
		new("UIStroke", { Color = C.lead, Thickness = stroke, LineJoinMode = Enum.LineJoinMode.Round }, label)
	end
	return label
end
local function centred(inst, x, y, w, h)
	inst.AnchorPoint, inst.Position, inst.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(x, y), UDim2.fromScale(w, h)
	return inst
end

-- Backup and replace --------------------------------------------------------------------------------------------
local old = StarterGui:FindFirstChild("PlaytimeRewardsScreen")
if old then
	local backups = ServerStorage:FindFirstChild("UIBackup_Topbar")
		or new("Folder", { Name = "UIBackup_Topbar" }, ServerStorage)
	local copy = old:Clone()
	copy.Name = "PlaytimeRewardsScreen_" .. os.date("!%Y%m%d_%H%M%S")
	copy.Enabled = false
	copy.Parent = backups
	old:Destroy()
end

local source = StarterGui:WaitForChild("CollectionScreen"):WaitForChild("Panel")
local gui = new("ScreenGui", {
	Name = "PlaytimeRewardsScreen",
	Enabled = false,
	ResetOnSpawn = false,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	DisplayOrder = 20,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
gui:SetAttribute("TopbarScreen", true)

local panel = new("Frame", {
	Name = "Panel",
	BackgroundTransparency = 1,
	Active = true,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.72, 0.9),
}, gui)
panel:SetAttribute("StainedGlass", true)
aspect(panel, PANEL_ASPECT)
image("WindowArtwork", "window", { Size = UDim2.fromScale(1, 1), ZIndex = 0 }, panel)

-- Header: banner, title, close (about Inventory's pixel size), note on the right.
local banner = source.TitleBanner:Clone()
banner.Image, banner.ZIndex = KIT["panel/title_aqua"], 3
banner:SetAttribute("AssetPath", "panel/title_aqua")
banner.Position, banner.Size = UDim2.fromScale(0.035, -0.065), UDim2.fromScale(0.36, 0.182)
banner.Parent = panel
local title = source.Title:Clone()
for _, k in title:GetAttributes() do
	title:SetAttribute(k, nil)
end
title.Text, title.ZIndex = "PLAYTIME REWARDS", 4
title.Position, title.Size = UDim2.fromScale(0.059, -0.04), UDim2.fromScale(0.312, 0.13)
title.Parent = panel
local close = source.Close:Clone()
close.ZIndex = 5
close.Position, close.Size = UDim2.fromScale(0.978, 0.045), UDim2.fromScale(0.0625, 0.125)
close.Parent = panel
-- Neutral sample text; the functionality pass sets the final wording.
text("Note", "Keep playing to unlock rewards!", BODY, {
	Position = UDim2.fromScale(0.45, 0.075),
	Size = UDim2.fromScale(0.48, 0.06),
	TextColor3 = C.milk,
	TextTransparency = 0.15,
	TextXAlignment = Enum.TextXAlignment.Right,
	Max = 22,
}, panel)

-- Progress bar ----------------------------------------------------------------------------------------------------
local progress = frame("Progress", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), panel)
progress:SetAttribute("PlayedMinutes", PLAYED_MIN)
local track = image("Track", "bar_track", {
	ScaleType = Enum.ScaleType.Slice,
	SliceCenter = Rect.new(20, 0, 1004, 46),
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromScale(BAR_X0, BAR_Y),
	Size = UDim2.fromScale(BAR_X1 - BAR_X0, BAR_H),
	ZIndex = 2,
}, progress)
local fillFraction = (timeToX(PLAYED_MIN) - BAR_X0) / (BAR_X1 - BAR_X0)
image("Fill", "bar_fill", {
	ScaleType = Enum.ScaleType.Slice,
	SliceCenter = Rect.new(20, 0, 1004, 46),
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	Size = UDim2.fromScale(fillFraction, 1),
	ZIndex = 3,
}, track)
-- Lead cames halfway between milestones split the fill into glass panes.
local leads = frame("Leads", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), track, 4)
local mids = { (BAR_X0 + COLUMN_X[1]) / 2 }
for i = 1, COUNT - 1 do
	table.insert(mids, (COLUMN_X[i] + COLUMN_X[i + 1]) / 2)
end
for i, x in mids do
	new("Frame", {
		Name = "Came" .. i,
		BackgroundColor3 = C.lead,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale((x - BAR_X0) / (BAR_X1 - BAR_X0), 0.5),
		Size = UDim2.fromScale(0.0035, 0.62),
		ZIndex = 4,
	}, leads)
end
aspect(centred(image("StartCap", "icon_clock", { ZIndex = 6 }, progress), BAR_X0, BAR_Y, 0.075, 0.145), 1)

local markers = frame("Markers", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), progress, 5)
for i, r in REWARDS do
	local reached = PLAYED_MIN >= r.Min
	local h = r.Best and 0.19 or 0.16
	local m = centred(frame("M" .. r.Min, UDim2.new(), UDim2.new(), markers, 5), COLUMN_X[i], BAR_Y, 0.1, h)
	aspect(m, 1)
	m:SetAttribute("Minutes", r.Min)
	m:SetAttribute("Reached", reached)
	local glow = centred(image("Glow", "glow", { ZIndex = 5, ImageTransparency = 0.25 }, m), 0.5, 0.5, 1.9, 1.9)
	glow.Visible = reached
	local gemKey = (r.Best and "gem_best_" or "gem_") .. (reached and "on" or "off")
	centred(image("Gem", gemKey, { ZIndex = 6 }, m), 0.5, 0.5, 1, 1)
	text("Label", tostring(r.Min), HEADING, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, r.Best and 0.56 or 0.5),
		Size = UDim2.fromScale(r.Best and 0.42 or 0.56, r.Best and 0.26 or 0.36),
		TextColor3 = reached and C.white or C.slate,
		Stroke = 2,
		Max = 30,
		ZIndex = 7,
	}, m)
end

-- Play-time readout: a tag riding above the gems at the fill's head, with a needle down to the fill.
local tag = image("Time", "time_tag", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(timeToX(PLAYED_MIN), BAR_Y - 0.085),
	Size = UDim2.fromScale(0.2, 0.115),
	ZIndex = 8,
}, progress)
aspect(tag, 220 / 84)
local needle = new("Frame", {
	Name = "Needle",
	BackgroundColor3 = C.aquaLight,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.97),
	Size = UDim2.fromScale(0.022, 0.5),
	ZIndex = 7,
}, tag)
new("UIStroke", { Color = C.lead, Thickness = 1.5 }, needle)
text("Label", PLAYED_MIN .. " MIN", HEADING, {
	Position = UDim2.fromScale(0.1, 0.06),
	Size = UDim2.fromScale(0.8, 0.64),
	Stroke = 2,
	Max = 30,
	ZIndex = 9,
}, tag)

-- Reward cells ----------------------------------------------------------------------------------------------------
local row = frame("Rewards", UDim2.fromScale(ROW_X, 0.445), UDim2.fromScale(ROW_W, 0.47), panel, 2)
for i, r in REWARDS do
	local state = r.State
	local cell = frame("R" .. r.Min, UDim2.new(), UDim2.new(), row, 2)
	cell.AnchorPoint, cell.Position, cell.Size = Vector2.new(0.5, 0), UDim2.fromScale((i - 0.5) / COUNT, 0), UDim2.fromScale(0.17, 1)
	aspect(cell, CELL_ASPECT)
	cell:SetAttribute("Minutes", r.Min)
	cell:SetAttribute("State", state) -- Claimed | Ready | Next | Locked
	if r.Best then
		cell:SetAttribute("Best", true)
	end
	local locked = state == "Locked"

	local glow = centred(image("Glow", "glow", { ZIndex = 1, ImageTransparency = 0.1 }, cell), 0.5, 0.45, 1.75, 1.25)
	glow.ScaleType = Enum.ScaleType.Stretch
	glow.Visible = state == "Ready"
	local outline = centred(image("Outline", "cell_outline", { ZIndex = 2, ImageColor3 = C.aquaLight }, cell), 0.5, 0.5, 216 / 200, 326 / 310)
	outline.Visible = state == "Next"
	local frameKey = r.Best and "cell_best" or locked and "cell_locked" or state == "Ready" and "cell_ready" or "cell_open"
	image("Artwork", frameKey, { Size = UDim2.fromScale(1, 1), ZIndex = 3 }, cell)

	local plaque = centred(image("TimePlaque", "hud/label_plaque", { ZIndex = 8 }, cell), 0.5, 0.035, 0.84, 0.16)
	aspect(plaque, 300 / 88)
	if locked then
		plaque.ImageColor3 = C.slate
	end
	text("TimeLabel", r.Min .. " MIN", NUMBER, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.035),
		Size = UDim2.fromScale(0.62, 0.09),
		TextColor3 = C.lead,
		Max = 24,
		ZIndex = 9,
	}, cell)

	local icon = centred(image("Icon", r.Icon, { ZIndex = 4 }, cell), 0.5, 0.37, 0.62, 0.4)
	aspect(icon, 1)
	if locked then
		icon.ImageColor3, icon.ImageTransparency = C.slateDim, 0.15
	end
	text("Amount", r.Amount, HEADING, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.635),
		Size = UDim2.fromScale(0.86, 0.12),
		TextColor3 = locked and C.slate or C.white,
		Stroke = 2.5,
		Max = 34,
		ZIndex = 5,
	}, cell)

	-- Claimed: whole cell dimmed, check over the icon, "CLAIMED" in the bottom slot.
	local dim = image("Dim", "cell_dim", { Size = UDim2.fromScale(1, 1), ImageTransparency = 0.45, ZIndex = 6 }, cell)
	dim.Visible = state == "Claimed"
	local check = centred(image("ClaimedMark", "icon_check", { ZIndex = 7 }, cell), 0.5, 0.4, 0.52, 0.34)
	aspect(check, 1)
	check.Visible = state == "Claimed"
	local status = text("Status", "CLAIMED", HEADING, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.83),
		Size = UDim2.fromScale(0.76, 0.1),
		TextColor3 = C.emeraldLight,
		Stroke = 2,
		Max = 26,
		ZIndex = 7,
	}, cell)
	status.Visible = state == "Claimed"

	-- Ready: green CLAIM gem (green = claim everywhere) + glow behind the cell. The gem stays inside the inner pane.
	local claim = new("TextButton", {
		Name = "ClaimButton",
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.83),
		Size = UDim2.fromScale(0.74, 0.15),
		ZIndex = 8,
		Visible = state == "Ready",
	}, cell)
	claim:SetAttribute("StainedGlass", true)
	aspect(claim, 600 / 172)
	image("Artwork", "button/gem_emerald", { Size = UDim2.fromScale(1, 1), ZIndex = 8 }, claim)
	text("Label", "CLAIM", HEADING, {
		Position = UDim2.fromScale(0.14, 0.17),
		Size = UDim2.fromScale(0.72, 0.62),
		Stroke = 2.5,
		Max = 30,
		ZIndex = 9,
	}, claim)
	new("UIScale", { Name = "InteractionScale" }, claim)

	-- Next: aqua outline + countdown to unlock.
	local cdTag = centred(image("CountdownTag", "tag/tag_aqua", { ZIndex = 8 }, cell), 0.5, 0.83, 0.72, 0.14)
	aspect(cdTag, 300 / 80)
	cdTag.Visible = state == "Next"
	local cd = text("Countdown", state == "Next" and NEXT_LEFT or "", HEADING, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.83),
		Size = UDim2.fromScale(0.5, 0.09),
		Stroke = 2,
		Max = 28,
		ZIndex = 9,
	}, cell)
	cd.Visible = state == "Next"

	-- Locked: padlock in the bottom slot, reward shown greyed so it still tempts.
	local lock = centred(image("LockIcon", "icon_lock", { ZIndex = 8 }, cell), 0.5, 0.83, 0.3, 0.15)
	aspect(lock, 80 / 96)
	lock.Visible = locked

	if r.Best then
		local badge = centred(image("BestBadge", "gem_best_on", { ZIndex = 10 }, cell), 0.93, 0.14, 0.34, 0.22)
		aspect(badge, 1)
	end
end

gui.Parent = StarterGui
return "PlaytimeRewardsScreen rebuilt (fill " .. string.format("%.3f", fillFraction) .. ")"
