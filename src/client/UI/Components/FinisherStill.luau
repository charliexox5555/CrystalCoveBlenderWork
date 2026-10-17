-- A frozen mid-burst frame of a finisher, built from the same meshes, colours and pieces as
-- Presentation/FinisherFX, for icons and portraits (ViewportFrames can't show particles or tweens).
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config.RoundCosmetics)
local T = require(RS.Shared.Config.Balance).CosmeticPresentation
local Still = {}

local PIECES = 12
local RADIUS = T.FinisherRadius * 0.5

local function part(world, name, color, size, cf, options)
	options = options or {}
	local library = RS.Assets.VFX:FindFirstChild("RoundHeroV2")
	local source = library and options.Mesh and library:FindFirstChild(options.Mesh)
	local p = if source then source:Clone() else Instance.new("Part")
	p.Name, p.Color, p.Material, p.Size, p.CFrame = name, color, options.Material or Enum.Material.Neon, size, cf
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Transparency = options.Transparency or 0
	if options.Shape and p:IsA("Part") then
		p.Shape = options.Shape
	end
	p.Parent = world
	return p
end

local function ring(world, color, turn, transparency)
	local source = RS.Assets.VFX.Combat.Meshes.Ring
	local r = source:Clone()
	r.Name, r.Material, r.Color, r.Transparency = "Shockwave", Enum.Material.Neon, color, transparency
	r.Anchored, r.CanCollide, r.CanTouch, r.CanQuery, r.CastShadow = true, false, false, false, false
	r.Size = source.Size * (RADIUS * 1.45)
	r.CFrame = CFrame.Angles(turn, 0, 0)
	r.Parent = world
end

local function direction(i)
	local a = i / PIECES * math.pi * 2
	return a, Vector3.new(math.cos(a), math.sin(a), math.sin(a * 3) * 0.35).Unit
end

-- Builds the still into `world` (a WorldModel or Model). Returns false for ids without a recipe.
function Still.build(world, id)
	local def = C.ByCategory.Finishers[id]
	if not def or not def.Color then
		return false
	end
	local color, accent = Color3.fromHex(def.Color), Color3.fromHex(def.Accent)
	-- Core glow: soft coloured burst with a bright heart.
	part(world, "BurstCore", color, Vector3.one * 3.6, CFrame.new(), {
		Shape = Enum.PartType.Ball,
		Transparency = 0.3,
		Mesh = if id == "brick_boom" then "BlastBloom" else nil,
	})
	part(world, "BurstHeart", accent, Vector3.one * 1.9, CFrame.new(), { Shape = Enum.PartType.Ball })
	ring(world, color, 0, 0.3)
	ring(world, accent, math.pi / 2, 0.5)
	for i = 1, PIECES do
		local a, dir = direction(i)
		local tint = if i % 2 == 0 then color else accent
		local at = dir * RADIUS * (1.3 + (i % 3) * 0.15)
		local tumble = CFrame.Angles(a * 2, a * 3, a)
		if id == "party_burst" then
			part(
				world,
				"BurstPiece",
				Color3.fromHSV(i / PIECES, 0.7, 1),
				Vector3.new(0.35, 0.8, 0.08) * 3.4,
				CFrame.new(at + Vector3.yAxis) * tumble,
				{ Material = Enum.Material.SmoothPlastic, Mesh = "ConfettiCurl" }
			)
		elseif id == "bubble_bloom" then
			part(
				world,
				"BurstPiece",
				tint,
				Vector3.one * (2.1 + i % 3 * 0.6),
				CFrame.new(dir * RADIUS * 1 + Vector3.yAxis * 1.2),
				{ Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic, Transparency = 0.3 }
			)
		elseif id == "brick_boom" then
			part(
				world,
				"BurstPiece",
				tint,
				Vector3.new(0.7 + i % 3 * 0.2, 0.7, 0.7) * 2.5,
				CFrame.new(at + Vector3.yAxis * 1.2) * tumble,
				{ Material = Enum.Material.SmoothPlastic }
			)
		elseif id == "starfall" then
			part(
				world,
				"StarGem",
				tint,
				Vector3.new(0.65, 0.65, 0.18) * 3.4,
				CFrame.new(dir * RADIUS * (0.85 + (i % 3) * 0.3)) * CFrame.Angles(0, 0, a),
				{ Mesh = "NovaStar" }
			)
		else
			part(world, "BurstPiece", tint, Vector3.new(0.35, 0.8, 0.2) * 3.6, CFrame.new(at) * tumble, {
				Material = Enum.Material.Glass,
				Transparency = 0.1,
				Mesh = if id == "glass_burst" then "CrystalShard" else nil,
			})
		end
	end
	if id == "starfall" then
		for i = 1, 4 do
			part(
				world,
				"NovaRay",
				accent,
				Vector3.new(RADIUS * 1.8, 0.22, 0.22),
				CFrame.Angles(0, 0, (i - 0.5) * math.pi / 2) * CFrame.new(RADIUS * 0.9, 0, 0),
				{ Transparency = 0.2 }
			)
		end
	elseif id == "brick_boom" then
		for i = 1, 3 do
			part(
				world,
				"ToyFireball",
				color,
				Vector3.one * (2 + i * 0.7),
				CFrame.new(Vector3.new(i - 2, 0.5 + i * 0.3, 0)),
				{ Shape = Enum.PartType.Ball, Mesh = "BlastBloom", Transparency = 0.45 }
			)
		end
	end
	return true
end
return Still
