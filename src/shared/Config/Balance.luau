--!strict
-- All tunable numbers live here. Change numbers here, not inside FightSim, MatchLogic or services.
-- After any change: run the tests and the balance simulator (see AGENTS.md).

local Balance = {}

-- Staged release signatures. Enable globally only after native kit validation.
Balance.CombatRelease = {
	Enabled = true,
	TurnMinSeconds = 0.45,
	TurnCollisionQuiet = 0.2,
	TurnRiseSpeed = 0.6,
	TurnRiseStuds = 0.35,
	TurnMinAngle = 0.35,
	SlowFloor = 0.65,
	ReflectionSeconds = 0.14,
	CounterSeconds = 4,
	MinCastSeconds = 5,
	TrackingSeconds = 0.05,
	TwistInfluence = 0.025,
	ProjectileLeadSeconds = 0.18,
	-- Optional cast (decision 85). For a side with a cast policy, a trigger makes the power Ready
	-- instead of casting: the player taps CAST, or it casts by itself after AutoSeconds.
	-- Contact-payoff kits (Pop, Pickle Jar, Ketchup, Briar Flask, Mason Jar) arm instead: the next
	-- contact within ArmedSeconds pays off. Sides without a policy (old tests, FightModel) cast at once.
	Cast = {
		Enabled = true,
		AutoSeconds = 1.6,
		ArmedSeconds = 3,
		-- "Good moment" read shared by bots, the simulators and the client hint (CastTiming).
		BraceLead = 0.55, -- guard/mirror: cast when contact is due within windup + this
		BoostLead = 1.2, -- boosts: contact due within windup + this
		ArmLead = 1.6, -- arming: contact due within this
		StrikeRangeSlack = 1.15, -- aimed: predicted distance at release within Range x this
		MinClosingSpeed = 0.8, -- studs/s; slower approaches don't count as "coming in"
		AimTolerance = 0.45, -- twist-aimed shots: allowed aim error as a share of the target's angular size
		-- Bots: reaction delay and how often they read the moment (by Skill 0..1).
		BotReactionMax = 0.75,
		BotReactionMin = 0.22,
		BotReadChanceMin = 0.35,
		BotReadChanceMax = 0.9,
		-- Simulated human for balance tools ("smart" policy).
		SmartReaction = 0.28,
	},
	Kits = {
		milk_bottle = {
			Thresholds = { 0.6, 0.3 },
			Trigger = "threshold",
			Shape = "heal",
			Heal = 0.085,
			Windup = 0.45,
			Duration = 0.35,
		},
		pickle_jar = {
			ContactBonus = 0.65,
			Trigger = "contact",
			Every = 2,
			Shape = "slow_contact",
			Slow = 0.65,
			StatusSeconds = 2.6,
			Immunity = 2.5,
			Windup = 0,
			Duration = 0.2,
		},
		ketchup_bottle = {
			Trigger = "contact",
			Every = 3,
			Shape = "mark_contact",
			MarkDamage = 0.5,
			StatusSeconds = 4,
			Windup = 0,
			Duration = 0.2,
		},
		glass_cup = {
			ContinuousBonus = true,
			Trigger = "turnaround",
			Every = 2,
			Shape = "boost",
			Drive = 1.28,
			ContactBonus = 0.58,
			Rebound = 1.15,
			Windup = 0.25,
			Duration = 2.5,
		},
		water_jug = {
			Trigger = "received",
			Every = 3,
			Shape = "cone",
			Range = 5.5,
			Radius = 0.15,
			Arc = 1.1,
			Damage = 0.322,
			Windup = 0.3,
			Duration = 0.3,
			LandChance = 0.7,
		},
		lemonade_bottle = {
			Trigger = "timer",
			First = 5,
			Interval = 7,
			Jitter = 0.8,
			Shape = "volley",
			Range = 8,
			Radius = 0.18,
			Arc = 0.5,
			Pulses = 3,
			Damage = 0.832,
			Windup = 0.35,
			Duration = 0.65,
			LandChance = 0.65,
		},
		mason_jar = {
			Trigger = "heavy",
			Threshold = 0.08,
			Every = 1,
			Shape = "armed_contact",
			ContactBonus = 0.525,
			Windup = 0,
			Duration = 4,
		},
		hot_sauce = {
			Thresholds = { 0.7, 0.4 },
			Trigger = "threshold",
			Shape = "boost",
			Drive = 1.18,
			ContactBonus = 0.91,
			ContinuousBonus = true,
			Windup = 0.25,
			Duration = 3.5,
		},
		crystal_tumbler = {
			Trigger = "timer",
			First = 4,
			Interval = 5,
			Jitter = 0.5,
			Shape = "mirror",
			Mitigation = 0.45,
			ContactBonus = 0.7,
			Range = 7,
			Radius = 0.13,
			Damage = 0.35,
			ReturnWindup = 0.25,
			Windup = 0.25,
			Duration = 1.8,
			LandChance = 0.6,
		},
		chime = {
			Trigger = "turnaround",
			Every = 2,
			Shape = "pulse",
			Range = 6,
			Radius = 0.12,
			Damage = 0.46,
			Windup = 0.25,
			Duration = 0.6,
			LandChance = 0.75,
		},
		hourglass = {
			Trigger = "turnaround",
			Every = 3,
			Shape = "heal",
			Heal = 0.09,
			HealBelow = 0.65,
			MaxCasts = 2,
			Cooldown = 8,
			Windup = 0.85,
			Duration = 0.65,
		},

		frostglobe = {
			Trigger = "timer",
			First = 5.5,
			Interval = 8,
			Jitter = 0.8,
			Shape = "cone",
			Range = 5.5,
			Radius = 0.15,
			Arc = 0.95,
			Damage = 0.406,
			Slow = 0.72,
			StatusSeconds = 1.5,
			Immunity = 2.5,
			Windup = 0.4,
			Duration = 0.35,
			LandChance = 0.65,
		},
		prism_blade = {
			Trigger = "turnaround",
			Every = 2,
			Shape = "projectile",
			Path = "return",
			Pulses = 2,
			Range = 7,
			Radius = 0.4,
			Damage = 0.702,
			Windup = 0.3,
			Duration = 1.05,
			LandChance = 0.65,
		},
		rocket_pop = {
			Trigger = "turnaround",
			Every = 3,
			Shape = "boost",
			Drive = 1.22,
			Impulse = 1.8,
			ContactBonus = 0.519,
			Rebound = 1.2,
			Windup = 0.3,
			Duration = 2.5,
		},
		glass_duck = {
			Thresholds = { 0.75, 0.5, 0.25 },
			Trigger = "threshold",
			Shape = "guard",
			Mitigation = 1,
			Windup = 0.12,
			Duration = 2.201,
		},
		comet = {
			Trigger = "contact",
			Every = 3,
			Shape = "echo_contact",
			Range = 8,
			Radius = 0.2,
			Damage = 0.47,
			StoreSeconds = 5,
			Windup = 0.25,
			Duration = 0.6,
			LandChance = 0.65,
		},
		glass_dragon = {
			Trigger = "timer",
			First = 7,
			Interval = 9,
			Jitter = 1,
			Shape = "breath",
			Range = 6,
			Radius = 0.15,
			Arc = 0.9,
			Pulses = 3,
			Damage = 0.676,
			Windup = 0.5,
			Duration = 0.5,
			LandChance = 0.7,
		},
		galaxy_orb = {
			Trigger = "timer",
			First = 8,
			Interval = 9,
			Jitter = 1,
			Shape = "orbit",
			Range = 4.2,
			Radius = 0.15,
			Force = 2.5,
			Damage = 0.57,
			Windup = 0.5,
			Duration = 1.2,
			LandChance = 0.75,
		},
		-- Seasonal Lantern Seeds: each clash plants a seed on the foe (cap MaxSeeds, all fade
		-- SeedSeconds after the newest). At MaxSeeds the next turnaround calls them home as wisps,
		-- SeedDamage each. A body hit of KnockThreshold x max HP knocks one seed loose.
		hollowlight = {
			Trigger = "contact",
			Every = 1,
			Shape = "seed_contact",
			MaxSeeds = 3,
			SeedSeconds = 6,
			SeedDamage = 0.11,
			KnockThreshold = 0.08,
			Windup = 0.35,
			Duration = 0.9,
			Radius = 0.2,
		},
		pop = {
			Trigger = "contact",
			Every = 3,
			ContactBonus = 0.887,
			Rebound = 1.35,
			Windup = 0,
			Shape = "contact",
			Duration = 0.14,
		},
		jam = { Trigger = "turnaround", Every = 2, Windup = 0.15, Shape = "guard", Duration = 1.61, Mitigation = 0.65 },
		prism = {
			Trigger = "timer",
			First = 5.5,
			Interval = 8,
			Jitter = 1,
			Windup = 0.45,
			Shape = "ray",
			Range = 8,
			Radius = 0.14,
			Damage = 0.546,
			Duration = 0.14,
			LandChance = 0.65,
		},
		crescent_axe = {
			Trigger = "turnaround",
			Every = 2,
			Windup = 0.65,
			Hold = 0.7,
			Shape = "sweep",
			Range = 4,
			Radius = 0.7,
			Arc = 1.4,
			Damage = 0.85,
			Duration = 0.5,
			LandChance = 0.6,
		},
		briar_flask = {
			Trigger = "turnaround",
			Every = 3,
			ContactBonus = 0.38,
			Windup = 0,
			Shape = "armed_contact",
			Duration = 0.14,
		},
		-- Roster V2 launch kits (decision 88, docs/design/ROSTER_V2.md). First-pass numbers; tuned with
		-- tools/release_matrix.sh before each glassy joins ReleaseRoster.
		fishbowl = {
			Trigger = "heavy",
			Threshold = 0.06,
			Shape = "projectile",
			Path = "return",
			Pulses = 2,
			Range = 6,
			Radius = 0.3,
			Damage = 1.235,
			Windup = 0.25,
			Duration = 1.0,
			LandChance = 0.65,
		},
		cookie_jar = {
			Trigger = "received",
			Every = 2,
			Shape = "volley",
			Range = 6,
			Radius = 0.16,
			Arc = 0.6,
			Pulses = 3,
			Damage = 0.76,
			Windup = 0.3,
			Duration = 0.6,
			LandChance = 0.65,
		},
		glass_top = {
			Trigger = "turnaround",
			Every = 2,
			Shape = "sweep",
			Plane = "horizontal",
			Arc = 6.28,
			Range = 2.2,
			Radius = 0.5,
			Damage = 0.934,
			Windup = 0.4,
			Hold = 0.6,
			Duration = 0.5,
			LandChance = 0.55,
		},
		bubble_wand = {
			Trigger = "timer",
			First = 5,
			Interval = 7,
			Jitter = 0.8,
			Shape = "zone",
			Look = "bubble",
			At = "self_lead",
			Lead = 0.25,
			Range = 1.2,
			Radius = 0.1,
			Damage = 0.54,
			Windup = 0.3,
			Duration = 4,
			LandChance = 0.55,
		},
		piggy_bank = {
			Trigger = "stored",
			StoreFraction = 0.6,
			StoreCap = 0.2,
			ReadyAt = 0.4,
			Shape = "volley",
			Range = 7,
			Radius = 0.16,
			Arc = 0.45,
			Pulses = 3,
			Damage = 1.001,
			Windup = 0.3,
			Duration = 0.6,
			LandChance = 0.65,
		},
		light_bulb = {
			Trigger = "contact",
			Every = 2,
			Shape = "drain_contact",
			Drain = 0.5,
			ContactBonus = 0.621,
			Windup = 0.15,
			Duration = 4,
		},
		potion_flask = {
			Trigger = "turnaround",
			Every = 3,
			Shape = "heal",
			Windup = 0.2,
			Duration = 0.35,
			Cycle = {
				{ Shape = "slow_contact", Slow = 0.75, StatusSeconds = 1.3, Immunity = 2.5 },
				{ Shape = "mark_contact", MarkDamage = 0.38, StatusSeconds = 4 },
				{ Shape = "heal", Heal = 0.05, Windup = 0.45, Duration = 0.35 },
			},
		},
		honey_bear = {
			Trigger = "turnaround",
			Every = 3,
			Shape = "zone",
			Look = "honey",
			At = "self",
			Range = 1.5,
			Radius = 0.1,
			Damage = 0.237,
			Slow = 0.78,
			StatusSeconds = 1.4,
			Immunity = 2.5,
			Windup = 0.35,
			Duration = 4,
			LandChance = 0.6,
		},
		crystal_ball = {
			Trigger = "timer",
			First = 6,
			Interval = 8,
			Jitter = 0.8,
			Shape = "zone",
			Look = "rune",
			At = "foe_predicted",
			Lead = 0.75,
			Delay = 0.45,
			Range = 1.5,
			Radius = 0.1,
			Damage = 0.38,
			Windup = 0.3,
			Duration = 0.6,
			LandChance = 0.5,
		},
		grizzly_guardian = {
			Trigger = "received",
			Every = 3,
			Shape = "guard",
			Mitigation = 0.45,
			Windup = 0.15,
			Duration = 2.358,
			Riposte = {
				Shape = "pulse",
				Range = 5,
				Radius = 0.12,
				Damage = 0.38,
				Windup = 0.1,
				Duration = 0.5,
				LandChance = 0.85,
			},
		},
		glass_unicorn = {
			Trigger = "turnaround",
			Every = 2,
			Shape = "boost",
			AimImpulse = 2.0,
			Drive = 1.12,
			ContactBonus = 0.62,
			PierceGuard = true,
			Rebound = 1.15,
			Windup = 0.35,
			Duration = 2,
		},
		glass_phoenix = {
			Trigger = "turnaround",
			Every = 3,
			Shape = "projectile",
			Range = 8,
			Radius = 0.16,
			Damage = 0.35,
			Windup = 0.3,
			Duration = 0.55,
			LandChance = 0.65,
			Rebirth = {
				Threshold = 0.3,
				Shape = "pulse",
				Range = 6,
				Radius = 0.15,
				Damage = 0.5,
				SelfHeal = 0.08,
				Windup = 0.55,
				Duration = 0.6,
				LandChance = 0.75,
			},
			Then = { Shape = "volley", Pulses = 3, Arc = 0.5, Damage = 0.5 },
		},
		-- Daily Rewards glassies (decision 115). Whiskers bats a yarn ball out and back; the first leg that lands
		-- tangles the foe (slow). Midnight sings a lullaby ring: a landed ring makes the foe Sleepy (slow) and its
		-- next clash within MarkSeconds is a wake-up bonk for MarkDamage (generic ranged Mark, FightRules).
		whiskers = {
			Trigger = "turnaround",
			Every = 2,
			Shape = "projectile",
			Path = "return",
			Pulses = 2,
			Range = 6.5,
			Radius = 0.28,
			Damage = 1.479,
			Slow = 0.75,
			StatusSeconds = 1.2,
			Immunity = 2.5,
			Windup = 0.45,
			Duration = 1.0,
			LandChance = 0.65,
		},
		midnight_moon = {
			Trigger = "timer",
			First = 6,
			Interval = 8.5,
			Jitter = 0.8,
			Shape = "pulse",
			Range = 5.5,
			Radius = 0.14,
			Damage = 0.38,
			Slow = 0.7,
			StatusSeconds = 1.6,
			Immunity = 2.5,
			MarkDamage = 0.45,
			MarkSeconds = 3.5,
			Windup = 0.5,
			Duration = 0.6,
			LandChance = 0.8,
		},
		-- Starter Pack glassy (decision 117). Sunny crows on a sunrise timer: three little suns fly out in a fan
		-- ("cock-a-doodle-doo"); each one that lands dazzles the foe (a short slow, one per round of immunity).
		sunny_rooster = {
			Trigger = "timer",
			First = 5,
			Interval = 7,
			Jitter = 0.8,
			Shape = "volley",
			Range = 6.5,
			Radius = 0.2,
			Arc = 0.55,
			Pulses = 3,
			Damage = 1.179,
			Slow = 0.8,
			StatusSeconds = 1.0,
			Immunity = 2.5,
			Windup = 0.5,
			Duration = 0.7,
			LandChance = 0.65,
		},
		arc_coil = {
			Trigger = "contact",
			Every = 3,
			Windup = 0.35,
			Shape = "ray",
			Range = 12,
			Radius = 0.18,
			Damage = 0.45,
			Duration = 0.14,
			LandChance = 0.65,
		},
	},
}

Balance.CombatVFX = {
	-- Presentation only; no charge cadence, damage or attack volumes change.
	-- Hollowlight Lantern Seeds: seeds orbit the seeded foe, wisps arc home to the pumpkin.
	-- Sizes and distances are fractions of the foe's displayed body width.
	LanternSeeds = {
		SeedColor = "#FFB347",
		GlowColor = "#9CFFD8",
		SeedSize = 0.17,
		ShellScale = 1.8,
		OrbitGap = 0.2,
		OrbitHz = 0.45,
		OrbitTilt = 0.45,
		Bob = 0.05,
		PopInSeconds = 0.18,
		FlareScale = 1.7,
		WispSize = 0.2,
		WispSeconds = 0.38,
		WispArc = 0.9,
		TrailSeconds = 0.22,
		FaceGlowSeconds = 0.3,
		-- v2 premium layers (docs/vfx/HOLLOWLIGHT_PREMIUM.md section 4); presentation only.
		SeedTrailSeconds = 0.28,
		FlameColor = "#9CFFD8",
		FlameScale = 0.55, -- mint flame flicker on top of each seed (x seed size)
		FlameHz = 9,
		RipeHz = 2.2, -- three seeds pulse together
		RipeGlow = 0.28,
		RipeSpin = 1.7, -- orbit speed multiplier once ripe
		GhostSize = 0.42, -- homing ghost height (x foe width)
		BlossomScale = 1.5, -- star blossom where a seed leaves (x foe width)
		BlossomSeconds = 0.32,
		ReadyWisps = 2, -- small wisps orbiting Hollowlight while its bloom is Ready
		ReadyOrbit = 0.8, -- x own width
		ReadyHz = 0.8,
		ReadyFlickerHz = 8, -- candle flicker of the pumpkin face
		ReadyLight = 1.4,
		ReadyLightRange = 9,
		ReadyColor = "#FFB347",
		CastGhosts = 6, -- ghost puff ring on a manual cast
		CastRadius = 1.9, -- x own width
		CastSeconds = 0.6,
	},
	ImpactRingSeconds = 0.28,
	ImpactRingStart = 0.7,
	ImpactRingEnd = 2.8,
	ImpactRingNormalEnd = 1.8,
	ImpactChipCount = 7,
	ChargeBurstScale = 1.6,
	WindupPulseHz = 3,
	WindupRingGrowth = 1.8,
	RayHaloScale = 4.5,
	RayHaloTransparency = 0.45,
	RayReadSeconds = 0.55,
	RayRingCount = 3,
	RayRingSize = 1.4,
	HeroRecoilSeconds = 0.55,
	HeroRecoilAngle = 0.24,
	PopCapLift = 1.1,
	PopWaveSize = 8,
	WeaponReadTail = 0.18,
	WeaponHeadColor = "#42A8DC",
	WeaponHandleColor = "#334469",
	ShieldRevealSeconds = 0.25,
	ShieldStandOff = 0.6,
	ShieldFacingBias = 0.35,
	WeaponWindupRange = 2,
	WeaponTrailSeconds = 0.16,
	ClockTicks = 12,
	ClockSize = 3.5,
	HealColor = "#65F5B0",
	ImpactSeconds = 0.36,
	ImpactStreaks = 8,
	ImpactStreakLength = 1.25,
	ImpactSpread = 2.4,
	FastSwingSpeed = 8,
	SwingTrailSeconds = 0.12,
	HealthWidth = 104,
	HealthHeight = 28,
	HealthGap = 0.45,
	HealthTextSize = 23,
	HealthStroke = 2,
	HealthPulseScale = 1.18,
	HealthPulseSeconds = 0.18,
	LowHealthFraction = 0.25,
	StatusTransparency = 0.4,
	StatusScale = 0.65,
	ConeTransparency = 0.6,
	ConeMotes = 6,
	ConeMoteSize = 0.42,
	ShotHaloScale = 2.6,
	AccentSeconds = 0.42,
	AccentChips = 6,
	AccentSize = 0.45,
	AccentTravel = 2.4,
	AccentSpin = 6,
	AccentRingSize = 3.4,
	ColorSaturation = 0.6,
	ColorValue = 0.9,
	ConeSheetScale = 0.7,
	ReadyGlowThreshold = 0.65,
	DetailPulse = 0.08,
	OrbitSpeed = 2.4,
	StressInterval = 2,
	FlameScale = 0.6,
	FlameColor = "#FFC96B",
	Tail = 0.25,
	ChargeDim = 0.78,
	ChargeLit = 0.1,
	GuardCameraBias = 0.65,
	GuardTransparency = 0.3,
	ChargeRingScale = 0.5,
	PressureRingScale = 1.8,
	ContactScale = 0.75,
	MaxShardsPerGlassy = 20,
}

-- Free retention plumbing only; existing economy/fight/content values are unchanged.
Balance.Retention = {
	TickSeconds = 1,
	AutoOpenWaitSeconds = 90, -- Daily Rewards opens by itself within this long after joining (decision 115)...
	AutoOpenQuietSeconds = 1.5, -- ...once the lobby has been quiet (no match, queue, results or menu) this long
	SnapshotSeconds = 5,
	ClaimRateSeconds = 0.5,
	CodeRateSeconds = 1,
	MaxTickSeconds = 5,
	LeaderboardPublishSeconds = 60,
	LeaderboardReadSeconds = 120,
	LeaderboardRows = 10,
}

-- First session (decision 100, docs/design/ONBOARDING.md). Presentation and one assisted match; nothing here
-- changes normal matches.
Balance.Onboarding = {
	WelcomeRarities = { "Common", "Uncommon", "Rare" }, -- one each, one of each type when possible, never owned
	WinPullOdds = { Rare = 0.7, Epic = 0.3 }, -- the free Kiln open for winning the first match, never owned
	BotName = "Rookie Bot",
	BotSkill = 0.1,
	RollSeconds = 40, -- longer card pick in the first match
	CastSeconds = 4, -- longer CAST window for the new player in the first match
	BotRound = 2, -- the round the bot takes (the player wins the match 3-1)
	-- Damage taken multipliers in the assisted match. The planned round winner can't drop below 1 HP, so every
	-- round lands as planned; overtime still ends it.
	WinnerTaken = 0.7,
	LoserTaken = 1.35,
	ReserveSeconds = 240, -- how long an arena stays reserved for the new player
	PlayHintSeconds = 20, -- after this long without reaching the arena, PLAY pulses
	-- Keep it going (client watcher): standing still with nothing open for this long brings the next step back
	-- (Daily Rewards re-opens, PLAY pulses on the Arena step and right after the tutorial), so nobody sits idle.
	IdleNudgeSeconds = 6,
	KeepCheckSeconds = 0.5, -- how often the watcher looks
	ClaimRetrySeconds = 5, -- OPEN sent but no opening came back: the card is offered again
	ClaimPreloadSeconds = 2, -- the claim card waits at most this long for its Kiln to load (decision 111 tiers)
	DoneNudgeSeconds = 180, -- for this long after the win prize, an idle player sees PLAY pulse (until a match starts)
	DailyCloseSeconds = 1.6, -- the tutorial daily screen closes this long after the claim
	ActionRateSeconds = 0.5,
}

Balance.Data = {
	Version = 2,
	-- v3: fresh start for release (creator, 2026-10-22). v2 (playtest data) is left untouched, so it can be read back
	-- if ever needed. Leaderboard ordered stores use the same prefix, so they start empty too.
	StoreName = "GlassClash_v3",
	StudioStoreName = "GlassClash_Studio_v3",
	StudioMock = true, -- protects live progress during automated Studio tests
	LoadTimeout = 60,
	ReleaseGrace = 0.25,
	RecentMatches = 32,
	RequestRateSeconds = 0.5,
	KilnRateSeconds = 0.75,
	KilnQuoteSeconds = 60,
	DaySeconds = 86400,
}

-- Player levels (LevelRules, decision 104). XP per finished match; bot matches give half; a forfeit gives none.
-- XP from level L to L + 1 = BaseXp + StepXp * (L - 1): Lv 2 after ~2 matches, Lv 5 in the first session,
-- Lv 10 after ~40 matches, then a slow climb with no cap. No level rewards yet.
Balance.Levels = {
	WinXp = 100,
	LossXp = 40,
	RoundWonXp = 10, -- per round won
	PerfectXp = 15, -- per Perfect release
	BotScale = 0.5, -- matches against a bot
	BaseXp = 100,
	StepXp = 70, -- EconomySim: Lv 10 after ~42 matches (40 min/day, 50% wins, 40% bots, 1 Perfect)
	ViewRateSeconds = 1, -- RequestPlayerProfile (another player's read-only profile)
	ViewCacheSeconds = 60, -- offline profiles read from the store are reused this long
	ViewReadReserve = 40, -- offline profile reads stop while the server's GetAsync budget is this low (profile loads first)
}

-- Sky lobby recovery; no combat or economy tuning.
Balance.Lobby = {
	FallY = -40,
	FallCheckSeconds = 0.1,
	RescueHeight = 4,
	BusyPadColor = "#78809A", -- pad glow while a match is on
	BusyPadTransparency = 0.7,
	WaitingPadTransparency = 0.55, -- someone is waiting here; the other, bright pad is the free one
}

-- Swing motion (GAME_DESIGN 3.1). STARTING VALUES for the client/server swing code that Codex
-- builds and tunes in Studio. Units are studs and seconds. The motion code reports each hit
-- (approach speed + who moved into it) to FightRules, and reads FightRules.swingMultiplier /
-- isFrozen / knockbackMultiplier to apply powers to the swing.
Balance.Motion = {
	StepRate = 60,
	Substeps = 3,
	MaxCatchupSeconds = 0.25,
	DriveGain = 1.4,
	PhaseCoupling = 2.5, -- weak reciprocal pull keeps both swings meeting after a deflection
	PhaseDamping = 0.8,
	DriveAcceleration = 24,
	AirDrag = 0.04,
	MaxAngle = 1.4,
	BodyCenter = 1.1, -- unscaled distance from hang point to collision centre
	PowerLandDistance = 13.5,
	PowerTwistInfluence = 0.12,
	PowerTrackingSeconds = 0.2, -- aim at the last sighting; fast pass-bys can escape the cone
	PowerLandCos = 0.5, -- 120 degree cone
	EncounterDistance = 7,
	EncounterCooldown = 0.4,
	NearMissDistance = 2,
	TumbleStiffness = 24,
	MaxTilt = 0.35, -- keep glancing pass-bys readable; large tilts hid the collision gap
	-- At true scale glassies (~2.5 studs) look tiny under the 17-stud stand (all 4 map concepts),
	-- so arenas show them GlassyScale times bigger, with longer strings and wider hooks to match.
	-- The swing uses Glassy.Radius * GlassyScale. The stand model's hooks sit at +-1.5 today;
	-- move them to +-HookGap/2 in Studio (DECISIONS 30).
	GlassyScale = 1.75,
	Gravity = 88, -- "game gravity": with StringLength 7 one full swing takes ~1.8 s (decision 122)
	StringLength = 7,
	HookGap = 6, -- distance between the two hooks on the crossbar
	MassByType = { Heavy = 1.3, Fizzy = 1.0, Sharp = 0.85 },
	Restitution = 0.7,
	AmplitudeBase = 0.78, -- radians the glassy keeps swinging to, at Swing 0
	AmplitudePerSwing = 0.006,
	AmplitudeMax = 1.25,
	FrozenDamping = 2.2, -- extra drag while frozen (and no self-driving)
	MinHitSpeed = 3, -- approach speed (studs/s) below which a bump does no damage
	HitCooldown = 0.15, -- seconds before the pair can hit again
	-- 3D, erratic swing (GAME_DESIGN 3.1, DECISIONS 34). Each glassy is a spherical pendulum:
	-- it can swing out of the stand's plane, pass the other glass and come back. All starting
	-- values; tune by eye so fights are unpredictable but readable.
	OutOfPlaneDamping = 0.9, -- how fast sideways swing settles back toward the stand's plane (lower = wilder)
	WanderStrength = 0.3, -- random sideways nudges (rad/s^2) that keep swings from repeating
	WanderIntervalMin = 0.6, -- seconds between nudges
	WanderIntervalMax = 1.8,
	HitFriction = 0.35, -- how much of a glancing hit turns into spin
	HitDeflect = 0.18, -- how much a hit off the line between them throws the glass sideways
	SpinFromHit = 2.5, -- spin (rad/s) per stud/s of glancing hit speed
	TwistStiffness = 4, -- the string winds up and unwinds (spring back toward no twist)
	TwistDamping = 0.6,
	MaxSpin = 18, -- rad/s cap on spin around the string
	TumbleFromHit = 0.04, -- body tilt (rad) per stud/s of hit speed; wobbles back to hanging straight
	TumbleDamping = 3,
	-- Aim (GAME_DESIGN 3.2): pull-back angle in radians (with the Perfect Release band) plus a
	-- sideways yaw, so players choose how far back and which way to pull.
	AimMin = 0.35,
	AimMax = 1.25,
	AimYawMax = 0.6, -- radians either side of straight at the other glass
	AimDefault = 0.8, -- used if a player doesn't aim in time
	SweetSpotWidth = 0.14, -- half-width of the band
	BotAimErrorMax = 0.45, -- bot aim error = BotAimErrorMax * (1 - skill) * random(-1, 1)
}

-- Fight rules (GAME_DESIGN 3.3-3.6). Used by FightRules; pure numbers, no motion.
Balance.Fight = {
	RefSpeed = 20, -- approach speed that counts as a "normal" hit
	SpeedExponent = 1.4, -- damage ~ (speed / RefSpeed) ^ SpeedExponent; >1 makes big swings smash
	SpeedFactorMax = 2.5,
	DamageScale = 0.29, -- damage per Power at RefSpeed (decision 122: ~18 s rounds)
	ShareBase = 0.6, -- the glassy that moved more into the hit deals more: ShareBase + ShareWeight * share
	ShareWeight = 0.8,
	MassExponent = 0.1, -- heavier glass hits harder: (2 m / (m + m_other)) ^ MassExponent
	VarianceMin = 0.6,
	VarianceMax = 1.4,
	CritBase = 0.08,
	CritPerSwing = 0.004,
	CritMax = 0.3,
	CritMultiplier = 2.0,
	PerfectFirstHitMult = 2.0, -- the first hit after a Perfect Release
	-- Special powers FIRE BY THEMSELVES (no button, DECISIONS 33). Placeholder formula: the first
	-- fires after a random wait, then repeats after another random wait, up to PowerMaxPerRound;
	-- every hit (dealt or taken) brings the next one closer. Luck decides whether it lands well.
	PowerFirstMin = 5,
	PowerFirstMax = 14,
	PowerRepeatMin = 9,
	PowerRepeatMax = 18,
	PowerHitAdvance = 0.5, -- seconds closer per hit
	PowerMaxPerRound = 3,
	PerfectPowerAdvance = 3, -- a Perfect Release makes the first power come 3 s sooner
	-- Round end. Overtime is the Heat's MELTDOWN (decision 122): damage climbs every second after it.
	OvertimeAt = 15, -- seconds
	OvertimePerSecond = 0.08, -- +8% damage per second of meltdown
	RoundTimeout = 40, -- winner = higher HP fraction
}

-- The arena layer of a round (decision 122, docs/design/ROUND_REVAMP.md): glints both glassies race for,
-- the Heat, one arena twist per round, PUSH and Last Glass. Rules in ArenaRules; the swing places glints
-- and applies the motion. Distances are studs in the stand frame (origin between the hooks, Y up).
Balance.Arena = {
	Glints = {
		FirstAt = 2, -- seconds after the release
		IntervalMin = 2.5, -- seconds between spawns
		IntervalMax = 4,
		Lifetime = 3.5, -- a glint nobody touches fades
		MaxLive = 2,
		Radius = 0.8, -- the gem; a glassy grabs it when their surfaces touch
		SpreadX = 2.2, -- how far either side of the middle a glint can sit
		SpreadZ = 1.4, -- in front of / behind the stand's plane
		Lift = 0.4, -- above the middle of the two swing spheres
		-- Stand-in simulator only (no positions): chance a glint gets grabbed, after this many seconds.
		SimGrabChance = 0.75,
		SimGrabSeconds = 1.2,
		Kinds = {
			Smash = { Weight = 1.2, DamageMult = 1.8 }, -- your next hit
			Bubble = { Weight = 1 }, -- blocks the next damage you would take
			Patch = { Weight = 0.8, Heal = 0.1 }, -- of max HP
			Bomb = { Weight = 1, Fuse = 1.2, Damage = 0.08 }, -- sticks to the other glass; max HP fraction
			Frost = { Weight = 0.8, Seconds = 1.5, SwingMult = 0.55 }, -- the other glass swings low
			Zoom = { Weight = 1, Speed = 9 }, -- a big shove for your glassy (studs/s)
		},
	},
	Heat = {
		WarmAt = 8, -- "HEATING UP!": glints come faster
		WarmIntervalMult = 0.6,
		-- MELTDOWN at Fight.OvertimeAt: the glass glows and swings a little higher
		MeltdownSwingMult = 1.12,
	},
	Push = {
		Charges = 3,
		RechargeSeconds = 4, -- one charge comes back every this many seconds
		Cooldown = 0.6, -- between two pushes
		Speed = 6, -- studs/s added along the swing
		MinSpeed = 1.5, -- slower than this, the push goes toward the other glass instead
		-- Bots (and simulator sides) push with their cast skill: they check every BrainSeconds.
		BrainSeconds = 0.25,
		BotApproachMin = 3.5, -- push while closing in from this far...
		BotApproachMax = 8, -- ...to this far
		BotGlintReach = 3, -- or when a glint is this close ahead
	},
	LastGlass = { "Smash", "Bubble" }, -- a player on their last heart starts the round holding one
	OnFireStreak = 2, -- round wins in a row that light the string (cosmetic)
	Twists = {
		-- One per round, rolled at the countdown and never the same twice in a row.
		Calm = { Weight = 0.8 },
		Windy = { Weight = 1, Force = 14, GustSeconds = 1.2, IntervalMin = 2.2, IntervalMax = 3.5 },
		Bouncy = { Weight = 1, Restitution = 0.92, Knockback = 1.25 },
		Magnet = { Weight = 1, Force = 9, Range = 12 },
		GlintRain = { Weight = 1, IntervalMult = 0.5, MaxLive = 3 },
		Bumpers = {
			Weight = 1,
			Radius = 0.75,
			Restitution = 0.95,
			Boost = 2.5, -- studs/s added away from the post
			Cooldown = 0.25,
			-- Crystal posts: one behind each glassy's backswing, one in front of and behind the clash.
			Posts = {
				{ -8.6, -6.6, 0 },
				{ 8.6, -6.6, 0 },
				{ -4.5, -7.6, 3.8 },
				{ 4.5, -7.6, 3.8 },
				{ -4.5, -7.6, -3.8 },
				{ 4.5, -7.6, -3.8 },
			},
		},
	},
}

-- BALANCE SIMULATOR ONLY. A stand-in for the real swing: one exchange of hits every
-- ~HitInterval seconds. Once the swing is built in Studio, measure the real hit rate and
-- approach speeds (FightService can log them) and update these so the simulator stays honest.
Balance.SimModel = {
	HitInterval = 1.3, -- seconds between encounters (measured 1.24-1.40 s on the real swing)
	HitIntervalJitter = 0.25,
	SpeedAtAmplitude = 27, -- approach speed when both swing at amplitude 1 rad
	SpeedSpread = 0.67, -- hits range from (1 - spread) to (1 + spread) of the typical speed
	ShareSpread = 0.245, -- who moved more into the hit varies this much either way
	MissChance = 0.367, -- flat pass-by share (used only if MissAtRadius is nil)
	MissAtRadius = 0.6, -- pass-by share when the two collision radii sum to 1 stud
	MissPerRadius = 0.38, -- bigger glassies collide more often: minus this per extra stud of radius
	MissSlowExponent = 2, -- slowed swings (Sticky, Freeze) hang close and rarely pass by
	FrozenSwing = 0.25, -- a frozen glassy swings at this fraction
}

-- Types (GAME_DESIGN 3.5): Heavy beats Sharp, Sharp beats Fizzy, Fizzy beats Heavy
Balance.Types = {
	Strong = 1.04,
	Weak = 0.96,
	Beats = {
		Heavy = "Sharp",
		Sharp = "Fizzy",
		Fizzy = "Heavy",
	},
}

-- Rarities (GAME_DESIGN 4.2). CrateWeight = percent chance in the Kiln (coin gacha).
-- Starter is unused since decision 102 (Pop, Jam and Prism are Commons). Decision 86: rarity is a small edge (~55% Mythic vs Common at
-- equal skill). StatMultiplier applies to HP only (Formula.stats), because Power is ~20 and
-- rounds to whole numbers, so a few percent on Power would jump in 5% steps.
Balance.Rarities = {
	Common = { Order = 1, StatMultiplier = 1.00, CrateWeight = 56.25 },
	Uncommon = { Order = 2, StatMultiplier = 1.01, CrateWeight = 22 },
	Rare = { Order = 3, StatMultiplier = 1.015, CrateWeight = 14 },
	Epic = { Order = 4, StatMultiplier = 1.02, CrateWeight = 6 },
	Legendary = { Order = 5, StatMultiplier = 1.025, CrateWeight = 1.5 },
	Mythic = { Order = 6, StatMultiplier = 1.03, CrateWeight = 0.25 },
	Starter = { Order = 0, StatMultiplier = 1.01, CrateWeight = 0 },
}

-- Stars from duplicates (GAME_DESIGN 4.3). Every duplicate from a crate adds a star.
Balance.Growth = {
	StatPerStar = 0.006, -- HP only; 5 stars = +3% HP (decision 86)
	MaxStars = 5,
	DuplicatesPerStar = 1,
	DuplicateCoinsAtMaxStars = 50, -- duplicates past max stars turn into coins
	RainbowChance = 1 / 500,
	RainbowBonus = 0.02, -- HP only
}

-- Matches (GAME_DESIGN 2). 1v1, each player has 3 hearts; losing a round costs a heart.
Balance.Match = {
	QueueCheckSeconds = 0.2,
	QueuePromptDistance = 10, -- studs; the ProximityPrompt on each queue pad
	QueuePromptRateSeconds = 0.5,
	LeaveRateSeconds = 0.25,
	RequestRateSeconds = 0.5,
	Hearts = 3,
	RollChoices = 3, -- glassies offered from your collection each round
	-- Decision 122 (shortens decision 64): round 1 picks from a fresh hand, later rounds keep last pick by default.
	RollSeconds = 12, -- time to pick; auto-picks last round's glassy (or the first offer) when it runs out
	RollSecondsLater = 8,
	FreeRerollsPerMatch = 0,
	RerollMarbleCosts = { 3, 3, 6, 6, 9 }, -- per match; the last value repeats
	FreePickAnyPerMatch = 1,
	PickAnyMarbleCosts = { 6, 9, 12 }, -- after the free pick; the last value repeats
	RerollReserveSeconds = 2.6, -- don't charge when the reveal cannot finish before selection closes
	AimSeconds = 10, -- starts from last round's aim
	CountdownSeconds = 3, -- long enough to read the twist banner
	RoundEndSeconds = 4.5, -- the finisher (rise, flight, impact, show) still fits
	QueueBotAfterSeconds = 30, -- an empty arena slot fills with a bot after this long
	BotSkillMin = 0.2,
	BotSkillMax = 0.7,
	-- Remote rate limits (seconds between accepted calls per player)
	PickRateSeconds = 0.25,
	CastRateSeconds = 0.15, -- CastPower (decision 85)
	PushRateSeconds = 0.15, -- Push (decision 122); ArenaRules also enforces Arena.Push.Cooldown
	RerollRateSeconds = 0.5,
	PickAnyRateSeconds = 0.5,
	AimRateSeconds = 0.05,
	Rewards = {
		-- DECISIONS 84 (Proposed): a match win always pays MatchWinCoins, bots included. A loss pays
		-- for performance: LossBaseCoins + LossHeartCoins per heart taken (round won) +
		-- LossChipCoins per glassy's worth of chip damage in rounds you lost (fights are close, so
		-- chip is weighted lightly) + LossPerfectCoins per Perfect Release, capped at LossMaxCoins.
		-- Quitting (reset or Leave mid-match) pays the quitter 0.
		MatchWinCoins = 100,
		LossBaseCoins = 8,
		LossHeartCoins = 10,
		LossChipCoins = 5,
		LossPerfectCoins = 2,
		LossMaxCoins = 40,
		WinTrophies = 20,
		LossTrophies = 8, -- subtracted, never below 0
		BotWinTrophies = 5, -- bots never take trophies
	},
}

-- Economy (GAME_DESIGN 8, docs/design/ECONOMY.md). Coins are earned by playing; Marbles are the
-- premium currency (Robux packs plus small free amounts). Run `lune run tools/economy_sim`
-- after changing anything here.
Balance.Economy = {
	-- The Kiln: coin gacha for glassies. Odds (Rarities.CrateWeight) shown before every pull.
	KilnCoinCost = 300,
	KilnTenPullCost = 2700, -- 10 for the price of 9
	-- Free coin sources
	DailyQuestCoins = 75, -- per quest, 3 quests a day
	DailyQuests = 3,
	-- Playtime gifts (decisions 99, 115): time adds up over the UTC day, and each gift collects itself when its time
	-- is reached (a small toast, no claim). Xp goes through LevelRules (decision 104). A gift with RotatingPull also
	-- gives one free pull ticket, rotating by UTC day through the listed crate categories (spent in the Shop, odds
	-- shown first).
	PlaytimeGifts = {
		{ Minutes = 10, Coins = 75 },
		{ Minutes = 20, Coins = 100 },
		{ Minutes = 30, Coins = 125 },
		{ Minutes = 45, Coins = 0, Xp = 200 },
		{ Minutes = 60, Coins = 150, RotatingPull = { "Glassies", "Finishers", "Rideables" } },
	},
	-- Daily Rewards calendar (decisions 99, 115): one claim per UTC day, a missed day keeps your place, then repeats.
	-- Pull = a free pull ticket for that crate category. Item = a Daily-only glassy (Day 2 Epic Whiskers, Day 7
	-- Legendary Midnight); a repeat week gives another copy (+1 star, like a Kiln duplicate) until it is at max stars,
	-- then WhenMaxed instead (coins and the item are replaced, not added).
	DailyRewards = {
		{ Coins = 100 },
		{ Coins = 100, Item = { Category = "Glassies", Id = "whiskers" }, WhenMaxed = { Coins = 200 } },
		{ Coins = 100 },
		{ Coins = 150 },
		{ Coins = 100, Pull = "Glassies" },
		{ Coins = 150 },
		{
			Coins = 300,
			Item = { Category = "Glassies", Id = "midnight_moon" },
			WhenMaxed = { Coins = 300, Pull = "Glassies" },
		},
	},
	FirstWinOfDayCoins = 100,
	WelcomeKilnPulls = 1, -- free pull right after a new player's first match
	GroupJoinMarbles = 20, -- one time, for joining the group
	-- Marble packs and Robux offers live in Config/MarbleShop and Config/Offers (decision 116).
}

-- ECONOMY SIMULATOR ONLY: how a typical player plays. Compare with real analytics after launch.
Balance.EconomyModel = {
	SessionMinutes = 40, -- one session a day
	Days = 30,
	WinRate = 0.5,
	BotMatchShare = 0.4, -- fraction of matches against bots (high at launch, lower later)
	RoundSecondsEstimate = 18, -- average fight length; tools/pacing_report prints the real one (decision 122)
	SecondsBetweenMatches = 25, -- results screen, walking to a pad, queue
	QuestsCompletedPerDay = 0, -- quests are hidden until their redesign (decision 99); was 2
	LossChipPerRound = 0.8, -- average share of the winner's HP a loser chips off (FightModel ~0.82)
	PerfectsPerMatch = 1,
	Players = 2000,
}

-- Presentation only (client). The fight itself uses Balance.Fight.
Balance.Feel = {
	SpectatorDistance = 120,
	ArenaBoardHeight = 4.8, -- studs above the crossbar
	ArenaBoardWidth = 11, -- studs
	ArenaBoardMaxDistance = 75, -- boards only draw when you are about close enough to walk over and join
	AimDragPixels = 170,
	AimYawPixels = 180,
	StickAimSeconds = 1.2, -- controller / keys: full pull range in this long at full tilt
	StickYawSeconds = 1.0, -- controller / keys: centre to full sideways aim
	StickDeadzone = 0.2,
	CameraDistance = 33,
	CameraHeight = 0,
	CameraSide = 0,
	OccludedLegTransparency = 0.72,
	CameraFollow = 0,
	CameraSmooth = 8,
	OrbitDragRadians = math.pi * 2,
	OrbitKeyRadiansPerSecond = 1.6,
	OrbitSmooth = 12,
	OrbitStickDeadzone = 0.18,
	BigHitSpeed = 1.15, -- multiple of RefSpeed
	PowerEffectSeconds = 0.65,
	PopupSeconds = 0.9,
	CountdownPulseScale = 1.18,
	CountdownPulseSeconds = 0.22,
	ClinkVolumeMin = 0.2,
	ClinkVolumeMax = 0.55,
	CrackVolume = 0.13,
	PowerEdgeSeconds = 0.4,
	PromptDistance = 20,
	PrototypePlayerId = "pop",
	PrototypeBotId = "prism",
	SnapshotBuffer = 100,
	DepthAngle = 0.16,
	BodyTwist = 0.12,
	CrackWidth = 0.014,
	CameraFocusOffset = -0.25,
	CameraFocusHeight = 3,
	CameraMinimumAspect = 1.6,
	CameraFieldOfView = 52,
	IdleAngle = 0.05,
	IdleSpeed = 1.6,
	SnapshotRate = 20, -- fight snapshots sent per second; clients interpolate between them
	InterpolationDelay = 0.1, -- seconds clients render behind the newest snapshot
	HitstopSeconds = 0.08,
	PowerImpactHoldSeconds = 0.045,
	PowerImpactShake = 0.65,
	SlowMotionRate = 0.3,
	SlowMotionSeconds = 1,
	ShardSeconds = 3,
	MaxShards = 150,
	HitSparkles = 14,
	HitFlashSize = 0.25,
	HitFlashSeconds = 0.18,
	ShardSpeed = 13,
	ShardSpin = 12,
	ShardBounce = 0.45,
	ShardDensity = 0.4,
	ShardFriction = 0.3,
	Sparkles = 45,
	CrackThresholds = { 0.75, 0.5, 0.25 },
	ShakeSeconds = 0.22,
	ShakeMax = 0.25,
	HapticSeconds = 0.08,
	OwnerTagSize = 3.2, -- studs; "YOU" marker over the local player's glassy
	OwnerTagHeight = 0.9,
	RoundBannerFallbackSeconds = 1.6, -- show the round result even if the shatter was never rendered
	SettleDamping = 0.7, -- the survivor swings down to rest after the shatter (client-only)
	VictoryGlints = 26,
	FarSwingSpeed = 3.2, -- distant fights (no snapshots) show a cheap stand-in swing
	FarSwingAngle = 0.42, -- radians either side of FarSwingCenter
	FarSwingCenter = -0.16, -- negative = pulled back; the peak stops just short of contact
	WatchPromptDistance = 18, -- studs from a pen's centre to offer "Watch"
	WatchRejoinSeconds = 60, -- safety only: a watch gives up if the next round hasn't started this long after the last
	WatchHidesSelf = true, -- while watching, your own avatar is hidden too (only the two fighters stay in the shot)
	-- Bystander fights (not yours, not watched) update less often when far or off screen; the time they skip is
	-- carried into the next update, so motion and events stay on time. Presentation only.
	BystanderHalfRateDistance = 55, -- studs from the camera beyond which an on-screen bystander fight renders every 2nd frame
	BystanderOffscreenEvery = 4, -- an off-screen bystander fight renders every Nth frame
	BystanderCullRadius = 14, -- studs around a stand that must be off screen to count as off screen
	PadRootHeight = 3,
	FinisherPause = 0.55,
	FinisherRiseSeconds = 0.55,
	FinisherCameraResetSeconds = 0.35,
	FinisherCameraDistanceScale = 0.82,
	FinisherCameraTargetHeight = 2,
	FinisherCameraHoldSeconds = 0.3,
	FinisherCameraReturnSeconds = 0.55,
	FinisherFlySeconds = 0.65,
	FinisherRiseHeight = 3,
	FinisherImpactSeconds = 0.5,
	FinisherFallbackSeconds = 3.1,
	FinisherKickStuds = 0.35,
	FinisherKickSeconds = 0.3,
	HeartTweenSeconds = 0.4,
}

Balance.CosmeticPresentation = {
	RideLift = 4.0, -- riders float well above the pad (creator, 2026-10-19; was 2.2)
	RideBob = 0.16,
	RideBobHz = 1.1,
	RideBank = 0.035,
	RideWingAngle = 0.16,
	RideExhaustSpeed = 22,
	RideDistance = 120,
	RideEmitterDistance = 70, -- exhaust particles only run for rides this close to the camera
	RideCullRadius = 9, -- studs around a ride (flyer + rider) that must be off screen before its frame is skipped
	RideHalfRateDistance = 45, -- rides farther than this from the camera animate every 2nd frame
	RideNod = 0.03, -- nose pitch (radians) following the bob
	RideFlapSharpness = 0.6, -- 0 = sine flap, 1 = quick down-stroke, slow recovery
	RideSwingAngle = 0.22, -- lantern pendulum swing (radians)
	RideSwingLag = 0.9, -- lantern lags the bob by this phase (radians)
	RideSpinSpeed = 1.2, -- radians/second for RideMotion=Spin parts (tail star)
	RidePulseHz = 0.9, -- RideMotion=Pulse parts (hover halo) breathe at this rate
	RidePulseScale = 0.08,
	RidePulseFade = 0.25,
	RideLightFlicker = 0.18, -- lantern light brightness wobble (fraction)
	FinisherSeconds = 1.2,
	FinisherParts = 12,
	FinisherRadius = 7,
	FinisherCoreSize = 5,
	FinisherHoldSeconds = 0.8,
	FinisherFadeSeconds = 0.28,
	-- Lantern Eclipse v2, seconds from the burst (docs/vfx/HOLLOWLIGHT_PREMIUM.md section 3):
	-- ignite -> gather (GatherAt) -> eclipse + moon shadow + grade (EclipseAt) -> hush (HushAt) -> release -> embers.
	Eclipse = {
		GatherAt = 0.3,
		EclipseAt = 1.0,
		HushAt = 1.55,
		ReleaseAt = 1.7,
		Duration = 3.2,
		LanternHeight = 4.2,
		LanternScale = 1.9,
		PopSeconds = 0.32,
		Ghosts = 5, -- the choir; low detail keeps LowGhosts
		LowGhosts = 2,
		GhostScale = 1.5,
		GhostStartRadius = 11,
		GhostStartHeight = 6,
		GhostOrbitRadius = 3.4,
		GhostTightRadius = 2.5,
		GhostSpin = 5,
		GhostTremble = 0.1,
		GhostScatter = 9,
		GhostRise = 7,
		ChoirHz = 1.8, -- the singing wave travels round the ring this fast
		ChoirBob = 0.32, -- studs
		ChoirMouth = 0.55, -- face stretch while singing
		CoreColor = "#FFB347", -- the lantern's glow core stays hot under the moon
		CoreSize = 0.8,
		CoreGrow = 0.9, -- extra size by the end of the gather
		CoreLight = 1.6, -- PointLight brightness while the core burns
		SwirlRate = 26, -- gather embers per second, sucked into the lantern
		SwirlRadius = 4.5,
		HaloScale = 1.7,
		HaloReleaseScale = 3.4,
		MoonScale = 1.2,
		MoonStartOffset = 9,
		MoonGatherOffset = 2.6,
		MoonTowardCamera = 1.4,
		MoonRise = 5,
		MoonColor = "#F4EBC8",
		RimColor = "#DDA84D",
		ShadowRadius = 10, -- moon shadow disc sweeping the floor under the lantern
		ShadowTravel = 18,
		ShadowColor = "#120826",
		ShadowTransparency = 0.3, -- the core disc; two softer rings fake a soft edge (tuned in Play, Oct 19)
		Grade = { -- viewed fight and bundle preview only; restored on destroy
			Tint = "#C8C0FF",
			Brightness = -0.12,
			Contrast = 0.12,
			Saturation = -0.18,
			InSeconds = 0.35,
			OutSeconds = 0.8,
			FlashTint = "#FFE2BC",
			FlashBrightness = 0.12,
			FlashSeconds = 0.3,
		},
		FlashSize = 6.5,
		FlashSeconds = 0.16,
		ShockRadius = 16,
		ShockSeconds = 0.55,
		ShardSpeed = 11,
		ShardLift = 6,
		ShardGravity = 20,
		ShardSpin = 9,
		ShardColor = "#FF8A2B",
		ShardGlowColor = "#FFC067",
		ShardScale = 0.85,
		Embers = 34, -- falling embers on release (low detail: halved like the kit)
		EmberColor = "#FFB347",
		EmberHot = "#FFE7A6",
		EmberCool = "#D9531E",
		Stars = 8,
		StarSpeed = 13,
		GlintAt = 2.75, -- the last sparkle before the clean exit
		LightRange = 16,
		LightBrightness = 3,
		LightColor = "#FFB45C",
	},
	-- Moonlantern Carriage extras (Presentation/CarriageFX), on top of the RideMotion pass.
	Carriage = {
		TipLag = 0.55, -- wing tips trail the wing beat by this phase (radians)
		TipFlex = 0.32, -- extra tip bend (radians) at full stroke
		FlameHz = 7,
		FlameFlicker = 0.18,
		CoreHz = 1.4,
		CorePulse = 0.25,
		TwinkleHz = 2.3,
		TakeOffSeconds = 0.9,
		TakeOffLift = 2.4, -- studs it rises from on take-off
		LandSeconds = 0.6,
		LoopFadeSeconds = 0.6,
		DustBurst = 28,
		WispBurst = 8,
	},
}

-- Creator-approved provisional cosmetic crate prices; every item stays in both pools.
Balance.Crates = {
	Prices = {
		Finishers = { Coins = 300, Marbles = 30 },
		Rideables = { Coins = 1000, Marbles = 100 },
		Glassies = { Coins = Balance.Economy.KilnCoinCost, Marbles = 30 },
	},
	CoinWeights = { Common = 60, Uncommon = 25, Rare = 10, Epic = 4, Legendary = 1 },
	MarbleWeights = { Common = 25, Uncommon = 30, Rare = 25, Epic = 15, Legendary = 5, Mythic = 1 },
}

return Balance
