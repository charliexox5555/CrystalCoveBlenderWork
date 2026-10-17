-- Installs the Blender lobby landmark kit (asset 90727861432563, tools/blender/build_lobby_landmarks.py).
-- 1. insert_asset 90727861432563 into ServerStorage as "LobbyLandmarksV1Raw" (PackageLink removed).
-- 2. Run this in Edit. Builds ServerStorage.LobbyKit.{ArenaGate,GuardianPlinth,SpawnRosette,CrystalCluster}
--    (pivot at the floor centre, colours/materials applied, invisible box colliders), then swaps the
--    LobbyConcepts gate and guardian plinths for the kit pieces and puts the rosette on the spawn pad.
--    The creator's original arrival-pad parts are moved to ServerStorage.ArrivalPad_Original (not deleted).
assert(not game:GetService("RunService"):IsRunning(), "Install in Edit")
local SS = game:GetService("ServerStorage")
local raw = assert(SS:FindFirstChild("LobbyLandmarksV1Raw"), "Insert the raw model first")
if SS:FindFirstChild("LobbyKit") and not _G.LobbyKitRebuild then
	return "LobbyKit already installed (set _G.LobbyKitRebuild = true to rebuild it)"
end
_G.LobbyKitRebuild = nil
if SS:FindFirstChild("LobbyKit") then
	SS.LobbyKit:Destroy()
end

local LEAD = Color3.fromHex("1F1830")
local COLOURS = {
	Lead = LEAD,
	Gold = Color3.fromHex("F5A524"),
	Milk = Color3.fromHex("EEE7D9"),
	Ruby = Color3.fromHex("E23A55"),
	Amber = Color3.fromHex("F5A524"),
	Emerald = Color3.fromHex("22B573"),
	Aqua = Color3.fromHex("1FC2D3"),
	Amethyst = Color3.fromHex("8B4FE0"),
	Sapphire = Color3.fromHex("2E6BE6"),
	Glass = Color3.fromHex("9BF3F8"),
	Rock = Color3.fromHex("3A3550"),
}
-- FBX imports at 100x (centimetres); bring it to studs first.
raw:ScaleTo(raw:GetScale() * 0.01)

local function style(p)
	local name = p.Name
	local key = name:match("Glass(%a+)$") or name:match("_(%a+)$")
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = COLOURS[key] or LEAD
	if name:find("Glass") then
		p.Material, p.Transparency, p.Reflectance, p.CastShadow = Enum.Material.Glass, 0.25, 0.05, false
		p.Color = if key == "Glass" then COLOURS.Glass else COLOURS[key]
	elseif name == "Crystal_Rock" then
		p.Color = COLOURS.Rock
	end
end

local kit = Instance.new("Folder")
kit.Name = "LobbyKit"
local pieces = { ArenaGate = "Gate_", GuardianPlinth = "Plinth_", SpawnRosette = "Rose_", CrystalCluster = "Crystal_" }
local colliders = {
	ArenaGate = {
		{ Vector3.new(1.3, 9.5, 1.3), Vector3.new(-4.6, 4.75, 0) },
		{ Vector3.new(1.3, 9.5, 1.3), Vector3.new(4.6, 4.75, 0) },
	},
	GuardianPlinth = { { Vector3.new(4, 3, 4), Vector3.new(0, 1.5, 0) } },
}
local report = {}
for name, prefix in pieces do
	local parts = {}
	for _, d in raw:GetDescendants() do
		if d:IsA("MeshPart") and d.Name:sub(1, #prefix) == prefix then
			table.insert(parts, d:Clone())
		end
	end
	local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in parts do
		mn = mn:Min(p.Position - p.Size / 2)
		mx = mx:Max(p.Position + p.Size / 2)
	end
	local floor = Vector3.new((mn.X + mx.X) / 2, mn.Y, (mn.Z + mx.Z) / 2)
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name, root.Size, root.Transparency = "Root", Vector3.new(1, 0.2, 1), 1
	root.Anchored, root.CanCollide, root.CanTouch, root.CanQuery = true, false, false, false
	root.CFrame = CFrame.new(0, 0.1, 0)
	root.PivotOffset = CFrame.new(0, -0.1, 0)
	root.Parent = model
	model.PrimaryPart = root
	-- The FBX import bakes a yaw into every mesh (about -42 degrees); square each piece up around its floor.
	local _, yaw = parts[1].CFrame.Rotation:ToEulerAnglesYXZ()
	for _, p in parts do
		p.CFrame = CFrame.Angles(0, -yaw, 0) * (CFrame.new(p.Position - floor) * p.CFrame.Rotation)
		style(p)
		p.Parent = model
	end
	for i, c in colliders[name] or {} do
		local box = Instance.new("Part")
		box.Name, box.Size, box.CFrame, box.Transparency = "Collider" .. i, c[1], CFrame.new(c[2]), 1
		box.Anchored, box.CanCollide, box.CanTouch, box.CanQuery = true, true, false, true
		box.Parent = model
	end
	model:SetAttribute("SourceAsset", 90727861432563)
	model.Parent = kit
	report[#report + 1] =
		string.format("%s %d meshes, %.1f x %.1f x %.1f", name, #parts, mx.X - mn.X, mx.Y - mn.Y, mx.Z - mn.Z)
end
kit.Parent = SS

-- Place the pieces in the lobby.
local concepts = workspace:FindFirstChild("LobbyConcepts")
if concepts then
	local gateConcept = concepts:FindFirstChild("ArenaGate")
	if gateConcept then
		local gate = kit.ArenaGate:Clone()
		gate:PivotTo(CFrame.new(0, 0, -25.6))
		-- Keep the banner and pennants from the concept; drop its part-built frame.
		for _, p in gateConcept:GetChildren() do
			if p.Name == "Banner" or p.Name == "BannerFrame" or p.Name == "Pennant" then
				p.Parent = gate
			end
		end
		gateConcept:Destroy()
		gate.Parent = concepts
	end
	local guardians = concepts:FindFirstChild("GlassyGuardians")
	for _, plinth in guardians and guardians:GetChildren() or {} do
		local statue = plinth:FindFirstChildWhichIsA("Model")
		local foot = plinth:FindFirstChild("Foot")
		if statue and foot then
			local new = kit.GuardianPlinth:Clone()
			new.Name = plinth.Name
			new:PivotTo(CFrame.new(foot.Position.X, 0, foot.Position.Z))
			local tint = plinth:FindFirstChild("Pane") and plinth.Pane.Color or COLOURS.Aqua
			new.Plinth_Glass.Color = tint
			for _, e in plinth:GetDescendants() do
				if e:IsA("ParticleEmitter") then
					e.Parent = new.Root
				end
			end
			statue.Parent = new
			plinth:Destroy()
			new.Parent = guardians
		end
	end
end
-- Spawn rosette over the arrival pad; the creator's pad parts are kept in ServerStorage.
local backup = SS:FindFirstChild("ArrivalPad_Original") or Instance.new("Folder")
backup.Name, backup.Parent = "ArrivalPad_Original", SS
for _, p in workspace.Lobby.Folder:GetChildren() do
	if p.Name:match("^Arrival") then
		p.Parent = backup
	end
end
local spawnPad = workspace.Lobby:FindFirstChild("SpawnLocation")
local rosette = kit.SpawnRosette:Clone()
rosette:PivotTo(
	CFrame.new(spawnPad and Vector3.new(spawnPad.Position.X, 0, spawnPad.Position.Z) or Vector3.new(0, 0, 6))
)
rosette.Parent = concepts or workspace
return table.concat(report, "\n")
