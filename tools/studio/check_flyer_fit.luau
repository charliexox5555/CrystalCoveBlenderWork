-- Play/Client. Rider fit on the installed flyers: poses a copy of the local avatar with each flyer's clip
-- (RidePose, the same solver as rounds) and reports key body points in the flyer's pivot space
-- (contact point at the origin, nose toward -Z), next to the flyer's own targets (attachments).
-- Optional: _G.FlyerFitClips = { [id] = { Pose = {...} } } overrides clip poses for a trial run.
local RS = game:GetService("ReplicatedStorage")
local Clips = require(RS.Shared.Config.RideAnimations)
local Pose = require(game.Players.LocalPlayer.PlayerScripts.Client.Presentation.RidePose)
local source = game.Players.LocalPlayer.Character
local archivable = source.Archivable
source.Archivable = true
local rig = source:Clone()
source.Archivable = archivable
for _, d in rig:GetDescendants() do
	if d:IsA("LuaSourceContainer") or d:IsA("Sound") then
		d:Destroy()
	end
end
rig.Name, rig.Parent = "FlyerFitCheck", workspace
local function point(poses, height, name, offset)
	for part, cf in poses do
		if part.Name == name then
			return CFrame.new(0, height, 0) * cf * (offset or Vector3.zero)
		end
	end
end
local out = {}
for _, id in { "skyboard", "cloud_cushion", "rocket_skiff", "prism_ray" } do
	local clip = Clips[id]
	local saved = clip.Pose
	if _G.FlyerFitClips and _G.FlyerFitClips[id] then
		clip.Pose = _G.FlyerFitClips[id].Pose
	end
	local p = Pose.new(rig, id)
	p.Connection:Disconnect()
	local height = p:Step(0)
	local poses = p.LocalParts
	local function v(name, offset)
		local cf = point(poses, height, name, offset)
		return cf and ("(%.2f, %.2f, %.2f)"):format(cf.X, cf.Y, cf.Z) or "?"
	end
	local line = ("%s height=%.2f LeftHand=%s RightHand=%s LeftFoot=%s RightFoot=%s LowerTorso=%s Head=%s"):format(
		id,
		height or -1,
		v("LeftHand", Vector3.new(0, -0.25, 0)),
		v("RightHand", Vector3.new(0, -0.25, 0)),
		v("LeftFoot"),
		v("RightFoot"),
		v("LowerTorso"),
		v("Head")
	)
	local model = RS.Assets.Rideables:FindFirstChild(id)
	if model then
		local targets = {}
		for _, a in model:GetDescendants() do
			if a:IsA("Attachment") and (a.Name:match("^Hand") or a.Name:match("^Rider")) then
				local w = model:GetPivot():PointToObjectSpace(a.WorldPosition)
				table.insert(targets, ("%s=(%.2f, %.2f, %.2f)"):format(a.Name, w.X, w.Y, w.Z))
			end
		end
		line ..= " targets " .. table.concat(targets, " ")
	end
	table.insert(out, line)
	p:Destroy()
	clip.Pose = saved
end
rig:Destroy()
return table.concat(out, "\n")
