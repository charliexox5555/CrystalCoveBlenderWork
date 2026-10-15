assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
local storage, RS = game.ServerStorage, game.ReplicatedStorage
local backups = storage.UIBackups
if not backups:FindFirstChild("BeforeUprightPortraits_20261015") then
	local copy = Instance.new("Folder")
	copy.Name, copy.Parent = "BeforeUprightPortraits_20261015", backups
	for _, gui in game.StarterGui:GetChildren() do
		gui:Clone().Parent = copy
	end
end
local modules = game.StarterPlayer.StarterPlayerScripts.Client.UI:Clone()
modules.Name, modules.Parent = "PortraitTemplateBuild", storage
local Portrait = require(modules.Components.GlassyPortrait)
local count, kilns = 0, 0
for _, v in game.StarterGui:GetDescendants() do
	if v:IsA("ViewportFrame") then
		local world = v:FindFirstChildOfClass("WorldModel")
		local body = world and world:FindFirstChild("Body")
		local id = v:GetAttribute("GlassyId")
		if not id and body and body:IsA("MeshPart") then
			for _, asset in RS.Assets.Glassies:GetChildren() do
				if asset:FindFirstChild("Body") and asset.Body:IsA("MeshPart") and asset.Body.MeshId == body.MeshId then
					id = asset.Name
					break
				end
			end
		end
		if id then
			Portrait.new(v.Parent, id, v.Size, v.Position, v.Name)
			count += 1
		elseif world then
			Portrait.fit(v, CFrame.lookAt(Vector3.new(1.2, 0.4, 4), Vector3.zero), 35)
			kilns += 1
		end
	end
end
modules:Destroy()
return { UprightGlassies = count, AuthoredCameras = kilns }
