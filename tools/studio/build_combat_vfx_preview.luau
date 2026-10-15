-- Isolated developer fixture; STAGED outcomes, original installed starter bodies.
-- This is a shared texture/Beam preview, not revised-body import or combat proof.
return function()
	local storage = game:GetService("ServerStorage")
	local root = Instance.new("Model")
	root.Name = "VFXPreview_CombatRelease"
	root:SetAttribute("PreviewOnly", true)
	root:SetAttribute("Outcome", "StagedHit")
	root:SetAttribute("RevisedBodiesImported", false)
	root:SetAttribute("CameraDistance", 33)
	root:SetAttribute("CameraFieldOfView", 52)
	local origin = Vector3.new(0, 20, 2000)
	local ids = {
		glass_glint = "rbxassetid://118014953401567",
		electricity_strip = "rbxassetid://110100143277445",
		glass_dust_4x4 = "rbxassetid://101019590487297",
		pressure_pop_4x4 = "rbxassetid://130955555778708",
	}
	local function anchor(name, pos)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Size = Vector3.new(0.1, 0.1, 0.1)
		p.Transparency = 1
		p.Position = pos
		p.Parent = root
		local a = Instance.new("Attachment")
		a.Parent = p
		return p, a
	end
	for i, gid in { "pop", "prism" } do
		local source = game.ReplicatedStorage.Assets.Glassies[gid]
		local m = Instance.new("Model")
		m.Name = gid .. "_OriginalPreview"
		m.Parent = root
		local pivot = source:GetPivot()
		local target = CFrame.new(origin + Vector3.new((i == 1 and -1 or 1) * 3, 0, 0))
		for _, p in source:GetDescendants() do
			if p:IsA("BasePart") and not p:FindFirstAncestor("Shards") then
				local c = p:Clone()
				c.CFrame = target * pivot:ToObjectSpace(p.CFrame)
				c.Anchored = true
				c.CanCollide = false
				c.CanTouch = false
				c.CanQuery = false
				c.Parent = m
			end
		end
		m:ScaleTo(1.75)
	end
	local _, start = anchor("CastSource", origin + Vector3.new(-2, -0.5, -0.2))
	local _, finish = anchor("CastImpact", origin + Vector3.new(2, -0.5, -0.2))
	local beam = Instance.new("Beam")
	beam.Name = "StagedArc"
	beam.Attachment0 = start
	beam.Attachment1 = finish
	beam.FaceCamera = true
	beam.Texture = ids.electricity_strip
	beam.TextureMode = Enum.TextureMode.Stretch
	beam.Width0 = 0.28
	beam.Width1 = 0.18
	beam.Color = ColorSequence.new(Color3.fromRGB(155, 241, 255))
	beam.LightEmission = 0.65
	beam.Parent = start
	local _, glintAnchor = anchor("Glint", finish.WorldPosition)
	local gui = Instance.new("BillboardGui")
	gui.Name = "AlphaGlint"
	gui.Size = UDim2.fromScale(0.75, 0.75)
	gui.Adornee = glintAnchor
	gui.AlwaysOnTop = false
	gui.Parent = glintAnchor
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = ids.glass_glint
	image.ImageColor3 = Color3.fromRGB(225, 250, 255)
	image.Parent = gui
	for i, name in { "pressure_pop_4x4", "glass_dust_4x4" } do
		local part, a = anchor(name, origin + Vector3.new((i == 1 and -1 or 1) * 1.25, -2.5, 0))
		local e = Instance.new("ParticleEmitter")
		e.Name = "Burst"
		e.Texture = ids[name]
		e.Enabled = false
		e.Rate = 0
		e.Speed = NumberRange.new(0)
		e.Lifetime = NumberRange.new(0.65)
		e.Size = NumberSequence.new(1.5)
		e.LightEmission = 0.4
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		e.FlipbookFramerate = NumberRange.new(24)
		e.FlipbookStartRandom = false
		e.Parent = a
		-- Static frame 6 makes alpha/order inspection repeatable in Edit mode.
		local card = Instance.new("BillboardGui")
		card.Name = "Frame6AlphaProof"
		card.Size = UDim2.fromScale(1.5, 1.5)
		card.Adornee = a
		card.Parent = a
		local im = Instance.new("ImageLabel")
		im.BackgroundTransparency = 1
		im.Size = UDim2.fromScale(1, 1)
		im.Image = ids[name]
		im.ImageRectOffset = Vector2.new(256, 128)
		im.ImageRectSize = Vector2.new(128, 128)
		im.Parent = card
	end
	root.Parent = storage
	return root, origin
end
