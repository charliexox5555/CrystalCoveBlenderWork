-- Run in Play / Client through the MCP (workstream E, docs/testing/glassy_motion). Builds a client-side "fishbowl"
-- fixture flagged MotionVersion = 4 with placeholder parts at the manifest pivots; Play stop discards it. Then run
-- tools/studio/preview_power_vfx.luau with KIT = "fishbowl" to see the idle, Ready and cast motion in a fight scene.
local RS = game.ReplicatedStorage
local cfg = require(RS.Shared.Config.GlassyMotion).Glassies.fishbowl
local lib = RS.Assets.Glassies
if lib:FindFirstChild("fishbowl") then lib.fishbowl:Destroy() end
local m = Instance.new("Model")
m.Name = "fishbowl"
m:SetAttribute("MotionVersion", 4)
local function part(name, size, cf, color, shape)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Anchored, p.CanCollide, p.Material, p.Transparency = true, false, Enum.Material.SmoothPlastic, 0
	if shape then p.Shape = shape end
	return p
end
local body = part("Body", Vector3.one * 1.8, CFrame.new(0, -1.1, 0), Color3.fromHex("#5BC8FF"), Enum.PartType.Ball)
body.Material, body.Transparency = Enum.Material.Glass, 0.5
body.PivotOffset = CFrame.new(0, 1.1, 0)
body.Parent = m
local details = Instance.new("Folder")
details.Name = "Details"
details.Parent = m
local colors = { Fish = "#FF7A1F", FishTail = "#FFB067", WaterSurface = "#D6F4FF" }
for _, spec in cfg.Parts do
	local pivot = Vector3.new(spec.Pivot[1], spec.Pivot[2], spec.Pivot[3])
	-- Offset each placeholder a little from its pivot so rotation about the pivot is visible.
	local size = if spec.Name == "WaterSurface" then Vector3.new(1.4, 0.06, 1.4) else Vector3.one * 0.22
	local offset = if spec.Name == "Fish" then Vector3.new(0.45, 0, 0) elseif spec.Name == "FishTail" then Vector3.new(0.2, 0, 0) else Vector3.zero
	local p = part(spec.Name, size, CFrame.new(pivot + offset), Color3.fromHex(colors[spec.Name] or "#FFFFFF"))
	p.Parent = details
end
local shards = Instance.new("Folder")
shards.Name = "Shards"
shards.Parent = m
for i = 1, 4 do
	local s = part("Shard_" .. i, Vector3.one * 0.4, CFrame.new(0, -1.1, 0), body.Color)
	s.Parent = shards
end
m.Parent = lib
local names = {}
for _, spec in cfg.Parts do table.insert(names, spec.Name .. (spec.Follows and ("<" .. spec.Follows) or "")) end
return "fixture parts: " .. table.concat(names, ", ")
