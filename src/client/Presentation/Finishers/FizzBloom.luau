-- Fizz Bloom (bubble_bloom, Rare): soda fizz rises, a giant shimmering bubble swells around the foe and wobbles,
-- pops in a splash crown, then a flower of bubbles blooms out and pops one after another.
local Kit = require(script.Parent.Kit)
local Show = {}

local MINT, PERI = Color3.fromHex("#80E8DA"), Color3.fromHex("#A9BBFF")
local IRIDESCENT = { MINT, Color3.fromHex("#D7B8FF"), Color3.fromHex("#FFD1B8"), PERI }

function Show.build(rig, s)
	local random = Random.new(37)
	rig.Bubble = rig:Actor("FizzBubble", {
		Shape = Enum.PartType.Ball,
		Size = 2,
		Color = MINT,
		Material = Enum.Material.ForceField,
		Transparency = 0,
	})
	rig.BubbleBody = rig:Actor("FizzBubbleBody", {
		Shape = Enum.PartType.Ball,
		Size = 2,
		Color = PERI,
		Material = Enum.Material.Glass,
		Transparency = 0.72,
		Reflectance = 0.3,
	})
	rig.Orbiters = {}
	for i = 1, (if rig.Low then 3 else s.Orbiters) do
		table.insert(rig.Orbiters, {
			Actor = rig:Actor("FizzOrbiter", {
				Shape = Enum.PartType.Ball,
				Size = random:NextNumber(0.7, 1.0),
				Color = IRIDESCENT[(i - 1) % #IRIDESCENT + 1],
				Material = Enum.Material.Glass,
				Transparency = 0.45,
				Reflectance = 0.3,
			}),
			Phase = i / s.Orbiters * math.pi * 2,
			Tilt = random:NextNumber(-0.6, 0.6),
		})
	end
	rig.Crown = rig:Actor("FizzCrown", {
		Mesh = { "FizzCrown", "SplashSheet" },
		Size = 2,
		Color = MINT,
		Material = Enum.Material.Glass,
		Transparency = 0.25,
		Reflectance = 0.2,
	})
	rig.Drops = rig:Actor("FizzDrops", { Mesh = { "FizzDrops" }, Size = 2, Color = Color3.fromHex("#E2FFFA") })
	if rig.Drops.Fallback then
		rig.Drops.Part:Destroy()
		table.remove(rig.Actors, #rig.Actors)
		rig.Drops = nil
	end
	rig.Ring = rig:Actor("FizzRing", { Mesh = { "Ring" }, Size = 2, Color = MINT, Transparency = 0.15 })
	rig.Flash = rig:Actor("FizzFlash", { Shape = Enum.PartType.Ball, Size = 1, Color = Color3.fromHex("#E8FFFB") })
	rig:Light(rig.Flash, MINT, s.LightRange)
	rig.Bloom = {}
	local count = if rig.Low then 6 else s.Bloom
	local inner = math.floor(count * 5 / 12 + 0.5)
	for i = 1, count do
		local ring = if i <= inner then 1 else 2
		local slot = if ring == 1 then i else i - inner
		local slots = if ring == 1 then inner else count - inner
		local angle = math.rad(90) + (slot - 1) / slots * math.pi * 2 + (if ring == 2 then math.pi / slots else 0)
		local radius = if ring == 1 then s.BloomRadius * 0.5 else s.BloomRadius
		local actor = rig:Actor("BloomBubble", {
			Shape = Enum.PartType.Ball,
			Size = random:NextNumber(1.2, 1.7) * (if ring == 1 then 0.9 else 1.1),
			Color = IRIDESCENT[(i - 1) % #IRIDESCENT + 1],
			Material = if i % 3 == 0 then Enum.Material.ForceField else Enum.Material.Glass,
			Transparency = if i % 3 == 0 then 0 else 0.5,
			Reflectance = 0.35,
		})
		local pop = {
			Actor = actor,
			Ring = ring,
			Offset = Vector3.new(
				math.cos(angle) * radius,
				math.sin(angle) * radius * 0.85 + 0.6,
				random:NextNumber(-0.8, 0.8)
			),
			Phase = random:NextNumber(0, math.pi * 2),
			PopAt = 0,
		}
		if not rig.Low then
			pop.Splash =
				rig:Actor("BloomPop", { Mesh = { "Ring" }, Size = 2, Color = Color3.new(1, 1, 1), Transparency = 0.2 })
		end
		table.insert(rig.Bloom, pop)
	end
	-- Pop order: inner ring first, then outward around the flower.
	for i, b in rig.Bloom do
		b.PopAt = s.PopStart + (i - 1) * s.PopStep * (12 / count)
	end
	rig.PopSocket = rig:SocketPart("PopSocket", Vector3.one * 0.2)
	rig:Emitter("Fizz", {
		Texture = "Bubble",
		Color = { Color3.new(1, 1, 1), MINT },
		Size = { { 0, 0.18 }, { 0.5, 0.42 }, { 1, 0.3 } },
		Transparency = { { 0, 0.1 }, { 0.8, 0.2 }, { 1, 1 } },
		Lifetime = { 0.55, 0.85 },
		Speed = { 5, 9 },
		Spread = 28,
		Offset = Vector3.new(0, -2.6, 0),
		RotSpeed = { -40, 40 },
		LightEmission = 0.4,
	})
	rig:Emitter("Droplets", {
		Texture = "Bubble",
		Color = { Color3.new(1, 1, 1), PERI },
		Size = { { 0, 0.5 }, { 1, 0.1 } },
		Lifetime = { 0.45, 0.7 },
		Speed = { 12, 20 },
		Acceleration = Vector3.new(0, -24, 0),
		Drag = 1.5,
		LightEmission = 0.5,
	})
	rig:Emitter("PopGlint", {
		Socket = rig.PopSocket,
		Texture = "StarGlint",
		Color = { Color3.new(1, 1, 1), MINT },
		Size = { { 0, 0.7 }, { 1, 0 } },
		Lifetime = { 0.18, 0.3 },
		Speed = { 4, 8 },
		Drag = 6,
	})
	for _, at in { 0, 0.14, 0.28, 0.4 } do
		rig:Burst(at, "Fizz", s.Fizz / 4)
	end
	rig:Burst(s.PeakAt, "Droplets", s.Droplets)
	for _, b in rig.Bloom do
		rig:On(b.PopAt, function(r)
			if r.Emitters.PopGlint and b.Actor.Part.Transparency < 1 then
				r.PopSocket.CFrame = b.Actor.Part.CFrame
				r.Emitters.PopGlint:Emit(math.max(1, math.floor(4 * r.ParticleScale + 0.5)))
			end
		end)
	end
end

function Show.step(rig, t, s)
	local origin = rig.Origin
	local after = t - s.PeakAt
	local released = after >= 0
	-- Big bubble: swells with an overshoot, jelly wobble growing toward the pop.
	if not released then
		local grow = Kit.pop(t / 0.42)
		local tension = Kit.window(t, 0.25, s.PeakAt)
		local w = 0.05 + 0.07 * tension
		local f = 9 + 9 * tension
		local wobble =
			Vector3.new(1 + w * math.sin(t * f), 1 + w * math.sin(t * f + 2.1), 1 + w * math.sin(t * f + 4.2))
		local radius = s.BubbleRadius * grow * (1 + 0.05 * tension)
		local cf = CFrame.new(origin) * CFrame.Angles(0, t * 1.4, 0)
		rig:Place(rig.Bubble, cf, wobble * radius, 0.15 * (1 - math.min(1, t / 0.15)))
		rig:Place(rig.BubbleBody, cf, wobble * radius * 0.98, 0)
		rig.Bubble.Part.Color = IRIDESCENT[1]:Lerp(IRIDESCENT[2], 0.5 + 0.5 * math.sin(t * 6))
	elseif after < 0.06 then
		rig:Place(rig.Bubble, CFrame.new(origin), s.BubbleRadius * (1.1 + after * 2), after / 0.06)
		rig:Hide(rig.BubbleBody)
	else
		rig:Hide(rig.Bubble)
		rig:Hide(rig.BubbleBody)
	end
	-- Orbiting bubbles spiral in and get swallowed.
	for _, o in rig.Orbiters do
		local u = Kit.clamp01(t / (s.PeakAt - 0.1))
		local radius = Kit.lerp(s.BubbleRadius * 2.2, s.BubbleRadius * 0.9, Kit.easeIn(u))
		local angle = o.Phase + t * (3 + 6 * u)
		local at = origin
			+ rig.View:VectorToWorldSpace(
				Vector3.new(
					math.cos(angle) * radius,
					math.sin(angle) * radius * 0.4 + o.Tilt,
					math.sin(angle) * radius * 0.6
				)
			)
		local scale = math.min(1, t / 0.12) * (1 - Kit.smooth((u - 0.85) / 0.15))
		rig:Place(o.Actor, CFrame.new(at), scale, 0)
	end
	-- Splash crown erupts upward from the pop.
	if released and after < 0.75 then
		local rise = Kit.easeOut(after / 0.22)
		local size = s.CrownSize
		local cf = CFrame.new(origin - Vector3.yAxis * s.BubbleRadius * 0.55) * CFrame.Angles(0, after * 1.5, 0)
		local scale = Vector3.new(0.6 + 0.4 * rise, 0.15 + 0.85 * rise, 0.6 + 0.4 * rise) * (size / 2)
		local fade = Kit.smooth((after - 0.3) / 0.45)
		if rig.Crown.Fallback or rig.Crown.Template == "SplashSheet" then
			cf = rig.Facing * CFrame.new(0, s.BubbleRadius * 0.2, 0)
		end
		rig:Place(rig.Crown, cf, scale, fade)
		if rig.Drops then
			rig:Place(rig.Drops, cf * CFrame.new(0, 0.15 * size * rise, 0), scale, fade)
		end
	else
		rig:Hide(rig.Crown)
		if rig.Drops then
			rig:Hide(rig.Drops)
		end
	end
	-- Horizontal ripple ring and flash.
	if released and after < 0.55 then
		local ringT = Kit.easeOut(after / 0.55)
		rig:Disc(rig.Ring, CFrame.new(origin) * CFrame.Angles(math.pi / 2, 0, 0), 1 + s.RingRadius * ringT, ringT)
	else
		rig:Hide(rig.Ring)
	end
	local flashT = after / 0.12
	if released and flashT < 1 then
		rig:Place(rig.Flash, CFrame.new(origin), 0.5 + s.FlashSize * Kit.easeOut(flashT), 0.3 + 0.7 * math.sqrt(flashT))
	else
		rig:Hide(rig.Flash)
	end
	for _, light in rig.Lights do
		light.Brightness = if released then s.LightBrightness * math.max(0, 1 - after / 0.5) else 0
	end
	-- Bloom: bubbles grow out into a flower, bob and drift up, then pop in order.
	for _, b in rig.Bloom do
		local open = Kit.pop((after - (b.Ring - 1) * 0.08) / 0.35)
		if not released or open <= 0 then
			rig:Hide(b.Actor)
			if b.Splash then
				rig:Hide(b.Splash)
			end
			continue
		end
		local bob = Vector3.new(0, math.sin(t * 3 + b.Phase) * 0.15 + after * 0.6, 0)
		local at = rig.View:PointToWorldSpace(b.Offset * open) + bob
		local popT = (t - b.PopAt) / 0.07
		if popT < 0 then
			local jiggle = 1 + 0.05 * math.sin(t * 11 + b.Phase)
			rig:Place(b.Actor, CFrame.new(at), open * jiggle, 0)
		elseif popT < 1 then
			rig:Place(b.Actor, CFrame.new(at), 1 + 0.25 * popT, popT)
		else
			rig:Hide(b.Actor)
		end
		if b.Splash then
			local splashT = (t - b.PopAt) / 0.22
			if splashT >= 0 and splashT < 1 then
				rig:Disc(b.Splash, CFrame.new(at) * rig.Facing.Rotation, 0.4 + 1.2 * Kit.easeOut(splashT), splashT, 0.6)
			else
				rig:Hide(b.Splash)
			end
		end
	end
end

return Show
