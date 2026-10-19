-- Edit mode (Studio MCP). Builds rider KeyframeSequences from Config/RideFamilies (sampled by RideKeyframes)
-- into ServerStorage.RideAnimations.<Family>_<Clip>_<R15|R6>, ready to serialize and upload as Animation assets.
-- Rebuilding replaces the sequences of the same name. Pose CFrames are joint transforms: R15 joints have identity
-- C0 rotations, so a channel's angles apply directly; R6 joints are rotated, so the parent-frame angles are
-- converted with the standard R6 C0 rotations read from a generated R6 rig.
assert(not game:GetService("RunService"):IsRunning(), "Build in Edit")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local K = require(RS.Shared.RideKeyframes)
local F = require(RS.Shared.Config.RideFamilies)
local STEP = 1 / 15

local folder = SS:FindFirstChild("RideAnimations") or Instance.new("Folder")
folder.Name, folder.Parent = "RideAnimations", SS

local R15_TREE = {
	{ "HumanoidRootPart", nil, nil },
	{ "LowerTorso", "HumanoidRootPart", "Root" },
	{ "UpperTorso", "LowerTorso", "Spine" },
	{ "Head", "UpperTorso", "Head" },
	{ "LeftUpperArm", "UpperTorso", "LeftArm" },
	{ "LeftLowerArm", "LeftUpperArm", "LeftElbow" },
	{ "LeftHand", "LeftLowerArm", nil },
	{ "RightUpperArm", "UpperTorso", "RightArm" },
	{ "RightLowerArm", "RightUpperArm", "RightElbow" },
	{ "RightHand", "RightLowerArm", nil },
	{ "LeftUpperLeg", "LowerTorso", "LeftHip" },
	{ "LeftLowerLeg", "LeftUpperLeg", "LeftKnee" },
	{ "LeftFoot", "LeftLowerLeg", "LeftAnkle" },
	{ "RightUpperLeg", "LowerTorso", "RightHip" },
	{ "RightLowerLeg", "RightUpperLeg", "RightKnee" },
	{ "RightFoot", "RightLowerLeg", "RightAnkle" },
}
local R6_TREE = {
	{ "HumanoidRootPart", nil, nil, nil },
	{ "Torso", "HumanoidRootPart", "Root", "RootJoint" },
	{ "Head", "Torso", "Head", "Neck" },
	{ "Left Arm", "Torso", "LeftArm", "Left Shoulder" },
	{ "Right Arm", "Torso", "RightArm", "Right Shoulder" },
	{ "Left Leg", "Torso", "LeftHip", "Left Hip" },
	{ "Right Leg", "Torso", "RightHip", "Right Hip" },
}

-- Standard R6 joint rotations, read from a generated rig.
local R6_ROT = {}
do
	local rig = game:GetService("Players")
		:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	for _, j in rig:GetDescendants() do
		if j:IsA("Motor6D") then
			R6_ROT[j.Name] = j.C0.Rotation
		end
	end
	rig:Destroy()
end

local function angles(a)
	return CFrame.Angles(math.rad(a[1]), math.rad(a[2]), math.rad(a[3]))
end

local function keyframe(time, pose, rig)
	local kf = Instance.new("Keyframe")
	kf.Time = time
	local made = {}
	local tree = if rig == "R6" then R6_TREE else R15_TREE
	for _, node in tree do
		local p = Instance.new("Pose")
		p.Name = node[1]
		p.EasingStyle, p.EasingDirection = Enum.PoseEasingStyle.Linear, Enum.PoseEasingDirection.In
		local a = node[3] and pose[node[3]]
		if a then
			if rig == "R6" then
				local r = R6_ROT[node[4]] or CFrame.identity
				p.CFrame = r:Inverse() * angles(a) * r
			else
				p.CFrame = angles(a)
			end
		end
		p.Weight = 1
		p.Parent = if node[2] then made[node[2]] else kf
		made[node[1]] = p
	end
	return kf
end

local PRIORITY = {
	Idle = Enum.AnimationPriority.Action,
	LeanLeft = Enum.AnimationPriority.Action2,
	LeanRight = Enum.AnimationPriority.Action2,
	Launch = Enum.AnimationPriority.Action3,
	Land = Enum.AnimationPriority.Action3,
}

local built = {}
local families = _G.RideAnimationFamilies -- optional list to build a subset
for familyName in F.Families do
	if families and not table.find(families, familyName) then
		continue
	end
	for _, clipName in F.ClipNames do
		local clip = K.clip(familyName, clipName)
		local frames = math.max(2, math.round(clip.Seconds / STEP))
		for _, rig in { "R15", "R6" } do
			local name = ("%s_%s_%s"):format(familyName, clipName, rig)
			local old = folder:FindFirstChild(name)
			if old then
				old:Destroy()
			end
			local seq = Instance.new("KeyframeSequence")
			seq.Name = name
			seq.Loop = F.Loops[clipName] == true
			seq.Priority = PRIORITY[clipName]
			seq:SetAttribute("Family", familyName)
			seq:SetAttribute("Clip", clipName)
			seq:SetAttribute("Rig", rig)
			for i = 0, frames do
				local time = clip.Seconds * i / frames
				local pose = K.sample(familyName, clipName, time)
				if rig == "R6" then
					pose = K.toR6(familyName, pose)
				end
				keyframe(time, pose, rig).Parent = seq
			end
			seq.Parent = folder
			table.insert(built, name)
		end
	end
	task.wait()
end
return ("%d sequences: %s"):format(#built, table.concat(built, ", "))
