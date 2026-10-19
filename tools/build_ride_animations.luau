-- lune run tools/build_ride_animations
-- Writes every rider animation family clip (Config/RideFamilies, sampled by RideKeyframes) as a KeyframeSequence
-- .rbxm for R15 and R6 into assets/animations/rider/<Family>_<Clip>_<Rig>.rbxm, plus an upload list for
-- tools/opencloud/upload_assets.py (Type "Animation"). Same output as tools/studio/build_ride_animations.luau,
-- without needing Studio. Pose CFrames are joint transforms: R15 joints have identity C0 rotations; R6 joints use
-- the standard rotated C0s, so the parent-frame angles are converted with them.
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local K = require("../src/shared/RideKeyframes")
local F = require("../src/shared/Config/RideFamilies")

local CFrame, Enum, Instance = roblox.CFrame, roblox.Enum, roblox.Instance
local OUT = "assets/animations/rider"
local STEP = 1 / 15

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
-- Standard R6 joint C0 rotations (as in a generated R6 rig; checked in Studio 2026-10-19).
local R6_ROT = {
	RootJoint = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	Neck = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	["Right Shoulder"] = CFrame.Angles(0, math.pi / 2, 0),
	["Left Shoulder"] = CFrame.Angles(0, -math.pi / 2, 0),
	["Right Hip"] = CFrame.Angles(0, math.pi / 2, 0),
	["Left Hip"] = CFrame.Angles(0, -math.pi / 2, 0),
}
local PRIORITY = {
	Idle = Enum.AnimationPriority.Action,
	LeanLeft = Enum.AnimationPriority.Action2,
	LeanRight = Enum.AnimationPriority.Action2,
	Launch = Enum.AnimationPriority.Action3,
	Land = Enum.AnimationPriority.Action3,
}

local function angles(a)
	return CFrame.Angles(math.rad(a[1]), math.rad(a[2]), math.rad(a[3]))
end

local function keyframe(time, pose, rig)
	local kf = Instance.new("Keyframe")
	kf.Name = "Keyframe"
	kf.Time = time
	local made = {}
	for _, node in if rig == "R6" then R6_TREE else R15_TREE do
		local p = Instance.new("Pose")
		p.Name = node[1]
		p.EasingStyle, p.EasingDirection = Enum.PoseEasingStyle.Linear, Enum.PoseEasingDirection.In
		p.Weight = 1
		local a = node[3] and pose[node[3]]
		if a then
			if rig == "R6" then
				local r = R6_ROT[node[4]]
				p.CFrame = r:Inverse() * angles(a) * r
			else
				p.CFrame = angles(a)
			end
		end
		p.Parent = if node[2] then made[node[2]] else kf
		made[node[1]] = p
	end
	return kf
end

if not fs.isDir(OUT) then
	fs.writeDir(OUT)
end
local items = {}
local names = {}
for name in F.Families do
	table.insert(names, name)
end
table.sort(names)
for _, familyName in names do
	for _, clipName in F.ClipNames do
		local clip = K.clip(familyName, clipName)
		local frames = math.max(2, math.round(clip.Seconds / STEP))
		for _, rig in { "R15", "R6" } do
			local name = ("%s_%s_%s"):format(familyName, clipName, rig)
			local seq = Instance.new("KeyframeSequence")
			seq.Name = name
			seq.Loop = F.Loops[clipName] == true
			seq.Priority = PRIORITY[clipName]
			for i = 0, frames do
				local time = clip.Seconds * i / frames
				local pose = K.sample(familyName, clipName, time)
				if rig == "R6" then
					pose = K.toR6(familyName, pose)
				end
				keyframe(time, pose, rig).Parent = seq
			end
			local path = ("%s/%s.rbxm"):format(OUT, name)
			fs.writeFile(path, roblox.serializeModel({ seq }))
			table.insert(items, {
				Key = name,
				Path = path,
				Type = "Animation",
				Name = "GC Ride " .. name,
				Description = "Glass Clash rider animation (original, family " .. familyName .. ").",
			})
		end
	end
end
fs.writeFile(
	OUT .. "/upload_list.json",
	serde.encode("json", { Record = OUT .. "/roblox_assets.json", Items = items }, true)
)
print(("%d animations -> %s"):format(#items, OUT))
