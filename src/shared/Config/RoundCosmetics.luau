-- Original cosmetic collection. Match milestones are free; no combat stats or purchases.
-- Equipped "" = none: no flyer, and the basic finisher (the winner's glass breaks, no show).
local C = {}
C.Rideables = {
	{
		Id = "skyboard",
		Name = "Skyboard",
		-- No free starter flyer (decision 95): a Common crate item.
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
	-- Launch flyers (Cosmetics V2; models by workstream F). In crate pools once installed (KilnService gate).
	{
		Id = "paper_jet",
		Name = "Paper Jet",
		Rarity = "Common",
		Color = "#F4F8FF",
		Accent = "#FFD84D",
		Description = "A giant folded paper plane made of frosted glass, trailing crease streamers.",
	},
	{
		Id = "bubble_pod",
		Name = "Bubble Pod",
		Rarity = "Uncommon",
		Color = "#E9DDFF",
		Accent = "#80E8DA",
		Description = "Ride inside a giant soap bubble with a wake of popping bubbles.",
	},
	{
		Id = "honey_hover",
		Name = "Honey Hover",
		Rarity = "Uncommon",
		Color = "#FFB92E",
		Accent = "#FFF1C9",
		Description = "A floating glass honeycomb with two little glass bees on patrol.",
	},
	{
		Id = "dragonfly",
		Name = "Dragonfly",
		Rarity = "Rare",
		Color = "#2FD0B5",
		Accent = "#F5D99A",
		Description = "A glass dragonfly bike with four shimmering wings.",
	},
	{
		Id = "carousel",
		Name = "Carousel",
		Rarity = "Epic",
		Color = "#FFD6F5",
		Accent = "#7CE7D5",
		Description = "A merry-go-round pony that flew off the ride, canopy, lights and all.",
	},
	{
		Id = "sunwing",
		Name = "Sunwing",
		Rarity = "Legendary",
		Color = "#FF7A2E",
		Accent = "#FFD34E",
		Description = "A blazing glass phoenix with ember-veined wings and a sunfire trail.",
	},
	{
		Id = "starwhale",
		Name = "Starwhale",
		Rarity = "Mythic",
		Color = "#2B2A7A",
		Accent = "#FFE9A8",
		Description = "A galaxy whale swimming through the sky, spouting stars.",
	},
}
C.Finishers = {
	{
		Id = "glass_burst",
		Name = "Prism Pop",
		-- Not a free starter any more (decision 95): a Common crate item. Default = plain glass break.
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
	-- Launch finishers (docs/design/COSMETICS_V2.md §4.2): crate/store only (no Matches field). Each joins the
	-- crate pools only once Assets.RoundFinishers.<id> is installed (KilnService's `available` gate).
	{
		Id = "frost_pop",
		Name = "Frost Pop",
		Rarity = "Common",
		Color = "#BFEFFF",
		Accent = "#7FB8FF",
		CameraHoldSeconds = 0.9,
		CameraPush = 0.76,
		Description = "An ice cube freezes around your foe, cracks, and bursts into spinning glass snowflakes.",
	},
	{
		Id = "gumball",
		Name = "Gumball",
		Rarity = "Uncommon",
		Color = "#FF5A4E",
		Accent = "#FFD34E",
		CameraHoldSeconds = 1.1,
		CameraPush = 0.74,
		Description = "A gumball machine drops over your foe, the crank turns, and glass gumballs bounce everywhere.",
	},
	{
		Id = "honeyburst",
		Name = "Honeyburst",
		Rarity = "Uncommon",
		Color = "#FFB92E",
		Accent = "#FFF1C9",
		CameraHoldSeconds = 1.1,
		CameraPush = 0.74,
		Description = "Golden honeycomb builds around your foe, glass bees buzz in, and it all pops into honey sparkles.",
	},
	{
		Id = "hocus_pop",
		Name = "Hocus Pop",
		Rarity = "Rare",
		Color = "#6CFF9A",
		Accent = "#FF7AC8",
		CameraHoldSeconds = 1.4,
		CameraPush = 0.72,
		CameraOrbit = 0.1,
		Description = "A potion tips over your foe, magic smoke swirls, and a crowned glass frog hops out.",
	},
	{
		Id = "petalstorm",
		Name = "Petalstorm",
		Rarity = "Rare",
		Color = "#FF8FB8",
		Accent = "#FFD84D",
		CameraHoldSeconds = 1.4,
		CameraPush = 0.7,
		CameraOrbit = 0.12,
		Description = "Glass flowers sprout around your foe, bloom all at once, and spin into a petal storm.",
	},
	{
		Id = "starmane",
		Name = "Starmane",
		Rarity = "Epic",
		Color = "#FFD6F5",
		Accent = "#FFE07A",
		CameraHoldSeconds = 1.6,
		CameraPush = 0.8,
		CameraOrbit = -0.1,
		Description = "A glass unicorn gallops in on a rainbow, rears up, and its horn fires a column that rains stars and hearts.",
	},
	{
		Id = "emberwing",
		Name = "Emberwing",
		Rarity = "Mythic",
		Color = "#FF7A2E",
		Accent = "#FFD34E",
		CameraHoldSeconds = 2.3,
		CameraPush = 0.68,
		CameraOrbit = 0.2,
		KickAt = 0.7, -- the dive (second peak), seconds after impact
		Description = "A sunfire phoenix circles your foe, dives, and a column of sunfire glass erupts as feathers of light fall.",
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
			Description = "Ride a glass crescent moon with flexing bat wings, wisp engines, a trail of moon dust and a swinging pumpkin lantern.",
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
			CameraHoldSeconds = 2.6,
			KickAt = 1.7,
			CameraPush = 0.68, -- slow push in through the gather and eclipse
			CameraOrbit = 0.3, -- and a gentle drift round the lantern (skipped with reduced motion)
			Description = "A choir of ghosts gathers round a pumpkin lantern, a glass moon's shadow sweeps the arena, and the lantern bursts into glowing glass and falling embers.",
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
-- Nothing equipped by default (decision 95): no flyer, and the basic finisher is the plain glass break.
function C.default(category)
	return ""
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
