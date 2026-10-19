--!strict
-- Finisher show tuning for the five standard finishers (docs/vfx/FINISHERS_V2.md). Times are seconds from the
-- show start; `PeakAt` is the impact beat (in a fight the show starts PeakAt before the winner lands, so the
-- gather plays during the flight). `StillAt` is the frame frozen for icons/portraits. Lantern Eclipse keeps its
-- own numbers in Balance.CosmeticPresentation.Eclipse.
local S = {}

-- Particle textures rendered in Blender (assets/blender/round_cosmetics/finishers_v3/textures). nil falls back
-- to the combat bank texture named in Kit.
S.Textures = {
	StarGlint = nil :: string?,
	SoftGlow = nil :: string?,
	Streak = nil :: string?,
	Bubble = nil :: string?,
	Confetti = nil :: string?, -- 4x4 flipbook
}

S.PoolPerFinisher = 2 -- parked rigs kept per finisher and detail level
S.LowDetailParticles = 0.4 -- particle count multiplier for low detail
S.MobileParticles = 0.7 -- touch-only devices
S.CameraFacingTilt = 0.12 -- radians the show plane leans back toward a camera above it

S.Shows = {
	glass_burst = {
		Module = "PrismPop",
		Duration = 1.7,
		PeakAt = 0.4,
		StillAt = 0.52,
		Shake = 0.22,
		Punch = 0,
		Facets = 12,
		ShellRadius = 2.6,
		FacetSize = 1.45,
		GatherRadius = 6.5,
		BurstSpeed = 11,
		Gravity = 14,
		Spin = 7,
		Slivers = 6,
		SliverLength = 5.5,
		FlashSize = 6,
		RingRadius = 5.5,
		LightBrightness = 0,
		Burst = 26, -- glints at the peak
		Glitter = 30,
	},
	party_burst = {
		Module = "PinataPop",
		Duration = 1.9,
		PeakAt = 0.5,
		StillAt = 0.6,
		Shake = 0.25,
		Punch = 0,
		DropHeight = 6,
		DropSeconds = 0.22,
		StarScale = 1.35,
		WiggleAngle = 0.32,
		PointSpeed = 9,
		Gems = 10,
		Curls = 8,
		Streamers = 4,
		GemSpeed = 10,
		Gravity = 16,
		Confetti = 60,
		ConfettiSpeed = 22,
		FlashSize = 5,
		RingRadius = 5,
	},
	bubble_bloom = {
		Module = "FizzBloom",
		Duration = 2.1,
		PeakAt = 0.55,
		StillAt = 0.95,
		Shake = 0.25,
		Punch = 0,
		BubbleRadius = 3.2,
		Orbiters = 6,
		Bloom = 12,
		BloomRadius = 4.2,
		PopStart = 1.15,
		PopStep = 0.065,
		CrownSize = 4.2,
		LightBrightness = 4,
		LightRange = 14,
		Fizz = 40,
		Droplets = 24,
		FlashSize = 4,
		RingRadius = 6,
	},
	brick_boom = {
		Module = "KaBlock",
		Duration = 2.0,
		PeakAt = 0.55,
		StillAt = 0.66,
		Shake = 0.4,
		Punch = -4,
		Blocks = 8,
		BlockSize = 1.35,
		TowerRadius = 1.9,
		DropHeight = 7,
		DropStep = 0.04,
		DropSeconds = 0.2,
		LetterSize = 1.6,
		LetterSpacing = 1.85,
		LetterForward = 3, -- studs toward the camera
		LetterDrop = 1.6, -- studs below the burst centre
		LandAt = 1.0,
		PopAt = 1.38,
		PopStep = 0.08,
		BlockSpeed = 10,
		Gravity = 18,
		SignSize = 4.2,
		SignHeight = 3.4,
		PuffSize = 6.5,
		LightBrightness = 5,
		LightRange = 16,
		Sparks = 34,
		RingRadius = 7,
	},
	starfall = {
		Module = "Supernova",
		Duration = 2.4,
		PeakAt = 0.62,
		StillAt = 0.74,
		HushAt = 0.5,
		Shake = 0.45,
		Punch = -6,
		Stars = 5,
		StarStartRadius = 6.5,
		StarSize = 1.3,
		HaloRadius = 3,
		CoreSize = 1.8,
		Rays = 8,
		RayLength = 7,
		ShowerStars = 10,
		ShowerSpeed = 9,
		Gravity = 6,
		ShockRadius = 8,
		FlashSize = 7,
		LightBrightness = 7,
		LightRange = 20,
		Glints = 36,
		Dust = 40,
		TwinkleAt = 1.5,
		-- Legendary-only post-processing (fight view only, never with reduced motion or low detail).
		Grade = {
			DimBrightness = -0.06,
			DimSaturation = 0.15,
			PeakBrightness = 0.12,
			PeakContrast = 0.12,
			PeakTint = "#FFF3DE",
			PeakSeconds = 0.25,
			FadeSeconds = 0.35,
		},
	},
}

return S
