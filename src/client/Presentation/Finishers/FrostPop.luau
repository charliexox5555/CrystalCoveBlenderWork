-- Frost Pop (frost_pop, Common): frost creeps up, six ice slabs snap into a cube around the foe, cracks flash
-- across it, and it bursts into tumbling ice and big spinning glass snowflakes under falling snow.
local Kit = require(script.Parent.Kit)
local Modules = require(script.Parent.Modules)
local Show = {}

local ICE, WHITE, FROST = Color3.fromHex("#BFEFFF"), Color3.new(1, 1, 1), Color3.fromHex("#7FB8FF")
local FACES = {
	Vector3.new(1, 0, 0),
	Vector3.new(-1, 0, 0),
	Vector3.new(0, 1, 0),
	Vector3.new(0, -1, 0),
	Vector3.new(0, 0, 1),
	Vector3.new(0, 0, -1),
}

function Show.build(rig, s)
	local random = Random.new(61)
	rig.Slabs = {}
	for i, n in FACES do
		table.insert(rig.Slabs, {
			Actor = rig:Actor("IceSlab", {
				Mesh = { "IceSlab", "GuardPlate" },
				Size = s.CubeHalf * 2.05,
				Color = ICE,
				Material = Enum.Material.Glass,
				Transparency = 0.22,
				Reflectance = 0.25,
			}),
			Normal = n,
			Delay = (i - 1) * 0.025,
			Swirl = random:NextNumber(0.8, 1.5) * (if i % 2 == 0 then 1 else -1),
			Spin = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-1, 1), random:NextNumber(-1, 1)) * 6,
			Speed = s.SlabSpeed * random:NextNumber(0.8, 1.2),
		})
	end
	-- Crack lines that flash across the front of the cube just before it breaks.
	rig.Cracks = {}
	for i = 1, (if rig.Low then 2 else 5) do
		table.insert(rig.Cracks, {
			Actor = rig:Actor("IceCrack", { Mesh = { "PrismSliver", "CrystalShard" }, Size = 1, Color = WHITE }),
			Angle = random:NextNumber(0, math.pi),
			Length = random:NextNumber(1.6, 3.2),
			Shift = Vector2.new(random:NextNumber(-0.8, 0.8), random:NextNumber(-0.8, 0.8)),
			At = s.PeakAt - 0.12 + (i - 1) * 0.02,
		})
	end
	Modules.ParticleField(rig, {
		Name = "FrostRise",
		Mode = "rise",
		At = 0,
		Until = s.PeakAt,
		Count = s.FrostRise,
		Radius = 2.4,
		Height = 3.6,
		Emitter = {
			Texture = "Snow",
			Color = { WHITE, ICE },
			Size = { { 0, 0.15 }, { 0.5, 0.35 }, { 1, 0.1 } },
			Lifetime = { 0.45, 0.7 },
			Speed = { 3, 6 },
			Spread = 15,
			RotSpeed = { -90, 90 },
		},
	})
	Modules.Flash(rig, { At = s.PeakAt, Size = s.FlashSize, Color = Color3.fromHex("#EAF9FF") })
	Modules.Shockwave(rig, { At = s.PeakAt, Radius = s.RingRadius, Color = FROST, Seconds = 0.5 })
	-- Small ice chips plus the big snowflakes.
	Modules.ShardBurst(rig, {
		Name = "IceChip",
		At = s.PeakAt,
		Count = 8,
		Mesh = { "IceSlab", "CrystalChip" },
		Size = { 0.5, 0.8 },
		Tints = { ICE, WHITE },
		Speed = { 9, 14 },
		Lift = 3,
		Gravity = 20,
		Fade = { At = 0.55, Seconds = 0.35 },
		Seed = 8,
	})
	Modules.ShardBurst(rig, {
		Name = "Snowflake",
		At = s.PeakAt + 0.02,
		Count = s.Flakes,
		Mesh = { "GlassSnowflake", "NovaStar" },
		Size = { 1.0, 1.5 },
		Tints = { WHITE, ICE },
		Material = Enum.Material.Glass,
		Transparency = 0.05,
		Reflectance = 0.35,
		Speed = { 5, 8 },
		Drag = 1.6,
		Gravity = 2.5,
		Orient = "face",
		Dir = function(i, count)
			local a = (i - 0.5) / count * math.pi * 2
			return Vector3.new(math.cos(a), math.sin(a) * 0.8 + 0.25, 0.25).Unit
		end,
		Fade = { At = 0.85, Seconds = 0.4 },
		Seed = 9,
	})
	Modules.ParticleField(rig, {
		Name = "Snowfall",
		Mode = "rain",
		At = s.PeakAt + 0.15,
		Until = s.PeakAt + 0.9,
		Count = s.Snow,
		Radius = 5,
		Height = 6,
		Emitter = {
			Texture = "Snow",
			Color = { WHITE, ICE },
			Size = { { 0, 0.3 }, { 1, 0.15 } },
			Transparency = { { 0, 0 }, { 0.8, 0.2 }, { 1, 1 } },
			Lifetime = { 0.7, 0.9 },
			Speed = { 4, 7 },
			Spread = 20,
			RotSpeed = { -120, 120 },
		},
	})
	rig:Emitter("Glints", {
		Texture = "StarGlint",
		Color = { WHITE, ICE },
		Size = { { 0, 1.0 }, { 1, 0 } },
		Lifetime = { 0.3, 0.5 },
		Speed = { 12, 20 },
		Drag = 5,
	})
	rig:Burst(s.PeakAt, "Glints", s.Glints)
end

function Show.step(rig, t, s)
	local origin = rig.Origin
	local after = t - s.PeakAt
	local released = after >= 0
	local charge = Kit.window(t, 0.26, s.PeakAt)
	local tail = Kit.smooth((after - 0.5) / 0.55)
	for _, slab in rig.Slabs do
		local n = rig.View:VectorToWorldSpace(slab.Normal)
		local up = if math.abs(slab.Normal.Y) > 0.9 then rig.View.ZVector else Vector3.yAxis
		local rest = n * s.CubeHalf * (1 - 0.05 * charge)
		local cf, scale, alpha
		if not released then
			local u = Kit.clamp01((t - slab.Delay) / 0.26)
			local from = CFrame.fromAxisAngle(Vector3.yAxis, (1 - u) * slab.Swirl):VectorToWorldSpace(n)
				* s.GatherRadius
			local at = from:Lerp(rest, Kit.pop(u))
			cf = CFrame.lookAt(origin + at, origin + at + n, up) * CFrame.Angles(0, 0, (1 - u) * slab.Swirl)
			scale = 0.4 + 0.6 * Kit.easeOut(u)
			alpha = 1 - Kit.smooth(u / 0.35)
			slab.Actor.Part.Material = if charge > 0.6 then Enum.Material.Neon else Enum.Material.Glass
			slab.Actor.Part.Color = ICE:Lerp(WHITE, charge * 0.6)
		else
			local at = rest + n * slab.Speed * after + Vector3.yAxis * (4 * after - 0.5 * s.Gravity * after * after)
			cf = CFrame.lookAt(origin + at, origin + at + n, up)
				* CFrame.Angles(slab.Spin.X * after, slab.Spin.Y * after, slab.Spin.Z * after)
			scale = 1 - 0.5 * tail
			alpha = tail
			slab.Actor.Part.Material = if after < 0.05 then Enum.Material.Neon else Enum.Material.Glass
			slab.Actor.Part.Color = ICE
		end
		rig:Place(slab.Actor, cf, scale, alpha)
	end
	-- Crack lines flicker across the cube face nearest the camera.
	local front = origin + rig.View.ZVector * (s.CubeHalf + 0.15)
	for _, crack in rig.Cracks do
		local u = (t - crack.At) / 0.16
		if u >= 0 and u < 1 then
			local dir = rig.View:VectorToWorldSpace(Vector3.new(math.cos(crack.Angle), math.sin(crack.Angle), 0))
			local center = front + rig.View:VectorToWorldSpace(Vector3.new(crack.Shift.X, crack.Shift.Y, 0))
			rig:Stretch(crack.Actor, center, dir, crack.Length * Kit.easeOut(u / 0.4), 1.6, Kit.smooth((u - 0.6) / 0.4))
		else
			rig:Hide(crack.Actor)
		end
	end
end

return Show
