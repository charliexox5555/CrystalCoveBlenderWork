-- Play/Client: original clips on the live R15 joint format and the anchored R6 bot rig.
local Pose = require(game.Players.LocalPlayer.PlayerScripts.Client.Presentation.RidePose)
local Clips = require(game.ReplicatedStorage.Shared.Config.RideAnimations)
local player = game.Players.LocalPlayer
local stage =
	assert(workspace:FindFirstChild("MatchStage_studio-match-1"), "Start a Studio mock player/bot match first")
local source = player.Character
local savedArchivable = source.Archivable
source.Archivable = true
local clone = source:Clone()
source.Archivable = savedArchivable
clone.Name, clone.Parent = "RidePoseR15Check", workspace
local bot = stage.Bot2:Clone()
bot.Name, bot.Parent = "RidePoseR6Check", workspace
local checks, signatures = 0, {}
local function check(value, message)
	assert(value, message)
	checks += 1
end
local active
local ok, problem = pcall(function()
	for _, rig in { clone, bot } do
		local originals = {}
		for _, joint in rig:GetDescendants() do
			if joint:IsA("Motor6D") or joint:IsA("AnimationConstraint") then
				originals[joint] = { C0 = joint.C0, Transform = joint.Transform }
			end
		end
		check(next(originals) ~= nil, "Rig has supported joints")
		local animate = rig:FindFirstChild("Animate")
		local disabled = animate and animate.Disabled
		for id, clip in Clips do
			if id == "Motion" then
				continue -- flyer motion profiles (RideMotion), not a pose clip
			end
			active = Pose.new(rig, id)
			active.Connection:Disconnect() -- deterministic frame sampling in this fixture
			check(#active.Joints >= 6, "Both legacy and modern joint formats supported")
			local first
			for _, phase in { 0, 0.25, 0.5, 0.75, 1 } do
				local height = active:Step(phase * clip.Seconds)
				check(height and height > 0 and height < 6, "Contact solver gives a valid riding height")
				local transforms = {}
				for _, joint in active.Joints do
					check(joint.Motor.C0 == originals[joint.Motor].C0, "Rig attachments remain untouched")
					transforms[joint.Motor] = joint.Motor.Transform
				end
				if phase == 0 then
					first = transforms
				elseif phase == 1 then
					for joint, transform in transforms do
						check(transform:FuzzyEq(first[joint], 0.0001), "Loop closes without a pose snap")
					end
				end
				if phase == 0.25 then
					signatures[rig.Name .. id] = tostring(active.Joints[1].Motor.Transform) .. tostring(height)
				end
			end
			local listener = active.AnimationPlayed
			active:Destroy()
			active = nil
			check(not listener or not listener.Connected, "Animation listener cleaned up")
			for joint, saved in originals do
				check(joint.Transform:FuzzyEq(saved.Transform, 0.0001), "Original transforms restored: " .. joint.Name)
			end
			check(not animate or animate.Disabled == disabled, "Default Animate state restored")
		end
	end
	local unique = {}
	for _, signature in signatures do
		unique[signature] = true
	end
	local count = 0
	for _ in unique do
		count += 1
	end
	check(count >= 4, "Distinct authored ride poses")
end)
if active then
	active:Destroy()
end
clone:Destroy()
bot:Destroy()
assert(ok, problem)
return { Passed = checks, Clips = 4, Rigs = 2 }
