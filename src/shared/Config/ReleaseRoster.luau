--!strict
-- Fixed creator-approved release manifest. Dormant definitions and ownership are preserved.
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
}
local byId: { [string]: boolean } = {}
for _, id in ids do
	byId[id] = true
end
return { Ids = ids, ById = byId }
