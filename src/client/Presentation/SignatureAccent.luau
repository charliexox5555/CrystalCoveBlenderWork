-- Bounded mesh accents: readable windup, release and confirmed payoff from every viewing angle.
local VFX = require(game.ReplicatedStorage.Shared.Config.Balance).CombatVFX
local Visuals = require(game.ReplicatedStorage.Shared.Config.CombatKitVisuals)
local Accent = {}
function Accent.create(self, cast, mode, color)
	local f = self.Scene.Fighters[cast.Side]
	if f.LowDetail then
		return
	end
	cast.Accent = { Mode = mode, Chips = {}, Rings = {} }
	local a = cast.Accent
	for i = 1, VFX.AccentChips do
		local name = if mode == "windup" then "CrystalChip" else Visuals[f.Id].MeshB
		local p = self:Mesh(name, cast.Root, color)
		p.Name, p.Material = "AccentChip" .. i, Enum.Material.Neon
		p.Size *= VFX.AccentSize / math.max(p.Size.X, p.Size.Y, p.Size.Z)
		a.Chips[i] = { Mesh = p, Size = p.Size }
	end
	for i = 1, 2 do
		local p = self:Mesh("Ring", cast.Root, color)
		p.Name, p.Material = "AccentRing" .. i, Enum.Material.Neon
		a.Rings[i] = { Mesh = p, Size = p.Size / math.max(p.Size.X, p.Size.Y) }
	end
end

function Accent.step(self, cast, age)
	local a = cast.Accent
	if not a then
		return
	end
	local duration = if a.Mode == "windup" then math.max(cast.Event.Windup, 0.01) else VFX.AccentSeconds
	local progress = math.clamp(age / duration, 0, 1)
	if progress >= 1 and a.Mode ~= "windup" then
		for _, chip in a.Chips do
			chip.Mesh:Destroy()
		end
		for _, ring in a.Rings do
			ring.Mesh:Destroy()
		end
		cast.Accent = nil
		return
	end
	local f = self.Scene.Fighters[cast.Side]
	local origin = cast.Origin or f.Body.Position
	local direction = cast.Direction or self.Scene.Frame.RightVector
	local basis = CFrame.lookAt(origin, origin + direction)
	local radius = if a.Mode == "windup" then VFX.AccentTravel * (1 - progress) else VFX.AccentTravel * progress
	for i, chip in a.Chips do
		local angle = i / #a.Chips * math.pi * 2 + age * VFX.AccentSpin
		local p = chip.Mesh
		p.CFrame = basis
			* CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
			* CFrame.Angles(angle, angle, angle)
		p.Size = chip.Size * (if a.Mode == "windup" then 1 else 1 - progress * 0.6)
		p.Transparency = if a.Mode == "windup" then VFX.ChargeLit else progress
	end
	for i, ring in a.Rings do
		ring.Mesh.CFrame = basis * CFrame.Angles(if i == 1 then 0 else math.pi / 2, 0, age)
		ring.Mesh.Size = ring.Size * math.max(0.05, radius * VFX.AccentRingSize / VFX.AccentTravel)
		ring.Mesh.Transparency = if a.Mode == "windup"
			then VFX.StatusTransparency
			else VFX.StatusTransparency + progress * (1 - VFX.StatusTransparency)
	end
end
return Accent
