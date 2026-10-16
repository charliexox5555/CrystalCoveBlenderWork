-- Editable original-texture VFX kit only. No map placement, scripts, catalog or sales changes.
assert(not game:GetService("RunService"):IsRunning(), "Build art in Edit")
local library = game.ReplicatedStorage.Assets.VFX
assert(not library:FindFirstChild("HollowlightPrototype"), "Preserve the existing artist prototype")
local kit = Instance.new("Model")
kit.Name = "HollowlightPrototype"
kit:SetAttribute("PrototypeOnly", true)
kit:SetAttribute("BaseGlassy", "pop")
kit:SetAttribute("DurationSeconds", 1.7)
local root = Instance.new("Part")
root.Name, root.Size, root.Transparency = "Origin", Vector3.one * 0.1, 1
root.Anchored, root.CanCollide, root.CanTouch, root.CanQuery = true, false, false, false
root.Parent = kit
kit.PrimaryPart = root
local source = {}
for _, x in library:GetDescendants() do
	if x:IsA("ParticleEmitter") or x:IsA("Beam") then
		source[x.Name] = x
	end
end
local mint, amber, violet = Color3.fromRGB(137, 255, 204), Color3.fromRGB(255, 164, 65), Color3.fromRGB(137, 88, 228)
local origin = Instance.new("Attachment")
origin.Name = "EmitterOrigin"
origin.Parent = root
local function layer(name, from, count, start, lifetime, speed, size, transparency)
	local p = source[from]:Clone()
	p.Name, p.Enabled, p.Rate = name, false, 0
	p.Lifetime, p.Speed, p.Size, p.Transparency = lifetime, speed, size, transparency
	p.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, mint),
		ColorSequenceKeypoint.new(0.4, amber),
		ColorSequenceKeypoint.new(1, violet),
	})
	p.LightEmission, p.LightInfluence = 0.65, 0
	p:SetAttribute("BurstCount", count)
	p:SetAttribute("PhaseStart", start)
	p.Parent = origin
	return p
end
local charge = layer(
	"ChargeWisps",
	"ContactGlint",
	6,
	0.05,
	NumberRange.new(0.35, 0.55),
	NumberRange.new(0.4, 0.8),
	NumberSequence.new(0.09),
	NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
)
charge.Acceleration = Vector3.new(0, 1.5, 0)
charge.Color = ColorSequence.new(mint)
local flash = layer(
	"LanternPressure",
	"PressurePop",
	2,
	0.65,
	NumberRange.new(0.45),
	NumberRange.new(0),
	NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(0.3, 4.2),
		NumberSequenceKeypoint.new(1, 5.5),
	}),
	NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.35, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
)
flash.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
flash.Color = ColorSequence.new(mint)
local chips = layer(
	"AmberGlassGlints",
	"GlassChips",
	18,
	0.7,
	NumberRange.new(0.3, 0.65),
	NumberRange.new(7, 11),
	NumberSequence.new(0.16, 0),
	NumberSequence.new(0, 1)
)
chips.Drag, chips.Acceleration, chips.SpreadAngle = 6, Vector3.new(0, -9, 0), Vector2.new(180, 180)
local mist = layer(
	"VioletDust",
	"GlassDust",
	10,
	0.75,
	NumberRange.new(0.5, 0.8),
	NumberRange.new(1, 2),
	NumberSequence.new(0.3, 0.8),
	NumberSequence.new(0.7, 1)
)
mist.Color = ColorSequence.new(violet)
for side = -1, 1, 2 do
	local a, b = Instance.new("Attachment"), Instance.new("Attachment")
	a.Name, b.Name = "RibbonStart" .. side, "RibbonEnd" .. side
	a.Position, b.Position = Vector3.new(-1.6, 1, side * 0.35), Vector3.new(1.6, 1.4, side * 0.35)
	a.Parent, b.Parent = root, root
	local beam = source.SandRibbon:Clone()
	beam.Name, beam.Enabled = "WispRibbon" .. side, false
	beam.Attachment0, beam.Attachment1 = a, b
	beam.Color = ColorSequence.new(mint, violet)
	beam.Width0, beam.Width1, beam.Segments, beam.FaceCamera = 0.14, 0.035, 24, true
	beam.CurveSize0, beam.CurveSize1 = side * 1.6, -side * 1.6
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.2),
		NumberSequenceKeypoint.new(0.8, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam:SetAttribute("PhaseStart", 0.25)
	beam:SetAttribute("PhaseEnd", 1.5)
	beam.Parent = root
end
local total = 0
for _, x in kit:GetDescendants() do
	assert(not x:IsA("LuaSourceContainer"))
	if x:IsA("ParticleEmitter") then
		assert(not x.Enabled and x.Rate == 0)
		total += x:GetAttribute("BurstCount")
	end
	if x:IsA("Beam") then
		assert(x.Attachment0:IsDescendantOf(kit) and x.Attachment1:IsDescendantOf(kit))
	end
end
assert(total <= 60)
kit.Parent = library
local bytes = game:GetService("SerializationService"):SerializeInstancesAsync({ kit })
_G.HollowlightVFXExport = buffer.tostring(game:GetService("EncodingService"):Base64Encode(bytes))
return {
	BurstParticles = total,
	Ribbons = 2,
	Bytes = buffer.len(bytes),
	Base64Length = #_G.HollowlightVFXExport,
	MapTouched = false,
	LiveEnabled = false,
}
