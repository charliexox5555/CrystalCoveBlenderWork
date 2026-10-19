-- Supernova (starfall, Legendary): stars spiral into a glass star core inside a spinning stained-glass halo,
-- everything hushes, then a white-gold supernova: ray blades, double shockwaves, a shower of shooting stars,
-- stardust and one last twinkle. The only standard finisher with a (brief, restrained) colour grade.
local Kit = require(script.Parent.Kit)
local Show = {}

local VIOLET, ROSE, GOLD = Color3.fromHex("#A995FF"), Color3.fromHex("#FFAFE9"), Color3.fromHex("#FFE9A8")
local WHITE = Color3.new(1, 1, 1)
local STAR_COLORS = { VIOLET, ROSE, GOLD, Color3.fromHex("#8FE8FF"), WHITE }

function Show.build(rig, s)
	local random = Random.new(53)
	rig.Core = rig:Actor("StarCore", { Mesh = { "StarCore", "NovaStar" }, Size = s.CoreSize, Color = GOLD })
	rig.CoreGlow = rig:Actor("StarCoreGlow", {
		Shape = Enum.PartType.Ball,
		Size = s.CoreSize * 0.9,
		Color = ROSE,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
	})
	rig.Halo = rig:Actor("StarHalo", {
		Mesh = { "StarHaloBand", "Ring" },
		Size = 2,
		Color = VIOLET,
		Material = Enum.Material.Glass,
		Transparency = 0.1,
		Reflectance = 0.2,
	})
	rig.HaloGems = rig:Actor("StarHaloGems", { Mesh = { "StarHaloGems" }, Size = 2.2, Color = ROSE })
	if rig.HaloGems.Fallback then
		rig.HaloGems.Part:Destroy()
		table.remove(rig.Actors, #rig.Actors)
		rig.HaloGems = nil
	end
	rig.Stars = {}
	for i = 1, (if rig.Low then 3 else s.Stars) do
		local star = {
			Actor = rig:Actor("SpiralStar", { Mesh = { "NovaStar" }, Size = s.StarSize, Color = STAR_COLORS[i] }),
			Phase = (i - 1) / s.Stars * math.pi * 2,
		}
		star.Trail = rig:Trail(star.Actor, { STAR_COLORS[i], WHITE }, 0.28, 0.5)
		star.Beam = rig:Beam(star.Actor, rig.Core, { STAR_COLORS[i], WHITE }, 0.28)
		table.insert(rig.Stars, star)
	end
	rig.Rays = {}
	for i = 1, (if rig.Low then 4 else s.Rays) do
		table.insert(rig.Rays, {
			Actor = rig:Actor("NovaRay", {
				Mesh = { "NovaRay", "CrystalShard" },
				Size = 1,
				Color = if i % 3 == 0 then ROSE elseif i % 3 == 1 then WHITE else GOLD,
			}),
			Angle = math.rad(22.5 + (i - 1) * 360 / (if rig.Low then 4 else s.Rays)),
			Length = if i % 2 == 0 then 0.6 else 1,
		})
	end
	rig.Flash = rig:Actor("NovaFlash", { Shape = Enum.PartType.Ball, Size = 1, Color = WHITE })
	rig.ShockA =
		rig:Actor("NovaShock", { Mesh = { "ShockCrown", "Ring" }, Size = 2, Color = VIOLET, Transparency = 0.05 })
	rig.ShockB =
		rig:Actor("NovaShockFlat", { Mesh = { "ShockCrown", "Ring" }, Size = 2, Color = ROSE, Transparency = 0.1 })
	rig:Light(rig.Flash, GOLD, s.LightRange)
	rig.Shower = {}
	for i = 1, (if rig.Low then 5 else s.ShowerStars) do
		local a = (i - 1) / s.ShowerStars * math.pi * 2 + random:NextNumber(-0.2, 0.2)
		local shooting = {
			Actor = rig:Actor("ShootingStar", {
				Mesh = { "NovaStar" },
				Size = random:NextNumber(0.5, 0.75),
				Color = Kit.rainbow(i, s.ShowerStars, 0.4, 1),
			}),
			Dir = Vector3.new(math.cos(a), math.sin(a) * 0.8 + 0.35, random:NextNumber(-0.6, 0.6)).Unit,
			Speed = s.ShowerSpeed * random:NextNumber(0.8, 1.25),
			Spin = random:NextNumber(4, 9) * (if i % 2 == 0 then 1 else -1),
		}
		if i % 2 == 1 then
			shooting.Trail = rig:Trail(shooting.Actor, { shooting.Actor.Part.Color, WHITE }, 0.3, 0.3)
		end
		table.insert(rig.Shower, shooting)
	end
	rig.Twinkle = rig:Actor("LastTwinkle", { Mesh = { "NovaStar" }, Size = 0.9, Color = WHITE })
	rig:Emitter("Glints", {
		Texture = "StarGlint",
		Color = { WHITE, GOLD, ROSE },
		Size = { { 0, 1.3 }, { 0.4, 0.9 }, { 1, 0 } },
		Lifetime = { 0.4, 0.7 },
		Speed = { 16, 28 },
		Drag = 4.5,
		RotSpeed = { -180, 180 },
	})
	rig:Emitter("Dust", {
		Texture = "Dust",
		Color = { VIOLET, ROSE, GOLD },
		Size = { { 0, 0.5 }, { 0.5, 0.9 }, { 1, 0.2 } },
		Transparency = { { 0, 0.3 }, { 0.7, 0.4 }, { 1, 1 } },
		Lifetime = { 0.9, 1.4 },
		Speed = { 2, 6 },
		Drag = 1.2,
		Acceleration = Vector3.new(0, 1.2, 0),
		LightEmission = 0.8,
	})
	rig.ChargeShell = rig:SocketPart("ChargeShell", Vector3.one * 7)
	rig:Emitter("Charge", {
		Texture = "StarGlint",
		Color = { GOLD, WHITE },
		Size = { { 0, 0.15 }, { 1, 0.5 } },
		Transparency = { { 0, 1 }, { 0.3, 0.2 }, { 1, 0 } },
		Lifetime = { 0.25, 0.35 },
		Speed = { -16, -12 }, -- inward: spawned on a shell, flying to the core
		Shape = Enum.ParticleEmitterShape.Sphere,
		Socket = rig.ChargeShell,
	})
	rig.TwinkleSocket = rig:SocketPart("TwinkleSocket", Vector3.one * 0.2)
	rig:Emitter("TwinkleGlint", {
		Socket = rig.TwinkleSocket,
		Texture = "StarGlint",
		Color = WHITE,
		Size = { { 0, 0.9 }, { 1, 0 } },
		Lifetime = { 0.2, 0.3 },
		Speed = { 3, 6 },
		Drag = 5,
	})
	rig:Burst(0.1, "Charge", 10)
	rig:Burst(0.3, "Charge", 12)
	rig:Burst(s.PeakAt, "Glints", s.Glints)
	rig:Burst(s.PeakAt + 0.1, "Dust", s.Dust)
	rig:Burst(s.TwinkleAt, "TwinkleGlint", 8)
end

local function grade(rig, t, s)
	local g = s.Grade
	local cc = rig:Grade()
	if not cc then
		return
	end
	local after = t - s.PeakAt
	if after < 0 then
		local dim = Kit.smooth(t / s.PeakAt)
		cc.Brightness, cc.Contrast = g.DimBrightness * dim, 0
		cc.Saturation, cc.TintColor = g.DimSaturation * dim, Color3.new(1, 1, 1)
	elseif after < g.PeakSeconds + g.FadeSeconds then
		local k = if after < g.PeakSeconds then 1 else 1 - Kit.smooth((after - g.PeakSeconds) / g.FadeSeconds)
		cc.Brightness, cc.Contrast = g.PeakBrightness * k, g.PeakContrast * k
		cc.Saturation = g.DimSaturation * k
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromHex(g.PeakTint), k)
	else
		rig:DropGrade()
	end
end

function Show.step(rig, t, s)
	local origin = rig.Origin
	local after = t - s.PeakAt
	local released = after >= 0
	local hush = Kit.window(t, s.HushAt, s.PeakAt)
	rig.ChargeShell.CFrame = CFrame.new(origin)
	if t < s.PeakAt + s.Grade.PeakSeconds + s.Grade.FadeSeconds then
		grade(rig, t, s)
	end
	-- Core: heartbeat that speeds up, shrinks in the hush, bursts at the peak.
	local beat = 6 * t + 14 * t * t
	if not released then
		local grow = Kit.pop(t / 0.3)
		local pulse = 1 + 0.14 * math.sin(beat) * (1 - hush)
		local k = grow * pulse * (1 - 0.45 * hush)
		local cf = CFrame.new(origin) * rig.Facing.Rotation * CFrame.Angles(t * 0.8, t * 1.6, t * 0.5)
		rig:Place(rig.Core, cf, k, 0)
		rig:Place(rig.CoreGlow, CFrame.new(origin), k * (1.1 + 0.2 * math.sin(beat)), 0.2 + 0.5 * hush)
	elseif after < 0.3 then
		local k = 1.6 + after * 3
		rig:Place(rig.Core, CFrame.new(origin) * rig.Facing.Rotation, k, after / 0.3)
		rig:Place(rig.CoreGlow, CFrame.new(origin), k * 1.3, after / 0.3)
	else
		rig:Hide(rig.Core)
		rig:Hide(rig.CoreGlow)
	end
	-- Halo: tilted stained-glass ring that spins up, tightens in the hush, then rings out.
	local haloRadius, haloAlpha
	if not released then
		haloRadius = s.HaloRadius * Kit.pop(t / 0.35) * (1 - 0.3 * hush)
		haloAlpha = 0
	else
		haloRadius = s.HaloRadius * (0.7 + 1.7 * Kit.easeOut(after / 0.6))
		haloAlpha = Kit.smooth(after / 0.6)
	end
	local spin = t * 2 + t * t * 4
	local haloCf = CFrame.new(origin) * rig.Facing.Rotation * CFrame.Angles(0.35, 0, spin)
	if haloAlpha < 1 then
		rig:Disc(rig.Halo, haloCf, haloRadius, haloAlpha, 1.4)
		if rig.HaloGems then
			rig:Disc(rig.HaloGems, haloCf, haloRadius * 1.1, haloAlpha, 1.4)
		end
	else
		rig:Hide(rig.Halo)
		if rig.HaloGems then
			rig:Hide(rig.HaloGems)
		end
	end
	-- Spiral stars: in from far out, swallowed by the core at the hush.
	for _, star in rig.Stars do
		local u = Kit.clamp01(t / s.HushAt)
		if u >= 1 then
			rig:Hide(star.Actor)
			if star.Trail then
				star.Trail.Enabled = false
			end
			if star.Beam then
				star.Beam.Enabled = false
			end
			continue
		end
		local radius = s.StarStartRadius * (1 - Kit.easeIn(u))
		local angle = star.Phase + 1.8 * t + 5 * t * t
		local at = rig:At(math.cos(angle) * radius, math.sin(angle) * radius * 0.75, math.sin(angle * 0.5) * 1.2)
		local cf = CFrame.new(at) * rig.Facing.Rotation * CFrame.Angles(0, 0, t * 6)
		rig:Place(star.Actor, cf, Kit.pop(t / 0.15) * (1 - 0.6 * u), 0)
		if star.Trail then
			star.Trail.Enabled = t > 0.03
		end
		if star.Beam then
			star.Beam.Enabled = t > 0.15
		end
	end
	-- Peak: flash, ray blades, double shock.
	local flashT = after / 0.16
	if released and flashT < 1 then
		rig:Place(rig.Flash, CFrame.new(origin), 0.6 + s.FlashSize * Kit.easeOut(flashT), 0.1 + 0.9 * math.sqrt(flashT))
	else
		rig:Hide(rig.Flash)
	end
	for _, light in rig.Lights do
		light.Brightness = if released
			then s.LightBrightness * math.max(0, 1 - after / 0.6)
			else 1.5 * Kit.smooth(t / s.PeakAt)
	end
	for _, ray in rig.Rays do
		if not released or after > 0.7 then
			rig:Hide(ray.Actor)
			continue
		end
		local grow = Kit.easeOut(after / 0.1) * (1 - Kit.smooth((after - 0.25) / 0.45))
		local angle = ray.Angle + after * 0.5
		local dir = rig.View:VectorToWorldSpace(Vector3.new(math.cos(angle), math.sin(angle), 0))
		local length = s.RayLength * ray.Length * grow
		rig:Stretch(ray.Actor, origin + dir * (0.4 + length / 2), dir, length, 3, Kit.smooth((after - 0.35) / 0.35))
	end
	if released and after < 0.55 then
		local a = Kit.easeOut(after / 0.55)
		rig:Disc(rig.ShockA, rig.Facing, 1 + s.ShockRadius * a, a, 1.2)
	else
		rig:Hide(rig.ShockA)
	end
	if released and after > 0.04 and after < 0.7 then
		local b = Kit.easeOut((after - 0.04) / 0.66)
		rig:Disc(rig.ShockB, CFrame.new(origin) * CFrame.Angles(math.pi / 2, 0, 0), 1 + s.ShockRadius * 1.2 * b, b, 1.2)
	else
		rig:Hide(rig.ShockB)
	end
	-- Shooting-star shower.
	local fade = Kit.smooth((after - 0.6) / 0.5)
	for _, st in rig.Shower do
		if not released or fade >= 1 then
			rig:Hide(st.Actor)
			if st.Trail then
				st.Trail.Enabled = false
			end
			continue
		end
		local dir = rig.View:VectorToWorldSpace(st.Dir)
		local k = 2.2
		local travel = (1 - math.exp(-k * after)) / k
		local at = origin + dir * st.Speed * travel * 1.6 - Vector3.yAxis * 0.5 * s.Gravity * after * after
		local cf = CFrame.new(at) * rig.Facing.Rotation * CFrame.Angles(0, 0, st.Spin * after)
		rig:Place(st.Actor, cf, Kit.pop(after / 0.12) * (1 - 0.5 * fade), fade)
		if st.Trail then
			st.Trail.Enabled = after > 0.02 and fade < 0.7
		end
	end
	-- Last twinkle in the centre.
	local twinkleIn = t - (s.TwinkleAt - 0.45)
	if twinkleIn >= 0 and t < s.TwinkleAt + 0.08 then
		local pulse = 0.6 + 0.4 * math.abs(math.sin(twinkleIn * 14))
		local popT = (t - s.TwinkleAt) / 0.08
		local k = Kit.pop(twinkleIn / 0.15) * pulse * (if popT > 0 then 1 + popT else 1)
		rig.TwinkleSocket.CFrame = CFrame.new(origin + Vector3.yAxis * 0.5)
		rig:Place(
			rig.Twinkle,
			CFrame.new(origin + Vector3.yAxis * 0.5) * rig.Facing.Rotation * CFrame.Angles(0, 0, t * 3),
			k,
			math.max(0, popT)
		)
	else
		rig:Hide(rig.Twinkle)
	end
end

return Show
