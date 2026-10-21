-- Edit mode (Studio MCP), with the Studio lock held. Builds StarterGui.ProfileScreen: the Stained Glass player
-- profile opened from the top bar's Profile button. Design only: no behaviour is wired; the build shows placeholder
-- data (Lv.4, 120/300 XP, 37 wins, 62%, best streak 5).
-- Layout and element names: docs/ui/screens/ProfileScreen.md. Art: tools/ui/profile_art.py.
-- VARIANT "Grids": the Glassies / Finishers / Flyers tabs show read-only grids inside the profile (option A).
-- VARIANT "Jump": those tabs carry an arrow badge and open the Inventory on that tab instead (option B).
-- PAGE picks the page shown in the saved build ("Profile" or, with VARIANT "Grids", "Glassies").
-- Re-runnable: replaces only ProfileScreen, after copying the previous one to ServerStorage.UIBackup_Topbar.
assert(not game:GetService("RunService"):IsRunning(), "Run in Edit")
local StarterGui, ServerStorage = game:GetService("StarterGui"), game:GetService("ServerStorage")

local VARIANT = "Grids"
local PAGE = "Profile"

-- Image ids (also in Config/UIAssets as screens/profile/* and the kit keys).
local A = {
	tabIdle = "rbxassetid://90010243896958",
	tabActive = "rbxassetid://99580315584236",
	portrait = "rbxassetid://85543514027212",
	namePlate = "rbxassetid://73357375001383",
	statAmber = "rbxassetid://128044873969831",
	statAqua = "rbxassetid://99211983728754",
	statRubyWide = "rbxassetid://95440625854768",
	xpTrack = "rbxassetid://95884890829347",
	xpFill = "rbxassetid://103999406609062",
	rewardsStrip = "rbxassetid://112713485025085",
	crown = "rbxassetid://95901055766653",
	winrate = "rbxassetid://111683525462250",
	flame = "rbxassetid://138668853430505",
	glassies = "rbxassetid://120940013228857",
	finishers = "rbxassetid://76476098201046",
	flyers = "rbxassetid://94219602724086",
	openBadge = "rbxassetid://122885890482531",
	-- kit
	titleRuby = "rbxassetid://128342047074629", -- panel/title_ruby
	tagAmber = "rbxassetid://108895420454763", -- tag/tag_amber
	tagSapphire = "rbxassetid://102972774392541", -- tag/tag_sapphire
	lock = "rbxassetid://103789030449627", -- screens/playtime_rewards/icon_lock
}

-- Placeholder data until LevelRules and the profile remotes exist.
local DATA = { Level = 4, Xp = 120, XpNext = 300, Wins = 37, WinRate = "62%", BestStreak = 5, Owned = 12, Total = 36 }
local userId = 1
pcall(function()
	userId = game:GetService("StudioService"):GetUserId()
end)
local userName = "Player"
pcall(function()
	userName = game:GetService("Players"):GetNameFromUserIdAsync(userId)
end)

local hex = Color3.fromHex
local C = {
	lead = hex("#1F1830"),
	white = hex("#FFFFFF"),
	amberLight = hex("#FFD98A"),
	aquaLight = hex("#9BF3F8"),
	rubyLight = hex("#FF8EA0"),
	slateLight = hex("#B7B3CC"),
	sapphireLight = hex("#93BCFF"),
}
local HEADING = Font.new("rbxasset://fonts/families/DenkOne.json")
local BODY = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy)

local function make(class, parent, name, props)
	local o = Instance.new(class)
	o.Name = name
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end
-- Scale box by centre: (cx, cy) centre, (w, h) size, all fractions of the parent.
local function box(cx, cy, w, h)
	return { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(cx, cy), Size = UDim2.fromScale(w, h) }
end
local function frame(parent, name, geo, z)
	return make("Frame", parent, name, {
		BackgroundTransparency = 1,
		ZIndex = z or 1,
		AnchorPoint = geo.AnchorPoint,
		Position = geo.Position,
		Size = geo.Size,
	})
end
local function image(parent, name, img, geo, z, aspect)
	local o = make("ImageLabel", parent, name, {
		Image = img,
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = z,
		AnchorPoint = geo.AnchorPoint,
		Position = geo.Position,
		Size = geo.Size,
	})
	if aspect then
		make("UIAspectRatioConstraint", o, "UIAspectRatioConstraint", { AspectRatio = aspect })
	end
	return o
end
local function text(parent, name, value, geo, z, style)
	local o = make("TextLabel", parent, name, {
		Text = value,
		BackgroundTransparency = 1,
		FontFace = style.Font or HEADING,
		TextColor3 = style.Color or C.white,
		TextScaled = true,
		TextXAlignment = style.AlignX or Enum.TextXAlignment.Center,
		ZIndex = z,
		AnchorPoint = geo.AnchorPoint,
		Position = geo.Position,
		Size = geo.Size,
	})
	make("UITextSizeConstraint", o, "UITextSizeConstraint", { MaxTextSize = style.Max or 40 })
	if style.Stroke ~= false then
		make("UIStroke", o, "UIStroke", {
			Color = C.lead,
			Thickness = style.Stroke or 2.5,
			LineJoinMode = Enum.LineJoinMode.Round,
		})
	end
	return o
end

-- Back up and remove the previous screen ----------------------------------------------------------------
local backups = ServerStorage:FindFirstChild("UIBackup_Topbar") or Instance.new("Folder")
backups.Name, backups.Parent = "UIBackup_Topbar", ServerStorage
local old = StarterGui:FindFirstChild("ProfileScreen")
if old then
	local prev = backups:FindFirstChild("ProfileScreen")
	if prev then
		prev:Destroy()
	end
	old:Clone().Parent = backups
	old:Destroy()
end

-- Screen and window (window, banner, title and close come from the Inventory panel like every menu) -----------
local gui = make("ScreenGui", nil, "ProfileScreen", {
	Enabled = false,
	ResetOnSpawn = false,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	DisplayOrder = 20,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
gui:SetAttribute("TopbarScreen", true)
gui:SetAttribute("DesignBuild", "build_profile_screen.luau")
gui:SetAttribute("Variant", VARIANT)
local source = StarterGui:WaitForChild("CollectionScreen"):WaitForChild("Panel")
local panel = make("Frame", gui, "Panel", {
	BackgroundTransparency = 1,
	Active = true,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.86, 0.9), -- the Inventory window's footprint
})
panel:SetAttribute("StainedGlass", true)
for _, part in { "UIAspectRatioConstraint", "WindowArtwork", "TitleBanner", "Title", "Close" } do
	source[part]:Clone().Parent = panel
end
panel.WindowArtwork.ZIndex = 0
panel.TitleBanner.ZIndex, panel.Title.ZIndex, panel.Close.ZIndex = 3, 4, 6
panel.TitleBanner.Image = A.titleRuby
panel.Title.Text = "PROFILE"
-- Panel fractions below assume its 1.773 aspect (Inventory's): 1 unit of height = 1/1.773 of width.
local ASPECT = panel.UIAspectRatioConstraint.AspectRatio

-- Left column: four big picture tabs ---------------------------------------------------------------------
local TABS = {
	{ Name = "Profile", Label = "Profile" },
	{ Name = "Glassies", Label = "Glassies", Icon = A.glassies },
	{ Name = "Finishers", Label = "Finishers", Icon = A.finishers },
	{ Name = "Flyers", Label = "Flyers", Icon = A.flyers },
}
local tabs = frame(
	panel,
	"Tabs",
	{ AnchorPoint = Vector2.zero, Position = UDim2.fromScale(0.045, 0.125), Size = UDim2.fromScale(0.12, 0.79) },
	2
)
local TAB_W = 1
local TAB_H = 0.12 * ASPECT / 1.2 / 0.79 -- tab art is 300x250 (1.2); fraction of the column's height
local TAB_GAP = (1 - 4 * TAB_H) / 3
for i, spec in TABS do
	local active = spec.Name == PAGE
	local tab = make("ImageButton", tabs, spec.Name .. "Tab", {
		Image = active and A.tabActive or A.tabIdle,
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, (i - 1) * (TAB_H + TAB_GAP)),
		Size = UDim2.fromScale(TAB_W, TAB_H),
	})
	tab:SetAttribute("Tab", spec.Name)
	tab:SetAttribute("Active", active)
	if spec.Name == "Profile" then
		-- Avatar headshot (runtime: rbxthumb AvatarHeadShot for the viewed player).
		local head = image(
			tab,
			"Icon",
			("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(userId),
			box(0.5, 0.39, 0.64, 0.64 * 1.2),
			2,
			1
		)
		head.ScaleType = Enum.ScaleType.Fit
	else
		image(tab, "Icon", spec.Icon, box(0.5, 0.39, 0.64, 0.64 * 1.2), 2, 1).ScaleType = Enum.ScaleType.Fit
		if VARIANT == "Jump" then
			-- Option B: the tab opens the Inventory on this tab; the arrow badge says "takes you somewhere".
			image(tab, "OpenBadge", A.openBadge, box(0.86, 0.17, 0.26, 0.26 * 1.2), 4, 1)
		end
	end
	text(tab, "Label", spec.Label, box(0.5, 0.85, 0.84, 0.19), 3, { Max = 30, Stroke = 2.5 })
	if not active then
		tab.Icon.ImageColor3 = Color3.fromRGB(205, 200, 220)
	end
end

-- Content: one page per tab -------------------------------------------------------------------------------
local content = frame(
	panel,
	"Content",
	{ AnchorPoint = Vector2.zero, Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1) },
	2
)

-- Profile page (all geometry in panel fractions; the page fills the panel).
local page = frame(
	content,
	"ProfilePage",
	{ AnchorPoint = Vector2.zero, Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1) },
	1
)
page.Visible = PAGE == "Profile"

-- Name plate across the top
local NAME_W = 0.6
local name = frame(page, "NamePlate", box(0.58, 0.178, NAME_W, NAME_W * ASPECT / (1000 / 110)), 1)
image(name, "Art", A.namePlate, box(0.5, 0.5, 1, 1), 1)
text(name, "Name", userName, box(0.5, 0.5, 0.86, 0.72), 2, { Max = 60, Stroke = 3 })

-- Avatar portrait with the level tag on its bottom edge and the XP bar under it
local PORT_W = 0.215
local PORT_H = PORT_W * ASPECT
local portrait = frame(page, "Portrait", box(0.3225, 0.255 + PORT_H / 2, PORT_W, PORT_H), 1)
image(portrait, "Art", A.portrait, box(0.5, 0.5, 1, 1), 1)
-- Runtime: a ViewportFrame with the player's avatar posed like a trophy; the design uses the 2D avatar render.
local avatar = image(
	portrait,
	"Avatar",
	("rbxthumb://type=Avatar&id=%d&w=420&h=420"):format(userId),
	box(0.5, 0.5, 0.86, 0.86),
	2,
	1
)
avatar.ScaleType = Enum.ScaleType.Fit
local level = frame(portrait, "Level", box(0.5, 0.97, 0.56, 0.56 / 3.75), 3)
image(level, "Tag", A.tagAmber, box(0.5, 0.5, 1, 1), 1)
text(level, "Text", "Lv." .. DATA.Level, box(0.5, 0.5, 0.7, 0.8), 2, { Max = 44, Stroke = 2.5 })

local XP_W = PORT_W
local xp = frame(page, "Xp", box(0.3225, 0.255 + PORT_H + 0.048, XP_W, XP_W * ASPECT / (600 / 84)), 1)
xp:SetAttribute("Xp", DATA.Xp)
xp:SetAttribute("XpNext", DATA.XpNext)
image(xp, "Track", A.xpTrack, box(0.5, 0.5, 1, 1), 1)
local fillClip = make("Frame", xp, "Fill", {
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromScale(0.01, 0.5),
	Size = UDim2.fromScale(0.98 * DATA.Xp / DATA.XpNext, 64 / 84), -- width = progress to the next level
	ZIndex = 2,
})
image(
	fillClip,
	"Art",
	A.xpFill,
	{ AnchorPoint = Vector2.zero, Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(DATA.XpNext / DATA.Xp, 1) },
	2
)
local xpText =
	text(page, "XpText", DATA.Xp .. " / " .. DATA.XpNext .. " XP", box(0.3225, 0.255 + PORT_H + 0.1, XP_W, 0.04), 2, {
		Font = BODY,
		Color = C.sapphireLight,
		Max = 24,
		Stroke = 2,
	})
xpText:SetAttribute("Format", "%d / %d XP")

-- Stat tiles: Wins and Win Rate side by side, Best Streak wide under them
local function statTile(name_, label, value, art, icon, labelColor, geo, wide)
	local tile = frame(page, name_, geo, 1)
	image(tile, "Art", art, box(0.5, 0.5, 1, 1), 1)
	text(
		tile,
		"Label",
		label,
		box(0.5, 0.24, wide and 0.5 or 0.8, 0.2),
		2,
		{ Max = 32, Color = labelColor, Stroke = 2.5 }
	)
	local iconW = wide and 0.11 or 0.24
	image(tile, "Icon", icon, box(wide and 0.4 or 0.3, 0.6, iconW, iconW * (wide and 810 / 205 or 400 / 205)), 2, 1).ScaleType =
		Enum.ScaleType.Fit
	local v = text(
		tile,
		"Value",
		tostring(value),
		box(wide and 0.56 or 0.62, 0.6, wide and 0.22 or 0.44, 0.46),
		2,
		{ Max = 90, Stroke = 3.5 }
	)
	v.TextXAlignment = wide and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
	return tile
end
local SW, SH = 0.245, 0.245 * ASPECT / (400 / 205)
statTile("Wins", "WINS", DATA.Wins, A.statAmber, A.crown, C.amberLight, box(0.455 + SW / 2, 0.255 + SH / 2, SW, SH))
statTile(
	"WinRate",
	"WIN RATE",
	DATA.WinRate,
	A.statAqua,
	A.winrate,
	C.aquaLight,
	box(0.955 - SW / 2, 0.255 + SH / 2, SW, SH)
)
local WW = 0.5
local WH = WW * ASPECT / (810 / 205)
statTile(
	"BestStreak",
	"BEST STREAK",
	DATA.BestStreak,
	A.statRubyWide,
	A.flame,
	C.rubyLight,
	box(0.705, 0.255 + SH + 0.014 + WH / 2, WW, WH),
	true
)

-- Level rewards: an empty strip kept for later (no rewards yet)
local RW = 0.74
local RH = RW * ASPECT / (1300 / 150)
local rewards = frame(page, "LevelRewards", box(0.585, 0.912 - RH / 2, RW, RH), 1)
image(rewards, "Art", A.rewardsStrip, box(0.5, 0.5, 1, 1), 1)
frame(rewards, "Track", box(0.5, 0.5, 0.92, 0.8), 2) -- reward cells go here later
image(rewards, "Lock", A.lock, box(0.5, 0.5, 0.06, 0.06 * 1300 / 150), 3, 1).ScaleType = Enum.ScaleType.Fit

-- Collection pages (option A): read-only grids that reuse the Inventory's tiles ---------------------------------
-- Tiles are the Inventory's GlassyTile template with the live GlassyPortrait (the same code the Inventory uses),
-- minus the Open button and selection outline. Finishers and Flyers will reuse CosmeticCatalog's tiles the same way.
local Portrait = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.UI.Components.GlassyPortrait)
local Glassies = require(game:GetService("ReplicatedStorage").Shared.Config.Glassies)
local UIAssets = require(game:GetService("ReplicatedStorage").Shared.Config.UIAssets)
local SAMPLE = {
	"pop",
	"jam",
	"prism",
	"fishbowl",
	"cookie_jar",
	"bubble_wand",
	"light_bulb",
	"potion_flask",
	"crystal_ball",
	"glass_unicorn",
}

local function glassyTile(id, order)
	local def = Glassies.get(id)
	local t = source.Content.Grid.Templates.GlassyTile:Clone()
	t.Name, t.LayoutOrder, t.Visible = id, order, true
	for _, n in { "Open", "SelectedOutline", "Unknown" } do
		local c = t:FindFirstChild(n)
		if c then
			c:Destroy()
		end
	end
	local rarity = string.lower(if def.Rarity == "Starter" then "Common" else def.Rarity)
	t.Artwork.Image = UIAssets["tile/tile_" .. rarity] or t.Artwork.Image
	t:FindFirstChild("Name").Text = def.Name
	local old = t.Portrait
	local geo, aspect = { old.Size, old.Position }, old:FindFirstChildOfClass("UIAspectRatioConstraint")
	aspect = aspect and aspect:Clone()
	old:Destroy()
	local vp = Portrait.new(t, id, geo[1], geo[2])
	vp.AnchorPoint, vp.Position = Vector2.new(0.5, 0.5), geo[2] -- Motion.center shifts it; put it back
	if aspect then
		aspect.Parent = vp
	end
	return t
end

local function collectionPage(name_, owned, total, ids)
	local p = frame(
		content,
		name_ .. "Page",
		{ AnchorPoint = Vector2.zero, Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1) },
		1
	)
	p.Visible = PAGE == name_
	local header = frame(p, "Count", box(0.58, 0.178, 0.26, 0.26 * ASPECT / 3.75), 2)
	image(header, "Tag", A.tagSapphire, box(0.5, 0.5, 1, 1), 1)
	text(header, "Text", owned .. " / " .. total, box(0.5, 0.5, 0.7, 0.78), 2, { Max = 44, Stroke = 2.5 })
	local grid = make("ScrollingFrame", p, "Grid", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.205, 0.255),
		Size = UDim2.fromScale(0.755, 0.66),
		CanvasSize = UDim2.new(), -- the runtime grows it with the rows (two rows fit without scrolling)
		ScrollBarThickness = 0,
		ZIndex = 2,
	})
	local tiles = frame(
		grid,
		"Tiles",
		{ AnchorPoint = Vector2.zero, Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1) },
		1
	)
	make("UIGridLayout", tiles, "UIGridLayout", {
		CellSize = UDim2.fromScale(0.18, 0.44),
		CellPadding = UDim2.fromScale(0.025, 0.07),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	make("Folder", grid, "Templates", {})
	for i, id in ids do
		glassyTile(id, i).Parent = tiles
	end
	return p
end
if VARIANT == "Grids" then
	collectionPage("Glassies", DATA.Owned, DATA.Total, SAMPLE)
	collectionPage("Finishers", 1, 12, {})
	collectionPage("Flyers", 0, 11, {})
end

gui.Parent = StarterGui
return ("ProfileScreen rebuilt (%s, %s page; previous copy in ServerStorage.UIBackup_Topbar)"):format(VARIANT, PAGE)
