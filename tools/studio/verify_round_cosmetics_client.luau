-- Play/Client: native assets, both catalog categories, bounded effects and cleanup.
local RS = game.ReplicatedStorage
local C = require(RS.Shared.Config.RoundCosmetics)
local client = game.Players.LocalPlayer.PlayerScripts.Client
local Catalog = require(client.UI.Screens.CosmeticCatalog)
local FX = require(client.Presentation.FinisherFX)
local checks = 0
local function check(value, message)
	assert(value, message)
	checks += 1
end
-- Feet remain on the deck while the ride banks; rider pivots around the deck, not its torso.
local RideController = require(client.Controllers.RideController)
local rideCheck = setmetatable({}, { __index = RideController })
rideCheck:Init()
local stage = Instance.new("Folder")
stage.Name, stage.Parent = "MatchStage_CosmeticFootCheck", workspace
local base = CFrame.new(workspace.CurrentCamera.CFrame.Position + Vector3.zAxis * 6)
local rider = Instance.new("Model")
rider.Name, rider.Parent = "CheckRider", stage
local hip = Instance.new("Part")
hip.Name, hip.Anchored, hip.CFrame, hip.Parent = "HumanoidRootPart", true, base * CFrame.new(0, 3, 0), rider
hip.CanCollide = false
rider.PrimaryPart = hip
local feet = hip:Clone()
feet.Name, feet.CFrame, feet.Parent = "Feet", base, rider
local ride = RS.Assets.Rideables.skyboard:Clone()
ride:PivotTo(base)
ride:SetAttribute("BasePose", base)
ride:SetAttribute("RootPose", rider:GetPivot())
ride:SetAttribute("RideId", "skyboard")
local object = Instance.new("ObjectValue")
object.Name, object.Value, object.Parent = "Rider", rider, ride
ride.Parent = stage
rideCheck:Attach(stage)
for _, time in { 0, 0.2, 0.7, 1.3 } do
	rideCheck:Step(time)
	check((feet.Position - ride:GetPivot().Position).Magnitude < 0.0001, "Feet track banked deck")
end
stage:Destroy()
local profile = {
	Stats = { MatchWins = 10, MatchLosses = 0 },
	Cosmetics = { Rideables = {}, Finishers = {}, EquippedRideables = "skyboard", EquippedFinishers = "brick_boom" },
}
for _, category in { "Rideables", "Finishers" } do
	local folder = RS.Assets[if category == "Rideables" then "Rideables" else "RoundFinishers"]
	check(#folder:GetChildren() == #C[category], "Native model count")
	for _, def in C[category] do
		table.insert(profile.Cosmetics[category], def.Id)
		local model = folder[def.Id]
		check(model:IsA("Model"), "Native cosmetic exists")
		for _, p in model:GetDescendants() do
			check(not p:IsA("LuaSourceContainer"), "Script-free native assets")
			if p:IsA("BasePart") then
				check(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery, "Cosmetic part flags")
			end
		end
	end
end
local gui = Instance.new("ScreenGui")
gui.Name, gui.Enabled, gui.Parent = "CosmeticCheck", false, game.Players.LocalPlayer.PlayerGui
local view
local root = Instance.new("Folder")
root.Name, root.Parent = "CosmeticFXCheck", workspace
local ok, problem = pcall(function()
	for _, category in { "Rideables", "Finishers" } do
		view = Catalog.new(gui, profile, category)
		for _, def in C[category] do
			view:Detail(def.Id)
			check(view.Selected == def.Id and view.Owned, "Truthful selected ownership")
			check(view.World:FindFirstChildOfClass("Model") ~= nil, "Real native portrait")
			check(view.Equipped == (profile.Cosmetics["Equipped" .. category] == def.Id), "Selected equip state")
		end
		view:Destroy()
		view = nil
	end
	for _, def in C.Finishers do
		local effect = FX.emit(root, def.Id, Vector3.new(0, 210, 3000), false)
		check(effect.Name == "Finisher_" .. def.Id, "Distinct finisher identity")
		check(#effect:GetChildren() <= 20, "Bounded extra part count")
		for _, p in effect:GetChildren() do
			check(
				p:IsA("BasePart") and p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery,
				"No damage or physical impact"
			)
		end
	end
	task.wait(0.23)
	local nova = root.Finisher_starfall:FindFirstChild("StarGem")
	check((nova.Position - Vector3.new(0, 210, 3000)).Magnitude < 0.3, "Nova contracts before bursting")
	task.wait(0.2)
	check((nova.Position - Vector3.new(0, 210, 3000)).Magnitude > 0.5, "Nova then bursts outward")
	check(root.Finisher_party_burst.BurstPiece.Transparency == 0, "Confetti holds before fade")
	check(root.Finisher_bubble_bloom.BurstPiece.Size.X > 1.4, "Bubbles grow before popping")
	task.wait(require(RS.Shared.Config.Balance).CosmeticPresentation.FinisherSeconds + 0.3)
	check(#root:GetChildren() == 0, "Transient effects expire")
end)
if view then
	view:Destroy()
end
gui:Destroy()
root:Destroy()
assert(ok, problem)
return { Passed = true, Checks = checks, Rides = #C.Rideables, Finishers = #C.Finishers }
