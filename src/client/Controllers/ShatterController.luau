local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local HapticService = game:GetService("HapticService")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local Audio = require(RS.Shared.Config.Audio)
local Balance = require(RS.Shared.Config.Balance)
local Glassies = require(RS.Shared.Config.Glassies)
local CrackPaths = require(RS.Shared.Config.CrackPaths)
local Feel = Balance.Feel
local Shatter = {}

function Shatter:Init()
	self.Random = Random.new()
	self.Shards = {}
	self.Sounds = {}
end
function Shatter:Start()
	task.spawn(function()
		local sounds = {}
		local cache = Instance.new("Folder")
		cache.Name, cache.Parent = "GlassClashAudio", SoundService
		for _, id in Audio do
			local sound = Instance.new("Sound")
			sound.SoundId = id
			sound.Parent = cache
			self.Sounds[id] = sound
			table.insert(sounds, sound)
		end
		-- Sound instances tell ContentProvider to request audio, rather than an image URL.
		ContentProvider:PreloadAsync(sounds)
	end)
end
function Shatter:Sound(id, parent, pitch, volume, short)
	local template = self.Sounds[id]
	local sound = template and template:Clone() or Instance.new("Sound")
	sound.SoundId, sound.PlaybackSpeed, sound.Volume = id, pitch or 1, volume or 0.35
	sound.RollOffMaxDistance = 70
	sound.RollOffMinDistance = 20
	sound.Parent = parent
	sound:Play()
	if short then
		task.delay(short, function()
			if sound.Parent then
				sound:Stop()
			end
		end)
	end
	Debris:AddItem(sound, 5)
end
function Shatter:Pulse()
	for _, input in { Enum.UserInputType.Gamepad1, Enum.UserInputType.Touch } do
		pcall(function()
			if HapticService:IsMotorSupported(input, Enum.VibrationMotor.Small) then
				HapticService:SetMotor(input, Enum.VibrationMotor.Small, 0.65)
				task.delay(Feel.HapticSeconds, function()
					pcall(function()
						HapticService:SetMotor(input, Enum.VibrationMotor.Small, 0)
					end)
				end)
			end
		end)
	end
end

-- Blender raycasts project these small segments onto each approved body's surface.
function Shatter:SetCracks(fighter, hp, maxHP)
	local stage = 0
	for _, threshold in Feel.CrackThresholds do
		if hp / maxHP <= threshold then
			stage += 1
		end
	end
	if stage == (fighter.CrackStage or 0) then
		return false
	end
	fighter.CrackStage = stage
	fighter.Model:SetAttribute("CrackStage", stage)
	for _, part in fighter.Cracks or {} do
		part:Destroy()
	end
	fighter.Cracks = {}
	if stage == 0 or hp == 0 then
		return stage > 0
	end
	for _, path in CrackPaths[fighter.RenderId or fighter.Id] or {} do
		if path[7] <= stage then
			local scale = fighter.Scale or 1
			local a, b = Vector3.new(path[1], path[2], path[3]) * scale, Vector3.new(path[4], path[5], path[6]) * scale
			local part = Instance.new("Part")
			part.Name = "SurfaceCrack"
			part.Size = Vector3.new(Feel.CrackWidth * scale, Feel.CrackWidth * scale, (b - a).Magnitude)
			part.CFrame = CFrame.lookAt((a + b) / 2, b)
			part.PivotOffset = part.CFrame:Inverse()
			part.Color, part.Material = Color3.fromHex("#17304A"), Enum.Material.SmoothPlastic
			part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
			part.CastShadow = false
			part:PivotTo(fighter.Pivot)
			part.Parent = fighter.Model
			table.insert(fighter.Cracks, part)
		end
	end
	return true
end

function Shatter:Break(fighter, root)
	local origin = fighter.Body.Position
	local pieces
	if fighter.ShardTemplates then
		pieces = fighter.ShardTemplates:GetChildren()
	else
		local source = RS.Assets.Glassies[fighter.Id]
		pieces = source.Shards:GetChildren()
		for _, detail in (source:FindFirstChild("Details") and source.Details:GetChildren() or {}) do
			if not detail.Name:find("Bubble") then
				table.insert(pieces, detail)
			end
		end
	end
	for _, part in fighter.Parts do
		part.Transparency = 1
	end
	fighter.Beam.Enabled = false
	for _, crack in fighter.Cracks or {} do
		crack.Transparency = 1
	end
	for _, template in pieces do
		-- Discard expired references before enforcing the mobile cap.
		for i = #self.Shards, 1, -1 do
			if not self.Shards[i].Parent then
				table.remove(self.Shards, i)
			end
		end
		if #self.Shards >= Feel.MaxShards then
			break
		end
		local shard = template:Clone()
		shard.Name = "LocalShard"
		shard:PivotTo(fighter.Pivot)
		shard.PivotOffset = CFrame.identity
		shard.CanCollide, shard.CanTouch, shard.CanQuery = true, false, false
		shard.CustomPhysicalProperties =
			PhysicalProperties.new(Feel.ShardDensity, Feel.ShardFriction, Feel.ShardBounce, 1, 1)
		shard.CastShadow = false
		shard.Parent = root
		shard.Anchored = false
		local offset = shard.Position - origin
		local outward = offset.Magnitude > 0.05 and offset.Unit or Vector3.new(1, 0, 0)
		local random =
			Vector3.new(self.Random:NextNumber(-1, 1), self.Random:NextNumber(-0.4, 0.7), self.Random:NextNumber(-1, 1))
		local velocity = (outward + random) * Feel.ShardSpeed
		shard.AssemblyLinearVelocity = velocity * Feel.SlowMotionRate
		shard.AssemblyAngularVelocity = Vector3.new(
			self.Random:NextNumber(-1, 1),
			self.Random:NextNumber(-1, 1),
			self.Random:NextNumber(-1, 1)
		) * Feel.ShardSpin * Feel.SlowMotionRate
		local attachment = Instance.new("Attachment")
		attachment.Parent = shard
		local force = Instance.new("VectorForce")
		force.Attachment0, force.RelativeTo, force.ApplyAtCenterOfMass = attachment, Enum.ActuatorRelativeTo.World, true
		force.Force = Vector3.new(0, shard.AssemblyMass * workspace.Gravity * (1 - Feel.SlowMotionRate ^ 2), 0)
		force.Parent = shard
		task.delay(Feel.SlowMotionSeconds, function()
			if shard.Parent then
				force:Destroy()
				shard.AssemblyLinearVelocity /= Feel.SlowMotionRate
				shard.AssemblyAngularVelocity /= Feel.SlowMotionRate
			end
		end)
		task.delay(Feel.ShardSeconds - 0.6, function()
			if shard.Parent then
				TweenService:Create(shard, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			end
		end)
		Debris:AddItem(shard, Feel.ShardSeconds)
		table.insert(self.Shards, shard)
	end
	local sparkle = Instance.new("Part")
	sparkle.Name, sparkle.Size, sparkle.Position = "ShatterSparkles", Vector3.one, origin
	sparkle.Transparency, sparkle.Anchored, sparkle.CanCollide = 1, true, false
	sparkle.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromHex(Glassies.get(fighter.Id).Tint), Color3.new(1, 1, 1))
	emitter.LightEmission, emitter.Rate = 1, 0
	emitter.Lifetime, emitter.Speed = NumberRange.new(0.5, 1.2), NumberRange.new(2, 8)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) })
	emitter.Parent = sparkle
	emitter:Emit(Feel.Sparkles)
	Debris:AddItem(sparkle, Feel.ShardSeconds)
	self:Sound(Audio.Break, sparkle, 0.92, 0.65 * (fighter.SoundScale or 1))
	task.delay(0.12, function()
		if sparkle.Parent then
			self:Sound(Audio.Tinkle, sparkle, 1.2, 0.4 * (fighter.SoundScale or 1))
		end
	end)
end

function Shatter:HitBurst(a, b, result, root)
	local strong = result.ActionA == "Perfect" or result.CritA or result.CritB
	local origin = (a.Body.Position + b.Body.Position) / 2
	local flash = Instance.new("Part")
	flash.Name, flash.Shape = "ImpactFlash", Enum.PartType.Ball
	flash.Anchored, flash.CanCollide, flash.CanTouch, flash.CanQuery = true, false, false, false
	flash.CastShadow, flash.Material = false, Enum.Material.Neon
	flash.Color = strong and Color3.fromHex("#FFE991") or Color3.fromHex("#D9F8FF")
	flash.Size, flash.Position = Vector3.one * Feel.HitFlashSize, origin
	flash.Parent = root
	TweenService:Create(flash, TweenInfo.new(Feel.HitFlashSeconds), {
		Size = Vector3.one * (strong and 1.5 or 0.9),
		Transparency = 1,
	}):Play()
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color, emitter.LightEmission, emitter.Rate = ColorSequence.new(flash.Color), 1, 0
	emitter.Lifetime, emitter.Speed = NumberRange.new(0.12, 0.3), NumberRange.new(7, 13)
	emitter.SpreadAngle, emitter.Drag = Vector2.new(180, 180), 6
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) })
	emitter.Parent = flash
	emitter:Emit(Feel.HitSparkles * (strong and 2 or 1))
	Debris:AddItem(flash, 0.4)
end

function Shatter:Impact(a, b, result, hud, root)
	self:HitBurst(a, b, result, root)
	local stageA = self:SetCracks(a, result.HpA, a.Stats.MaxHP)
	local stageB = self:SetCracks(b, result.HpB, b.Stats.MaxHP)
	self:Sound(Audio.Clink, a.Body, Glassies.get(a.Id).ClinkPitch * self.Random:NextNumber(0.96, 1.04), 0.4)
	self:Sound(Audio.Clink, b.Body, Glassies.get(b.Id).ClinkPitch, 0.25)
	if stageA or stageB then
		self:Sound(Audio.Break, a.Body, 1.4, 0.14, 0.18)
	end
	self:Pulse()
	hud:UpdateHP(result.HpA, result.HpB)
	hud:Popup("−" .. result.DamageToA, a.Body.Position, Color3.fromHex("#FFBCC9"))
	hud:Popup("−" .. result.DamageToB, b.Body.Position, Color3.new(1, 1, 1))
	if result.ActionA == "Perfect" or result.CritA then
		hud:Popup(
			result.CritA and "CRIT!" or "PERFECT!",
			b.Body.Position + Vector3.new(0, 1.2, 0),
			Color3.fromHex("#FFE45C")
		)
	end
	if result.CritB then
		hud:Popup("CRIT!", a.Body.Position + Vector3.new(0, 1.2, 0), Color3.fromHex("#FFBCC9"))
	end
	if result.Clutch then
		hud:Popup("CLUTCH!", a.Body.Position + Vector3.new(0, 2.1, 0), Color3.fromHex("#FFE45C"))
	end
	if result.Winner then
		self:Break(result.Winner == "A" and b or a, root)
		hud:Shattered(result.Winner == "A")
	end
end
return Shatter
