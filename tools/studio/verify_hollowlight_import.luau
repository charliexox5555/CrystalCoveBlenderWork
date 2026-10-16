-- Play/Client. Focused asset, skin, finisher timeline and ride-pose verification.
local RS = game.ReplicatedStorage
local client = game.Players.LocalPlayer.PlayerScripts.Client
local assets = RS.Assets.Seasonal.Hollowlight
local FX = require(client.Presentation.HollowlightFX)
local root = Instance.new("Folder")
root.Name, root.Parent = "HollowlightVerification", workspace
local checks, states, parts, preloadFailures = 0, {}, {}, {}
local function check(value, message)
	assert(value, message)
	checks += 1
end
local human = game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
local health = human.Health
local scene
local ok, problem = pcall(function()
	for _, p in assets:GetDescendants() do
		if p:IsA("MeshPart") then
			table.insert(parts, p)
			check(p.MeshId ~= "", "Permanent uploaded mesh")
			check(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery, "Nonphysical cosmetic")
			check(p:GetPivot().Position.Magnitude < 0.0001, "Common source origin")
		end
	end
	check(#parts == 68, "All 68 installed components")
	game:GetService("ContentProvider"):PreloadAsync(parts, function(id, status)
		if status ~= Enum.AssetFetchStatus.Success then
			table.insert(preloadFailures, id)
		end
	end)
	check(#preloadFailures == 0, "Every permanent mesh preloads")
	check(#assets.pop_hollowlight.Shards:GetChildren() == 16, "Sixteen pumpkin shards")
	check(
		math.abs(assets.pop_hollowlight.Body.Size.X - RS.Assets.Glassies.pop.Body.Size.X) < 0.0001,
		"Fits original Pop width"
	)
	check(
		assets:GetAttribute("SaleEnabled") == false and assets:GetAttribute("ReleaseCount") == 24,
		"Sale disabled and fixed roster"
	)
	local Scene = require(client.Presentation.FightScene)
	scene = Scene.new({
		Id = "HollowlightCheck",
		Frame = CFrame.new(0, 500, 0),
		A = { Id = "pop", Skin = "hollowlight" },
		B = { Id = "pop" },
	}, { 100, 100 }, {})
	check(
		scene.Fighters[1].Body.MeshId == assets.pop_hollowlight.Body.MeshId,
		"Explicit Pop skin resolves refined mesh"
	)
	check(scene.Fighters[2].Body.MeshId == RS.Assets.Glassies.pop.Body.MeshId, "Ordinary Pop preserved")
	check(
		scene.Fighters[1].Id == "pop" and scene.Fighters[1].Def == scene.Fighters[2].Def,
		"Same authoritative Pop definition"
	)
	scene:Destroy()
	scene = nil
	for _, low in { false, true } do
		local state = FX.create(root, Vector3.new(0, 500, 0), low, CFrame.identity)
		table.insert(states, state)
		check(#state.Parts == (if low then 10 else 19), "Bounded actor count")
		local model = state.Root.lantern_eclipse
		local ghost, face = model.Wisp0, model.WispFace0
		local relative = ghost.CFrame:ToObjectSpace(face.CFrame)
		local initial = (ghost.Position * Vector3.new(1, 0, 1)).Magnitude
		state:Step(0.45)
		check((ghost.Position * Vector3.new(1, 0, 1)).Magnitude < initial, "Wisps converge")
		check(ghost.CFrame:ToObjectSpace(face.CFrame):FuzzyEq(relative, 0.001), "Face stays attached while orbiting")
		for _, beam in state.Beams do
			check(beam.Enabled == not low, "Reduced-detail ribbons disabled")
		end
		local ringSize = model.Halo.Size.X
		state:Step(0.95)
		check(model.Halo.Size.X > ringSize, "Impact expands the ring")
		check(model.Core_AmberGlass.Transparency > 0.5, "Core clears recipient on release")
		for _, entry in state.Emitters do
			check(entry.Fired, "One-shot layers fire at authored phases")
		end
		state:Step(state.Lifetime)
		check(state.Stopped and state.Root.Parent == nil, "Manual timeline expires cleanly")
	end
	local dispatched =
		require(client.Presentation.FinisherFX).emit(root, "lantern_eclipse", Vector3.new(0, 500, 0), false)
	check(dispatched and dispatched.Name == "Finisher_lantern_eclipse", "Finisher dispatcher selects seasonal sequence")
	dispatched:Destroy()
	local pressure = FX.pressure(root, Vector3.new(0, 500, 0))
	check(pressure ~= nil and pressure.Anchored, "Pop pressure uses authored native kit")
	local ride = assets.lantern_skiff:Clone()
	ride:PivotTo(CFrame.new(0, 500, 0))
	ride.Parent = root
	local deck = ride.DeckInlay
	check(math.abs(deck.Position.Y + deck.Size.Y / 2 - 500) < 0.0001, "Rider deck normalized to y=0")
	local wings = 0
	for _, p in ride:GetChildren() do
		if p:GetAttribute("RideMotion") == "Wing" then
			wings += 1
			local pivot = p.CFrame:PointToWorldSpace(p:GetAttribute("WingPivot"))
			check(math.abs(math.abs(pivot.X) - 1) < 0.001, "Wing group shares authored hinge")
		end
	end
	check(wings == 10, "Both shells/rims and all six veins are hinged")
	check(ride.NoseCrescent.Position.Z < 0, "Skiff nose agrees with rider forward")
	local stage = Instance.new("Folder")
	stage.Name, stage.Parent = "MatchStage_HollowlightVerification", root
	local base = CFrame.new(workspace.CurrentCamera.CFrame.Position + Vector3.zAxis * 8)
	ride:PivotTo(base)
	ride:SetAttribute("RideId", "lantern_skiff")
	ride:SetAttribute("BasePose", base)
	ride:SetAttribute("RootPose", base * CFrame.new(0, 3, 0))
	ride.Parent = stage
	local Controller = require(client.Controllers.RideController)
	local controller = setmetatable({}, { __index = Controller })
	controller:Init()
	controller:Attach(stage)
	controller:Step(0.1)
	local firstWing = ride.Wing_L.CFrame
	controller:Step(0.4)
	check(not ride.Wing_L.CFrame:FuzzyEq(firstWing, 0.0001), "Seasonal wings animate through normal ride controller")
	controller:Detach(stage)
	check(next(controller.Rides) == nil, "Seasonal ride detaches cleanly")
	local character = game.Players.LocalPlayer.Character
	local animate, previous = character:FindFirstChild("Animate"), character.Animate.Disabled
	local pose = require(client.Presentation.RidePose).new(character, ride:GetAttribute("PoseId"))
	check(pose:Step(0.4) ~= nil, "Glider pose computes foot contact")
	pose:Destroy()
	check(animate.Disabled == previous, "Default avatar animation restored")
	ride:Destroy()
	stage:Destroy()
	task.wait(1)
	check(#root:GetChildren() == 0, "Cancellation and pressure leave no leftovers")
	check(human.Health == health, "Real avatar health unchanged")
end)
if scene then
	scene:Destroy()
end
for _, state in states do
	state:Destroy()
end
root:Destroy()
assert(ok, problem)
return {
	Passed = checks,
	Preloaded = #parts,
	FailedLoads = #preloadFailures,
	AvatarHealth = human.Health,
	SaleEnabled = false,
}
