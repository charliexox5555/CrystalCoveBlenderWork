--!strict
-- One server connection; no per-character listeners or remote inputs.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Balance = require(game:GetService("ReplicatedStorage").Shared.Config.Balance)

local FallService = {}
local connection: RBXScriptConnection? = nil

function FallService:Start()
	if connection then
		return
	end
	local lobby = workspace:WaitForChild("Lobby")
	local islands = lobby:WaitForChild("Islands")
	local elapsed = 0
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < Balance.Lobby.FallCheckSeconds then
			return
		end
		elapsed = 0
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if
				character
				and root
				and root:IsA("BasePart")
				and humanoid
				and humanoid.Health > 0
				and root.Position.Y < Balance.Lobby.FallY
			then
				local target: Vector3? = nil
				local nearest = math.huge
				for _, island in islands:GetChildren() do
					if island:IsA("Model") then
						local centre = island:GetPivot().Position
						local delta = Vector2.new(centre.X - root.Position.X, centre.Z - root.Position.Z)
						if delta.Magnitude < nearest then
							nearest = delta.Magnitude
							local safe = island:GetAttribute("RescuePosition")
							target = if typeof(safe) == "Vector3" then safe else centre
						end
					end
				end
				if not target then
					local spawn = lobby:FindFirstChildWhichIsA("SpawnLocation", true)
					if spawn then
						target = spawn.Position
					end
				end
				if target then
					local destination = target + Vector3.new(0, Balance.Lobby.RescueHeight, 0)
					character:PivotTo(CFrame.new(destination))
					root.AssemblyLinearVelocity = Vector3.zero
					root.AssemblyAngularVelocity = Vector3.zero
				end
			end
		end
	end)
end

function FallService:Destroy()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return FallService
