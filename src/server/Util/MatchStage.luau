-- Presentation staging only. Pendulum coordinates, damage and hearts remain server rules.
local RS = game:GetService("ReplicatedStorage")
local Feel = require(RS.Shared.Config.Balance).Feel
local Tuning = require(RS.Shared.Config.Balance).CosmeticPresentation
local Stage = {}

function Stage.positions(arena)
	return {
		arena.Pads[1].Position + Vector3.yAxis * (Feel.PadRootHeight + Tuning.RideLift),
		arena.Pads[2].Position + Vector3.yAxis * (Feel.PadRootHeight + Tuning.RideLift),
	}
end

local function bot(parent, name, pose, side)
	local model = Instance.new("Model")
	model.Name = name
	local colors = { Color3.fromHex("#62DDEB"), Color3.fromHex("#FFAD55") }
	local pieces = {
		{ "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.zero },
		{ "Torso", Vector3.new(2, 2, 1), Vector3.zero },
		{ "Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0) },
		{ "Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0) },
		{ "Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0) },
		{ "Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0) },
		{ "Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0) },
	}
	for _, spec in pieces do
		local part = Instance.new("Part")
		part.Name, part.Size, part.CFrame = spec[1], spec[2], pose * CFrame.new(spec[3])
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
		part.Material, part.Color = Enum.Material.SmoothPlastic, colors[side]
		if part.Name == "HumanoidRootPart" then
			part.Transparency = 1
		elseif part.Name == "Head" then
			part.Color = Color3.fromHex("#F8D99B")
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType, mesh.Scale, mesh.Parent = Enum.MeshType.Head, Vector3.new(1.25, 1.25, 1.25), part
		end
		part.Parent = model
	end
	local human = Instance.new("Humanoid")
	human.DisplayDistanceType, human.Parent = Enum.HumanoidDisplayDistanceType.None, model
	model.PrimaryPart = model.HumanoidRootPart
	-- Anchored presentation rig; client keyframes solve these joints without physics.
	for _, spec in
		{
			{ "RootJoint", "HumanoidRootPart", "Torso", Vector3.zero, Vector3.zero },
			{ "Neck", "Torso", "Head", Vector3.new(0, 1, 0), Vector3.new(0, -0.5, 0) },
			{ "Left Shoulder", "Torso", "Left Arm", Vector3.new(-1, 0.5, 0), Vector3.new(0.5, 0.5, 0) },
			{ "Right Shoulder", "Torso", "Right Arm", Vector3.new(1, 0.5, 0), Vector3.new(-0.5, 0.5, 0) },
			{ "Left Hip", "Torso", "Left Leg", Vector3.new(-0.5, -1, 0), Vector3.new(0, 1, 0) },
			{ "Right Hip", "Torso", "Right Leg", Vector3.new(0.5, -1, 0), Vector3.new(0, 1, 0) },
		}
	do
		local joint = Instance.new("Motor6D")
		joint.Name, joint.Part0, joint.Part1 = spec[1], model[spec[2]], model[spec[3]]
		joint.C0, joint.C1 = CFrame.new(spec[4]), CFrame.new(spec[5])
		joint.Parent = joint.Part0
	end
	model.Parent = parent
	return model
end

function Stage.start(entry)
	local folder = Instance.new("Folder")
	folder.Name = "MatchStage_" .. entry.Id
	folder.Parent = workspace
	entry.Stage = { Folder = folder, Saved = {} }
	local positions = Stage.positions(entry.Arena)
	local center = (positions[1] + positions[2]) / 2
	for side = 1, 2 do
		-- Cosmetic rides hover above the existing pads, facing into the arena.
		local pose = CFrame.lookAt(positions[side], center)
		local player = entry.Players[side]
		local character = player and player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local human = character and character:FindFirstChildOfClass("Humanoid")
		if root and human then
			local height = if human.RigType == Enum.HumanoidRigType.R6
				then Feel.PadRootHeight
				else human.HipHeight + root.Size.Y / 2
			local position = entry.Arena.Pads[side].Position + Vector3.yAxis * (height + Tuning.RideLift)
			pose = CFrame.lookAt(position, Vector3.new(center.X, position.Y, center.Z))
			entry.Stage.Saved[side] = {
				Character = character,
				Root = root,
				Humanoid = human,
				Pivot = character:GetPivot(),
				Anchored = root.Anchored,
				AutoRotate = human.AutoRotate,
			}
			root.Anchored, human.AutoRotate = true, false
			character:PivotTo(pose)
			root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
			human:Move(Vector3.zero)
			human:ChangeState(Enum.HumanoidStateType.Running)
			local animator = human:FindFirstChildOfClass("Animator")
			for _, track in animator and animator:GetPlayingAnimationTracks() or {} do
				if track.Priority.Value <= Enum.AnimationPriority.Movement.Value then
					track:Stop()
				end
			end
		else
			character = bot(folder, "Bot" .. side, pose, side)
		end
		local id = entry.Cosmetics and entry.Cosmetics.Rideables[side] or "skyboard"
		local source = RS.Assets.Rideables:FindFirstChild(id) or RS.Assets.Rideables.skyboard
		local ride = source:Clone()
		ride.Name = "Ride" .. side
		local top = entry.Arena.Pads[side].Position + Vector3.yAxis * Tuning.RideLift
		local ridePose = CFrame.lookAt(top, Vector3.new(center.X, top.Y, center.Z))
		ride:PivotTo(ridePose)
		ride:SetAttribute("BasePose", ridePose)
		ride:SetAttribute("RootPose", character:GetPivot())
		ride:SetAttribute("RideId", id)
		local rider = Instance.new("ObjectValue")
		rider.Name, rider.Value, rider.Parent = "Rider", character, ride
		ride.Parent = folder
	end
end

function Stage.finish(entry)
	if not entry.Stage then
		return
	end
	for _, saved in entry.Stage.Saved do
		if saved.Root.Parent and saved.Character.Parent then
			saved.Character:PivotTo(saved.Pivot)
			saved.Root.AssemblyLinearVelocity, saved.Root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
			saved.Root.Anchored, saved.Humanoid.AutoRotate = saved.Anchored, saved.AutoRotate
		end
	end
	entry.Stage.Folder:Destroy()
	entry.Stage = nil
end

return Stage
