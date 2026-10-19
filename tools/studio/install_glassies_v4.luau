-- v4 glassy installer (docs/art/IMPORT_RUNBOOK.md). Edit mode only, through the Studio MCP, under the Studio lock.
-- Do not run this file alone: tools/studio/glassy_install_chunk.py prepends the DATA and OPTIONS tables
-- (asset ids from the Open Cloud Record + every part's manifest centre/size/colour/material/pivot/motion).
--
-- OPTIONS.Mode:
--   "dry"     loads each uploaded model (or a RawPath test source), fits it and checks it, then throws the
--             result away. Writes nothing to the DataModel.
--   "install" same fit and checks, then: keeps the raw insert in ServerStorage.<Import>, backs up the current
--             ReplicatedStorage.Assets.Glassies.<id> to ServerStorage.<Backup> (once, never overwritten), and
--             installs the rebuilt model at the same path with the release template layout
--             (Body MeshPart + Details folder + Shards folder, part attributes as normalize_combat_release.luau).
--             Idempotent: a model already at ArtVersion with the same SourceAsset is left alone (OPTIONS.Force redoes it).
--   "verify"  compares the installed models with DATA (names, roles, counts, bounds, pivots, geometry).
-- The raw import's scale and orientation are fitted, not assumed: scale from the Body size, rotation by trying
-- all 24 axis rotations against the manifest part centres (the creator's FBX imports came in 100x with a baked
-- 180 degree yaw; Open Cloud model conversion may differ). Every placed part must match its manifest bounds.
assert(not game:GetService("RunService"):IsRunning(), "Install in Edit mode (stop Play first)")
assert(type(DATA) == "table" and type(OPTIONS) == "table", "Run through glassy_install_chunk.py (DATA/OPTIONS missing)")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local MODE = OPTIONS.Mode or "dry"
assert(MODE == "dry" or MODE == "install" or MODE == "verify", "Mode must be dry, install or verify")
local VERSION = OPTIONS.Version or "v4"
local TOL = OPTIONS.Tolerance or 0.003
local okGeometry, Geometry = pcall(require, RS.Shared.Config.ReleaseGeometry)
if not okGeometry then
	Geometry = {}
end

local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end
local function resolve(path)
	local node
	for i, name in string.split(path, ".") do
		node = if i == 1 then game:GetService(name) else node and node:FindFirstChild(name)
	end
	return node
end
-- OPTIONS.Library (a DataModel path) installs somewhere else, for testing; default is the live template library.
local library = if OPTIONS.Library then assert(resolve(OPTIONS.Library), "Library not found") else RS.Assets.Glassies
local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name, f.Parent = name, parent
	end
	return f
end
local function aabb(part)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local p = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) / 2)
				lo, hi = lo:Min(p), hi:Max(p)
			end
		end
	end
	return lo, hi
end
local ROTATIONS = {}
do
	local axes = { Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis }
	for _, x in axes do
		for _, y in axes do
			if math.abs(x:Dot(y)) < 0.5 then
				table.insert(ROTATIONS, CFrame.fromMatrix(Vector3.zero, x, y, x:Cross(y)))
			end
		end
	end
end

local function rawFor(id, entry)
	if entry.RawPath then
		local src = assert(resolve(entry.RawPath), "RawPath not found: " .. entry.RawPath)
		return src:Clone(), "RawPath " .. entry.RawPath
	end
	assert(entry.AssetId, id .. ": no AssetId in the Record (upload first)")
	local cache = SS:FindFirstChild(OPTIONS.Import or "GlassyV4Import")
	local cached = cache and cache:FindFirstChild(id)
	if cached and cached:GetAttribute("AssetId") == entry.AssetId then
		return cached:Clone(), "cached import"
	end
	local objects = game:GetObjects("rbxassetid://" .. tostring(entry.AssetId))
	assert(#objects >= 1, id .. ": asset " .. tostring(entry.AssetId) .. " returned nothing")
	local raw = objects[1]
	if #objects > 1 or not raw:IsA("Model") then
		local m = Instance.new("Model")
		for _, o in objects do
			o.Parent = m
		end
		raw = m
	end
	raw.Name = id
	raw:SetAttribute("AssetId", entry.AssetId)
	if MODE == "install" then
		local keep = raw:Clone()
		keep.Parent = folder(SS, OPTIONS.Import or "GlassyV4Import")
		if cached then
			cached:Destroy()
		end
	end
	return raw, "asset " .. tostring(entry.AssetId)
end

local function build(id, entry)
	local raw, source = rawFor(id, entry)
	for _, d in raw:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), id .. ": unexpected script in the import")
	end
	local parts, extra = {}, {}
	local want = {}
	for _, p in entry.Parts do
		want[p.Name] = p
	end
	for _, d in raw:GetDescendants() do
		if d:IsA("MeshPart") then
			if want[d.Name] and not parts[d.Name] then
				parts[d.Name] = d
			else
				table.insert(extra, d.Name)
			end
		end
	end
	local missing = {}
	for _, p in entry.Parts do
		if not parts[p.Name] then
			table.insert(missing, p.Name)
		end
	end
	assert(#missing == 0, id .. ": import is missing " .. table.concat(missing, ", "))
	local bodyEntry
	for _, p in entry.Parts do
		if p.Role == "Body" then
			bodyEntry = p
		end
	end
	local rawBody = parts[bodyEntry.Name]
	local scale = v3(bodyEntry.Size).Magnitude / rawBody.Size.Magnitude
	local best, bestErr = nil, math.huge
	for _, rot in ROTATIONS do
		local err = 0
		for _, p in entry.Parts do
			local rel = (parts[p.Name].Position - rawBody.Position) * scale
			err += ((rot * rel) - (v3(p.Center) - v3(bodyEntry.Center))).Magnitude
		end
		if err < bestErr then
			best, bestErr = rot, err
		end
	end
	local meanErr = bestErr / #entry.Parts
	assert(
		meanErr < 0.01 * v3(bodyEntry.Size).Magnitude,
		string.format("%s: no axis rotation fits (mean error %.4f)", id, meanErr)
	)
	local model = Instance.new("Model")
	model.Name = id
	model.WorldPivot = CFrame.identity
	local details, shards = Instance.new("Folder"), Instance.new("Folder")
	details.Name, details.Parent = "Details", model
	shards.Name, shards.Parent = "Shards", model
	local maxBounds, counts = 0, { Body = 0, Detail = 0, Shard = 0 }
	for _, p in entry.Parts do
		local src = parts[p.Name]
		local part = src:Clone()
		for _, child in part:GetChildren() do
			child:Destroy()
		end
		part.Name = p.Source
		part.Size = src.Size * scale
		part.CFrame = CFrame.new(v3(p.Center)) * best * src.CFrame.Rotation
		part.PivotOffset = part.CFrame:Inverse()
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
		part.Massless, part.CastShadow = true, false
		part.Material, part.Color = Enum.Material[p.Material], Color3.fromHex(p.Color)
		part.Transparency = p.Transparency
		part.Reflectance = if p.Material == "Glass" then 0.15 else 0
		part:SetAttribute("SourceName", p.Source)
		part:SetAttribute("AssetRole", p.Role)
		part:SetAttribute("EffectOnly", p.EffectOnly)
		part:SetAttribute("AnimationPivot", v3(p.Pivot))
		if p.Motion then
			part:SetAttribute("MotionJson", p.Motion)
		end
		local lo, hi = aabb(part)
		local half = v3(p.Size) / 2
		local err = math.max((lo - (v3(p.Center) - half)).Magnitude, (hi - (v3(p.Center) + half)).Magnitude)
		maxBounds = math.max(maxBounds, err)
		assert(
			err < TOL + 0.002 * v3(p.Size).Magnitude,
			string.format("%s/%s: bounds off by %.4f after fitting", id, p.Source, err)
		)
		counts[p.Role] += 1
		part.Parent = if p.Role == "Shard" then shards elseif p.Role == "Detail" then details else model
		if p.Role == "Body" then
			model.PrimaryPart = part
		end
	end
	assert(counts.Body == 1 and counts.Shard >= 12, id .. ": needs one Body and 12+ shards")
	local lo, hi = aabb(model.PrimaryPart)
	local measured = { Radius = math.max(-lo.X, hi.X, -lo.Z, hi.Z), Center = -(lo.Y + hi.Y) / 2 }
	local config = Geometry[id]
	local warnings = {}
	if #extra > 0 then
		table.insert(warnings, "extra meshes ignored: " .. table.concat(extra, ", "))
	end
	if
		config
		and (math.abs(config.Radius - measured.Radius) > 0.02 or math.abs(config.Center - measured.Center) > 0.02)
	then
		table.insert(
			warnings,
			string.format(
				"ReleaseGeometry %.3f/%.3f vs measured %.3f/%.3f (update Config/ReleaseGeometry.luau)",
				config.Radius,
				config.Center,
				measured.Radius,
				measured.Center
			)
		)
	elseif not config then
		table.insert(warnings, "no ReleaseGeometry entry yet")
	end
	-- ReleaseVersion 2 keeps FightScene on the release crack paths (Config/ReleaseCrackPaths.luau).
	model:SetAttribute("ReleaseVersion", 2)
	model:SetAttribute("ArtVersion", VERSION)
	model:SetAttribute("NativeImportValidated", true)
	model:SetAttribute("LiveKitValidated", false)
	model:SetAttribute("SourceAsset", entry.AssetId or 0)
	if entry.IconAssetId then
		model:SetAttribute("IconAsset", entry.IconAssetId)
	end
	model:SetAttribute("MeasuredRadius", measured.Radius)
	model:SetAttribute("MeasuredCenter", measured.Center)
	raw:Destroy()
	return model,
		{
			Source = source,
			Scale = scale,
			Rotation = tostring(best),
			FitError = meanErr,
			MaxBoundsError = maxBounds,
			Parts = counts,
			Geometry = measured,
			Warnings = warnings,
		}
end

local function verify(id, entry)
	local m = library:FindFirstChild(id)
	if not m then
		return { Ok = false, Problem = "not installed" }
	end
	local problems = {}
	if m:GetAttribute("ArtVersion") ~= VERSION then
		table.insert(problems, "ArtVersion " .. tostring(m:GetAttribute("ArtVersion")))
	end
	if m:GetAttribute("ReleaseVersion") ~= 2 then
		table.insert(problems, "ReleaseVersion must stay 2")
	end
	local maxBounds = 0
	for _, p in entry.Parts do
		local where = if p.Role == "Shard"
			then m:FindFirstChild("Shards")
			elseif p.Role == "Detail" then m:FindFirstChild("Details")
			else m
		local part = where and where:FindFirstChild(p.Source)
		if not part then
			table.insert(problems, "missing " .. p.Source)
			continue
		end
		local lo, hi = aabb(part)
		local half = v3(p.Size) / 2
		maxBounds = math.max(maxBounds, (lo - (v3(p.Center) - half)).Magnitude, (hi - (v3(p.Center) + half)).Magnitude)
		if part:GetAttribute("AssetRole") ~= p.Role or part:GetAttribute("AnimationPivot") == nil then
			table.insert(problems, "attributes " .. p.Source)
		end
	end
	if maxBounds > TOL + 0.01 then
		table.insert(problems, string.format("bounds off by %.4f", maxBounds))
	end
	if m:GetPivot().Position.Magnitude > 0.001 then
		table.insert(problems, "model pivot is not the hang point")
	end
	return { Ok = #problems == 0, Problems = problems, MaxBoundsError = maxBounds }
end

local report = { Mode = MODE, Version = VERSION, Glassies = {} }
local backups = if MODE == "install" then folder(SS, OPTIONS.Backup or "GlassiesBeforeV4") else nil
for id, entry in DATA do
	if MODE == "verify" then
		report.Glassies[id] = verify(id, entry)
		continue
	end
	local old = library:FindFirstChild(id)
	if
		old
		and not OPTIONS.Force
		and old:GetAttribute("ArtVersion") == VERSION
		and entry.AssetId
		and old:GetAttribute("SourceAsset") == entry.AssetId
	then
		report.Glassies[id] =
			{ Status = "unchanged (already " .. VERSION .. " from asset " .. tostring(entry.AssetId) .. ")" }
		continue
	end
	local ok, model, info = pcall(build, id, entry)
	if not ok then
		report.Glassies[id] = { Status = "FAILED", Error = tostring(model) }
		continue
	end
	if MODE == "dry" then
		model:Destroy()
		info.Status = if old
			then "would replace " .. old:GetFullName()
			else "would add " .. library:GetFullName() .. "." .. id
	else
		if old and not backups:FindFirstChild(id) then
			old:Clone().Parent = backups
		end
		if old then
			old:Destroy()
		end
		model.Parent = library
		info.Status = "installed"
		info.Backup = backups:FindFirstChild(id) and backups[id]:GetFullName() or nil
	end
	report.Glassies[id] = info
	task.wait()
end
return report
