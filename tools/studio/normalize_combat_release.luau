-- Run in Studio Edit with the generated release import-data table.
-- Preserve raw originals; normalize the creator's imports and stage canonical assets.
return function(manifest)
	assert(not game:GetService("RunService"):IsRunning(), "Use Edit mode")
	local storage = game:GetService("ServerStorage")
	local imports = assert(storage:FindFirstChild("CombatReleaseImports"), "Missing imports")
	if imports:GetAttribute("ReleaseV2Normalized") then
		return { AlreadyNormalized = true, Path = "ServerStorage.CombatReleaseStaged" }
	end
	local correction = CFrame.Angles(0, math.pi, 0)
	local function bounds(entry)
		local a, b = entry.bounds_blender[1], entry.bounds_blender[2]
		return Vector3.new(a[1], a[3], -b[2]), Vector3.new(b[1], b[3], -a[2])
	end
	local function actualBounds(part)
		local low, high = Vector3.one * math.huge, Vector3.one * -math.huge
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					local p = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) / 2)
					low, high = low:Min(p), high:Max(p)
				end
			end
		end
		return low, high
	end
	local sources, duplicates, total = {}, {}, 0
	-- Validate every source first, before changing any object.
	for _, model in imports:GetChildren() do
		local id = model.Name:gsub("_bundle$", "")
		local data = manifest.assets[id]
		if data then
			assert(model:IsA("Model"), model.Name .. " must be a Model")
			local found = {}
			for _, p in model:GetDescendants() do
				assert(not p:IsA("LuaSourceContainer"), "Unexpected script in import")
				if p:IsA("BasePart") then
					assert(p:IsA("MeshPart") and p.MeshId ~= "", "Invalid imported mesh")
					assert(not found[p.Name], "Duplicate mesh name within " .. model.Name)
					found[p.Name] = p
				end
			end
			local count = 0
			for _, entry in data.meshes do
				local p = assert(found[entry.name], "Missing " .. id .. "/" .. entry.name)
				local low, high = bounds(entry)
				local expected = high - low
				local imported = p.Size / 100
				assert((imported - expected).Magnitude < 0.001, "Unexpected import scale: " .. id .. "/" .. p.Name)
				count += 1
			end
			local actual = 0
			for _ in found do
				actual += 1
			end
			assert(count == actual, "Unexpected extra mesh in " .. model.Name)
			if sources[id] then
				table.insert(duplicates, model.Name)
			else
				sources[id] = model
			end
			total += actual
		end
	end
	for id in manifest.assets do
		assert(sources[id], "Missing bundle " .. id)
	end
	local backups = storage:FindFirstChild("CombatReleaseBackups") or Instance.new("Folder")
	backups.Name, backups.Parent = "CombatReleaseBackups", storage
	assert(not backups:FindFirstChild("RawBeforeNormalization_20261015"), "Backup already exists")
	local backup = Instance.new("Folder")
	backup.Name, backup.Parent = "RawBeforeNormalization_20261015", backups
	for _, model in imports:GetChildren() do
		model:Clone().Parent = backup
		task.wait()
	end
	local staged = Instance.new("Folder")
	staged.Name = "CombatReleaseStaged"
	assert(not storage:FindFirstChild(staged.Name), "Staging folder already exists")
	staged.Parent = storage
	local glassies, vfx = Instance.new("Folder"), Instance.new("Folder")
	glassies.Name, glassies.Parent = "Glassies", staged
	vfx.Name, vfx.Parent = "VFX", staged
	local report =
		{ assets = {}, duplicateBundlesPreserved = duplicates, normalizedParts = 0, rawBackup = backup:GetFullName() }
	for _, model in imports:GetChildren() do
		local id = model.Name:gsub("_bundle$", "")
		local data = manifest.assets[id]
		if not data then
			continue
		end
		-- FBX import retained a common hang pivot and baked a 180-degree yaw.
		model:ScaleTo(model:GetScale() * 0.01)
		model:PivotTo(correction)
		local entries = {}
		for _, entry in data.meshes do
			entries[entry.name] = entry
		end
		for _, p in model:GetDescendants() do
			if not p:IsA("MeshPart") then
				continue
			end
			local entry = entries[p.Name]
			local low, high = bounds(entry)
			-- Exact manifest centres remove the tiny FBX pivot roundoff at large import coordinates.
			p.CFrame = CFrame.new((low + high) / 2) * p.CFrame.Rotation
			p.PivotOffset = p.CFrame:Inverse()
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
			p.Massless, p.CastShadow = true, false
			p.Material, p.Color = Enum.Material[entry.material], Color3.fromHex(entry.color)
			p.Transparency = if entry.role == "Shard" then 1 elseif entry.material == "Glass" then 0.28 else 0
			p.Reflectance = if entry.material == "Glass" then 0.15 else 0
			p:SetAttribute("SourceName", entry.source_name)
			p:SetAttribute("AssetRole", entry.role)
			p:SetAttribute("EffectOnly", entry.effect_only or false)
			local a, b = actualBounds(p)
			assert(
				math.max((a - low).Magnitude, (b - high).Magnitude) < 0.001,
				"Normalized bounds failed: " .. id .. "/" .. p.Name
			)
			report.normalizedParts += 1
		end
		model.WorldPivot = CFrame.identity
		model:SetAttribute("ReleaseV2Normalized", true)
		model:SetAttribute("SourceImportScale", 100)
		if sources[id] ~= model then
			task.wait()
			continue
		end
		local canonical = Instance.new("Model")
		canonical.Name, canonical.WorldPivot = id, CFrame.identity
		local shards, details
		if id ~= "combat_vfx" then
			shards, details = Instance.new("Folder"), Instance.new("Folder")
			shards.Name, shards.Parent = "Shards", canonical
			details.Name, details.Parent = "Details", canonical
		end
		local row = { path = "", meshes = {}, maxBoundsError = 0, parts = 0, shards = 0, originalImportScale = 100 }
		for _, entry in data.meshes do
			local source = assert(model:FindFirstChild(entry.name, true))
			local p = source:Clone()
			p.Name = entry.source_name
			p.Transparency = if entry.material == "Glass" then 0.28 else 0
			p.Parent = if entry.role == "Shard" then shards elseif entry.role == "Detail" then details else canonical
			if entry.role == "Body" then
				canonical.PrimaryPart = p
			end
			if entry.role == "Shard" then
				row.shards += 1
			end
			if entry.animation_pivot then
				p:SetAttribute(
					"AnimationPivot",
					Vector3.new(entry.animation_pivot[1], entry.animation_pivot[3], -entry.animation_pivot[2])
				)
			end
			row.parts += 1
			local a, b = actualBounds(p)
			local low, high = bounds(entry)
			row.maxBoundsError = math.max(row.maxBoundsError, (a - low).Magnitude, (b - high).Magnitude)
			row.meshes[entry.source_name] =
				{ meshId = p.MeshId, rawName = entry.name, role = entry.role, size = { p.Size.X, p.Size.Y, p.Size.Z } }
		end
		canonical:SetAttribute("ReleaseVersion", 2)
		canonical:SetAttribute("NativeImportValidated", true)
		canonical:SetAttribute("LiveKitValidated", false)
		canonical.Parent = if id == "combat_vfx" then vfx else glassies
		row.path = canonical:GetFullName()
		assert(canonical:GetPivot().Position.Magnitude < 0.001, "Hang pivot failed")
		if id ~= "combat_vfx" then
			assert(row.shards == 16 and canonical.PrimaryPart, "Incomplete canonical glassy")
		end
		report.assets[id] = row
		task.wait()
	end
	local textures = Instance.new("Folder")
	textures.Name, textures.Parent = "Textures", vfx
	for name, id in manifest.textures do
		local decal = Instance.new("Decal")
		decal.Name, decal.Texture, decal.Parent = name, id, textures
		decal:SetAttribute("OriginalCombatReleaseTexture", true)
	end
	imports:SetAttribute("ReleaseV2Normalized", true)
	staged:SetAttribute("ReleaseCount", 24)
	staged:SetAttribute("PreviewOnly", true)
	staged:SetAttribute("LiveCatalogChanged", false)
	assert(report.normalizedParts == total)
	return report
end
