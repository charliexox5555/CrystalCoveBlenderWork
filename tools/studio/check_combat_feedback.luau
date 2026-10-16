-- Short presentation-only check in Play / Client. No match, grant, camera or device changes.
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local client = Players.LocalPlayer.PlayerScripts.Client
local Scene = require(client.Presentation.FightScene)
local Hud = require(client.UI.Screens.FightHud)
local Shatter = require(client.Controllers.ShatterController)
local VFX = require(RS.Shared.Config.Balance).CombatVFX
local camera = workspace.CurrentCamera
local checks = 0
local function check(value, message)
	assert(value, message)
	checks += 1
end
local scenes, gui = {}, nil
local ok, problem = pcall(function()
	for index, ids in { { "pop", "crescent_axe" }, { "jam", "arc_coil" }, { "prism", "briar_flask" } } do
		local scene = Scene.new({
			Id = "FeedbackCheck" .. index,
			Frame = CFrame.new(camera.CFrame:PointToWorldSpace(Vector3.new(0, 0, -12))),
			A = { Id = ids[1] },
			B = { Id = ids[2] },
			ReleasePrototype = true,
		}, { 100, 100 }, { SetCracks = function() end })
		table.insert(scenes, scene)
		scene.Muted = true
		scene:SetViewing(true)
		for side = 1, 2 do
			scene:Pose(side, Vector3.new(if side == 1 then -2 else 2, -4, 0), 0, Vector3.zero)
			check(scene.Fighters[side].Health.Enabled, "health missing")
		end
		local r = {
			Hp = { 25, 100 },
			Frozen = { false, false },
			Shield = { false, false },
			Rage = { false, false },
			Slam = { false, false },
			Pump = { false, false },
			Power = { 0.5, 0.5 },
			Effect = { { 0 }, { 0 } },
		}
		scene:Update(r, 0)
		check(scene.Fighters[1].Health.Amount.Text == "25 HP", "HP is not authoritative snapshot value")
		check(scene.Fighters[1].Health.Amount.TextColor3 == require(client.UI.Theme).Palette.rubyLight, "low HP color")
		local combat = scene.Combat
		combat:Event({ Type = "Charge", Side = 1, Time = 0 })
		check(combat.Root:FindFirstChild("Signature_ContactGlint") ~= nil, "charge feedback missing")
		combat:Event({ Type = "CastStart", CastId = 1, Side = 1, Time = 0, Windup = 0.45, Shape = "ray" })
		combat:Update(r, 0.2)
		check(combat.Casts[1].Ring.Size.X > combat.Assets.Meshes.Ring.Size.X * VFX.ChargeRingScale, "windup growth")
		combat:Event({
			Type = "CastRelease",
			CastId = 1,
			Side = 1,
			Time = 0.2,
			Duration = 0.14,
			Shape = "ray",
			Origin = { 0, -4, 0 },
			Direction = { 1, 0, 0 },
			Range = 7,
			Radius = 0.18,
		})
		check(combat.Casts[1].Halo.Width0 > combat.Casts[1].Beam.Width0, "ray halo")
		combat:Event({ Type = "CastContact", CastId = 1, Side = 1, Time = 0.2, Missed = true })
		check(combat.Casts[1].Root:GetAttribute("Missed") == true, "miss presentation")
		combat:Update(r, 1)
		check(next(combat.Casts) == nil, "cast lifetime")
		Shatter:HitBurst(scene.Fighters[1], scene.Fighters[2], { CritA = true }, scene.Root)
		check(scene.Root:FindFirstChild("ContactRing") ~= nil, "ordinary contact ring")
		scene:SetViewing(false)
		check(not scene.Fighters[1].Health.Enabled, "watch exit health cleanup")
		scene:SetViewing(true)
		scene:HideBroken(1)
		check(not scene.Fighters[1].Health.Enabled, "shatter health cleanup")
		scene:StartFinisher(1, os.clock())
		check(not scene.Fighters[2].Health.Enabled, "finisher health cleanup")
	end
	gui = Instance.new("ScreenGui")
	gui.Name, gui.Parent = "FeedbackFadeCheck", Players.LocalPlayer.PlayerGui
	local hud = { Gui = gui }
	Hud.Popup(hud, "−12", camera.CFrame:PointToWorldSpace(Vector3.new(0, 0, -10)), Color3.new(1, 1, 1))
	local popup = assert(hud.Popups["−12"])
	-- Exercise the legacy stroke as well as the UIStroke used by current templates.
	popup.TextStrokeTransparency = 0
	task.wait(0.3)
	check(popup.TextTransparency > 0 and popup.TextTransparency < 1, "text tween did not run")
	check(popup.TextStrokeTransparency > 0, "legacy text stroke did not fade")
	check(popup.UIStroke.Transparency > 0.15, "UIStroke did not fade")
	task.wait(0.8)
	check(popup.Parent == nil, "popup lifetime")
end)
for _, scene in scenes do
	local root = scene.Root
	scene:Destroy()
	check(root.Parent == nil, "scene cleanup")
end
if gui then
	gui:Destroy()
end
assert(ok, problem)
return { Checks = checks, Result = "PASS", Scope = "Presentation fixture; creator reviews live feel" }
