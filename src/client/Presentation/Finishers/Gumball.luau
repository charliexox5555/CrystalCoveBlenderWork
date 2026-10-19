-- Gumball (gumball, Uncommon): a gumball machine drops over the foe, the crank turns twice while the gumballs
-- churn, the coin-slot lid pops, and glass gumballs burst out, bounce twice and pop into sparkles in sequence.
local Kit = require(script.Parent.Kit)
local Modules = require(script.Parent.Modules)
local Show = {}

local RED, GOLD, WHITE = Color3.fromHex("#FF5A4E"), Color3.fromHex("#FFD34E"), Color3.new(1, 1, 1)
local CANDY = {
	Color3.fromHex("#FF5A7A"),
	Color3.fromHex("#FFB547"),
	Color3.fromHex("#FFE45C"),
	Color3.fromHex("#6FE38A"),
	Color3.fromHex("#5EC8FF"),
	Color3.fromHex("#B48CFF"),
	Color3.fromHex("#FF8FD0"),
}

function Show.build(rig, s)
	local random = Random.new(71)
	local machine = rig:Group("GumballMachine")
	rig.Globe = rig:Actor("GumballGlobe", {
		Shape = Enum.PartType.Ball,
		Size = s.GlobeRadius * 2,
		Color = Color3.fromHex("#E8F7FF"),
		Material = Enum.Material.Glass,
		Transparency = 0.55,
		Reflectance = 0.35,
		Parent = machine,
	})
	rig.Base = rig:Actor("GumballBase", {
		Mesh = { "GumballBase" },
		Shape = Enum.PartType.Cylinder,
		NativeSize = Vector3.new(0.7, 1.32, 1.32),
		Size = s.BaseWidth,
		Color = RED,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.2,
		Parent = machine,
	})
	rig.Lid = rig:Actor("GumballLid", {
		Mesh = { "GumballLid" },
		Size = Vector3.new(0.55, 0.38, 0.12),
		Color = GOLD,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.3,
		Parent = machine,
	})
	rig.Crank = rig:Actor("GumballCrank", {
		Mesh = { "GumballCrank" },
		Size = 1.1,
		Color = GOLD,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.3,
		Parent = machine,
	})
	rig.MachineOutline = rig:Outline(machine, WHITE)
	-- Gumballs churning inside the globe before the burst.
	rig.Inside = {}
	for i = 1, (if rig.Low then 5 else 10) do
		table.insert(rig.Inside, {
			Actor = rig:Actor("InnerGumball", {
				Shape = Enum.PartType.Ball,
				Size = random:NextNumber(0.45, 0.6),
				Color = CANDY[(i - 1) % #CANDY + 1],
				Material = Enum.Material.SmoothPlastic,
				Reflectance = 0.25,
			}),
			Phase = random:NextNumber(0, math.pi * 2),
			Radius = random:NextNumber(0.4, 1.0),
			Height = random:NextNumber(-0.9, 0.5),
		})
	end
	Modules.Flash(rig, { At = s.PeakAt, Size = s.FlashSize, Color = Color3.fromHex("#FFF6E6") })
	Modules.Shockwave(rig, { At = s.PeakAt, Radius = s.RingRadius, Color = RED, Accent = GOLD, Count = 2 })
	Modules.ShardBurst(rig, {
		Name = "Gumball",
		At = s.PeakAt,
		Count = s.Balls,
		Shape = Enum.PartType.Ball,
		Size = { 0.55, 0.8 },
		Tints = CANDY,
		Material = Enum.Material.Glass,
		Transparency = 0.05,
		Reflectance = 0.35,
		Speed = s.BallSpeed,
		Lift = 5,
		Gravity = 24,
		Floor = s.Floor,
		Bounces = 2,
		Restitution = 0.5,
		Trails = 5,
		From = function()
			return Vector3.new(0, 0.3, 0)
		end,
		Dir = function(i, count, random)
			local a = (i - 0.5) / count * math.pi * 2
			return Vector3.new(math.cos(a), random:NextNumber(0.3, 0.9), math.sin(a) * 0.7).Unit
		end,
		PopAt = function(i)
			return s.PopStart + (i - 1) * s.PopStep
		end,
		PopEmitter = "GumballPop",
		Seed = 12,
	})
	rig:Emitter("Glints", {
		Texture = "StarGlint",
		Color = { WHITE, GOLD },
		Size = { { 0, 0.9 }, { 1, 0 } },
		Lifetime = { 0.3, 0.5 },
		Speed = { 10, 18 },
		Drag = 5,
	})
	rig:Burst(s.PeakAt, "Glints", s.Glints)
end

function Show.step(rig, t, s)
	local after = t - s.PeakAt
	local released = after >= 0
	local offset, squash =
		Modules.reveal({ Mode = "drop", T0 = 0, T1 = s.DropSeconds, Height = s.DropHeight, Squash = 0.18 }, t)
	-- The machine shrinks away after the gumballs are out.
	local leave = Kit.smooth((after - 0.6) / 0.5)
	local k = 1 - leave
	local frame = CFrame.new(rig:At(offset.X, offset.Y, offset.Z)) * rig.Facing.Rotation
	local globeCf = frame * CFrame.new(0, 0.3 * k, 0)
	local baseH = s.BaseWidth * 0.53
	local baseCf = frame * CFrame.new(0, (0.3 - s.GlobeRadius * 0.92 - baseH / 2) * k, 0)
	if rig.Base.Fallback then
		baseCf *= CFrame.Angles(0, 0, math.pi / 2)
	end
	local flash = released and after < 0.06
	rig.Globe.Part.Material = if flash then Enum.Material.Neon else Enum.Material.Glass
	rig:Place(rig.Globe, globeCf, squash * k, if leave >= 1 then 1 else 0)
	rig:Place(rig.Base, baseCf, squash * k, if leave >= 1 then 1 else 0)
	-- Crank on the right side, two turns during the wind-up.
	local turn = Kit.smooth((t - s.DropSeconds) / (s.PeakAt - s.DropSeconds)) * s.CrankTurns * math.pi * 2
	local crankCf = baseCf
		* CFrame.new(s.BaseWidth * 0.52 * k, 0, 0)
		* CFrame.Angles(turn, 0, 0)
		* CFrame.Angles(0, math.pi / 2, 0)
	rig:Place(rig.Crank, crankCf, squash * k, if leave >= 1 then 1 else 0)
	-- Lid on the front plate; pops off at the peak.
	local lidCf = baseCf * CFrame.new(0, 0.05 * k, -(s.BaseWidth * 0.47) * k)
	if released then
		lidCf = lidCf
			* CFrame.new(0, 3 * after - 6 * after * after, -4 * after)
			* CFrame.Angles(-after * 14, 0, after * 6)
		rig:Place(rig.Lid, lidCf, 1, Kit.smooth((after - 0.35) / 0.25))
	else
		rig:Place(rig.Lid, lidCf, squash, 0)
	end
	if rig.MachineOutline then
		rig.MachineOutline.Enabled = not released
		rig.MachineOutline.OutlineTransparency = 0.4
	end
	-- Churning gumballs inside the globe, faster as the crank turns.
	local churn = 2 + 10 * Kit.window(t, s.DropSeconds, s.PeakAt)
	for _, g in rig.Inside do
		if released then
			rig:Hide(g.Actor)
			continue
		end
		local a = g.Phase + t * churn
		local local_ = CFrame.new(math.cos(a) * g.Radius, g.Height + math.sin(a * 2) * 0.2, math.sin(a) * g.Radius)
		rig:Place(g.Actor, globeCf * local_, squash, 0)
	end
end

return Show
