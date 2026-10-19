-- Emberwing (emberwing, Mythic, Phoenix set): embers swirl up while the Glass Phoenix circles twice; at the impact
-- (P) a ring and ember burst, the phoenix climbs and the world warms to sunset as a ring of fire-glass runes
-- spreads; a hush, then the second peak (P2): the phoenix dives into the foe, a sunfire column erupts with a
-- double shockwave, twelve glowing feathers spiral out, the grade eases away and the phoenix rises and flies off.
-- Signature shatter: the shards of the winner's glassy that just broke over the foe glow ember at P2.
local Kit = require(script.Parent.Kit)
local Modules = require(script.Parent.Modules)
local Show = {}

local EMBER, GOLD, CORE = Color3.fromHex("#FF7A2E"), Color3.fromHex("#FFD34E"), Color3.fromHex("#B8321A")
local WHITE = Color3.new(1, 1, 1)

function Show.build(rig, s)
	rig.Phoenix = rig:GlassyHero("glass_phoenix", s.PhoenixHeight)
	if not rig.Phoenix then
		rig.PhoenixFallback = rig:Actor("PhoenixFallback", {
			Mesh = { "NovaStar" },
			Size = s.PhoenixHeight,
			Color = EMBER,
			Material = Enum.Material.Neon,
		})
	else
		-- Sunfire trails from the wing tips (well, the wing parts) while it circles and dives.
		rig.PhoenixTrails = {}
		for _, p in rig.Phoenix.Parts do
			if p.Name == "Wing_L" or p.Name == "Wing_R" or p.Name == "TailFeather_2" then
				local trail = rig:Trail(p.Actor, { GOLD, EMBER, CORE }, 0.35, 0.5)
				if trail then
					table.insert(rig.PhoenixTrails, trail)
				end
			end
		end
	end
	rig.Runes = rig:Actor("RuneRing", {
		Mesh = { "RuneRing", "ShockCrown" },
		Size = 2,
		Color = GOLD,
		Material = Enum.Material.Neon,
		Transparency = 0.1,
	})
	-- Per-play state for the signature shatter (FinisherFX.attachShards hands the winner's shards over).
	rig:AddStep(function() end, function()
		rig.ShardsLit = false
		rig.ExternalShards = nil
	end)
	Modules.ParticleField(rig, {
		Name = "EmberSwirl",
		Mode = "swirl",
		At = 0,
		Until = s.PeakAt,
		Count = s.Embers,
		Radius = 3.2,
		Spin = 9,
		Lift = 4,
		Emitter = {
			Texture = "Ember",
			Color = { GOLD, EMBER, CORE },
			Size = { { 0, 0.3 }, { 0.5, 0.45 }, { 1, 0 } },
			Lifetime = { 0.5, 0.8 },
			Speed = { 1, 3 },
			Acceleration = Vector3.new(0, 5, 0),
		},
	})
	-- P: the impact.
	Modules.Shockwave(
		rig,
		{ At = s.PeakAt, Radius = s.ShockRadius * 0.7, Color = EMBER, Plane = "ground", Height = s.Ground + 0.2 }
	)
	Modules.Flash(rig, { At = s.PeakAt, Size = s.FlashSize * 0.6, Color = Color3.fromHex("#FFE6C2") })
	rig:Emitter("EmberBurst", {
		Texture = "Ember",
		Color = { GOLD, EMBER },
		Size = { { 0, 0.6 }, { 1, 0 } },
		Lifetime = { 0.4, 0.7 },
		Speed = { 12, 20 },
		Drag = 4,
	})
	rig:Burst(s.PeakAt, "EmberBurst", 26)
	-- P2: the dive.
	Modules.Flash(rig, { At = s.Peak2At, Size = s.FlashSize, Color = WHITE, Seconds = 0.18 })
	Modules.Shockwave(rig, {
		At = s.Peak2At,
		Radius = s.ShockRadius,
		Color = GOLD,
		Accent = EMBER,
		Plane = "ground",
		Height = s.Ground + 0.2,
		Count = 2,
	})
	Modules.Shockwave(rig, { At = s.Peak2At + 0.03, Radius = s.ShockRadius * 0.8, Color = EMBER, Seconds = 0.55 })
	Modules.BeamColumn(rig, {
		At = s.Peak2At,
		Height = s.ColumnHeight,
		Width = s.ColumnWidth,
		Colors = { WHITE, GOLD, EMBER, CORE },
		CoreColor = GOLD,
		Rise = 0.14,
		Hold = 0.55,
		Fade = 0.5,
		Twist = 3,
		Offset = Vector3.new(0, s.Ground, 0),
	})
	Modules.Light(
		rig,
		{ At = s.Peak2At, Brightness = s.LightBrightness, Range = s.LightRange, Color = EMBER, Rise = 0.5, Decay = 0.7 }
	)
	Modules.ShardBurst(rig, {
		Name = "SunFeather",
		At = s.Peak2At + 0.04,
		Count = s.Feathers,
		Mesh = { "SunFeatherPlate", "CrystalShard" },
		Size = { 1.0, 1.4 },
		Tints = { GOLD, EMBER, Color3.fromHex("#FFB067") },
		Material = Enum.Material.Neon,
		Transparency = 0.05,
		Speed = s.FeatherSpeed,
		Lift = 4,
		Gravity = 5,
		Drag = 1.4,
		Spin = 5,
		Trails = 4,
		TrailColor = GOLD,
		From = function(i, count)
			return Vector3.new(0, -1 + (i / count) * 4, 0)
		end,
		Dir = function(i, count)
			local a = i / count * math.pi * 4
			return Vector3.new(math.cos(a), 0.55, math.sin(a)).Unit
		end,
		Fade = { At = 0.6, Seconds = 0.4 },
		Seed = 33,
	})
	Modules.ParticleField(rig, {
		Name = "FeatherDrift",
		Mode = "rain",
		At = 1.9,
		Until = 2.5,
		Count = s.FeatherDrift,
		Radius = 5,
		Height = 7,
		Emitter = {
			Texture = "Feather",
			Color = { GOLD, EMBER },
			Size = { { 0, 0.55 }, { 1, 0.35 } },
			Lifetime = { 0.7, 0.9 },
			Speed = { 2, 4 },
			Drag = 1,
			RotSpeed = { -120, 120 },
			LightEmission = 0.7,
		},
	})
end

-- Mythic sunset grade: warms from P, brightens briefly on P2, eases out by Grade.End.
local function grade(rig, t, s)
	local g = s.Grade
	if t < g.Start or t > g.End then
		if t > g.End then
			rig:DropGrade()
		end
		return
	end
	local cc = rig:Grade()
	if not cc then
		return
	end
	local k = Kit.smooth((t - g.Start) / (g.Full - g.Start)) * (1 - Kit.smooth((t - g.EaseFrom) / (g.End - g.EaseFrom)))
	local flash = math.max(0, 1 - math.abs(t - s.Peak2At) / 0.12)
	cc.Brightness = g.Brightness * k + g.Peak2Brightness * flash
	cc.Saturation = g.Saturation * k
	cc.Contrast = 0.06 * k
	cc.TintColor = WHITE:Lerp(Color3.fromHex(g.Tint), k)
end

function Show.step(rig, t, s)
	grade(rig, t, s)
	-- Phoenix flight: orbit twice, climb to the apex after P, fold and dive at P2, rise out of the column, fly off.
	local p, look, fold, alpha
	if t < s.PeakAt then
		local offset = Modules.reveal(
			{ Mode = "orbit", T0 = 0, T1 = s.PeakAt, Radius = s.OrbitRadius, Height = s.OrbitHeight, Turns = 2 },
			t
		)
		p = offset
		local a = 2 * math.pi * 2 * (t / s.PeakAt)
		look = Vector3.new(-math.sin(a), 0.1, math.cos(a))
		fold = 0
		alpha = 1 - Kit.smooth(t / 0.1)
	elseif t < s.HushAt then
		local u = Kit.smooth((t - s.PeakAt) / (s.HushAt - s.PeakAt))
		p = Vector3.new(s.OrbitRadius * (1 - u), s.OrbitHeight + (s.ApexHeight - s.OrbitHeight) * u, 0)
		look = Vector3.new(-0.3, 1, 0.2)
		fold = u
		alpha = 0
	elseif t < s.Peak2At then
		local u = Kit.easeIn((t - s.HushAt) / (s.Peak2At - s.HushAt))
		p = Vector3.new(0, s.ApexHeight * (1 - u), 0)
		look = Vector3.new(0, -1, 0.05)
		fold = 1
		alpha = 0
	elseif t < 1.95 then
		p = Vector3.new(0, 0, 0)
		look = Vector3.new(0, -1, 0.05)
		fold = 1
		alpha = 1 -- inside the column
	else
		local u = Kit.clamp01((t - 1.95) / 0.85)
		p = Vector3.new(2 * u, 2 + 9 * u, -1.5 * u)
		look = Vector3.new(0.35, 1, -0.2)
		fold = 0
		alpha = math.max(1 - Kit.clamp01(u / 0.12), Kit.smooth((u - 0.6) / 0.4))
	end
	local world = rig.View:PointToWorldSpace(p)
	local dir = rig.View:VectorToWorldSpace(look).Unit
	local up = if math.abs(dir.Y) > 0.95 then rig.View.ZVector else Vector3.yAxis
	local cf = CFrame.lookAt(world, world + dir, up)
	if rig.Phoenix then
		local flap = if fold > 0.5 then 0 else math.sin(t * 16) * 0.5
		local wing = 0.9 * fold
		rig:PlaceHero(rig.Phoenix, cf, 1, alpha, {
			["^Wing.*_L$"] = CFrame.Angles(0, 0, flap - wing),
			["^Wing.*_R$"] = CFrame.Angles(0, 0, -flap + wing),
		})
		for _, trail in rig.PhoenixTrails or {} do
			trail.Enabled = alpha < 0.8 and (t < s.PeakAt or (t > s.HushAt and t < s.Peak2At) or t > 2.0)
		end
	elseif rig.PhoenixFallback then
		rig:Place(rig.PhoenixFallback, cf, 1, alpha)
	end
	-- Rune ring: spreads on the ground through the world change, flares at P2, fades.
	local spread = Kit.easeOut((t - s.PeakAt - 0.05) / 0.5)
	if t > s.PeakAt and t < s.Peak2At + 0.7 then
		local flare = if t >= s.Peak2At then 1 + 0.4 * Kit.easeOut((t - s.Peak2At) / 0.3) else 1
		local alphaR = Kit.smooth((t - s.Peak2At - 0.25) / 0.45)
		local cf2 = CFrame.new(rig:At(0, s.Ground + 0.1, 0)) * CFrame.Angles(math.pi / 2, 0, t * 0.8)
		rig:Disc(rig.Runes, cf2, s.RuneRadius * spread * flare, alphaR, 1.5)
	else
		rig:Hide(rig.Runes)
	end
	-- Signature shatter: the winner's glassy shards glow ember for a moment at P2.
	if rig.ExternalShards and t >= s.Peak2At and not rig.ShardsLit then
		rig.ShardsLit = true
		for _, shard in rig.ExternalShards do
			if shard.Parent and shard:IsA("BasePart") then
				shard.Color = EMBER:Lerp(shard.Color, 0.35)
				shard.Material = Enum.Material.Neon
			end
		end
	end
end

return Show
