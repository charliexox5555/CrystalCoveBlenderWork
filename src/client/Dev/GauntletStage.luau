-- The Kiln Room: a dark, warm stage so tinted glass is the brightest thing on screen. Local parts only.
local RS = game:GetService("ReplicatedStorage")
local G = require(RS.Shared.Config.Gauntlet)
local Stage = {}
Stage.__index = Stage

local WALL = Color3.fromHex("#1B1433")
local FLOOR = Color3.fromHex("#2A1E45")
local TRIM = Color3.fromHex("#3B2A5E")
local IRON = Color3.fromHex("#141020")
local BRASS = Color3.fromHex("#E8B24A")
local EMBER = Color3.fromHex("#FF8A2B")

local function part(parent, name, size, frame, color, material)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, frame, color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function Stage.new(frame, hookGap)
	local root = Instance.new("Folder")
	root.Name = "GauntletStage"
	local at = function(x, y, z)
		return frame * CFrame.new(x, y, z)
	end
	-- Room shell hides the sky so the fight owns the frame.
	part(root, "BackWall", Vector3.new(90, 50, 1), at(0, -3, -13), WALL)
	part(root, "Floor", Vector3.new(90, 1, 50), at(0, -14, 6), FLOOR)
	part(root, "Ceiling", Vector3.new(90, 1, 50), at(0, 8, 6), IRON)
	part(root, "LeftWall", Vector3.new(1, 50, 50), at(-30, -3, 6), WALL)
	part(root, "RightWall", Vector3.new(1, 50, 50), at(30, -3, 6), WALL)
	-- The Kiln mouth behind the swing: a warm glow right where the glass passes.
	local mouth = Instance.new("Part")
	mouth.Name, mouth.Shape = "KilnGlow", Enum.PartType.Cylinder
	mouth.Size, mouth.CFrame = Vector3.new(0.4, 19, 19), at(0, -6.5, -12.2) * CFrame.Angles(0, math.pi / 2, 0)
	mouth.Color, mouth.Material = Color3.fromHex("#4A1F2E"), Enum.Material.SmoothPlastic
	mouth.Anchored, mouth.CanCollide, mouth.CanTouch, mouth.CanQuery = true, false, false, false
	mouth.CastShadow, mouth.Transparency = false, 0
	mouth.Parent = root
	local core = mouth:Clone()
	core.Name, core.Size = "KilnCore", Vector3.new(0.4, 11, 11)
	core.CFrame, core.Color, core.Transparency = at(0, -6.5, -12), Color3.fromHex("#6B2F24"), 0
	core.CFrame *= CFrame.Angles(0, math.pi / 2, 0)
	core.Parent = root
	local arch = mouth:Clone()
	arch.Name, arch.Size = "KilnBrick", Vector3.new(0.3, 22, 22)
	arch.CFrame = at(0, -6.5, -12.5) * CFrame.Angles(0, math.pi / 2, 0)
	arch.Color, arch.Material, arch.Transparency = Color3.fromHex("#2B1D47"), Enum.Material.SmoothPlastic, 0
	arch.Parent = root
	-- Iron crossbar with brass rings: reads as a swing rig, no giant timber frame blocking the view.
	part(root, "Crossbar", Vector3.new(44, 0.7, 0.7), at(0, 0, 0), IRON, Enum.Material.Metal)
	for _, x in { -hookGap / 2, hookGap / 2 } do
		part(root, "Ring", Vector3.new(0.5, 0.5, 0.9), at(x, -0.1, 0), BRASS, Enum.Material.Metal)
	end
	for _, x in { -21, 21 } do
		part(root, "Post", Vector3.new(0.9, 16, 0.9), at(x, -7, 0), IRON, Enum.Material.Metal)
	end
	-- Light: warm from the Kiln behind, cool key from the camera side so faces stay readable.
	local kilnLight = Instance.new("PointLight")
	kilnLight.Color, kilnLight.Brightness, kilnLight.Range, kilnLight.Shadows = EMBER, 0.6, 22, false
	kilnLight.Parent = core
	local key = part(root, "KeyLight", Vector3.one, at(0, 2, 15), WALL)
	key.Transparency = 1
	local keyLight = Instance.new("PointLight")
	keyLight.Color, keyLight.Brightness, keyLight.Range, keyLight.Shadows = Color3.fromHex("#EAF0FF"), 0.9, 30, false
	keyLight.Parent = key
	-- Embers drifting up past the glass.
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(EMBER, Color3.fromHex("#FFD27A"))
	emitter.LightEmission, emitter.LightInfluence = 1, 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime, emitter.Rate = NumberRange.new(3, 6), 7
	emitter.Speed, emitter.SpreadAngle = NumberRange.new(1, 2.4), Vector2.new(35, 35)
	emitter.EmissionDirection = Enum.NormalId.Top
	local bed = part(root, "EmberBed", Vector3.new(26, 0.2, 12), at(0, -13.4, 0), FLOOR)
	bed.Transparency = 1
	emitter.Parent = bed
	-- The Shelf: everything you own stands behind the fight; locked glassies wait as dark silhouettes.
	local shelfY, shelf = -12, {}
	part(root, "Shelf", Vector3.new(34, 0.5, 3), at(0, shelfY, -9.5), TRIM)
	local library = RS.Assets[G.Library]
	for i, id in G.Roster do
		local x = (i - (#G.Roster + 1) / 2) * 4.6
		local source = library[id]
		local model = Instance.new("Model")
		model.Name = id
		model.WorldPivot = CFrame.identity
		source.Body:Clone().Parent = model
		for _, d in source.Details:GetChildren() do
			if not d.Name:find("Face") or d.Name == "FaceIdle" then
				d:Clone().Parent = model
			end
		end
		local height = 0
		for _, p in model:GetChildren() do
			height = math.max(height, -(p.Position.Y - p.Size.Y / 2))
		end
		model:PivotTo(at(x, shelfY + 0.25 + height, -9.5))
		model.Parent = root
		shelf[id] = { Model = model, Lit = true, Colors = {} }
		for _, p in model:GetChildren() do
			shelf[id].Colors[p] = { Color = p.Color, Transparency = p.Transparency, Material = p.Material }
		end
	end
	root.Parent = workspace
	return setmetatable({ Root = root, Shelf = shelf, Frame = frame, Pops = {} }, Stage)
end

function Stage:SetOwned(owned)
	for id, entry in self.Shelf do
		local lit = owned[id] == true
		if lit == entry.Lit then
			continue
		end
		entry.Lit = lit
		for p, look in entry.Colors do
			if lit then
				p.Color, p.Transparency, p.Material = look.Color, look.Transparency, look.Material
			elseif p.Name == "FaceIdle" then
				p.Transparency = 1
			else
				p.Color, p.Transparency, p.Material = Color3.fromHex("#0B0816"), 0, Enum.Material.SmoothPlastic
			end
		end
	end
end

function Stage:Destroy()
	self.Root:Destroy()
end

return Stage
