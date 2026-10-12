--!strict
-- All tunable numbers live here. Change numbers here, not inside Formula or services.
-- After any change: run the tests and the balance simulator (see AGENTS.md).

local Balance = {}

-- Power meter (GAME_DESIGN 3.3). Zones are symmetric around the centre of the bar (0.5):
-- Weak | Good | Great | PERFECT | Great | Good | Weak. Widths are fractions of the whole bar.
Balance.Meter = {
	SweepTime = 1.1, -- seconds for the needle to cross the bar once; it ping-pongs
	MaxHoldTime = 1.5, -- auto-release as Weak after this many seconds
	LatencyAllowance = 0.15, -- seconds the server will trust an earlier client release time
	PerfectWidth = 0.06,
	PerfectWidthFromSwing = 0.06, -- extra Perfect width at SwingForMaxPerfect
	SwingForMaxPerfect = 120,
	GreatWidth = 0.15, -- total, split either side of Perfect
	GoodWidth = 0.40, -- total, split either side of Great
	Multipliers = {
		Weak = 0.7,
		Good = 1.0,
		Great = 1.15,
		Perfect = 1.3,
	},
}

-- Damage (GAME_DESIGN 3.4)
Balance.Damage = {
	VarianceMin = 0.75,
	VarianceMax = 1.25,
	CritBase = 0.05,
	CritPerSwing = 0.0025,
	CritMax = 0.30,
	CritMultiplier = 1.5,
}

-- Types (GAME_DESIGN 3.5): Heavy beats Sharp, Sharp beats Fizzy, Fizzy beats Heavy
Balance.Types = {
	Strong = 1.1,
	Weak = 0.92,
	Beats = {
		Heavy = "Sharp",
		Sharp = "Fizzy",
		Fizzy = "Heavy",
	},
}

-- Rarities (GAME_DESIGN 4.2). CrateWeight values are percentages for the coin crate.
-- Starters are not in crates; their multiplier (plus x1.2 per evolution) keeps them viable all game.
-- Fight strength scales with Power x HP, i.e. roughly with StatMultiplier squared, so keep the spread modest.
Balance.Rarities = {
	Common = { Order = 1, StatMultiplier = 1.00, CrateWeight = 60, CatchRate = 0.9 },
	Uncommon = { Order = 2, StatMultiplier = 1.08, CrateWeight = 25, CatchRate = 0.7 },
	Rare = { Order = 3, StatMultiplier = 1.16, CrateWeight = 10, CatchRate = 0.45 },
	Epic = { Order = 4, StatMultiplier = 1.26, CrateWeight = 4, CatchRate = 0.25 },
	Legendary = { Order = 5, StatMultiplier = 1.38, CrateWeight = 0.9, CatchRate = 0.1 },
	Mythic = { Order = 6, StatMultiplier = 1.52, CrateWeight = 0.1, CatchRate = 0.03 },
	Starter = { Order = 0, StatMultiplier = 1.15, CrateWeight = 0, CatchRate = 0 },
}

-- Growth (GAME_DESIGN 4.3)
Balance.Growth = {
	MaxLevel = 50,
	StatPerLevel = 0.04,
	StatPerStar = 0.10,
	MaxStars = 5,
	DuplicatesPerStar = 3,
	RainbowChance = 1 / 500,
	RainbowBonus = 0.05,
	EvolutionBonus = 1.2, -- evolved forms already have this baked into their Base stats
}

-- XP. Target: first evolution (level 15) in ~30 minutes, second (35) within a few hours.
Balance.Xp = {
	ToNextBase = 20,
	ToNextPerLevel = 10,
	WinBase = 25,
	WinPerOpponentLevel = 4,
	LossFraction = 0.3,
}

-- Catching wild glassies (GAME_DESIGN 5.4)
Balance.Catch = {
	HpFloor = 0.15,
	MaxChance = 0.95,
	Corks = {
		Basic = 1.0,
		Golden = 1.5,
	},
}

-- NPC timing skill (0..1) -> chance of each meter zone
Balance.Npc = {
	PerfectBase = 0.05,
	PerfectPerSkill = 0.35,
	GreatBase = 0.15,
	GreatPerSkill = 0.25,
	GoodBase = 0.50,
	GoodPerSkill = -0.30,
}

-- Coins
Balance.Rewards = {
	TrainerCoinsBase = 20,
	TrainerCoinsPerLevel = 4,
	RematchFraction = 0.25,
	BossCoins = 250,
	WildCoinsBase = 8,
	PickWinnerCoins = 40,
	Tournament = {
		Winner = 500,
		RunnerUp = 250,
		Semifinal = 100,
		Entry = 25,
	},
}

-- Lobby tournaments (GAME_DESIGN 6)
Balance.Tournament = {
	IntervalSeconds = 480,
	CountdownSeconds = 60,
	Slots = 8,
	RookieLevel = 10,
}

-- Battle pacing (GAME_DESIGN 3.2)
Balance.Battle = {
	MaxClashes = 30, -- safety cap; a battle that reaches it is a draw
	PullBackSeconds = 1.5,
	SwingSeconds = 0.5,
	BounceSeconds = 0.8,
	StartLeadSeconds = 0.35,
	ClashLeadSeconds = 0.15,
	ReleaseRateSeconds = 0.08,
	PromptRateSeconds = 2,
	PromptDistance = 12,
	PollSeconds = 0.03,
	ResultSeconds = 3.5,
}

-- Presentation and the temporary M1 matchup; no persistence/rewards yet.
Balance.Prototype = { PlayerId = "pop", OpponentId = "jam", Level = 10, NpcSkill = 0.35 }
Balance.Feel = {
	StringLength = 5,
	PullAngle = 0.8,
	ContactAngle = 0.11,
	BounceAngle = 0.35,
	HitstopSeconds = 0.08,
	SlowMotionRate = 0.3,
	SlowMotionSeconds = 1,
	ShardSeconds = 3,
	MaxShards = 150,
	ShardSpeed = 13,
	ShardSpin = 12,
	Sparkles = 45,
	CrackThresholds = { 0.75, 0.5, 0.25 },
	ShakeSeconds = 0.22,
	ShakeMax = 0.25,
	HapticSeconds = 0.08,
}

return Balance
