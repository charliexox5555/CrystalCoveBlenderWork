-- Play/Client QA fixture: every family flyer in open sky with an R15 rider (copy of the local avatar) and an R6
-- rider (copy of workspace.RideQA_R6, a dummy the server fixture spawns with
-- Players:CreateHumanoidModelFromDescription(..., R6)), driven by the real RideMotion + RidePose. Reports each
-- rider's mode and playing ride tracks. _G.RideLineup.Bank(x) forces a bank (radians) to show the lean clips;
-- _G.RideLineup.Shot(name) fires a one-shot; _G.RideLineup.Stop() removes everything.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Client = game.Players.LocalPlayer.PlayerScripts:FindFirstChild("Client", true)
local RideMotion = require(Client.Presentation.RideMotion)
local RidePose = require(Client.Presentation.RidePose)
if _G.RideLineup then
	_G.RideLineup.Stop()
end
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "RideLineupQA", workspace
local function copy(model)
	local archivable = model.Archivable
	model.Archivable = true
	local c = model:Clone()
	model.Archivable = archivable
	for _, d in c:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	c.HumanoidRootPart.Anchored = true
	return c
end
local riders = {}
local r6Source = workspace:FindFirstChild("RideQA_R6")
local rigs = { R15 = game.Players.LocalPlayer.Character, R6 = r6Source }
local x = 0
for _, id in { "skyboard", "cloud_cushion", "rocket_skiff", "prism_ray" } do
	for _, rig in { "R15", "R6" } do
		if not rigs[rig] then
			continue
		end
		x += 13
		local base = CFrame.new(-60 + x, 80, 260)
		local ride = RS.Assets.Rideables[id]:Clone()
		for _, p in ride:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored, p.CanCollide = true, false
			end
		end
		ride:PivotTo(base)
		ride.Parent = folder
		local npc = copy(rigs[rig])
		npc.Name = id .. "_" .. rig
		npc.Parent = folder
		local entry = {
			Id = id,
			Rig = rig,
			Base = base,
			Ride = ride,
			Npc = npc,
			Motion = RideMotion.new(ride, base, { Id = id, Sound = false }),
		}
		entry.Pose = RidePose.new(npc, id, { Ride = ride })
		table.insert(riders, entry)
	end
end
local bank
local conn = RunService.RenderStepped:Connect(function()
	local t = workspace:GetServerTimeNow()
	for _, e in riders do
		local pose = e.Motion:Step(t, e.Base, true)
		e.Pose:Lean(bank or e.Motion.Bank, e.Motion.Pitch)
		local rootPose = pose * CFrame.new(0, e.Pose.Height or 0, 0)
		e.Npc:PivotTo(rootPose)
		e.Pose:PlaceAnchored(rootPose)
	end
end)
_G.RideLineup = {
	Riders = riders,
	Bank = function(value)
		bank = value
	end,
	Shot = function(name)
		for _, e in riders do
			e.Pose:OneShot(name)
		end
	end,
	Report = function()
		local out = {}
		for _, e in riders do
			local playing = {}
			for clip, track in e.Pose.Tracks or {} do
				if track.IsPlaying then
					table.insert(playing, ("%s(%.2f,%.1fs)"):format(clip, track.WeightCurrent, track.Length))
				end
			end
			table.insert(
				out,
				("%s %s mode=%s height=%.2f ik=%d tracks=[%s]"):format(
					e.Id,
					e.Rig,
					e.Pose.Mode,
					e.Pose.Height or -1,
					#(e.Pose.IK or {}),
					table.concat(playing, " ")
				)
			)
		end
		return table.concat(out, "\n")
	end,
	Stop = function()
		conn:Disconnect()
		for _, e in riders do
			e.Pose:Destroy()
			e.Motion:Destroy()
		end
		folder:Destroy()
		_G.RideLineup = nil
	end,
}
return #riders
