-- Hocus Pop (hocus_pop, Rare): the Potion Flask glassy swoops in, tips and pours three colours of magic smoke
-- that swirl round the foe faster and faster; a poof, and a crowned glass frog pops out, hops and ribbits, then
-- the green, pink and gold smoke puffs pop one after another and the frog sparkles away.
local Kit = require(script.Parent.Kit)
local Modules = require(script.Parent.Modules)
local Show = {}

local GREEN, PINK, GOLD = Color3.fromHex("#6CFF9A"), Color3.fromHex("#FF7AC8"), Color3.fromHex("#FFD34E")
local BREWS = { GREEN, PINK, GOLD }
local PUFF_SPOTS = { Vector3.new(-2.2, 1.0, 0.6), Vector3.new(0, 2.6, 0.6), Vector3.new(2.2, 1.0, 0.6) }

function Show.build(rig, s)
	rig.Flask = rig:GlassyHero("potion_flask", s.FlaskHeight)
	if not rig.Flask then
		rig.FlaskFallback = rig:Actor("PotionFallback", {
			Shape = Enum.PartType.Ball,
			Size = s.FlaskHeight * 0.7,
			Color = GREEN,
			Material = Enum.Material.Glass,
			Transparency = 0.2,
		})
	end
	local k = s.FrogSize / 1.48
	rig.Frog = rig:Actor("FrogBody", {
		Mesh = { "FrogBody" },
		Shape = Enum.PartType.Ball,
		Size = s.FrogSize,
		Color = GREEN,
		Material = Enum.Material.Glass,
		Transparency = 0.08,
		Reflectance = 0.25,
	})
	rig.Crown = rig:Actor("FrogCrown", {
		Mesh = { "FrogCrown", "NovaStar" },
		Size = 0.486 * k,
		Color = GOLD,
		Material = Enum.Material.Neon,
	})
	rig.CrownOffset = Vector3.new(0, 0.505 * k, 0.05 * k)
	for i, color in BREWS do
		Modules.ParticleField(rig, {
			Name = "Smoke" .. i,
			Mode = "swirl",
			At = 0.18 + (i - 1) * 0.03,
			Until = s.PeakAt,
			Count = s.Smoke,
			Radius = s.SmokeRadius,
			Spin = 7 + i,
			Lift = 1.5,
			Emitter = {
				Texture = "Puff",
				Color = { color, color:Lerp(Color3.new(1, 1, 1), 0.4) },
				Size = { { 0, 0.6 }, { 0.5, 1.3 }, { 1, 0.6 } },
				Transparency = { { 0, 0.2 }, { 0.7, 0.4 }, { 1, 1 } },
				Lifetime = { 0.45, 0.65 },
				Speed = { 0.5, 1.5 },
				LightEmission = 0.5,
				FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			},
		})
	end
	Modules.Flash(rig, { At = s.PeakAt, Size = s.FlashSize, Color = Color3.fromHex("#DFFFE9") })
	Modules.Shockwave(rig, { At = s.PeakAt, Radius = s.RingRadius, Color = GREEN, Accent = PINK, Count = 2 })
	Modules.Light(
		rig,
		{ At = s.PeakAt, Brightness = s.LightBrightness, Range = s.LightRange, Color = GREEN, Decay = 0.6 }
	)
	rig:Emitter("PoofBurst", {
		Texture = "Puff",
		Color = { GREEN, PINK, GOLD },
		Size = { { 0, 1.0 }, { 0.5, 2.0 }, { 1, 1.2 } },
		Transparency = { { 0, 0.1 }, { 0.6, 0.35 }, { 1, 1 } },
		Lifetime = { 0.45, 0.7 },
		Speed = { 6, 10 },
		Drag = 4,
		LightEmission = 0.5,
	})
	rig:Burst(s.PeakAt, "PoofBurst", 14)
	-- Chain-reaction puffs, each with its own little ring.
	rig.PuffSocket = rig:SocketPart("PuffSocket", Vector3.one * 0.2)
	for i, color in BREWS do
		rig:Emitter("Puff" .. i, {
			Socket = rig.PuffSocket,
			Texture = "Puff",
			Color = { color, color:Lerp(Color3.new(1, 1, 1), 0.5) },
			Size = { { 0, 0.8 }, { 0.5, 1.6 }, { 1, 0.8 } },
			Transparency = { { 0, 0.1 }, { 0.6, 0.35 }, { 1, 1 } },
			Lifetime = { 0.35, 0.5 },
			Speed = { 3, 6 },
			Drag = 5,
			LightEmission = 0.5,
		})
		rig:On(s.PuffAt[i], function(r)
			local spot = PUFF_SPOTS[i]
			r.PuffSocket.CFrame = CFrame.new(r:At(spot.X, spot.Y, spot.Z))
			local e = r.Emitters["Puff" .. i]
			if e then
				e:Emit(math.max(1, math.floor(10 * r.ParticleScale + 0.5)))
			end
		end)
		Modules.Shockwave(
			rig,
			{ At = s.PuffAt[i], Radius = 1.6, Seconds = 0.3, Color = color, Offset = PUFF_SPOTS[i], Mesh = { "Ring" } }
		)
	end
	rig.FrogSocket = rig:SocketPart("FrogSocket", Vector3.one * 0.2)
	rig:Emitter("Ribbit", {
		Socket = rig.FrogSocket,
		Texture = "StarGlint",
		Color = { Color3.new(1, 1, 1), GOLD },
		Size = { { 0, 0.8 }, { 1, 0 } },
		Lifetime = { 0.25, 0.45 },
		Speed = { 4, 8 },
		Drag = 5,
	})
	rig:On(0.88, function(r)
		local e = r.Emitters.Ribbit
		if e then
			e:Emit(math.max(1, math.floor(8 * r.ParticleScale + 0.5)))
		end
	end)
	rig:On(1.82, function(r)
		local e = r.Emitters.Ribbit
		if e then
			e:Emit(math.max(1, math.floor(12 * r.ParticleScale + 0.5)))
		end
	end)
end

function Show.step(rig, t, s)
	local after = t - s.PeakAt
	-- Flask: swoop in above the foe, tip to pour, then spin away.
	local offset, scale = Modules.reveal({
		Mode = "swoop",
		T0 = 0,
		T1 = 0.3,
		From = Vector3.new(-9, 7, -1),
		To = Vector3.new(0.8, 4.3, 0),
		Height = 2,
	}, t)
	local tip = Kit.smooth((t - 0.22) / 0.2) * 2.1
	local away = Kit.smooth((after - 0.05) / 0.45)
	local spin = away * 5
	local pos = rig:At(offset.X + away * 5, offset.Y + away * 3, offset.Z)
	local cf = CFrame.new(pos) * rig.Facing.Rotation * CFrame.Angles(0, spin, tip + spin * 0.4)
	local flaskAlpha = if t < 0.02 then 1 else away
	if rig.Flask then
		rig:PlaceHero(rig.Flask, cf, scale.X, flaskAlpha)
	elseif rig.FlaskFallback then
		rig:Place(rig.FlaskFallback, cf, scale, flaskAlpha)
	end
	-- Frog: pops up from the smoke at the peak, hops once, then sparkles away.
	if after < 0 or t > 2.0 then
		rig:Hide(rig.Frog)
		rig:Hide(rig.Crown)
		return
	end
	local grow = Kit.pop(after / 0.22)
	local hopU = Kit.clamp01((t - 0.78) / 0.32)
	local hop = math.sin(hopU * math.pi) * 1.4
	local squash = 0
	if t < 0.78 then
		squash = Kit.window(t, 0.66, 0.78) * 0.2
	elseif hopU >= 1 then
		squash = Kit.spring(t - 1.1, 30, 9) * 0.22
	else
		squash = -0.12 * math.sin(hopU * math.pi)
	end
	local leave = Kit.smooth((t - 1.72) / 0.25)
	local k = grow * (1 - leave)
	local s3 = Vector3.new(1 + squash * 0.6, 1 - squash, 1 + squash * 0.6) * k
	local frogPos = rig:At(0, -2.2 + hop, 1.7)
	local frogCf = CFrame.new(frogPos) * rig.Facing.Rotation * CFrame.Angles(0, math.sin(t * 3) * 0.15, 0)
	rig:Place(rig.Frog, frogCf, s3, leave)
	rig:Place(rig.Crown, frogCf * CFrame.new(rig.CrownOffset * s3), k, leave)
	rig.FrogSocket.CFrame = frogCf
end

return Show
