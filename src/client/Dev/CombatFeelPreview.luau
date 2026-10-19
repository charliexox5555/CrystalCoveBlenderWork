-- Studio-only CombatFeel preview (workstream B). Stages one beat on a local scene up in the sky, slowed down so a
-- screenshot catches it. Presentation only: no match, remote or server state. Driven from
-- tools/studio/preview_combat_feel.luau through the MCP in Play / Client.
-- mode: a tier ("Glance", "Solid", "Smash", "Crit", "Block") or "Perfect", "Manual", "KO", "Victory", "Tension",
-- or "Cleanup" (destroys the preview and returns the camera). slow: effect durations multiplied by this.
return function(mode: string?, slow: number?)
	if not game:GetService("RunService"):IsStudio() then
		return "studio only"
	end
	local MODE = mode or "Crit"
	local SLOW = slow or 25
	local RS = game:GetService("ReplicatedStorage")
	local Players = game:GetService("Players")
	local client = Players.LocalPlayer.PlayerScripts.Client
	local camera = workspace.CurrentCamera

	for _, old in workspace:GetChildren() do
		if old.Name == "LocalFight_FeelPreview" then
			old:Destroy()
		end
	end
	local grade = game.Lighting:FindFirstChild("FightFeelGrade")
	if grade then
		grade:Destroy()
	end
	local RunService = game:GetService("RunService")
	RunService:UnbindFromRenderStep("FeelPreviewCamera")
	if MODE == "Cleanup" then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		return "cleaned"
	end

	local Scene = require(client.Presentation.FightScene)
	local CombatFeel = require(client.Presentation.CombatFeel)
	local Impact = require(client.Presentation.ImpactBeat)
	local Shatter = require(client.Controllers.ShatterController)
	local C = require(RS.Shared.Config.CombatFeel)
	local Balance = require(RS.Shared.Config.Balance)
	Shatter:Init()

	-- Up in the open sky above the player, so the background is clean.
	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local look = (camera.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
	local origin = (if root then root.Position else camera.CFrame.Position) + Vector3.yAxis * 30 + look * 20
	local frame = CFrame.lookAt(origin, origin + look)
	local scene = Scene.new({
		Id = "FeelPreview",
		Frame = frame + Vector3.yAxis * 6,
		A = { Id = "pop" },
		B = { Id = "prism" },
	}, { 100, 100 }, Shatter)
	scene.Muted = true
	scene:SetViewing(true)
	local view = { Viewing = true, Scene = scene, Side = 1, Participant = true, Phase = "Fighting", RenderTime = 0 }
	local feel = CombatFeel.new(view)
	scene.Feel = feel
	local L = Balance.Motion.StringLength
	local function pose()
		scene:Pose(1, Vector3.new(0.12, -1, 0).Unit * L, 0, Vector3.zero)
		scene:Pose(2, Vector3.new(-0.12, -1, 0).Unit * L, 0, Vector3.zero)
	end
	pose()
	local hp = if MODE == "Tension" or MODE == "KO" then { 18, 70 } else { 60, 70 }
	scene:Update({
		Hp = hp,
		Power = { 0, 0 },
		Frozen = { false, false },
		Shield = { false, false },
		Rage = { false, false },
		Slam = { false, false },
		Pump = { false, false },
		Effect = { {}, {} },
	}, 0)

	local a, b = scene.Fighters[1].Body.Position, scene.Fighters[2].Body.Position
	local mid = (a + b) / 2
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = Balance.Feel.CameraFieldOfView
	camera.CFrame = CFrame.lookAt(mid + frame.LookVector * -16 + Vector3.yAxis * 1.5, mid)

	local function slowed(tier)
		local copy = table.clone(tier)
		copy.Seconds *= SLOW
		return copy
	end
	-- Freeze particles mid-flight for the capture.
	local function freezeParticles()
		task.wait(0.06)
		for _, d in scene.Root:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				d.TimeScale = 0.02
			end
		end
	end
	local now = os.clock()
	local library = RS.Assets.VFX.Combat
	-- Slow the beat helpers too.
	feel.Burst = function(self, tier, position)
		local slowTier = table.clone(tier)
		slowTier.Seconds *= SLOW
		return CombatFeel.Burst(self, slowTier, position)
	end
	feel.Flash = function(self, side, seconds)
		return CombatFeel.Flash(self, side, seconds * SLOW)
	end

	if C.Tiers[MODE] then
		local tier = slowed(C.Tiers[MODE])
		feel:Settings(now)
		Impact.tier(scene.Root, library, mid, tier, { Particles = feel.Particles, Light = true })
		local dir = (b - a).Unit
		feel:React(2, tier.Struck, dir)
		feel:React(1, tier.Striker, -dir)
		feel:Flash(2, tier.ImpactFlash)
		feel:Glint(2, tier.CrackGlint * SLOW)
		feel:Punch(tier.Fov)
		scene.Fighters[1].Glints:Emit(tier.Striker.Glints)
	elseif MODE == "Perfect" then
		feel:Perfect({ Side = 1 }, now)
	elseif MODE == "Manual" then
		feel:Cast({ Type = "CastStart", Side = 1, Manual = true, CastId = "preview", Time = 0 }, now)
	elseif MODE == "KO" then
		feel:KO({ Side = 1 }, now)
		Impact.tier(scene.Root, library, mid, slowed(C.Tiers.Crit), { Particles = 1, Light = true })
	elseif MODE == "Victory" then
		feel:Victory(2, now)
	elseif MODE == "Tension" then
		feel:Update({ Hp = hp }, now)
	end
	freezeParticles()
	-- Step the springs to near their peak and apply the camera offset/FOV like FightView does.
	for _ = 1, 5 do
		feel:Step(1 / 60, os.clock())
		pose()
		if MODE == "Tension" then
			feel.Grade.Tension = 1
		end
	end
	local offset, fov = feel:Camera(os.clock())
	local shot = camera.CFrame * offset
	local shotFov = Balance.Feel.CameraFieldOfView + fov
	-- Hold the shot against the default camera scripts until MODE = "Cleanup".
	RunService:BindToRenderStep("FeelPreviewCamera", Enum.RenderPriority.Camera.Value + 2, function()
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame, camera.FieldOfView = shot, shotFov
	end)
	return string.format("%s staged: fov %.1f", MODE, shotFov)
end
