-- Private relaunch slice values (docs/design/RELAUNCH_PLAN.md). Production services never require this config.
return {
	Roster = { "pop", "jam", "prism", "glass_cup", "water_jug", "ketchup_bottle" },
	Starter = "pop",
	FirstRival = "glass_cup",
	Library = "GlassiesV5",
	Names = {
		pop = "Pop",
		jam = "Jam",
		prism = "Prism",
		glass_cup = "Cup",
		water_jug = "Jug",
		ketchup_bottle = "Ketchup",
	},
	Powers = {
		pop = "Every third hit BURSTS",
		jam = "Lid shield blocks a smash",
		prism = "Fires a glass BEAM",
		glass_cup = "Dashes at top speed",
		water_jug = "Water BLAST",
		ketchup_bottle = "Splats the rival",
	},
	Icons = {
		pop = "rbxassetid://115018504914088",
		jam = "rbxassetid://123620539639960",
		prism = "rbxassetid://97420566544408",
		glass_cup = "rbxassetid://90109336711669",
		water_jug = "rbxassetid://94776176653773",
		ketchup_bottle = "rbxassetid://122483878573856",
	},
	Fill = {
		pop = "#1E7BFF",
		jam = "#FF8A1F",
		prism = "#8B4DFF",
		glass_cup = "#6FE01F",
		water_jug = "#10CFC0",
		ketchup_bottle = "#F2212F",
	},
	-- Same triangle as GAME_DESIGN 3.4: Heavy > Sharp > Fizzy > Heavy.
	Types = {
		pop = "Fizzy",
		jam = "Heavy",
		prism = "Sharp",
		glass_cup = "Sharp",
		water_jug = "Heavy",
		ketchup_bottle = "Fizzy",
	},
	Beats = { Heavy = "Sharp", Sharp = "Fizzy", Fizzy = "Heavy" },
	-- Contact radius follows the rounder v5 silhouettes, so glass meets glass instead of overlapping.
	Radius = {
		pop = 1.02,
		jam = 1.36,
		prism = 1.16,
		glass_cup = 0.98,
		water_jug = 1.4,
		ketchup_bottle = 0.96,
	},
	Hearts = 3,
	ShardsNeeded = { 2, 3, 3, 4, 5 }, -- shards to unlock the next glassy; the first unlock lands fast
	BossEvery = 5,
	BossShards = 2,
	PlayerHp = 0.6,
	FirstDuelHp = 0.3, -- the very first rival breaks fast: first shatter well inside the first minute
	RivalHp = 0.5,
	RivalHpPerRung = 0.035,
	RivalHpMax = 1.05,
	BossHp = 1.3,
	CounterHp = 0.78, -- bringing the type that beats this rival makes it visibly easier
	CoinsPerWin = 10,
	CoinsPerRung = 2,
	HookGap = 7.5,
	AimSeconds = 12,
	BeatSeconds = 1.7, -- shatter beat before the next rival swings in
	UnlockSeconds = 2.2, -- extra beat when the win unlocks a new glassy
	RateSeconds = 0.15,
	Step = 1 / 60,
	SnapshotSeconds = 1 / 20,
	Seed = 311102,
}
