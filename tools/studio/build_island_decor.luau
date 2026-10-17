-- Builds Workspace.IslandDecor: light set dressing on the arena and featured islands (never on the arenas,
-- paths or bridges). Per island: Blender crystal clusters (ServerStorage.LobbyKit.CrystalCluster) in the free
-- corners and two lantern posts (cloned from LobbyPolish) beside the lane. Each spot must have island floor
-- under it and nothing else within its radius, otherwise it is skipped. Refuses if IslandDecor exists
-- (set _G.IslandDecorRebuild = true to replace it).
assert(not game:GetService("RunService"):IsRunning(), "Build in Edit mode")
if workspace:FindFirstChild("IslandDecor") then
	if not _G.IslandDecorRebuild then
		return "IslandDecor already exists: nothing changed (set _G.IslandDecorRebuild = true to replace it)"
	end
	workspace.IslandDecor:Destroy()
end
_G.IslandDecorRebuild = nil
local crystal = assert(
	game.ServerStorage:FindFirstChild("LobbyKit") and game.ServerStorage.LobbyKit:FindFirstChild("CrystalCluster"),
	"Install the LobbyKit first"
)
local polish = workspace:FindFirstChild("LobbyPolish")
local lanternSource = polish and polish.Lanterns:FindFirstChildWhichIsA("Model")
local TINTS = { Color3.fromHex("9BF3F8"), Color3.fromHex("CDAAFF"), Color3.fromHex("86EDB8"), Color3.fromHex("FFD98A") }
local random = Random.new(77)

local root = Instance.new("Model")
root.Name = "IslandDecor"
root:SetAttribute("BuiltBy", "tools/studio/build_island_decor.luau")
local collision = workspace.Lobby:FindFirstChild("Collision")
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Lobby.Islands, collision }
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.FilterDescendantsInstances = { workspace.Lobby.Islands, collision, root, workspace.Terrain }

-- Floor height at (x, z) if it is island ground and the radius around it is free.
local function spot(x, z, radius)
	local hit = workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -100, 0), params)
	if not hit or math.abs(hit.Normal.Y) < 0.95 then
		return nil
	end
	local centre = hit.Position + Vector3.new(0, radius, 0)
	for _, p in workspace:GetPartBoundsInRadius(centre, radius, overlap) do
		if p.Transparency < 1 or p.CanCollide then
			return nil
		end
	end
	return hit.Position
end

local placed, skipped = 0, 0
for _, island in workspace.Lobby.Islands:GetChildren() do
	if island.Name == "Isle_Lobby" or not island:IsA("Model") then
		continue
	end
	local cf, size = island:GetBoundingBox()
	local cx, cz = cf.Position.X, cf.Position.Z
	local hx, hz = size.X / 2 - 7, size.Z / 2 - 6
	local group = Instance.new("Model")
	group.Name = island.Name
	group.Parent = root
	-- Corner crystal clusters (try a few offsets inward if the corner is busy or off the edge).
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		for step = 0, 4 do
			local x, z = cx + corner[1] * (hx - step * 2.5), cz + corner[2] * (hz - step * 1.5)
			local at = spot(x, z, 2.4)
			if at then
				local c = crystal:Clone()
				local scale = random:NextNumber(1.0, 1.5)
				c:ScaleTo(scale)
				c:PivotTo(CFrame.new(at) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0))
				c.Crystal_Glass.Color = TINTS[random:NextInteger(1, #TINTS)]
				c.Parent = group
				placed += 1
				break
			elseif step == 4 then
				skipped += 1
			end
		end
	end
	-- Two lanterns beside the lane through the middle of the island.
	if lanternSource then
		for _, side in { -1, 1 } do
			for _, dz in { 0, 3, -3, 6, -6 } do
				local at = spot(cx + side * 5.4, cz + dz, 0.8)
				if at then
					local l = lanternSource:Clone()
					l.Name = "Lantern"
					local bcf, bsize = l:GetBoundingBox()
					l:PivotTo(l:GetPivot() + (at - Vector3.new(bcf.X, bcf.Y - bsize.Y / 2, bcf.Z)))
					l.Parent = group
					placed += 1
					break
				end
			end
		end
	end
end
root.Parent = workspace
return string.format("IslandDecor: %d placed, %d corners skipped", placed, skipped)
