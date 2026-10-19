-- Flyers v3 installer (docs/art/FLYERS_V3.md). Edit mode only, through the Studio MCP.
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

local TEX = {
	glint = "rbxassetid://118014953401567",
	streak = "rbxassetid://125001828353860",
	puff = "rbxassetid://95994848531562",
	fleck = "rbxassetid://119749428254490",
	fire = "rbxasset://textures/particles/fire_main.dds",
	sparkle = "rbxasset://textures/particles/sparkles_main.dds",
}
local MAIN = { skyboard = "Deck", cloud_cushion = "CloudBody", rocket_skiff = "Hull", prism_ray = "Body" }

local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name, f.Parent = name, parent
	end
	return f
end
local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end
local function seq(points)
	local keys = {}
	for _, p in points do
		table.insert(keys, ColorSequenceKeypoint.new(p[1], Color3.fromHex(p[2])))
	end
	return ColorSequence.new(keys)
end
local function nseq(points)
	local keys = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(keys)
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

local EFFECTS = {}
local function emitter(parent, name, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	for k, v in props do
		if k ~= "Tag" and k ~= "Burst" then
			e[k] = v
		end
	end
	e.Enabled = false
	if props.Burst then
		e:SetAttribute("RideLaunch", true)
		e:SetAttribute("EmitCount", props.Burst)
	else
		e:SetAttribute("RideEmitter", true)
	end
	e.Parent = parent
	return e
end
local function trail(parent, name, a0, a1, props)
	local t = Instance.new("Trail")
	t.Name, t.Attachment0, t.Attachment1 = name, a0, a1
	t.FaceCamera, t.Enabled = true, false
	for k, v in props do
		t[k] = v
	end
	t:SetAttribute("RideEmitter", true)
	t.Parent = parent
	return t
end
local function light(parent, color, brightness, range)
	local l = Instance.new("PointLight")
	l.Color, l.Brightness, l.Range, l.Shadows, l.Enabled = Color3.fromHex(color), brightness, range, false, false
	l:SetAttribute("RideEmitter", true)
	l:SetAttribute("BaseBrightness", brightness)
	l.Parent = parent
	return l
end
local function wake(att, color)
	emitter(att, "WindStreaks", {
		Texture = TEX.streak,
		Color = ColorSequence.new(Color3.fromHex(color)),
		LightEmission = 0.6,
		Transparency = nseq({ { 0, 1 }, { 0.2, 0.55 }, { 1, 1 } }),
		Size = nseq({ { 0, 0.14 }, { 1, 0.08 } }),
		Lifetime = NumberRange.new(0.45, 0.6),
		Rate = 5,
		Speed = NumberRange.new(11, 15),
		EmissionDirection = Enum.NormalId.Back,
		SpreadAngle = Vector2.new(20, 9),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Squash = nseq({ { 0, 1.2 }, { 1, 1.2 } }),
	})
end

EFFECTS.skyboard = function(model, A)
	local rail = model.Rail
	local props = {
		Color = seq({ { 0, "#9BF6F2" }, { 1, "#FFFFFF" } }),
		Transparency = nseq({ { 0, 0.3 }, { 1, 1 } }),
		Lifetime = 0.35,
		LightEmission = 0.8,
		MinLength = 0.04,
		WidthScale = nseq({ { 0, 1 }, { 1, 0.2 } }),
	}
	trail(rail, "RailTrailR", A.TrailR0, A.TrailR1, props)
	trail(rail, "RailTrailL", A.TrailL0, A.TrailL1, props)
	for _, pod in { A.PodF, A.PodB } do
		emitter(pod, "LiftMotes", {
			Texture = TEX.glint,
			Color = seq({ { 0, "#C9FFFB" }, { 1, "#61D4DF" } }),
			LightEmission = 1,
			Size = nseq({ { 0, 0.32 }, { 1, 0 } }),
			Transparency = nseq({ { 0, 0.1 }, { 1, 0.6 } }),
			Lifetime = NumberRange.new(0.6, 1),
			Rate = 5,
			Speed = NumberRange.new(1.5, 3),
			EmissionDirection = Enum.NormalId.Bottom,
			SpreadAngle = Vector2.new(25, 25),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-90, 90),
		})
	end
	light(A.PodF, "#7FF0EC", 0.9, 7)
	wake(A.Wake, "#E8FFFE")
	emitter(A.Launch, "LaunchPuff", {
		Burst = 14,
		Texture = TEX.puff,
		Color = ColorSequence.new(Color3.fromHex("#E8FFFE")),
		LightEmission = 0.3,
		Size = nseq({ { 0, 0.8 }, { 1, 2.4 } }),
		Transparency = nseq({ { 0, 0.35 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.45, 0.65),
		Speed = NumberRange.new(5, 8),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(75, 75),
		Drag = 4,
	})
	emitter(A.Launch, "LaunchGlints", {
		Burst = 10,
		Texture = TEX.glint,
		Color = ColorSequence.new(Color3.fromHex("#9BF6F2")),
		LightEmission = 1,
		Size = nseq({ { 0, 0.45 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(6, 10),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
	})
end

EFFECTS.cloud_cushion = function(model, A)
	trail(model.RainbowButter, "RainbowWake", A.Trail0, A.Trail1, {
		Color = seq({ { 0, "#F7A8D2" }, { 0.5, "#FFE08A" }, { 1, "#7FE6EA" } }),
		Transparency = nseq({ { 0, 0.25 }, { 1, 1 } }),
		Lifetime = 0.6,
		LightEmission = 0.5,
		MinLength = 0.04,
		WidthScale = nseq({ { 0, 1 }, { 1, 0.4 } }),
	})
	emitter(A.Wisps, "CloudWisps", {
		Texture = TEX.puff,
		Color = ColorSequence.new(Color3.fromHex("#F4F6FF")),
		LightEmission = 0.15,
		Size = nseq({ { 0, 0.7 }, { 1, 1.7 } }),
		Transparency = nseq({ { 0, 1 }, { 0.25, 0.55 }, { 1, 1 } }),
		Lifetime = NumberRange.new(1.4, 2.2),
		Rate = 4,
		Speed = NumberRange.new(0.6, 1.2),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(35, 35),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-20, 20),
		Drag = 0.6,
	})
	emitter(model.CloudBody, "Twinkles", {
		Texture = TEX.glint,
		Color = seq({ { 0, "#FFE08A" }, { 0.5, "#F7A8D2" }, { 1, "#7FE6EA" } }),
		LightEmission = 1,
		Size = nseq({ { 0, 0 }, { 0.3, 0.32 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Rate = 4,
		Speed = NumberRange.new(0.2, 0.6),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	wake(A.Wake, "#FFFFFF")
	emitter(A.Launch, "LaunchPuff", {
		Burst = 18,
		Texture = TEX.puff,
		Color = ColorSequence.new(Color3.fromHex("#FFFFFF")),
		LightEmission = 0.2,
		Size = nseq({ { 0, 1 }, { 1, 2.8 } }),
		Transparency = nseq({ { 0, 0.3 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.6, 0.9),
		Speed = NumberRange.new(4, 7),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(85, 85),
		Drag = 3,
	})
end

EFFECTS.rocket_skiff = function(model, A)
	for _, side in { "L", "R" } do
		local ex = A["Exhaust_" .. side]
		emitter(ex, "FlameCore", {
			Texture = TEX.fire,
			Color = seq({ { 0, "#FFF6D0" }, { 0.4, "#FFC46B" }, { 1, "#FF7A45" } }),
			LightEmission = 1,
			Size = nseq({ { 0, 0.55 }, { 1, 0.1 } }),
			Transparency = nseq({ { 0, 0.15 }, { 1, 1 } }),
			Lifetime = NumberRange.new(0.16, 0.26),
			Rate = 36,
			Speed = NumberRange.new(8, 11),
			EmissionDirection = Enum.NormalId.Back,
			SpreadAngle = Vector2.new(6, 6),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-180, 180),
		})
		emitter(ex, "Smoke", {
			Texture = TEX.puff,
			Color = ColorSequence.new(Color3.fromHex("#F6EDE6")),
			LightEmission = 0.1,
			Size = nseq({ { 0, 0.5 }, { 1, 1.7 } }),
			Transparency = nseq({ { 0, 0.65 }, { 1, 1 } }),
			Lifetime = NumberRange.new(0.8, 1.2),
			Rate = 6,
			Speed = NumberRange.new(4, 6),
			EmissionDirection = Enum.NormalId.Back,
			SpreadAngle = Vector2.new(12, 12),
			Rotation = NumberRange.new(0, 360),
			Drag = 1.5,
		})
		emitter(ex, "Sparks", {
			Texture = TEX.glint,
			Color = seq({ { 0, "#FFF1B8" }, { 1, "#FF9A55" } }),
			LightEmission = 1,
			Size = nseq({ { 0, 0.22 }, { 1, 0 } }),
			Lifetime = NumberRange.new(0.3, 0.5),
			Rate = 6,
			Speed = NumberRange.new(6, 10),
			EmissionDirection = Enum.NormalId.Back,
			SpreadAngle = Vector2.new(22, 22),
			Acceleration = Vector3.new(0, -8, 0),
		})
		light(ex, "#FFB866", 1.6, 8)
		trail(model["TailFin_" .. side], "FinTrail", A["FinTrail" .. side .. "0"], A["FinTrail" .. side .. "1"], {
			Color = seq({ { 0, "#FFE39A" }, { 1, "#FFFFFF" } }),
			Transparency = nseq({ { 0, 0.4 }, { 1, 1 } }),
			Lifetime = 0.3,
			LightEmission = 0.6,
			MinLength = 0.04,
		})
	end
	wake(A.Wake, "#FFF4E6")
	emitter(A.Launch, "LaunchSmoke", {
		Burst = 16,
		Texture = TEX.puff,
		Color = ColorSequence.new(Color3.fromHex("#FFF0E0")),
		LightEmission = 0.2,
		Size = nseq({ { 0, 1 }, { 1, 3 } }),
		Transparency = nseq({ { 0, 0.35 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(6, 9),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(80, 80),
		Drag = 4,
	})
	emitter(A.Launch, "LaunchSparks", {
		Burst = 14,
		Texture = TEX.glint,
		Color = seq({ { 0, "#FFF1B8" }, { 1, "#FF9A55" } }),
		LightEmission = 1,
		Size = nseq({ { 0, 0.35 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(8, 12),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -12, 0),
		Drag = 2,
	})
end

EFFECTS.prism_ray = function(model, A)
	local prism = seq({
		{ 0, "#FFA8D8" },
		{ 0.25, "#FFE08A" },
		{ 0.5, "#7CE7D5" },
		{ 0.75, "#8FC8FF" },
		{ 1, "#B8A4F4" },
	})
	for _, side in { "L", "R" } do
		trail(model["Wing_" .. side], "PrismTrail", A["WingTip" .. side .. "0"], A["WingTip" .. side .. "1"], {
			Color = prism,
			Transparency = nseq({ { 0, 0.2 }, { 1, 1 } }),
			Lifetime = 0.5,
			LightEmission = 0.8,
			MinLength = 0.03,
			WidthScale = nseq({ { 0, 1 }, { 1, 0.3 } }),
		})
	end
	emitter(model.Body, "PrismGlints", {
		Texture = TEX.glint,
		Color = prism,
		LightEmission = 1,
		Size = nseq({ { 0, 0 }, { 0.25, 0.36 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.6, 1),
		Rate = 6,
		Speed = NumberRange.new(0.4, 1.2),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Rotation = NumberRange.new(0, 360),
	})
	emitter(A.PrismGlow, "PrismSparkle", {
		Texture = TEX.sparkle,
		Color = ColorSequence.new(Color3.fromHex("#B8FFF2")),
		LightEmission = 1,
		Size = nseq({ { 0, 0.4 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.4, 0.7),
		Rate = 4,
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
	})
	light(A.PrismGlow, "#7CE7D5", 1.2, 6)
	wake(A.Wake, "#F0EBFF")
	emitter(A.Launch, "LaunchCrystals", {
		Burst = 22,
		Texture = TEX.fleck,
		Color = prism,
		LightEmission = 0.8,
		Size = nseq({ { 0, 0.3 }, { 1, 0.05 } }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(7, 12),
		SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-300, 300),
		Acceleration = Vector3.new(0, -10, 0),
		Drag = 2,
	})
	emitter(A.Launch, "LaunchGlints", {
		Burst = 14,
		Texture = TEX.glint,
		Color = prism,
		LightEmission = 1,
		Size = nseq({ { 0, 0.55 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(5, 9),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
	})
end

local report = {}
local imports = folder(SS, "FlyersV3Import")
local backups = folder(SS, "FlyersBeforeV3")
local rideables = RS.Assets.Rideables
for id, entry in input do
	local manifest = HttpService:JSONDecode(entry.Manifest)
	local raw = imports:FindFirstChild(id)
	if not raw then
		raw = game:GetObjects("rbxassetid://" .. entry.AssetId)[1]
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
		part.Parent = model
	end
	local main = model[MAIN[id]]
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
	EFFECTS[id](model, A)
	model:SetAttribute("Version", 3)
	model:SetAttribute("OriginalGlassClash", true)
	model:SetAttribute("BlenderAuthored", true)
	model:SetAttribute("DisplayName", manifest.Name)
	model:SetAttribute("Triangles", manifest.Tris)
	model:SetAttribute("SourceAsset", entry.AssetId)
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
