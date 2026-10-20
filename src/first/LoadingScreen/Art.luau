--!strict
-- Loading screen art (tools/ui/loading_art.py, uploads in assets/ui/loading/roblox_assets.json). Kept here rather than
-- in Shared.Config.UIAssets because the loading screen runs from ReplicatedFirst before ReplicatedStorage arrives.
local Art = {}

Art.Images = {
	backdrop = "rbxassetid://117138491401474",
	swing_frame = "rbxassetid://108270533709138",
	glassy_pop = "rbxassetid://129439856208608",
	glassy_jam = "rbxassetid://106895392763045",
	glassy_prism = "rbxassetid://82717297206466",
	glassy_flask = "rbxassetid://105167290325000",
	shard_a = "rbxassetid://74205091766371",
	shard_b = "rbxassetid://115868796471055",
	shard_c = "rbxassetid://139295644692089",
	burst = "rbxassetid://100951320117347",
	glow = "rbxassetid://93410086870549",
}

-- The glassies that take turns on the strings. Size = image size in svg units (the art is drawn at 1 unit = 1 px of
-- a 1920x1080 screen before Scale); HalfWidth = half the glass body, used for contact; Tint colours its shards.
Art.Glassies = {
	{ Image = "glassy_pop", Size = Vector2.new(220, 340), HalfWidth = 66, Tint = Color3.fromHex("#8FE3FF") },
	{ Image = "glassy_jam", Size = Vector2.new(240, 340), HalfWidth = 86, Tint = Color3.fromHex("#FF6B8B") },
	{ Image = "glassy_prism", Size = Vector2.new(230, 340), HalfWidth = 81, Tint = Color3.fromHex("#C9A8FF") },
	{ Image = "glassy_flask", Size = Vector2.new(230, 340), HalfWidth = 93, Tint = Color3.fromHex("#86EDB8") },
}

-- Stained Glass tokens (copied from client UI/Theme, which isn't available this early).
Art.Colors = {
	lead = Color3.fromHex("#1F1830"),
	smoke = Color3.fromHex("#261D3B"),
	smoke2 = Color3.fromHex("#332854"),
	amber = Color3.fromHex("#F5A524"),
	amberLight = Color3.fromHex("#FFD98A"),
	cream = Color3.fromHex("#FFF4D6"),
}

Art.Heading = Font.new("rbxasset://fonts/families/DenkOne.json")
Art.Body = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy)

Art.Lines = {
	"Heating the Kiln...",
	"Polishing glassies...",
	"Tying strings...",
	"Sweeping up shards...",
	"Blowing new glass...",
	"Waking the arenas...",
}

return Art
