-- Bounded cosmetic explosions. No Explosion instance, humanoid damage or world physics.
local RS = game:GetService("ReplicatedStorage")
local TweenService, Debris = game:GetService("TweenService"), game:GetService("Debris")
local C = require(RS.Shared.Config.RoundCosmetics)
local T = require(RS.Shared.Config.Balance).CosmeticPresentation
local FX = {}
local function part(root, name, color, size, cf, shape)
	local p = Instance.new("Part")
	p.Name, p.Color, p.Material, p.Size, p.CFrame = name, color, Enum.Material.Neon, size, cf
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	if shape then
		p.Shape = shape
	end
	p.Parent = root
	return p
end
local function tween(p, seconds, props, delay)
	if delay and delay > 0 then
		task.delay(delay, function()
			if p.Parent then
				tween(p, seconds, props)
			end
		end)
		return
	end
	TweenService:Create(p, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end
function FX.emit(parent, id, origin, lowDetail, orientation)
	local def = C.ByCategory.Finishers[id] or C.Finishers[1]
	id = def.Id
	local root = Instance.new("Folder")
	root.Name, root.Parent = "Finisher_" .. id, parent
	root:SetAttribute("CosmeticOnly", true)
	local color, accent = Color3.fromHex(def.Color), Color3.fromHex(def.Accent)
	local basis = orientation or workspace.CurrentCamera.CFrame.Rotation
	local core = part(root, "BurstCore", color, Vector3.one * 0.3, CFrame.new(origin), Enum.PartType.Ball)
	core.Transparency = 0.2
	tween(core, T.FinisherSeconds * 0.35, { Size = Vector3.one * T.FinisherCoreSize, Transparency = 1 })
	for i = 1, (if lowDetail then 1 else 2) do
		local ring = RS.Assets.VFX.Combat.Meshes.Ring:Clone()
		ring.Name, ring.Material, ring.Color = "Shockwave", Enum.Material.Neon, if i == 1 then color else accent
		ring.CFrame = CFrame.new(origin) * basis * CFrame.Angles(if i == 2 then math.pi / 2 else 0, 0, 0)
		ring.Size *= 0.25
		ring.Parent = root
		tween(
			ring,
			T.FinisherSeconds * 0.65,
			{ Size = RS.Assets.VFX.Combat.Meshes.Ring.Size * T.FinisherRadius, Transparency = 1 }
		)
	end
	local count = if lowDetail then math.floor(T.FinisherParts / 2) else T.FinisherParts
	for i = 1, count do
		local a = i / count * math.pi * 2
		local dir = basis:VectorToWorldSpace(Vector3.new(math.cos(a), math.sin(a), math.sin(a * 3) * 0.35)).Unit
		local p = part(root, "BurstPiece", if i % 2 == 0 then color else accent, Vector3.one * 0.5, CFrame.new(origin))
		local destination = origin + dir * T.FinisherRadius
		if id == "party_burst" then
			p.Material, p.Color, p.Size =
				Enum.Material.SmoothPlastic, Color3.fromHSV(i / count, 0.7, 1), Vector3.new(0.35, 0.8, 0.08)
			destination += Vector3.yAxis * 2
			tween(p, T.FinisherSeconds * 0.55, { CFrame = CFrame.new(destination) * CFrame.Angles(a * 2, a, a) })
			tween(p, T.FinisherFadeSeconds, { Transparency = 1 }, T.FinisherHoldSeconds)
			continue
		elseif id == "bubble_bloom" then
			p.Shape, p.Material, p.Transparency = Enum.PartType.Ball, Enum.Material.Glass, 0.2
			p.Size = Vector3.one * 0.8
			destination = origin + dir * T.FinisherRadius * 0.55 + Vector3.yAxis * 3
			tween(p, T.FinisherSeconds * 0.55, { Size = Vector3.one * (1.4 + i % 3 * 0.4) })
			tween(p, T.FinisherSeconds * 0.75, { CFrame = CFrame.new(destination) })
			tween(p, T.FinisherFadeSeconds, { Size = Vector3.one * 0.1, Transparency = 1 }, T.FinisherHoldSeconds)
			continue
		elseif id == "brick_boom" then
			p.Material, p.Size = Enum.Material.SmoothPlastic, Vector3.new(0.7 + i % 3 * 0.2, 0.7, 0.7)
			destination += Vector3.yAxis * 1.5
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
	if id == "brick_boom" and not lowDetail then
		for i = 1, 3 do
			local fire = part(
				root,
				"ToyFireball",
				color,
				Vector3.one * 0.5,
				CFrame.new(origin + Vector3.new(i - 2, 0.5, 0)),
				Enum.PartType.Ball
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
