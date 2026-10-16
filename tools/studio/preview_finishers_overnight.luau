-- Play/Client: a labeled scripted native VFX loop, not actual match or damage evidence.
if _G.NightFinisherPreview then
	_G.NightFinisherPreview:Destroy()
end
local FX = require(game.Players.LocalPlayer.PlayerScripts.Client.Presentation.FinisherFX)
local C = require(game.ReplicatedStorage.Shared.Config.RoundCosmetics)
local RunService = game:GetService("RunService")
local camera = workspace.CurrentCamera
local preview = {
	Root = Instance.new("Folder"),
	Guis = {},
	Camera = { CFrame = camera.CFrame, FOV = camera.FieldOfView, Type = camera.CameraType },
}
preview.Root.Name, preview.Root.Parent = "NightFinisherPreview", workspace
local pg = game.Players.LocalPlayer.PlayerGui
for _, g in pg:GetChildren() do
	if g:IsA("ScreenGui") then
		preview.Guis[g] = g.Enabled
		g.Enabled = false
	end
end
local caption = Instance.new("ScreenGui")
caption.Name, caption.Parent = "FinisherPreviewCaption", pg
local text = Instance.new("TextLabel")
text.Size, text.Position, text.BackgroundTransparency = UDim2.fromScale(0.94, 0.07), UDim2.fromScale(0.03, 0.03), 1
text.Text, text.TextColor3, text.TextScaled =
	"Crystal Pop  ·  Party Pop  ·  Bubble Bloom  ·  Block Boom  ·  Pocket Nova\nSCRIPTED COSMETIC VFX PREVIEW",
	Color3.new(1, 1, 1),
	true
text.FontFace, text.Parent = Font.fromName("FredokaOne"), caption
local focus = Vector3.new(0, 210, 3000)
local pose = CFrame.lookAt(focus + Vector3.new(0, 7, 56), focus)
function preview:Destroy()
	if self.Done then
		return
	end
	self.Done = true
	if self.Connection then
		self.Connection:Disconnect()
	end
	self.Root:Destroy()
	caption:Destroy()
	for g, enabled in self.Guis do
		if g.Parent then
			g.Enabled = enabled
		end
	end
	camera.CameraType, camera.FieldOfView, camera.CFrame = self.Camera.Type, self.Camera.FOV, self.Camera.CFrame
end
local function burst()
	camera.CFrame = pose
	for i, def in C.Finishers do
		FX.emit(preview.Root, def.Id, focus + Vector3.new((i - 3) * 12, 0, 0), false, pose.Rotation)
	end
end
local age = 0
preview.Connection = RunService.RenderStepped:Connect(function(dt)
	camera.CameraType, camera.FieldOfView, camera.CFrame = Enum.CameraType.Scriptable, 52, pose
	age += dt
	if age > 1.7 then
		age = 0
		burst()
	end
end)
burst()
_G.NightFinisherPreview = preview
task.delay(25, function()
	preview:Destroy()
end)
return { CameraPosition = { 0, 217, 3056 }, LookAt = { 0, 210, 3000 }, AutoRestoreSeconds = 25, Scripted = true }
