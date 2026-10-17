-- Builds Workspace.LobbyPolish: stepping-stone lanes from spawn to every lobby stop, a stained-glass
-- signpost, lantern posts and the Kiln court (rim, mosaic, windows, title and plaques around the creator's
-- kilns; the kiln models themselves are never touched). Static, matte Stained Glass / low-poly pieces.
-- Refuses to run if LobbyPolish already exists so manual moves are never wiped; delete it first (or set
-- _G.LobbyPolishRebuild = true) to rebuild. Reads the current positions of the stage, stands and kilns.
assert(not game:GetService("RunService"):IsRunning(), "Build the lobby polish in Edit mode")
if workspace:FindFirstChild("LobbyPolish") and not _G.LobbyPolishRebuild then
	return "LobbyPolish already exists: nothing changed (set _G.LobbyPolishRebuild = true to replace it)"
end
_G.LobbyPolishRebuild = nil
if workspace:FindFirstChild("LobbyPolish") then
	workspace.LobbyPolish:Destroy()
end

local LEAD = Color3.fromHex("1F1830")
local C = {
	ruby = { "E23A55", "FF8EA0", "9E1D38" },
	amber = { "F5A524", "FFD98A", "B26E0B" },
	emerald = { "22B573", "86EDB8", "11703F" },
	aqua = { "1FC2D3", "9BF3F8", "0F7C88" },
	sapphire = { "2E6BE6", "93BCFF", "1A409C" },
	amethyst = { "8B4FE0", "CDAAFF", "57299F" },
	milk = { "EEE7D9", "FFFFFF", "B9AE99" },
}
local function hex(name, shade)
	return Color3.fromHex(C[name][shade or 1])
end
local DENK = Font.new("rbxasset://fonts/families/DenkOne.json")
local NUNITO = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy)
local STONES = { "D9D1C2", "CFC6B4", "C4BAA6" }
local random = Random.new(2026)

local function part(parent, name, size, cf, color, props)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props or {} do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end
local function glass(parent, name, size, cf, color)
	return part(parent, name, size, cf, color, {
		Material = Enum.Material.Glass,
		Transparency = 0.32,
		Reflectance = 0.05,
		CastShadow = false,
	})
end
local function model(parent, name)
	local m = Instance.new("Model")
	m.Name, m.Parent = name, parent
	return m
end
local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, range, brightness, false
	l.Parent = parent
	return l
end
-- Text on one face of a part; lines stack top to bottom.
local function label(p, face, lines)
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Face = "Label" .. face.Name, face
	gui.SizingMode, gui.PixelsPerStud = Enum.SurfaceGuiSizingMode.PixelsPerStud, 50
	gui.LightInfluence, gui.MaxDistance = 0, 220
	gui.Parent = p
	local y = 0
	for _, line in lines do
		local t = Instance.new("TextLabel")
		t.Name, t.Text = line.Name or "Text", line.Text
		t.Size, t.Position = UDim2.fromScale(0.92, line.Height or 1), UDim2.fromScale(0.04, y)
		t.BackgroundTransparency, t.TextScaled = 1, true
		t.FontFace = line.Font or DENK
		t.TextColor3 = line.Color or Color3.new(1, 1, 1)
		if line.Stroke ~= false then
			local stroke = Instance.new("UIStroke")
			stroke.Color, stroke.Thickness, stroke.LineJoinMode =
				LEAD, line.StrokeThickness or 5, Enum.LineJoinMode.Round
			stroke.Parent = t
		end
		t.Parent = gui
		y += line.Height or 1
	end
	return gui
end
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local root = Instance.new("Model")
root.Name = "LobbyPolish"
root:SetAttribute("BuiltBy", "tools/studio/build_lobby_polish.luau")

-- ── Where things are now ─────────────────────────────────────────────────────────────────────────
local spawnPad = workspace.Lobby:FindFirstChild("SpawnLocation")
local spawnAt = flat(spawnPad and spawnPad.Position or Vector3.new(0, 0, 6))
local showcase = workspace:FindFirstChild("FeaturedShowcase")
local kilnBase
for _, p in workspace:GetChildren() do
	if p:IsA("BasePart") and p.Position.X < -10 and math.abs(p.Size.X - 21.5) < 0.6 then
		kilnBase = p
	end
end
assert(kilnBase, "Kiln base part not found")
local function facing(cf)
	local look = flat(cf.LookVector)
	return if look:Dot(spawnAt - flat(cf.Position)) < 0 then -look else look
end
local kilnCenter = flat(kilnBase.Position)
local kilnLook = facing(kilnBase.CFrame).Unit
local K0 = CFrame.lookAt(kilnCenter, kilnCenter + kilnLook)
local stops = {
	{ Name = "Kilns", Colour = "aqua", Text = "KILNS", To = kilnCenter + kilnLook * 6.2 },
	{ Name = "Arenas", Colour = "emerald", Text = "ARENAS", To = Vector3.new(0, 0, -30) },
}
if showcase then
	-- Model pivots keep whatever the creator dragged, so read fronts from built parts instead.
	local stage = showcase:FindFirstChild("Stage")
	local step = stage and stage:FindFirstChild("Step")
	if step then
		table.insert(stops, {
			Name = "Featured",
			Colour = "amber",
			Text = "FEATURED",
			To = flat(step.Position) + facing(step.CFrame) * 1.6,
		})
	end
	local bay = showcase:FindFirstChild("CapsuleBay")
	for _, stand in bay and bay:GetChildren() or {} do
		local category = stand:GetAttribute("Category")
		local slot = stand:FindFirstChild("MachineSlot")
		if category and slot then
			table.insert(stops, {
				Name = category,
				Colour = if category == "Finishers" then "amethyst" else "ruby",
				Text = if category == "Finishers" then "FINISHERS" else "FLYERS",
				To = flat(slot.Position) + flat(slot.CFrame.LookVector).Unit * 4.2,
			})
		end
	end
end

-- ── Stepping-stone lanes: paired slabs every 2.9 studs, like the existing LobbyLane ─────────────
local lanes = model(root, "Lanes")
local SPAWN_RADIUS = 5.8
for _, stop in stops do
	if stop.Name == "Arenas" then
		continue -- the creator's LobbyLane already runs north
	end
	local lane = model(lanes, stop.Name .. "Lane")
	local dir = (stop.To - spawnAt).Unit
	local from = spawnAt + dir * SPAWN_RADIUS
	local length = (stop.To - from).Magnitude
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local steps = math.max(1, math.floor(length / 2.9))
	for i = 0, steps do
		local at = from + dir * (i * length / steps)
		for _, s in { -1, 1 } do
			local w, d = random:NextNumber(2.4, 2.9), random:NextNumber(2.2, 2.6)
			local jitter = math.rad(random:NextNumber(-9, 9))
			local cf = CFrame.lookAt(at + side * s * 1.42, at + side * s * 1.42 + dir) * CFrame.Angles(0, jitter, 0)
			part(
				lane,
				"Stone",
				Vector3.new(w, 0.14, d),
				cf + Vector3.yAxis * 0.085,
				Color3.fromHex(STONES[random:NextInteger(1, 3)]),
				{
					CastShadow = false,
				}
			)
		end
	end
	stop.Lane = { From = from, Dir = dir, Side = side }
end

-- ── Lantern posts at each stop ──────────────────────────────────────────────────────────────────
local lanterns = model(root, "Lanterns")
local function lantern(name, at, colour)
	local m = model(lanterns, name)
	local base = CFrame.new(at)
	part(m, "Foot", Vector3.new(1.0, 0.3, 1.0), base * CFrame.new(0, 0.15, 0), LEAD)
	part(m, "Post", Vector3.new(0.35, 3.6, 0.35), base * CFrame.new(0, 2.0, 0), LEAD)
	part(m, "Floor", Vector3.new(1.05, 0.15, 1.05), base * CFrame.new(0, 3.85, 0), LEAD)
	glass(m, "Glass", Vector3.new(0.85, 1.0, 0.85), base * CFrame.new(0, 4.43, 0), hex(colour, 2))
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part(m, "Frame", Vector3.new(0.12, 1.0, 0.12), base * CFrame.new(x * 0.46, 4.43, z * 0.46), LEAD)
		end
	end
	local core = part(m, "Core", Vector3.new(0.45, 0.45, 0.45), base * CFrame.new(0, 4.43, 0), hex("amber", 2), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon,
		CastShadow = false,
	})
	part(m, "Cap", Vector3.new(1.15, 0.2, 1.15), base * CFrame.new(0, 5.03, 0), LEAD)
	part(
		m,
		"Finial",
		Vector3.new(0.4, 0.4, 0.4),
		base * CFrame.new(0, 5.3, 0),
		hex(colour),
		{ Shape = Enum.PartType.Ball }
	)
	light(core, hex("amber", 2), 10, 0.8)
end
for _, stop in stops do
	if stop.Lane then
		lantern(stop.Name .. "Lantern", stop.To - stop.Lane.Dir * 7 + stop.Lane.Side * 4.2, stop.Colour)
	end
end

-- ── Signpost beside the spawn pad, one jewel arrow per stop ─────────────────────────────────────
local post = model(root, "Signpost")
local postAt = spawnAt + Vector3.new(-4.6, 0, -7.8)
part(post, "Foot", Vector3.new(1.8, 0.4, 1.8), CFrame.new(postAt + Vector3.yAxis * 0.2), LEAD, { CanCollide = true })
part(post, "Post", Vector3.new(0.55, 9.4, 0.55), CFrame.new(postAt + Vector3.yAxis * 4.9), LEAD, { CanCollide = true })
part(post, "Cap", Vector3.new(0.9, 0.3, 0.9), CFrame.new(postAt + Vector3.yAxis * 9.7), LEAD)
local finial =
	part(post, "Finial", Vector3.new(0.8, 0.8, 0.8), CFrame.new(postAt + Vector3.yAxis * 10.2), hex("amber"), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon,
	})
light(finial, hex("amber", 2), 12, 0.9)
table.sort(stops, function(a, b)
	return (a.To - postAt).Magnitude > (b.To - postAt).Magnitude
end)
for i, stop in stops do
	local dir = flat(stop.To - postAt).Unit
	local y = 9.0 - (i - 1) * 0.95
	local length = 4.2
	local board = CFrame.lookAt(postAt, postAt + dir) * CFrame.new(0, y, -(0.3 + length / 2))
	part(post, "Arrow" .. stop.Name, Vector3.new(0.2, 0.72, length), board, hex(stop.Colour, 3))
	local plank = part(
		post,
		"ArrowFace" .. stop.Name,
		Vector3.new(0.24, 0.52, length - 0.25),
		board * CFrame.new(0, 0, 0.1),
		hex(stop.Colour)
	)
	part(
		post,
		"ArrowTip" .. stop.Name,
		Vector3.new(0.2, 0.62, 0.62),
		board * CFrame.new(0, 0, -length / 2) * CFrame.Angles(math.rad(45), 0, 0),
		hex(stop.Colour, 3)
	)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		label(plank, face, { { Text = stop.Text, StrokeThickness = 4 } })
	end
end

-- ── Kiln court: rim, mosaic, two stained-glass windows, title and plaques ───────────────────────
local court = model(root, "KilnCourt")
local function K(x, y, z)
	return K0 * CFrame.new(x, y, z)
end
local L, D = kilnBase.Size.X, kilnBase.Size.Z
local top = kilnBase.Position.Y + kilnBase.Size.Y / 2
part(court, "RimFront", Vector3.new(L + 1, 0.35, 0.5), K(0, 0.175, -(D / 2 + 0.25)), LEAD, { CanCollide = true })
part(court, "RimBack", Vector3.new(L + 1, 0.35, 0.5), K(0, 0.175, D / 2 + 0.25), LEAD)
part(court, "RimLeft", Vector3.new(0.5, 0.35, D), K(L / 2 + 0.25, 0.175, 0), LEAD)
part(court, "RimRight", Vector3.new(0.5, 0.35, D), K(-(L / 2 + 0.25), 0.175, 0), LEAD)
part(court, "Lip", Vector3.new(L + 1.05, 0.1, 0.3), K(0, 0.39, -(D / 2 + 0.25)), hex("amber"))
part(court, "Grout", Vector3.new(L, 0.04, D), K(0, top + 0.02, 0), LEAD, { CastShadow = false })
local cols, rows = 6, 3
local tw, td = L / cols, D / rows
local warm = { { "amber", 3 }, { "amber", 1 }, { "milk", 3 }, { "ruby", 3 } }
local cool = { { "aqua", 3 }, { "sapphire", 3 }, { "aqua", 1 }, { "amethyst", 3 } }
-- Which end each kiln sits on (local +X is the west end).
local marble = workspace.Kilns:FindFirstChild("MarbleKiln")
local marbleSide = if marble and K0:PointToObjectSpace(marble:GetPivot().Position).X > 0 then 1 else -1
for c = 1, cols do
	for r = 1, rows do
		local x = -L / 2 + (c - 0.5) * tw
		local palette = if (x > 0) == (marbleSide > 0) then cool else warm
		local swatch = palette[(c * 5 + r * 3) % #palette + 1]
		part(
			court,
			"Tile",
			Vector3.new(tw - 0.15, 0.06, td - 0.15),
			K(x, top + 0.05, -D / 2 + (r - 0.5) * td),
			hex(swatch[1], swatch[2]),
			{
				CastShadow = false,
			}
		)
	end
end
local function window(name, x, palette, glow)
	local w = model(court, name)
	local width, height, gable, bar, t = 8.2, 10.4, 2.2, 0.45, 0.6
	local frame = K(x, top, D / 2 + 0.35)
	part(w, "PostL", Vector3.new(bar, height, t), frame * CFrame.new(-width / 2 + bar / 2, height / 2, 0), LEAD)
	part(w, "PostR", Vector3.new(bar, height, t), frame * CFrame.new(width / 2 - bar / 2, height / 2, 0), LEAD)
	part(w, "Sill", Vector3.new(width + 0.4, bar + 0.1, t + 0.2), frame * CFrame.new(0, bar / 2, 0), LEAD)
	part(w, "Head", Vector3.new(width, bar, t), frame * CFrame.new(0, height - bar / 2, 0), LEAD)
	local iw, ih = width - bar * 2, height - bar * 2
	local pc, pr = 3, 3
	for i = 1, pc - 1 do
		part(
			w,
			"Mullion",
			Vector3.new(0.18, ih, t * 0.8),
			frame * CFrame.new(-iw / 2 + i * iw / pc, bar + ih / 2, 0),
			LEAD
		)
	end
	for i = 1, pr - 1 do
		part(w, "Transom", Vector3.new(iw, 0.18, t * 0.8), frame * CFrame.new(0, bar + i * ih / pr, 0), LEAD)
	end
	for i = 1, pc do
		for j = 1, pr do
			local swatch = palette[(i * 7 + j * 3) % #palette + 1]
			glass(
				w,
				"Pane",
				Vector3.new(iw / pc - 0.18, ih / pr - 0.18, 0.2),
				frame * CFrame.new(-iw / 2 + (i - 0.5) * iw / pc, bar + (j - 0.5) * ih / pr, 0),
				hex(swatch[1], swatch[2])
			)
		end
	end
	local half = width / 2
	local slope = math.atan2(gable, half)
	for s = -1, 1, 2 do
		part(
			w,
			"Gable",
			Vector3.new(math.sqrt(half * half + gable * gable) + 0.3, bar, t),
			frame * CFrame.new(s * half / 2, height + gable / 2, 0) * CFrame.Angles(0, 0, -s * slope),
			LEAD
		)
	end
	local gem = glass(
		w,
		"Diamond",
		Vector3.new(1.3, 1.3, 0.2),
		frame * CFrame.new(0, height + gable * 0.42, 0) * CFrame.Angles(0, 0, math.rad(45)),
		hex(glow)
	)
	light(gem, hex(glow, 2), 14, 1)
end
window(
	"WindowWarm",
	-marbleSide * 5.1,
	{ { "amber", 1 }, { "amber", 2 }, { "ruby", 3 }, { "amber", 3 }, { "milk", 1 } },
	"amber"
)
window(
	"WindowCool",
	marbleSide * 5.1,
	{ { "aqua", 1 }, { "sapphire", 1 }, { "aqua", 3 }, { "sapphire", 3 }, { "amethyst", 1 } },
	"aqua"
)
part(court, "Pillar", Vector3.new(1.0, 13.8, 0.8), K(0, top + 6.9, D / 2 + 0.35), LEAD)
local title = part(court, "TitleSign", Vector3.new(11, 2.4, 0.45), K(0, 15.0, D / 2 + 0.1), hex("aqua", 3))
part(court, "TitleFrame", Vector3.new(11.6, 3.0, 0.35), K(0, 15.0, D / 2 + 0.35), LEAD)
label(title, Enum.NormalId.Front, {
	{ Name = "Title", Text = "THE KILNS", Height = 0.62, StrokeThickness = 7 },
	{ Name = "Subtitle", Text = "OPEN GLASSIES", Height = 0.34, Color = hex("aqua", 2), StrokeThickness = 4 },
})
for _, info in { { -marbleSide, "COINS", "Kiln", "amber" }, { marbleSide, "MARBLES", "Marble Kiln", "aqua" } } do
	local x = info[1] * 5.1
	local at = K(x, 0, -(D / 2 + 1.5))
	part(court, "PlaqueStand" .. info[2], Vector3.new(0.5, 0.9, 0.5), at * CFrame.new(0, 0.45, 0), LEAD)
	local plaque = part(
		court,
		"Plaque" .. info[2],
		Vector3.new(4.2, 1.3, 0.25),
		at * CFrame.new(0, 1.05, 0) * CFrame.Angles(math.rad(35), 0, 0),
		hex("milk")
	)
	part(
		court,
		"PlaqueFrame" .. info[2],
		Vector3.new(4.5, 1.6, 0.15),
		at * CFrame.new(0, 1.05, 0) * CFrame.Angles(math.rad(35), 0, 0) * CFrame.new(0, 0, 0.18),
		LEAD
	)
	label(plaque, Enum.NormalId.Front, {
		{ Name = "Kind", Text = info[2], Height = 0.4, Color = hex(info[4], 3), Stroke = false, Font = NUNITO },
		{ Name = "Name", Text = info[3], Height = 0.56, Color = LEAD, Stroke = false, Font = DENK },
	})
end

root.Parent = workspace
local count = 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
return string.format("Built LobbyPolish: %d parts, %d stops", count, #stops)
