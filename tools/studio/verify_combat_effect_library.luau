-- Native template contract checks; passing does not validate gameplay or subjective sound quality.
return function(spec)
	local library = game.ServerStorage.CombatReleaseStaged.VFX.Combat
	local checks = 0
	local function check(ok, message)
		checks += 1
		assert(ok, message)
	end
	check(library:GetAttribute("PreviewOnly") == true, "Preview boundary")
	check(library:GetAttribute("RulesConnected") == false, "No live-rules claim")
	check(#library.Meshes:GetChildren() == 10, "10 shared meshes")
	check(#library.Particles:GetChildren() == 6, "6 burst templates")
	check(#library.Beams:GetChildren() == 4, "4 beam templates")
	check(#library.Audio:GetChildren() == 14, "14 sound cues")
	check(#library.Kits:GetChildren() == 24, "Fixed 24 kits")
	for _, item in library:GetDescendants() do
		check(not item:IsA("LuaSourceContainer"), "Library must not contain scripts")
		check(not item:IsA("Light"), "No dynamic lights")
		if item:IsA("BasePart") then
			check(item.Anchored, "Anchor " .. item.Name)
			check(not item.CanCollide and not item.CanTouch and not item.CanQuery, "Cosmetic flags " .. item.Name)
			check(not item.CastShadow, "No effect shadows")
			check(item:IsA("MeshPart") and item.MeshId:match("^rbxassetid://%d+$"), "Persistent native mesh")
		elseif item:IsA("ParticleEmitter") then
			check(not item.Enabled and item.Rate == 0, "No automatic emission")
			check(item:GetAttribute("BurstCount") <= 6, "Bounded particle burst")
			check(item.Lifetime.Max <= 0.65, "Bounded particle lifetime")
			check(item.Texture:match("^rbxassetid://%d+$"), "Uploaded texture")
			if item.Name == "PressurePop" or item.Name == "GlassDust" then
				check(item.FlipbookLayout == Enum.ParticleFlipbookLayout.Grid4x4, "4x4 layout")
				check(item.FlipbookMode == Enum.ParticleFlipbookMode.OneShot, "One-shot flipbook")
				check(not item.FlipbookStartRandom, "Frame zero start")
			end
		elseif item:IsA("Beam") then
			check(not item.Enabled and not item.Attachment0 and not item.Attachment1, "Unbound beam template")
			check(item.Width0 <= 0.18001 and item.Width1 <= 0.18001, "Narrow beam")
		end
	end
	local sounds, audio = {}, {}
	for _, definition in spec.audio do
		local sound = library.Audio:FindFirstChild(definition.name)
		check(sound and sound.SoundId == definition.id, "Sound identity " .. definition.name)
		table.insert(sounds, sound)
	end
	game:GetService("ContentProvider"):PreloadAsync(sounds)
	for _, sound in sounds do
		check(sound.IsLoaded and sound.TimeLength > 0, "Native audio load " .. sound.Name)
		check(not sound.IsPlaying and not sound.Looped, "Sound remains idle")
		check(
			sound:GetAttribute("StartSeconds") >= 0 and sound:GetAttribute("StartSeconds") < sound.TimeLength,
			"Valid cue start"
		)
		check(sound:GetAttribute("FadeSeconds") < sound:GetAttribute("PreviewSeconds"), "Valid fade")
		check(sound.Volume <= 1.5 and sound.PlaybackSpeed >= 0.75 and sound.PlaybackSpeed <= 1.5, "Mix bounds")
		check(sound:GetAttribute("RuntimeActive") == false, "Staged audio only")
		table.insert(
			audio,
			{ name = sound.Name, id = sound.SoundId, length = sound.TimeLength, loaded = sound.IsLoaded }
		)
	end
	local seen = {}
	for _, definition in spec.kits do
		local kit = library.Kits:FindFirstChild(definition.id)
		check(kit and not seen[definition.id], "Unique kit " .. definition.id)
		seen[definition.id] = true
		check(
			kit:GetAttribute("PrototypeOnly") == true and kit:GetAttribute("LiveValidated") == false,
			"Honest kit status"
		)
		check(kit:GetAttribute("ContactRequiresServerResult") == true, "Contact truth contract")
		check(kit:GetAttribute("MissUsesLockedDirection") == true, "Miss direction contract")
		check(library.Audio:FindFirstChild(kit:GetAttribute("ReleaseSound")), "Release audio exists")
		check(library.Audio:FindFirstChild(kit:GetAttribute("ContactSound")), "Contact audio exists")
		for _, reference in kit:GetChildren() do
			if reference:IsA("ObjectValue") then
				check(reference.Value and reference.Value.Parent == library.Meshes, "Internal mesh reference")
			end
		end
	end
	check(#library.Kits.crescent_axe.CrescentWeapon:GetChildren() == 2, "Separate axe pieces")
	return { checks = checks, passed = true, kits = 24, audio = audio, liveRulesConnected = false }
end
