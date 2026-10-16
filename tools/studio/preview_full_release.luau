-- Client-only staged contact sheet. Restores camera/UI automatically; never resolves damage.
local RS, player = game.ReplicatedStorage, game.Players.LocalPlayer
local Scene = require(player.PlayerScripts.Client.Presentation.FightScene)
local G = require(RS.Shared.Config.Glassies)
local B = require(RS.Shared.Config.Balance)
local Geometry = require(RS.Shared.Config.ReleaseGeometry)
local camera = workspace.CurrentCamera
local old = { Type = camera.CameraType, CFrame = camera.CFrame, FOV = camera.FieldOfView }
local preview = { Scenes = {}, Hidden = {}, Done = false }
for _, gui in player.PlayerGui:GetChildren() do
	if gui:IsA("ScreenGui") then
		preview.Hidden[gui] = gui.Enabled
		gui.Enabled = false
	end
end
function preview:Destroy()
	if self.Done then
		return
	end
	self.Done = true
	for _, scene in self.Scenes do
		scene:Destroy()
	end
	for gui, enabled in self.Hidden do
		if gui.Parent then
			gui.Enabled = enabled
		end
	end
	camera.CameraType, camera.CFrame, camera.FieldOfView = old.Type, old.CFrame, old.FOV
end
local ok, problem = pcall(function()
	camera.CameraType, camera.FieldOfView = Enum.CameraType.Scriptable, 52
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 310, 3070), Vector3.new(0, 310, 3000))
	for i, def in G.ReleaseList do
		local x = ((i - 1) % 6 - 2.5) * 10
		local y = 326 - math.floor((i - 1) / 6) * 10
		local scene = Scene.new({
			Id = "Showcase" .. i,
			A = { Id = def.Id },
			B = { Id = "jam" },
			Frame = CFrame.new(x + 3, y + 7 + Geometry[def.Id].Center * B.Motion.GlassyScale, 3000),
		}, { 100, 100 }, { SetCracks = function() end })
		table.insert(preview.Scenes, scene)
		scene.Muted = true
		scene:SetViewing(true)
		scene:Pose(1, Vector3.new(0, -7, 0), 0, Vector3.zero)
		scene.Fighters[2].Broken = true
		for _, p in scene.Fighters[2].Parts do
			p.Transparency = 1
		end
		scene.Fighters[2].Beam.Enabled = false
		local r = {
			Hp = { 100, 0 },
			Power = { 1, 0 },
			Frozen = { false, false },
			Shield = { false, false },
			Rage = { false, false },
			Slam = { false, false },
			Pump = { false, false },
			Effect = { { 0, 0, 0, 0, 0 }, { 0, 0, 0, 0, 0 } },
		}
		scene:Update(r, 0.3)
		local gui = Instance.new("BillboardGui")
		gui.Adornee, gui.Size, gui.AlwaysOnTop = scene.Fighters[1].Body, UDim2.fromOffset(135, 25), true
		gui.StudsOffsetWorldSpace = Vector3.yAxis * (scene.Fighters[1].Body.Size.Y / 2 + 1)
		local text = Instance.new("TextLabel")
		text.Size, text.BackgroundTransparency, text.Text, text.TextSize = UDim2.fromScale(1, 1), 1, def.Name, 14
		text.TextColor3, text.TextStrokeTransparency, text.Font = Color3.new(1, 1, 1), 0.1, Enum.Font.GothamBold
		text.Parent, gui.Parent = gui, scene.Root
	end
end)
if not ok then
	preview:Destroy()
	error(problem)
end
_G.ReleaseShowcase = preview
task.delay(20, function()
	preview:Destroy()
end)
return { Models = #preview.Scenes, PreviewOnly = true, AutoRestoreSeconds = 20 }
