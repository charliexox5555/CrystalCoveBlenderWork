-- Play / Client. Frozen release poses for art review, not gameplay/balance evidence.
local RS = game.ReplicatedStorage
local client = game.Players.LocalPlayer.PlayerScripts.Client
local Scene = require(client.Presentation.FightScene)
local B = require(RS.Shared.Config.Balance)
local Geometry = require(RS.Shared.Config.ReleaseGeometry)
local scenes, guis = {}, {}
local camera = workspace.CurrentCamera
local oldFov = camera.FieldOfView
local oldType, oldCFrame = camera.CameraType, camera.CFrame
local destroyed = false
local function cleanup()
	if destroyed then
		return
	end
	destroyed = true
	for _, scene in scenes do
		scene:Destroy()
	end
	for gui, enabled in guis do
		if gui.Parent then
			gui.Enabled = enabled
		end
	end
	camera.FieldOfView = oldFov
	camera.CameraType, camera.CFrame = oldType, oldCFrame
end
local ok, problem = pcall(function()
	for _, gui in game.Players.LocalPlayer.PlayerGui:GetChildren() do
		if gui:IsA("ScreenGui") then
			guis[gui], gui.Enabled = gui.Enabled, false
		end
	end
	camera.FieldOfView = B.Feel.CameraFieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 216, 3035), Vector3.new(0, 211, 3000))
	for i, id in { "prism_blade", "glass_dragon", "galaxy_orb" } do
		local kit = B.CombatRelease.Kits[id]
		local frame = CFrame.new((i - 2) * 10 + 3, 210 + 7 + Geometry[id].Center * B.Motion.GlassyScale, 3000)
		local scene = Scene.new(
			{ Id = "PowerBeat" .. i, A = { Id = id }, B = { Id = "jam" }, Frame = frame },
			{ 100, 100 },
			{ SetCracks = function() end }
		)
		table.insert(scenes, scene)
		scene.Muted = true
		scene:SetViewing(true)
		scene:Pose(1, Vector3.new(0, -7, 0), 0, Vector3.zero)
		scene:Pose(2, Vector3.new(0, -7, 0), 0, Vector3.zero)
		local origin = frame:PointToObjectSpace(scene.Fighters[1].Body.Position)
		scene.Combat:Event({
			Type = "CastRelease",
			Side = 1,
			CastId = 1,
			Time = 0,
			Shape = kit.Shape,
			Origin = { origin.X, origin.Y, origin.Z },
			Direction = { 1, 0, 0 },
			Duration = kit.Duration,
			Range = kit.Range,
			Radius = kit.Radius,
			Arc = kit.Arc,
			Pulses = kit.Pulses,
			Path = kit.Path,
		})
		scene:Update({
			Hp = { 100, 100 },
			Power = { 1, 0 },
			Frozen = { false, false },
			Shield = { false, false },
			Rage = { false, false },
			Slam = { false, false },
			Pump = { false, false },
			Effect = { { 0, 0, 0, 0, 0 }, { 0, 0, 0, 0, 0 } },
		}, 0.24)
	end
end)
if not ok then
	cleanup()
	error(problem)
end
task.delay(15, cleanup)
return { Scenes = 3, PreviewOnly = true, AutoCleanup = 15, CameraPosition = { 0, 216, 3035 }, LookAt = { 0, 211, 3000 } }
