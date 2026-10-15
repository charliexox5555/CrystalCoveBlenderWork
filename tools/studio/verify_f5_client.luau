-- Run through Studio MCP in Client mode with no active participant match.
-- Cloned modules keep these component fixtures separate from the live controllers.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local player = Players.LocalPlayer
assert(not player.PlayerGui:GetAttribute("InMatch"), "Finish the active match before this fixture")
local modules = player.PlayerScripts.Client:Clone()
modules.Name, modules.Parent = "GlassClashQAClientModules", RS
local view
local checks = 0
local function check(condition, message)
	assert(condition, message)
	checks += 1
end
local function flashes()
	local n = 0
	for _, item in Lighting:GetChildren() do
		if item.Name == "FightShatterFlash" then
			n += 1
		end
	end
	return n
end
local before = flashes()
local Feel = require(RS.Shared.Config.Balance).Feel
local ok, result = xpcall(function()
	local View = require(modules.Presentation.FightView)
	local shatter = require(modules.Controllers.ShatterController)
	shatter:Init()
	local stand
	for _, candidate in CollectionService:GetTagged("ArenaStand") do
		if candidate:GetAttribute("ArenaId") == 1 then
			stand = candidate
		end
	end
	assert(stand, "Arena 1 is not replicated")
	local bar = stand.Crossbar
	local a, b = bar.HookA.WorldPosition, bar.HookB.WorldPosition
	local x = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
	local data = {
		Id = "qa-component",
		ArenaId = 1,
		Phase = "Fighting",
		SweetSpot = 0.8,
		Frame = CFrame.fromMatrix((a + b) / 2, x, Vector3.yAxis, x:Cross(Vector3.yAxis)),
		HookPositions = { a, b },
		HeartPositions = { a - Vector3.yAxis * 10, b - Vector3.yAxis * 10 },
		A = { Id = "pop" },
		B = { Id = "jam" },
		PlayerIds = { player.UserId, 0 },
		Hearts = { 3, 3 },
	}
	-- No replicated Hook Instances: poses, camera occlusion and heart positions still work.
	for _ = 1, 20 do
		view = View.new({ ShatterController = shatter })
		view:State(data)
		for side = 1, 2 do
			view.Scene:Pose(side, Vector3.new(0, -7, 0), 0, Vector3.zero)
			check(view.Scene.Fighters[side].Beam.Attachment0 ~= nil, "Missing local string hook")
		end
		check(view.Scene:GetStand() == stand, "Local hooks broke stand lookup")
		view:Camera(1 / 60, os.clock())
		local shot = workspace.CurrentCamera.CFrame
		view.PendingHearts = { 2, 3 }
		view:Event({ Type = "Shatter", Side = 1, Time = 1 })
		check(view.Hud.Hearts[1] == 3, "Heart was lost before the avatar impact")
		check(not view.Scene.Root:FindFirstChild("GlassHeartPop"), "Heart pop preceded the finisher")
		local finisher = view.Scene.Finisher
		check(finisher ~= nil, "Shatter did not start the finisher")
		check(
			finisher:Step(finisher.At + Feel.FinisherPause + Feel.FinisherRiseSeconds + Feel.FinisherFlySeconds + 0.01),
			"Finisher never impacted"
		)
		view:ShowRoundResult()
		check(view.Hud.Hearts[1] == 2, "Authoritative hearts did not apply at impact")
		view.Hud:Update({ Hp = { 0, 80 } })
		check(view.Hud.Billboards[1].Gui.Body.HpAmount.Text:find("0 /", 1, true) == 1, "Numeric HP missing")
		check(
			view.Scene.Fighters[1].Body.Transparency == 1 and view.Scene.Fighters[2].Body.Transparency == 1,
			"Ghost glass remained after impact"
		)
		view.Hud:Banner(1, "SHOULD STAY HIDDEN", Color3.new(1, 1, 1))
		check(not view.Hud.PowerBanner.Visible, "Removed power banner appeared")
		view.ShakeUntil = nil
		view:Camera(1 / 60, os.clock())
		check((workspace.CurrentCamera.CFrame.Position - shot.Position).Magnitude < 0.001, "Camera moved at round end")
		view:Event({ Type = "Shatter", Side = 2, Time = 1 })
		check(flashes() == before + 1, "Double KO leaked a second flash")
		local heart = view.Scene.Root:FindFirstChild("GlassHeartPop")
		check(
			heart and (heart.Position - data.HeartPositions[1] - Vector3.yAxis * 5).Magnitude < 0.001,
			"Heart pop lost its pad position"
		)
		view:EndFight()
		check(
			flashes() == before and not workspace:FindFirstChild("LocalFight_qa-component"),
			"Scene/flash cleanup leaked"
		)
	end
	-- A far arena must drain its final reliable event before rendering becomes static.
	data.PlayerIds = { 0, 0 }
	view = View.new({ ShatterController = shatter })
	view:State(data)
	local snapshot = {
		T = 1,
		SentAt = workspace:GetServerTimeNow() - 2,
		B = { { 0, -7, 0, 0, 0, 0, 0, 0, 0, 0 }, { 0, -7, 0, 0, 0, 0, 0, 0, 0, 0 } },
		R = {
			Hp = { 100, 100 },
			Power = { 0, 0 },
			Frozen = { false, false },
			Shield = { false, false },
			Rage = { false, false },
			Pump = { false, false },
			Slam = { false, false },
			Effect = {},
		},
	}
	view:Snapshot(snapshot)
	view.Events = { { Type = "Whoosh", Time = 1 } }
	view:Render(2)
	check(#view.Events == 0 and view.RenderTime == 1, "Distant final event never drained")
	view:EndFight()
	check(game:GetService("GuiService").TouchControlsEnabled, "Touch controls did not restore")
	check(flashes() == before, "Flash remained after fixtures")
	return { Checks = checks, DoubleKOCycles = 20, FlashesBefore = before, FlashesAfter = flashes() }
end, debug.traceback)
if view then
	view:EndFight()
end
modules:Destroy()
assert(ok, result)
return result
