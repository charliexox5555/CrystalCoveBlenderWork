-- Compact volumetric star, expanding rings and glass chips at confirmed contact points.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local VFX = require(game.ReplicatedStorage.Shared.Config.Balance).CombatVFX
local Impact = {}
function Impact.emit(root, assets, origin, color, strong, lowDetail)
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "ImpactBeat", root
	local basis = workspace.CurrentCamera.CFrame.Rotation
	local count = if lowDetail then 4 else VFX.ImpactStreaks
	local size = if strong then 1.25 else 1
	for i = 1, count do
		local angle = i / count * math.pi * 2
		local dir = basis:VectorToWorldSpace(Vector3.new(math.cos(angle), math.sin(angle), 0))
		local p = Instance.new("Part")
		p.Name, p.Material, p.Color =
			"ImpactSpoke", Enum.Material.Neon, if i % 2 == 0 then color else Color3.new(1, 1, 1)
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
		p.Size = Vector3.new(0.1, 0.1, VFX.ImpactStreakLength * size)
		p.CFrame = CFrame.lookAt(origin + dir * VFX.ImpactStreakLength / 2, origin + dir * VFX.ImpactSpread)
		p.Parent = folder
		TweenService:Create(p, TweenInfo.new(VFX.ImpactSeconds, Enum.EasingStyle.Quad), {
			CFrame = p.CFrame + dir * VFX.ImpactSpread * size,
			Size = Vector3.new(0.025, 0.025, 0.15),
			Transparency = 1,
		}):Play()
	end
	for i = 1, (if lowDetail then 1 else 2) do
		local ring = assets.Meshes.Ring:Clone()
		ring.Name, ring.Material, ring.Color = "ImpactRing", Enum.Material.Neon, color
		ring.Size *= VFX.ImpactRingStart
		ring.CFrame = CFrame.new(origin) * basis * CFrame.Angles(if i == 2 then math.pi / 2 else 0, 0, 0)
		ring.Parent = folder
		TweenService:Create(ring, TweenInfo.new(VFX.ImpactSeconds), {
			Size = assets.Meshes.Ring.Size * (if strong then VFX.ImpactRingEnd else VFX.ImpactRingNormalEnd),
			Transparency = 1,
		}):Play()
	end
	local flash = Instance.new("Part")
	flash.Name, flash.Shape, flash.Material = "ContactCore", Enum.PartType.Ball, Enum.Material.Neon
	flash.Anchored, flash.CanCollide, flash.CanTouch, flash.CanQuery, flash.CastShadow =
		true, false, false, false, false
	flash.Color, flash.Size, flash.Position, flash.Parent = Color3.new(1, 1, 1), Vector3.one * 0.25, origin, folder
	TweenService:Create(flash, TweenInfo.new(VFX.ImpactSeconds), { Size = Vector3.one * size, Transparency = 1 }):Play()
	if not lowDetail then
		local chips = assets.Particles.GlassChips:Clone()
		chips.Color, chips.Parent = ColorSequence.new(color), flash
		chips:Emit(VFX.ImpactChipCount)
	end
	Debris:AddItem(folder, math.max(VFX.ImpactSeconds, assets.Particles.GlassChips.Lifetime.Max) + VFX.Tail)
end
return Impact
