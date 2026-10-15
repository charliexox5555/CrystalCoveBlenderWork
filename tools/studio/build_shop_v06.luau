-- Edit-only, one-time shop layout migration. Keeps the creator's shell and a full previous-shop copy.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before building the shop")
local RS, starter, storage = game.ReplicatedStorage, game.StarterGui, game.ServerStorage
local gui = starter.KilnScreen
assert(gui:GetAttribute("ShopLayoutVersion") ~= 6, "Shop v0.6 exists; preserve subsequent creator edits")
local backups = storage:FindFirstChild("UIBackups") or Instance.new("Folder")
backups.Name, backups.Parent = "UIBackups", storage
assert(not backups:FindFirstChild("ShopBeforeFeatured_20261015"), "Previous-shop backup already exists")
local before = gui:Clone()
before.Name, before.Parent = "ShopBeforeFeatured_20261015", backups
local modules = game.StarterPlayer.StarterPlayerScripts.Client.UI:Clone()
modules.Name, modules.Parent = "ShopTemplateBuild", storage
local Theme = require(modules.Theme)
local S = require(modules.Components.StainedGlass)
local Motion = require(modules.Components.Motion)
local Portrait = require(modules.Components.GlassyPortrait)
local P = Theme.Palette
local p, c = gui.Panel, gui.Panel.Content
local old = before.Panel.Content
local tileSource, buttonSource = old.Pool.Templates.GlassyTile, old.Hero.Pull1
local kilnSource = old.Hero.KilnPortrait
local function make(class, parent, name, props)
	local o = Instance.new(class)
	o.Name = name
	for k, v in props or {} do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function frame(parent, name, w, h, x, y)
	return make("Frame", parent, name, {
		Size = UDim2.fromScale(w, h),
		Position = UDim2.fromScale(x or 0, y or 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	})
end
local function text(parent, name, value, w, h, x, y, heading, max, color, wrap)
	local t = make("TextLabel", parent, name, {
		Size = UDim2.fromScale(w, h),
		Position = UDim2.fromScale(x, y),
		BackgroundTransparency = 1,
		Text = value,
		FontFace = heading and Theme.Fonts.Heading or Theme.Fonts.Body,
		TextColor3 = color or P.milkLight,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = wrap == true,
		TextWrapped = wrap == true,
		TextSize = max or 18,
	})
	make("UITextSizeConstraint", t, "UITextSizeConstraint", { MinTextSize = 1, MaxTextSize = max or 18 })
	if not wrap then
		t:SetAttribute("FitSingleLine", true)
	end
	return t
end
local function art(parent, name, asset, w, h, x, y)
	return S.image(parent, name, asset, UDim2.fromScale(w, h), UDim2.fromScale(x or 0, y or 0))
end
local function pane(parent, name, w, h, x, y)
	local f = frame(parent, name, w, h, x, y)
	local bg = art(f, "Artwork", "panel/pane_dark", 1, 1, 0, 0)
	bg:FindFirstChildOfClass("UIAspectRatioConstraint"):Destroy()
	bg:SetAttribute("StretchArtwork", true)
	return f
end
local function button(parent, name, value, tint, w, h, x, y)
	local b = buttonSource:Clone()
	b.Name, b.Size, b.Position, b.AnchorPoint =
		name, UDim2.fromScale(w, h), UDim2.fromScale(x + w / 2, y + h / 2), Vector2.new(0.5, 0.5)
	b.Active, b.Selectable = true, true
	S.setAsset(b.Artwork, "button/gem_" .. tint)
	b.Label.Text, b.Label.TextTransparency = value, 0
	b.Label.UITextSizeConstraint.MaxTextSize = 21
	b.Parent = parent
	return b
end
local function dormant(b)
	b.Active, b.Selectable = false, false
	b:SetAttribute("PreviewOnly", true)
	b.Label.TextTransparency = 0.25
end
local function preview(parent, name, id, w, h, x, y)
	local v = Portrait.new(parent, id, UDim2.fromScale(w, h), UDim2.fromScale(x, y), name)
	S.aspect(v, 1)
	return v
end
local function pool(parent, name, w, h, x, y)
	local f = make("ScrollingFrame", parent, name, {
		Size = UDim2.fromScale(w, h),
		Position = UDim2.fromScale(x, y),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.fromScale(1, 0),
		ClipsDescendants = true,
	})
	make("UIListLayout", f, "UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0.025, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local folder = make("Folder", f, "Templates")
	local tile = tileSource:Clone()
	tile.Name, tile.Visible, tile.Parent = "GlassyTile", false, folder
	return f
end
for _, child in c:GetChildren() do
	child:Destroy()
end
local oldTab = p.Tabs.KilnTab:Clone()
for _, child in p.Tabs:GetChildren() do
	if child:IsA("GuiObject") then
		child:Destroy()
	end
end
local tabs = { { "Featured", "amber" }, { "Glassies", "aqua" }, { "Finishers", "amethyst" }, { "Flyers", "ruby" } }
for i, entry in tabs do
	local b = oldTab:Clone()
	b.Name, b.LayoutOrder, b.Size, b.Parent = entry[1] .. "Tab", i, UDim2.fromScale(0.22, 1), p.Tabs
	b.Active, b.Selectable = true, true
	b:SetAttribute("TabTint", entry[2])
	b.Label.Text, b.Label.TextTransparency = entry[1], 0
	S.setAsset(b.Artwork, "tab/tab_" .. entry[2] .. (i == 1 and "_active" or "_idle"))
	Motion.center(b)
end
oldTab:Destroy()
local featured = frame(c, "FeaturedPage", 1, 0.95)
text(featured, "DailyTitle", "DAILY SHOP", 0.48, 0.075, 0.02, 0, true, 28)
text(featured, "RefreshTimer", "Refreshes in --:--:--", 0.46, 0.06, 0.52, 0.01, false, 15, P.amberLight).TextXAlignment =
	Enum.TextXAlignment.Right
local offers = frame(featured, "DailyOffers", 0.96, 0.48, 0.02, 0.09)
local samples = {
	{ "milk_bottle", "Milk Bottle", "coin" },
	{ "glass_cup", "Glass Cup", "coin" },
	{ "hot_sauce", "Hot Sauce", "marble" },
	{ "crystal_tumbler", "Crystal Tumbler", "marble" },
}
for i, entry in samples do
	local card = pane(offers, "Offer" .. i, 0.235, 1, (i - 1) * 0.255, 0)
	card:SetAttribute("SampleGlassy", entry[1])
	card:SetAttribute("PreviewOnly", true)
	preview(card, "Portrait", entry[1], 0.78, 0.60, 0.11, 0.04)
	text(card, "ItemName", entry[2], 0.88, 0.12, 0.06, 0.66, false, 17).TextXAlignment = Enum.TextXAlignment.Center
	local price = button(card, "Price", "COMING SOON", entry[3] == "coin" and "amber" or "aqua", 0.9, 0.19, 0.05, 0.79)
	price.Label.UITextSizeConstraint.MaxTextSize = 15
	dormant(price)
	card:SetAttribute("Currency", entry[3] == "coin" and "Coins" or "Marbles")
end
local showcase = pane(featured, "Showcase", 0.96, 0.36, 0.02, 0.61)
art(showcase, "Glint", "kiln/glow", 0.30, 0.98, 0.66, 0)
text(showcase, "Eyebrow", "FEATURED COLLECTION", 0.53, 0.12, 0.04, 0.08, false, 13, P.aqua)
text(showcase, "Title", "Find your next favorite.", 0.57, 0.26, 0.04, 0.23, true, 29)
text(showcase, "Description", "Discover glassies from both Kilns.", 0.55, 0.16, 0.04, 0.50, false, 16)
button(showcase, "Explore", "EXPLORE GLASSIES", "amber", 0.38, 0.22, 0.04, 0.71)
preview(showcase, "ShowcasePop", "pop", 0.17, 0.78, 0.58, 0.12)
preview(showcase, "ShowcaseJam", "jam", 0.17, 0.78, 0.71, 0.12)
preview(showcase, "ShowcasePrism", "prism", 0.17, 0.78, 0.83, 0.12)
task.wait()
local glassies = frame(c, "GlassiesPage", 1, 0.95)
glassies.Visible = false
for i, entry in { { "CoinKiln", "COIN KILN", "coin", "amber" }, { "MarbleKiln", "MARBLE KILN", "marble", "aqua" } } do
	local card = pane(glassies, entry[1], 0.47, 0.98, i == 1 and 0.02 or 0.51, 0)
	card:SetAttribute("Currency", i == 1 and "Coins" or "Marbles")
	if i == 2 then
		card:SetAttribute("PreviewOnly", true)
	end
	local icon = art(card, "CurrencyIcon", "icon/" .. entry[3], 0.075, 0.085, 0.035, 0.025)
	icon.Image = p[i == 1 and "Coins" or "Marbles"].Icon.Image
	text(card, "Title", entry[2], 0.82, 0.075, 0.13, 0.025, true, 25)
	local viewport = kilnSource:Clone()
	viewport.Name, viewport.Size, viewport.Position =
		"KilnPortrait", UDim2.fromScale(0.44, 0.47), UDim2.fromScale(0.035, 0.13)
	viewport:SetAttribute("EditHint", "Separate editable kiln copy: expand WorldModel. Recolor MarbleKiln here.")
	viewport.Parent = card
	viewport.WorldModel.KilnModel.Name = entry[1] .. "Model"
	local odds = frame(card, "OddsPane", 0.49, 0.49, 0.485, 0.115)
	text(
		odds,
		"Title",
		i == 1 and "ODDS" or "ODDS · SOON",
		1,
		0.12,
		0,
		0,
		false,
		20,
		i == 1 and P.amberLight or P.aqua
	)
	local rows = frame(odds, "RarityRows", 1, 0.80, 0, 0.14)
	make("UIListLayout", rows, "UIListLayout", { Padding = UDim.new(0.012, 0), SortOrder = Enum.SortOrder.LayoutOrder })
	for index, rarity in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } do
		local row = old.OddsPane.RarityRows[rarity]:Clone()
		row.Name, row.LayoutOrder, row.Size, row.Parent = rarity, index, UDim2.fromScale(1, 0.15), rows
		row.Chance.Text = "—"
		row.Rarity.UITextSizeConstraint.MaxTextSize = 18
		row.Chance.UITextSizeConstraint.MaxTextSize = 18
	end
	text(odds, "RainbowOdds", i == 1 and "Rainbow: 0.20%" or "COMING SOON", 1, 0.07, 0, 0.95, false, 12, P.aqua)
	text(card, "PoolTitle", i == 1 and "PRIZE PREVIEW" or "SAMPLE PREVIEW", 0.59, 0.06, 0.035, 0.625, true, 19)
	local all = button(card, "ViewAll", "VIEW ALL ›", entry[4], 0.28, 0.08, 0.69, 0.615)
	all.Label.UITextSizeConstraint.MaxTextSize = 14
	pool(card, "Pool", 0.93, 0.17, 0.035, 0.705)
	local one = button(card, "Pull1", i == 1 and "OPEN 1 · 300" or "OPEN 1 · —", entry[4], 0.44, 0.10, 0.035, 0.89)
	local ten =
		button(card, "Pull10", i == 1 and "OPEN 10 · 2,700" or "OPEN 10 · —", entry[4], 0.44, 0.10, 0.525, 0.89)
	if i == 2 then
		dormant(one)
		dormant(ten)
	end
end
task.wait()
for _, entry in
	{
		{ "Finishers", "Make every shatter your own.", "heart_broken", "amethyst" },
		{ "Flyers", "A new way to arrive in style.", "marble", "ruby" },
	}
do
	local page = frame(c, entry[1] .. "Page", 1, 0.95)
	page.Visible = false
	local body = pane(page, "Preview", 0.96, 0.96, 0.02, 0.01)
	art(body, "Icon", "icon/" .. entry[3], 0.13, 0.30, 0.435, 0.13)
	text(body, "Title", string.upper(entry[1]), 0.88, 0.12, 0.06, 0.47, true, 34).TextXAlignment =
		Enum.TextXAlignment.Center
	text(body, "Description", entry[2], 0.88, 0.08, 0.06, 0.63, false, 22).TextXAlignment = Enum.TextXAlignment.Center
	text(body, "Status", "COMING SOON", 0.88, 0.08, 0.06, 0.78, false, 16, P.aqua).TextXAlignment =
		Enum.TextXAlignment.Center
end
local all = frame(c, "PoolPage", 1, 0.95)
all.Visible = false
button(all, "Back", "‹ BACK", "aqua", 0.18, 0.095, 0.02, 0.005)
text(all, "Title", "COIN KILN · ALL GLASSIES", 0.75, 0.09, 0.23, 0.005, true, 27)
local grid = make("ScrollingFrame", all, "Grid", {
	Size = UDim2.fromScale(0.96, 0.86),
	Position = UDim2.fromScale(0.02, 0.13),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromScale(0, 1),
	ScrollBarThickness = 4,
})
make("UIGridLayout", grid, "UIGridLayout", {
	CellSize = UDim2.fromScale(0.18, 0.46),
	CellPadding = UDim2.fromScale(0.025, 0.03),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
local templates = make("Folder", grid, "Templates")
local tile = tileSource:Clone()
tile.Name, tile.Visible, tile.Parent = "GlassyTile", false, templates
text(c, "Message", "", 0.96, 0.045, 0.02, 0.955, false, 14, P.amberLight)
gui.Enabled = false
gui:SetAttribute("ShopLayoutVersion", 6)
gui:SetAttribute("DefaultTab", "Featured")
S.bindSlices(gui)
modules:Destroy()
return "Shop v0.6 installed; prior template saved under ServerStorage.UIBackups.ShopBeforeFeatured_20261015"
