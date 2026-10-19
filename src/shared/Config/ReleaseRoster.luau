--!strict
-- Creator-approved release manifest (24 + 12 launch glassies, decisions 58 and 88). Dormant definitions and ownership are preserved.
local ids = {
	"pop",
	"jam",
	"prism",
	"crescent_axe",
	"briar_flask",
	"arc_coil",
	"milk_bottle",
	"pickle_jar",
	"ketchup_bottle",
	"glass_cup",
	"water_jug",
	"lemonade_bottle",
	"mason_jar",
	"hot_sauce",
	"crystal_tumbler",
	"chime",
	"hourglass",
	"frostglobe",
	"prism_blade",
	"rocket_pop",
	"glass_duck",
	"comet",
	"glass_dragon",
	"galaxy_orb",
	-- Roster V2 launch glassies (decision 88), installed at v4 on Oct 19.
	"fishbowl",
	"cookie_jar",
	"glass_top",
	"bubble_wand",
	"piggy_bank",
	"light_bulb",
	"potion_flask",
	"honey_bear",
	"crystal_ball",
	"grizzly_guardian",
	"glass_unicorn",
	"glass_phoenix",
}
local byId: { [string]: boolean } = {}
for _, id in ids do
	byId[id] = true
end
return { Ids = ids, ById = byId }
