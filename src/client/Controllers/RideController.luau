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
				entry.Parts[p] =
					{ Pose = entry.Base:ToObjectSpace(p.CFrame), Size = p.Size, Transparency = p.Transparency }
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
		local phase = time * T.RideBobHz * math.pi * 2 + entry.Base.Position.X
		local wave = math.sin(phase)
		local motion = CFrame.new(0, wave * T.RideBob, 0)
			* CFrame.Angles(math.cos(phase) * T.RideNod, 0, wave * T.RideBank)
		local near = (camera.CFrame.Position - entry.Base.Position).Magnitude <= T.RideEmitterDistance
		if entry.EmittersOn ~= near then
			-- Particles, trails, beams and lights tagged RideEmitter only run near the camera.
			entry.EmittersOn, entry.Lights = near, {}
			for _, effect in model:GetDescendants() do
				if
					effect:GetAttribute("RideEmitter")
					and (
						effect:IsA("ParticleEmitter")
						or effect:IsA("Trail")
						or effect:IsA("Beam")
						or effect:IsA("Light")
					)
				then
					effect.Enabled = near
					if effect:IsA("Light") then
						entry.Lights[effect] = effect:GetAttribute("BaseBrightness") or effect.Brightness
					end
				end
			end
		end
		for light, brightness in entry.Lights do
			light.Brightness = brightness * (1 - T.RideLightFlicker * (0.5 + 0.5 * math.noise(time * 6, light.Range)))
		end
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
			local kind = part:GetAttribute("RideMotion")
			if kind == "Wing" then
				local pivot = part:GetAttribute("WingPivot") or Vector3.zero
				-- Quick down-stroke, slower recovery reads as a real wingbeat.
				local flap = wave + T.RideFlapSharpness * 0.35 * math.sin(phase * 2)
				part.CFrame = entry.Base
					* motion
					* rest.Pose
					* CFrame.new(pivot)
					* CFrame.Angles(0, 0, flap * T.RideWingAngle * part:GetAttribute("WingSide"))
					* CFrame.new(-pivot)
			elseif kind == "Swing" then
				-- The hanging lantern trails the bob and bank like a pendulum.
				local pivot = part:GetAttribute("SwingPivot") or Vector3.zero
				local swing = math.sin(phase - T.RideSwingLag) * T.RideSwingAngle
				part.CFrame = entry.Base
					* motion
					* rest.Pose
					* CFrame.new(pivot)
					* CFrame.Angles(swing, 0, -swing * 0.5)
					* CFrame.new(-pivot)
			elseif kind == "Spin" then
				part.CFrame = entry.Base * motion * rest.Pose * CFrame.Angles(0, 0, time * T.RideSpinSpeed)
			elseif kind == "Pulse" then
				local breathe = math.sin(time * T.RidePulseHz * math.pi * 2)
				part.Size = rest.Size * (1 + T.RidePulseScale * breathe)
				part.Transparency = (rest.Transparency or 0) + T.RidePulseFade * (0.5 + 0.5 * breathe)
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
