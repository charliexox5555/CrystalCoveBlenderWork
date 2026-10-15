-- Returns a base64 RBXM snapshot of the editable templates and billboard.
-- Decode the returned text to places/UI_v05.rbxm; this does not publish the place.
assert(not game:GetService("RunService"):IsRunning(), "Export in Edit mode")
local bundle = Instance.new("Folder")
bundle.Name = "GlassClash_UI_v05"
local screens = Instance.new("Folder")
screens.Name, screens.Parent = "StarterGuiTemplates", bundle
for _, gui in game.StarterGui:GetChildren() do
	if gui:IsA("ScreenGui") then
		gui:Clone().Parent = screens
	end
end
game.ReplicatedStorage.Assets.UI.FightBillboard:Clone().Parent = bundle
local bytes = game:GetService("SerializationService"):SerializeInstancesAsync({ bundle })
bundle:Destroy()
return buffer.tostring(game:GetService("EncodingService"):Base64Encode(bytes))
