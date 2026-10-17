-- Original cosmetic collection. Match milestones are free; no combat stats or purchases.
local C = {}
C.Rideables = {
	{
		Id = "skyboard",
		Name = "Skyboard",
		Matches = 0,
		Color = "#61D4DF",
		Accent = "#F5D99A",
		Description = "A carved skyboard with glowing lift fins.",
	},
	{
		Id = "cloud_cushion",
		Name = "Cloud Cushion",
		Matches = 1,
		Color = "#E2ECFF",
		Accent = "#A9A0EA",
		Description = "A soft little cloud with a rainbow wake.",
	},
	{
		Id = "rocket_skiff",
		Name = "Rocket Skiff",
		Matches = 5,
		Color = "#EF8268",
		Accent = "#FFE39A",
		Description = "Twin engines and a cheerful flickering exhaust.",
	},
	{
		Id = "prism_ray",
		Name = "Prism Ray",
		Matches = 10,
		Color = "#B8A4F4",
		Accent = "#7CE7D5",
		Description = "A friendly crystal ray that flaps its broad wings.",
	},
}
C.Finishers = {
	{
		Id = "glass_burst",
		Name = "Crystal Pop",
		Sound = "ShatterScatter",
		Matches = 0,
		Color = "#7EDFF2",
		Accent = "#FFFFFF",
		Description = "A bright crystal shockwave and tumbling toy shards.",
	},
	{
		Id = "party_burst",
		Name = "Party Pop",
		Sound = "BubblePop",
		Matches = 1,
		Color = "#F9ADDA",
		Accent = "#FFE790",
		Description = "A shower of spinning, colorful confetti.",
	},
	{
		Id = "bubble_bloom",
		Name = "Bubble Bloom",
		Sound = "WaterSlap",
		Matches = 3,
		Color = "#80E8DA",
		Accent = "#A9BBFF",
		Description = "Big iridescent bubbles swell, float and pop.",
	},
	{
		Id = "brick_boom",
		Name = "Block Boom",
		Sound = "ClinkHeavy",
		Matches = 5,
		Color = "#FFAE62",
		Accent = "#FFF2A0",
		Description = "A toy explosion throws chunky blocks through a golden shockwave.",
	},
	{
		Id = "starfall",
		Name = "Pocket Nova",
		Sound = "ChargeGlass",
		Matches = 10,
		Color = "#A995FF",
		Accent = "#FFAFE9",
		Description = "Orbiting stars collapse into a tiny colorful supernova.",
	},
}
C.Skins = {}
-- Seasonal entries are inspectable/equippable but never members of the ordinary crate pools above.
C.Seasonal = {
	Skins = {
		{
			Id = "hollowlight",
			Name = "Hollowlight Pop",
			BaseGlassy = "pop",
			Rarity = "Legendary",
			AssetBundle = "Hollowlight",
			AssetName = "pop_hollowlight",
			Seasonal = true,
			Description = "A friendly pumpkin lantern look for Pop. Same stats and pressure power.",
		},
	},
	Rideables = {
		{
			Id = "lantern_skiff",
			Name = "Lantern Skiff",
			Rarity = "Legendary",
			AssetBundle = "Hollowlight",
			AssetName = "lantern_skiff",
			Seasonal = true,
			Description = "A moon-skiff with fluttering wings and mint lantern engines.",
		},
	},
	Finishers = {
		{
			Id = "lantern_eclipse",
			Name = "Lantern Eclipse",
			Rarity = "Legendary",
			Sound = "ChargeGlass",
			Color = "#63EFBC",
			Accent = "#FFAA55",
			AssetBundle = "Hollowlight",
			AssetName = "lantern_eclipse",
			Seasonal = true,
			Description = "Friendly ghost wisps gather, then burst through a glowing lantern eclipse.",
		},
	},
}
function C.catalog(category)
	local out = {}
	for _, def in C[category] or {} do
		table.insert(out, def)
	end
	for _, def in C.Seasonal[category] or {} do
		table.insert(out, def)
	end
	return out
end
function C.default(category)
	return C[category] and C[category][1] and C[category][1].Id or ""
end
local rarities = {
	skyboard = "Common",
	cloud_cushion = "Uncommon",
	rocket_skiff = "Rare",
	prism_ray = "Epic",
	glass_burst = "Common",
	party_burst = "Uncommon",
	bubble_bloom = "Rare",
	brick_boom = "Epic",
	starfall = "Legendary",
}
C.ByCategory = {}
for _, category in { "Rideables", "Finishers", "Skins" } do
	local map = {}
	for _, def in C.catalog(category) do
		def.Rarity = def.Rarity or rarities[def.Id]
		map[def.Id] = def
	end
	C.ByCategory[category] = map
end
return C
