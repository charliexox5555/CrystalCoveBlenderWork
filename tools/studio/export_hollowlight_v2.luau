-- Edit only. Native recovery bundle; runtime modules remain in Rojo.
assert(not game:GetService("RunService"):IsRunning(), "Export in Edit")
local bundle = Instance.new("Folder")
bundle.Name = "GlassClash_Hollowlight_v2"
game.ReplicatedStorage.Assets.Seasonal.Hollowlight:Clone().Parent = bundle
game.ServerStorage.HollowlightBeforeV2:Clone().Parent = bundle
for _, obj in bundle:GetDescendants() do
	assert(not obj:IsA("LuaSourceContainer"), "Art snapshot must be script-free")
end
local count = #bundle:GetDescendants()
local bytes = game:GetService("SerializationService"):SerializeInstancesAsync({ bundle })
local restored = game:GetService("SerializationService"):DeserializeInstancesAsync(bytes)
assert(#restored[1]:GetDescendants() == count, "Native round-trip mismatch")
for _, obj in restored do
	obj:Destroy()
end
bundle:Destroy()
_G.HollowlightExport = buffer.tostring(game:GetService("EncodingService"):Base64Encode(bytes))
return { Bytes = buffer.len(bytes), Descendants = count, Base64Length = #_G.HollowlightExport, RoundTrip = true }
