-- Play / Client. Exercises real scene/detail/shatter/finisher code without desktop input.
local RS = game.ReplicatedStorage
local client = game.Players.LocalPlayer.PlayerScripts.Client
local Scene = require(client.Presentation.FightScene)
local Shatter = require(client.Controllers.ShatterController)
local Camera = require(client.Presentation.FinisherCamera)
local G = require(RS.Shared.Config.Glassies)
local B = require(RS.Shared.Config.Balance)
local checks = 0
local function check(value, message)
	assert(value, message)
	checks += 1
end
local shatter = setmetatable({}, { __index = Shatter })
shatter:Init()
local scene, stage
local ok, problem = pcall(function()
	for _, def in G.ReleaseList do
		scene = Scene.new(
			{ Id = "GhostCheck_" .. def.Id, A = { Id = def.Id }, B = { Id = "jam" }, Frame = CFrame.new(0, 210, 3000) },
			{ 100, 100 },
			shatter
		)
		scene.Muted = true
		scene:SetViewing(true)
		scene:Pose(1, Vector3.new(-1, -7, 0), 0, Vector3.zero)
		scene:Pose(2, Vector3.new(1, -7, 0), 0, Vector3.zero)
		for _, f in scene.Fighters do
			f.SoundScale = 0
		end
		local r = {
			Hp = { 100, 100 },
			Power = { 1, 1 },
			Frozen = { false, false },
			Shield = { false, false },
			Rage = { false, false },
			Slam = { false, false },
			Pump = { false, false },
			Effect = { { 0, 0, 0, 0, 0 }, { 0, 0, 0, 0, 0 } },
		}
		scene:Update(r, 0)
		local f = scene.Fighters[1]
		shatter:Break(f, scene.Root)
		check(f.Broken and not f.Health.Enabled, "Break owns death state " .. def.Id)
		r.Hp[1] = 0
		for i = 1, 5 do
			scene:Update(r, i * 0.1)
		end
		for _, part in f.Parts do
			check(part.Transparency == 1, "No resurrected glass/detail " .. def.Id .. "/" .. part.Name)
		end
		check(not f.Glints.Enabled and not f.Trail.Enabled, "No ghost emitters " .. def.Id)
		scene:Destroy()
		scene = nil
	end
	stage = Instance.new("Folder")
	stage.Name, stage.Parent = "RoundFinishFixture", workspace
	local avatar = Instance.new("Model")
	avatar.Name, avatar.Parent = "Bot2", stage
	local torso = Instance.new("Part")
	torso.Name, torso.Anchored, torso.Parent = "Torso", true, avatar
	torso.Position, torso.LocalTransparencyModifier = Vector3.new(0, 200, 3000), 0.23
	local face = Instance.new("Decal")
	face.Transparency, face.Parent = 0.3, torso
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = avatar
	scene = Scene.new({
		Id = "FinishCheck",
		A = { Id = "galaxy_orb" },
		B = { Id = "jam" },
		Frame = CFrame.new(0, 210, 3000),
		StageName = stage.Name,
		AvatarPositions = { Vector3.new(-8, 200, 3000), torso.Position },
	}, { 100, 100 }, shatter)
	scene.Muted = true
	scene:SetViewing(true)
	scene:Pose(1, Vector3.new(-1, -7, 0), 0, Vector3.zero)
	scene:Pose(2, Vector3.new(1, -7, 0), 0, Vector3.zero)
	for _, f in scene.Fighters do
		f.SoundScale = 0
	end
	scene:HideBroken(2)
	scene:StartFinisher(2, 100)
	local finish = scene.Finisher
	check(finish ~= nil, "Finisher starts")
	local r = {
		Hp = { 100, 0 },
		Power = { 1, 1 },
		Frozen = { false, false },
		Shield = { false, false },
		Rage = { false, false },
		Slam = { false, false },
		Pump = { false, false },
		Effect = { { 0, 0, 0, 0, 0 }, { 0, 0, 0, 0, 0 } },
	}
	finish:Step(100 + B.Feel.FinisherPause + B.Feel.FinisherRiseSeconds + 0.2)
	local positions = {}
	for _, p in scene.Fighters[1].Parts do
		positions[p] = p.CFrame
	end
	scene:Update(r, 1)
	for p, cf in positions do
		check((p.Position - cf.Position).Magnitude < 0.001, "Flying details cannot snap back")
	end
	scene.CameraFocus = Vector3.new(0, 202, 3000)
	local focus = scene.CameraFocus
	local normal = CFrame.lookAt(focus + Vector3.zAxis * 33, focus)
	local from = CFrame.lookAt(focus + Vector3.xAxis * 33, focus)
	check(Camera.pose(finish, normal, from, 100) == from, "Camera begins at orbited pose")
	check(
		(Camera.pose(finish, normal, from, 100 + B.Feel.FinisherCameraResetSeconds).Position - normal.Position).Magnitude
			< 0.001,
		"Normal shot before flight"
	)
	local impactAt = 100 + B.Feel.FinisherPause + B.Feel.FinisherRiseSeconds + B.Feel.FinisherFlySeconds
	local close = Camera.pose(finish, normal, from, impactAt)
	check((close.Position - normal.Position).Magnitude > 1, "Camera moves toward recipient")
	check(
		(close.Position - (finish.Target + Vector3.yAxis * B.Feel.FinisherCameraTargetHeight)).Magnitude < 33,
		"Mild zoom"
	)
	local returned = Camera.pose(
		finish,
		normal,
		from,
		impactAt + B.Feel.FinisherCameraHoldSeconds + B.Feel.FinisherCameraReturnSeconds + 0.1
	)
	check((returned.Position - normal.Position).Magnitude < 0.001, "Camera returns")
	check(finish:Step(impactAt + 0.01), "Impact completes")
	check(
		math.abs(torso.LocalTransparencyModifier - 0.23) < 0.001 and math.abs(face.Transparency - 0.3) < 0.001,
		"Avatar and face remain visible"
	)
	check(humanoid.Health == 100, "Cosmetic impact leaves health intact")
	check(scene.Root:FindFirstChild("GlassyImpact") ~= nil, "Avatar receives visible impact effect")
	check(scene.Fighters[1].Broken, "Winner hides at avatar impact")
	scene:Update(r, 2)
	for _, p in scene.Fighters[1].Parts do
		check(p.Transparency == 1, "Winner detail never reappears at arena center")
	end
end)
if scene then
	scene:Destroy()
end
if stage then
	stage:Destroy()
end
assert(ok, problem)
return { Passed = true, Checks = checks, Models = 24, AvatarUntouched = true, CameraSequence = true }
