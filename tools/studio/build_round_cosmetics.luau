-- Edit only. Original anchored native parts; no Toolbox assets/scripts. Never replaces prior assets.
assert(not game:GetService("RunService"):IsRunning(), "Build in Edit")
local RS, SS = game.ReplicatedStorage, game.ServerStorage
local C = require(RS.Shared.Config.RoundCosmetics)
assert(not RS.Assets:FindFirstChild("Rideables"), "Rideables already built; preserve/review before rebuilding")
local root = Instance.new("Folder")
root.Name, root.Parent = "Rideables", RS.Assets
local finishers = Instance.new("Folder")
finishers.Name, finishers.Parent = "RoundFinishers", RS.Assets
local function model(parent, id)
	local m = Instance.new("Model")
	m.Name, m.WorldPivot, m.Parent = id, CFrame.identity, parent
	m:SetAttribute("OriginalGlassClash", true)
	m:SetAttribute("Version", 1)
	return m
end
local function part(m, name, size, cf, color, class, material)
	local p = Instance.new(class or "Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Color, p.Material = Color3.fromHex(color), material or Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end
local function ball(m, name, size, pos, color, material)
	local p = part(m, name, size, CFrame.new(pos), color, nil, material)
	p.Shape = Enum.PartType.Ball
	return p
end
local function deck(m, name, size, pos, color)
	return part(m, name, size, CFrame.new(pos), color)
end
for _, def in C.Rideables do
	local m = model(root, def.Id)
	m:SetAttribute("DisplayName", def.Name)
	if def.Id == "skyboard" then
		deck(m, "Deck", Vector3.new(3.8, 0.38, 5.8), Vector3.new(0, -0.19, 0), def.Color)
		deck(m, "Grip", Vector3.new(2.4, 0.08, 3.1), Vector3.new(0, 0.02, 0), "#3A556E")
		for _, z in { -3, 3 } do
			part(
				m,
				"RaisedTip",
				Vector3.new(3.8, 0.4, 1),
				CFrame.new(0, -0.02, z) * CFrame.Angles(if z < 0 then -0.25 else 0.25, 0, 0),
				def.Color,
				"WedgePart"
			)
		end
		for _, x in { -1.65, 1.65 } do
			deck(m, "LiftFin", Vector3.new(0.2, 0.5, 4.7), Vector3.new(x, -0.48, 0), def.Accent)
			part(
				m,
				"LiftGlow",
				Vector3.new(0.12, 0.12, 3.8),
				CFrame.new(x, -0.68, 0),
				"#85F4F0",
				nil,
				Enum.Material.Neon
			)
		end
	elseif def.Id == "cloud_cushion" then
		deck(m, "Seat", Vector3.new(2.5, 0.3, 2.5), Vector3.new(0, -0.18, 0), def.Accent)
		for i = 1, 7 do
			local a = i / 7 * math.pi * 2
			ball(
				m,
				"CloudPuff",
				Vector3.new(2.5, 1.3, 2.6),
				Vector3.new(math.cos(a) * 1.35, -0.72, math.sin(a) * 1.35),
				def.Color
			)
		end
		for i, color in { "#F2B3D9", "#FFE29D", "#A9DBCA" } do
			deck(m, "RainbowWake", Vector3.new(0.45, 0.14, 2.2), Vector3.new((i - 2) * 0.5, -0.8, 3), color)
		end
	elseif def.Id == "rocket_skiff" then
		deck(m, "Deck", Vector3.new(3.4, 0.45, 4.4), Vector3.new(0, -0.24, 0), def.Color)
		deck(m, "Grip", Vector3.new(2.2, 0.08, 2.7), Vector3.new(0, 0.02, 0), "#493D58")
		part(
			m,
			"Prow",
			Vector3.new(3.4, 0.6, 1.8),
			CFrame.new(0, -0.16, -3.05) * CFrame.Angles(0, math.pi, 0),
			def.Color,
			"WedgePart"
		)
		for _, x in { -2, 2 } do
			ball(m, "Engine", Vector3.new(0.95, 0.95, 3.5), Vector3.new(x, -0.45, 0.6), def.Accent)
			local e = ball(
				m,
				"Exhaust",
				Vector3.new(0.55, 0.55, 1.65),
				Vector3.new(x, -0.45, 2.75),
				"#8FEAFF",
				Enum.Material.Neon
			)
			e:SetAttribute("RideMotion", "Flame")
			deck(m, "Fin", Vector3.new(0.18, 0.85, 1.3), Vector3.new(x, -0.1, 1.2), def.Color)
		end
	else
		ball(m, "Body", Vector3.new(3, 0.75, 4.3), Vector3.new(0, -0.4, 0), def.Color)
		deck(m, "Grip", Vector3.new(1.8, 0.1, 2.4), Vector3.new(0, 0.02, 0), def.Accent)
		for _, side in { -1, 1 } do
			local wing = part(
				m,
				"Wing",
				Vector3.new(0.32, 3.5, 4),
				CFrame.new(side * 2.5, -0.4, 0) * CFrame.Angles(0, 0, side * math.pi / 2),
				def.Color,
				"WedgePart"
			)
			wing:SetAttribute("RideMotion", "Wing")
			wing:SetAttribute("WingSide", side)
			ball(m, "FriendlyEye", Vector3.new(0.22, 0.22, 0.22), Vector3.new(side * 0.7, -0.08, -1.65), "#324D68")
		end
		part(m, "Tail", Vector3.new(0.3, 0.3, 3), CFrame.new(0, -0.4, 3), def.Accent)
	end
	task.wait()
end
for _, def in C.Finishers do
	local m = model(finishers, def.Id)
	m:SetAttribute("DisplayName", def.Name)
	local color = def.Color
	ball(m, "Core", Vector3.one * 1.7, Vector3.zero, color, Enum.Material.Neon)
	if def.Id == "starfall" then
		m.Core.Shape = Enum.PartType.Block
		m.Core.Size = Vector3.new(2.2, 0.38, 0.3)
		m.Core.CFrame = CFrame.Angles(0, 0, math.pi / 4)
		local cross = m.Core:Clone()
		cross.Name, cross.CFrame, cross.Color, cross.Parent =
			"StarCross", CFrame.Angles(0, 0, -math.pi / 4), Color3.fromHex(def.Accent), m
	elseif def.Id == "brick_boom" then
		for _, x in { -0.7, 0.7 } do
			ball(m, "ToyFlame", Vector3.one * 1.1, Vector3.new(x, 0.6, 0), def.Accent, Enum.Material.Neon)
		end
	end
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local p = part(
			m,
			"BurstPiece",
			Vector3.one * 0.45,
			CFrame.new(math.cos(a) * 2, math.sin(a) * 2, 0) * CFrame.Angles(a, a, a),
			if i % 2 == 0 then def.Accent else color
		)
		if def.Id == "bubble_bloom" then
			p.Shape = Enum.PartType.Ball
			p.Size = Vector3.one * 0.9
			p.Transparency = 0.3
		end
		if def.Id == "party_burst" then
			p.Size = Vector3.new(0.35, 0.75, 0.08)
			p.Color = Color3.fromHSV(i / 8, 0.6, 1)
		end
		if def.Id == "starfall" then
			p.Material = Enum.Material.Neon
		end
	end
end
return { Rideables = #root:GetChildren(), Finishers = #finishers:GetChildren(), ScriptFree = true }
