-- Edit only. Recoverable permanent art/display bundle; source animation stays in Rojo.
assert(not game:GetService("RunService"):IsRunning(), "Export in Edit")
local bundle = Instance.new("Folder")
bundle.Name = "GlassClash_RoundHeroes_v2"
local assets = Instance.new("Folder")
assets.Name, assets.Parent = "Assets", bundle
for _, name in { "Rideables", "RoundFinishers" } do
	game.ReplicatedStorage.Assets[name]:Clone().Parent = assets
end
game.ReplicatedStorage.Assets.VFX.RoundHeroV2:Clone().Parent = assets
workspace.Lobby.NightPolishV1:Clone().Parent = bundle
game.ServerStorage.RoundHeroesBeforeV2:Clone().Parent = bundle
for _, item in bundle:GetDescendants() do
	assert(not item:IsA("LuaSourceContainer"), "No scripts in art snapshot")
end
local bytes = game:GetService("SerializationService"):SerializeInstancesAsync({ bundle })
local count = #bundle:GetDescendants()
bundle:Destroy()
_G.RoundHeroExport = buffer.tostring(game:GetService("EncodingService"):Base64Encode(bytes))
return { Bytes = buffer.len(bytes), Base64Length = #_G.RoundHeroExport, Descendants = count }
