-- Edit mode (Studio MCP), with tools/studio/flyer_effects.luau prepended. Builds ReplicatedStorage.Assets.RideStand:
-- the faint glass hover pad a player stands on in matches when no flyer is equipped (decision 95). MatchStage uses
-- it in place of a flyer (RideId/PoseId "stand"); RideController/RidePose treat it like any ride (Stand family).
-- Pivot = the top of the pad, where the feet go. Not a catalog item; replaces any earlier RideStand.
assert(not game:GetService("RunService"):IsRunning(), "Install in Edit")
local RS = game:GetService("ReplicatedStorage")
local old = RS.Assets:FindFirstChild("RideStand")
if old then
	old:Destroy()
end
local model = Instance.new("Model")
model.Name = "RideStand"
local function disc(name, diameter, thick, y, color, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(thick, diameter, diameter)
	p.CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90))
	p.Color, p.Material, p.Transparency = Color3.fromHex(color), material, transparency
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Parent = model
	return p
end
local pad = disc("Pad", 2.8, 0.08, -0.05, "#BFF3FF", Enum.Material.Glass, 0.55)
local ring = disc("Ring", 3.0, 0.04, -0.09, "#9FE3FF", Enum.Material.Neon, 0.6)
ring:SetAttribute("RideMotion", "Pulse")
local shimmer = Instance.new("Attachment")
shimmer.Name = "Shimmer"
shimmer.CFrame = pad.CFrame:ToObjectSpace(CFrame.new(0, -0.05, 0))
shimmer.Parent = pad
local feet = Instance.new("Attachment")
feet.Name = "RiderFeet"
feet.CFrame = pad.CFrame:ToObjectSpace(CFrame.new())
feet.Parent = pad
pad.PivotOffset = pad.CFrame:Inverse()
model.PrimaryPart = pad
EFFECTS.stand(model, { Shimmer = shimmer })
model:SetAttribute("RideId", "stand")
model:SetAttribute("PoseId", "stand")
model:SetAttribute("OriginalGlassClash", true)
model.Parent = RS.Assets
return #model:GetDescendants()
