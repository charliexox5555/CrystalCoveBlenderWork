-- Rider pose on a flyer. Restores avatar joints/default animation on exit.
-- Flyers with an animation family (Config/RideFamilies) play its uploaded Animation assets through the Animator
-- (Idle loop, LeanLeft/LeanRight blended by bank, Launch/Land one-shots; handle families lock the hands onto the
-- flyer's GripL/GripR with IK). Where tracks can't play (anchored bot rigs, missing or failed assets) the same
-- family keyframes are sampled in code (RideKeyframes). Other players' characters show their owner's replicated
-- tracks. Flyers without a family keep the legacy Config/RideAnimations clip. Either way the rig is solved in root
-- space every frame so feet (or the seat) stay on the deck.
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Clips = require(RS.Shared.Config.RideAnimations)
local Families = require(RS.Shared.Config.RideFamilies)
local K = require(RS.Shared.RideKeyframes)
local Pose = {}
Pose.__index = Pose

local LEGACY_NAMES = {
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
-- Family channels: R15 has a Root and a Waist; R6's RootJoint carries both (RideKeyframes.toR6 merges them).
local FAMILY_NAMES = table.clone(LEGACY_NAMES)
FAMILY_NAMES.Root = "Root"
FAMILY_NAMES.RootJoint = "Root"
local CONTACT = {
	Feet = { LeftFoot = true, RightFoot = true, ["Left Leg"] = true, ["Right Leg"] = true },
	Seat = { LowerTorso = true, Torso = true },
	Low = {
		LeftFoot = true,
		RightFoot = true,
		LeftLowerLeg = true,
		RightLowerLeg = true,
		["Left Leg"] = true,
		["Right Leg"] = true,
	},
}
local LEAN_FULL = 0.3 -- flyer bank (radians) that plays a lean clip at full weight
local LOAD_TIMEOUT = 4 -- seconds before an asset that hasn't loaded falls back to code keyframes
local OBSERVE_TIMEOUT = 2.5 -- seconds to wait for another player's replicated ride tracks

local rideIds = {}
for _, clips in Families.AnimationIds do
	for _, rigs in clips do
		for _, assetId in rigs do
			rideIds[assetId] = true
		end
	end
end

-- Motor6D and AnimationConstraint joints in one shape (parts, C0/C1 and the live Transform).
local function joint(motor)
	if motor:IsA("Motor6D") then
		if motor.Part0 and motor.Part1 then
			return { Motor = motor, Part0 = motor.Part0, Part1 = motor.Part1, C0 = motor.C0, C1 = motor.C1 }
		end
	elseif motor:IsA("AnimationConstraint") then
		local a0, a1 = motor.Attachment0, motor.Attachment1
		if a0 and a1 and a0.Parent and a1.Parent then
			return { Motor = motor, Part0 = a0.Parent, Part1 = a1.Parent, C0 = a0.CFrame, C1 = a1.CFrame }
		end
	end
	return nil
end

-- options: { Ride = flyer model (for grip IK) }
function Pose.new(character, id, options)
	options = options or {}
	local flyer = Families.Flyers[id]
	local self = setmetatable({
		Character = character,
		Family = flyer and flyer.Family,
		Clip = Clips[id] or Clips.skyboard,
		Joints = {},
		LeanRoll = 0,
		LeanPitch = 0,
		Bank = 0,
		Tracks = nil,
		Own = {},
		Born = workspace:GetServerTimeNow(),
	}, Pose)
	self.Root = character:FindFirstChild("HumanoidRootPart")
	local human = character:FindFirstChildOfClass("Humanoid")
	self.Rig = if human and human.RigType == Enum.HumanoidRigType.R15 then "R15" else "R6"
	if not character:FindFirstChild("UpperTorso") then
		self.Rig = "R6"
	end
	local names = if self.Family then FAMILY_NAMES else LEGACY_NAMES
	-- Capture before stopping tracks: stopping an Animator can reset its transforms.
	for _, motor in character:GetDescendants() do
		local j = joint(motor)
		if j then
			j.Transform = motor.Transform
			j.Channel = names[motor.Name]
			table.insert(self.Joints, j)
		end
	end
	self.Animate = character:FindFirstChild("Animate")
	if self.Animate and self.Animate:IsA("LocalScript") then
		self.AnimateDisabled = self.Animate.Disabled
		self.Animate.Disabled = true
	end
	local animator = human and human:FindFirstChildOfClass("Animator")
	local anchoredRig = true
	for _, j in self.Joints do
		if not j.Part1.Anchored then
			anchoredRig = false
			break
		end
	end
	local player = Players:GetPlayerFromCharacter(character)
	-- Code: anchored presentation rigs (bots) and anything without an Animator. Observe: another player's
	-- character, animated by its owner's replicated tracks. Tracks: the local player and local display clones.
	self.Mode = if not self.Family
			or not animator
			or anchoredRig
			or not Families.AnimationIds[self.Family]
		then "Code"
		elseif player and player ~= Players.LocalPlayer then "Observe"
		else "Tracks"
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			if not (self.Mode == "Observe" and rideIds[track.Animation.AnimationId]) then
				track:Stop(0)
			end
		end
		self.AnimationPlayed = animator.AnimationPlayed:Connect(function(track)
			if self.Own[track] or (self.Mode == "Observe" and rideIds[track.Animation.AnimationId]) then
				return
			end
			track:Stop(0)
		end)
	end
	if self.Mode == "Tracks" then
		self:LoadTracks(animator)
		if self.Tracks and Families.Families[self.Family].Handles then
			self.HandleRide = options.Ride -- grips may stream in after the ride; Step retries LockHands
		end
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

function Pose:LoadTracks(animator)
	local ids = Families.AnimationIds[self.Family]
	if not ids then
		return
	end
	local tracks = {}
	for _, clipName in Families.ClipNames do
		local assetId = ids[clipName] and ids[clipName][self.Rig]
		if not assetId then
			return -- an incomplete set falls back to code keyframes as a whole
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = assetId
		local ok, track = pcall(animator.LoadAnimation, animator, animation)
		if not ok or not track then
			for _, t in tracks do
				t:Destroy()
			end
			return
		end
		self.Own[track] = true
		track.Looped = Families.Loops[clipName] == true
		tracks[clipName] = track
	end
	self.Tracks = tracks
	tracks.Idle:Play(0.25, 1, 1)
	tracks.LeanLeft:Play(0.25, 0.001, 1)
	tracks.LeanRight:Play(0.25, 0.001, 1)
end

-- Handle families: IK pulls each hand onto the flyer's grip attachments (R15 with live tracks).
function Pose:LockHands(ride)
	local human = self.Character:FindFirstChildOfClass("Humanoid")
	if self.Rig ~= "R15" or not human then
		self.HandleRide = nil
		return
	end
	local targets = { Left = ride:FindFirstChild("GripL", true), Right = ride:FindFirstChild("GripR", true) }
	if not (targets.Left and targets.Right) then
		return -- not streamed in yet
	end
	self.HandleRide = nil
	self.IK = {}
	for side, target in targets do
		local root = self.Character:FindFirstChild(side .. "UpperArm")
		local hand = self.Character:FindFirstChild(side .. "Hand")
		if target:IsA("Attachment") and root and hand then
			local ik = Instance.new("IKControl")
			ik.Name = "RideGrip" .. side
			ik.Type = Enum.IKControlType.Position
			ik.ChainRoot, ik.EndEffector = root, hand:FindFirstChild(side .. "GripAttachment") or hand
			ik.Target = target
			ik.Weight, ik.SmoothTime = 1, 0.04
			ik.Parent = human
			table.insert(self.IK, ik)
		end
	end
end

local function tracksReady(tracks)
	return tracks and tracks.Idle.Length > 0
end

-- Launch / Land one-shot (track if ready, otherwise code keyframes).
function Pose:OneShot(clipName)
	if not self.Family then
		return
	end
	if tracksReady(self.Tracks) then
		self.Tracks[clipName]:Play(0.1, 1, 1)
	else
		self.Shot = { Clip = clipName, Start = workspace:GetServerTimeNow() }
	end
end

function Pose:FamilyPose(time)
	local family = self.Family
	local pose = K.sample(family, "Idle", time)
	local lean = math.clamp(self.Bank / LEAN_FULL, -1, 1)
	if math.abs(lean) > 0.001 then
		pose = K.blend(pose, K.sample(family, if lean > 0 then "LeanLeft" else "LeanRight", time), math.abs(lean))
	end
	local shot = self.Shot
	if shot then
		local clip = K.clip(family, shot.Clip)
		local t = time - shot.Start
		if t >= clip.Seconds then
			self.Shot = nil
		else
			local w = math.min(1, t / 0.1, (clip.Seconds - t) / 0.15)
			pose = K.blend(pose, K.sample(family, shot.Clip, t), math.clamp(w, 0, 1))
		end
	end
	return if self.Rig == "R6" then K.toR6(family, pose) else pose
end

function Pose:Step(time)
	local mode = self.Mode
	if mode == "Tracks" and self.Tracks and not tracksReady(self.Tracks) and time - self.Born > LOAD_TIMEOUT then
		self:DropTracks() -- assets missing or failed: play the same keyframes in code
	elseif mode == "Observe" and time - self.Born > OBSERVE_TIMEOUT and not self.Seen then
		local human = self.Character:FindFirstChildOfClass("Humanoid")
		local animator = human and human:FindFirstChildOfClass("Animator")
		for _, track in animator and animator:GetPlayingAnimationTracks() or {} do
			if rideIds[track.Animation.AnimationId] then
				self.Seen = true
			end
		end
		if not self.Seen then
			self.Mode = "Code" -- the owner isn't streaming tracks (e.g. fallback there): pose locally
		end
	end
	if self.HandleRide and self.Tracks and time >= (self.NextGripTry or 0) then
		self.NextGripTry = time + 0.5
		self:LockHands(self.HandleRide)
	end
	if self.Tracks and tracksReady(self.Tracks) then
		local lean = math.clamp(self.Bank / LEAN_FULL, -1, 1)
		self.Tracks.LeanLeft:AdjustWeight(math.max(lean, 0.001), 0.1)
		self.Tracks.LeanRight:AdjustWeight(math.max(-lean, 0.001), 0.1)
	elseif self.Mode == "Code" or (self.Mode == "Tracks" and not tracksReady(self.Tracks)) then
		self:WriteTransforms(time)
	end
	return self:Solve()
end

function Pose:WriteTransforms(time)
	local familyPose = self.Family and self:FamilyPose(time)
	local clip = self.Clip
	local pitch, yaw, roll = 0, 0, 0
	if not familyPose then
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
		pitch, yaw, roll = a[2] + (b[2] - a[2]) * blend, a[3] + (b[3] - a[3]) * blend, a[4] + (b[4] - a[4]) * blend
	end
	for _, j in self.Joints do
		local motor = j.Motor
		if not motor.Parent then
			continue
		end
		local angles = if familyPose then familyPose[j.Channel] else clip.Pose[j.Channel]
		if angles then
			local x, y, z = angles[1], angles[2], angles[3]
			if not familyPose then
				if j.Channel == "Spine" then
					-- The rider leans into the flyer's bank and pitch (Lean, radians -> degrees, scaled down).
					x += pitch - self.LeanPitch
					y += yaw
					z += roll + self.LeanRoll
				elseif j.Channel == "LeftArm" or j.Channel == "RightArm" then
					z -= roll
				end
			end
			motor.Transform = j.C0.Rotation:Inverse()
				* CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
				* j.C0.Rotation
		else
			motor.Transform = CFrame.identity
		end
	end
end

-- Solve the rig in root space so crouched feet (or a seated torso) contact the deck.
function Pose:Solve()
	local poses = { [self.Root] = CFrame.identity }
	for _ = 1, #self.Joints do
		local advanced = false
		for _, j in self.Joints do
			if j.Motor.Parent and poses[j.Part0] and not poses[j.Part1] then
				poses[j.Part1] = poses[j.Part0] * j.C0 * j.Motor.Transform * j.C1:Inverse()
				advanced = true
			end
		end
		if not advanced then
			break
		end
	end
	local family = self.Family and Families.Families[self.Family]
	local contact = CONTACT[if family then family.Contact elseif self.Clip.Seated then "Seat" else "Feet"]
	local lowest = math.huge
	for part, pose in poses do
		if contact[part.Name] then
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

-- Bank/pitch of the flyer in radians. Families blend their lean clips by bank; legacy clips tilt the spine
-- by a share of it (Clip.Lean, default 0.8).
function Pose:Lean(bank, pitch)
	self.Bank = bank or 0
	local share = self.Clip.Lean or 0.8
	self.LeanRoll, self.LeanPitch = math.deg(bank or 0) * share, math.deg(pitch or 0) * share * 0.5
end

function Pose:PlaceAnchored(rootPose)
	for part, pose in self.LocalParts or {} do
		if part ~= self.Root and part.Parent and part.Anchored then
			part.CFrame = rootPose * pose
		end
	end
end

function Pose:DropTracks()
	for _, track in self.Tracks or {} do
		track:Stop(0.1)
		track:Destroy()
	end
	self.Tracks = nil
	for _, ik in self.IK or {} do
		ik:Destroy()
	end
	self.IK = nil
end

function Pose:Destroy()
	if self.Connection then
		self.Connection:Disconnect()
	end
	if self.AnimationPlayed then
		self.AnimationPlayed:Disconnect()
	end
	self:DropTracks()
	for _, j in self.Joints do
		if j.Motor.Parent then
			j.Motor.Transform = j.Transform
		end
	end
	if self.Animate and self.Animate.Parent and self.AnimateDisabled ~= nil then
		self.Animate.Disabled = self.AnimateDisabled
	end
end

return Pose
