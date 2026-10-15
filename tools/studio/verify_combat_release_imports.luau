-- Independent native invariants for the staged imported art. No gameplay claims.
return function(manifest)
	local SS = game:GetService("ServerStorage")
	local staged = SS.CombatReleaseStaged
	local checks, parts, shards, maxError = 0, 0, 0, 0
	local function check(value, message)
		assert(value, message)
		checks += 1
	end
	check(#staged.Glassies:GetChildren() == 24, "Release count")
	check(#staged.VFX.Textures:GetChildren() == 8, "Texture count")
	for id, data in manifest.assets do
		local model = if id == "combat_vfx" then staged.VFX.combat_vfx else staged.Glassies[id]
		check(model:GetScale() == 1, "Canonical source scale")
		check(model:GetPivot().Position.Magnitude < 0.001, "Model hang origin")
		check(not model:GetAttribute("LiveKitValidated"), "Do not claim live kit proof")
		if id ~= "combat_vfx" then
			check(model.PrimaryPart == model.Body, "Primary body")
			check(#model.Shards:GetChildren() == 16, "Shard count")
		end
		local count = 0
		for _, entry in data.meshes do
			local p = model:FindFirstChild(entry.source_name, true)
			check(p and p:IsA("MeshPart"), "Missing native mesh")
			check(p.MeshId ~= "", "Persistent MeshId")
			check(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery, "Unsafe part flags")
			check(p:GetPivot().Position.Magnitude < 0.001, "Aligned part pivot")
			check(p.Color == Color3.fromHex(entry.color), "Recolorable part tint")
			check(p.Material == Enum.Material[entry.material], "Native material")
			check(p:GetAttribute("AssetRole") == entry.role, "Role")
			local a, b = entry.bounds_blender[1], entry.bounds_blender[2]
			local low, high = Vector3.new(a[1], a[3], -b[2]), Vector3.new(b[1], b[3], -a[2])
			local actualLow, actualHigh = Vector3.one * math.huge, Vector3.one * -math.huge
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local v = p.CFrame:PointToWorldSpace(p.Size * Vector3.new(x, y, z) / 2)
						actualLow, actualHigh = actualLow:Min(v), actualHigh:Max(v)
					end
				end
			end
			local error = math.max((actualLow - low).Magnitude, (actualHigh - high).Magnitude)
			maxError = math.max(maxError, error)
			check(error < 0.001, "Source/native geometry bounds")
			if entry.role == "Shard" then
				shards += 1
			end
			count += 1
			parts += 1
		end
		local actualCount = 0
		for _, p in model:GetDescendants() do
			check(not p:IsA("LuaSourceContainer"), "Embedded script")
			if p:IsA("BasePart") then
				actualCount += 1
			end
		end
		check(actualCount == count, "No extra native parts")
		task.wait()
	end
	local rawParts, unanchored = 0, 0
	for _, p in SS.CombatReleaseImports:GetDescendants() do
		if p:IsA("BasePart") then
			rawParts += 1
			if not p.Anchored then
				unanchored += 1
			end
		end
	end
	check(rawParts == 527 and unanchored == 0, "All creator imports anchored")
	local preserved = 0
	for _, p in SS.CombatReleaseBackups.RawBeforeNormalization_20261015:GetDescendants() do
		if p:IsA("BasePart") then
			preserved += 1
		end
	end
	check(preserved == rawParts, "Raw originals preserved")
	check(shards == 384, "24 aligned shard sets")
	for key, id in manifest.textures do
		check(staged.VFX.Textures[key].Texture == id, "Recorded texture reference")
	end
	return {
		checks = checks,
		canonicalParts = parts,
		shards = shards,
		creatorImportParts = rawParts,
		unanchored = unanchored,
		maxBoundsError = maxError,
		liveKitTest = false,
	}
end
