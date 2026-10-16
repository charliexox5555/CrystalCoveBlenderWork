-- Presentation fixture: every live model, every signature timeline and owned cleanup.
local RS = game.ReplicatedStorage
local client = game.Players.LocalPlayer.PlayerScripts.Client
local Scene = require(client.Presentation.FightScene)
local Shatter = require(client.Controllers.ShatterController)
local G = require(RS.Shared.Config.Glassies)
local B = require(RS.Shared.Config.Balance)
local Formula = require(RS.Shared.Formula)
local Portrait = require(client.UI.Components.GlassyPortrait)
local checks, partsMax = 0, 0
local function check(value, message)
	assert(value, message)
	checks += 1
end
local scene, gui
local ok, problem = pcall(function()
	gui = Instance.new("ScreenGui")
	gui.Name, gui.Parent = "ReleasePortraitCheck", game.Players.LocalPlayer.PlayerGui
	for index, def in G.ReleaseList do
		local kit = B.CombatRelease.Kits[def.Id]
		local hp = Formula.stats(def).HP
		scene = Scene.new(
			{ Id = "ReleaseCheck" .. index, A = { Id = def.Id }, B = { Id = "jam" }, Frame = CFrame.new(0, 200, 3000) },
			{ hp, 150 },
			setmetatable({}, { __index = Shatter })
		)
		scene.Shatter:Init()
		scene.Muted = true
		scene:SetViewing(true)
		scene:Pose(1, Vector3.new(-1, -5, 0), 0, Vector3.zero)
		scene:Pose(2, Vector3.new(1, -5, 0), 0, Vector3.zero)
		check(scene.Fighters[1].RenderId == def.Id, "fallback " .. def.Id)
		check(scene.Fighters[1].ReleaseArt, "revised cracks " .. def.Id)
		local portrait = Portrait.new(gui, def.Id, UDim2.fromOffset(100, 100), UDim2.new(), "Portrait" .. index)
		check(portrait:FindFirstChildOfClass("WorldModel") ~= nil, "portrait " .. def.Id)
		portrait:Destroy()
		local r = {
			Hp = { hp, 150 },
			Power = { 1, 0 },
			Frozen = { false, false },
			Shield = { false, false },
			Rage = { false, false },
			Slam = { false, false },
			Pump = { false, false },
			Effect = { { 0, 0, 0, 0, 0 }, { 0, 0, 0, 0, 0 } },
		}
		local e = {
			Type = "CastStart",
			Side = 1,
			Time = 0,
			Windup = math.max(0.1, kit.Windup),
			Shape = kit.Shape,
			CastId = 1,
		}
		scene.Combat:Event(e)
		scene:Update(r, 0.05)
		local shape = kit.Shape
		if shape == "armed_contact" or shape:find("_contact") or shape == "contact" then
			scene.Combat:Event({ Type = "SignatureContact", Side = 1, Time = 0.1, Shape = shape, Point = { 0, -5, 0 } })
		else
			scene.Combat:Event({
				Type = "CastRelease",
				Side = 1,
				Time = 0.1,
				Shape = shape,
				CastId = 1,
				Duration = kit.Duration,
				Origin = { 0, -5, 0 },
				Direction = { 1, 0, 0 },
				Range = kit.Range,
				Radius = kit.Radius,
				Arc = kit.Arc,
				Pulses = kit.Pulses,
			})
		end
		for i = 1, 30 do
			scene:Update(r, 0.1 + i * kit.Duration / 30)
		end
		for pulse = 1, kit.Pulses or 1 do
			scene.Combat:Event({
				Type = "CastContact",
				Side = 1,
				Target = 2,
				Time = 0.2,
				CastId = 1,
				Pulse = pulse,
				Point = { 1, -5, 0 },
				Missed = pulse == 2,
				Amount = 1,
			})
		end
		r.Effect = { { 1, 1, 1, 1, 1 }, { 1, 1, 1, 1, 1 } }
		scene.Combat:Event({
			Type = "SignatureStatus",
			Kind = "Echo",
			Side = 1,
			Time = 0.2,
			Seconds = 1,
			Point = {
				0,
				-5,
				0,
			},
		})
		scene:Update(r, 0.3)
		partsMax = math.max(partsMax, #scene.Root:GetDescendants())
		for _, fraction in { 0.7, 0.4, 0.2 } do
			scene.Shatter:SetCracks(scene.Fighters[1], hp * fraction, hp)
			check(#scene.Fighters[1].Cracks > 0, "cracks " .. def.Id)
		end
		scene.Shatter:Break(scene.Fighters[1], scene.Root)
		check(#scene.Shatter.Shards >= 12, "shards " .. def.Id)
		scene:HideBroken(1)
		scene:SetViewing(false)
		check(next(scene.Combat.Casts) == nil, "watch cleanup " .. def.Id)
		for _, f in scene.Fighters do
			check(not f.Health.Enabled, "health cleanup")
		end
		local root = scene.Root
		scene:Destroy()
		scene = nil
		check(root.Parent == nil, "root cleanup")
		task.wait()
	end
end)
if scene then
	scene:Destroy()
end
if gui then
	gui:Destroy()
end
assert(ok, problem)
return {
	Checks = checks,
	Models = 24,
	MaxFixtureDescendants = partsMax,
	Result = "PASS",
	Scope = "Fixture; not live feel approval",
}
