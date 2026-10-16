-- Play/Client: delayed model/part replication and stage removal/rearrival.
local RS = game.ReplicatedStorage
local Controller = require(game.Players.LocalPlayer.PlayerScripts.Client.Controllers.RideController)
local controller = setmetatable({}, { __index = Controller })
controller:Init()
local checks = 0
local function check(value, message)
	assert(value, message)
	checks += 1
end
local stage = Instance.new("Folder")
stage.Name, stage.Parent = "MatchStage_StreamingCheck", workspace
local connections = {}
local ok, problem = pcall(function()
	controller:Attach(stage)
	for _, connection in controller.Stages[stage] do
		table.insert(connections, connection)
	end
	local base = CFrame.new(workspace.CurrentCamera.CFrame.Position + Vector3.zAxis * 6)
	for _, id in { "skyboard", "cloud_cushion", "rocket_skiff", "prism_ray" } do
		local ride = RS.Assets.Rideables[id]:Clone()
		ride:PivotTo(base)
		ride:SetAttribute("BasePose", base)
		ride:SetAttribute("RootPose", base * CFrame.new(0, 3, 0))
		ride:SetAttribute("RideId", id)
		ride.Parent = stage
		task.wait()
		check(controller.Rides[ride] ~= nil, id .. " attaches after stage arrival")
		controller:Step(0.2)
		check((ride:GetPivot().Position - base.Position).Magnitude > 0.001, id .. " bobs")
		local wing = Instance.new("Part")
		wing.Anchored, wing.CanCollide, wing.CanTouch, wing.CanQuery = true, false, false, false
		wing.CFrame = base * CFrame.new(2, 0, 0)
		wing:SetAttribute("RideMotion", "Wing")
		wing:SetAttribute("WingSide", 1)
		wing.Parent = ride
		task.wait()
		check(controller.Rides[ride].Parts[wing] ~= nil, "Late wing attaches")
		check(
			(controller.Rides[ride].Parts[wing].Pose.Position - Vector3.new(2, 0, 0)).Magnitude < 0.001,
			"Late wing keeps server rest pose"
		)
		controller:Step(0.7)
		check((wing.Position - ride:GetPivot().Position).Magnitude < 2.01, "Late wing follows deck")
		wing:Destroy()
		controller:Step(0.8)
		check(controller.Rides[ride].Parts[wing] == nil, "Removed wing released")
	end
	stage.Parent = nil
	task.wait()
	check(
		next(controller.Rides) == nil and next(controller.Stages) == nil,
		"Streamed-out stage releases rides/listeners"
	)
	for _, connection in connections do
		check(not connection.Connected, "Stage listener disconnected")
	end
	stage.Parent = workspace
	controller:Attach(stage)
	local count = 0
	for _ in controller.Rides do
		count += 1
	end
	check(count == 4, "Returning stage registers all rides")
	controller:Attach(stage)
	check(#controller.Stages[stage] == 3, "Repeat attach does not duplicate listeners")
	stage:Destroy()
	task.wait()
	check(
		next(controller.Rides) == nil and next(controller.Stages) == nil,
		"Destroyed stage cleans up after deferred signals"
	)
	task.wait()
	check(next(controller.Stages) == nil, "Deferred work cannot revive removed stage")
end)
stage:Destroy()
if not ok then
	error(problem)
end
return { Passed = checks, Rides = 4, RemainingStages = next(controller.Stages) ~= nil }
