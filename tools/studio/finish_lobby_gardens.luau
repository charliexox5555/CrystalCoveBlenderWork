-- Original faceted foliage and gate pennants, kept outside functional paths/courts.
assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local root = workspace.Lobby.NightPolishV1
assert(not root:FindFirstChild("GardenTrees"), "Trees already installed")
local trees = Instance.new("Model")
trees.Name, trees.Parent = "GardenTrees", root
local function p(name, size, cf, color, class)
	local part = Instance.new(class or "Part")
	part.Name, part.Size, part.CFrame = name, size, cf
	part.Color, part.Material = Color3.fromHex(color), Enum.Material.SmoothPlastic
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
	part.Parent = trees
	return part
end
for i, pos in { Vector3.new(-40, 0, -14), Vector3.new(39, 0, -14), Vector3.new(-39, 0, 13), Vector3.new(39, 0, 13) } do
	p("Trunk", Vector3.new(0.85, 5, 0.85), CFrame.new(pos + Vector3.yAxis * 2.5), "#80634C")
	for tier = 1, 3 do
		local width = 6.2 - tier * 1.2
		local base = pos + Vector3.yAxis * (3 + tier * 1.35)
		for _, side in { -1, 1 } do
			p(
				"CanopyFacet",
				Vector3.new(width, 2.5, width / 2),
				CFrame.new(base + Vector3.new(0, 0, side * width / 4))
					* CFrame.Angles(0, if side < 0 then math.pi else 0, 0),
				if tier % 2 == 0 then "#71A383" else "#528B78",
				"WedgePart"
			)
		end
	end
	p(
		"TreeBed",
		Vector3.new(4.2, 0.35, 4.2),
		CFrame.new(pos + Vector3.yAxis * 0.18) * CFrame.Angles(0, 0.3, 0),
		"#9FAD8D"
	)
end
for _, x in { -6.6, 6.6 } do
	p("Pennant", Vector3.new(1.6, 3, 0.16), CFrame.new(x, 7.3, -21.7), if x < 0 then "#64B8BE" else "#A394CC")
	p(
		"PennantTip",
		Vector3.new(1.6, 0.8, 0.16),
		CFrame.new(x, 5.4, -21.7) * CFrame.Angles(0, 0, math.pi / 4),
		"#E5CD9B",
		"WedgePart"
	)
end
return { Trees = 4, Parts = #trees:GetChildren() }
