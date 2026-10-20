-- Stained-glass queue board that floats above each Clash Stand: the arena name on a banner, two players in hex
-- frames with VS, "1 / 2 PLAYERS", "WIN 100" and a status plaque. Built from the UI kit (pane, banner, hexes,
-- plaque) so it matches the menus. Built and updated by the server so every player sees the same thing;
-- properties are only written when they change.
local RS = game:GetService("ReplicatedStorage")
local Balance = require(RS.Shared.Config.Balance)
local UIAssets = require(RS.Shared.Config.UIAssets)
local Theme = require(game.StarterPlayer.StarterPlayerScripts.Client.UI.Theme)
local Feel = Balance.Feel
local Board = {}

local LEAD = Theme.Colors.Shadow
local GOLD = Theme.Colors.Highlight

local function make(class, parent, props)
	local object = Instance.new(class)
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function image(parent, name, key, size, position, props)
	local img = make("ImageLabel", parent, {
		Name = name,
		Size = size,
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = UIAssets[key] or "",
		ScaleType = Enum.ScaleType.Fit,
	})
	for k, v in props or {} do
		img[k] = v
	end
	return img
end

local function text(parent, name, value, size, position, font, color, outline)
	local label = make("TextLabel", parent, {
		Name = name,
		Text = value,
		Size = size,
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		FontFace = font,
		TextColor3 = color or Theme.Colors.Text,
		TextScaled = true,
		ZIndex = 4,
	})
	if outline ~= false then
		make("UIStroke", label, { Color = LEAD, Thickness = outline or 2.5, LineJoinMode = Enum.LineJoinMode.Round })
	end
	return label
end

-- A player slot: a stained-glass hex (blue side A, amber side B, like the pads) with the headshot inside and the
-- name on a small plaque under it.
local HEX = { "hud/hex_sapphire", "hud/hex_amber" }
local function portrait(parent, side)
	local x = if side == 1 then 0.22 else 0.78
	local hex = image(parent, "Side" .. side, HEX[side], UDim2.fromScale(0.3, 0.5), UDim2.fromScale(x, 0.47), {
		ZIndex = 2,
	})
	make("UIAspectRatioConstraint", hex, { AspectRatio = 0.882 })
	local avatar = image(hex, "Avatar", "", UDim2.fromScale(0.66, 0.58), UDim2.fromScale(0.5, 0.5), { ZIndex = 3 })
	avatar.Image = ""
	local empty = text(hex, "Empty", "?", UDim2.fromScale(0.5, 0.4), UDim2.fromScale(0.5, 0.5), Theme.Fonts.Heading)
	local name = text(
		parent,
		"PlayerName",
		"",
		UDim2.fromScale(0.36, 0.1),
		UDim2.fromScale(x, 0.79),
		Theme.Fonts.Body,
		Theme.Colors.Text,
		2
	)
	return { Image = avatar, Empty = empty, Name = name }
end

function Board.build(arena)
	local bar = arena.Stand:FindFirstChild("Crossbar")
	local old = bar:FindFirstChild("ArenaLabelAnchor")
	if old then
		old:Destroy() -- the previous plain text sign
	end
	local anchor = bar:FindFirstChild("ArenaBoardAnchor") or Instance.new("Attachment")
	anchor.Name, anchor.Position, anchor.Parent = "ArenaBoardAnchor", Vector3.yAxis * Feel.ArenaBoardHeight, bar
	local existing = anchor:FindFirstChild("ArenaStatus")
	if existing then
		existing:Destroy()
	end
	-- Sized in studs so it reads like a sign hanging over the stand; only drawn when you are near enough to
	-- join or watch (ArenaBoardMaxDistance), so the lobby skyline stays clean.
	-- Named ArenaStatus: FightView hides billboards with this name while the fight camera runs.
	local gui = make("BillboardGui", anchor, {
		Name = "ArenaStatus",
		Size = UDim2.fromScale(Feel.ArenaBoardWidth, Feel.ArenaBoardWidth * 0.66),
		MaxDistance = Feel.ArenaBoardMaxDistance,
		LightInfluence = 0,
		AlwaysOnTop = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	gui:SetAttribute("ArenaActive", true)
	-- Dark cut-glass pane (Stained Glass kit), title banner riding its top edge.
	local root = make("Frame", gui, {
		Name = "Board",
		Size = UDim2.fromScale(1, 0.9),
		Position = UDim2.fromScale(0, 0.1),
		BackgroundTransparency = 1,
	})
	image(root, "Pane", "panel/pane_dark", UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), {
		ScaleType = Enum.ScaleType.Stretch,
		ImageTransparency = 0.04,
		ZIndex = 1,
	})
	local view = { Gui = gui, Sides = {} }
	local banner =
		image(gui, "TitleBanner", "panel/title_amethyst", UDim2.fromScale(0.62, 0.24), UDim2.fromScale(0.5, 0.11), {
			ZIndex = 5,
		})
	view.Title = text(banner, "Title", "", UDim2.fromScale(0.78, 0.52), UDim2.fromScale(0.5, 0.48), Theme.Fonts.Heading)
	view.Title.ZIndex = 6
	for side = 1, 2 do
		view.Sides[side] = portrait(root, side)
	end
	view.VS = text(root, "VS", "VS", UDim2.fromScale(0.2, 0.22), UDim2.fromScale(0.5, 0.4), Theme.Fonts.Heading, nil, 3)
	make("UIGradient", view.VS, { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), GOLD) })
	view.Count = text(
		root,
		"Count",
		"",
		UDim2.fromScale(0.22, 0.08),
		UDim2.fromScale(0.5, 0.57),
		Theme.Fonts.Caption,
		Theme.Colors.TextMuted,
		1.5
	)
	-- Prize chip under the count: coin + amount.
	local reward = make("Frame", root, {
		Name = "Reward",
		Size = UDim2.fromScale(0.22, 0.1),
		Position = UDim2.fromScale(0.5, 0.69),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	})
	image(reward, "Coin", "icon/coin", UDim2.fromScale(0.34, 1), UDim2.fromScale(0.17, 0.5), { ZIndex = 4 })
	view.Win = text(
		reward,
		"Win",
		"WIN " .. Balance.Match.Rewards.MatchWinCoins,
		UDim2.fromScale(0.66, 1),
		UDim2.fromScale(0.67, 0.5),
		Theme.Fonts.Heading,
		GOLD,
		2
	)
	-- Status on a milk plaque along the bottom edge.
	local plaque =
		image(root, "StatusPlaque", "hud/label_plaque", UDim2.fromScale(0.8, 0.15), UDim2.fromScale(0.5, 0.92), {
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = 4,
		})
	view.Status = text(
		plaque,
		"Status",
		"",
		UDim2.fromScale(0.86, 0.62),
		UDim2.fromScale(0.5, 0.5),
		Theme.Fonts.Body,
		Theme.Colors.TextDark,
		false
	)
	view.Status.ZIndex = 5
	return view
end

local function set(object, key, value)
	if object[key] ~= value then
		object[key] = value
	end
end

-- state = { Title, Count, Status, Sides = { [1|2] = { UserId: number?, Name: string } | nil } }
function Board.update(view, state)
	if not view or not view.Gui.Parent then
		return
	end
	set(view.Title, "Text", state.Title)
	set(view.Count, "Text", state.Count)
	set(view.Status, "Text", state.Status)
	for side = 1, 2 do
		local ui, who = view.Sides[side], state.Sides[side]
		local id = who and who.UserId or 0
		set(
			ui.Image,
			"Image",
			if id > 0 then string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", id) else ""
		)
		-- Bots and empty slots show a glyph instead of a headshot.
		set(ui.Empty, "Text", if who then "BOT" else "?")
		set(ui.Empty, "Visible", id <= 0)
		set(ui.Name, "Text", who and who.Name or "OPEN")
	end
end

return Board
