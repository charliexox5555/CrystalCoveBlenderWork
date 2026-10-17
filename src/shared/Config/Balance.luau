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
	Kits = {
		milk_bottle = {
			Trigger = "threshold",
			Threshold = 0.5,
			Shape = "heal",
			Heal = 0.12,
			Windup = 0.45,
			Duration = 0.35,
		},
		pickle_jar = {
			Trigger = "contact",
			Every = 3,
			Shape = "slow_contact",
			Slow = 0.75,
			StatusSeconds = 1.7,
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
			Trigger = "turnaround",
			Every = 2,
			Shape = "boost",
			Drive = 1.16,
			ContactBonus = 0.22,
			Rebound = 1.15,
			Windup = 0.25,
			Duration = 2.5,
		},
		water_jug = {
			Trigger = "received",
			Every = 2,
			Shape = "cone",
			Range = 5.5,
			Radius = 0.15,
			Arc = 1.1,
			Damage = 0.7,
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
			Damage = 0.72,
			Windup = 0.35,
			Duration = 0.65,
			LandChance = 0.65,
		},
		mason_jar = {
			Trigger = "heavy",
			Threshold = 0.12,
			Every = 1,
			Shape = "armed_contact",
			ContactBonus = 0.6,
			Windup = 0,
			Duration = 4,
		},
		hot_sauce = {
			Trigger = "threshold",
			Threshold = 0.5,
			Shape = "boost",
			Drive = 1.18,
			ContactBonus = 0.35,
			ContinuousBonus = true,
			Windup = 0.25,
			Duration = 3,
		},
		crystal_tumbler = {
			Trigger = "timer",
			First = 4,
			Interval = 7,
			Jitter = 0.5,
			Shape = "mirror",
			Mitigation = 0.45,
			ContactBonus = 0.25,
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
			Damage = 0.5,
			Windup = 0.25,
			Duration = 0.6,
			LandChance = 0.75,
		},
		hourglass = {
			Trigger = "turnaround",
			Every = 3,
			Shape = "heal",
			Heal = 0.07,
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
			Damage = 0.3,
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
			Damage = 0.65,
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
			ContactBonus = 0.35,
			Rebound = 1.2,
			Windup = 0.3,
			Duration = 2.5,
		},
		glass_duck = {
			Trigger = "threshold",
			Threshold = 0.35,
			Shape = "guard",
			Mitigation = 0.5,
			Windup = 0.12,
			Duration = 2.5,
		},
		comet = {
			Trigger = "contact",
			Every = 3,
			Shape = "echo_contact",
			Range = 8,
			Radius = 0.2,
			Damage = 0.65,
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
			Damage = 1.05,
			Windup = 0.5,
			Duration = 0.5,
			LandChance = 0.7,
		},
		galaxy_orb = {
			Trigger = "timer",
			First = 8,
			Interval = 11,
			Jitter = 1,
			Shape = "orbit",
			Range = 3.5,
			Radius = 0.15,
			Force = 2,
			Damage = 0.45,
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
			SeedDamage = 0.14,
			KnockThreshold = 0.08,
			Windup = 0.35,
			Duration = 0.9,
			Radius = 0.2,
		},
		pop = {
			Trigger = "contact",
			Every = 3,
			ContactBonus = 0.6,
			Rebound = 1.35,
			Windup = 0,
			Shape = "contact",
			Duration = 0.14,
		},
		jam = { Trigger = "turnaround", Every = 2, Windup = 0.15, Shape = "guard", Duration = 2, Mitigation = 0.4 },
		prism = {
			Trigger = "timer",
			First = 5.5,
			Interval = 8,
			Jitter = 1,
			Windup = 0.45,
			Shape = "ray",
			Range = 8,
			Radius = 0.14,
			Damage = 0.55,
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
			Damage = 0.5,
			Duration = 0.5,
			LandChance = 0.6,
		},
		briar_flask = {
			Trigger = "turnaround",
			Every = 3,
			ContactBonus = 0.8,
			Windup = 0,
			Shape = "armed_contact",
			Duration = 0.14,
		},
		arc_coil = {
			Trigger = "contact",
			Every = 3,
			Windup = 0.35,
			Shape = "ray",
			Range = 12,
			Radius = 0.18,
			Damage = 0.6,
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
	SnapshotSeconds = 5,
	ClaimRateSeconds = 0.5,
	CodeRateSeconds = 1,
	MaxTickSeconds = 5,
	LeaderboardPublishSeconds = 60,
	LeaderboardReadSeconds = 120,
	LeaderboardRows = 10,
}

Balance.Data = {
	Version = 2,
	StoreName = "GlassClash_v2",
	StudioStoreName = "GlassClash_Studio_v2",
	StudioMock = true, -- protects live progress during automated Studio tests
	LoadTimeout = 60,
	ReleaseGrace = 0.25,
	RecentMatches = 32,
	RequestRateSeconds = 0.5,
	KilnRateSeconds = 0.75,
	KilnQuoteSeconds = 60,
	DaySeconds = 86400,
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
	Gravity = 77, -- "game gravity": with StringLength 7 one full swing takes ~1.9 s
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
	DamageScale = 0.27, -- damage per Power at RefSpeed
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
	-- Round end
	OvertimeAt = 45, -- seconds; after this, damage grows to stop endless rounds
	OvertimePerSecond = 0.06, -- +6% damage per second of overtime
	RoundTimeout = 75, -- winner = higher HP fraction
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
-- Starters are not in crates. Fight strength scales with Power x HP, i.e. roughly with
-- StatMultiplier squared, so keep the spread modest.
Balance.Rarities = {
	Common = { Order = 1, StatMultiplier = 1.00, CrateWeight = 56.25 },
	Uncommon = { Order = 2, StatMultiplier = 1.02, CrateWeight = 22 },
	Rare = { Order = 3, StatMultiplier = 1.04, CrateWeight = 14 },
	Epic = { Order = 4, StatMultiplier = 1.06, CrateWeight = 6 },
	Legendary = { Order = 5, StatMultiplier = 1.08, CrateWeight = 1.5 },
	Mythic = { Order = 6, StatMultiplier = 1.1, CrateWeight = 0.25 },
	Starter = { Order = 0, StatMultiplier = 1.02, CrateWeight = 0 },
}

-- Stars from duplicates (GAME_DESIGN 4.3). Every duplicate from a crate adds a star.
Balance.Growth = {
	StatPerStar = 0.02,
	MaxStars = 5,
	DuplicatesPerStar = 1,
	DuplicateCoinsAtMaxStars = 50, -- duplicates past max stars turn into coins
	RainbowChance = 1 / 500,
	RainbowBonus = 0.05,
}

-- Matches (GAME_DESIGN 2). 1v1, each player has 3 hearts; losing a round costs a heart.
Balance.Match = {
	QueueCheckSeconds = 0.2,
	QueueMargin = 0.5,
	QueueHeight = 7,
	LeaveRateSeconds = 0.25,
	RequestRateSeconds = 0.5,
	Hearts = 3,
	RollChoices = 3, -- glassies offered from your collection each round
	RollSeconds = 25, -- time to pick; auto-picks the first offer when it runs out
	FreeRerollsPerMatch = 0,
	RerollMarbleCosts = { 3, 3, 6, 6, 9 }, -- per match; the last value repeats
	FreePickAnyPerMatch = 1,
	PickAnyMarbleCosts = { 6, 9, 12 }, -- after the free pick; the last value repeats
	RerollReserveSeconds = 2.6, -- don't charge when the reveal cannot finish before selection closes
	AimSeconds = 15,
	CountdownSeconds = 4,
	RoundEndSeconds = 6,
	QueueBotAfterSeconds = 15, -- an empty arena slot fills with a bot after this long
	BotSkillMin = 0.2,
	BotSkillMax = 0.7,
	-- Remote rate limits (seconds between accepted calls per player)
	PickRateSeconds = 0.25,
	RerollRateSeconds = 0.5,
	PickAnyRateSeconds = 0.5,
	AimRateSeconds = 0.05,
	Rewards = {
		RoundWinCoins = 10,
		MatchWinCoins = 60,
		MatchLossCoins = 20,
		BotMatchFraction = 0.6, -- coins against bots
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
	PlaytimeGifts = {
		{ Minutes = 5, Coins = 40 },
		{ Minutes = 15, Coins = 60 },
		{ Minutes = 30, Coins = 100 },
		{ Minutes = 60, Coins = 150 },
	},
	FirstWinOfDayCoins = 100,
	WelcomeKilnPulls = 1, -- free pull right after a new player's first match
	GroupJoinMarbles = 20, -- one time, for joining the group
	DailyStreakMarbles = { 0, 0, 5, 0, 0, 0, 15 }, -- day 1..7 of a login streak, then repeats
	-- Marble packs (dev products). Robux prices are set on the Creator Dashboard; keep the
	-- Marbles-per-Robux curve gently rising so small packs aren't a bad deal for kids.
	MarblePacks = {
		{ Marbles = 40, Robux = 49 },
		{ Marbles = 100, Robux = 99 },
		{ Marbles = 220, Robux = 199 },
		{ Marbles = 600, Robux = 499 },
	},
}

-- ECONOMY SIMULATOR ONLY: how a typical player plays. Compare with real analytics after launch.
Balance.EconomyModel = {
	SessionMinutes = 40, -- one session a day
	Days = 30,
	WinRate = 0.5,
	BotMatchShare = 0.4, -- fraction of matches against bots (high at launch, lower later)
	RoundSecondsEstimate = 27, -- average fight length; BalanceSim prints the real one
	SecondsBetweenMatches = 25, -- results screen, walking to a pad, queue
	QuestsCompletedPerDay = 2,
	Players = 2000,
}

-- Presentation only (client). The fight itself uses Balance.Fight.
Balance.Feel = {
	SpectatorDistance = 120,
	ArenaLabelHeight = 4,
	ArenaLabelWidth = 11, -- studs
	AimDragPixels = 170,
	AimYawPixels = 180,
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
	WatchRejoinSeconds = 35, -- keep watching an arena across the roll between its rounds
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
	RideLift = 2.2,
	RideBob = 0.16,
	RideBobHz = 1.1,
	RideBank = 0.035,
	RideWingAngle = 0.16,
	RideExhaustSpeed = 22,
	RideDistance = 120,
	RideEmitterDistance = 70, -- exhaust particles only run for rides this close to the camera
	RideNod = 0.03, -- nose pitch (radians) following the bob
	RideFlapSharpness = 0.6, -- 0 = sine flap, 1 = quick down-stroke, slow recovery
	RideSwingAngle = 0.22, -- lantern pendulum swing (radians)
	RideSwingLag = 0.9, -- lantern lags the bob by this phase (radians)
	FinisherSeconds = 1.2,
	FinisherParts = 12,
	FinisherRadius = 7,
	FinisherCoreSize = 5,
	FinisherHoldSeconds = 0.8,
	FinisherFadeSeconds = 0.28,
	-- Lantern Eclipse show, seconds from the burst: gather -> eclipse -> hush -> release -> dispersal.
	Eclipse = {
		EclipseAt = 0.55,
		HushAt = 0.77,
		ReleaseAt = 0.85,
		Duration = 2.2,
		LanternHeight = 4.2,
		LanternScale = 1.9,
		PopSeconds = 0.32,
		GhostScale = 1.5,
		GhostStartRadius = 10,
		GhostStartHeight = 5,
		GhostOrbitRadius = 3.2,
		GhostTightRadius = 2.2,
		GhostSpin = 7,
		GhostTremble = 0.12,
		GhostScatter = 9,
		GhostRise = 6,
		HaloScale = 1.6,
		HaloReleaseScale = 3.2,
		MoonScale = 1.15,
		MoonStartOffset = 9,
		MoonGatherOffset = 2.6,
		MoonTowardCamera = 1.4,
		MoonRise = 5,
		MoonColor = "#F4EBC8",
		RimColor = "#DDA84D",
		FlashSize = 5.5,
		FlashSeconds = 0.14,
		ShockRadius = 14,
		ShockSeconds = 0.5,
		ShardSpeed = 11,
		ShardLift = 6,
		ShardGravity = 22,
		ShardSpin = 9,
		ShardColor = "#FF8A2B",
		ShardGlowColor = "#FFC067",
		ShardScale = 0.8,
		Stars = 6,
		StarSpeed = 12,
		LightRange = 14,
		LightBrightness = 2.5,
		LightColor = "#FFB45C",
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
