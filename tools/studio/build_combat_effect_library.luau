-- Editable art-production library. This does not modify Rojo-managed scripts or live combat.
-- Input: assets/vfx/combat_release/native_library.json decoded with HttpService.
return function(spec)
	assert(game.PlaceId == 129420351303019, "Glass Clash only")
	local staged = game.ServerStorage:FindFirstChild("CombatReleaseStaged")
	assert(staged and staged:FindFirstChild("VFX"), "Normalize imports first")
	assert(#spec.kits == 24 and #spec.audio == 14, "Unexpected release manifest")
	assert(not staged.VFX:FindFirstChild("Combat"), "Library already exists; preserve it before rebuilding")
	local root = Instance.new("Folder")
	root.Name = "Combat"
	root:SetAttribute("PreviewOnly", true)
	root:SetAttribute("RulesConnected", false)
	root:SetAttribute("Version", 2)
	root:SetAttribute("Provenance", "Original Blender meshes and textures; documented Creator Store audio")
	local meshes = Instance.new("Folder")
	meshes.Name, meshes.Parent = "Meshes", root
	for _, original in staged.VFX.combat_vfx:GetChildren() do
		local mesh = original:Clone()
		mesh.Name = original:GetAttribute("SourceName") or original.Name
		mesh.Anchored, mesh.CanCollide, mesh.CanTouch, mesh.CanQuery = true, false, false, false
		mesh.CastShadow, mesh.Material, mesh.Transparency = false, Enum.Material.Neon, 0.2
		mesh.Parent = meshes
	end
	local particles = Instance.new("Folder")
	particles.Name, particles.Parent = "Particles", root
	for _, definition in spec.particles do
		local p = Instance.new("ParticleEmitter")
		p.Name, p.Texture = definition.name, spec.textures[definition.texture]
		p.Enabled, p.Rate = false, 0
		p:SetAttribute("BurstCount", definition.count)
		p.Lifetime = NumberRange.new(definition.life[1], definition.life[2])
		p.Speed = NumberRange.new(definition.speed[1], definition.speed[2])
		p.SpreadAngle = Vector2.new(180, 180)
		p.Drag = 3
		p.LightEmission, p.LightInfluence = 0.55, 0
		p.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, definition.size[1]),
			NumberSequenceKeypoint.new(0.2, definition.size[2]),
			NumberSequenceKeypoint.new(1, 0),
		})
		p.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.65, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		p.Rotation, p.RotSpeed = NumberRange.new(-180, 180), NumberRange.new(-80, 80)
		p.Orientation = Enum.ParticleOrientation.FacingCamera
		if definition.flipbook then
			p.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
			p.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
			p.FlipbookStartRandom = false
			p.FlipbookFramerate = NumberRange.new(24, 24)
		end
		p.Parent = particles
	end
	local beams = Instance.new("Folder")
	beams.Name, beams.Parent = "Beams", root
	for _, definition in spec.beams do
		local b = Instance.new("Beam")
		b.Name, b.Texture = definition.name, spec.textures[definition.texture]
		b.Enabled, b.FaceCamera = false, true
		b.Width0, b.Width1 = definition.width, definition.width * 0.65
		b.LightEmission, b.LightInfluence = 0.6, 0
		b.Segments, b.TextureLength, b.TextureSpeed = 8, 1, 0
		b.Transparency = NumberSequence.new(0.12)
		b.Parent = beams
	end
	local audio = Instance.new("Folder")
	audio.Name, audio.Parent = "Audio", root
	for _, definition in spec.audio do
		local s = Instance.new("Sound")
		s.Name, s.SoundId, s.Volume = definition.name, definition.id, definition.volume
		s.PlaybackSpeed = definition.pitch
		s.RollOffMinDistance, s.RollOffMaxDistance = 12, 65
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s:SetAttribute("Creator", definition.creator)
		s:SetAttribute("SourceURL", definition.url)
		s:SetAttribute("PreviewSeconds", definition.preview_seconds)
		s:SetAttribute("StartSeconds", definition.start_seconds)
		s:SetAttribute("FadeSeconds", definition.fade_seconds)
		s:SetAttribute("RuntimeActive", false)
		s.Parent = audio
	end
	local kits = Instance.new("Folder")
	kits.Name, kits.Parent = "Kits", root
	local seen = {}
	for _, definition in spec.kits do
		assert(not seen[definition.id] and staged.Glassies:FindFirstChild(definition.id), "Missing/duplicate glassy")
		seen[definition.id] = true
		local kit = Instance.new("Folder")
		kit.Name = definition.id
		kit:SetAttribute("Shape", definition.shape)
		kit:SetAttribute("TriggerBrief", definition.trigger)
		kit:SetAttribute("WindupSeconds", definition.windup)
		kit:SetAttribute("ActionSeconds", definition.action)
		kit:SetAttribute("TailSeconds", definition.tail)
		kit:SetAttribute("ReleaseSound", definition.release_sound)
		kit:SetAttribute("ContactSound", definition.contact_sound)
		kit:SetAttribute("ContactRequiresServerResult", true)
		kit:SetAttribute("MissUsesLockedDirection", true)
		kit:SetAttribute("LiveValidated", false)
		kit:SetAttribute("PrototypeOnly", true)
		for _, name in definition.meshes do
			assert(meshes:FindFirstChild(name), "Missing effect mesh " .. name)
			local ref = Instance.new("ObjectValue")
			ref.Name, ref.Value, ref.Parent = name, meshes[name], kit
		end
		kit.Parent = kits
	end
	-- The separate weapon has its own authored pivot; keep it out of intact-body/shard templates.
	local axe = Instance.new("Model")
	axe.Name, axe.WorldPivot = "CrescentWeapon", CFrame.identity
	for _, detail in staged.Glassies.crescent_axe.Details:GetChildren() do
		if detail:GetAttribute("EffectOnly") then
			local p = detail:Clone()
			local pivot = p:GetAttribute("AnimationPivot")
			p:PivotTo(CFrame.new(-pivot) * p:GetPivot())
			p.Parent = axe
		end
	end
	axe.Parent = kits.crescent_axe
	root.Parent = staged.VFX
	return {
		meshes = #meshes:GetChildren(),
		particles = #particles:GetChildren(),
		beams = #beams:GetChildren(),
		audio = #audio:GetChildren(),
		kits = #kits:GetChildren(),
	}
end
