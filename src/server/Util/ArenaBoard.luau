-- Stained-glass queue board that floats above each Clash Stand: two avatar portraits with VS,
-- "1 / 2 PLAYERS", "WIN 100" and a status line. Built and updated by the server so every
-- player sees the same thing; properties are only written when they change.
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

local function corner(parent, scale)
	make("UICorner", parent, { CornerRadius = UDim.new(scale, 0) })
end

local function stroke(parent, color, thickness)
	return make("UIStroke", parent, {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function text(parent, name, value, size, position, font, color)
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
	})
	make("UIStroke", label, { Color = LEAD, Thickness = 2.5 })
	return label
end

-- One coloured pane of glass with a soft diagonal sheen, framed by dark leading.
local function pane(parent, name, color, size, position)
	local frame = make("Frame", parent, {
		Name = name,
		Size = size,
		Position = position,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
	})
	corner(frame, 0.06)
	stroke(frame, LEAD, 4)
	make("UIGradient", frame, {
		Rotation = 35,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(1, 1, 1), 0.25)),
			ColorSequenceKeypoint.new(0.45, color),
			ColorSequenceKeypoint.new(1, color:Lerp(LEAD, 0.45)),
		}),
	})
	return frame
end

local function portrait(parent, side)
	local color = Theme.Sides[side]
	local holder = make("Frame", parent, {
		Name = "Side" .. side,
		Size = UDim2.fromScale(0.3, 0.62),
		Position = UDim2.fromScale(if side == 1 then 0.185 else 0.815, 0.4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	})
	local frame = make("Frame", holder, {
		Name = "Frame",
		Size = UDim2.fromScale(0.8, 0.8),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = color:Lerp(LEAD, 0.55),
		BorderSizePixel = 0,
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
	})
	corner(frame, 0.22)
	stroke(frame, color, 4)
	make("UIGradient", frame, {
		Rotation = 90,
		Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.2), color:Lerp(LEAD, 0.6)),
	})
	local image = make("ImageLabel", frame, {
		Name = "Avatar",
		Size = UDim2.fromScale(0.92, 0.92),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = "",
	})
	corner(image, 0.2)
	local empty = text(frame, "Empty", "?", UDim2.fromScale(0.6, 0.6), UDim2.fromScale(0.5, 0.5), Theme.Fonts.Heading)
	local name = text(
		holder,
		"PlayerName",
		"",
		UDim2.fromScale(1.25, 0.2),
		UDim2.fromScale(0.5, 0.92),
		Theme.Fonts.Body,
		Theme.Colors.Text
	)
	return { Image = image, Empty = empty, Name = name }
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
	-- Sized in studs so it reads like a sign hanging over the stand and shrinks with distance.
	-- Named ArenaStatus: FightView hides billboards with this name while the fight camera runs.
	local gui = make("BillboardGui", anchor, {
		Name = "ArenaStatus",
		Size = UDim2.fromScale(Feel.ArenaBoardWidth, Feel.ArenaBoardWidth * 0.62),
		MaxDistance = Feel.SpectatorDistance,
		LightInfluence = 0,
		AlwaysOnTop = false,
	})
	gui:SetAttribute("ArenaActive", true)
	local root = make("Frame", gui, {
		Name = "Board",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = LEAD,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
	})
	corner(root, 0.07)
	local edge = stroke(root, Color3.new(1, 1, 1), 5)
	make("UIGradient", edge, { Rotation = 20, Color = ColorSequence.new(Theme.Colors.EdgeA, Theme.Colors.EdgeB) })

	-- Window of panes: blue side A, violet centre, orange side B, amber footer.
	local glass = make("Frame", root, {
		Name = "Glass",
		Size = UDim2.fromScale(0.94, 0.9),
		Position = UDim2.fromScale(0.03, 0.05),
		BackgroundTransparency = 1,
	})
	pane(glass, "PaneA", Theme.Sides[1], UDim2.fromScale(0.36, 0.68), UDim2.fromScale(0, 0))
	pane(glass, "PaneVS", Theme.Colors.EdgeB, UDim2.fromScale(0.26, 0.68), UDim2.fromScale(0.37, 0))
	pane(glass, "PaneB", Theme.Sides[2], UDim2.fromScale(0.36, 0.68), UDim2.fromScale(0.64, 0))
	pane(glass, "PaneFooter", Theme.Colors.PanelTop, UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0.7))

	local view = { Gui = gui, Sides = {} }
	view.Title = text(
		glass,
		"Title",
		"",
		UDim2.fromScale(0.24, 0.1),
		UDim2.fromScale(0.5, 0.08),
		Theme.Fonts.Caption,
		Theme.Colors.TextMuted
	)
	view.VS = text(glass, "VS", "VS", UDim2.fromScale(0.24, 0.3), UDim2.fromScale(0.5, 0.36), Theme.Fonts.Heading)
	make("UIGradient", view.VS, { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), GOLD) })
	for side = 1, 2 do
		view.Sides[side] = portrait(glass, side)
	end
	view.Count = text(
		glass,
		"Count",
		"",
		UDim2.fromScale(0.5, 0.15),
		UDim2.fromScale(0.29, 0.79),
		Theme.Fonts.Heading,
		Theme.Colors.Text
	)
	local reward = make("Frame", glass, {
		Name = "Reward",
		Size = UDim2.fromScale(0.38, 0.15),
		Position = UDim2.fromScale(0.77, 0.79),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	})
	view.Win = text(
		reward,
		"Win",
		"WIN " .. Balance.Match.Rewards.MatchWinCoins,
		UDim2.fromScale(0.74, 1),
		UDim2.fromScale(0.37, 0.5),
		Theme.Fonts.Heading,
		GOLD
	)
	make("ImageLabel", reward, {
		Name = "Coin",
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Position = UDim2.fromScale(0.8, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Image = UIAssets["icon/coin"] or "",
		ScaleType = Enum.ScaleType.Fit,
	})
	view.Status = text(
		glass,
		"Status",
		"",
		UDim2.fromScale(0.9, 0.09),
		UDim2.fromScale(0.5, 0.93),
		Theme.Fonts.Caption,
		Theme.Colors.TextMuted
	)
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
