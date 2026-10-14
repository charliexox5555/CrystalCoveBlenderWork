--!strict
-- All tunable numbers live here. Change numbers here, not inside FightSim, MatchLogic or services.
-- After any change: run the tests and the balance simulator (see AGENTS.md).

local Balance = {}

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
	HitInterval = 1.2, -- seconds between hits in an even matchup
	HitIntervalJitter = 0.25,
	SpeedAtAmplitude = 22, -- approach speed when both swing at amplitude 1 rad
	SpeedSpread = 0.55, -- hits range from (1 - spread) to (1 + spread) of the typical speed
	ShareSpread = 0.35, -- who moved more into the hit varies this much either way
	MissChance = 0.3, -- 3D swings: a swing that passes by without touching
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
	RollSeconds = 8, -- time to pick; auto-picks the first offer when it runs out
	FreeRerollsPerMatch = 1,
	RerollMarbleCosts = { 5, 10, 20 }, -- after the free one; the last value repeats
	AimSeconds = 6,
	CountdownSeconds = 3,
	RoundEndSeconds = 4,
	QueueBotAfterSeconds = 15, -- an empty arena slot fills with a bot after this long
	BotSkillMin = 0.2,
	BotSkillMax = 0.7,
	-- Remote rate limits (seconds between accepted calls per player)
	PickRateSeconds = 0.25,
	RerollRateSeconds = 0.5,
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
	AimDragPixels = 170,
	AimYawPixels = 180,
	CameraDistance = 23,
	CameraHeight = 5,
	CameraSide = 4,
	OccludedLegTransparency = 0.72,
	CameraFollow = 0.18,
	CameraSmooth = 8,
	BigHitSpeed = 1.15, -- multiple of RefSpeed
	PowerEffectSeconds = 0.65,
	PopupSeconds = 0.9,
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
	CameraFocusHeight = 2,
	CameraMinimumAspect = 1.35,
	CameraFieldOfView = 52,
	IdleAngle = 0.05,
	IdleSpeed = 1.6,
	SnapshotRate = 20, -- fight snapshots sent per second; clients interpolate between them
	InterpolationDelay = 0.1, -- seconds clients render behind the newest snapshot
	HitstopSeconds = 0.08,
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
}

return Balance
