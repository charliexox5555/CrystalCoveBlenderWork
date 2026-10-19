-- Flyers v3 installer (docs/art/FLYERS_V3.md). Edit mode only, through the Studio MCP, with
-- tools/studio/flyer_effects.luau prepended (it defines TEX, EFFECTS, v3, seq, nseq).
-- Before running, set _G.FlyersV3 = { [id] = { AssetId = <Open Cloud model id>, Manifest = <manifest.json string> } }.
-- For each flyer: loads the uploaded model, keeps the raw insert in ServerStorage.FlyersV3Import, backs up
-- the current template to ServerStorage.FlyersBeforeV3 (once), then rebuilds ReplicatedStorage.Assets.Rideables.<id>
-- from the manifest (sizes, positions, materials, motion attributes, attachments) plus its effects.
-- Same template name/path, so MatchStage, the lobby displays, shop portraits and crate reveals pick it up.
assert(not game:GetService("RunService"):IsRunning(), "Install in Edit")
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local input = assert(_G.FlyersV3, "_G.FlyersV3 missing")

-- Main part (PrimaryPart, sound host) per flyer; a manifest may name its own with "Main".
local MAIN = {
	skyboard = "Deck",
	cloud_cushion = "CloudBody",
	rocket_skiff = "Hull",
	prism_ray = "Body",
	honey_hover = "Deck",
	bubble_pod = "Shell",
	paper_jet = "Keel",
	dragonfly = "Thorax",
	carousel = "Pole", -- the main part must not move (the pony bobs)
}
-- Flyers whose rider sits on a moving part (RideMotion follows it; see RideMotion:RiderPose).
local MOUNT = { carousel = "Pony" }

local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name, f.Parent = name, parent
	end
	return f
end
-- All 24 axis-aligned rotations, to map the raw import onto the manifest whatever the importer did.
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

local function fit(raw, manifest)
	-- Raw parts by name, centred on the raw bounds; manifest centres are relative to the contact origin.
	local parts = {}
	for _, d in raw:GetDescendants() do
		if d:IsA("MeshPart") and manifest.Parts[d.Name] then
			parts[d.Name] = d
		end
	end
	for name in manifest.Parts do
		assert(parts[name], "raw import missing " .. name)
	end
	local rawCf, rawSize = raw:GetBoundingBox()
	local ext = v3(manifest.Extents)
	local scale = ext.Magnitude / rawSize.Magnitude
	-- manifest bounds centre (Roblox coords)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in manifest.Parts do
		local c, s = v3(p.Centre), v3(p.Size) / 2
		lo, hi = lo:Min(c - s), hi:Max(c + s)
	end
	local mCentre = (lo + hi) / 2
	local best, bestErr
	for _, rot in ROTATIONS do
		local err = 0
		for name, p in manifest.Parts do
			local rel = rawCf:PointToObjectSpace(parts[name].Position) * scale
			err += ((rot * rel) - (v3(p.Centre) - mCentre)).Magnitude
		end
		if not bestErr or err < bestErr then
			best, bestErr = rot, err
		end
	end
	return parts, scale, best, bestErr, rawCf, mCentre
end

local function axisSign(part, axis)
	local v = ({ X = part.CFrame.RightVector, Y = part.CFrame.UpVector, Z = -part.CFrame.LookVector })[axis]
	local world = ({ X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis })[axis]
	return if v:Dot(world) < 0 then -1 else 1
end

local report = {}
local imports = folder(SS, "FlyersV3Import")
local backups = folder(SS, "FlyersBeforeV3")
local rideables = RS.Assets.Rideables
for id, entry in input do
	local manifest = HttpService:JSONDecode(entry.Manifest)
	local raw = imports:FindFirstChild(id)
	if not raw then
		-- Slow connections: asset loads can time out once, so retry with a growing wait.
		for attempt = 1, 5 do
			local ok, result = pcall(function()
				return game:GetObjects("rbxassetid://" .. entry.AssetId)[1]
			end)
			if ok and result then
				raw = result
				break
			end
			warn(("install_flyers_v3: %s load attempt %d failed: %s"):format(id, attempt, tostring(result)))
			task.wait(2 * attempt)
		end
		assert(raw, id .. " asset did not load")
		raw.Name = id
		raw.Parent = imports
	end
	raw:SetAttribute("AssetId", entry.AssetId)
	local parts, scale, rot, err, rawCf, mCentre = fit(raw, manifest)
	local old = rideables:FindFirstChild(id)
	if old and not backups:FindFirstChild(id) then
		old:Clone().Parent = backups
	end

	local model = Instance.new("Model")
	model.Name = id
	for name, p in manifest.Parts do
		local src = parts[name]
		local part = src:Clone()
		for _, child in part:GetChildren() do
			child:Destroy()
		end
		local relRot = rawCf.Rotation:ToObjectSpace(src.CFrame.Rotation)
		part.CFrame = CFrame.new(v3(p.Centre)) * rot * relRot
		part.Size = src.Size * scale
		part.Color = Color3.fromHex(p.Color)
		part.Material = Enum.Material[p.Material]
		part.Transparency, part.Reflectance = p.Transparency, p.Reflectance
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.Massless = true, false, false, false, true
		part.CastShadow = p.Material ~= "Neon"
		part:SetAttribute("Triangles", p.Tris)
		for key, value in p.Motion do
			if key == "MotionPivot" then
				-- pivot offsets are in world axes from the part centre; RideMotion reads part-local
				part:SetAttribute(key, part.CFrame:VectorToObjectSpace(v3(value)))
			else
				part:SetAttribute(key, value)
			end
		end
		-- RideMotion turns parts about their local axes; the importer may flip them (it turned these 180°),
		-- so flip the signed values to keep the motion as designed in world space.
		local kind = p.Motion.RideMotion
		if kind == "Wing" then
			part:SetAttribute("WingSide", part:GetAttribute("WingSide") * axisSign(part, "Z"))
		elseif kind == "Fin" then
			local s = axisSign(part, part:GetAttribute("FinAxis") or "X")
			part:SetAttribute("FinAngle", (part:GetAttribute("FinAngle") or 0.1) * s)
			part:SetAttribute("FinBank", (part:GetAttribute("FinBank") or 0) * s)
		end
		if kind and part:GetAttribute("SpinSpeed") then
			part:SetAttribute(
				"SpinSpeed",
				part:GetAttribute("SpinSpeed") * axisSign(part, part:GetAttribute("SpinAxis") or "Z")
			)
		end
		part.Parent = model
	end
	local main = model[manifest.Main or MAIN[id]]
	main.PivotOffset = main.CFrame:Inverse() -- model pivot = contact point at the origin
	model.PrimaryPart = main
	local A = {}
	for name, a in manifest.Attachments do
		local part = model[a.Part]
		local att = Instance.new("Attachment")
		att.Name = name
		att.Position = part.CFrame:PointToObjectSpace(v3(a.World))
		att.Parent = part
		A[name] = att
	end
	EFFECTS[id](model, A) -- the v3 part names are the effect roles
	model:SetAttribute("Version", 3)
	model:SetAttribute("OriginalGlassClash", true)
	model:SetAttribute("BlenderAuthored", true)
	model:SetAttribute("DisplayName", manifest.Name)
	model:SetAttribute("Triangles", manifest.Tris)
	model:SetAttribute("SourceAsset", entry.AssetId)
	model:SetAttribute("AxisFixed", true)
	if manifest.RiderMount or MOUNT[id] then
		model:SetAttribute("RiderMount", manifest.RiderMount or MOUNT[id])
	end
	-- size check against the manifest
	local _, size = model:GetBoundingBox()
	local want = v3(manifest.Extents)
	if old then
		old:Destroy()
	end
	model.Parent = rideables
	report[id] = {
		Scale = scale,
		FitError = err,
		Rotation = tostring(rot),
		Size = tostring(size),
		Want = tostring(want),
		Parts = #model:GetChildren(),
	}
end
return HttpService:JSONEncode(report)
