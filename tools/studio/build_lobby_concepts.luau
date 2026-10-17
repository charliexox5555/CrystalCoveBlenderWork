-- Builds Workspace.LobbyConcepts: three landmark concepts for the creator to judge before the lobby gets more
-- set dressing. A) Marble Fountain centrepiece between spawn and the trophy board, B) giant glassy guardians
-- on stained-glass plinths at the bridge, C) a stained-glass Arena Gate arch with pennants over the north lane.
-- Static, matte Stained Glass / low-poly pieces; glassies are clones of the real collectibles.
-- Refuses to run if LobbyConcepts exists (set _G.LobbyConceptsRebuild = true to replace it).
assert(not game:GetService("RunService"):IsRunning(), "Build the lobby concepts in Edit mode")
if workspace:FindFirstChild("LobbyConcepts") then
	if not _G.LobbyConceptsRebuild then
		return "LobbyConcepts already exists: nothing changed (set _G.LobbyConceptsRebuild = true to replace it)"
	end
	workspace.LobbyConcepts:Destroy()
end
_G.LobbyConceptsRebuild = nil

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
local function glass(parent, name, size, cf, color, props)
	local p =
		part(parent, name, size, cf, color, { Material = Enum.Material.Glass, Transparency = 0.3, CastShadow = false })
	for k, v in props or {} do
		(p :: any)[k] = v
	end
	return p
end
local function model(parent, name)
	local m = Instance.new("Model")
	m.Name, m.Parent = name, parent
	return m
end
local function disc(parent, name, diameter, height, cf, color, props)
	local p = part(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		cf * CFrame.Angles(0, 0, math.rad(90)),
		color,
		props
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function sparkles(parent, color, rate, props)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission, e.LightInfluence = 1, 0
	e.Rate, e.Lifetime, e.Speed = rate, NumberRange.new(1.2, 2.2), NumberRange.new(1, 2.5)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new(0.1, 1)
	e.SpreadAngle = Vector2.new(25, 25)
	for k, v in props or {} do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end
local function label(p, text, size)
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.SizingMode, gui.PixelsPerStud = Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 50
	gui.LightInfluence, gui.MaxDistance = 0, 220
	gui.Parent = p
	local t = Instance.new("TextLabel")
	t.Size, t.Position = UDim2.fromScale(0.92, 1), UDim2.fromScale(0.04, 0)
	t.BackgroundTransparency, t.TextScaled, t.FontFace = 1, true, DENK
	t.Text, t.TextColor3 = text, Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.LineJoinMode = LEAD, size or 7, Enum.LineJoinMode.Round
	stroke.Parent = t
	t.Parent = gui
end

local root = Instance.new("Model")
root.Name = "LobbyConcepts"
root:SetAttribute("BuiltBy", "tools/studio/build_lobby_concepts.luau")

-- ── A) Marble Fountain: octagonal lead basin, glass water, a giant glowing marble on a pillar ──────
local fountain = model(root, "MarbleFountain")
local F = CFrame.new(0, 0, 17)
disc(fountain, "Basin", 9, 0.9, F * CFrame.new(0, 0.45, 0), LEAD, { CanCollide = true, CanQuery = true })
glass(
	fountain,
	"Water",
	Vector3.new(0.3, 7.8, 7.8),
	F * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)),
	hex("aqua", 2),
	{
		Shape = Enum.PartType.Cylinder,
		Transparency = 0.35,
	}
)
for i = 0, 7 do
	local a = i * math.pi / 4
	local swatch = ({ "amethyst", "aqua", "amber", "ruby", "emerald", "sapphire", "amethyst", "aqua" })[i + 1]
	glass(
		fountain,
		"RimPane",
		Vector3.new(2.9, 0.7, 0.25),
		F * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.55, -4.45),
		hex(swatch),
		{
			Transparency = 0.2,
		}
	)
end
disc(fountain, "PillarBase", 2.6, 0.5, F * CFrame.new(0, 1.15, 0), LEAD)
part(fountain, "Pillar", Vector3.new(1.3, 3.4, 1.3), F * CFrame.new(0, 3.0, 0), hex("milk", 3))
part(fountain, "PillarBand", Vector3.new(1.45, 0.35, 1.45), F * CFrame.new(0, 3.4, 0), hex("amethyst"))
disc(fountain, "Cup", 2.8, 0.4, F * CFrame.new(0, 4.85, 0), hex("amber"))
local marble = glass(fountain, "Marble", Vector3.new(3, 3, 3), F * CFrame.new(0, 6.6, 0), hex("aqua"), {
	Shape = Enum.PartType.Ball,
	Transparency = 0.25,
	Reflectance = 0.1,
})
local swirl = part(fountain, "Swirl", Vector3.new(1.4, 1.4, 1.4), F * CFrame.new(0, 6.6, 0), hex("amethyst", 2), {
	Shape = Enum.PartType.Ball,
	Material = Enum.Material.Neon,
	CastShadow = false,
})
local light = Instance.new("PointLight")
light.Color, light.Range, light.Brightness, light.Shadows = hex("aqua", 2), 14, 1, false
light.Parent = swirl
sparkles(marble, hex("aqua", 2), 6, { Acceleration = Vector3.new(0, -3, 0), EmissionDirection = Enum.NormalId.Top })
for i = 0, 3 do
	local a = i * math.pi / 2 + math.pi / 4
	local spout = part(
		fountain,
		"Spout",
		Vector3.new(0.5, 0.5, 0.5),
		F * CFrame.Angles(0, a, 0) * CFrame.new(0, 1.2, -1.6),
		hex("amber"),
		{
			Shape = Enum.PartType.Ball,
		}
	)
	sparkles(spout, hex("aqua", 2), 4, {
		Acceleration = Vector3.new(0, -12, 0),
		Speed = NumberRange.new(5, 6),
		SpreadAngle = Vector2.new(8, 8),
		Lifetime = NumberRange.new(0.6, 0.8),
	})
end

-- ── B) Giant glassy guardians on stained-glass plinths at the bridge ────────────────────────────
local guardians = model(root, "GlassyGuardians")
local glassies = game:GetService("ReplicatedStorage").Assets.Glassies
for _, info in { { -8.6, "pop", "aqua" }, { 8.6, "prism_blade", "amethyst" } } do
	local x, id, colour = info[1], info[2], info[3]
	local base = CFrame.new(x, 0, -22.5)
	local plinth = model(guardians, "Plinth_" .. id)
	part(
		plinth,
		"Foot",
		Vector3.new(4.2, 0.5, 4.2),
		base * CFrame.new(0, 0.25, 0),
		LEAD,
		{ CanCollide = true, CanQuery = true }
	)
	part(
		plinth,
		"Block",
		Vector3.new(3.4, 2.2, 3.4),
		base * CFrame.new(0, 1.6, 0),
		hex("milk", 3),
		{ CanCollide = true, CanQuery = true }
	)
	for s = 0, 3 do
		glass(
			plinth,
			"Pane",
			Vector3.new(2.6, 1.5, 0.2),
			base * CFrame.Angles(0, s * math.pi / 2, 0) * CFrame.new(0, 1.6, -1.72),
			hex(colour),
			{
				Transparency = 0.15,
			}
		)
	end
	part(plinth, "Cap", Vector3.new(3.9, 0.35, 3.9), base * CFrame.new(0, 2.88, 0), hex("amber"))
	local source = glassies:FindFirstChild(id)
	if source then
		local statue = source:Clone()
		local shards = statue:FindFirstChild("Shards")
		if shards then
			shards:Destroy()
		end
		for _, p in statue:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
			end
		end
		statue:ScaleTo(4)
		statue.Name = "Giant_" .. id
		-- Stand it on the plinth (the model pivot is the hang point at the top).
		local cf, size = statue:GetBoundingBox()
		local bottom = cf.Position.Y - size.Y / 2
		statue:PivotTo(
			CFrame.new(x, 0, -22.5) * CFrame.Angles(0, if x < 0 then math.rad(25) else math.rad(-25), 0)
				+ Vector3.yAxis * (statue:GetPivot().Y - bottom + 3.05)
		)
		statue.Parent = plinth
		sparkles(
			plinth.Cap,
			hex(colour, 2),
			3,
			{ Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(0.5, 1.2) }
		)
	end
end

-- ── C) Arena Gate: stained-glass arch with a banner and pennants over the north lane ─────────────
local gate = model(root, "ArenaGate")
local G = CFrame.new(0, 0, -25.6)
for _, x in { -4.6, 4.6 } do
	part(
		gate,
		"Pillar",
		Vector3.new(1.0, 9, 1.0),
		G * CFrame.new(x, 4.5, 0),
		LEAD,
		{ CanCollide = true, CanQuery = true }
	)
	part(gate, "PillarFoot", Vector3.new(1.6, 0.5, 1.6), G * CFrame.new(x, 0.25, 0), LEAD)
	part(gate, "PillarCap", Vector3.new(1.4, 0.4, 1.4), G * CFrame.new(x, 9.2, 0), hex("amber"))
	for i = 1, 3 do
		glass(
			gate,
			"PillarPane",
			Vector3.new(1.06, 1.6, 1.06),
			G * CFrame.new(x, 1.4 + i * 2.1, 0),
			hex(({ "emerald", "aqua", "amethyst" })[i]),
			{
				Transparency = 0.15,
			}
		)
	end
end
part(gate, "Beam", Vector3.new(10.6, 0.8, 1.0), G * CFrame.new(0, 9.6, 0), LEAD)
local slope = math.atan2(2.4, 5.3)
for s = -1, 1, 2 do
	part(
		gate,
		"Gable",
		Vector3.new(math.sqrt(5.3 ^ 2 + 2.4 ^ 2) + 0.3, 0.5, 0.9),
		G * CFrame.new(s * 2.65, 11.2, 0) * CFrame.Angles(0, 0, -s * slope),
		LEAD
	)
end
for i, swatch in { "ruby", "amber", "emerald", "aqua", "amethyst" } do
	local x = -3.6 + (i - 1) * 1.8
	local h = 2.2 - math.abs(x) * 0.42
	glass(
		gate,
		"GablePane",
		Vector3.new(1.6, h, 0.25),
		G * CFrame.new(x, 10 + h / 2, 0),
		hex(swatch),
		{ Transparency = 0.15 }
	)
end
local banner = part(gate, "Banner", Vector3.new(7.4, 1.6, 0.3), G * CFrame.new(0, 8.3, -0.6), hex("emerald", 3))
part(gate, "BannerFrame", Vector3.new(7.9, 2.0, 0.2), G * CFrame.new(0, 8.3, -0.75), LEAD)
label(banner, "ARENAS")
banner:FindFirstChildOfClass("SurfaceGui").Face = Enum.NormalId.Back -- reads from the spawn side
for i = 0, 6 do
	local x = -3.9 + i * 1.3
	local swatch = ({ "ruby", "amber", "emerald", "aqua", "sapphire", "amethyst", "ruby" })[i + 1]
	local flag = part(
		gate,
		"Pennant",
		Vector3.new(0.12, 1.0, 0.9),
		G * CFrame.new(x, 6.9, -0.2) * CFrame.Angles(0, math.rad(90), 0),
		hex(swatch),
		{
			Shape = Enum.PartType.Wedge,
		}
	)
	flag.CFrame = G * CFrame.new(x, 7.0, -0.2) * CFrame.Angles(math.rad(180), math.rad(90), 0)
	flag:SetAttribute("Sway", true)
end

root.Parent = workspace
local count = 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
return string.format("Built LobbyConcepts: %d parts", count)
