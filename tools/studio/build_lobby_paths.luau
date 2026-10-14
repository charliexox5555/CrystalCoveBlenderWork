-- Polish pass (2026-10-14): matte stepping-stone walkway for wayfinding on Crystal Isles.
-- Run once in Edit mode through the Studio MCP. Refuses to run if Workspace.Lobby.Paths exists, so it
-- never rebuilds over manual edits. Delete that folder to remove the path entirely.
--
-- * Centre lane (X = 0) from spawn across every island to the featured stage, between the bridges.
-- * Short spurs from the lane to each arena's two queue pads (A blue / B orange) so the route reads
--   "walk here -> glowing pad".
-- Stones are low-poly, matte SmoothPlastic, non-colliding, no shadows/queries: purely visual, so walking,
-- pads and fall recovery are unchanged. Deterministic (fixed seed). ~180 Parts.

local lobby = workspace:WaitForChild("Lobby")
assert(not lobby:FindFirstChild("Paths"), "Lobby.Paths already exists; refusing to rebuild over manual edits")

local rng = Random.new(20261014)
local colors = { "#CFC6B4", "#C4BAA6", "#D9D1C2", "#BDB3A0" }
local THICKNESS, LIFT = 0.14, 0.015

local root = Instance.new("Folder")
root.Name = "Paths"

local function stone(parent: Instance, x: number, y: number, z: number, w: number, d: number, yaw: number)
	local p = Instance.new("Part")
	p.Name = "PathStone"
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Material, p.Color = Enum.Material.SmoothPlastic, Color3.fromHex(colors[rng:NextInteger(1, #colors)])
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Size = Vector3.new(w, THICKNESS, d)
	p.CFrame = CFrame.new(x, y + THICKNESS / 2 + LIFT, z) * CFrame.Angles(0, yaw, 0)
	p.Parent = parent
end

-- Centre lane: staggered pairs of stones about 6 studs wide.
local function lane(name: string, y: number, zStart: number, zEnd: number)
	local model = Instance.new("Model")
	model.Name = name
	local row = 0
	for z = zStart, zEnd, -3.1 do
		local stagger = if row % 2 == 0 then 0.35 else -0.35
		for _, x in { -1.55, 1.55 } do
			stone(
				model,
				x + rng:NextNumber(-0.25, 0.25),
				y,
				z + stagger * math.sign(x) + rng:NextNumber(-0.2, 0.2),
				rng:NextNumber(2.5, 2.95),
				rng:NextNumber(2.2, 2.65),
				rng:NextNumber(-0.16, 0.16)
			)
		end
		row += 1
	end
	model.Parent = root
	return model
end

-- Single-file spur from the lane edge to a pad, stopping just short of the pad rim.
local function spur(parent: Instance, y: number, z: number, toX: number)
	local dir = math.sign(toX)
	for x = 3.7, math.abs(toX) - 3.6, 3.2 do
		stone(
			parent,
			dir * x + rng:NextNumber(-0.15, 0.15),
			y,
			z + rng:NextNumber(-0.25, 0.25),
			rng:NextNumber(2.3, 2.7),
			rng:NextNumber(2.1, 2.5),
			rng:NextNumber(-0.18, 0.18)
		)
	end
end

lane("LobbyLane", 0, 8, -25)
lane("FeaturedLane", 9, -184, -190)

-- Arena islands: lane between the bridges, spurs to both pads of both stands, taken from the real pads.
local islands = {
	{ Name = "Arena1Lane", Y = 2, From = -35, To = -76, Arenas = { 1, 2 } },
	{ Name = "Arena2Lane", Y = 4, From = -85, To = -126, Arenas = { 3, 4 } },
	{ Name = "Arena3Lane", Y = 6, From = -135, To = -175, Arenas = { 5, 6 } },
}
for _, island in islands do
	local model = lane(island.Name, island.Y, island.From, island.To)
	for _, id in island.Arenas do
		local arena = lobby.Arenas:FindFirstChild("Arena" .. id)
		for _, padName in { "QueueA", "QueueB" } do
			local pad = arena and arena:FindFirstChild(padName)
			if pad then
				spur(model, island.Y, pad.Position.Z, pad.Position.X)
			end
		end
	end
end

root.Parent = lobby
local count = 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
return "built Lobby.Paths with " .. count .. " stones"
