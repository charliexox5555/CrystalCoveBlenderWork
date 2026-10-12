--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local names = { "BattleStarted", "ClashStarted", "ReleaseSwing", "ClashResolved", "BattleEnded" }
local folder = ReplicatedStorage:FindFirstChild("Remotes")
if not folder and RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
end
folder = folder or ReplicatedStorage:WaitForChild("Remotes")
local remotes: { [string]: RemoteEvent } = {}
for _, name in names do
	local remote = folder:FindFirstChild(name)
	if not remote and RunService:IsServer() then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	remote = remote or folder:WaitForChild(name)
	assert(remote:IsA("RemoteEvent"), "Unexpected remote class: " .. name)
	remotes[name] = remote
end
return remotes
