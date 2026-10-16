-- Local cosmetic motion for replicated, anchored match rides and riders.
local RunService = game:GetService("RunService")
local T = require(game.ReplicatedStorage.Shared.Config.Balance).CosmeticPresentation
local Controller = {}
local RidePose = require(script.Parent.Parent.Presentation.RidePose)
function Controller:Init()
	self.Rides, self.Connections, self.Stages = {}, {}, {}
end
function Controller:Detach(folder)
	for _, connection in self.Stages[folder] or {} do
		connection:Disconnect()
	end
	self.Stages[folder] = nil
	for ride, entry in self.Rides do
		if entry.Stage == folder then
			if entry.Pose then
				entry.Pose:Destroy()
			end
			self.Rides[ride] = nil
		end
	end
end
function Controller:Attach(folder)
	if not folder.Name:match("^MatchStage_") or not folder:IsDescendantOf(workspace) then
		return
	end
	if not self.Stages[folder] then
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
		if not entry then
			local base, rootPose = ride:GetAttribute("BasePose"), ride:GetAttribute("RootPose")
			if typeof(base) ~= "CFrame" or typeof(rootPose) ~= "CFrame" then
				continue
			end
			entry = {
				Model = ride,
				Stage = folder,
				Base = base,
				RootPose = rootPose,
				Parts = {},
			}
			entry.RootLocal = entry.Base:ToObjectSpace(entry.RootPose)
			self.Rides[ride] = entry
		end
		for _, p in ride:GetDescendants() do
			if p:IsA("BasePart") and p:GetAttribute("RideMotion") and not entry.Parts[p] then
				entry.Parts[p] = { Pose = entry.Base:ToObjectSpace(p.CFrame), Size = p.Size }
			end
		end
	end
end
function Controller:Step(time)
	local camera = workspace.CurrentCamera
	for model, entry in self.Rides do
		if not model:IsDescendantOf(workspace) then
			if entry.Pose then
				entry.Pose:Destroy()
			end
			self.Rides[model] = nil
			continue
		end
		if (camera.CFrame.Position - entry.Base.Position).Magnitude > T.RideDistance then
			continue
		end
		local wave = math.sin(time * T.RideBobHz * math.pi * 2 + entry.Base.Position.X)
		local motion = CFrame.new(0, wave * T.RideBob, 0) * CFrame.Angles(0, 0, wave * T.RideBank)
		model:PivotTo(entry.Base * motion)
		local rider = model:FindFirstChild("Rider")
		local character = rider and rider.Value
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root.Anchored then
			if entry.Character ~= character then
				if entry.Pose then
					entry.Pose:Destroy()
				end
				entry.Character, entry.Pose =
					character, RidePose.new(character, model:GetAttribute("PoseId") or model:GetAttribute("RideId"))
			end
			local height = entry.Pose.Height
			local localPose = entry.RootLocal
			if height then
				localPose = CFrame.new(0, height, 0) * entry.RootLocal.Rotation
			end
			local rootPose = entry.Base * motion * localPose
			character:PivotTo(rootPose)
			entry.Pose:PlaceAnchored(rootPose)
		end
		for part, rest in entry.Parts do
			if not part:IsDescendantOf(model) then
				entry.Parts[part] = nil
				continue
			end
			if part:GetAttribute("RideMotion") == "Wing" then
				local pivot = part:GetAttribute("WingPivot") or Vector3.zero
				part.CFrame = entry.Base
					* motion
					* rest.Pose
					* CFrame.new(pivot)
					* CFrame.Angles(0, 0, wave * T.RideWingAngle * part:GetAttribute("WingSide"))
					* CFrame.new(-pivot)
			else
				part.Size = rest.Size * Vector3.new(1, 1, 0.8 + math.sin(time * T.RideExhaustSpeed) * 0.2)
			end
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
