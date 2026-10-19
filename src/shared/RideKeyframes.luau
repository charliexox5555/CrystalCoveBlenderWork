-- Samples the rider animation families in Config/RideFamilies (pure; runs in Lune). Used by the Studio generator
-- for the uploaded KeyframeSequences and by RidePose as the code fallback, so both play the same motion.
local Families = if script then require(script.Parent.Config.RideFamilies) else require("./Config/RideFamilies")

local K = {}

export type Angles = { number }
export type PoseMap = { [string]: Angles }

K.Channels = {
	"Root",
	"Spine",
	"Head",
	"LeftArm",
	"RightArm",
	"LeftElbow",
	"RightElbow",
	"LeftHip",
	"RightHip",
	"LeftKnee",
	"RightKnee",
	"LeftAnkle",
	"RightAnkle",
}
local MIRROR = {
	LeftArm = "RightArm",
	RightArm = "LeftArm",
	LeftElbow = "RightElbow",
	RightElbow = "LeftElbow",
	LeftHip = "RightHip",
	RightHip = "LeftHip",
	LeftKnee = "RightKnee",
	RightKnee = "LeftKnee",
	LeftAnkle = "RightAnkle",
	RightAnkle = "LeftAnkle",
}

local function add(pose: PoseMap, channel: string, a: Angles, scale: number?)
	local s = scale or 1
	local p = pose[channel]
	if not p then
		p = { 0, 0, 0 }
		pose[channel] = p
	end
	p[1] += (a[1] or 0) * s
	p[2] += (a[2] or 0) * s
	p[3] += (a[3] or 0) * s
end

local function smooth(x: number): number
	return x * x * (3 - 2 * x)
end

-- Mirror a clip left <-> right (LeanRight from LeanLeft): swap sides, negate yaw and roll.
function K.mirror(clip)
	local function flipPose(src)
		local out = {}
		for channel, a in src do
			out[MIRROR[channel] or channel] = { a[1], -(a[2] or 0), -(a[3] or 0) }
		end
		return out
	end
	local out = { Seconds = clip.Seconds }
	if clip.Offset then
		out.Offset = flipPose(clip.Offset)
	end
	if clip.Waves then
		out.Waves = {}
		for _, w in clip.Waves do
			local ch = MIRROR[w[1]] or w[1]
			local amp = if w[2] == 1 then w[3] else -w[3]
			table.insert(out.Waves, { ch, w[2], amp, w[4], w[5] })
		end
	end
	if clip.Keys then
		out.Keys = {}
		for _, k in clip.Keys do
			table.insert(out.Keys, { k[1], flipPose(k[2]) })
		end
	end
	return out
end

function K.family(name: string)
	return Families.Families[name]
end

function K.clip(familyName: string, clipName: string)
	local family = Families.Families[familyName]
	if not family then
		return nil
	end
	local clip = family.Clips[clipName]
	if not clip and clipName == "LeanRight" and family.Clips.LeanLeft then
		clip = K.mirror(family.Clips.LeanLeft)
		family.Clips.LeanRight = clip
	end
	return clip
end

-- Full pose (channel -> {x, y, z} degrees) of a clip at `t` seconds. Loops wrap; one-shots clamp.
function K.sample(familyName: string, clipName: string, t: number, withBase: boolean?): PoseMap
	local family = Families.Families[familyName]
	local clip = K.clip(familyName, clipName)
	local pose: PoseMap = {}
	if not family or not clip then
		return pose
	end
	if withBase ~= false then
		for channel, a in family.Base do
			add(pose, channel, a)
		end
	end
	for channel, a in clip.Offset or {} do
		add(pose, channel, a)
	end
	local u = if Families.Loops[clipName] then (t / clip.Seconds) % 1 else math.clamp(t / clip.Seconds, 0, 1)
	for _, w in clip.Waves or {} do
		local v = w[3] * math.sin(2 * math.pi * (w[4] * u + w[5]))
		local a = { 0, 0, 0 }
		a[w[2]] = v
		add(pose, w[1], a)
	end
	local keys = clip.Keys
	if keys then
		local a, b = keys[1], keys[#keys]
		for i = 2, #keys do
			if u <= keys[i][1] then
				a, b = keys[i - 1], keys[i]
				break
			end
		end
		local span = b[1] - a[1]
		local blend = if span > 0 then smooth((u - a[1]) / span) else 0
		for channel, d in a[2] do
			add(pose, channel, d, 1 - blend)
		end
		for channel, d in b[2] do
			add(pose, channel, d, blend)
		end
	end
	return pose
end

-- Blend b into a by weight w (0..1), channel-wise linear on angles.
function K.blend(a: PoseMap, b: PoseMap, w: number): PoseMap
	local out: PoseMap = {}
	for channel, v in a do
		out[channel] = { v[1], v[2], v[3] }
	end
	for channel, v in b do
		local o = out[channel] or { 0, 0, 0 }
		out[channel] = { o[1] + (v[1] - o[1]) * w, o[2] + (v[2] - o[2]) * w, o[3] + (v[3] - o[3]) * w }
	end
	return out
end

-- R6 channel map: R6 has no waist, elbows, knees or ankles. Spine joins Root; a share of each elbow/knee
-- bend folds into the shoulder/hip so arms and legs point roughly where the R15 hands and feet are.
function K.toR6(familyName: string, pose: PoseMap): PoseMap
	local family = Families.Families[familyName] or {}
	local knee, elbow = family.R6KneeFold or 0.5, family.R6ElbowFold or 0.5
	local out: PoseMap = {}
	local function get(c)
		return pose[c] or { 0, 0, 0 }
	end
	out.Root = { get("Root")[1] + get("Spine")[1], get("Root")[2] + get("Spine")[2], get("Root")[3] + get("Spine")[3] }
	out.Head = table.clone(get("Head"))
	for _, side in { "Left", "Right" } do
		local arm, el = get(side .. "Arm"), get(side .. "Elbow")
		out[side .. "Arm"] = { arm[1] + el[1] * elbow, arm[2], arm[3] }
		local hip, kn = get(side .. "Hip"), get(side .. "Knee")
		out[side .. "Hip"] = { hip[1] + kn[1] * knee, hip[2], hip[3] }
	end
	return out
end

return K
