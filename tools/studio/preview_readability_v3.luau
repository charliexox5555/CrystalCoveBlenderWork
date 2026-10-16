-- Play / Client. Normal-camera, normal-speed scripted art replay; no combat rewards or desktop input.
-- Optional _G.ReadabilityOptions={Id="prism",FrozenTime=.65,Angle=0}; clear FrozenTime to animate.
local opt = _G.ReadabilityOptions or { Id = "prism" }
if _G.ReadabilityPreview then
	_G.ReadabilityPreview:Destroy()
end
local RS = game.ReplicatedStorage
local client = game.Players.LocalPlayer.PlayerScripts.Client
local Scene = require(client.Presentation.FightScene)
local Shatter = require(client.Controllers.ShatterController)
local Theme = require(client.UI.Theme)
local B = require(RS.Shared.Config.Balance)
local kit = B.CombatRelease.Kits[opt.Id]
assert(kit and table.find({ "pop", "jam", "prism", "crescent_axe", "hourglass" }, opt.Id), "Choose a focused hero")
local camera = workspace.CurrentCamera
local old = { Type = camera.CameraType, CFrame = camera.CFrame, FOV = camera.FieldOfView }
local preview = { Id = opt.Id, Guis = {}, Frame = CFrame.new(0, 310, 3000) }
for _, gui in game.Players.LocalPlayer.PlayerGui:GetChildren() do
	if gui:IsA("ScreenGui") then
		preview.Guis[gui] = gui.Enabled
		gui.Enabled = false
	end
end
local caption = Instance.new("ScreenGui")
caption.Name, caption.ScreenInsets, caption.Parent =
	"ReadabilityCaption", Enum.ScreenInsets.CoreUISafeInsets, game.Players.LocalPlayer.PlayerGui
local text = Instance.new("TextLabel")
text.Size, text.Position, text.BackgroundTransparency = UDim2.fromScale(0.9, 0.06), UDim2.fromScale(0.05, 0.03), 1
text.FontFace, text.TextSize, text.TextColor3, text.TextStrokeTransparency =
	Theme.Fonts.Heading, 24, Color3.new(1, 1, 1), 0.2
text.Text, text.Parent = RS.Assets.Glassies[opt.Id].Name .. " • scripted VFX preview", caption
local shatter = setmetatable({}, { __index = Shatter })
shatter:Init()
function preview:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	if self.Connection then
		self.Connection:Disconnect()
	end
	if self.Scene then
		self.Scene:Destroy()
	end
	caption:Destroy()
	for gui, enabled in self.Guis do
		if gui.Parent then
			gui.Enabled = enabled
		end
	end
	camera.CameraType, camera.CFrame, camera.FieldOfView = old.Type, old.CFrame, old.FOV
end
function preview:Build()
	if self.Scene then
		self.Scene:Destroy()
	end
	self.Scene = Scene.new(
		{ Id = "HeroReadability", A = { Id = self.Id }, B = { Id = "jam" }, Frame = self.Frame },
		{ 100, 100 },
		shatter
	)
	self.Scene.Muted = true
	self.Scene:SetViewing(true)
	for _, f in self.Scene.Fighters do
		f.SoundScale = 0
	end
	self.R = {
		Hp = { if self.Id == "hourglass" then 50 else 100, 100 },
		Power = { 1, 0 },
		Frozen = { false, false },
		Shield = { false, false },
		Rage = { false, false },
		Slam = { false, false },
		Pump = { false, false },
		Effect = { { 0, 0, 0, 0, 0 }, { 0, 0, 0, 0, 0 } },
	}
	self.Released, self.Contact = false, false
	self.Windup = if self.Id == "pop" then 0.45 else kit.Windup
	self.Scene:Pose(1, Vector3.new(1, -math.sqrt(48), 0), 0, Vector3.zero)
	self.Scene:Pose(2, Vector3.new(-1, -math.sqrt(48), 0), 0, Vector3.zero)
	self.Scene.Combat:Event({
		Type = "CastStart",
		Side = 1,
		CastId = 1,
		Time = 0,
		Shape = kit.Shape,
		Windup = self.Windup,
		Direction = { 1, 0, 0 },
	})
end
function preview:Step(t)
	local scene, r = self.Scene, self.R
	local focus = self.Frame.Position
		- Vector3.yAxis * (B.Motion.StringLength + B.Motion.BodyCenter * B.Motion.GlassyScale)
		+ Vector3.yAxis * B.Feel.CameraFocusHeight
	local offset = CFrame.fromAxisAngle(Vector3.yAxis, opt.Angle or 0)
		:VectorToWorldSpace(Vector3.zAxis * B.Feel.CameraDistance)
	camera.CameraType, camera.FieldOfView, camera.CFrame =
		Enum.CameraType.Scriptable, B.Feel.CameraFieldOfView, CFrame.lookAt(focus + offset, focus)
	scene.Combat.Time = t
	for side = 1, 2 do
		local x = (if side == 1 then 1 else -1)
			* (if self.Id == "prism" then -0.2 elseif self.Id == "pop" then 1.3 else 0.5)
		scene:Pose(side, Vector3.new(x, -math.sqrt(49 - x * x), 0), 0, Vector3.zero)
	end
	if t >= self.Windup and not self.Released then
		self.Released = true
		local origin = scene.Frame:PointToObjectSpace(scene.Fighters[1].Body.Position)
		local dir = (scene.Fighters[2].Body.Position - scene.Fighters[1].Body.Position).Unit
		if self.Id == "pop" then
			local point =
				scene.Frame:PointToObjectSpace((scene.Fighters[1].Body.Position + scene.Fighters[2].Body.Position) / 2)
			scene.Combat:Event({
				Type = "SignatureContact",
				Side = 1,
				CastId = 2,
				Time = self.Windup,
				Shape = "contact",
				Point = { point.X, point.Y, point.Z },
			})
		else
			scene.Combat:Event({
				Type = "CastRelease",
				Side = 1,
				CastId = 1,
				Time = self.Windup,
				Shape = kit.Shape,
				Duration = kit.Duration,
				Origin = { origin.X, origin.Y, origin.Z },
				Direction = { dir.X, dir.Y, dir.Z },
				Range = kit.Range,
				Radius = kit.Radius,
				Arc = kit.Arc,
			})
		end
		if self.Id == "jam" then
			r.Effect[1][1] = 2
		end
		if self.Id == "hourglass" then
			r.Hp[1] = 57
		end
	end
	local impactAt = self.Windup + (if self.Id == "jam" then 0.8 else 0.2)
	if t >= impactAt and not self.Contact then
		self.Contact = true
		if self.Id == "jam" then
			scene.Combat:Event({ Type = "SignatureBlock", Side = 1, Time = impactAt, Amount = 10 })
			r.Effect[1][1] = 0
		elseif self.Id == "prism" or self.Id == "crescent_axe" then
			local point = scene.Frame:PointToObjectSpace(scene.Fighters[2].Body.Position)
			scene.Combat:Event({
				Type = "CastContact",
				Side = 1,
				Target = 2,
				CastId = 1,
				Time = impactAt,
				Amount = 15,
				Pulse = 1,
				Point = { point.X, point.Y, point.Z },
				Missed = false,
			})
			r.Hp[2] = 85
		end
	end
	for side = 1, 2 do
		local x = (if side == 1 then 1 else -1)
			* (if self.Id == "prism" then -0.2 elseif self.Id == "pop" then 1.3 else 0.5)
		scene:Pose(side, Vector3.new(x, -math.sqrt(49 - x * x), 0), 0, Vector3.zero)
	end
	scene:Update(r, t)
end
local ok, problem = pcall(function()
	preview:Build()
	preview:Step(opt.FrozenTime or 0)
	preview.Elapsed = opt.FrozenTime or 0
	preview.Connection = game:GetService("RunService").RenderStepped:Connect(function(dt)
		if opt.FrozenTime then
			return
		end
		preview.Elapsed += dt
		if preview.Elapsed > preview.Windup + kit.Duration + 1.4 then
			preview:Build()
			preview.Elapsed = 0
		end
		preview:Step(preview.Elapsed)
	end)
end)
if not ok then
	preview:Destroy()
	error(problem)
end
_G.ReadabilityPreview = preview
task.delay(25, function()
	preview:Destroy()
end)
local p = camera.CFrame.Position
local target = p + camera.CFrame.LookVector * B.Feel.CameraDistance
return {
	Id = opt.Id,
	PreviewOnly = true,
	CameraPosition = { p.X, p.Y, p.Z },
	LookAt = { target.X, target.Y, target.Z },
	AutoRestoreSeconds = 25,
}
