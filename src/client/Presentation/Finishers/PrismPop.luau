-- Prism Pop (glass_burst, Common): a dodecahedron shell of prism facets snaps shut around the foe, glows white,
-- and pops into rainbow glass with prism slivers and falling glitter. Timeline in Config/FinisherShows.
local Kit = require(script.Parent.Kit)
local Show = {}

local ICE, WHITE = Color3.fromHex("#7EDFF2"), Color3.new(1, 1, 1)
local PHI = (1 + math.sqrt(5)) / 2

-- The 12 face normals of a dodecahedron (the vertices of an icosahedron).
local NORMALS = {}
for _, v in
	{
		{ 0, 1, PHI },
		{ 0, -1, PHI },
		{ 0, 1, -PHI },
		{ 0, -1, -PHI },
		{ 1, PHI, 0 },
		{ -1, PHI, 0 },
		{ 1, -PHI, 0 },
		{ -1, -PHI, 0 },
		{ PHI, 0, 1 },
		{ -PHI, 0, 1 },
		{ PHI, 0, -1 },
		{ -PHI, 0, -1 },
	}
do
	table.insert(NORMALS, Vector3.new(v[1], v[2], v[3]).Unit)
end

function Show.build(rig, s)
	local random = Random.new(11)
	local inradius = s.ShellRadius * 0.85
	rig.Facets = {}
	local count = if rig.Low then 6 else s.Facets
	for i = 1, count do
		local tint = Kit.rainbow(i, s.Facets, 0.32, 1)
		local actor = rig:Actor("PrismFacet", {
			Mesh = { "PrismFacet", "GuardPlate" },
			Size = s.FacetSize * 2,
			Color = tint,
			Material = Enum.Material.Glass,
			Transparency = 0.18,
			Reflectance = 0.15,
		})
		local normal = NORMALS[(i - 1) % #NORMALS + 1]
		table.insert(rig.Facets, {
			Actor = actor,
			Tint = tint,
			Normal = normal,
			Inradius = inradius,
			Delay = (i - 1) / count * 0.14,
			Swirl = random:NextNumber(0.8, 1.6) * (if i % 2 == 0 then 1 else -1),
			Spin = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-1, 1), random:NextNumber(-1, 1)) * s.Spin,
			Speed = s.BurstSpeed * random:NextNumber(0.75, 1.2),
			Lift = random:NextNumber(2, 5),
		})
	end
	rig.Slivers = {}
	for i = 1, (if rig.Low then 3 else s.Slivers) do
		table.insert(
			rig.Slivers,
			rig:Actor("PrismSliver", {
				Mesh = { "PrismSliver", "CrystalShard" },
				Size = 1,
				Color = Kit.rainbow(i, s.Slivers, 0.55, 1),
			})
		)
	end
	rig.Flash = rig:Actor("PrismFlash", { Shape = Enum.PartType.Ball, Size = 1, Color = WHITE })
	rig.Ring = rig:Actor("PrismRing", { Mesh = { "ShockCrown", "Ring" }, Size = 2, Color = ICE, Transparency = 0.1 })
	rig:Emitter("Glints", {
		Texture = "StarGlint",
		Color = { WHITE, ICE, Color3.fromHex("#C9B8FF") },
		Size = { { 0, 1.1 }, { 0.3, 0.8 }, { 1, 0 } },
		Lifetime = { 0.35, 0.6 },
		Speed = { 14, 24 },
		Drag = 5,
		RotSpeed = { -200, 200 },
	})
	rig:Emitter("Glitter", {
		Texture = "StarGlint",
		Color = { Color3.fromHex("#FFB3E6"), Color3.fromHex("#FFF3A8"), Color3.fromHex("#A8FFE8"), ICE },
		Size = { { 0, 0.35 }, { 0.5, 0.3 }, { 1, 0 } },
		Transparency = { { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } },
		Lifetime = { 0.75, 1.1 },
		Speed = { 3, 8 },
		Acceleration = Vector3.new(0, -7, 0),
		Drag = 1.2,
	})
	rig.Seams = rig:SocketPart("ShellSocket", Vector3.one * s.ShellRadius * 1.7)
	rig:Emitter("Seams", {
		Socket = rig.Seams,
		Texture = "StarGlint",
		Color = WHITE,
		Size = { { 0, 0 }, { 0.3, 0.7 }, { 1, 0 } },
		Lifetime = { 0.2, 0.32 },
		Speed = { 0.2, 0.6 },
		Shape = Enum.ParticleEmitterShape.Sphere,
	})
	rig:Burst(0.22, "Seams", 8)
	rig:Burst(s.PeakAt - 0.08, "Seams", 10)
	rig:Burst(s.PeakAt, "Glints", s.Burst)
	rig:Burst(s.PeakAt + 0.12, "Glitter", s.Glitter)
end

function Show.step(rig, t, s)
	local origin = rig.Origin
	rig.Seams.CFrame = CFrame.new(origin)
	local peak = s.PeakAt
	local after = t - peak
	local released = after >= 0
	-- Charge: the shell tightens and brightens toward white just before the pop.
	local charge = Kit.window(t, 0.26, peak)
	local tail = Kit.smooth((after - 0.55) / (s.Duration - peak - 0.65))
	for _, f in rig.Facets do
		local p = f.Actor.Part
		local rest = f.Normal * f.Inradius * (1 - 0.07 * charge)
		local cf, scale, alpha
		if not released then
			local u = Kit.clamp01((t - f.Delay) / 0.24)
			local swirl = CFrame.fromAxisAngle(Vector3.yAxis, (1 - u) * f.Swirl)
			local from = swirl:VectorToWorldSpace(f.Normal) * s.GatherRadius
			local at = from:Lerp(rest, Kit.pop(u))
			local rot = CFrame.lookAt(Vector3.zero, -f.Normal)
				* CFrame.Angles(f.Spin.X * (1 - u) * 0.3, f.Spin.Y * (1 - u) * 0.3, 0)
			cf = CFrame.new(origin + at) * rot
			-- Snap squash as each facet locks in, then the whole shell squeezes on the charge.
			local snap = Kit.spring(t - f.Delay - 0.24, 40, 14) * 0.12
			scale = (0.4 + 0.6 * Kit.easeOut(u)) * (1 + (if u >= 1 then snap else 0))
			alpha = 1 - Kit.smooth(u / 0.35)
			p.Color = f.Tint:Lerp(Color3.new(1, 1, 1), charge * 0.7)
			p.Material = if charge > 0.55 or (u >= 1 and t - f.Delay - 0.24 < 0.05)
				then Enum.Material.Neon
				else Enum.Material.Glass
		else
			local at = rest
				+ f.Normal * f.Speed * after
				+ Vector3.yAxis * (f.Lift * after - 0.5 * s.Gravity * after * after)
			cf = CFrame.new(origin + at)
				* CFrame.lookAt(Vector3.zero, -f.Normal)
				* CFrame.Angles(f.Spin.X * after, f.Spin.Y * after, f.Spin.Z * after)
			scale = 1 - 0.55 * tail
			alpha = tail
			p.Color = f.Tint
			p.Material = if after < 0.06 then Enum.Material.Neon else Enum.Material.Glass
		end
		rig:Place(f.Actor, cf, scale, alpha)
	end
	-- Prism slivers fan out in the view plane, then retract and fade.
	for i, sliver in rig.Slivers do
		if not released then
			rig:Hide(sliver)
			continue
		end
		local angle = math.rad(30 + (i - 1) * 360 / #rig.Slivers) + after * 0.6
		local dir = rig.View:VectorToWorldSpace(Vector3.new(math.cos(angle), math.sin(angle), 0))
		local grow = Kit.easeOut(after / 0.12) * (1 - Kit.smooth((after - 0.22) / 0.3))
		local length = s.SliverLength * grow
		local center = origin + dir * (0.8 + length / 2 + after * 2)
		rig:Stretch(sliver, center, dir, length, 2.6, Kit.smooth((after - 0.25) / 0.25))
	end
	-- Flash and ring at the pop.
	local flashT = after / 0.14
	if released and flashT < 1 then
		rig:Place(
			rig.Flash,
			CFrame.new(origin),
			0.5 + s.FlashSize * Kit.easeOut(flashT),
			0.15 + 0.85 * math.sqrt(flashT)
		)
	else
		rig:Hide(rig.Flash)
	end
	if released and after < 0.5 then
		local ringT = Kit.easeOut(after / 0.5)
		rig:Disc(rig.Ring, rig.Facing, 1 + s.RingRadius * ringT, ringT)
	else
		rig:Hide(rig.Ring)
	end
end

return Show
