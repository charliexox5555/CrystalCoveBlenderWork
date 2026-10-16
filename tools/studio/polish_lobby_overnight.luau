-- Edit only. Reversible original native-parts lobby dressing; preserves gameplay geometry.
assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local lobby, SS, RS = workspace.Lobby, game.ServerStorage, game.ReplicatedStorage
assert(not lobby:FindFirstChild("NightPolishV1"), "Pass already installed")
assert(not SS:FindFirstChild("LobbyBeforeNight_20261016"), "Backup already exists")
local backup = Instance.new("Folder")
backup.Name, backup.Parent = "LobbyBeforeNight_20261016", SS
for _, child in lobby:GetChildren() do
	child:Clone().Parent = backup
	task.wait()
end
local root = Instance.new("Model")
root.Name, root.Parent = "NightPolishV1", lobby
root:SetAttribute("OriginalGlassClash", true)
root:SetAttribute("Version", 1)
local function part(name, size, cf, color, shape, parent)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Color, p.Material = Color3.fromHex(color), Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent or root
	return p
end
local function cylinder(name, diameter, height, pos, color)
	return part(
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		Enum.PartType.Cylinder
	)
end
local function label(p, text, face)
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Face, gui.SizingMode, gui.PixelsPerStud =
		"Sign", face or Enum.NormalId.Back, Enum.SurfaceGuiSizingMode.PixelsPerStud, 40
	gui.LightInfluence, gui.Parent = 0.2, p
	local t = Instance.new("TextLabel")
	t.Size, t.BackgroundTransparency, t.Text = UDim2.fromScale(0.94, 0.9), 1, text
	t.Position, t.TextScaled, t.TextWrapped = UDim2.fromScale(0.03, 0.05), true, true
	t.FontFace, t.TextColor3 = Font.fromName("FredokaOne"), Color3.fromHex("#FFF3D5")
	t.Parent = gui
end
local function sign(name, text, pos, width, color)
	part(name .. "Post", Vector3.new(0.45, 3, 0.45), CFrame.new(pos + Vector3.yAxis * 1.5), "#715847")
	local p = part(name, Vector3.new(width, 1.8, 0.25), CFrame.new(pos + Vector3.yAxis * 3.2), color)
	label(p, text)
	return p
end
local props = lobby.GlassClashProps
local function move(model, x, z)
	local cf = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(x - cf.X, 0, z - cf.Z))
end
move(props.Kiln, -25, -9)
lobby.Spots.Kiln.Position = Vector3.new(-25, lobby.Spots.Kiln.Position.Y, -9)
for _, spec in
	{
		{ "Leaderboard_MatchWins", "LeaderboardWins", -18, 24 },
		{ "Leaderboard_Trophies", "Champion", 0, 25 },
		{ "Leaderboard_Shatters", "LeaderboardStreak", 18, 24 },
	}
do
	move(props[spec[1]], spec[3], spec[4])
	local spot = lobby.Spots[spec[2]]
	spot.Position = Vector3.new(spec[3], spot.Position.Y, spec[4])
end
for _, spec in { { "DailyKiosk", "Daily", -31, 9 }, { "CodesKiosk", "Codes", 31, 9 } } do
	move(props[spec[1]], spec[3], spec[4])
	local spot = lobby.Spots[spec[2]]
	spot.Position = Vector3.new(spec[3], spot.Position.Y, spec[4])
	sign(
		spec[2] .. "Header",
		if spec[2] == "Daily" then "DAILY GIFTS" else "SECRET CODES",
		Vector3.new(spec[3], 0, spec[4] + 1.6),
		6,
		"#5C7291"
	)
end
-- Arrival medallion and two warm stone courts; clear center corridor remains intact.
cylinder("ArrivalMedallion", 12, 0.12, Vector3.new(0, 0.03, 12), "#D1B991")
cylinder("ArrivalInlay", 10.4, 0.13, Vector3.new(0, 0.04, 12), "#809D9B")
for i = 1, 8 do
	local a = i / 8 * math.pi * 2
	part(
		"ArrivalFacet",
		Vector3.new(0.5, 0.08, 1.2),
		CFrame.new(math.cos(a) * 4.7, 0.14, 12 + math.sin(a) * 4.7) * CFrame.Angles(0, -a, 0),
		"#EFE1BA"
	)
end
cylinder("KilnCourt", 23, 0.12, Vector3.new(-25, 0.03, -9), "#CFBE9F")
cylinder("RideCourt", 24, 0.12, Vector3.new(25, 0.03, -9), "#B8C8BD")
for _, side in { -1, 1 } do
	for i = 1, 6 do
		local p = Vector3.new(side * (7 + i * 2.2), 0.12, 7 - i * 2)
		part(
			"BranchPaver",
			Vector3.new(2, 0.16, 1.4),
			CFrame.new(p) * CFrame.Angles(0, side * 0.5, 0),
			if i % 2 == 0 then "#D8C9AA" else "#B6B3A2"
		)
	end
end
-- Welcome gate frames the vista without changing queue/hook/stand geometry.
for _, x in { -8, 8 } do
	part("WelcomePost", Vector3.new(0.8, 11, 0.8), CFrame.new(x, 5.5, -22), "#715847")
	part("PostCap", Vector3.new(1.2, 0.35, 1.2), CFrame.new(x, 11, -22), "#D9B67C")
end
local title = part("WelcomeTitle", Vector3.new(17, 2.6, 0.5), CFrame.new(0, 10, -22), "#497B89")
label(title, "GLASS CLASH")
sign("ClashRoute", "CLASHES  ↑", Vector3.new(-8, 0, -15), 6, "#497B89")
sign("KilnRoute", "THE KILN  ←", Vector3.new(-9, 0, 1), 6, "#A16D49")
sign("RideRoute", "SKY RIDES  →", Vector3.new(9, 0, 1), 6, "#6D6595")
-- Original workshop bench and glassmaking display.
part("WorkshopBench", Vector3.new(7, 0.5, 2.8), CFrame.new(-34, 2.3, -7), "#8C6B4B")
for _, x in { -36.5, -31.5 } do
	part("BenchLeg", Vector3.new(0.5, 2.2, 0.5), CFrame.new(x, 1.1, -7), "#715847")
end
for i, id in { "pop", "jam", "prism" } do
	local source = RS.Assets.Glassies[id]
	local m = Instance.new("Model")
	m.Name, m.WorldPivot = "Workshop_" .. id, CFrame.identity
	source.Body:Clone().Parent = m
	local details = source:FindFirstChild("Details")
	if details then
		for _, p in details:GetChildren() do
			if p:IsA("BasePart") then
				p:Clone().Parent = m
			end
		end
	end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		end
	end
	m:ScaleTo(0.8)
	m:PivotTo(CFrame.new(-37 + i * 1.5, 4.3, -7))
	m.Parent = root
end
sign("KilnHeader", "THE KILN\nMake your next glassy", Vector3.new(-25, 0, -17.5), 11, "#A16D49")
sign("RideHeader", "SKY RIDES\nInventory → Flyers", Vector3.new(25, 0, -18), 12, "#6D6595")
for i, def in require(RS.Shared.Config.RoundCosmetics).Rideables do
	local pos = Vector3.new(21 + (i - 1) % 2 * 8, 0.7, -4 - math.floor((i - 1) / 2) * 8)
	cylinder("RidePlinth", 5.5, 0.6, pos - Vector3.yAxis * 0.3, "#789C9B")
	local m = RS.Assets.Rideables[def.Id]:Clone()
	m.Name = "Showcase_" .. def.Id
	m:ScaleTo(0.65)
	m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, -0.3, 0))
	m.Parent = root
	local plaque = part("RidePlaque", Vector3.new(4, 0.7, 0.15), CFrame.new(pos + Vector3.new(0, -0.3, 3)), "#52677F")
	label(plaque, def.Name)
end
local function planter(x, y, z, seed)
	local pos = Vector3.new(x, y, z)
	part("Planter", Vector3.new(3.3, 0.7, 2), CFrame.new(pos + Vector3.yAxis * 0.35), "#B8A07F")
	for i = 1, 3 do
		local leaf = part(
			"LowPolyShrub",
			Vector3.new(1.6, 1.3, 1.5),
			CFrame.new(pos + Vector3.new((i - 2) * 0.8, 1.3, 0)) * CFrame.Angles(0.2 * i, 0.7 * i, 0.15 * i),
			if i % 2 == 0 then "#659B7A" else "#83AC80"
		)
		for j = 1, 2 do
			part(
				"Flower",
				Vector3.one * 0.3,
				CFrame.new(leaf.Position + Vector3.new((j - 1.5) * 0.6, 0.7, 0.3)),
				if seed % 2 == 0 then "#D9ADD2" else "#F0CD8B",
				Enum.PartType.Ball
			)
		end
	end
end
for i, p in { { -40, 0, -2 }, { 40, 0, -2 }, { -9, 0, 21 }, { 9, 0, 21 }, { -36, 0, 17 }, { 36, 0, 17 } } do
	planter(p[1], p[2], p[3], i)
end
for row = 1, 3 do
	for _, x in { -33, 33 } do
		planter(x, row * 2, -55 - (row - 1) * 50 + 18, row)
	end
	task.wait()
end
for _, x in { -15, 15 } do
	part("Seat", Vector3.new(5, 0.3, 1.7), CFrame.new(x, 1.4, 10), "#957550")
	part("SeatBack", Vector3.new(5, 1.2, 0.25), CFrame.new(x, 2, 10.75), "#957550")
	for _, dx in { -1.8, 1.8 } do
		part("SeatFoot", Vector3.new(0.4, 1.3, 1.3), CFrame.new(x + dx, 0.65, 10), "#655448")
	end
end
for i, z in { -29.9, -80, -129.8, -179.9 } do
	for _, x in { -6.8, 6.8 } do
		local y = 1 + (i - 1) * 2
		part("BridgeLanternPost", Vector3.new(0.35, 3, 0.35), CFrame.new(x, y + 1.5, z), "#715847")
		local lamp = part("BridgeLantern", Vector3.new(0.8, 1, 0.8), CFrame.new(x, y + 3, z), "#FFE2A8")
		lamp.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Shadows = lamp.Color, 0.45, 9, false
		light.Parent = lamp
	end
end
root:SetAttribute("DecorativeParts", #root:GetDescendants())
return {
	Backup = backup:GetFullName(),
	Decor = root:GetFullName(),
	Descendants = #root:GetDescendants(),
	Geometry = "Islands/fences/arenas unchanged",
}
