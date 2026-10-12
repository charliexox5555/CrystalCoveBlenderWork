--!strict
-- NPC trainers (GAME_DESIGN 5.3). Skill 0..1 = how often they hit Great/Perfect.
-- They are standard R15 NPCs dressed with HumanoidDescription; no Blender rigging needed.
--
-- Bosses carry a Team and send out the glassy that matches the challenger's type, so the
-- fight is about level and timing, not which starter you picked. Use Trainers.glassyFor().

export type TrainerDef = {
	Id: string,
	Name: string,
	Zone: string,
	Order: number,
	Glassy: string,
	Level: number,
	Skill: number,
	IsBoss: boolean,
	Badge: string?,
	Team: { Heavy: string, Fizzy: string, Sharp: string }?,
	Intro: string,
	WinLine: string,
	LoseLine: string,
}

local list: { TrainerDef } = {
	{
		Id = "kevin",
		Name = "Kevin",
		Zone = "recycling_yard",
		Order = 1,
		Glassy = "milk_bottle",
		Level = 2,
		Skill = 0.15,
		IsBoss = false,
		Intro = "First time on the stand? Me too! Let's clink!",
		WinLine = "Ha! My milk bottle is undefeated! (Once.)",
		LoseLine = "Aww, spilled milk. Good swing!",
	},
	{
		Id = "sam",
		Name = "Sam",
		Zone = "recycling_yard",
		Order = 2,
		Glassy = "glass_cup",
		Level = 4,
		Skill = 0.2,
		IsBoss = false,
		Intro = "I sort the glass around here. Let's see if you crack.",
		WinLine = "Sorted!",
		LoseLine = "Into the recycling it goes...",
	},
	{
		Id = "cora",
		Name = "Cora",
		Zone = "recycling_yard",
		Order = 3,
		Glassy = "lemonade_bottle",
		Level = 5,
		Skill = 0.25,
		IsBoss = false,
		Intro = "When life gives you lemons, swing them!",
		WinLine = "Zesty win!",
		LoseLine = "That was a sour one.",
	},
	{
		Id = "jo",
		Name = "Jo",
		Zone = "recycling_yard",
		Order = 4,
		Glassy = "pickle_jar",
		Level = 7,
		Skill = 0.3,
		IsBoss = false,
		Intro = "My pickle jar has never lost a lid. Never!",
		WinLine = "Still tight!",
		LoseLine = "You got me in a pickle.",
	},
	{
		Id = "bo",
		Name = "Bo",
		Zone = "recycling_yard",
		Order = 5,
		Glassy = "water_jug",
		Level = 9,
		Skill = 0.35,
		IsBoss = false,
		Intro = "Rusty's up ahead. You'll have to get past my jug first.",
		WinLine = "Splash down!",
		LoseLine = "Go on then. Rusty's waiting.",
	},
	{
		Id = "rusty",
		Name = "Rusty, the Shelf Champion",
		Zone = "recycling_yard",
		Order = 6,
		Glassy = "mason_jar",
		Level = 14,
		Skill = 0.6,
		IsBoss = true,
		Badge = "recycling_badge",
		Team = { Heavy = "mason_jar", Fizzy = "hot_sauce", Sharp = "crystal_tumbler" },
		Intro = "Nobody leaves the Yard without beating my Mason Jar.",
		WinLine = "Come back when your glass is tougher.",
		LoseLine = "Well swung. The Yard Badge is yours!",
	},
}

local Trainers = { List = list, ById = {} :: { [string]: TrainerDef } }
for _, trainer in list do
	Trainers.ById[trainer.Id] = trainer
end

-- The glassy this trainer sends out against a challenger of the given type.
function Trainers.glassyFor(trainer: TrainerDef, challengerType: string): string
	if trainer.Team then
		return (trainer.Team :: any)[challengerType] or trainer.Glassy
	end
	return trainer.Glassy
end

return Trainers
