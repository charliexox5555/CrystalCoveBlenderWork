--!strict
-- Zones / routes (GAME_DESIGN 5.2). Maps are low-poly, built mostly in Blender
-- (docs/art/ART_BIBLE.md, docs/art/MAP_PLAN.md).
--
-- WildSpawns: glassy id -> spawn weight. WildLevel: level range for wild glassies.

export type ZoneDef = {
	Id: string,
	Name: string,
	Order: number,
	Enabled: boolean,
	LevelRange: { number },
	WildLevel: { number },
	WildSpawns: { [string]: number },
	MaxWild: number,
	Badge: string?,
	Palette: string,
	Notes: string,
}

local list: { ZoneDef } = {
	{
		Id = "recycling_yard",
		Name = "Recycling Yard",
		Order = 1,
		Enabled = true,
		LevelRange = { 1, 12 },
		WildLevel = { 2, 10 },
		WildSpawns = {
			milk_bottle = 30,
			ketchup_bottle = 25,
			lemonade_bottle = 20,
			glass_cup = 15,
			pickle_jar = 12,
			water_jug = 10,
			mason_jar = 4,
			hot_sauce = 3,
			crystal_tumbler = 3,
		},
		MaxWild = 8,
		Badge = "recycling_badge",
		Palette = "Sunny greens, recycling-bin blues and warm wood",
		Notes = "Starter route. Paths between bins, crates and conveyor belts. Boss: Rusty.",
	},
	{
		Id = "sunny_beach",
		Name = "Sunny Beach",
		Order = 2,
		Enabled = false,
		LevelRange = { 10, 18 },
		WildLevel = { 10, 16 },
		WildSpawns = {},
		MaxWild = 8,
		Badge = "beach_badge",
		Palette = "Sand, turquoise water, coral pinks",
		Notes = "Update 1. Message bottles, sea glass, glass shells and crabs.",
	},
	{
		Id = "candy_factory",
		Name = "Candy Factory",
		Order = 3,
		Enabled = false,
		LevelRange = { 16, 24 },
		WildLevel = { 16, 22 },
		WildSpawns = {},
		MaxWild = 8,
		Palette = "Pastel pinks, mint, candy stripes",
		Notes = "Candy jars, lollipops, gummy bears, ice cream.",
	},
	{
		Id = "pumpkin_patch",
		Name = "Pumpkin Patch",
		Order = 4,
		Enabled = false,
		LevelRange = { 22, 28 },
		WildLevel = { 22, 27 },
		WildSpawns = {},
		MaxWild = 8,
		Palette = "Dusk purples, pumpkin orange, lantern glow",
		Notes = "Halloween 2027. Jack-o'-Glass, lanterns, ghost jars, glass bats.",
	},
	{
		Id = "wizard_tower",
		Name = "Wizard Tower",
		Order = 5,
		Enabled = false,
		LevelRange = { 26, 34 },
		WildLevel = { 26, 32 },
		WildSpawns = {},
		MaxWild = 8,
		Palette = "Deep blues, gold trim, glowing runes",
		Notes = "Potions, crystal balls, wands, glass swords.",
	},
	{
		Id = "ice_palace",
		Name = "Ice Palace",
		Order = 6,
		Enabled = false,
		LevelRange = { 32, 40 },
		WildLevel = { 32, 38 },
		WildSpawns = {},
		MaxWild = 8,
		Palette = "Ice blue, white, pale violet",
		Notes = "Snow globes, ice crowns, glass unicorns.",
	},
	{
		Id = "volcano",
		Name = "Volcano",
		Order = 7,
		Enabled = false,
		LevelRange = { 38, 46 },
		WildLevel = { 38, 44 },
		WildSpawns = {},
		MaxWild = 8,
		Palette = "Charcoal rock, lava orange, ember red",
		Notes = "Lava glass, glass dragons, phoenixes.",
	},
	{
		Id = "rainbow_sky_castle",
		Name = "Rainbow Sky Castle",
		Order = 8,
		Enabled = false,
		LevelRange = { 44, 50 },
		WildLevel = { 44, 50 },
		WildSpawns = {},
		MaxWild = 8,
		Palette = "Clouds, rainbow gradients, gold",
		Notes = "Endgame. Pegasus, rainbow unicorns, galaxy orbs. Then the Glass League.",
	},
}

local Zones = { List = list, ById = {} :: { [string]: ZoneDef } }
for _, zone in list do
	Zones.ById[zone.Id] = zone
end

return Zones
