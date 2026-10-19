-- Edit mode (Studio MCP), with the Studio lock held. Builds StarterGui.DailyRewardsScreen: the Stained Glass Daily
-- Rewards window opened from the top bar's Rewards dropdown (decision 98). Design only: no behaviour is wired; the
-- build shows a mid-week example (Days 1-2 claimed, Day 3 today, Days 4-7 locked, progress 3/7); set SCENARIO
-- to "Day7" to preview the weekly prize's claim state.
-- Layout and element names: docs/ui/screens/DailyRewardsScreen.md. Art: tools/ui/daily_rewards_art.py.
-- Re-runnable: replaces only DailyRewardsScreen, after copying the previous one to ServerStorage.UIBackup_Topbar.
assert(not game:GetService("RunService"):IsRunning(), "Run in Edit")
local StarterGui, ServerStorage = game:GetService("StarterGui"), game:GetService("ServerStorage")

-- Image ids (also in Config/UIAssets as screens/daily_rewards/* and the kit keys).
local A = {
	cellLocked = "rbxassetid://112424900545322",
	cellClaimed = "rbxassetid://123062189542207",
	cellToday = "rbxassetid://89477285281517",
	cellDay7 = "rbxassetid://120953856890626",
	glowToday = "rbxassetid://71166976377615",
	glowBurst = "rbxassetid://77624391348245",
	check = "rbxassetid://89983929075705",
	track = "rbxassetid://103459116303156",
	segOff = "rbxassetid://83486640438740",
	segLit = "rbxassetid://108615290612409",
	segToday = "rbxassetid://134509086525244",
	gemOff = "rbxassetid://101814573321454",
	gemLit = "rbxassetid://85620972073701",
	sparkle = "rbxassetid://117952041961855",
	timerPlaque = "rbxassetid://136293032496465",
	clock = "rbxassetid://95614830605707",
	-- kit
	titleAmber = "rbxassetid://98596836833682", -- panel/title_amber
	gemEmerald = "rbxassetid://108061531278853", -- button/gem_emerald (claim)
	bannerRuby = "rbxassetid://83218652456640", -- banner/power_ruby
	labelPlaque = "rbxassetid://95988431808015", -- hud/label_plaque
	coin = "rbxassetid://139764505735042", -- icon/coin
	marble = "rbxassetid://126376968177419", -- icon/marble
	tag = {
		Claimed = "rbxassetid://92936516115203", -- tag/tag_emerald
		Today = "rbxassetid://108895420454763", -- tag/tag_amber
		Locked = "rbxassetid://92043931376308", -- tag/tag_slate
		Day7 = "rbxassetid://80087951112210", -- tag/tag_amethyst
	},
}
local CELL_ART = { Claimed = A.cellClaimed, Today = A.cellToday, Locked = A.cellLocked }
local SEG_ART = { Claimed = A.segLit, Today = A.segToday, Locked = A.segOff }

local hex = Color3.fromHex
local C = {
	lead = hex("#1F1830"),
	white = hex("#FFFFFF"),
	emeraldLight = hex("#86EDB8"),
	amberLight = hex("#FFD98A"),
	milk = hex("#EEE7D9"),
	slateLight = hex("#B7B3CC"),
}
local HEADING = Font.new("rbxasset://fonts/families/DenkOne.json")
local BODY = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy)

-- Which example the build shows: "MidWeek" (the saved design: Days 1-2 claimed, Day 3 today, 3/7) or "Day7"
-- (Days 1-6 claimed, Day 7 today, 7/7) to preview the weekly prize's claim state.
local SCENARIO = "MidWeek"
local STREAK = SCENARIO == "Day7" and 7 or 3 -- "x/7": today's place in the week
-- Rewards are placeholders until the reward table is decided.
local DAYS = {
	{ Icon = A.coin, Amount = "x50" },
	{ Icon = A.coin, Amount = "x75" },
	{ Icon = A.coin, Amount = "x100" },
	{ Icon = A.coin, Amount = "x150" },
	{ Icon = A.marble, Amount = "x1" },
	{ Icon = A.coin, Amount = "x250" },
	{ Icon = A.marble, Amount = "x5" },
}
for n, day in DAYS do
	day.State = n < STREAK and "Claimed" or n == STREAK and "Today" or "Locked"
	if n == STREAK + 1 then
		day.Status = "TOMORROW"
	elseif n == 7 and day.State == "Locked" then
		day.Status = (7 - STREAK) .. " DAYS TO GO"
	end
end

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
	local o = make(style.Button and "TextButton" or "TextLabel", parent, name, {
		Text = value,
		BackgroundTransparency = 1,
		FontFace = style.Font or HEADING,
		TextColor3 = style.Color or C.white,
		TextScaled = true,
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
local old = StarterGui:FindFirstChild("DailyRewardsScreen")
if old then
	local prev = backups:FindFirstChild("DailyRewardsScreen")
	if prev then
		prev:Destroy()
	end
	old:Clone().Parent = backups
	old:Destroy()
end

-- Screen and window (window, banner, title and close come from the Inventory panel like every menu) -----------
local gui = make("ScreenGui", nil, "DailyRewardsScreen", {
	Enabled = false,
	ResetOnSpawn = false,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	DisplayOrder = 20,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
gui:SetAttribute("TopbarScreen", true)
gui:SetAttribute("DesignBuild", "build_daily_rewards_screen.luau")
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
panel.TitleBanner.Image = A.titleAmber
panel.Title.Text = "DAILY REWARDS"

-- Progress: leaded track, seven glass segments, Day 7 gem, "x/7" plaque -----------------------------------
local progress = make("Frame", panel, "Progress", {
	BackgroundTransparency = 1,
	Position = UDim2.fromScale(0.05, 0.118),
	Size = UDim2.fromScale(0.9, 0.095),
	ZIndex = 2,
})
progress:SetAttribute("Streak", STREAK)
image(progress, "Track", A.track, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromScale(0.79, 0.58) }, 1)
local segments = make("Frame", progress, "Segments", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromScale(0.022, 0.5),
	Size = UDim2.fromScale(0.725, 0.42),
	ZIndex = 2,
})
local SEG_GAP = 0.008
local segW = (1 - 6 * SEG_GAP) / 7
for i = 1, 7 do
	local state = DAYS[i].State
	local seg = image(segments, "Seg" .. i, SEG_ART[state], {
		AnchorPoint = Vector2.zero,
		Position = UDim2.fromScale((i - 1) * (segW + SEG_GAP), 0),
		Size = UDim2.fromScale(segW, 1),
	}, 1)
	seg:SetAttribute("State", state)
end
local gem = image(progress, "Gem", STREAK >= 7 and A.gemLit or A.gemOff, box(0.79, 0.5, 0.2, 1.05), 3, 1)
gem:SetAttribute("Lit", STREAK >= 7)
image(progress, "CountPlaque", A.labelPlaque, box(0.918, 0.5, 0.163, 0.8), 2, 300 / 88)
local count = text(progress, "Count", STREAK .. "/7", box(0.918, 0.5, 0.11, 0.56), 3, { Font = BODY, Color = C.lead, Stroke = false, Max = 34 })
count:SetAttribute("TextFit", false)

-- Day cells: 4 columns x 2 rows; Days 1-6 in columns 1-3, Day 7 spans both rows of column 4 -------------
local days = make("Frame", panel, "Days", {
	BackgroundTransparency = 1,
	Position = UDim2.fromScale(0.045, 0.245),
	Size = UDim2.fromScale(0.91, 0.595),
	ZIndex = 2,
})
local COL_W, COL_GAP, ROW_GAP = 0.2192, 0.01758, 0.05
local ROW_H = (1 - ROW_GAP) / 2

local function dayCell(n, spec, big)
	local col, row = (n - 1) % 3, (n - 1) // 3
	local cell = make("Frame", days, "Day" .. n, {
		BackgroundTransparency = 1,
		Position = big and UDim2.fromScale(3 * (COL_W + COL_GAP), 0)
			or UDim2.fromScale(col * (COL_W + COL_GAP), row * (ROW_H + ROW_GAP)),
		Size = big and UDim2.fromScale(1 - 3 * (COL_W + COL_GAP), 1) or UDim2.fromScale(COL_W, ROW_H),
		ZIndex = 1,
	})
	cell:SetAttribute("Day", n)
	cell:SetAttribute("State", spec.State)
	local claimed, today = spec.State == "Claimed", spec.State == "Today"
	-- y positions of the stack (fractions of the cell); Day 7 is taller, so its rows sit differently
	local Y = big and { tag = 0.045, icon = 0.45, amount = 0.705, bottom = 0.865, mark = 0.56 }
		or { tag = 0.075, icon = 0.405, amount = 0.66, bottom = 0.86, mark = 0.52 }

	local glow = image(cell, "Glow", A.glowToday, box(0.5, 0.5, 1.26, 1.26), 0)
	glow.Visible = today
	local art = image(cell, "Art", big and A.cellDay7 or CELL_ART[spec.State], box(0.5, 0.5, 1, 1), 1)
	if big and claimed then
		art.ImageColor3 = Color3.fromRGB(150, 150, 165) -- Day 7 keeps its frame and dims when claimed
	end

	local tagW = 0.5
	local tagH = tagW * (big and 300 / 386 or 300 / 242) / 3.75
	image(cell, "LabelTag", big and A.tag.Day7 or A.tag[spec.State], box(0.5, Y.tag, tagW, tagH), 3)
	text(cell, "Label", "DAY " .. n, box(0.5, Y.tag, tagW * 0.66, tagH * 0.8), 4, { Max = 30, Stroke = 2 })

	if big then
		image(cell, "Badge", A.bannerRuby, box(0.5, 0.165, 0.78, 0.78 * 300 / 386 / 5.45), 3)
		text(cell, "BadgeText", "BIG PRIZE!", box(0.5, 0.165, 0.56, 0.07), 4, { Max = 30, Stroke = 2 })
		local burst = image(cell, "IconGlow", A.glowBurst, box(0.5, Y.icon, 0.95, 0.95 * 300 / 386), 2)
		burst.ImageTransparency = claimed and 0.7 or 0
		local sparkles = make("Folder", cell, "Sparkles", {})
		for i, s in { { 0.2, 0.31, 0.12 }, { 0.82, 0.37, 0.1 }, { 0.75, 0.6, 0.08 } } do
			local sp = image(sparkles, "Sparkle" .. i, A.sparkle, box(s[1], s[2], s[3], s[3] * 300 / 386), 4)
			sp.Visible = not claimed
		end
	end

	local iconW = big and 0.52 or 0.38 * 242 / 300
	local icon = image(cell, "Icon", spec.Icon, box(0.5, Y.icon, iconW, big and iconW * 300 / 386 or 0.38), 3, 1)
	icon.ScaleType = Enum.ScaleType.Fit
	local amount = text(cell, "Amount", spec.Amount, box(0.5, Y.amount, 0.8, big and 0.1 or 0.16), 4, { Max = big and 48 or 34, Stroke = 3 })
	if claimed then
		icon.ImageTransparency = 0.45
		amount.TextTransparency = 0.45
		amount.UIStroke.Transparency = 0.45
	end

	local markW = big and 0.22 or 0.26 * 242 / 300
	local mark = image(cell, "ClaimedMark", A.check, box(big and 0.68 or 0.63, Y.mark, markW, big and markW * 300 / 386 or 0.26), 5, 1)
	mark.Visible = claimed

	local btnW = big and 0.7 or 0.62
	local btnH = btnW * (big and 300 / 386 or 300 / 242) / (600 / 172)
	local button = make("ImageButton", cell, "ClaimButton", {
		Image = A.gemEmerald,
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 5,
		Visible = today,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, Y.bottom),
		Size = UDim2.fromScale(btnW, btnH),
	})
	text(button, "Caption", "CLAIM!", box(0.5, 0.5, 0.62, 0.56), 6, { Max = 30, Stroke = 2.5 })

	local statusText = claimed and "CLAIMED" or spec.Status or ""
	local status = text(cell, "Status", statusText, box(0.5, Y.bottom, 0.8, big and 0.065 or 0.13), 4, {
		Font = BODY,
		Color = claimed and C.emeraldLight or C.slateLight,
		Max = 22,
		Stroke = 2,
	})
	status.Visible = not today and statusText ~= ""
	return cell
end
for n = 1, 6 do
	dayCell(n, DAYS[n], false)
end
dayCell(7, DAYS[7], true)

-- Timer: when the next reward unlocks (or "Come back tomorrow!") ------------------------------------------
local timer = make("Frame", panel, "Timer", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.902),
	Size = UDim2.fromScale(0.34, 0.066),
	ZIndex = 2,
})
image(timer, "Plaque", A.timerPlaque, box(0.5, 0.5, 1, 1), 1)
image(timer, "ClockIcon", A.clock, box(0.035, 0.5, 0.16, 1.5), 3, 1).ScaleType = Enum.ScaleType.Fit
text(timer, "Text", "Next reward in 12:34:56", box(0.53, 0.5, 0.8, 0.62), 2, { Font = BODY, Color = C.lead, Stroke = false, Max = 26 })

gui.Parent = StarterGui
return "DailyRewardsScreen rebuilt (previous copy in ServerStorage.UIBackup_Topbar)"
