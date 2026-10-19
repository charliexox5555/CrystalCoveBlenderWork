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
		Name = "Prism Pop",
		Matches = 0,
		Color = "#7EDFF2",
		Accent = "#FFFFFF",
		-- Camera during the show (FinisherCamera): hold after impact, push-in scale, drift (radians).
		CameraHoldSeconds = 0.9,
		CameraPush = 0.76,
		Description = "A crystal shell snaps shut around your foe and pops into rainbow glass.",
	},
	{
		Id = "party_burst",
		Name = "Piñata Pop",
		Matches = 1,
		Color = "#F9ADDA",
		Accent = "#FFE790",
		-- Camera during the show (FinisherCamera): hold after impact, push-in scale, drift (radians).
		CameraHoldSeconds = 1.1,
		CameraPush = 0.74,
		Description = "A stained-glass piñata drops in, wiggles, and bursts into confetti and candy gems.",
	},
	{
		Id = "bubble_bloom",
		Name = "Fizz Bloom",
		Matches = 3,
		Color = "#80E8DA",
		Accent = "#A9BBFF",
		-- Camera during the show (FinisherCamera): hold after impact, push-in scale, drift (radians).
		CameraHoldSeconds = 1.4,
		CameraPush = 0.72,
		CameraOrbit = 0.12,
		Description = "A giant fizzy bubble swells, pops, and blooms into a bouquet of bubbles that pop in a chain.",
	},
	{
		Id = "brick_boom",
		Name = "Ka-Block",
		Matches = 5,
		Color = "#FFAE62",
		Accent = "#FFF2A0",
		-- Camera during the show (FinisherCamera): hold after impact, push-in scale, drift (radians).
		CameraHoldSeconds = 1.6,
		CameraPush = 0.78,
		CameraOrbit = -0.1,
		Description = "Glass toy blocks stack into a tower, go KA-BLOCK!, and bounce down spelling BOOM.",
	},
	{
		Id = "starfall",
		Name = "Supernova",
		Matches = 10,
		Color = "#A995FF",
		Accent = "#FFAFE9",
		-- Camera during the show (FinisherCamera): hold after impact, push-in scale, drift (radians).
		CameraHoldSeconds = 1.7,
		CameraPush = 0.7,
		CameraOrbit = 0.16,
		Description = "Stars spiral into a glass star core, everything goes quiet, then it explodes into a rainbow supernova.",
	},
}
-- Seasonal entries are inspectable/equippable but never members of the ordinary crate pools above.
-- The Hollowlight pumpkin is a standalone seasonal glassy (Config/Glassies), not a skin.
C.Seasonal = {
	Rideables = {
		{
			Id = "lantern_skiff", -- id kept so existing ownership carries over to the v4 carriage
			Name = "Moonlantern Carriage",
			Rarity = "Legendary",
			AssetBundle = "Hollowlight",
			AssetName = "moonlantern_carriage",
			Seasonal = true,
			Description = "Ride a glass crescent moon with bat wings, wisp engines and a swinging pumpkin lantern.",
		},
	},
	Finishers = {
		{
			Id = "lantern_eclipse",
			Name = "Lantern Eclipse",
			Rarity = "Legendary",
			Color = "#63EFBC",
			Accent = "#FFAA55",
			AssetBundle = "Hollowlight",
			AssetName = "lantern_eclipse",
			Seasonal = true,
			-- Longer show: the camera holds on it and kicks on the release beat (seconds after impact).
			CameraHoldSeconds = 1.6,
			KickAt = 0.85,
			Description = "Ghosts gather round a pumpkin lantern, a glass moon eclipses it, and it bursts into glowing shards.",
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
for _, category in { "Rideables", "Finishers" } do
	local map = {}
	for _, def in C.catalog(category) do
		def.Rarity = def.Rarity or rarities[def.Id]
		map[def.Id] = def
	end
	C.ByCategory[category] = map
end
return C
