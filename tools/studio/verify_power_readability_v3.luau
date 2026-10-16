-- Play / Client: focused real-prop/path/visibility checks. No desktop input or rewards.
local RS = game.ReplicatedStorage
local client = game.Players.LocalPlayer.PlayerScripts.Client
local Scene = require(client.Presentation.FightScene)
local Shatter = require(client.Controllers.ShatterController)
local B = require(RS.Shared.Config.Balance)
local checks, scene = 0, nil
local function check(value, message)
	assert(value, message)
	checks += 1
end
local function build(id)
	if scene then
		scene:Destroy()
	end
	local shatter = setmetatable({}, { __index = Shatter })
	shatter:Init()
	scene = Scene.new(
		{ Id = "ReadabilityCheck", A = { Id = id }, B = { Id = "jam" }, Frame = CFrame.new(0, 210, 3000) },
		{ 100, 100 },
		shatter
	)
	scene.Muted = true
	scene:SetViewing(true)
	scene:Pose(1, Vector3.new(1, -math.sqrt(48), 0), 0, Vector3.zero)
	scene:Pose(2, Vector3.new(-1, -math.sqrt(48), 0), 0, Vector3.zero)
	return {
		Hp = { 100, 100 },
		Power = { 1, 0 },
		Frozen = { false, false },
		Shield = { false, false },
		Rage = { false, false },
		Slam = { false, false },
		Pump = { false, false },
		Effect = { { 0, 0, 0, 0, 0 }, { 0, 0, 0, 0, 0 } },
	}
end
local function release(shape, id, time)
	local k = B.CombatRelease.Kits[id]
	scene.Combat:Event({
		Type = "CastRelease",
		Side = 1,
		CastId = 1,
		Time = time or 0,
		Shape = shape,
		Duration = k.Duration,
		Range = k.Range,
		Radius = k.Radius,
		Arc = k.Arc,
		Origin = { -2, -9, 0 },
		Direction = { 1, 0, 0 },
	})
end
local ok, problem = pcall(function()
	local r = build("crescent_axe")
	scene.Combat:Event({
		Type = "CastStart",
		Side = 1,
		CastId = 1,
		Time = 0,
		Windup = 0.65,
		Shape = "sweep",
		Direction = {
			1,
			0,
			0,
		},
	})
	scene:Update(r, 0.2)
	check(scene.Combat.Casts[1].Winding and scene.Combat.Casts[1].Weapon ~= nil, "Axe is visible during windup")
	release("sweep", "crescent_axe", 0.3)
	local cast = scene.Combat.Casts[1]
	for _, age in { 0, 0.1, 0.25, 0.5 } do
		scene:Update(r, 0.3 + age)
		local angle = (-0.5 + math.clamp(age / 0.5, 0, 1)) * cast.Event.Arc
		local expected = cast.Origin + (cast.Direction * math.cos(angle) + cast.Up * math.sin(angle)) * cast.Event.Range
		check(
			(cast.Weapon.AxeHead.Position - expected).Magnitude < 0.001,
			"Actual axe head matches the authoritative arc"
		)
		check(cast.Weapon.AxeHead.Transparency < 0.5, "Axe remains readable")
	end
	check(cast.Weapon.AxeHead:FindFirstChildOfClass("Trail") ~= nil, "Swept weapon trail")
	r = build("prism")
	scene.Combat:Event({
		Type = "CastStart",
		Side = 1,
		CastId = 1,
		Time = 0,
		Windup = 0.45,
		Shape = "ray",
		Direction = {
			1,
			0,
			0,
		},
	})
	scene:Update(r, 0.2)
	local lens
	for p in scene.Fighters[1].DetailStates do
		if p.Name == "RayLens" then
			lens = p
		end
	end
	check(lens and lens.Material == Enum.Material.Neon, "Lens glows while charging")
	check(lens.CFrame.LookVector:Dot(Vector3.xAxis) > 0.999, "Lens points toward shot")
	release("ray", "prism", 0.3)
	scene:Update(r, 0.6)
	cast = scene.Combat.Casts[1]
	check(cast and cast.Beam.Transparency.Keypoints[1].Value < 0.1, "Ray is readable after instant damage window")
	check(#cast.RayRings == 3 and cast.Halo.Width0 > cast.Beam.Width0 * 4, "Visible refraction and afterglow")
	r = build("pop")
	scene.Combat:Event({
		Type = "SignatureContact",
		Side = 1,
		CastId = 1,
		Time = 0,
		Shape = "contact",
		Point = {
			0,
			-9,
			0,
		},
	})
	scene:Update(r, 0.15)
	cast = scene.Combat.Casts[1]
	check(#cast.Caps > 0 and #cast.Waves == 2, "Cap launch and pressure wave")
	check((cast.Caps[1].Mesh.Position - cast.Caps[1].Base.Position).Magnitude > 0.5, "Cap visibly lifts")
	local f = scene.Fighters[1]
	local normal = f.Model:GetPivot()
	scene:Pose(1, Vector3.new(1, -math.sqrt(48), 0), 0, Vector3.zero)
	check(f.Model:GetPivot().Rotation ~= normal.Rotation, "Pressure recoil moves the glassy")
	scene:Update(r, 0.7)
	for p, rest in f.DetailStates do
		if p.Name:match("^Cap") then
			check(p.Transparency == rest.Transparency, "Original cap restored")
		end
	end
	r = build("jam")
	scene.Combat:Event({ Type = "CastRelease", Side = 1, CastId = 1, Time = 0, Shape = "guard", Duration = 2 })
	r.Effect[1][1] = 2
	scene:Update(r, 0.4)
	f = scene.Fighters[1]
	check(f.HeroLid and #f.LidParts == 2, "Real lid and ridge form shield")
	check(f.HeroLidOutline.Enabled and f.LidParts[1].Mesh.Transparency < 0.2, "Lid shield is visible")
	for _, entry in f.LidParts do
		check(entry.Original.Transparency == 1, "Original lid hidden while raised")
	end
	scene.Combat:Event({ Type = "SignatureBlock", Side = 1, Time = 0.5, Amount = 10 })
	r.Effect[1][1] = 0
	scene:Update(r, 0.6)
	check(not f.HeroLidOutline.Enabled, "No ghost outline after block")
	for _, entry in f.LidParts do
		check(
			entry.Mesh.Transparency == 1 and entry.Original.Transparency == entry.Rest.Transparency,
			"Shield resets on block"
		)
	end
	check(scene.Combat.Root:FindFirstChild("ImpactBeat", true) ~= nil, "Confirmed block has impact spokes")
	r = build("hourglass")
	scene.Combat:Event({ Type = "CastStart", Side = 1, CastId = 1, Time = 0, Shape = "heal", Windup = 0.85 })
	scene:Update(r, 0.2)
	f = scene.Fighters[1]
	normal = f.Model:GetPivot()
	scene:Pose(1, Vector3.new(1, -math.sqrt(48), 0), 0, Vector3.zero)
	check((normal.Position - f.Model:GetPivot().Position).Magnitude < 0.001, "Heal spin preserves hang point")
	check(normal.Rotation ~= f.Model:GetPivot().Rotation, "Hourglass really spins")
	check(#scene.Combat.Casts[1].Clock == 12, "Readable healing clock ticks")
	release("heal", "hourglass", 0.85)
	scene:Update(r, 1)
	check(
		scene.Combat.Casts[1].ClockRelease and not scene.Combat.Casts[1].Shots,
		"Healing release replaces sand attack"
	)
	scene.Combat:ClearTransient()
	check(next(scene.Combat.Casts) == nil, "All props owned by scene cleanup")
end)
if scene then
	scene:Destroy()
end
assert(ok, problem)
return { Passed = true, Checks = checks, Scope = "Native geometry/visibility, not subjective feel" }
