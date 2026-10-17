-- Builds Workspace.FeaturedShowcase: the Featured Collection stage on the creator's marker (mirror of the
-- Marble Kiln), the Flyers display on the east side and the capsule opening stands beside the arena path.
-- Static, matte Stained Glass pieces plus named anchors; ShowcaseController adds every moving/cosmetic
-- part on the client. Re-running replaces the whole model. Run in Edit mode through the Studio MCP.
assert(not game:GetService("RunService"):IsRunning(), "Build the showcase in Edit mode")

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
local function anchor(parent, name, cf)
	return part(parent, name, Vector3.one * 0.4, cf, LEAD, { Transparency = 1, CastShadow = false })
end
local function model(parent, name)
	local m = Instance.new("Model")
	m.Name, m.Parent = name, parent
	return m
end
-- One SurfaceGui text panel on the part's Front face.
local function label(p, text, opts)
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Face = "Label", Enum.NormalId.Front
	gui.SizingMode, gui.PixelsPerStud = Enum.SurfaceGuiSizingMode.PixelsPerStud, 50
	gui.LightInfluence, gui.MaxDistance = 0, 220
	gui.Parent = p
	local lines = opts.Lines or { { Name = "Text", Text = text, Height = 1, Font = opts.Font or DENK } }
	local y = 0
	for _, line in lines do
		local t = Instance.new("TextLabel")
		t.Name, t.Text = line.Name, line.Text
		t.Size, t.Position = UDim2.fromScale(0.92, line.Height), UDim2.fromScale(0.04, y)
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
		y += line.Height
	end
	return gui
end
local function emitter(parent, name, color, props)
	local e = Instance.new("ParticleEmitter")
	e.Name, e.Enabled = name, false
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission, e.LightInfluence = 1, 0
	e.Rate, e.Lifetime, e.Speed = 4, NumberRange.new(0.8, 1.4), NumberRange.new(0.4, 1)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new(0.1, 1)
	e.SpreadAngle = Vector2.new(180, 180)
	for k, v in props or {} do
		(e :: any)[k] = v
	end
	e:SetAttribute("ShowcaseEmitter", true)
	e.Parent = parent
	return e
end
local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows, l.Enabled = color, range, brightness, false, false
	l:SetAttribute("ShowcaseEmitter", true)
	l.Parent = parent
	return l
end

-- Stained-glass window: lead frame, mullions, jewel panes and a gable with a diamond pane on top.
local function window(parent, name, frame, width, height, cols, rows, palette, gable)
	local w = model(parent, name)
	local t, bar = 0.6, 0.45
	part(w, "PostL", Vector3.new(bar, height, t), frame * CFrame.new(-width / 2 + bar / 2, height / 2, 0), LEAD)
	part(w, "PostR", Vector3.new(bar, height, t), frame * CFrame.new(width / 2 - bar / 2, height / 2, 0), LEAD)
	part(w, "Sill", Vector3.new(width + 0.4, bar + 0.1, t + 0.2), frame * CFrame.new(0, bar / 2, 0), LEAD)
	part(w, "Head", Vector3.new(width, bar, t), frame * CFrame.new(0, height - bar / 2, 0), LEAD)
	local innerW, innerH = width - bar * 2, height - bar * 2
	local paneW, paneH = innerW / cols, innerH / rows
	for c = 1, cols - 1 do
		part(
			w,
			"Mullion",
			Vector3.new(0.18, innerH, t * 0.8),
			frame * CFrame.new(-innerW / 2 + c * paneW, bar + innerH / 2, 0),
			LEAD
		)
	end
	for r = 1, rows - 1 do
		part(w, "Transom", Vector3.new(innerW, 0.18, t * 0.8), frame * CFrame.new(0, bar + r * paneH, 0), LEAD)
	end
	for c = 1, cols do
		for r = 1, rows do
			local swatch = palette[(c * 7 + r * 3) % #palette + 1]
			glass(
				w,
				"Pane",
				Vector3.new(paneW - 0.18, paneH - 0.18, 0.2),
				frame * CFrame.new(-innerW / 2 + (c - 0.5) * paneW, bar + (r - 0.5) * paneH, 0),
				hex(swatch[1], swatch[2])
			)
		end
	end
	-- Gable: two leaning lead beams and a diamond pane.
	local half = width / 2
	local slope = math.atan2(gable, half)
	local beam = math.sqrt(half * half + gable * gable) + 0.3
	for side = -1, 1, 2 do
		part(
			w,
			"Gable",
			Vector3.new(beam, bar, t),
			frame * CFrame.new(side * half / 2, height + gable / 2, 0) * CFrame.Angles(0, 0, -side * slope),
			LEAD
		)
	end
	local d = gable * 0.62
	glass(
		w,
		"Diamond",
		Vector3.new(d, d, 0.2),
		frame * CFrame.new(0, height + gable * 0.42, 0) * CFrame.Angles(0, 0, math.rad(45)),
		hex("amber")
	)
	part(
		w,
		"DiamondLead",
		Vector3.new(d + 0.3, d + 0.3, 0.12),
		frame * CFrame.new(0, height + gable * 0.42, 0.12) * CFrame.Angles(0, 0, math.rad(45)),
		LEAD
	)
	return w
end

-- Never wipe the creator's manual moves: refuse unless a rebuild is asked for explicitly.
if workspace:FindFirstChild("FeaturedShowcase") then
	if not _G.FeaturedShowcaseRebuild then
		return "FeaturedShowcase already exists: nothing changed (set _G.FeaturedShowcaseRebuild = true to replace it)"
	end
	workspace.FeaturedShowcase:Destroy()
end
_G.FeaturedShowcaseRebuild = nil
local root = Instance.new("Model")
root.Name = "FeaturedShowcase"
root.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
root:SetAttribute("BuiltBy", "tools/studio/build_featured_showcase.luau")

-- ── Stage frame from the creator's marker (21.5 x 9.5 grey part mirroring the Kiln base) ──────────
local marker
for _, p in workspace:GetChildren() do
	if
		p:IsA("BasePart")
		and p.Position.X > 10
		and math.abs(p.Size.X - 21.5) < 0.6
		and math.abs(p.Size.Z - 9.5) < 0.6
	then
		marker = p
	end
end
local spawnAt = Vector3.new(0, 0, 6)
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end
local center = if marker then Vector3.new(marker.Position.X, 0, marker.Position.Z) else Vector3.new(24.8, 0, -14.8)
local look = if marker then marker.CFrame.LookVector else Vector3.new(0.7071, 0, -0.7071)
if look:Dot(spawnAt - center) < 0 then
	look = -look
end
-- Stage local axes: -Z faces spawn (front), +X is the bridge end (the viewer's left).
local S0 = CFrame.lookAt(center, center + look)
local function S(x, y, z)
	return S0 * CFrame.new(x, y, z)
end

local stage = model(root, "Stage")
local anchors = model(stage, "Anchors") -- inside Stage so the demo follows the stage
local L, D, TOP = 21.5, 9.5, 1.2

-- Dais with a mosaic top, amber lip and a front step.
part(stage, "Dais", Vector3.new(L + 1, 1, D + 1), S(0, 0.5, 0), LEAD, { CanCollide = true, CanQuery = true })
local tileCols, tileRows = 6, 3
local tw, td = L / tileCols, D / tileRows
local tiles =
	{ { "amethyst", 3 }, { "amethyst", 1 }, { "sapphire", 3 }, { "amethyst", 3 }, { "emerald", 3 }, { "amethyst", 1 } }
for c = 1, tileCols do
	for r = 1, tileRows do
		local swatch = tiles[(c * 5 + r * 2) % #tiles + 1]
		part(
			stage,
			"Tile",
			Vector3.new(tw - 0.15, 0.2, td - 0.15),
			S(-L / 2 + (c - 0.5) * tw, TOP - 0.1, -D / 2 + (r - 0.5) * td),
			hex(swatch[1], swatch[2]),
			{
				CanCollide = true,
				CanQuery = true,
			}
		)
	end
end
part(stage, "Lip", Vector3.new(L + 1.1, 0.3, 0.35), S(0, TOP - 0.05, -(D + 1) / 2), hex("amber"))
part(
	stage,
	"Step",
	Vector3.new(L + 1, 0.6, 1.6),
	S(0, 0.3, -(D + 1) / 2 - 0.8),
	LEAD,
	{ CanCollide = true, CanQuery = true }
)
part(stage, "StepLip", Vector3.new(L + 1.1, 0.2, 0.3), S(0, 0.55, -(D + 1) / 2 - 1.6), hex("amber", 3))

-- Backdrop: three stained-glass windows (night sky, ghost green, lantern amber).
local night = { { "amethyst", 1 }, { "sapphire", 1 }, { "amethyst", 3 }, { "sapphire", 3 }, { "amethyst", 2 } }
local ghost = { { "emerald", 1 }, { "aqua", 3 }, { "emerald", 3 }, { "amethyst", 1 }, { "emerald", 2 } }
window(stage, "WindowCenter", S(0, TOP, 4.2), 9, 9, 3, 3, night, 2.6)
window(stage, "WindowLeft", S(8.3, TOP, 4.2), 5, 6.5, 2, 3, ghost, 1.7)
window(stage, "WindowRight", S(-8.3, TOP, 4.2), 5, 6.5, 2, 3, ghost, 1.7)
local moon = part(
	stage,
	"MoonPane",
	Vector3.new(0.25, 2.4, 2.4),
	S(0, TOP + 6.6, 3.85) * CFrame.Angles(0, math.rad(90), 0),
	hex("milk", 1),
	{
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		CastShadow = false,
	}
)
light(moon, hex("amethyst", 2), 18, 1.3)

-- Title sign over the centre window, countdown pill beneath it.
local title = part(stage, "TitleSign", Vector3.new(12, 2.4, 0.45), S(0, 11.6, 3.7), hex("amethyst", 3))
part(stage, "TitleFrame", Vector3.new(12.6, 3.0, 0.35), S(0, 11.6, 3.95), LEAD)
label(title, "HOLLOWLIGHT", {
	Lines = {
		{ Name = "Title", Text = "HOLLOWLIGHT", Height = 0.62, StrokeThickness = 7 },
		{
			Name = "Subtitle",
			Text = "HALLOWEEN COLLECTION",
			Height = 0.34,
			Color = hex("amber", 2),
			StrokeThickness = 4,
		},
	},
})
local pill = part(stage, "CountdownSign", Vector3.new(5.4, 1.05, 0.35), S(0, 9.75, 3.6), hex("amber"))
part(stage, "CountdownFrame", Vector3.new(5.9, 1.5, 0.3), S(0, 9.75, 3.8), LEAD)
label(pill, "LIMITED TIME", {
	Lines = {
		{
			Name = "Countdown",
			Text = "LIMITED TIME",
			Height = 1,
			Color = Color3.fromHex("1F1830"),
			Stroke = false,
			Font = NUNITO,
		},
	},
})

-- Exhibit 1 (bridge end): the finisher demo — hook post, practice target.
local hookPost = model(stage, "DemoHookPost")
part(hookPost, "Post", Vector3.new(0.6, 11, 0.6), S(10.3, TOP + 5.5, 2.4), LEAD)
part(hookPost, "Arm", Vector3.new(3.1, 0.45, 0.45), S(8.95, TOP + 10.8, 2.4), LEAD)
part(hookPost, "Foot", Vector3.new(1.6, 0.4, 1.6), S(10.3, TOP + 0.2, 2.4), LEAD)
part(
	hookPost,
	"Hook",
	Vector3.new(0.3, 0.7, 0.7),
	S(7.6, TOP + 10.45, 2.4) * CFrame.Angles(0, math.rad(90), 0),
	hex("amber"),
	{
		Shape = Enum.PartType.Cylinder,
	}
)
part(
	hookPost,
	"Finial",
	Vector3.new(0.9, 0.9, 0.9),
	S(10.3, TOP + 11.3, 2.4),
	hex("amber"),
	{ Shape = Enum.PartType.Ball }
)
anchor(anchors, "DemoHook", S(7.6, TOP + 10.1, 2.4))
anchor(anchors, "DemoArc", S(11.5, TOP + 12, -6))

local target = model(stage, "DemoTarget")
local tx, tz, ty = 8.2, -1.7, TOP + 3.2
part(target, "Post", Vector3.new(0.5, 2.2, 0.5), S(tx, TOP + 1.1, tz + 0.3), LEAD)
part(target, "Foot", Vector3.new(1.8, 0.35, 1.2), S(tx, TOP + 0.18, tz + 0.3), LEAD)
for i, ring in
	{ { 3.0, LEAD }, { 2.7, hex("milk") }, { 2.1, hex("amethyst") }, { 1.45, hex("milk") }, { 0.8, hex("amber") } }
do
	part(
		target,
		"Ring" .. i,
		Vector3.new(0.12, ring[1], ring[1]),
		S(tx, ty, tz - 0.06 * i) * CFrame.Angles(0, math.rad(90), 0),
		ring[2],
		{
			Shape = Enum.PartType.Cylinder,
		}
	)
end
anchor(anchors, "DemoTarget", S(tx, ty, tz - 0.5))

-- Exhibit 2 (centre): the carriage's hover pad.
local pad = model(stage, "CarriagePad")
part(
	pad,
	"Pad",
	Vector3.new(0.5, 5.2, 5.2),
	S(0, TOP + 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)),
	LEAD,
	{ Shape = Enum.PartType.Cylinder }
)
local glow = part(
	pad,
	"Glow",
	Vector3.new(0.12, 5.5, 5.5),
	S(0, TOP + 0.45, 0) * CFrame.Angles(0, 0, math.rad(90)),
	hex("emerald", 2),
	{
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		CastShadow = false,
	}
)
part(
	pad,
	"Cap",
	Vector3.new(0.14, 4.6, 4.6),
	S(0, TOP + 0.52, 0) * CFrame.Angles(0, 0, math.rad(90)),
	hex("amethyst", 3),
	{ Shape = Enum.PartType.Cylinder }
)
emitter(
	glow,
	"PadSparkles",
	hex("emerald", 2),
	{ Rate = 5, Acceleration = Vector3.new(0, 2, 0), SpreadAngle = Vector2.new(15, 15) }
)
anchor(anchors, "CarriageSpot", S(0, TOP + 0.5 + 2.2, 0))

-- Exhibit 3 (east end): the Hollowlight glassy above a pedestal.
local pedestal = model(stage, "GlassyPedestal")
local gx, gz = -8.2, -1.7
part(pedestal, "Base", Vector3.new(2.8, 0.45, 2.8), S(gx, TOP + 0.22, gz), LEAD)
part(pedestal, "Shaft", Vector3.new(1.8, 2.2, 1.8), S(gx, TOP + 1.55, gz), hex("milk", 3))
part(pedestal, "Band", Vector3.new(1.95, 0.35, 1.95), S(gx, TOP + 1.6, gz), hex("amethyst"))
local cap = part(pedestal, "Cap", Vector3.new(2.5, 0.35, 2.5), S(gx, TOP + 2.8, gz), hex("amber"))
part(
	pedestal,
	"Glow",
	Vector3.new(0.1, 2.0, 2.0),
	S(gx, TOP + 3.0, gz) * CFrame.Angles(0, 0, math.rad(90)),
	hex("amber", 2),
	{
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		CastShadow = false,
	}
)
emitter(cap, "GlassySparkles", hex("amber", 2), { Rate = 4, Acceleration = Vector3.new(0, 1.5, 0) })
light(cap, hex("amber", 2), 9, 0.9)
anchor(anchors, "GlassySpot", S(gx, TOP + 7.2, gz))

-- Front plaques, tilted back like museum labels. The centre one carries the "View Collection" prompt.
for _, info in
	{
		{ 8.2, "FINISHER", "Lantern Eclipse", "PlaqueFinisher" },
		{ 0, "FLYER", "Moonlantern Carriage", "PlaqueFlyer" },
		{ -8.2, "GLASSY", "Hollowlight", "PlaqueGlassy" },
	}
do
	local x, kind, name, id = info[1], info[2], info[3], info[4]
	part(stage, id .. "Stand", Vector3.new(0.5, 0.9, 0.5), S(x, TOP + 0.45, -4.3), LEAD)
	local plaque = part(
		stage,
		id,
		Vector3.new(4.2, 1.3, 0.25),
		S(x, TOP + 1.05, -4.35) * CFrame.Angles(math.rad(35), 0, 0),
		hex("milk")
	)
	part(
		stage,
		id .. "Frame",
		Vector3.new(4.5, 1.6, 0.15),
		S(x, TOP + 1.05, -4.35) * CFrame.Angles(math.rad(35), 0, 0) * CFrame.new(0, 0, 0.18),
		LEAD
	)
	label(plaque, name, {
		Lines = {
			{ Name = "Kind", Text = kind, Height = 0.4, Color = hex("amethyst", 3), Stroke = false, Font = NUNITO },
			{ Name = "Name", Text = name, Height = 0.56, Color = LEAD, Stroke = false, Font = DENK },
		},
	})
	if x == 0 then
		local point = Instance.new("Attachment")
		point.Name, point.Position, point.Parent = "PromptPoint", Vector3.new(0, 0.6, -0.6), plaque
		plaque:SetAttribute("ShowcasePrompt", "Featured")
	end
end

-- ── Flyers display: two rotating hover pads either side of the Flyers stand ─────────────────────
-- ShowcaseController cycles every installed flyer through RiderSpot1..2, one rider each.
local flyers = model(root, "FlyersDisplay")
local flyerLook = Vector3.new(14, 0, 5)
for i, at in { Vector3.new(34.5, 3.4, -1.5), Vector3.new(34.5, 3.4, 10.0) } do
	local face = CFrame.lookAt(Vector3.new(at.X, 0, at.Z), flyerLook)
	anchor(flyers, "RiderSpot" .. i, face + Vector3.yAxis * at.Y)
	part(
		flyers,
		"PadRim" .. i,
		Vector3.new(0.25, 4.6, 4.6),
		face * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)),
		LEAD,
		{
			Shape = Enum.PartType.Cylinder,
			CastShadow = false,
		}
	)
	part(
		flyers,
		"PadGlow" .. i,
		Vector3.new(0.12, 4.0, 4.0),
		face * CFrame.new(0, 0.26, 0) * CFrame.Angles(0, 0, math.rad(90)),
		hex("ruby", 2),
		{
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Neon,
			Transparency = 0.3,
			CastShadow = false,
		}
	)
	part(
		flyers,
		"PadCore" .. i,
		Vector3.new(0.14, 2.2, 2.2),
		face * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
		hex("ruby"),
		{
			Shape = Enum.PartType.Cylinder,
			CastShadow = false,
		}
	)
end

-- ── Capsule opening stands, west and east of spawn (creator placement) ───────────────────────────── ───────────────────────────────────────────────
local bay = model(root, "CapsuleBay")
-- `lift` raises the sign so the two stands stay readable when one is behind the other from spawn.
local function stand(name, category, at, colour, title, subtitle, lift)
	local m = model(bay, name)
	m:SetAttribute("Category", category)
	local face = flat(spawnAt - at).Unit
	local B0 = CFrame.lookAt(at, at + face)
	local function B(x, y, z)
		return B0 * CFrame.new(x, y, z)
	end
	part(m, "Base", Vector3.new(5.6, 0.6, 5.6), B(0, 0.3, 0), LEAD, { CanCollide = true, CanQuery = true })
	part(m, "Top", Vector3.new(5.2, 0.15, 5.2), B(0, 0.62, 0), hex(colour, 3))
	part(m, "Lip", Vector3.new(5.7, 0.3, 0.3), B(0, 0.55, -2.8), hex("amber"))
	local slot =
		part(m, "MachineSlot", Vector3.new(4, 0.1, 4), B(0, 0.72, -0.2), LEAD, { Transparency = 1, CastShadow = false })
	slot:SetAttribute("Category", category)
	-- The crate-machines Coins template (pivot at its base, facing -Z, prompt on PromptPoint) when installed,
	-- otherwise a placeholder capsule. Tagged CrateMachine, so CrateMachineController animates it.
	local templates = game.ReplicatedStorage.Assets:FindFirstChild("CrateMachines")
	local template = templates and templates:FindFirstChild(category .. "_Coins")
	if template then
		local machine = template:Clone()
		machine.Name = "Machine"
		machine:PivotTo(slot.CFrame)
		machine.Parent = m
	else
		local ph = model(m, "MachinePlaceholder")
		part(
			ph,
			"Plinth",
			Vector3.new(1.4, 3.2, 3.2),
			B(0, 1.4, -0.2) * CFrame.Angles(0, 0, math.rad(90)),
			LEAD,
			{ Shape = Enum.PartType.Cylinder, CanCollide = true }
		)
		part(
			ph,
			"Band",
			Vector3.new(0.3, 3.35, 3.35),
			B(0, 2.0, -0.2) * CFrame.Angles(0, 0, math.rad(90)),
			hex(colour),
			{ Shape = Enum.PartType.Cylinder }
		)
		part(ph, "Dome", Vector3.new(3, 3, 3), B(0, 2.6, -0.2), hex(colour, 2), {
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Glass,
			Transparency = 0.45,
			CastShadow = false,
		})
		local core = part(
			ph,
			"Core",
			Vector3.new(1.2, 1.2, 1.2),
			B(0, 2.9, -0.2),
			hex(colour),
			{ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon }
		)
		emitter(core, "CoreSparkles", hex(colour, 2), { Rate = 3 })
		local plate = part(ph, "Plate", Vector3.new(1.4, 0.8, 0.2), B(0, 1.3, -1.75), hex("amber"))
		local point = Instance.new("Attachment")
		point.Name, point.Position, point.Parent = "PromptPoint", Vector3.new(0, 0.6, -0.4), plate
	end
	-- Sign behind the machine.
	part(m, "PostL", Vector3.new(0.4, 7 + lift, 0.4), B(-2.3, 3.8 + lift / 2, 2.3), LEAD)
	part(m, "PostR", Vector3.new(0.4, 7 + lift, 0.4), B(2.3, 3.8 + lift / 2, 2.3), LEAD)
	local sign = part(m, "Sign", Vector3.new(5.2, 1.8, 0.4), B(0, 6.6 + lift, 2.2), hex(colour))
	part(m, "SignFrame", Vector3.new(5.7, 2.3, 0.3), B(0, 6.6 + lift, 2.4), LEAD)
	label(sign, title, { Lines = { { Name = "Title", Text = title, Height = 1, StrokeThickness = 7 } } })
	local sub = part(m, "SubSign", Vector3.new(4.4, 0.8, 0.3), B(0, 5.25 + lift, 2.2), hex("milk"))
	label(
		sub,
		subtitle,
		{ Lines = { { Name = "Subtitle", Text = subtitle, Height = 1, Color = LEAD, Stroke = false, Font = NUNITO } } }
	)
	anchor(m, "ExampleSpot", B(0, 10 + lift, 0.4))
	return m
end
stand("Stand_Finishers", "Finishers", Vector3.new(-29.8, 0, 4.2), "amethyst", "FINISHERS", "Open Burst Capsules", 1.4)
stand("Stand_Rideables", "Rideables", Vector3.new(29.8, 0, 4.2), "ruby", "FLYERS", "Open Sky Capsules", 3.4)

root.Parent = workspace
local count = 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
return string.format(
	"Built FeaturedShowcase: %d parts, marker %s",
	count,
	if marker then marker:GetFullName() else "not found (default spot)"
)
