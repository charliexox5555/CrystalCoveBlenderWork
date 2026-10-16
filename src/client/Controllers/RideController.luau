-- Local cosmetic motion for replicated, anchored match rides and riders.
local RunService = game:GetService("RunService")
local T = require(game.ReplicatedStorage.Shared.Config.Balance).CosmeticPresentation
local Controller = {}
function Controller:Init()
	self.Rides, self.Connections = {}, {}
end
function Controller:Attach(folder)
	if not folder.Name:match("^MatchStage_") then
		return
	end
	for _, ride in folder:GetChildren() do
		if ride:IsA("Model") and ride:GetAttribute("RideId") and not self.Rides[ride] then
			local entry = {
				Model = ride,
				Base = ride:GetAttribute("BasePose"),
				RootPose = ride:GetAttribute("RootPose"),
				Parts = {},
			}
			entry.RootLocal = entry.Base:ToObjectSpace(entry.RootPose)
			for _, p in ride:GetDescendants() do
				if p:IsA("BasePart") and p:GetAttribute("RideMotion") then
					entry.Parts[p] = { Pose = entry.Base:ToObjectSpace(p.CFrame), Size = p.Size }
				end
			end
			self.Rides[ride] = entry
		end
	end
end
function Controller:Step(time)
	local camera = workspace.CurrentCamera
	for model, entry in self.Rides do
		if not model.Parent then
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
			character:PivotTo(entry.Base * motion * entry.RootLocal)
		end
		for part, rest in entry.Parts do
			if part:GetAttribute("RideMotion") == "Wing" then
				part.CFrame = entry.Base
					* motion
					* rest.Pose
					* CFrame.Angles(0, 0, wave * T.RideWingAngle * part:GetAttribute("WingSide"))
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
