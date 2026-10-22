-- Daybreak (daybreak, Epic, Starter Pack Daybreak set, decision 117): dusk falls round the foe as Sunny the glass
-- rooster hops in and puffs up (gather); at the impact it crows, a glass sun bursts up from behind the foe with a fan
-- of rays and the foe breaks into dawn-coloured glass (peak and release); the sun climbs and fades into warm light
-- motes while Sunny bows and hops off (linger).
local Kit = require(script.Parent.Kit)
local Modules = require(script.Parent.Modules)
local Show = {}

local PEACH, ROSE, GOLD, LILAC = Color3.fromHex("#FF9E7A"), Color3.fromHex("#FF5D7E"), Color3.fromHex("#FFD45C"), Color3.fromHex("#C7A6FF")
local SUN, WHITE = Color3.fromHex("#FFF1B0"), Color3.new(1, 1, 1)

function Show.build(rig, s)
	rig.Rooster = rig:GlassyHero("sunny_rooster", s.RoosterHeight)
	if not rig.Rooster then
		rig.RoosterFallback = rig:Actor("RoosterFallback", {
			Mesh = { "NovaStar" },
			Size = s.RoosterHeight,
			Color = PEACH,
			Material = Enum.Material.Glass,
		})
	end
	-- Dusk horizon behind the foe: two long glowing bands (lilac sky over a rose glow).
	rig.Horizon = {
		rig:Actor("HorizonSky", {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(s.HorizonWidth, 0.9, 0.9),
			Color = LILAC,
			Transparency = 0.7,
		}),
		rig:Actor("HorizonGlow", {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(s.HorizonWidth * 0.8, 0.32, 0.32),
			Color = ROSE,
			Transparency = 0.4,
		}),
	}
	-- The glass sun and its rays.
	rig.Sun = rig:Actor("Sun", { Shape = Enum.PartType.Ball, Size = Vector3.one * s.SunSize, Color = GOLD, Transparency = 0.05 })
	rig.SunCore = rig:Actor("SunCore", { Shape = Enum.PartType.Ball, Size = Vector3.one * s.SunSize * 0.7, Color = SUN, Transparency = 0 })
	rig.Rays = {}
	for i = 1, (if rig.Low then 8 else s.Rays) do
		table.insert(rig.Rays, rig:Actor("SunRay", {
			Size = Vector3.new(0.35, 1, 0.12),
			Color = if i % 2 == 0 then PEACH else GOLD,
			Transparency = 0.15,
		}))
	end
	if rig.Rooster then
		for _, p in rig.Rooster.Parts do
			if p.Name == "TailFeather_3" then
				rig.Rooster.Trail = rig:Trail(p.Actor, { GOLD, ROSE, LILAC }, 0.3, 0.4)
			end
		end
	end
	-- Gather: warm motes drift in and up toward the foe.
	Modules.ParticleField(rig, {
		Name = "DawnMotes",
		Mode = "swirl",
		At = 0,
		Until = s.PeakAt,
		Count = s.Motes,
		Radius = 3.4,
		Spin = 6,
		Lift = 3,
		Emitter = {
			Texture = "SoftGlow",
			Color = { SUN, PEACH, ROSE },
			Size = { { 0, 0.2 }, { 0.5, 0.45 }, { 1, 0 } },
			Lifetime = { 0.4, 0.7 },
			Speed = { 0.5, 1.5 },
			LightEmission = 0.8,
		},
	})
	-- Peak: the crow and the sunrise.
	Modules.Flash(rig, { At = s.PeakAt, Size = s.FlashSize, Color = SUN, Seconds = 0.18 })
	Modules.Shockwave(rig, {
		At = s.PeakAt,
		Radius = s.RingRadius,
		Color = GOLD,
		Accent = ROSE,
		Plane = "ground",
		Height = s.Ground + 0.2,
		Count = 2,
	})
	Modules.Shockwave(rig, { At = s.PeakAt + 0.04, Radius = s.RingRadius * 0.7, Color = PEACH, Seconds = 0.45 })
	Modules.ShardBurst(rig, {
		Name = "DawnGlass",
		At = s.PeakAt + 0.02,
		Count = s.Shards,
		Mesh = { "CrystalShard" },
		Size = { 0.6, 1.1 },
		Tints = { ROSE, PEACH, GOLD, LILAC },
		Material = Enum.Material.Glass,
		Transparency = 0.2,
		Speed = { 9, 14 },
		Lift = 3,
		Gravity = 12,
		Drag = 0.8,
		Spin = 7,
		Trails = 4,
		TrailColor = GOLD,
		Fade = { At = 0.7, Seconds = 0.4 },
		Seed = 41,
	})
	rig:Emitter("SunGlints", {
		Texture = "StarGlint",
		Color = { WHITE, GOLD },
		Size = { { 0, 0.55 }, { 1, 0 } },
		Lifetime = { 0.5, 0.8 },
		Speed = { 10, 16 },
		Drag = 3,
	})
	rig:Burst(s.PeakAt, "SunGlints", s.Glints)
	Modules.Light(rig, {
		At = s.PeakAt,
		Brightness = s.LightBrightness,
		Range = s.LightRange,
		Color = Color3.fromHex("#FFC46B"),
		Rise = 0.2,
		Decay = 1.2,
		Offset = Vector3.new(0, s.Ground + s.SunRise * 0.6, -2),
	})
	-- Linger: warm light motes rising from the ground as the sun climbs.
	Modules.ParticleField(rig, {
		Name = "MorningMotes",
		Mode = "rise",
		At = s.PeakAt + 0.3,
		Until = s.Duration - 0.5,
		Count = s.RiseMotes,
		Radius = 4.5,
		Height = 3.5,
		Emitter = {
			Texture = "SoftGlow",
			Color = { SUN, GOLD, PEACH },
			Size = { { 0, 0 }, { 0.3, 0.4 }, { 1, 0 } },
			Lifetime = { 0.9, 1.3 },
			Speed = { 2, 3.5 },
			LightEmission = 1,
		},
	})
	rig.BeakSocket = rig:SocketPart("BeakSocket", Vector3.one * 0.6)
	rig:Emitter("CrowNotes", {
		Socket = rig.BeakSocket,
		Texture = "StarGlint",
		Color = { SUN, GOLD, ROSE },
		Size = { { 0, 0 }, { 0.3, 0.5 }, { 1, 0 } },
		Lifetime = { 0.4, 0.6 },
		Speed = { 4, 7 },
		Shape = Enum.ParticleEmitterShape.Sphere,
	})
	rig:Burst(s.PeakAt - 0.02, "CrowNotes", 12)
	rig:Burst(s.BowAt + 0.1, "CrowNotes", 8)
end

-- Sun centre in view space: rises from behind the ground line through the peak and keeps climbing slowly.
local function sunPoint(s, t)
	local a = t - s.PeakAt
	local burst = Kit.easeOut(Kit.clamp01(a / 0.35))
	local climb = Kit.clamp01((a - 0.35) / (s.Duration - s.PeakAt))
	return Vector3.new(0.6, s.Ground - s.SunSize * 0.3 + (s.SunRise + s.SunSize * 0.3) * burst + 0.8 * climb, -2.2)
end

function Show.step(rig, t, s)
	local after = t - s.PeakAt
	-- Dusk horizon: draws in through the gather, brightens at the peak, fades into day.
	local duskIn = Kit.smooth(t / 0.3)
	local dayOut = Kit.smooth((t - s.PeakAt - 0.6) / 0.7)
	for i, band in rig.Horizon do
		local y = s.Ground + (if i == 1 then 0.9 else 0.35)
		local cf = CFrame.new(rig:At(0, y, -2.6)) * rig.Facing.Rotation
		local glow = if after > 0 then 1 + 0.25 * math.exp(-after * 4) else 1
		rig:Place(band, cf, Vector3.new(0.6 + 0.4 * duskIn, glow, 1), math.max(1 - duskIn, dayOut))
	end
	-- Sun and rays.
	if after < 0 then
		rig:Hide(rig.Sun)
		rig:Hide(rig.SunCore)
		for _, ray in rig.Rays do
			rig:Hide(ray)
		end
	else
		local p = sunPoint(s, t)
		local world = rig:At(p.X, p.Y, p.Z)
		local fade = Kit.smooth((t - s.Duration + 0.75) / 0.6)
		local pulse = 1 + 0.06 * math.sin(after * 9) * (1 - fade)
		local grow = Kit.pop(Kit.clamp01(after / 0.3))
		rig:Place(rig.Sun, CFrame.new(world), grow * pulse, fade)
		rig:Place(rig.SunCore, CFrame.new(world - rig.View.LookVector * 0.2), grow * pulse, math.max(fade, 0.1))
		local length = s.RayLength * Kit.easeOut(Kit.clamp01(after / 0.4)) * (1 - 0.3 * fade)
		local spin = after * 0.35
		for i, ray in rig.Rays do
			local a = spin + (i - 1) / #rig.Rays * math.pi * 2
			local dir = (rig.View.RightVector * math.cos(a) + Vector3.yAxis * math.sin(a)).Unit
			local len = length * (if i % 2 == 0 then 0.72 else 1)
			local inner = s.SunSize * 0.62 * grow
			rig:Stretch(ray, world + dir * (inner + len / 2), dir, math.max(0.05, len), 1, math.max(fade, 0.15))
		end
	end
	-- Sunny: hops in from the left, puffs up, crows at the peak, bows, hops off.
	local spot = Vector3.new(-s.Spot, s.Ground, 0.4)
	local pos, yaw, pitch, alpha, hop = spot, -0.7, 0, 0, 0
	local wings = 0
	if t < s.PeakAt - 0.18 then
		local u = Kit.clamp01(t / (s.PeakAt - 0.18))
		pos = spot + Vector3.new(-4 * (1 - Kit.smooth(u)), 0, 0)
		hop = math.abs(math.sin(u * math.pi * 3)) * 0.7 * (1 - u)
		alpha = 1 - Kit.smooth(t / 0.08)
	elseif t < s.BowAt then
		local puff = Kit.smooth((t - s.PeakAt + 0.18) / 0.18)
		local crow = Kit.window(t, s.PeakAt - 0.02, s.PeakAt + 0.06) * (1 - Kit.window(t, s.PeakAt + 0.5, s.PeakAt + 0.7))
		pitch = -0.28 * puff * (1 - crow) + 0.18 * crow
		wings = math.max(puff * 0.5, crow)
		hop = 0.35 * crow * math.abs(math.sin(after * 10))
	elseif t < s.LeaveAt then
		local bow = Kit.smooth((t - s.BowAt) / 0.18) * (1 - Kit.smooth((t - s.LeaveAt + 0.12) / 0.12))
		pitch = 0.42 * bow
		yaw = -0.7 + 0.5 * bow
	else
		local u = Kit.clamp01((t - s.LeaveAt) / 0.4)
		pos = spot + Vector3.new(-4.5 * Kit.easeIn(u), 0, 0)
		yaw = 1.4
		hop = math.abs(math.sin(u * math.pi * 3)) * 0.7
		alpha = Kit.smooth((u - 0.6) / 0.4)
	end
	local half = s.RoosterHeight / 2
	local cf = CFrame.new(rig:At(pos.X, pos.Y + hop, pos.Z))
		* rig.Facing.Rotation
		* CFrame.Angles(0, yaw, 0)
		* CFrame.Angles(pitch, 0, 0)
		* CFrame.new(0, half, 0)
	if rig.Rooster then
		local flap = wings * 0.9
		rig:PlaceHero(rig.Rooster, cf, 1, alpha, {
			["^Wing_L"] = CFrame.Angles(0, 0, flap),
			["^Wing_R"] = CFrame.Angles(0, 0, -flap),
			["^TailFeather"] = CFrame.Angles(-0.25 * wings, 0, 0),
		})
		if rig.Rooster.Trail then
			rig.Rooster.Trail.Enabled = (t < s.PeakAt - 0.18 or t > s.LeaveAt) and alpha < 0.8
		end
	elseif rig.RoosterFallback then
		rig:Place(rig.RoosterFallback, cf, 1, alpha)
	end
	rig.BeakSocket.CFrame = cf * CFrame.new(0, half * 0.55, -half * 0.5)
end

return Show
