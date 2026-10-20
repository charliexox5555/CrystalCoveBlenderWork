-- Edit mode (Studio MCP), with the Studio lock held. Map polish (2026-10-20): restrained decor for the sky islands.
-- Everything goes in Workspace.Lobby.Decor (delete that folder to undo); kit templates in ServerStorage.MapDecorKit.
-- Re-running replaces only Decor and MapDecorKit; nothing else in the place is moved or changed.
--   Decor.Islands.<Isle>   trees, bushes, rocks, flower tufts from assets/blender/map/decor_kit (Open Cloud ids below)
--   Decor.Clouds           a few extra clones of the existing SkyArt clouds
--   Decor.Glints           one soft sparkle emitter per island (client-cheap: a few particles per second)
-- Placement is seeded and clearance-checked: a prop goes only on island floor (Lobby.Collision floor strips), away
-- from pens, pads, paths, bridges, fences, lanterns and every other part (CanQuery=false parts by bounding box).
assert(not game:GetService("RunService"):IsRunning(), "Run in Edit")
local InsertService = game:GetService("InsertService")
local SS = game:GetService("ServerStorage")
local Lobby = workspace.Lobby

local IDS = {
	TreeRound = 112923572292891,
	TreePine = 119942453672575,
	Bush = 121358676796724,
	Rock = 108813216400441,
	FlowerTuft = 127599498711858,
}
local MESH_LOOK = { -- mesh name -> colour(s); a list picks one per placement
	Trunk = { "#7A5232" },
	Canopy = { "#4E9A45", "#5AA64B", "#4A9150" },
	Leaves = { "#3F8F52", "#4C9A49" },
	Stone = { "#B3ACC4", "#A39CB8" },
	Grass = { "#5DAF45" },
	Petals = { "#FF8FB8", "#FFD45E", "#F5F0FF", "#C9A6FF" },
	Centers = { "#FFC83D" },
}
-- Footprint radius, clearance margin and height for the overlap check, per prop.
local PROPS = {
	TreeRound = { Radius = 3.6, Margin = 1.0, Height = 10.5, Scale = { 0.9, 1.1 } },
	TreePine = { Radius = 3.2, Margin = 1.0, Height = 9.5, Scale = { 0.9, 1.15 } },
	Bush = { Radius = 2.2, Margin = 1.2, Height = 2.6, Scale = { 0.8, 1.15 } },
	Rock = { Radius = 1.6, Margin = 1.0, Height = 1.6, Scale = { 0.8, 1.3 } },
	FlowerTuft = { Radius = 0.8, Margin = 0.6, Height = 2.0, Scale = { 1.2, 1.5 } },
}
-- How many of each per island (kept small on purpose). Flowers come in clusters of 2-3 tufts. The arena islands are
-- nearly all pens, pads and paths (no tree fits), so they only get small things; trees go on the Featured island's
-- sides and the spawn island's edges.
-- The leaderboards are being rebuilt along the spawn island's back (+Z) edge: keep that strip free for them.
local function awayFromBoards(x, z)
	return not (z > 10 and x > -30 and x < 40)
end
local ISLANDS = {
	Isle_Arena1 = { Trees = 0, Bush = 2, Rock = 2, FlowerClusters = 3 },
	Isle_Arena2 = { Trees = 0, Bush = 2, Rock = 2, FlowerClusters = 3 },
	Isle_Arena3 = { Trees = 0, Bush = 2, Rock = 2, FlowerClusters = 3 },
	Isle_Featured = {
		Trees = 2,
		Bush = 2,
		Rock = 2,
		FlowerClusters = 2,
		TreeSpot = function(x)
			return math.abs(x) >= 26 -- beside the featured arena, not in front of it
		end,
	},
	Isle_Lobby = {
		Trees = 2,
		Bush = 2,
		Rock = 1,
		FlowerClusters = 3,
		Spot = awayFromBoards,
		TreeSpot = function(x, z)
			return math.abs(x) >= 34 and awayFromBoards(x, z)
		end,
	},
}

local rng = Random.new(20261020)

-- Kit templates -----------------------------------------------------------------------------------------------
local kit = SS:FindFirstChild("MapDecorKit")
if kit then
	kit:Destroy()
end
kit = Instance.new("Folder")
kit.Name = "MapDecorKit"
for name, id in IDS do
	local container = InsertService:LoadAsset(id)
	local model = container:FindFirstChildWhichIsA("Model") or container
	model.Parent = nil
	container:Destroy()
	model.Name = name
	model:ScaleTo(model:GetScale() * 0.01) -- the FBX imports in centimetres
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
			part.Material, part.Reflectance = Enum.Material.SmoothPlastic, 0
			part.CastShadow = name == "TreeRound" or name == "TreePine"
		end
	end
	-- Pivot at the ground centre (the FBX origin).
	local trunk = model:FindFirstChild("Trunk")
	local _, size = model:GetBoundingBox()
	local base = model:GetBoundingBox().Position - Vector3.yAxis * size.Y / 2
	model.WorldPivot = CFrame.new(if trunk then Vector3.new(trunk.Position.X, base.Y, trunk.Position.Z) else base)
	model.Parent = kit
end
kit.Parent = SS

-- Where the floor is: the invisible floor strips (4 studs deep) per island -----------------------------------
local floors = {}
for _, strip in Lobby.Collision:GetChildren() do
	local isle = strip.Name:match("^(Isle_%w+)_Floor")
	if isle and strip:IsA("BasePart") then
		floors[isle] = floors[isle] or {}
		table.insert(floors[isle], strip)
	end
end
local function onFloor(isle, x, z, radius)
	-- Every corner of the footprint must sit on some strip, `radius` in from its ends (and 1.5 studs more toward the
	-- island's front and back rims, where the fences run).
	local deep = radius + 1.5
	for _, offset in { Vector2.new(radius, 0), Vector2.new(-radius, 0), Vector2.new(0, deep), Vector2.new(0, -deep) } do
		local px, pz, ok = x + offset.X, z + offset.Y, false
		for _, strip in floors[isle] do
			local p, s = strip.Position, strip.Size
			if math.abs(px - p.X) <= s.X / 2 - 1 and math.abs(pz - p.Z) <= s.Z / 2 then
				ok = true
				break
			end
		end
		if not ok then
			return false
		end
	end
	return true
end
local function groundY(isle)
	local strip = floors[isle][1]
	return strip.Position.Y + strip.Size.Y / 2
end

-- Clearance: nothing but island ground and floor strips inside the prop's padded footprint ------------------
local decor = Lobby:FindFirstChild("Decor")
if decor then
	decor:Destroy()
end
decor = Instance.new("Folder")
decor.Name = "Decor"
decor:SetAttribute("Source", "tools/studio/place_lobby_decor.luau (map polish 2026-10-20)")
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { Lobby.Islands, Lobby.Collision, workspace.Terrain, decor }
local placed = {} -- { Position, Radius }
-- Spatial queries skip CanQuery = false parts (path stones, pads, lanes...), so those are checked by their world
-- bounding boxes instead.
local hidden = {}
local skip = { Lobby.Islands, Lobby.Collision, workspace.Terrain }
for _, part in workspace:GetDescendants() do
	if part:IsA("BasePart") and not part.CanQuery and part.Transparency < 1 and part.Size.Magnitude < 150 then
		local excluded = false
		for _, root in skip do
			if part:IsDescendantOf(root) then
				excluded = true
				break
			end
		end
		-- Perimeter meshes (one fence mesh per island) would cover the whole island; edges are handled by onFloor.
		local flat = part.Size
		if flat.X > 20 and flat.Z > 20 then
			excluded = true
		end
		if not excluded then
			local half = part.Size / 2
			local r = part.CFrame.RightVector * half.X
			local u = part.CFrame.UpVector * half.Y
			local l = part.CFrame.LookVector * half.Z
			local extent = Vector3.new(
				math.abs(r.X) + math.abs(u.X) + math.abs(l.X),
				math.abs(r.Y) + math.abs(u.Y) + math.abs(l.Y),
				math.abs(r.Z) + math.abs(u.Z) + math.abs(l.Z)
			)
			table.insert(hidden, { Min = part.Position - extent, Max = part.Position + extent })
		end
	end
end
local function clear(x, y, z, prop)
	local r = prop.Radius + prop.Margin
	for _, other in placed do
		if (Vector2.new(other.Position.X, other.Position.Z) - Vector2.new(x, z)).Magnitude < r + other.Radius then
			return false
		end
	end
	for _, box in hidden do
		if
			box.Max.Y > y - 0.5
			and box.Min.Y < y + prop.Height
			and x + r > box.Min.X
			and x - r < box.Max.X
			and z + r > box.Min.Z
			and z - r < box.Max.Z
		then
			return false
		end
	end
	local box = CFrame.new(x, y + prop.Height / 2 - 0.15, z)
	return #workspace:GetPartBoundsInBox(box, Vector3.new(r * 2, prop.Height + 0.6, r * 2), params) == 0
end
local function dress(model)
	local picks = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local look = MESH_LOOK[part.Name]
			if look then
				picks[part.Name] = picks[part.Name] or look[rng:NextInteger(1, #look)]
				part.Color = Color3.fromHex(picks[part.Name])
			end
		end
	end
end

local function put(kind, isle, x, z, folder)
	local prop = PROPS[kind]
	local y = groundY(isle)
	local model = kit[kind]:Clone()
	model:ScaleTo(model:GetScale() * rng:NextNumber(prop.Scale[1], prop.Scale[2]))
	model:PivotTo(CFrame.new(x, y - 0.05, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	dress(model)
	model.Parent = folder
	table.insert(placed, { Position = Vector3.new(x, y, z), Radius = prop.Radius })
	return model
end

-- Candidate spots: a 2-stud grid over each island's strips, shuffled with the seed.
local function candidates(isle)
	local list = {}
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, strip in floors[isle] do
		minX = math.min(minX, strip.Position.X - strip.Size.X / 2)
		maxX = math.max(maxX, strip.Position.X + strip.Size.X / 2)
		minZ = math.min(minZ, strip.Position.Z - strip.Size.Z / 2)
		maxZ = math.max(maxZ, strip.Position.Z + strip.Size.Z / 2)
	end
	for x = minX, maxX, 2 do
		for z = minZ, maxZ, 2 do
			table.insert(list, Vector2.new(x, z))
		end
	end
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

local function scatter(kind, isle, count, folder, filter)
	local prop, done = PROPS[kind], 0
	local y = groundY(isle)
	for _, spot in candidates(isle) do
		if done >= count then
			break
		end
		if
			onFloor(isle, spot.X, spot.Y, prop.Radius)
			and (not filter or filter(spot.X, spot.Y))
			and clear(spot.X, y, spot.Y, prop)
		then
			put(kind, isle, spot.X, spot.Y, folder)
			done += 1
		end
	end
	return done
end

local islandsFolder = Instance.new("Folder")
islandsFolder.Name = "Islands"
islandsFolder.Parent = decor
local report = {}
for isle, plan in ISLANDS do
	if not floors[isle] then
		continue
	end
	local folder = Instance.new("Folder")
	folder.Name = isle
	folder.Parent = islandsFolder
	local trees = 0
	for i = 1, plan.Trees do
		trees += scatter(if i % 2 == 1 then "TreeRound" else "TreePine", isle, 1, folder, plan.TreeSpot)
	end
	local bushes = scatter("Bush", isle, plan.Bush, folder, plan.Spot)
	local rocks = scatter("Rock", isle, plan.Rock, folder, plan.Spot)
	local clusters = 0
	for _ = 1, plan.FlowerClusters do
		if scatter("FlowerTuft", isle, 1, folder, plan.Spot) == 1 then
			clusters += 1
			-- One or two more tufts right beside the first.
			local first = placed[#placed].Position
			for _ = 1, rng:NextInteger(1, 2) do
				local a = rng:NextNumber(0, math.pi * 2)
				local x, z = first.X + math.cos(a) * 1.6, first.Z + math.sin(a) * 1.6
				if onFloor(isle, x, z, 0.8) and clear(x, first.Y, z, { Radius = 0.7, Margin = 0.1, Height = 2 }) then
					put("FlowerTuft", isle, x, z, folder)
				end
			end
		end
	end
	table.insert(
		report,
		string.format("%s trees=%d bushes=%d rocks=%d flowerClusters=%d", isle, trees, bushes, rocks, clusters)
	)
end

-- A few more clouds around the islands (clones of the existing SkyArt clouds) -------------------------------
local clouds = Instance.new("Folder")
clouds.Name = "Clouds"
clouds.Parent = decor
local skyArt = Lobby.GlassClashProps:FindFirstChild("SkyArt")
local sources = {}
for _, c in skyArt and skyArt:GetChildren() or {} do
	if c.Name:match("^Cloud") then
		table.insert(sources, c)
	end
end
local CLOUD_SPOTS = { -- x, y, z, scale
	{ 70, -18, 10, 1.1 },
	{ -72, -30, -15, 1.3 },
	{ 62, -34, -60, 0.9 },
	{ -66, -14, -120, 1.0 },
	{ 70, -24, -195, 1.2 },
	{ 18, -46, -40, 1.4 },
	{ -30, -44, -170, 1.2 },
}
for i, spot in CLOUD_SPOTS do
	local source = sources[(i - 1) % math.max(#sources, 1) + 1]
	if source then
		local cloud = source:Clone()
		cloud.Name = "Cloud" .. i
		if cloud:IsA("Model") then
			cloud:ScaleTo(cloud:GetScale() * spot[4])
			cloud:PivotTo(CFrame.new(spot[1], spot[2], spot[3]) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		end
		cloud.Parent = clouds
	end
end

-- Soft glints drifting over each island ------------------------------------------------------------------------
local glints = Instance.new("Folder")
glints.Name = "Glints"
glints.Parent = decor
for _, isle in Lobby.Islands:GetChildren() do
	local cf, size
	if isle:IsA("Model") then
		cf, size = isle:GetBoundingBox()
	elseif isle:IsA("BasePart") then
		cf, size = isle.CFrame, isle.Size
	else
		continue
	end
	local top = floors[isle.Name] and groundY(isle.Name) or (cf.Position.Y + size.Y / 2)
	local volume = Instance.new("Part")
	volume.Name = isle.Name .. "_Glints"
	volume.Anchored, volume.CanCollide, volume.CanTouch, volume.CanQuery = true, false, false, false
	volume.Transparency, volume.CastShadow = 1, false
	volume.Size = Vector3.new(size.X * 0.9, 10, size.Z * 0.9)
	volume.CFrame = CFrame.new(cf.Position.X, top + 6, cf.Position.Z)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Glints"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Shape, emitter.ShapeStyle = Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Volume
	emitter.Rate, emitter.Lifetime = 2.5, NumberRange.new(4, 6)
	emitter.Speed, emitter.SpreadAngle = NumberRange.new(0.2, 0.6), Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 0.15, 0)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Color3.fromHex("#BFF6FF"), Color3.fromHex("#FFD6F0"))
	emitter.LightEmission, emitter.LightInfluence = 0.8, 0
	emitter.RotSpeed = NumberRange.new(-30, 30)
	emitter.Parent = volume
	volume.Parent = glints
end

decor.Parent = Lobby
local parts = 0
for _, d in decor:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
table.insert(
	report,
	"decor parts=" .. parts .. ", clouds=" .. #clouds:GetChildren() .. ", glint volumes=" .. #glints:GetChildren()
)
return table.concat(report, "\n")
