-- Play/Client: preview framing, resize, replay and close while delayed effects are active.
local client = game.Players.LocalPlayer.PlayerScripts.Client
local Catalog = require(client.UI.Screens.CosmeticCatalog)
local C = require(game.ReplicatedStorage.Shared.Config.RoundCosmetics)
local gui = Instance.new("ScreenGui")
gui.Name, gui.Enabled, gui.Parent = "PreviewFitCheck", true, game.Players.LocalPlayer.PlayerGui
local panel = Instance.new("Frame")
panel.Size, panel.Parent = UDim2.fromScale(0.8, 0.8), gui
local view = Catalog.new(
	panel,
	{ Cosmetics = { Finishers = { "glass_burst" }, EquippedFinishers = "glass_burst" }, Stats = {} },
	"Finishers"
)
local checks, oldWorst, newWorst = 0, 0, 0
local function check(value, message)
	assert(value, message)
	checks += 1
end
local function extent(effect, pose, viewport)
	local tangent = math.tan(math.rad(viewport.CurrentCamera.FieldOfView) / 2)
	local aspect = viewport.AbsoluteSize.X / viewport.AbsoluteSize.Y
	local worst = 0
	for _, p in effect:GetChildren() do
		if p:IsA("BasePart") then
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local point =
							pose:PointToObjectSpace(p.CFrame:PointToWorldSpace(p.Size * Vector3.new(x, y, z) / 2))
						check(point.Z < 0, "Effect stays in front of preview camera")
						worst = math.max(
							worst,
							math.abs(point.X) / (-point.Z * tangent * aspect),
							math.abs(point.Y) / (-point.Z * tangent)
						)
					end
				end
			end
		end
	end
	return worst
end
local ok, problem = pcall(function()
	task.wait(0.05)
	for _, def in C.Finishers do
		view:Detail(def.Id)
		local close = view.Portrait.CurrentCamera.CFrame
		local effect = view:PreviewSelected()
		task.wait(0.43)
		oldWorst = math.max(oldWorst, extent(effect, close, view.Portrait))
		local bound = extent(effect, view.Portrait.CurrentCamera.CFrame, view.Portrait)
		newWorst = math.max(newWorst, bound)
		check(bound < 1, "Full animated finisher fits both preview axes")
		local replay = view:PreviewSelected()
		check(effect.Parent == nil and replay.Parent == view.World, "Replay replaces previous effects")
		view:Detail(def.Id)
		check(
			replay.Parent == nil and view.Portrait.CurrentCamera.CFrame.Position.Magnitude < 11,
			"Selecting restores close icon camera"
		)
	end
	check(oldWorst > 1, "Regression reproduces original clipping")
	view:PreviewSelected()
	local before = view.Portrait.CurrentCamera.CFrame.Position.Magnitude
	view.Portrait.Size = UDim2.fromScale(0.2, 0.38)
	task.wait(0.05)
	check(view.Portrait.CurrentCamera.CFrame.Position.Magnitude > before, "Narrow resize refits automatically")
	local world = view.World
	view:Destroy()
	view = nil
	check(world.Parent == nil, "Closing clears active preview world")
	task.wait(1.5)
end)
if view then
	view:Destroy()
end
gui:Destroy()
assert(ok, problem)
return {
	Passed = true,
	Checks = checks,
	OriginalNormalizedExtent = oldWorst,
	FittedNormalizedExtent = newWorst,
	Scope = "Preview only, not device layout approval",
}
