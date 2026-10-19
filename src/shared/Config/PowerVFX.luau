-- Power VFX v2 presentation numbers (workstream E, docs/vfx/POWER_VFX_V2.md). Client presentation only:
-- no rule, timing or damage reads these. Sizes are studs unless they say "scale" (a multiple of the body size).
return {
	-- Rarity -> presentation tier.
	Tier = {
		Starter = "Crisp",
		Common = "Crisp",
		Uncommon = "Crisp",
		Rare = "Rare",
		Epic = "Epic",
		Legendary = "Hero",
		Mythic = "Hero",
	},
	TierRank = { Crisp = 1, Rare = 2, Epic = 3, Hero = 4 },
	Ready = {
		HaloScale = 1.45, -- x the body's largest side
		HaloTransparency = 0.22,
		HaloPulse = 0.12, -- size pulse amplitude
		PulseHzStart = 1.6,
		PulseHzEnd = 4,
		TightenSeconds = 0.6, -- the last stretch before AutoAt pulls the halo onto the body
		TightenScale = 0.8,
		SpinHz = 0.25,
		OutlineTransparency = 0.3,
		OutlinePulse = 0.35,
		Orbiters = { Crisp = 0, Rare = 3, Epic = 3, Hero = 5 },
		OrbitScale = 0.95, -- x the body's largest side
		OrbitHz = 0.55,
		OrbiterSize = 0.42,
		SparkleEvery = 0.18, -- Epic and Hero: a rising sparkle this often
		GroundRadius = 2.6, -- Hero only
	},
	Cast = {
		ManualSeconds = 0.42,
		ManualFlash = 2.4,
		ManualRing = 6.5,
		ManualSpokes = 8,
		ManualSpokeLength = 2.6,
		ManualLight = 5,
		OtherScale = 0.6, -- the other side's manual cast
		AutoSeconds = 0.3,
		AutoRing = 3.4,
		AutoGlints = 4,
	},
	Armed = {
		BandScale = 1.2, -- x the body's largest side
		BandHz = 1.3,
		BandTilt = 0.5,
		FlickerSeconds = 0.6,
		OutlineTransparency = 0.15,
		FadeSeconds = 0.4,
		CrackleEvery = 0.22,
	},
	Hero = {
		BloomBrightness = 0.08,
		BloomSaturation = 0.18,
		BloomSeconds = 0.32,
		GroundRing = 5.5,
	},
	Impact = {
		Flash = 1.6,
		FlashSeconds = 0.14,
		Ring = 4.2,
		RingSeconds = 0.32,
		Spokes = 6,
		SpokeLength = 1.8,
	},
	Light = { Range = 12, Brightness = 3.5 },
	Budget = {
		MaxEffects = 48, -- per fight; the oldest stops first
		LowQualityLevel = 3, -- SavedQualityLevel 1..3 -> low detail
		TouchParticles = 0.6,
		LowParticles = 0.4,
		Lights = 3,
		StaleSeconds = 0.4, -- a moment that arrives later than this is skipped (late join / catch-up)
	},
	Motion = {
		WindupWiggle = 0.09, -- radians
		WindupHz = 9,
		RearBack = 0.32, -- dragon
		Recoil = 0.2,
		RecoilSeconds = 0.35,
		PopCapLift = 2.4, -- Pop's cap rockets off on the payoff
	},
}
