-- Starmane (starmane, Epic, Unicorn set): the Glass Unicorn gallops in along a rainbow bridge and lands beside the
-- foe, rears up as its horn fires a twisting rainbow column, stars and hearts rain down, it bows to the camera
-- (payoff pose) and gallops off up the fading rainbow.
local Kit = require(script.Parent.Kit)
local Modules = require(script.Parent.Modules)
local Show = {}

local PEARL, GOLD, WHITE = Color3.fromHex("#FFD6F5"), Color3.fromHex("#FFE07A"), Color3.new(1, 1, 1)
local RAINBOW = {
	Color3.fromHex("#FF8A8A"),
	Color3.fromHex("#FFC27A"),
	Color3.fromHex("#FFF08A"),
	Color3.fromHex("#9BF0A0"),
	Color3.fromHex("#8AD2FF"),
	Color3.fromHex("#C3A2FF"),
}

function Show.build(rig, s)
	rig.Unicorn = rig:GlassyHero("glass_unicorn", s.UnicornHeight)
	if not rig.Unicorn then
		rig.UnicornFallback = rig:Actor("UnicornFallback", {
			Mesh = { "NovaStar" },
			Size = s.UnicornHeight,
			Color = PEARL,
			Material = Enum.Material.Glass,
		})
	end
	rig.Bands = {}
	for i = 1, (if rig.Low then 3 else 5) do
		table.insert(rig.Bands, {
			Actor = rig:Actor("RainbowBand", {
				Mesh = { "RainbowArc", "HalfRing" },
				Size = s.BridgeRadius * 2 * (1 - (i - 1) * 0.07),
				Color = RAINBOW[i],
				Material = Enum.Material.Neon,
				Transparency = 0.25,
			}),
			Radius = s.BridgeRadius * (1 - (i - 1) * 0.07),
		})
	end
	if rig.Unicorn then
		rig.Unicorn.Trail = rig:Trail(rig.Unicorn.Parts[1].Actor, RAINBOW, 0.35, 0.9)
	end
	local spot = Vector3.new(-s.Spot, s.Ground, 0)
	Modules.Flash(
		rig,
		{ At = s.PeakAt, Size = 3.5, Color = WHITE, Offset = spot + Vector3.new(0.4, s.UnicornHeight + 0.2, 0) }
	)
	Modules.Shockwave(rig, {
		At = s.PeakAt,
		Radius = s.RingRadius,
		Color = PEARL,
		Accent = GOLD,
		Plane = "ground",
		Height = s.Ground + 0.2,
		Count = 2,
	})
	Modules.BeamColumn(rig, {
		At = s.PeakAt,
		Height = s.ColumnHeight,
		Width = s.ColumnWidth,
		Colors = RAINBOW,
		Rise = 0.16,
		Hold = 0.75,
		Fade = 0.45,
		Twist = 4,
		Offset = spot + Vector3.new(0.3, s.UnicornHeight * 0.95, 0),
	})
	Modules.ParticleField(rig, {
		Name = "HeartRain",
		Mode = "rain",
		At = s.PeakAt + 0.12,
		Until = s.PeakAt + 0.85,
		Count = s.Hearts,
		Radius = 4.5,
		Height = 9,
		Emitter = {
			Texture = "Heart",
			Color = { Color3.fromHex("#FF8FC8"), PEARL },
			Size = { { 0, 0.5 }, { 1, 0.35 } },
			Lifetime = { 0.8, 1.0 },
			Speed = { 6, 9 },
			RotSpeed = { -60, 60 },
			LightEmission = 0.6,
		},
	})
	Modules.ParticleField(rig, {
		Name = "StarRain",
		Mode = "rain",
		At = s.PeakAt + 0.12,
		Until = s.PeakAt + 0.85,
		Count = s.Stars,
		Radius = 4.5,
		Height = 9,
		Emitter = {
			Texture = "StarGlint",
			Color = { GOLD, WHITE },
			Size = { { 0, 0.6 }, { 1, 0.3 } },
			Lifetime = { 0.8, 1.0 },
			Speed = { 7, 10 },
			RotSpeed = { -120, 120 },
		},
	})
	rig.ManeSocket = rig:SocketPart("ManeSocket", Vector3.one * 1.6)
	rig:Emitter("ManeSparkle", {
		Socket = rig.ManeSocket,
		Texture = "StarGlint",
		Color = { WHITE, PEARL, GOLD },
		Size = { { 0, 0 }, { 0.3, 0.7 }, { 1, 0 } },
		Lifetime = { 0.3, 0.5 },
		Speed = { 0.5, 2 },
		Shape = Enum.ParticleEmitterShape.Sphere,
	})
	rig:Burst(s.BowAt + 0.12, "ManeSparkle", 14)
	rig:Burst(s.PeakAt, "ManeSparkle", 10)
end

-- Position along the bridge arc (angle pi = far left end, 0 = beside the foe), in view space.
local function arcPoint(s, angle)
	local center = Vector3.new(-s.Spot - s.BridgeRadius, s.Ground, 0)
	return center + Vector3.new(math.cos(angle) * s.BridgeRadius, math.sin(angle) * s.BridgeRadius, 0)
end

function Show.step(rig, t, s)
	local after = t - s.PeakAt
	-- Rainbow bridge: draws in, holds, fades as the unicorn leaves.
	local bridgeIn = Kit.smooth(t / 0.18)
	local bridgeOut = Kit.smooth((t - s.LeaveAt - 0.15) / 0.35)
	for _, band in rig.Bands do
		local center = Vector3.new(-s.Spot - s.BridgeRadius, s.Ground + band.Radius / 2, -0.4)
		local cf = CFrame.new(rig:At(center.X, center.Y, center.Z)) * rig.Facing.Rotation
		if band.Actor.Fallback or band.Actor.Template == "HalfRing" then
			cf *= CFrame.Angles(0, 0, math.pi)
		end
		local alpha = math.max(1 - bridgeIn, bridgeOut)
		rig:Place(band.Actor, cf, 1, alpha)
	end
	-- Unicorn path: gallop down the arc, rear at the peak, bow, gallop back up and away.
	local angle, yaw, pitch, alpha = math.pi, -1.0, 0, 0
	local hop = 0
	if t < s.PeakAt then
		local u = Kit.clamp01((t - 0.05) / (s.PeakAt - 0.12))
		angle = math.pi * (1 - Kit.smooth(u))
		hop = math.abs(math.sin(t * 22)) * 0.35 * (1 - u)
		pitch = -0.15 * (1 - u)
		alpha = 1 - Kit.smooth(t / 0.08)
	elseif t < s.BowAt then
		angle = 0
		local rear = math.sin(Kit.clamp01(after / 0.45) * math.pi)
		pitch = 0.55 * rear
		yaw = -1.0 + 0.4 * Kit.smooth(after / 0.5)
	elseif t < s.LeaveAt then
		angle = 0
		local bow = Kit.smooth((t - s.BowAt) / 0.2)
		yaw = -0.6 * (1 - bow)
		pitch = -0.35 * bow * (1 - Kit.smooth((t - s.LeaveAt + 0.12) / 0.12))
	else
		local u = Kit.clamp01((t - s.LeaveAt) / 0.4)
		angle = math.pi * 0.85 * Kit.easeIn(u)
		yaw = 1.2
		hop = math.abs(math.sin(t * 22)) * 0.3
		alpha = Kit.smooth((u - 0.55) / 0.45)
	end
	local p = arcPoint(s, angle) + Vector3.new(0, hop, 0.3)
	local world = rig:At(p.X, p.Y, p.Z)
	-- Pivot at the hooves: the hero is placed by its centre, so lift by half its height and pitch about the base.
	local half = s.UnicornHeight / 2
	local cf = CFrame.new(world)
		* rig.Facing.Rotation
		* CFrame.Angles(0, yaw, 0)
		* CFrame.Angles(pitch, 0, 0)
		* CFrame.new(0, half, 0)
	if rig.Unicorn then
		rig:PlaceHero(rig.Unicorn, cf, 1, alpha)
		if rig.Unicorn.Trail then
			rig.Unicorn.Trail.Enabled = (t < s.PeakAt - 0.05 or t > s.LeaveAt) and alpha < 0.8
		end
	elseif rig.UnicornFallback then
		rig:Place(rig.UnicornFallback, cf, 1, alpha)
	end
	rig.ManeSocket.CFrame = cf * CFrame.new(0, half * 0.6, 0)
end

return Show
