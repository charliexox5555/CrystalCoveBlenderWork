-- Ka-Block (brick_boom, Epic): glass toy blocks rain down and stack around the foe, a comic sign pops
-- "KA-BLOCK!", the tower blows apart in a golden puff, and four letter blocks bounce into a row spelling BOOM,
-- then pop into sparkles one by one.
local Kit = require(script.Parent.Kit)
local Show = {}

local TANGERINE, LEMON = Color3.fromHex("#FFAE62"), Color3.fromHex("#FFF2A0")
local GLASS =
	{ Color3.fromHex("#8FD3FF"), Color3.fromHex("#8FF0C8"), Color3.fromHex("#FFA8D2"), Color3.fromHex("#FFE27A") }
local LETTERS = { "B", "O", "O", "M" }
local HEADING = Font.new("rbxasset://fonts/families/DenkOne.json")

local function label(parent, text, color, strokeThickness)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.Parent = parent
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.FontFace = HEADING
	t.Text = text
	t.TextScaled = true
	t.TextColor3 = color
	t.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness = Color3.new(1, 1, 1), strokeThickness
	stroke.Parent = t
	return gui
end

function Show.build(rig, s)
	local random = Random.new(41)
	rig.Blocks = {}
	local count = if rig.Low then 4 else s.Blocks
	for i = 1, count do
		local row = if i <= 4 then 0 else 1
		local slot = (i - 1) % 4
		local angle = math.rad(45 + slot * 90 + row * 45)
		table.insert(rig.Blocks, {
			Actor = rig:Actor("ToyBlock", {
				Mesh = { "ToyBlock" },
				Size = s.BlockSize,
				Color = GLASS[(i - 1) % #GLASS + 1],
				Material = Enum.Material.Glass,
				Transparency = 0.12,
				Reflectance = 0.2,
			}),
			Angle = angle,
			Row = row,
			LandAt = 0.06 + (i - 1) * s.DropStep + s.DropSeconds,
			Spin = Vector3.new(random:NextNumber(-7, 7), random:NextNumber(-7, 7), random:NextNumber(-7, 7)),
			Speed = s.BlockSpeed * random:NextNumber(0.8, 1.2),
			Lift = random:NextNumber(6, 9),
			Yaw = random:NextNumber(-0.3, 0.3),
		})
	end
	-- Letter blocks: the B-O-O-M row. Letters are Blender meshes when installed, otherwise SurfaceGui text.
	local row = rig:Group("BoomRow")
	rig.Row = row
	rig.Letters = {}
	for i, char in LETTERS do
		local block = rig:Actor("LetterBlock", {
			Mesh = { "ToyBlock" },
			Size = s.LetterSize,
			Color = GLASS[(i % #GLASS) + 1],
			Material = Enum.Material.Glass,
			Transparency = 0.08,
			Reflectance = 0.2,
			Parent = row,
		})
		local glyph = rig:Actor("Letter" .. char, {
			Mesh = { "BlockLetter" .. char },
			Size = s.LetterSize * 0.62,
			Color = TANGERINE,
			Parent = row,
		})
		if glyph.Fallback then
			-- No letter mesh: use the block's own Front face.
			glyph.Part:Destroy()
			table.remove(rig.Actors, #rig.Actors)
			glyph = nil
			label(block.Part, char, TANGERINE, 4)
		end
		table.insert(rig.Letters, {
			Block = block,
			Glyph = glyph,
			Index = i,
			PopAt = s.PopAt + (i - 1) * s.PopStep,
			Spin = (if i % 2 == 0 then 1 else -1) * 2 * math.pi,
		})
	end
	rig.RowOutline = rig:Outline(row, Color3.new(1, 1, 1))
	rig.Sign = rig:Actor("BurstSign", {
		Mesh = { "BurstSign" },
		Size = s.SignSize,
		NativeSize = Vector3.new(2, 1.15, 0.2),
		Color = LEMON,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0,
	})
	-- Without the Blender sign, a plain plate sits on a jagged crown so it still reads as a comic burst.
	if rig.Sign.Fallback then
		rig.SignBack =
			rig:Actor("BurstSignBack", { Mesh = { "ShockCrown" }, Size = s.SignSize * 0.95, Color = TANGERINE })
	end
	label(rig.Sign.Part, "KA-BLOCK!", TANGERINE, 5)
	rig.Puff = rig:Actor("BlockPuff", {
		Mesh = { "BlastBloom" },
		Shape = Enum.PartType.Ball,
		Size = 1,
		Color = TANGERINE,
	})
	rig.Puff2 = rig:Actor("BlockPuffCore", {
		Mesh = { "BlastBloom" },
		Shape = Enum.PartType.Ball,
		Size = 1,
		Color = LEMON,
	})
	rig.Ring = rig:Actor("BlockRing", { Mesh = { "ShockCrown", "Ring" }, Size = 2, Color = LEMON, Transparency = 0.1 })
	rig:Light(rig.Puff2, Color3.fromHex("#FFC46B"), s.LightRange)
	rig.Pops = {}
	if not rig.Low then
		for i = 1, #LETTERS do
			rig.Pops[i] =
				rig:Actor("LetterPop", { Mesh = { "Ring" }, Size = 2, Color = Color3.new(1, 1, 1), Transparency = 0.2 })
		end
	end
	rig.PopSocket = rig:SocketPart("PopSocket", Vector3.one * 0.2)
	rig:Emitter("Sparks", {
		Texture = "Streak",
		Color = { Color3.new(1, 1, 1), LEMON, TANGERINE },
		Size = { { 0, 0.45 }, { 1, 0.1 } },
		Squash = { { 0, 1.6 }, { 1, 0.6 } },
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Lifetime = { 0.3, 0.5 },
		Speed = { 20, 32 },
		Drag = 3.5,
		Acceleration = Vector3.new(0, -10, 0),
	})
	rig:Emitter("Glints", {
		Texture = "StarGlint",
		Color = { Color3.new(1, 1, 1), LEMON },
		Size = { { 0, 1.0 }, { 1, 0 } },
		Lifetime = { 0.3, 0.5 },
		Speed = { 8, 16 },
		Drag = 5,
	})
	rig:Emitter("PopGlint", {
		Socket = rig.PopSocket,
		Texture = "StarGlint",
		Color = { Color3.new(1, 1, 1), LEMON, TANGERINE },
		Size = { { 0, 0.9 }, { 1, 0 } },
		Lifetime = { 0.2, 0.35 },
		Speed = { 6, 11 },
		Drag = 6,
	})
	rig:Burst(s.PeakAt, "Sparks", s.Sparks)
	rig:Burst(s.PeakAt, "Glints", 14)
	for _, letter in rig.Letters do
		rig:On(letter.PopAt, function(r)
			if r.Emitters.PopGlint then
				r.PopSocket.CFrame = letter.Block.Part.CFrame
				r.Emitters.PopGlint:Emit(math.max(1, math.floor(7 * r.ParticleScale + 0.5)))
			end
		end)
	end
end

local function towerSpot(rig, b, s)
	local radius = s.TowerRadius + b.Row * 0.15
	local x, z = math.cos(b.Angle) * radius, math.sin(b.Angle) * radius
	local y = -1.4 + b.Row * s.BlockSize * 0.98
	return rig.View:PointToWorldSpace(Vector3.new(x, y, z))
end

function Show.step(rig, t, s)
	local origin = rig.Origin
	local after = t - s.PeakAt
	local released = after >= 0
	local tremble = Kit.window(t, s.PeakAt - 0.14, s.PeakAt)
	for _, b in rig.Blocks do
		local spot = towerSpot(rig, b, s)
		local p = b.Actor
		if not released then
			local fallT = (t - (b.LandAt - s.DropSeconds)) / s.DropSeconds
			if fallT < 0 then
				rig:Hide(p)
				continue
			end
			local land = t - b.LandAt
			local height = if fallT < 1 then (1 - Kit.easeIn(fallT)) * s.DropHeight else 0
			local squash = if land >= 0 then Kit.spring(land, 34, 10) else 0
			local scale = Vector3.new(1 + 0.18 * squash, 1 - 0.24 * squash, 1 + 0.18 * squash)
			local shake = Vector3.new(math.noise(t * 30, b.Angle), 0, math.noise(b.Angle, t * 30)) * 0.12 * tremble
			local cf = CFrame.new(spot + Vector3.yAxis * (height - s.BlockSize * 0.12 * squash) + shake)
				* rig.View.Rotation
				* CFrame.Angles(0, b.Angle + b.Yaw, math.sin(t * 40 + b.Angle) * 0.06 * tremble)
			rig:Place(p, cf, scale, 0)
		else
			local radial = (spot - origin) * Vector3.new(1, 0, 1)
			radial = if radial.Magnitude > 0.01 then radial.Unit else Vector3.xAxis
			local at = spot
				+ radial * b.Speed * after
				+ Vector3.yAxis * (b.Lift * after - 0.5 * s.Gravity * after * after)
			local cf = CFrame.new(at)
				* rig.View.Rotation
				* CFrame.Angles(b.Spin.X * after, b.Angle + b.Spin.Y * after, b.Spin.Z * after)
			local fade = Kit.smooth((after - 0.6) / 0.4)
			rig:Place(p, cf, 1 - 0.3 * fade, fade)
		end
	end
	-- BOOM row: hidden inside the tower, launched at the peak, bounces into a camera-facing row.
	local flight = s.LandAt - s.PeakAt
	for _, letter in rig.Letters do
		if not released then
			rig:Hide(letter.Block)
			if letter.Glyph then
				rig:Hide(letter.Glyph)
			end
			continue
		end
		local i = letter.Index
		local target = rig:At((i - 2.5) * s.LetterSpacing, -s.LetterDrop, s.LetterForward)
		local u = Kit.clamp01(after / flight)
		local arc = math.sin(u * math.pi) * (3.5 + i * 0.3)
		local at = origin:Lerp(target, Kit.smooth(u)) + Vector3.yAxis * arc
		local spin = (1 - Kit.easeOut(u)) * letter.Spin
		local land = t - s.LandAt
		local scale = Vector3.one * Kit.pop(after / 0.2)
		if land >= 0 then
			-- Two decaying hops, squash on each touch-down.
			local hop = math.abs(math.sin(land * 9)) * math.exp(-land * 5) * 0.9
			at = target + Vector3.yAxis * hop
			local squash = Kit.spring(land, 36, 9) * 0.22
			scale = Vector3.new(1 + squash * 0.6, 1 - squash, 1 + squash * 0.6)
			-- A little wobble once settled.
			spin = math.sin(land * 7 + i) * 0.08 * Kit.window(land, 0.35, 0.5)
		end
		local cf = CFrame.new(at) * rig.Facing.Rotation * CFrame.Angles(0, spin, spin * 0.2)
		local popT = (t - letter.PopAt) / 0.09
		local alpha = 0
		if popT >= 1 then
			rig:Hide(letter.Block)
			if letter.Glyph then
				rig:Hide(letter.Glyph)
			end
		else
			if popT >= 0 then
				scale *= 1 + 0.3 * popT
				alpha = popT
			end
			rig:Place(letter.Block, cf, scale, alpha)
			if letter.Glyph then
				rig:Place(letter.Glyph, cf * CFrame.new(0, 0, -s.LetterSize * 0.5), scale, alpha)
			end
		end
		local pop = rig.Pops[i]
		if pop then
			local ringT = (t - letter.PopAt) / 0.25
			if ringT >= 0 and ringT < 1 then
				rig:Disc(pop, CFrame.new(target) * rig.Facing.Rotation, 0.6 + 1.6 * Kit.easeOut(ringT), ringT, 0.6)
			else
				rig:Hide(pop)
			end
		end
	end
	if rig.RowOutline then
		rig.RowOutline.Enabled = released and t < s.PopAt + 0.4
		rig.RowOutline.OutlineTransparency = 0.15
	end
	-- Comic sign: pops in with overshoot, wobbles, shrinks away.
	if released and t < s.PopAt then
		local inT = Kit.pop(after / 0.18)
		local outT = Kit.smooth((t - (s.PopAt - 0.3)) / 0.3)
		local wobble = math.sin(after * 10) * 0.08 * math.exp(-after * 2)
		local cf = CFrame.new(origin + Vector3.yAxis * s.SignHeight + rig.View.ZVector * 1.2)
			* rig.Facing.Rotation
			* CFrame.Angles(0, 0, -0.15 + wobble)
		local k = inT * (1 - outT)
		rig:Place(rig.Sign, cf, Vector3.new(k, k, 1), outT * 0.6)
		if rig.SignBack then
			rig:Place(
				rig.SignBack,
				cf * CFrame.new(0, 0, 0.15) * CFrame.Angles(0, 0, after * 0.8),
				Vector3.new(k, k, 1),
				outT * 0.6
			)
		end
	else
		rig:Hide(rig.Sign)
		if rig.SignBack then
			rig:Hide(rig.SignBack)
		end
	end
	-- Golden puff, ring and light.
	if released and after < 0.65 then
		local grow = Kit.easeOut(after / 0.3)
		local fade = Kit.smooth((after - 0.15) / 0.5)
		local cf = CFrame.new(origin) * rig.Facing.Rotation * CFrame.Angles(0, 0, after * 1.2)
		rig:Place(rig.Puff, cf, 0.4 + s.PuffSize * grow, fade)
		rig:Place(
			rig.Puff2,
			cf * CFrame.Angles(0, 0, 0.6),
			0.3 + s.PuffSize * 0.6 * grow,
			Kit.smooth((after - 0.05) / 0.35)
		)
	else
		rig:Hide(rig.Puff)
		rig:Hide(rig.Puff2)
	end
	if released and after < 0.55 then
		local ringT = Kit.easeOut(after / 0.55)
		rig:Disc(
			rig.Ring,
			CFrame.new(origin - Vector3.yAxis * 1.4) * CFrame.Angles(math.pi / 2, 0, 0),
			1 + s.RingRadius * ringT,
			ringT
		)
	else
		rig:Hide(rig.Ring)
	end
	for _, light in rig.Lights do
		light.Brightness = if released then s.LightBrightness * math.max(0, 1 - after / 0.45) else 0
	end
end

return Show
