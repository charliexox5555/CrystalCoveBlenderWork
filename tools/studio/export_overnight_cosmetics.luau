-- Edit only. Recoverable native scene/art/UI bundle; no publishing or source-script copies.
-- Read _G.GlassClashNightExport.Current in <=32,000-character chunks through MCP, decode to RBXM.
assert(not game:GetService("RunService"):IsRunning(), "Export in Edit")
local bundle = Instance.new("Folder")
bundle.Name = "GlassClash_OvernightCosmetics_v1"
workspace.Lobby:Clone().Parent = bundle
local lighting = Instance.new("Folder")
lighting.Name, lighting.Parent = "Lighting", bundle
for _, key in { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient" } do
	lighting:SetAttribute(key, game.Lighting[key])
end
for _, v in game.Lighting:GetChildren() do
	v:Clone().Parent = lighting
end
task.wait()
local assets = Instance.new("Folder")
assets.Name, assets.Parent = "Assets", bundle
for _, name in { "Rideables", "RoundFinishers" } do
	game.ReplicatedStorage.Assets[name]:Clone().Parent = assets
end
local templates = Instance.new("Folder")
templates.Name, templates.Parent = "StarterGuiTemplates", bundle
for _, name in { "CollectionScreen", "KilnScreen" } do
	game.StarterGui[name]:Clone().Parent = templates
	task.wait()
end
for _, p in bundle:GetDescendants() do
	assert(not p:IsA("LuaSourceContainer"), "Native snapshot unexpectedly contains scripts")
end
local bytes = game:GetService("SerializationService"):SerializeInstancesAsync({ bundle })
bundle:Destroy()
_G.GlassClashNightExport = _G.GlassClashNightExport or {}
_G.GlassClashNightExport.Current = buffer.tostring(game:GetService("EncodingService"):Base64Encode(bytes))
return { Bytes = buffer.len(bytes), Base64Length = #_G.GlassClashNightExport.Current }
