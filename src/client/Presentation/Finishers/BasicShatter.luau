-- Basic Shatter (decision 95): what you get with no finisher equipped. In a fight there is no show at all (the
-- winner's glassy flies in and simply breaks); this short show only exists so the inventory tile and preview
-- can show that plain glass break: a clear glass bubble wobbles, cracks white and bursts into tumbling shards.
local Kit = require(script.Parent.Kit)
local Modules = require(script.Parent.Modules)
local Show = {}

local GLASS, WHITE = Color3.fromHex("#CFEFF7"), Color3.new(1, 1, 1)

function Show.build(rig, s)
	rig.Glass = rig:Actor("PlainGlass", {
		Shape = Enum.PartType.Ball,
		Size = s.GlassSize,
		Color = GLASS,
		Material = Enum.Material.Glass,
		Transparency = 0.35,
		Reflectance = 0.3,
	})
	Modules.Flash(rig, { At = s.PeakAt, Size = 3, Color = WHITE, Seconds = 0.12 })
	Modules.ShardBurst(rig, {
		Name = "PlainShard",
		At = s.PeakAt,
		Count = s.Shards,
		Mesh = { "CrystalShard", "CrystalChip" },
		Size = { 0.6, 1.1 },
		Tints = { GLASS, WHITE },
		Speed = { 6, 10 },
		Lift = 3,
		Gravity = 18,
		Fade = { At = 0.6, Seconds = 0.35 },
		Seed = 4,
	})
	rig:Emitter("Glints", {
		Texture = "StarGlint",
		Color = { WHITE, GLASS },
		Size = { { 0, 0.7 }, { 1, 0 } },
		Lifetime = { 0.25, 0.4 },
		Speed = { 8, 14 },
		Drag = 5,
	})
	rig:Burst(s.PeakAt, "Glints", 10)
end

function Show.step(rig, t, s)
	if t >= s.PeakAt then
		rig:Hide(rig.Glass)
		return
	end
	local wobble = 1 + 0.06 * math.sin(t * 40) * Kit.window(t, 0, s.PeakAt)
	rig.Glass.Part.Material = if t > s.PeakAt - 0.05 then Enum.Material.Neon else Enum.Material.Glass
	rig:Place(rig.Glass, CFrame.new(rig.Origin), Kit.pop(t / 0.1) * wobble, 0)
end

return Show
