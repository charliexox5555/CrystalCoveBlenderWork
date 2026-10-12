-- Run in Edit through MCP with manifest.exports as the argument.
-- Preserves raw imports and all temporary visuals before organizing final meshes.
return function(exports)
	local map = assert(workspace:FindFirstChild("Map"), "Create walkable layout first")
	assert(map:GetAttribute("VisualImportPending"), "Detailed visuals already installed")
	local imports = {}
	for _, chunk in exports do
		local model = assert(workspace:FindFirstChild("layout_" .. chunk.chunk), chunk.file)
		local n = 0
		for _, part in model:GetDescendants() do
			if part:IsA("MeshPart") then
				n += 1
			end
		end
		assert(n == chunk.meshes, "Unexpected mesh count: " .. chunk.chunk)
		for _, row in chunk.parts do
			local p = assert(model:FindFirstChild(row.name, true), row.name)
			assert(p:IsA("MeshPart"), "Expected imported mesh: " .. row.name)
			local ratio = p.Size.X / row.size[1]
			assert(math.abs(p.Size.Y / row.size[2] - ratio) < 0.005, "Nonuniform Y scale: " .. row.name)
			assert(math.abs(p.Size.Z / row.size[3] - ratio) < 0.005, "Nonuniform Z scale: " .. row.name)
		end
		imports[chunk.chunk] = model
	end
	local SS = game:GetService("ServerStorage")
	assert(not SS:FindFirstChild("MapImportedSources"), "Inspect previous backups first")
	local originals = Instance.new("Folder")
	originals.Name, originals.Parent = "MapImportedSources", SS
	local proxies = Instance.new("Folder")
	proxies.Name, proxies.Parent = "MapBlockoutVisuals", SS
	local visuals = {}
	for _, parent in { map.GlassTown, map.RecyclingYard } do
		local f = Instance.new("Folder")
		f.Name, f.Parent = "Visuals", parent
		visuals[parent] = f
	end
	local report = {}
	for _, chunk in exports do
		local model = imports[chunk.chunk]
		model:Clone().Parent = originals
		local reference = model:FindFirstChild(chunk.parts[1].name, true)
		local importScale = reference.Size.X / chunk.parts[1].size[1]
		for _, row in chunk.parts do
			local p = model:FindFirstChild(row.name, true)
			p.Size = Vector3.new(table.unpack(row.size))
			-- FBX imported with both horizontal axes reversed; same correction as M1.
			p.PivotOffset = CFrame.identity
			p.CFrame = CFrame.new(Vector3.new(table.unpack(row.position))) * CFrame.Angles(0, math.pi, 0)
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
			p.TextureID, p.Reflectance, p.Transparency = "", 0, 0
			p.Color, p.Material = Color3.fromHex(row.color), Enum.Material.SmoothPlastic
			p.RenderFidelity = Enum.RenderFidelity.Automatic
			p:SetAttribute("BlenderColor", row.color)
		end
		local parent = chunk.chunk == "glass_town" and map.GlassTown or map.RecyclingYard
		model.Name, model.WorldPivot = chunk.chunk, CFrame.identity
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		model:SetAttribute("SourceFBX", chunk.file)
		model.Parent = visuals[parent]
		local blockout = assert(parent:FindFirstChild(chunk.chunk))
		local stash = Instance.new("Folder")
		stash.Name, stash.Parent = chunk.chunk, proxies
		local collisionCount = 0
		for _, part in blockout:GetChildren() do
			if part:IsA("BasePart") then
				if part.CanCollide then
					part.Transparency, part.CastShadow = 1, false
					collisionCount += 1
				else
					part.Parent = stash
				end
			end
		end
		blockout:SetAttribute("CollisionOnly", true)
		table.insert(
			report,
			{ Chunk = chunk.chunk, ImportedScale = importScale, Meshes = chunk.meshes, Colliders = collisionCount }
		)
		task.wait()
	end
	map:SetAttribute("VisualImportPending", false)
	map:SetAttribute("DetailedMeshCount", 128)
	return report
end
