-- Edit mode only. Preserve the prior live models; canonical staged art remains untouched.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before promoting art")
local RS, SS = game.ReplicatedStorage, game.ServerStorage
local roster = require(RS.Shared.Config.ReleaseRoster)
local staged = SS.CombatReleaseStaged
local checks = 0
for _, id in roster.Ids do
	local model = assert(staged.Glassies:FindFirstChild(id), "Missing staged " .. id)
	assert(model:FindFirstChild("Body") and #model.Shards:GetChildren() == 16, "Body/shards " .. id)
	for _, p in model:GetDescendants() do
		assert(not p:IsA("LuaSourceContainer"), "Unexpected asset script")
		if p:IsA("BasePart") then
			assert(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery, "Asset flags " .. id)
			assert(p:IsA("MeshPart") and p.MeshId:match("^rbxassetid://%d+$"), "Mesh identity " .. id)
			checks += 1
		end
	end
end
assert(#staged.Glassies:GetChildren() == 24, "Fixed 24 roster")
local assets = RS.Assets
if assets.Glassies:GetAttribute("FullCombatRelease") then
	return { AlreadyPromoted = true, Checks = checks }
end
local backup = Instance.new("Folder")
backup.Name = "LiveBeforeFullRelease_20261015"
assert(not SS.CombatReleaseBackups:FindFirstChild(backup.Name), "Backup already exists; inspect before retry")
local models = staged.Glassies:Clone()
models:SetAttribute("FullCombatRelease", true)
for _, model in models:GetChildren() do
	model:SetAttribute("ReleaseVersion", 2)
end
local combat = staged.VFX.Combat:Clone()
combat:SetAttribute("PreviewOnly", false)
combat:SetAttribute("RulesConnected", true)
local vfx = assets:FindFirstChild("VFX")
if not vfx then
	vfx = Instance.new("Folder")
	vfx.Name, vfx.Parent = "VFX", assets
end
backup.Parent = SS.CombatReleaseBackups
assets.Glassies.Parent = backup
if vfx:FindFirstChild("Combat") then
	vfx.Combat.Parent = backup
end
models.Parent, combat.Parent = assets, vfx
return { Promoted = #models:GetChildren(), Checks = checks, Backup = backup:GetFullName() }
