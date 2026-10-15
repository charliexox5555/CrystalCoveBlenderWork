-- One-time Edit-mode migration. Refuses to overwrite the creator's v0.5 edits.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before migration")
local starter, RS, storage = game.StarterGui, game.ReplicatedStorage, game.ServerStorage
assert(storage:FindFirstChild("UIBackup_v04"), "Back up StarterGui to UIBackup_v04 first")
assert(not starter.LobbyHUD:GetAttribute("StainedGlassV05"), "v0.5 already installed; preserve authored edits")
local modules = game.StarterPlayer.StarterPlayerScripts.Client.UI:Clone()
modules.Name, modules.Parent = "StainedGlassTemplateBuild", storage
local Theme = require(modules.Theme)
local S = require(modules.Components.StainedGlass)
local Portrait = require(modules.Components.GlassyPortrait)
local Glassies = require(RS.Shared.Config.Glassies)
local P = Theme.Palette
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
local function text(parent, name, copy, w, h, x, y, title, colour, max)
	local t = make("TextLabel", parent, name, {
		Text = copy,
		Size = UDim2.fromScale(w, h),
		Position = UDim2.fromScale(x, y),
		BackgroundTransparency = 1,
		TextColor3 = colour or P.milkLight,
		FontFace = if title then Theme.Fonts.Heading else Theme.Fonts.Body,
		TextScaled = true,
		TextWrapped = true,
	})
	make(
		"UITextSizeConstraint",
		t,
		"UITextSizeConstraint",
		{ MinTextSize = 8, MaxTextSize = (max or (if title then 34 else 20)) * 1.5 }
	)
	if title then
		make("UIStroke", t, "UIStroke", { Color = P.lead, Thickness = 2.5, LineJoinMode = Enum.LineJoinMode.Round })
	end
	return t
end
local function art(parent, name, path, w, h, x, y)
	return S.image(parent, name, path, UDim2.fromScale(w, h), UDim2.fromScale(x or 0, y or 0))
end
local function button(parent, name, copy, path, w, h, x, y)
	local b = make("TextButton", parent, name, {
		Text = "",
		Size = UDim2.fromScale(w, h),
		Position = UDim2.fromScale(x, y),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Selectable = true,
	})
	b:SetAttribute("StainedGlass", true)
	local a = art(b, "Artwork", path, 1, 1, 0, 0)
	S.aspect(b, a.UIAspectRatioConstraint.AspectRatio)
	make("UISizeConstraint", b, "UISizeConstraint", { MinSize = Vector2.new(44, 44) })
	local label = text(b, "Label", copy, 0.74, 0.66, 0.13, 0.17, true, nil, 30)
	label:SetAttribute("FitSingleLine", true)
	return b
end
local function gui(name, order)
	local g = starter:FindFirstChild(name) or make("ScreenGui", starter, name)
	g:ClearAllChildren()
	g.Enabled, g.ResetOnSpawn, g.ScreenInsets = false, false, Enum.ScreenInsets.CoreUISafeInsets
	g.DisplayOrder, g.ZIndexBehavior = order, Enum.ZIndexBehavior.Sibling
	g:SetAttribute("StainedGlassV05", true)
	return g
end
local function tag(parent, name, copy, colour, w, h, x, y)
	local a = art(parent, name, "tag/tag_" .. colour, w, h, x, y)
	text(a, "Label", copy, 0.72, 0.8, 0.14, 0.08, false, P.milkLight, 16)
	return a
end
local function hearts(parent, name, w, h, x, y)
	local row = frame(parent, name, w, h, x, y)
	make("UIListLayout", row, "UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0.04, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	for i = 1, 3 do
		local a = art(row, "Heart" .. i, "icon/heart_full", 0.28, 1, 0, 0)
		a.LayoutOrder = i
	end
	return row
end
local function portrait(parent, id, w, h, x, y, name)
	local v = Portrait.new(parent, id, UDim2.fromScale(w, h), UDim2.fromScale(x, y), name)
	S.aspect(v, 1)
	return v
end
local function currency(parent, name, icon, w, h, x, y)
	local f = art(parent, name, "hud/currency_plaque", w, h, x, y)
	f.Active = false
	art(f, "Icon", "icon/" .. icon, 0.3, 1.2, -0.05, -0.1)
	local t = text(
		f,
		name == "Coins" and "CoinsAmount" or "MarblesAmount",
		name == "Coins" and "1,250" or "0",
		0.72,
		0.7,
		0.23,
		0.15,
		false,
		P.lead,
		23
	)
	t.Active = false
	return f
end
local function shell(name, title, shop)
	local g = gui(name, 20)
	local dim = frame(g, "Backdrop", 1, 1, 0, 0)
	dim.BackgroundColor3 = P.lead
	dim.BackgroundTransparency = 0.4
	dim.Active = true
	local panel = frame(g, "Panel", if shop then 0.91 else 0.85, 0.9, 0.5, 0.5)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Active = true
	panel:SetAttribute("StainedGlass", true)
	S.aspect(panel, if shop then 3400 / 1880 else 3120 / 1760)
	art(panel, "WindowArtwork", if shop then "panel/window_shop" else "panel/window_inventory", 1, 1, 0, 0)
	art(panel, "TitleBanner", if shop then "panel/title_amber" else "panel/title_sapphire", 0.25, 0.14, 0.045, -0.035)
	text(panel, "Title", title, 0.215, 0.09, 0.063, -0.012, true, nil, 40)
	local close = button(panel, "Close", "", "button/close_diamond", 0.055, 0.1, 0.955, -0.025)
	art(close, "CloseIcon", "icon/close_x", 0.7, 0.7, 0.15, 0.15)
	local tabs = frame(panel, "Tabs", 0.62, 0.09, 0.04, 0.105)
	make("UIListLayout", tabs, "UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0.025, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	for i, entry in
		(if shop
			then {
				{ "KilnTab", "The Kiln", "amber" },
				{ "FlyersTab", "Flyers", "ruby" },
				{ "FinishersTab", "Finishers", "amethyst" },
				{ "MarblesTab", "Marbles", "aqua" },
			}
			else {
				{ "GlassiesTab", "Glassies", "aqua" },
				{ "FlyersTab", "Flyers", "ruby" },
				{ "FinishersTab", "Finishers", "amethyst" },
			})
	do
		local b = button(
			tabs,
			entry[1],
			entry[2],
			"tab/tab_" .. entry[3] .. (if i == 1 then "_active" else "_idle"),
			if shop then 0.22 else 0.25,
			1,
			0,
			0
		)
		b.LayoutOrder = i
		b.Active = i == 1
		b.Selectable = i == 1
		if i ~= 1 then
			b:SetAttribute("ComingSoon", true)
			b.Label.TextTransparency = 0.35
		end
	end
	local content = frame(panel, "Content", 0.94, 0.76, 0.03, 0.21)
	return g, panel, content
end
local function tile(parent, name, id)
	local d = Glassies.get(id)
	local t = frame(parent, name, 0.235, 0.45, 0, 0)
	S.aspect(t, 400 / 480)
	t:SetAttribute("StainedGlass", true)
	art(t, "Artwork", "tile/tile_" .. S.rarity(d.Rarity), 1, 1, 0, 0)
	portrait(t, id, 0.84, 0.72, 0.08, 0.05)
	art(t, "NamePlaque", "tile/name_plaque", 0.89, 0.17, 0.055, 0.81)
	local nameLabel = text(t, "Name", d.Name, 0.64, 0.13, 0.18, 0.83, false, P.lead, 17)
	nameLabel:SetAttribute("FitSingleLine", true)
	nameLabel.UITextSizeConstraint.MinTextSize = 1
	local selected = art(t, "SelectedOutline", "tile/selected_outline", 1.08, 1.067, -0.04, -0.033)
	selected.Visible = false
	selected.ZIndex = 3
	local tap = make(
		"TextButton",
		t,
		"Open",
		{ Text = "", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Selectable = true, ZIndex = 5 }
	)
	make("UISizeConstraint", tap, "UISizeConstraint", { MinSize = Vector2.new(44, 44) })
	return t
end
-- Lobby: two left hex controls, two display-only currencies, bottom-centre Play.
do
	local g = gui("LobbyHUD", 5)
	local nav = frame(g, "Navigation", 0.095, 0.44, 0.018, 0.12)
	for i, e in
		{ { "ShopButton", "Shop", "amber", "shop" }, { "InventoryButton", "Inventory", "sapphire", "inventory" } }
	do
		local b = button(nav, e[1], "", "hud/hex_" .. e[3], 0.86, 0.43, 0, (i - 1) * 0.5)
		b.Label.Visible = false
		art(b, "Icon", "icon/" .. e[4], 0.5, 0.5, 0.25, 0.15)
		local plaque = art(b, "LabelPlaque", "hud/label_plaque", 1, 0.26, 0, 0.79)
		text(plaque, "Label", e[2], 0.70, 0.8, 0.15, 0.1, false, P.lead, 18)
	end
	local money = frame(g, "Currency", 0.135, 0.15, 0.018, 0.59)
	currency(money, "Coins", "coin", 1, 0.38, 0, 0)
	currency(money, "Marbles", "marble", 1, 0.38, 0, 0.48)
	local play = button(g, "PlayButton", "PLAY", "button/gem_play", 0.28, 0.14, 0.5, 0.97)
	play.AnchorPoint = Vector2.new(0.5, 1)
	play.Label.UITextSizeConstraint.MaxTextSize = 52
	text(g, "Hint", "joins the nearest free arena", 0.38, 0.045, 0.31, 0.78, true, nil, 19)
end
-- Inventory shell and all reusable tiles / info elements.
do
	local g, p, c = shell("CollectionScreen", "INVENTORY", false)
	local grid = make("ScrollingFrame", c, "Grid", {
		Size = UDim2.fromScale(0.59, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 1),
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	})
	grid:SetAttribute("Role", "GlassyGrid")
	local templates = make("Folder", grid, "Templates")
	local proto = tile(templates, "GlassyTile", "pop")
	proto.Visible = false
	local tiles = frame(grid, "Tiles", 1, 1, 0, 0)
	make("UIGridLayout", tiles, "UIGridLayout", {
		CellSize = UDim2.fromScale(0.235, 0.31),
		CellPadding = UDim2.fromScale(0.015, 0.02),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	make("UIPadding", tiles, "UIPadding", {
		PaddingTop = UDim.new(0.01, 0),
		PaddingLeft = UDim.new(0.01, 0),
		PaddingRight = UDim.new(0.01, 0),
		PaddingBottom = UDim.new(0.01, 0),
	})
	local n = 0
	for _, d in Glassies.List do
		if RS.Assets.Glassies:FindFirstChild(d.Id) then
			n += 1
			local t = tile(tiles, d.Id, d.Id)
			t.LayoutOrder = n
		end
	end
	local info = frame(c, "InfoPane", 0.36, 1, 0.63, 0)
	S.aspect(info, 800 / 1000)
	art(info, "PaneArtwork", "panel/pane_dark", 1, 1, 0, 0).UIAspectRatioConstraint.AspectRatio = 800 / 1000
	text(info, "InfoName", "Pop", 0.88, 0.09, 0.06, 0.035, true, nil, 34).TextXAlignment = Enum.TextXAlignment.Left
	tag(info, "TypeTag", "Fizzy", "aqua", 0.28, 0.045, 0.06, 0.14)
	tag(info, "RarityTag", "Starter", "milk", 0.36, 0.045, 0.37, 0.14)
	text(info, "Stars", "☆☆☆☆☆", 0.88, 0.045, 0.06, 0.195, false, P.amber, 18)
	art(info, "ViewportPane", "panel/pane_viewport", 0.9, 0.25, 0.05, 0.25)
	portrait(info, "pop", 0.7, 0.24, 0.15, 0.255, "InfoPortrait")
	text(info, "PassiveCaption", "PASSIVE", 0.88, 0.025, 0.06, 0.52, false, P.aqua, 12).TextXAlignment =
		Enum.TextXAlignment.Left
	text(info, "PassiveName", "Fizz Burst", 0.88, 0.045, 0.06, 0.55, true, nil, 23).TextXAlignment =
		Enum.TextXAlignment.Left
	text(info, "PassiveDescription", "Fizzy glass hits with extra sparkle.", 0.88, 0.075, 0.06, 0.595, false, nil, 16).TextXAlignment =
		Enum.TextXAlignment.Left
	text(info, "PowerCaption", "POWER · FIRES ON ITS OWN", 0.88, 0.025, 0.06, 0.69, false, P.aqua, 12).TextXAlignment =
		Enum.TextXAlignment.Left
	text(info, "PowerName", "Pressure Pop", 0.88, 0.04, 0.06, 0.72, true, nil, 23).TextXAlignment =
		Enum.TextXAlignment.Left
	text(info, "PowerDescription", "A powerful swinging smash.", 0.88, 0.065, 0.06, 0.76, false, nil, 16).TextXAlignment =
		Enum.TextXAlignment.Left
	for i, e in { { "Power", "amber" }, { "HP", "emerald" }, { "Swing", "aqua" } } do
		local y = 0.85 + (i - 1) * 0.045
		text(info, e[1] .. "Label", string.upper(e[1]), 0.19, 0.03, 0.06, y, false, nil, 12).TextXAlignment =
			Enum.TextXAlignment.Left
		local track = art(info, e[1] .. "Track", "bar/stat_track", 0.6, 0.035, 0.25, y)
		local mask = frame(track, "FillMask", 0.7, 1, 0, 0)
		mask.ClipsDescendants = true
		art(mask, "Fill", "bar/stat_fill_" .. e[2], 1 / 0.7, 1, 0, 0)
		text(info, e[1] .. "Amount", "20", 0.1, 0.035, 0.87, y, false, nil, 14)
	end
end
-- Shop: exact live odds occupy the right pane throughout every pull.
do
	local g, p, c = shell("KilnScreen", "SHOP", true)
	currency(p, "Coins", "coin", 0.145, 0.085, 0.62, 0.11)
	currency(p, "Marbles", "marble", 0.145, 0.085, 0.79, 0.11)
	local hero = frame(c, "Hero", 0.66, 0.55, 0, 0)
	S.aspect(hero, 2160 / 760)
	art(hero, "Artwork", "kiln/hero_window", 1, 1, 0, 0)
	art(hero, "Glow", "kiln/glow", 0.32, 0.84, 0.02, 0.07)
	local kiln = make("ViewportFrame", hero, "KilnPortrait", {
		Size = UDim2.fromScale(0.34, 0.84),
		Position = UDim2.fromScale(0.01, 0.06),
		BackgroundTransparency = 1,
		Ambient = P.amberLight,
		LightColor = Color3.new(1, 1, 1),
	})
	S.aspect(kiln, 1)
	local world = make("WorldModel", kiln, "WorldModel")
	local source = workspace.Lobby:FindFirstChild("GlassClashProps")
	source = source and source:FindFirstChild("Kiln")
	if source then
		local model = make("Model", world, "KilnModel")
		for _, part in source:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 1 then
				local copy = part:Clone()
				copy:ClearAllChildren()
				copy.Anchored = true
				copy.Parent = model
			end
		end
		local cf, size = model:GetBoundingBox()
		model:PivotTo(CFrame.new(-cf.Position) * model:GetPivot())
		local camera = make("Camera", kiln, "Camera", {
			FieldOfView = 35,
			CFrame = CFrame.lookAt(
				Vector3.new(size.Magnitude * 0.35, size.Magnitude * 0.15, size.Magnitude * 1.4),
				Vector3.zero
			),
		})
		kiln.CurrentCamera = camera
	end
	text(hero, "KilnTitle", "THE KILN", 0.61, 0.2, 0.35, 0.1, true, nil, 44).TextXAlignment = Enum.TextXAlignment.Left
	text(
		hero,
		"KilnDescription",
		"Blow a brand-new glassy from molten glass.\nDuplicates add a star.",
		0.61,
		0.24,
		0.35,
		0.34,
		false,
		nil,
		19
	).TextXAlignment =
		Enum.TextXAlignment.Left
	button(hero, "Pull1", "PULL ×1 · 300", "button/gem_amber", 0.29, 0.23, 0.35, 0.67)
	button(hero, "Pull10", "PULL ×10 · 2,700", "button/gem_emerald", 0.29, 0.23, 0.66, 0.67)
	text(c, "PoolTitle", "IN THE KILN NOW", 0.64, 0.045, 0, 0.58, true, nil, 18).TextXAlignment =
		Enum.TextXAlignment.Left
	local pool = make("ScrollingFrame", c, "Pool", {
		Size = UDim2.fromScale(0.66, 0.30),
		Position = UDim2.fromScale(0, 0.65),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(1, 0),
		ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.X,
	})
	make("UIListLayout", pool, "UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0.025, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	make("UIPadding", pool, "UIPadding", { PaddingLeft = UDim.new(0.005, 0), PaddingRight = UDim.new(0.005, 0) })
	local f = make("Folder", pool, "Templates")
	local t = tile(f, "GlassyTile", "milk_bottle")
	t.Size = UDim2.fromScale(0.17, 1)
	t.Visible = false
	local odds = frame(c, "OddsPane", 0.30, 1, 0.70, 0)
	S.aspect(odds, 800 / 1120)
	art(odds, "Artwork", "panel/pane_dark", 1, 1, 0, 0).UIAspectRatioConstraint.AspectRatio = 800 / 1120
	text(odds, "OddsTitle", "ODDS", 0.88, 0.09, 0.06, 0.03, true, nil, 32).TextXAlignment = Enum.TextXAlignment.Left
	text(
		odds,
		"OddsHint",
		"Shown before every pull. Every glassy in a rarity is equally likely.",
		0.88,
		0.10,
		0.06,
		0.13,
		false,
		nil,
		15
	).TextXAlignment =
		Enum.TextXAlignment.Left
	local rows = frame(odds, "RarityRows", 0.88, 0.54, 0.06, 0.26)
	make("UIListLayout", rows, "UIListLayout", { Padding = UDim.new(0.027, 0), SortOrder = Enum.SortOrder.LayoutOrder })
	for i, r in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } do
		local row = art(rows, r, "panel/odds_row_" .. string.lower(r), 1, 0.13, 0, 0)
		row.LayoutOrder = i
		text(row, "Rarity", r, 0.57, 0.75, 0.12, 0.12, false, nil, 17).TextXAlignment = Enum.TextXAlignment.Left
		text(row, "Chance", "0%", 0.28, 0.75, 0.68, 0.12, false, nil, 17)
	end
	text(odds, "RainbowOdds", "Rainbow variant: 0%", 0.88, 0.055, 0.06, 0.83, false, nil, 14)
	text(odds, "PoolOdds", "", 0.88, 0.075, 0.06, 0.90, false, nil, 12)
	text(c, "Message", "", 0.66, 0.045, 0, 0.95, false, P.amberLight, 16)
end
-- Choose: authored card prototypes and top-corner player/hearts groups.
do
	local g = gui("RollScreen", 15)
	local roll = frame(g, "Roll", 1, 1, 0, 0)
	roll:SetAttribute("StainedGlass", true)
	text(roll, "Title", "CHOOSE YOUR GLASSY · 8", 0.5, 0.08, 0.25, 0.015, true, nil, 38)
	for side = 1, 2 do
		local f = frame(roll, "Player" .. side, 0.18, 0.15, if side == 1 then 0.025 else 0.795, 0.01)
		text(f, "OwnerName", if side == 1 then "YOU" else "Bottle Bot", 1, 0.35, 0, 0, true, nil, 23).TextXAlignment = if side
				== 1
			then Enum.TextXAlignment.Left
			else Enum.TextXAlignment.Right
		hearts(f, "Hearts", 0.7, 0.4, if side == 1 then 0 else 0.3, 0.4)
	end
	local cards = frame(roll, "Cards", 0.80, 0.65, 0.10, 0.13)
	make("UIListLayout", cards, "UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0.04, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local f = make("Folder", cards, "Templates")
	local function card(parent, name, id)
		local d = Glassies.get(id)
		local t = frame(parent, name, 0.29, 1, 0, 0)
		S.aspect(t, 920 / 1240)
		t:SetAttribute("StainedGlass", true)
		art(t, "Artwork", "card/card_" .. S.rarity(d.Rarity), 1, 1, 0, 0)
		text(t, "Name", d.Name, 0.86, 0.085, 0.07, 0.08, true, nil, 30)
		portrait(t, id, 0.84, 0.45, 0.08, 0.19)
		tag(t, "TypeTag", d.Type, S.Types[d.Type], 0.33, 0.055, 0.12, 0.66)
		tag(t, "RarityTag", d.Rarity, S.Rarity[d.Rarity], 0.39, 0.055, 0.49, 0.66)
		text(t, "Power", "Pressure Pop: a powerful smash.", 0.84, 0.15, 0.08, 0.76, false, nil, 18)
		local selected = art(t, "SelectedOutline", "card/selected_outline", 1.0435, 1.0323, -0.02175, -0.01615)
		selected.Visible = false
		selected.ZIndex = 4
		local b = make(
			"TextButton",
			t,
			"Select",
			{ Text = "", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Selectable = true }
		)
		make("UISizeConstraint", b, "UISizeConstraint", { MinSize = Vector2.new(44, 44) })
		return t
	end
	local proto = card(f, "GlassyCard", "pop")
	proto.Visible = false
	for i, id in { "pop", "jam", "prism" } do
		local c = card(cards, "Card" .. i, id)
		c.LayoutOrder = i
	end
	local reroll = button(roll, "Reroll", "REROLL · FREE", "button/gem_sapphire", 0.21, 0.10, 0.5, 0.88)
	reroll.AnchorPoint = Vector2.new(0.5, 0.5)
	text(
		roll,
		"Message",
		"Tap a card to pick. Picks stay hidden until both lock in.",
		0.72,
		0.045,
		0.14,
		0.95,
		false,
		nil,
		17
	)
end
-- Keep the working Aim/Countdown controls; replace fight panels with a billboard prototype.
do
	local g = starter.FightHud
	g:SetAttribute("StainedGlassV05", true)
	for _, name in { "Side1", "Side2", "VS", "PowerBanner1", "PowerBanner2" } do
		local o = g:FindFirstChild(name)
		if o then
			o:Destroy()
		end
	end
	local banner = art(g, "PowerBanner", "banner/power_aqua", 0.33, 0.09, 0.5, 0.035)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Visible = false
	local powerText = text(banner, "Label", "HOT STREAK!", 0.78, 0.75, 0.11, 0.125, true, nil, 32)
	powerText:SetAttribute("FitSingleLine", true)
	local assets = RS.Assets:FindFirstChild("UI") or make("Folder", RS.Assets, "UI")
	assert(not assets:FindFirstChild("FightBillboard"), "Billboard already exists")
	local bill = make("BillboardGui", assets, "FightBillboard", {
		Size = UDim2.fromScale(5, 2.5),
		StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0),
		AlwaysOnTop = false,
		MaxDistance = 180,
		Enabled = false,
	})
	local body = frame(bill, "Body", 1, 1, 0, 0)
	text(body, "OwnerName", "PLAYER", 1, 0.3, 0, 0, true, nil, 28)
	hearts(body, "Hearts", 0.62, 0.28, 0.19, 0.34)
	tag(body, "GlassyTag", "Pop", "aqua", 0.84, 0.19, 0.08, 0.72)
end
-- Existing auxiliary screens keep every binding; remove the previous rounded-corner skin.
for _, g in starter:GetChildren() do
	if g:IsA("ScreenGui") then
		g.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		for _, o in g:GetDescendants() do
			if o:IsA("UICorner") then
				o:Destroy()
			elseif o:IsA("TextLabel") or o:IsA("TextButton") then
				if not g:GetAttribute("StainedGlassV05") or g.Name == "FightHud" then
					o.FontFace = if o.Name == "Title"
							or o.Name == "Headline"
							or o:IsA("TextButton")
						then Theme.Fonts.Heading
						else Theme.Fonts.Body
				end
			end
		end
		g.Enabled = false
	end
end
require(game.StarterPlayer.StarterPlayerScripts.Client.UI.Components.StainedGlass).bindSlices(starter)
modules:Destroy()
return "Stained Glass v0.5 installed. Device formatting deliberately deferred."
