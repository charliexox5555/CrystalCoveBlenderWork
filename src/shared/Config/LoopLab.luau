-- Private prototype values only. Production services never require this config.
return {
	Roster = { "pop", "jam", "prism", "glass_cup", "water_jug", "ketchup_bottle" },
	Roles = {
		pop = "Third hit bursts",
		jam = "Lid shield",
		prism = "Glass beam",
		glass_cup = "Fast dash",
		water_jug = "Water blast",
		ketchup_bottle = "Marks the rival",
	},
	AimSeconds = 5,
	ShotSeconds = 2,
	RecoverySeconds = 0.7,
	ContinueSeconds = 1.25, -- brief shatter payoff, then directly into the next automatic duel
	MaxShots = 10,
	HpScale = 0.6,
	RateSeconds = 0.15,
	Step = 1 / 60,
	SnapshotSeconds = 1 / 20,
	Seed = 291026,
}
