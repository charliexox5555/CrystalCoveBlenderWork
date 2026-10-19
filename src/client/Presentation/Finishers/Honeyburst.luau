-- Honeyburst (honeyburst, Uncommon, Honey set): golden honeycomb cells assemble into a dome around the foe while
-- four glass bees orbit in, the comb flashes gold with a honey splash crown, the cells pop outward, the bees zoom
-- off on looping trails, and honey drips fall through hex sparkles.
local Kit = require(script.Parent.Kit)
local Modules = require(script.Parent.Modules)
local Show = {}

local AMBER, HONEY, CREAM = Color3.fromHex("#FFB92E"), Color3.fromHex("#C77A00"), Color3.fromHex("#FFF1C9")
local BEE_PARTS = {
	-- Mesh, native fallback, colour, material, transparency, offset from the bee centre (manifest centres).
	{ "BeeBody", Enum.PartType.Ball, Color3.fromHex("#FFD34E"), Enum.Material.Glass, 0.05, Vector3.new(0.09, 0, 0) },
	{ "BeeStripes", nil, Color3.fromHex("#5A3A1A"), Enum.Material.SmoothPlastic, 0, Vector3.new(-0.06, 0, 0) },
	{ "BeeWings", nil, Color3.fromHex("#E8F8FF"), Enum.Material.Glass, 0.35, Vector3.new(0.05, 0.52, 0) },
}

-- Ten cell positions on the upper dome: a ring of 7 and a cap of 3, outward normals.
local function domeNormals(count)
	local out = {}
	local ring = math.max(1, count - 3)
	for i = 1, ring do
		local a = (i - 0.5) / ring * math.pi * 2
		table.insert(out, Vector3.new(math.cos(a), 0.15, math.sin(a)).Unit)
	end
	for i = 1, count - ring do
		local a = (i - 0.5) / (count - ring) * math.pi * 2
		table.insert(out, Vector3.new(math.cos(a) * 0.6, 0.85, math.sin(a) * 0.6).Unit)
	end
	return out
end

function Show.build(rig, s)
	local random = Random.new(81)
	rig.Cells = {}
	local count = if rig.Low then 6 else s.Hexes
	for i, n in domeNormals(count) do
		table.insert(rig.Cells, {
			Actor = rig:Actor("HoneyHex", {
				Mesh = { "HoneyHex", "GuardPlate" },
				Size = s.HexSize,
				Color = AMBER,
				Material = Enum.Material.Glass,
				Transparency = 0.12,
				Reflectance = 0.25,
			}),
			Normal = n,
			Delay = (i - 1) / count * 0.2,
			Spin = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-1, 1), random:NextNumber(-1, 1)) * 7,
			Speed = random:NextNumber(7, 11),
		})
	end
	rig.Bees = {}
	for i = 1, (if rig.Low then 2 else s.Bees) do
		local bee = { Parts = {}, Phase = (i - 1) / s.Bees * math.pi * 2, Loop = random:NextNumber(0.8, 1.3) }
		for _, spec in BEE_PARTS do
			local actor = rig:Actor(spec[1], {
				Mesh = { spec[1] },
				Shape = spec[2],
				Size = s.BeeSize * (if spec[1] == "BeeBody" then 1 else (if spec[1] == "BeeWings" then 0.52 else 0.6)),
				Color = spec[3],
				Material = spec[4],
				Transparency = spec[5],
			})
			if actor.Fallback and spec[1] ~= "BeeBody" then
				-- Without the Blender bee, a single glass ball stands in.
				actor.Part:Destroy()
				table.remove(rig.Actors, #rig.Actors)
			else
				table.insert(
					bee.Parts,
					{ Actor = actor, Offset = spec[6] * (s.BeeSize / 1.02), Wings = spec[1] == "BeeWings" }
				)
			end
		end
		bee.Trail = rig:Trail(bee.Parts[1].Actor, { AMBER, CREAM }, 0.35, 0.3)
		table.insert(rig.Bees, bee)
	end
	rig.Crown = rig:Actor("HoneyCrown", {
		Mesh = { "FizzCrown", "SplashSheet" },
		Size = 2,
		Color = AMBER,
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		Reflectance = 0.2,
	})
	Modules.Flash(rig, { At = s.PeakAt, Size = s.FlashSize, Color = CREAM })
	Modules.Shockwave(rig, { At = s.PeakAt, Radius = s.RingRadius, Color = AMBER, Plane = "ground", Height = -3.4 })
	Modules.Light(rig, { At = s.PeakAt, Brightness = 3, Range = 14, Color = AMBER, Decay = 0.5 })
	Modules.ParticleField(rig, {
		Name = "HoneyDrips",
		Mode = "rain",
		At = s.PeakAt + 0.6,
		Until = s.PeakAt + 1.1,
		Count = s.Drips,
		Radius = 3.5,
		Height = 4,
		Emitter = {
			Texture = "Bubble",
			Color = { AMBER, HONEY },
			Size = { { 0, 0.25 }, { 0.6, 0.32 }, { 1, 0.1 } },
			Squash = { { 0, -0.6 }, { 1, -0.3 } },
			Lifetime = { 0.5, 0.7 },
			Speed = { 2, 4 },
			Acceleration = Vector3.new(0, -20, 0),
			LightEmission = 0.4,
		},
	})
	Modules.ParticleField(rig, {
		Name = "HexSparkles",
		Mode = "burst",
		At = s.PeakAt + 0.05,
		Count = s.Sparkles,
		Emitter = {
			Texture = "Hex",
			Color = { CREAM, AMBER },
			Size = { { 0, 0.6 }, { 1, 0 } },
			Lifetime = { 0.5, 0.9 },
			Speed = { 6, 12 },
			Drag = 3,
			RotSpeed = { -60, 60 },
		},
	})
end

function Show.step(rig, t, s)
	local origin = rig.Origin
	local after = t - s.PeakAt
	local released = after >= 0
	local charge = Kit.window(t, 0.32, s.PeakAt)
	local tail = Kit.smooth((after - 0.55) / 0.4)
	for _, cell in rig.Cells do
		local n = rig.View:VectorToWorldSpace(cell.Normal)
		local rest = n * s.DomeRadius + Vector3.yAxis * -0.6
		local cf, scale, alpha
		if not released then
			local u = Kit.clamp01((t - cell.Delay) / 0.24)
			local from = rest + n * 5 + Vector3.yAxis * 2
			local at = from:Lerp(rest, Kit.pop(u))
			cf = CFrame.lookAt(origin + at, origin + at + n) * CFrame.Angles(0, 0, (1 - u) * 2)
			scale = Kit.pop(u) * (1 - 0.06 * charge)
			alpha = 1 - Kit.smooth(u / 0.3)
			cell.Actor.Part.Material = if charge > 0.7 then Enum.Material.Neon else Enum.Material.Glass
			cell.Actor.Part.Color = AMBER:Lerp(CREAM, charge * 0.5)
		else
			local at = rest + n * cell.Speed * after + Vector3.yAxis * (3 * after - 7 * after * after)
			cf = CFrame.lookAt(origin + at, origin + at + n)
				* CFrame.Angles(cell.Spin.X * after, cell.Spin.Y * after, cell.Spin.Z * after)
			scale = 1 - 0.5 * tail
			alpha = tail
			cell.Actor.Part.Material = if after < 0.06 then Enum.Material.Neon else Enum.Material.Glass
			cell.Actor.Part.Color = AMBER
		end
		rig:Place(cell.Actor, cf, scale, alpha)
	end
	-- Bees: orbit in, circle the dome, then zoom off on looping paths.
	for _, bee in rig.Bees do
		local p, heading
		if not released then
			local u = Kit.clamp01(t / s.PeakAt)
			local radius = s.BeeOrbit * (2.2 - 1.2 * Kit.easeOut(u))
			local a = bee.Phase + t * 7
			p = Vector3.new(math.cos(a) * radius, 1.2 + 0.4 * math.sin(t * 9 + bee.Phase), math.sin(a) * radius)
			heading = Vector3.new(-math.sin(a), 0, math.cos(a))
		else
			local a = bee.Phase + s.PeakAt * 7
			local start = Vector3.new(math.cos(a) * s.BeeOrbit, 1.2, math.sin(a) * s.BeeOrbit)
			local out = Vector3.new(math.cos(a), 0.45, math.sin(a))
			local loop = Vector3.new(math.cos(after * 9 * bee.Loop), math.sin(after * 9 * bee.Loop), 0) * 1.2
			p = start + out * 9 * after + loop
			heading = (out + Vector3.new(-math.sin(after * 9), math.cos(after * 9), 0) * 0.5).Unit
		end
		local world = rig.View:PointToWorldSpace(p)
		local dir = rig.View:VectorToWorldSpace(heading)
		local fade = if released then Kit.smooth((after - 0.5) / 0.4) else 1 - math.min(1, t / 0.1)
		local base = CFrame.lookAt(world, world + dir) * CFrame.Angles(0, math.pi / 2, 0)
		local flap = math.sin(t * 70) * 0.35
		for _, part in bee.Parts do
			local cf = base * CFrame.new(part.Offset)
			if part.Wings then
				cf *= CFrame.Angles(flap, 0, 0)
			end
			rig:Place(part.Actor, cf, 1, fade)
		end
		if bee.Trail then
			bee.Trail.Enabled = released and fade < 0.8
		end
	end
	-- Honey splash crown at the peak.
	if released and after < 0.7 then
		local rise = Kit.easeOut(after / 0.22)
		local cf = CFrame.new(origin - Vector3.yAxis * 2.2) * CFrame.Angles(0, after * 1.4, 0)
		if rig.Crown.Template == "SplashSheet" or rig.Crown.Fallback then
			cf = rig.Facing * CFrame.new(0, -1.2, 0)
		end
		local scale = Vector3.new(0.6 + 0.4 * rise, 0.2 + 0.8 * rise, 0.6 + 0.4 * rise) * (s.CrownSize / 2)
		rig:Place(rig.Crown, cf, scale, Kit.smooth((after - 0.3) / 0.4))
	else
		rig:Hide(rig.Crown)
	end
end

return Show
