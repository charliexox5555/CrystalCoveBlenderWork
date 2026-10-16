-- Original looping joint keyframes. Restores avatar joints/default animation on exit.
local Clips = require(game.ReplicatedStorage.Shared.Config.RideAnimations)
local RunService = game:GetService("RunService")
local Pose = {}
Pose.__index = Pose
local names = {
	Waist = "Spine",
	RootJoint = "Spine",
	Neck = "Head",
	LeftShoulder = "LeftArm",
	RightShoulder = "RightArm",
	["Left Shoulder"] = "LeftArm",
	["Right Shoulder"] = "RightArm",
	LeftHip = "LeftHip",
	RightHip = "RightHip",
	["Left Hip"] = "LeftHip",
	["Right Hip"] = "RightHip",
	LeftKnee = "LeftKnee",
	RightKnee = "RightKnee",
	LeftAnkle = "LeftAnkle",
	RightAnkle = "RightAnkle",
	LeftElbow = "LeftElbow",
	RightElbow = "RightElbow",
}
function Pose.new(character, id)
	local self = setmetatable({ Character = character, Clip = Clips[id] or Clips.skyboard, Joints = {} }, Pose)
	self.Root = character:FindFirstChild("HumanoidRootPart")
	-- Capture before stopping tracks: stopping an Animator can reset its transforms.
	for _, motor in character:GetDescendants() do
		if (motor:IsA("Motor6D") or motor:IsA("AnimationConstraint")) and motor.Part0 and motor.Part1 then
			table.insert(
				self.Joints,
				{ Motor = motor, C0 = motor.C0, Transform = motor.Transform, Channel = names[motor.Name] }
			)
		end
	end
	self.Animate = character:FindFirstChild("Animate")
	if self.Animate and self.Animate:IsA("LocalScript") then
		self.AnimateDisabled = self.Animate.Disabled
		self.Animate.Disabled = true
	end
	local human = character:FindFirstChildOfClass("Humanoid")
	local animator = human and human:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0)
		end
		self.AnimationPlayed = animator.AnimationPlayed:Connect(function(track)
			track:Stop(0)
		end)
	end
	self:Step(workspace:GetServerTimeNow())
	-- Animator evaluates before PreSimulation, for both modern constraints and Motor6Ds.
	self.Connection = RunService.PreSimulation:Connect(function()
		if self.Root.Parent then
			self:Step(workspace:GetServerTimeNow())
		end
	end)
	return self
end
function Pose:Step(time)
	local clip = self.Clip
	local phase = time % clip.Seconds / clip.Seconds
	local a, b = clip.Keys[1], clip.Keys[2]
	for i = 2, #clip.Keys do
		if phase <= clip.Keys[i][1] then
			a, b = clip.Keys[i - 1], clip.Keys[i]
			break
		end
	end
	local blend = (phase - a[1]) / (b[1] - a[1])
	blend = blend * blend * (3 - 2 * blend)
	local pitch, yaw, roll = a[2] + (b[2] - a[2]) * blend, a[3] + (b[3] - a[3]) * blend, a[4] + (b[4] - a[4]) * blend
	for _, joint in self.Joints do
		local motor = joint.Motor
		if not motor.Parent then
			continue
		end
		local angles = clip.Pose[joint.Channel]
		if angles then
			local x, y, z = unpack(angles)
			if joint.Channel == "Spine" then
				x += pitch
				y += yaw
				z += roll
			elseif joint.Channel == "LeftArm" then
				z -= roll
			elseif joint.Channel == "RightArm" then
				z -= roll
			end
			motor.Transform = joint.C0.Rotation:Inverse()
				* CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
				* joint.C0.Rotation
		else
			motor.Transform = CFrame.identity
		end
	end
	-- Solve the rig in root space so crouched feet (or a seated torso) contact the deck.
	local poses = { [self.Root] = CFrame.identity }
	for _ = 1, #self.Joints do
		local advanced = false
		for _, joint in self.Joints do
			local motor = joint.Motor
			if motor.Parent and poses[motor.Part0] and not poses[motor.Part1] then
				poses[motor.Part1] = poses[motor.Part0] * motor.C0 * motor.Transform * motor.C1:Inverse()
				advanced = true
			end
		end
		if not advanced then
			break
		end
	end
	local lowest = math.huge
	for part, pose in poses do
		local name = part.Name
		local contact = if clip.Seated
			then (name == "LowerTorso" or name == "Torso")
			else (name == "LeftFoot" or name == "RightFoot" or name == "Left Leg" or name == "Right Leg")
		if contact then
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						lowest = math.min(lowest, pose:PointToWorldSpace(part.Size * Vector3.new(x, y, z) / 2).Y)
					end
				end
			end
		end
	end
	self.LocalParts = poses
	self.Height = if lowest < math.huge then -lowest else nil
	return self.Height
end
function Pose:PlaceAnchored(rootPose)
	for part, pose in self.LocalParts or {} do
		if part ~= self.Root and part.Parent and part.Anchored then
			part.CFrame = rootPose * pose
		end
	end
end
function Pose:Destroy()
	if self.Connection then
		self.Connection:Disconnect()
	end
	if self.AnimationPlayed then
		self.AnimationPlayed:Disconnect()
	end
	for _, joint in self.Joints do
		if joint.Motor.Parent then
			joint.Motor.Transform = joint.Transform
		end
	end
	if self.Animate and self.Animate.Parent and self.AnimateDisabled ~= nil then
		self.Animate.Disabled = self.AnimateDisabled
	end
end
return Pose
