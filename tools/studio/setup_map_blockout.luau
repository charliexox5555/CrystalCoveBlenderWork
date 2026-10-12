-- Blender manifest bridge for an immediately walkable layout review.
-- Invoke returned function with begin, chunk, finish; pass parsed manifest data.
-- Visuals are explicitly temporary native-Part proxies until the FBX import.
local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name, f.Parent = name, parent
	return f
end

local function vector(a)
	return Vector3.new(a[1], a[2], a[3])
end

local function region(parent, name, position, size)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position = name, size, position
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Transparency, p.Parent = 1, parent
	return p
end

return function(operation, data)
	if operation == "begin" then
		assert(not workspace:FindFirstChild("Map"), "Map exists; inspect before running setup again")
		local map = folder(workspace, "Map")
		map:SetAttribute("Source", "Blender first_pass/manifest.json")
		map:SetAttribute("VisualImportPending", true)
		folder(map, "GlassTown")
		folder(map, "RecyclingYard")
		folder(map, "Markers")
		local baseplate = workspace:FindFirstChild("Baseplate")
		if baseplate then
			baseplate:SetAttribute("BeforeMapTransparency", baseplate.Transparency)
			baseplate:SetAttribute("BeforeMapCanCollide", baseplate.CanCollide)
			baseplate.Transparency, baseplate.CanCollide = 1, false
		end
		local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation")
		if spawn then
			spawn:SetAttribute("BeforeMapPosition", spawn.Position)
			spawn.CFrame = CFrame.new(0, 0.5, 122)
		end
		return "Map created; existing stand preserved"
	elseif operation == "chunk" then
		local map = assert(workspace:FindFirstChild("Map"))
		local parent = data.name == "glass_town" and map.GlassTown or map.RecyclingYard
		assert(not parent:FindFirstChild(data.name), "Chunk already exists")
		local model = Instance.new("Model")
		model.Name = data.name
		model:SetAttribute("BlenderChunk", "layout_" .. data.name .. ".fbx")
		model:SetAttribute("BlockoutProxy", true)
		for _, row in data.proxies do
			local p = Instance.new("Part")
			p.Name, p.Size = row.name, vector(row.size)
			p.CFrame = CFrame.new(vector(row.position)) * CFrame.Angles(0, row.yaw, 0)
			if row.shape == "Cylinder" then
				p.Shape = Enum.PartType.Cylinder
				p.Size = Vector3.new(row.size[2], row.size[1], row.size[3])
				p.CFrame *= CFrame.Angles(0, 0, math.pi / 2)
			elseif row.shape == "Ball" then
				p.Shape = Enum.PartType.Ball
			end
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, row.collision, false, row.collision
			p.Color, p.Material, p.Reflectance = Color3.fromHex(row.color), Enum.Material.SmoothPlastic, 0
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.Parent = model
		end
		model.Parent = parent
		task.wait()
		return { Chunk = data.name, Parts = #data.proxies }
	elseif operation == "finish" then
		local map = assert(workspace:FindFirstChild("Map"))
		assert(#map.Markers:GetChildren() == 0, "Markers already created")
		local tags = game:GetService("CollectionService")
		local template = game.ReplicatedStorage.Assets.ClashStand
		for _, row in data.markers do
			local p = region(map.Markers, row.name, vector(row.position), Vector3.one)
			p:SetAttribute("Kind", row.kind)
			p:SetAttribute("Planned", row.active ~= true)
			if row.zone then
				p:SetAttribute("Zone", row.zone)
			end
			if row.kind == "Stand" and not row.active then
				local stand = template:Clone()
				stand.Name = "Stand_" .. row.name
				stand:PivotTo(CFrame.new(p.Position))
				stand:SetAttribute("TrainerId", row.name)
				stand:SetAttribute("GameplayPending", true)
				local floor = Instance.new("Part")
				floor.Name, floor.Size = "WalkableFloor", Vector3.new(25, 0.5, 25)
				floor.CFrame = CFrame.new(p.Position + Vector3.new(0, -0.15, 0))
				floor.Anchored, floor.Transparency, floor.CanTouch = true, 1, false
				floor.Parent = stand
				stand.Parent = row.name:sub(1, 4) == "pvp_" and map.GlassTown or map.RecyclingYard
			elseif row.kind == "Trainer" then
				p:SetAttribute("TrainerId", row.name)
				tags:AddTag(p, "TrainerMarker")
			elseif row.kind == "WildRegion" then
				p.Size = vector(row.size)
				tags:AddTag(p, "WildSpawnRegion")
			elseif row.kind == "Repair" then
				tags:AddTag(p, "RepairBenchMarker")
			elseif row.kind == "Label" then
				local gui = Instance.new("BillboardGui")
				gui.Name, gui.Size, gui.MaxDistance = "MapLabel", UDim2.fromOffset(200, 48), 85
				gui.LightInfluence, gui.AlwaysOnTop = 0, false
				gui.Parent = p
				local title = Instance.new("TextLabel")
				title.Size, title.BackgroundTransparency = UDim2.fromScale(1, 0.6), 1
				title.Text, title.Font, title.TextSize = row.name, Enum.Font.MontserratBold, 16
				title.TextColor3, title.TextStrokeTransparency = Color3.fromRGB(242, 246, 235), 0.4
				title.Parent = gui
				local sub = title:Clone()
				sub.Name, sub.Position, sub.Size = "Subtitle", UDim2.fromScale(0, 0.6), UDim2.fromScale(1, 0.4)
				sub.Text, sub.Font, sub.TextSize = row.subtitle or "", Enum.Font.MontserratMedium, 11
				sub.Parent = gui
			end
		end
		map:SetAttribute("RouteLength", data.routeLength)
		map:SetAttribute("PathWidth", data.pathWidth)
		map:SetAttribute("SetupComplete", true)
		return { Markers = #data.markers, RouteLength = data.routeLength, VisualImportPending = true }
	end
	error("Unknown map setup operation")
end
