-- Local cosmetic motion for replicated, anchored match rides and riders (motion in Presentation/RideMotion).
local RunService = game:GetService("RunService")
local T = require(game.ReplicatedStorage.Shared.Config.Balance).CosmeticPresentation
local Controller = {}
local RidePose = require(script.Parent.Parent.Presentation.RidePose)
local RideMotion = require(script.Parent.Parent.Presentation.RideMotion)
-- A ride first seen this soon after its stage appeared launches in; later sightings (streaming, late
-- joiners) start in place.
local LAUNCH_WINDOW = 2
function Controller:Init()
	self.Rides, self.Connections, self.Stages, self.StageSeen = {}, {}, {}, {}
end
function Controller:Drop(ride, entry)
	if entry.Pose then
		entry.Pose:Destroy()
	end
	-- Rides that were on screen land (per-ride flourish, e.g. the carriage); far ones just clean up.
	entry.Motion:Destroy(if entry.Motion.EffectsOn then workspace else nil)
	self.Rides[ride] = nil
end
function Controller:Detach(folder)
	for _, connection in self.Stages[folder] or {} do
		connection:Disconnect()
	end
	self.Stages[folder], self.StageSeen[folder] = nil, nil
	for ride, entry in self.Rides do
		if entry.Stage == folder then
			self:Drop(ride, entry)
		end
	end
end
function Controller:Attach(folder)
	if not folder.Name:match("^MatchStage_") or not folder:IsDescendantOf(workspace) then
		return
	end
	local now = workspace:GetServerTimeNow()
	if not self.Stages[folder] then
		self.StageSeen[folder] = now
		-- Streaming may deliver the stage before its rides, or a ride before all its parts.
		self.Stages[folder] = {
			folder.DescendantAdded:Connect(function()
				task.defer(function()
					self:Attach(folder)
				end)
			end),
			folder.AncestryChanged:Connect(function()
				if not folder:IsDescendantOf(workspace) then
					self:Detach(folder)
				end
			end),
			folder.Destroying:Connect(function()
				self:Detach(folder)
			end),
		}
	end
	for _, ride in folder:GetChildren() do
		if not ride:IsA("Model") or not ride:GetAttribute("RideId") then
			continue
		end
		local entry = self.Rides[ride]
		if entry then
			entry.Motion:Collect()
			continue
		end
		local base, rootPose = ride:GetAttribute("BasePose"), ride:GetAttribute("RootPose")
		if typeof(base) ~= "CFrame" or typeof(rootPose) ~= "CFrame" then
			continue
		end
		local fresh = now - (self.StageSeen[folder] or now) <= LAUNCH_WINDOW
		entry = {
			Model = ride,
			Stage = folder,
			Base = base,
			RootPose = rootPose,
			Motion = RideMotion.new(ride, base, { Launch = fresh and now or nil }),
		}
		entry.RootLocal = entry.Base:ToObjectSpace(entry.RootPose)
		self.Rides[ride] = entry
	end
end
function Controller:Step(time)
	local camera = workspace.CurrentCamera
	for model, entry in self.Rides do
		if not model:IsDescendantOf(workspace) then
			self:Drop(model, entry)
			continue
		end
		local distance = (camera.CFrame.Position - entry.Base.Position).Magnitude
		if distance > T.RideDistance then
			continue
		end
		-- Particles, trails, beams, lights and the loop sound only run near the camera.
		local pose = entry.Motion:Step(time, entry.Base, distance <= T.RideEmitterDistance)
		local rider = model:FindFirstChild("Rider")
		local character = rider and rider.Value
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root.Anchored then
			if entry.Character ~= character then
				if entry.Pose then
					entry.Pose:Destroy()
				end
				entry.Character, entry.Pose =
					character,
					RidePose.new(
						character,
						model:GetAttribute("PoseId") or model:GetAttribute("RideId"),
						{ Ride = model }
					)
				if entry.Motion.LaunchAt then
					entry.Pose:OneShot("Launch")
				end
			end
			-- The launch rise has just settled: the rider absorbs the landing.
			if entry.Launching and not entry.Motion.LaunchAt then
				entry.Pose:OneShot("Land")
			end
			entry.Launching = entry.Motion.LaunchAt ~= nil
			entry.Pose:Lean(entry.Motion.Bank, entry.Motion.Pitch)
			local height = entry.Pose.Height
			local localPose = entry.RootLocal
			if height then
				localPose = CFrame.new(0, height, 0) * entry.RootLocal.Rotation
			end
			local rootPose = entry.Motion:RiderPose(pose, localPose)
			character:PivotTo(rootPose)
			entry.Pose:PlaceAnchored(rootPose)
		end
	end
end
function Controller:Start()
	for _, folder in workspace:GetChildren() do
		self:Attach(folder)
	end
	table.insert(
		self.Connections,
		workspace.ChildAdded:Connect(function(folder)
			task.defer(function()
				self:Attach(folder)
			end)
		end)
	)
	table.insert(
		self.Connections,
		RunService.RenderStepped:Connect(function()
			self:Step(workspace:GetServerTimeNow())
		end)
	)
end
return Controller
