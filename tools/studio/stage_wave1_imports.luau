-- Stage exact Wave1 import names; preserve every raw Model and reject embedded scripts.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play first")
local wanted = {}
for id in require(game.ReplicatedStorage.Shared.Config.ArtImports) do
	wanted["Wave1_" .. id] = true
end
for _, id in
	{
		"crystal_single",
		"crystal_small",
		"crystal_big",
		"kiln_crystal",
		"featured_arch",
		"cloud_puff",
		"cloud_long",
		"cloud_bank",
	}
do
	wanted["Wave1_" .. id] = true
end
local root = workspace:FindFirstChild("GlassClashImports") or Instance.new("Folder")
root.Name, root.Parent = "GlassClashImports", workspace
local staged = {}
for _, model in workspace:GetChildren() do
	if model:IsA("Model") and wanted[model.Name] then
		for _, child in model:GetDescendants() do
			assert(not child:IsA("LuaSourceContainer"), "Unexpected import script")
		end
		model.Parent = root
		table.insert(staged, model.Name)
	end
end
return { Staged = staged }
