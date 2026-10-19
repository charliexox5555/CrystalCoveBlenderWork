-- Petalstorm (petalstorm, Rare): glass stems grow up in a ring round the foe and their buds swell, all six bloom at
-- once, the petals tear off into a rising vortex, then flutter down while the flowers chime and shrink in turn.
local Kit = require(script.Parent.Kit)
local Modules = require(script.Parent.Modules)
local Show = {}

local ROSE, SUN, LEAF = Color3.fromHex("#FF8FB8"), Color3.fromHex("#FFD84D"), Color3.fromHex("#7CD992")
local WARM = Color3.fromHex("#FFE3C2")

function Show.build(rig, s)
	rig.Flowers = {}
	local count = if rig.Low then 3 else s.Flowers
	for i = 1, count do
		local bloomColor = if i % 2 == 0 then SUN else ROSE
		table.insert(rig.Flowers, {
			Stem = rig:Actor("FlowerStem", {
				Mesh = { "FlowerStem" },
				Shape = Enum.PartType.Cylinder,
				NativeSize = Vector3.new(0.12, 1.6, 0.12),
				Size = s.StemHeight,
				Color = LEAF,
				Material = Enum.Material.Glass,
				Transparency = 0.1,
				Reflectance = 0.2,
			}),
			Bud = rig:Actor("FlowerBud", {
				Mesh = { "FlowerBud" },
				Shape = Enum.PartType.Ball,
				Size = s.BloomSize * 0.45,
				Color = bloomColor,
				Material = Enum.Material.Glass,
				Transparency = 0.1,
			}),
			Bloom = rig:Actor("FlowerBloom", {
				Mesh = { "FlowerBloom", "NovaStar" },
				Size = s.BloomSize,
				Color = bloomColor,
				Material = Enum.Material.Glass,
				Transparency = 0.05,
				Reflectance = 0.25,
			}),
			Angle = (i - 0.5) / count * math.pi * 2 + math.pi / 2,
			Delay = (i - 1) * 0.04,
			ChimeAt = s.ChimeAt + (i - 1) * s.ChimeStep,
		})
	end
	Modules.Flash(rig, { At = s.PeakAt, Size = s.FlashSize, Color = WARM })
	Modules.Shockwave(rig, {
		At = s.PeakAt,
		Radius = s.ShockRadius,
		Color = ROSE,
		Accent = SUN,
		Plane = "ground",
		Height = s.Ground + 0.2,
		Count = 2,
	})
	Modules.Light(rig, {
		At = s.PeakAt,
		Brightness = s.LightBrightness,
		Range = s.LightRange,
		Color = Color3.fromHex("#FFC98A"),
		Decay = 0.6,
	})
	Modules.ParticleField(rig, {
		Name = "PetalVortex",
		Mode = "swirl",
		At = s.PeakAt,
		Until = s.PeakAt + 0.65,
		Count = s.Vortex,
		Radius = s.RingRadius + 0.4,
		Spin = 10,
		Lift = 4,
		Emitter = {
			Texture = "Petal",
			Color = { ROSE, SUN, Color3.fromHex("#FFB3D1") },
			Size = { { 0, 0.45 }, { 1, 0.35 } },
			Transparency = { { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } },
			Lifetime = { 0.6, 0.9 },
			Speed = { 2, 4 },
			Acceleration = Vector3.new(0, 3, 0),
			RotSpeed = { -260, 260 },
			LightEmission = 0.2,
			LightInfluence = 0.4,
		},
	})
	Modules.ParticleField(rig, {
		Name = "PetalFlutter",
		Mode = "rain",
		At = 1.2,
		Until = 1.75,
		Count = s.Flutter,
		Radius = 5,
		Height = 5,
		Emitter = {
			Texture = "Petal",
			Color = { ROSE, SUN },
			Size = { { 0, 0.4 }, { 1, 0.3 } },
			Transparency = { { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } },
			Lifetime = { 0.7, 0.9 },
			Speed = { 1.5, 3 },
			Drag = 1,
			RotSpeed = { -200, 200 },
			LightEmission = 0.2,
			LightInfluence = 0.4,
		},
	})
	rig.ChimeSocket = rig:SocketPart("ChimeSocket", Vector3.one * 0.2)
	rig:Emitter("Chime", {
		Socket = rig.ChimeSocket,
		Texture = "StarGlint",
		Color = { Color3.new(1, 1, 1), SUN },
		Size = { { 0, 0.8 }, { 1, 0 } },
		Lifetime = { 0.2, 0.35 },
		Speed = { 4, 7 },
		Drag = 6,
	})
	for _, f in rig.Flowers do
		rig:On(f.ChimeAt, function(r)
			local e = r.Emitters.Chime
			if e and f.TopWorld then
				r.ChimeSocket.CFrame = CFrame.new(f.TopWorld)
				e:Emit(math.max(1, math.floor(6 * r.ParticleScale + 0.5)))
			end
		end)
	end
	rig:Emitter("BloomGlints", {
		Texture = "StarGlint",
		Color = { Color3.new(1, 1, 1), ROSE },
		Size = { { 0, 0.9 }, { 1, 0 } },
		Lifetime = { 0.3, 0.5 },
		Speed = { 8, 14 },
		Drag = 5,
	})
	rig:Burst(s.PeakAt, "BloomGlints", 18)
end

function Show.step(rig, t, s)
	local after = t - s.PeakAt
	local released = after >= 0
	local up = Vector3.yAxis
	local toCamera = rig.View.ZVector
	for _, f in rig.Flowers do
		local out = rig.View:VectorToWorldSpace(Vector3.new(math.cos(f.Angle), 0, math.sin(f.Angle)))
		local base = rig.Origin + out * s.RingRadius + up * s.Ground
		local u = Kit.clamp01((t - 0.05 - f.Delay) / 0.35)
		local grow = Kit.easeOut(u)
		local chime = Kit.smooth((t - f.ChimeAt) / 0.25)
		local keep = 1 - chime
		local height = s.StemHeight * grow * keep
		local lean = CFrame.fromAxisAngle(out:Cross(up).Unit, -0.12 + 0.05 * math.sin(t * 3 + f.Angle))
		local stemCf = CFrame.new(base)
			* lean
			* CFrame.new(0, height / 2, 0)
			* CFrame.lookAt(Vector3.zero, out:Cross(up))
		if f.Stem.Fallback then
			stemCf *= CFrame.Angles(0, 0, math.pi / 2)
		end
		rig:Place(f.Stem, stemCf, Vector3.new(keep, grow * keep, keep), if grow <= 0.01 then 1 else 0)
		local top = (CFrame.new(base) * lean * CFrame.new(0, height, 0)).Position
		f.TopWorld = top
		local face = (out * 0.5 + up * 0.7 + toCamera * 0.6).Unit
		if not released then
			-- Buds swell toward the peak.
			local swell = 0.5 + 0.7 * Kit.window(t, 0.2, s.PeakAt) + 0.06 * math.sin(t * 25)
			rig:Place(f.Bud, CFrame.lookAt(top, top + face), swell * grow, if grow <= 0.01 then 1 else 0)
			rig:Hide(f.Bloom)
		else
			rig:Hide(f.Bud)
			local open = Kit.pop(after / 0.18) * keep
			local cf = CFrame.lookAt(top, top + face) * CFrame.Angles(0, 0, after * 0.6)
			f.Bloom.Part.Material = if after < 0.06 then Enum.Material.Neon else Enum.Material.Glass
			rig:Place(f.Bloom, cf, open, chime)
		end
	end
end

return Show
