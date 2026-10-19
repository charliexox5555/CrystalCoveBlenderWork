-- Piñata Pop (party_burst, Uncommon): a stained-glass piñata star drops in on a ribbon, squashes, wiggles faster
-- and faster, then bursts into confetti, candy-glass gems with streamers and paper curls.
local Kit = require(script.Parent.Kit)
local Show = {}

local PINK, BUTTER = Color3.fromHex("#F9ADDA"), Color3.fromHex("#FFE790")
local POINT_COLORS = {
	Color3.fromHex("#FF8FC8"),
	Color3.fromHex("#FFD86B"),
	Color3.fromHex("#7FE3F0"),
	Color3.fromHex("#B9A2FF"),
	Color3.fromHex("#9BF08A"),
}
local CANDY = {
	Color3.fromHex("#FF6FAE"),
	Color3.fromHex("#FFB547"),
	Color3.fromHex("#6FD8FF"),
	Color3.fromHex("#9E7BFF"),
	Color3.fromHex("#7BE68C"),
}
local CONFETTI = {
	{ Color3.fromHex("#FF7FBF"), Color3.fromHex("#FFC2E0") },
	{ Color3.fromHex("#FFD65A"), Color3.fromHex("#FFF0A8") },
	{ Color3.fromHex("#5ED8F5"), Color3.fromHex("#B8F2FF") },
	{ Color3.fromHex("#A98BFF"), Color3.fromHex("#DCCFFF") },
}

function Show.build(rig, s)
	local random = Random.new(23)
	local star = rig:Group("Pinata")
	rig.Star = star
	rig.Core = rig:Actor("PinataCore", {
		Mesh = { "PinataCore" },
		Shape = Enum.PartType.Cylinder,
		Size = 1.6 * s.StarScale,
		NativeSize = Vector3.new(0.7, 1.6, 1.6),
		Color = BUTTER,
		Material = Enum.Material.Glass,
		Transparency = 0.08,
		Reflectance = 0.2,
		Parent = star,
	})
	rig.Points = {}
	for i = 1, 5 do
		local angle = math.rad(90 + (i - 1) * 72)
		table.insert(rig.Points, {
			Actor = rig:Actor("PinataPoint", {
				Mesh = { "PinataPoint", "Thorn" },
				Size = 1.25 * s.StarScale,
				Color = POINT_COLORS[i],
				Material = Enum.Material.Glass,
				Transparency = 0.06,
				Reflectance = 0.2,
				Parent = star,
			}),
			Angle = angle,
			Spin = random:NextNumber(-8, 8),
		})
	end
	rig.Ribbon = rig:Actor("PinataRibbon", {
		Size = Vector3.new(0.12, 1, 0.12),
		Color = PINK,
		Material = Enum.Material.SmoothPlastic,
	})
	rig.StarOutline = rig:Outline(star, Color3.new(1, 1, 1))
	rig.Gems = {}
	for i = 1, (if rig.Low then 5 else s.Gems) do
		local a = random:NextNumber(-0.85, 0.85) * math.pi * 0.5
		local gem = {
			Actor = rig:Actor("CandyGem", {
				Mesh = { "CandyGem", "Droplet" },
				Shape = Enum.PartType.Ball,
				Size = random:NextNumber(0.9, 1.25),
				Color = CANDY[(i - 1) % #CANDY + 1],
				Material = Enum.Material.Glass,
				Transparency = 0.05,
				Reflectance = 0.25,
			}),
			Dir = Vector3.new(math.sin(a), math.cos(a) * 0.9 + 0.35, random:NextNumber(-0.5, 0.5)).Unit,
			Speed = s.GemSpeed * random:NextNumber(0.75, 1.2),
			Spin = Vector3.new(random:NextNumber(-9, 9), random:NextNumber(-9, 9), random:NextNumber(-9, 9)),
		}
		if i <= s.Streamers then
			gem.Trail = rig:Trail(gem.Actor, { gem.Actor.Part.Color, Color3.new(1, 1, 1) }, 0.35, 0.35)
		end
		table.insert(rig.Gems, gem)
	end
	rig.Curls = {}
	for i = 1, (if rig.Low then 3 else s.Curls) do
		local a = random:NextNumber(0, math.pi * 2)
		table.insert(rig.Curls, {
			Actor = rig:Actor("ConfettiCurl", {
				Mesh = { "ConfettiCurl" },
				Size = 1.1,
				NativeSize = Vector3.new(0.35, 0.9, 0.08),
				Color = Kit.rainbow(i, s.Curls, 0.6, 1),
				Material = Enum.Material.SmoothPlastic,
			}),
			Dir = Vector3.new(math.cos(a), 1.3, math.sin(a)).Unit,
			Speed = s.GemSpeed * random:NextNumber(0.9, 1.4),
			Phase = random:NextNumber(0, math.pi * 2),
		})
	end
	rig.Flash = rig:Actor("PinataFlash", { Shape = Enum.PartType.Ball, Size = 1, Color = Color3.fromHex("#FFF7D6") })
	rig.Ring = rig:Actor("PinataRing", { Mesh = { "Ring" }, Size = 2, Color = PINK, Transparency = 0.1 })
	for i, pair in CONFETTI do
		rig:Emitter("Confetti" .. i, {
			Texture = "Confetti",
			Color = pair,
			Size = { { 0, 0.42 }, { 1, 0.36 } },
			Transparency = { { 0, 0 }, { 0.85, 0 }, { 1, 1 } },
			Lifetime = { 1.0, 1.3 },
			Speed = { s.ConfettiSpeed * 0.55, s.ConfettiSpeed },
			Spread = 62,
			Acceleration = Vector3.new(0, -16, 0),
			Drag = 2.4,
			RotSpeed = { -320, 320 },
			LightEmission = 0.15,
			LightInfluence = 0.4,
			FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookStartRandom = true,
		})
		rig:Burst(s.PeakAt, "Confetti" .. i, s.Confetti / #CONFETTI)
	end
	rig:Emitter("Sparks", {
		Texture = "StarGlint",
		Color = { Color3.new(1, 1, 1), BUTTER },
		Size = { { 0, 0.8 }, { 1, 0 } },
		Lifetime = { 0.25, 0.45 },
		Speed = { 12, 20 },
		Drag = 4,
	})
	rig:Burst(0.32, "Sparks", 5)
	rig:Burst(0.44, "Sparks", 6)
	rig:Burst(s.PeakAt, "Sparks", 18)
end

local function starPose(rig, t, s)
	local drop = Kit.clamp01(t / s.DropSeconds)
	local fall = (1 - Kit.easeIn(drop)) * s.DropHeight
	local land = t - s.DropSeconds
	-- Stretch while falling, squash on landing, spring back.
	local stretchY, stretchXZ = 1, 1
	if land < 0 then
		stretchY, stretchXZ = 1 + 0.18 * drop, 1 - 0.08 * drop
	else
		local spring = Kit.spring(land, 30, 9)
		stretchY, stretchXZ = 1 - 0.25 * spring, 1 + 0.16 * spring
	end
	-- Wiggle faster and harder, inflating a little before the burst.
	local wiggle = Kit.window(t, s.DropSeconds + 0.05, s.PeakAt)
	local freq = 16 + 26 * wiggle
	local tilt = math.sin(t * freq) * s.WiggleAngle * wiggle
	local inflate = 1 + 0.12 * wiggle
	local pose = rig.Facing * CFrame.new(0, fall, 0) * CFrame.Angles(0, 0, tilt)
	return pose, Vector3.new(stretchXZ, stretchY, stretchXZ) * inflate
end

function Show.step(rig, t, s)
	local after = t - s.PeakAt
	local released = after >= 0
	local pose, squash = starPose(rig, math.min(t, s.PeakAt), s)
	local tail = Kit.smooth((after - 0.75) / (s.Duration - s.PeakAt - 0.85))
	local coreRadius = rig.Core.Base.Y / 2
	-- Core: pops bigger and fades at the burst.
	if not released then
		local grow = Kit.pop(t / 0.12)
		local coreCf = if rig.Core.Fallback then pose * CFrame.Angles(0, math.pi / 2, 0) else pose
		rig:Place(rig.Core, coreCf, squash * grow, 0)
	elseif after < 0.12 then
		rig:Place(rig.Core, pose, squash * (1 + after * 4), after / 0.12)
	else
		rig:Hide(rig.Core)
	end
	for _, pt in rig.Points do
		local radial = Vector3.new(math.cos(pt.Angle), math.sin(pt.Angle), 0)
		local length = pt.Actor.Base[pt.Actor.Axis]
		local offset = radial * (coreRadius * 0.7 + length / 2) * squash
		local local_ = CFrame.new(offset) * CFrame.Angles(0, 0, pt.Angle - math.pi / 2)
		if not released then
			rig:Place(pt.Actor, pose * local_, squash * Kit.pop(t / 0.12), 0)
		else
			local fly = radial * (s.PointSpeed * after) + Vector3.new(0, 3 * after - 0.5 * s.Gravity * after * after, 0)
			local cf = pose * CFrame.new(fly) * local_ * CFrame.Angles(pt.Spin * after * 0.3, 0, pt.Spin * after)
			rig:Place(pt.Actor, cf, 1 - 0.5 * tail, tail)
		end
	end
	if rig.StarOutline then
		rig.StarOutline.Enabled = not released
		rig.StarOutline.OutlineTransparency = 0.6 - 0.6 * Kit.window(t, s.DropSeconds, s.PeakAt)
	end
	-- Ribbon from the star's top up out of frame; snaps at the burst.
	if not released then
		local top = pose:PointToWorldSpace(Vector3.new(0, coreRadius + 1.2 * s.StarScale, 0))
		local length = 9
		rig:Place(
			rig.Ribbon,
			CFrame.new(top + Vector3.yAxis * length / 2) * rig.View.Rotation,
			Vector3.new(1, length, 1),
			0
		)
	elseif after < 0.25 then
		local top = rig.Origin + Vector3.yAxis * (coreRadius + 1.2 * s.StarScale + 4.5 + after * 14)
		rig:Place(rig.Ribbon, CFrame.new(top) * rig.View.Rotation, Vector3.new(1, 9 * (1 - after * 2), 1), after / 0.25)
	else
		rig:Hide(rig.Ribbon)
	end
	-- Candy gems arc out, streamers trailing.
	for _, g in rig.Gems do
		if not released then
			rig:Hide(g.Actor)
			if g.Trail then
				g.Trail.Enabled = false
			end
			continue
		end
		local dir = rig.View:VectorToWorldSpace(g.Dir)
		local at = rig.Origin + dir * g.Speed * after - Vector3.yAxis * 0.5 * s.Gravity * after * after
		local cf = CFrame.new(at) * CFrame.Angles(g.Spin.X * after, g.Spin.Y * after, g.Spin.Z * after)
		rig:Place(g.Actor, cf, Kit.pop(after / 0.1) * (1 - 0.4 * tail), tail)
		if g.Trail then
			g.Trail.Enabled = after > 0.02 and tail < 0.8
		end
	end
	-- Paper curls flutter: fast launch, heavy drag, slow wobbly fall.
	for _, c in rig.Curls do
		if not released then
			rig:Hide(c.Actor)
			continue
		end
		local dir = rig.View:VectorToWorldSpace(c.Dir)
		local k = 3.2
		local travel = (1 - math.exp(-k * after)) / k
		local wobble = Vector3.new(math.sin(after * 7 + c.Phase), 0, math.cos(after * 6 + c.Phase)) * 0.35
		local at = rig.Origin + dir * c.Speed * travel - Vector3.yAxis * 2.2 * after * after + wobble
		local cf = CFrame.new(at) * CFrame.Angles(after * 9 + c.Phase, after * 5, math.sin(after * 8 + c.Phase))
		rig:Place(c.Actor, cf, 1, tail)
	end
	local flashT = after / 0.13
	if released and flashT < 1 then
		rig:Place(
			rig.Flash,
			CFrame.new(rig.Origin),
			0.5 + s.FlashSize * Kit.easeOut(flashT),
			0.2 + 0.8 * math.sqrt(flashT)
		)
	else
		rig:Hide(rig.Flash)
	end
	if released and after < 0.45 then
		local ringT = Kit.easeOut(after / 0.45)
		rig:Disc(rig.Ring, rig.Facing, 1 + s.RingRadius * ringT, ringT)
	else
		rig:Hide(rig.Ring)
	end
end

return Show
