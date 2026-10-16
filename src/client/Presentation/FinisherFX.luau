-- Bounded cosmetic explosions. No Explosion instance, humanoid damage or world physics.
local RS = game:GetService("ReplicatedStorage")
local TweenService, Debris = game:GetService("TweenService"), game:GetService("Debris")
local C = require(RS.Shared.Config.RoundCosmetics)
local T = require(RS.Shared.Config.Balance).CosmeticPresentation
local FX = {}
local function after(owner, delay, callback)
	if delay > 0 then
		task.delay(delay, function()
			if owner.Parent then
				callback()
			end
		end)
	else
		callback()
	end
end
local function part(root, name, color, size, cf, shape, meshName)
	local library = RS.Assets.VFX:FindFirstChild("RoundHeroV2")
	local source = library and meshName and library:FindFirstChild(meshName)
	local p = if source then source:Clone() else Instance.new("Part")
	p.Name, p.Color, p.Material, p.Size, p.CFrame = name, color, Enum.Material.Neon, size, cf
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	if shape and p:IsA("Part") then
		p.Shape = shape
	end
	p.Parent = root
	return p
end
local function tween(p, seconds, props, delay)
	after(p, delay or 0, function()
		TweenService:Create(p, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
	end)
end
local function wave(root, name, origin, basis, color, radius, seconds, delay)
	local library = RS.Assets.VFX:FindFirstChild("RoundHeroV2")
	local source = (name == "Shockwave" and library and library:FindFirstChild("ShockCrown"))
		or RS.Assets.VFX.Combat.Meshes.Ring
	local ring = source:Clone()
	ring.Name, ring.Material, ring.Color = name, Enum.Material.Neon, color
	ring.Anchored, ring.CanCollide, ring.CanTouch, ring.CanQuery = true, false, false, false
	ring.CFrame = CFrame.new(origin) * basis
	ring.Size *= 0.25
	ring.Transparency, ring.Parent = 1, root
	after(ring, delay, function()
		ring.Transparency = 0.1
		tween(ring, seconds, { Size = source.Size * radius, Transparency = 1 })
	end)
	return ring
end
function FX.emit(parent, id, origin, lowDetail, orientation)
	local def = C.ByCategory.Finishers[id] or C.Finishers[1]
	id = def.Id
	local root = Instance.new("Folder")
	root.Name, root.Parent = "Finisher_" .. id, parent
	root:SetAttribute("CosmeticOnly", true)
	local color, accent = Color3.fromHex(def.Color), Color3.fromHex(def.Accent)
	local basis = orientation or workspace.CurrentCamera.CFrame.Rotation
	local burstDelay = if id == "starfall" then T.FinisherSeconds * 0.25 else 0
	local core = part(
		root,
		"BurstCore",
		color,
		Vector3.one * 0.3,
		CFrame.new(origin),
		Enum.PartType.Ball,
		if id == "brick_boom" then "BlastBloom" else nil
	)
	core.Transparency = 1
	after(core, burstDelay, function()
		core.Transparency = 0.2
		tween(core, T.FinisherSeconds * 0.35, { Size = Vector3.one * T.FinisherCoreSize, Transparency = 1 })
	end)
	-- Layer the existing original texture bank with the authored meshes.
	local socket = Instance.new("Attachment")
	socket.Parent = core
	local particles = RS.Assets.VFX.Combat.Particles
	local sparks = particles.ContactGlint:Clone()
	sparks.Rate, sparks.Enabled = 0, false
	sparks.Color = ColorSequence.new(accent, color)
	sparks.Lifetime = NumberRange.new(T.FinisherSeconds * 0.5, T.FinisherSeconds * 0.75)
	sparks.Speed = NumberRange.new(T.FinisherRadius * 0.5, T.FinisherRadius)
	sparks.Parent = socket
	after(core, burstDelay, function()
		sparks:Emit(if lowDetail then 3 else 8)
	end)
	if id == "brick_boom" or id == "starfall" then
		local plume = particles.PressurePop:Clone()
		plume.Rate, plume.Enabled = 0, false
		plume.Color = ColorSequence.new(accent, color)
		plume.Lifetime = NumberRange.new(T.FinisherSeconds * 0.6)
		plume.Parent = socket
		after(core, burstDelay, function()
			plume:Emit(if lowDetail then 1 else 3)
		end)
	end
	for i = 1, (if lowDetail then 1 else 2) do
		wave(
			root,
			"Shockwave",
			origin,
			basis * CFrame.Angles(if i == 2 then math.pi / 2 else 0, 0, 0),
			if i == 1 then color else accent,
			T.FinisherRadius,
			T.FinisherSeconds * 0.65,
			burstDelay
		)
	end
	local count = if lowDetail then math.floor(T.FinisherParts / 2) else T.FinisherParts
	for i = 1, count do
		local a = i / count * math.pi * 2
		local dir = basis:VectorToWorldSpace(Vector3.new(math.cos(a), math.sin(a), math.sin(a * 3) * 0.35)).Unit
		local meshName = if id == "starfall"
			then "NovaStar"
			elseif id == "party_burst" then "ConfettiCurl"
			elseif id == "glass_burst" then "CrystalShard"
			else nil
		local p = part(
			root,
			"BurstPiece",
			if i % 2 == 0 then color else accent,
			Vector3.one * 0.5,
			CFrame.new(origin),
			nil,
			meshName
		)
		local destination = origin + dir * T.FinisherRadius
		if id == "party_burst" then
			p.Material, p.Color, p.Size =
				Enum.Material.SmoothPlastic, Color3.fromHSV(i / count, 0.7, 1), Vector3.new(0.35, 0.8, 0.08)
			destination += Vector3.yAxis * 2
			tween(p, T.FinisherSeconds * 0.55, { CFrame = CFrame.new(destination) * CFrame.Angles(a * 2, a, a) })
			tween(p, T.FinisherSeconds * 0.45, {
				CFrame = CFrame.new(destination - Vector3.yAxis * T.FinisherCoreSize) * CFrame.Angles(a * 3, a * 2, a),
			}, T.FinisherSeconds * 0.55)
			tween(p, T.FinisherFadeSeconds, { Transparency = 1 }, T.FinisherHoldSeconds)
			continue
		elseif id == "bubble_bloom" then
			p.Shape, p.Material, p.Transparency = Enum.PartType.Ball, Enum.Material.Glass, 0.2
			p.Size = Vector3.one * 0.8
			destination = origin + dir * T.FinisherRadius * 0.55 + Vector3.yAxis * 3
			tween(p, T.FinisherSeconds * 0.55, { Size = Vector3.one * (1.4 + i % 3 * 0.4) })
			tween(p, T.FinisherSeconds * 0.75, { CFrame = CFrame.new(destination) })
			local popAt = T.FinisherHoldSeconds + i / count * T.FinisherFadeSeconds * 0.5
			tween(p, T.FinisherFadeSeconds, { Size = Vector3.one * 0.1, Transparency = 1 }, popAt)
			if not lowDetail and i % 4 == 0 then
				after(p, popAt, function()
					wave(root, "BubblePop", p.Position, basis, accent, T.FinisherRadius * 0.2, T.FinisherFadeSeconds, 0)
				end)
			end
			continue
		elseif id == "brick_boom" then
			p.Material, p.Size = Enum.Material.SmoothPlastic, Vector3.new(0.7 + i % 3 * 0.2, 0.7, 0.7)
			destination += Vector3.yAxis * 1.5
			tween(p, T.FinisherSeconds * 0.4, { CFrame = CFrame.new(destination) * CFrame.Angles(a, a * 2, a) })
			tween(p, T.FinisherSeconds * 0.6, {
				CFrame = CFrame.new(destination - Vector3.yAxis * T.FinisherCoreSize) * CFrame.Angles(a * 2, a * 3, a),
			}, T.FinisherSeconds * 0.4)
			tween(p, T.FinisherFadeSeconds, { Transparency = 1 }, T.FinisherHoldSeconds)
			continue
		elseif id == "starfall" then
			p.Name, p.Size = "StarGem", Vector3.new(0.65, 0.65, 0.18)
			p.CFrame = CFrame.new(origin + dir * 2.5)
			if not lowDetail then
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.Position, a1.Position = Vector3.new(-0.15, 0, 0), Vector3.new(0.15, 0, 0)
				a0.Parent, a1.Parent = p, p
				local trail = Instance.new("Trail")
				trail.Attachment0, trail.Attachment1, trail.Color = a0, a1, ColorSequence.new(color, accent)
				trail.Lifetime, trail.LightEmission, trail.Transparency = 0.2, 1, NumberSequence.new(0.1, 1)
				trail.Parent = p
			end
			tween(p, T.FinisherSeconds * 0.25, { CFrame = CFrame.new(origin) })
			tween(p, T.FinisherSeconds * 0.7, {
				CFrame = CFrame.new(destination) * basis * CFrame.Angles(0, 0, math.pi / 4),
				Size = Vector3.one * 0.12,
				Transparency = 1,
			}, T.FinisherSeconds * 0.25)
			continue
		else
			p.Material, p.Transparency = Enum.Material.Glass, 0.15
			p.Size = Vector3.new(0.35, 0.8, 0.2)
		end
		tween(
			p,
			T.FinisherSeconds,
			{ CFrame = CFrame.new(destination) * CFrame.Angles(a * 2, a * 3, a), Transparency = 1 }
		)
	end
	if id == "starfall" and not lowDetail then
		for i = 1, 4 do
			local pose = CFrame.new(origin) * basis * CFrame.Angles(0, 0, i * math.pi / 2)
			local ray = part(root, "NovaRay", accent, Vector3.one * 0.1, pose)
			ray.Transparency = 1
			after(ray, burstDelay, function()
				ray.Transparency = 0.15
				tween(ray, T.FinisherSeconds * 0.5, {
					Size = Vector3.new(T.FinisherRadius, 0.1, 0.1),
					CFrame = pose * CFrame.new(T.FinisherRadius / 2, 0, 0),
					Transparency = 1,
				})
			end)
		end
	end
	if id == "brick_boom" and not lowDetail then
		for i = 1, 3 do
			local fire = part(
				root,
				"ToyFireball",
				color,
				Vector3.one * 0.5,
				CFrame.new(origin + Vector3.new(i - 2, 0.5, 0)),
				Enum.PartType.Ball,
				"BlastBloom"
			)
			tween(
				fire,
				T.FinisherSeconds * 0.55,
				{ Size = Vector3.one * (3 + i), CFrame = fire.CFrame + Vector3.yAxis * 2, Transparency = 1 },
				i * 0.05
			)
		end
	end
	Debris:AddItem(root, T.FinisherSeconds + 0.2)
	return root
end
return FX
