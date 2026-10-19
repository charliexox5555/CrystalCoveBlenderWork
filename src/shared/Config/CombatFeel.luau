--!strict
-- Client-only fight feel (workstream B): hit tiers, hitstop, camera, glass reactions and feedback beats.
-- Presentation only: nothing here changes damage, rules or what the server decides. Sounds are Config/Audio keys.
-- Research ranges: docs/research/COMBAT_OVERHAUL_RESEARCH.md section 4 (hitstop 40-110 ms, shake 0.15-0.25 s).
return {
	-- A hit's tier comes from approach speed (multiple of Balance.Fight.RefSpeed) and the bigger damage share
	-- (damage / max HP). Crit wins over everything; then the first tier whose Speed or Damage is reached.
	Classify = {
		Smash = { Speed = 1.15, Damage = 0.16 },
		Solid = { Speed = 0.55, Damage = 0.06 },
	},

	-- Bursts sit this far in front of the contact point (toward the camera) so the glass never hides them.
	FrontStuds = 1.4,
	Tiers = {
		Glance = {
			Hitstop = 0,
			Trauma = 0.12,
			Kick = 0.05, -- studs of directional camera kick
			Fov = 0,
			Spokes = 4,
			SpokeLength = 0.8,
			SpokeWidth = 0.1,
			Spread = 1.6,
			Rings = 1,
			RingEnd = 1.3,
			Flash = 0.55, -- contact flash ball size (studs)
			Chips = 0,
			Glints = 3,
			Light = 0,
			Seconds = 0.24,
			Color = "#A8EBFF",
			Struck = { Jolt = 0.05, Wobble = 0.05 },
			Striker = { Jolt = 0.02, Wobble = 0.02, Glints = 0 },
			CrackGlint = 0.08,
			ImpactFlash = 0,
			Sounds = {
				{
					Key = "ClinkLightA",
					Volume = 0.22,
					Pitch = 1.25,
					Jitter = 0.06,
					Short = 0.18,
					UseGlassyPitch = true,
				},
			},
		},
		Solid = {
			Hitstop = 0.045,
			Trauma = 0.28,
			Kick = 0.12,
			Fov = 0,
			Spokes = 6,
			SpokeLength = 1.2,
			SpokeWidth = 0.14,
			Spread = 2.2,
			Rings = 1,
			RingEnd = 2.3,
			Flash = 1.1,
			Chips = 5,
			Glints = 4,
			Light = 0,
			Seconds = 0.3,
			Color = "#5FD8FF",
			Struck = { Jolt = 0.1, Wobble = 0.1 },
			Striker = { Jolt = 0.04, Wobble = 0.04, Glints = 3 },
			CrackGlint = 0.12,
			ImpactFlash = 0.05,
			Sounds = {
				{ Key = "ClinkLightA", Volume = 0.2, Pitch = 1.6, Jitter = 0.05, Short = 0.07 }, -- transient
				{ Key = "Clink", Volume = 0.42, Pitch = 1.0, Jitter = 0.05, UseGlassyPitch = true }, -- body
				{ Key = "ClinkAlt", Volume = 0.16, Pitch = 1.15, Jitter = 0.08, Delay = 0.03 }, -- glass tail
			},
		},
		Smash = {
			Hitstop = 0.075,
			Trauma = 0.5,
			Kick = 0.22,
			Fov = -2.5, -- degrees; negative = punch in
			Spokes = 8,
			SpokeLength = 1.6,
			SpokeWidth = 0.2,
			Spread = 2.7,
			Rings = 2,
			RingEnd = 3.4,
			Flash = 1.6,
			Chips = 9,
			Glints = 6,
			Light = 3,
			Seconds = 0.36,
			Color = "#3FC8FF",
			Struck = { Jolt = 0.18, Wobble = 0.17 },
			Striker = { Jolt = 0.07, Wobble = 0.06, Glints = 5 },
			CrackGlint = 0.16,
			ImpactFlash = 0.07,
			Sounds = {
				{ Key = "ClinkLightA", Volume = 0.24, Pitch = 1.75, Jitter = 0.05, Short = 0.07 },
				{ Key = "ClinkHeavy", Volume = 0.55, Pitch = 1.0, Jitter = 0.05, UseGlassyPitch = true },
				{ Key = "ShatterScatter", Volume = 0.16, Pitch = 1.45, Jitter = 0.08, Delay = 0.04, Short = 0.45 },
			},
		},
		Crit = {
			Hitstop = 0.105,
			Trauma = 0.62,
			Kick = 0.26,
			Fov = -4,
			Spokes = 10,
			SpokeLength = 1.8,
			SpokeWidth = 0.24,
			Spread = 3,
			Rings = 2,
			RingEnd = 4,
			Flash = 1.9,
			Chips = 11,
			Glints = 8,
			Light = 5,
			Seconds = 0.4,
			Color = "#FFC21F",
			Struck = { Jolt = 0.22, Wobble = 0.21 },
			Striker = { Jolt = 0.08, Wobble = 0.07, Glints = 8 },
			CrackGlint = 0.2,
			ImpactFlash = 0.09,
			Sounds = {
				{ Key = "ClinkLightA", Volume = 0.26, Pitch = 1.9, Jitter = 0.04, Short = 0.07 },
				{ Key = "ClinkHeavy", Volume = 0.6, Pitch = 0.95, Jitter = 0.04, UseGlassyPitch = true },
				{ Key = "ShatterScatter", Volume = 0.18, Pitch = 1.55, Jitter = 0.06, Delay = 0.04, Short = 0.5 },
				{ Key = "ChimeCluster", Volume = 0.2, Pitch = 1.35, Jitter = 0.04, Delay = 0.06, Short = 0.45 },
			},
		},
		-- Every hit point was absorbed (guards, shields): a dull, golden "tok" with no hitstop.
		Block = {
			Hitstop = 0.02,
			Trauma = 0.16,
			Kick = 0.06,
			Fov = 0,
			Spokes = 0,
			SpokeLength = 0,
			SpokeWidth = 0,
			Spread = 0,
			Rings = 1,
			RingEnd = 2.2,
			Flash = 0.7,
			Chips = 0,
			Glints = 5,
			Light = 0,
			Seconds = 0.3,
			Color = "#FFB547",
			Struck = { Jolt = 0.04, Wobble = 0.03 },
			Striker = { Jolt = 0.08, Wobble = 0.08, Glints = 0 },
			CrackGlint = 0,
			ImpactFlash = 0,
			Sounds = {
				{ Key = "LidBlock", Volume = 0.4, Pitch = 1.0, Jitter = 0.05 },
				{ Key = "ClinkLightB", Volume = 0.14, Pitch = 1.5, Jitter = 0.05, Delay = 0.02 },
			},
		},
	},

	-- Render clock: hold, then catch up proportionally so interpolation never jumps or drifts.
	Hitstop = {
		HoldRate = 0.04, -- render clock speed during a hold (a near-freeze reads better than a dead stop)
		CatchUpGain = 6, -- extra speed per second of lag behind the target
		CatchUpMax = 2, -- never run the clock faster than this multiple
		NormalRate = 1.25, -- the existing chase rate toward the interpolation target
		PowerLand = 0.065, -- power/signature contact that landed
		MaxSeconds = 0.12, -- cap for any single hold
	},

	Camera = {
		TraumaDecay = 2.6, -- trauma lost per second (0.5 trauma rings down in ~0.2 s)
		ShakeStuds = 0.32, -- positional shake at trauma 1 (shake = ShakeStuds * trauma^2)
		ShakeRoll = 0.006, -- radians of roll at trauma 1; kept tiny on purpose
		ShakeHz = 22,
		MaxStuds = 0.3, -- hard cap on combined shake + kick offset
		KickSpring = 70, -- directional kick: critically damped spring stiffness
		FovRecover = 9, -- FOV punch eases back at this rate
		FovMin = -6, -- cap on total FOV punch (degrees)
	},

	-- Glass reactions: rotation about the body centre plus a small jolt, layered over the authoritative pose.
	React = {
		Spring = 160, -- wobble spring stiffness
		Damping = 9, -- wobble damping (low enough for two or three visible wiggles)
		JoltDecay = 14,
		MaxAngle = 0.3, -- radians
		MaxJolt = 0.25, -- studs
		FlashColor = "#FFFFFF",
	},

	-- Beat bursts use the same shape set as hit tiers (ImpactBeat.tier), centred on the glassy.
	Perfect = {
		Burst = {
			Spokes = 6,
			SpokeLength = 1.2,
			SpokeWidth = 0.14,
			Spread = 2.4,
			Rings = 2,
			RingEnd = 3,
			Flash = 1.2,
			Chips = 0,
			Glints = 10,
			Light = 2,
			Seconds = 0.45,
			Color = "#FFE45C",
		},
		Fov = -1.5,
		Sounds = { { Key = "ChimeCluster", Volume = 0.24, Pitch = 1.25, Jitter = 0.03, Short = 0.6 } },
	},

	-- A power or signature reached its target vs went wide.
	PowerLand = {
		Trauma = 0.42,
		Kick = 0.18,
		Fov = -2,
		Struck = { Jolt = 0.16, Wobble = 0.16 },
		CrackGlint = 0.16,
	},
	PowerMiss = {
		Wobble = 0.06,
		Sounds = { { Key = "Whoosh", Volume = 0.16, Pitch = 0.62, Jitter = 0.04, Short = 0.4 } },
	},

	-- Lead change: the side with more HP left (as a fraction) swaps after being behind by this much.
	Comeback = {
		MinLead = 0.12, -- the old lead must have been at least this big
		Cooldown = 3, -- seconds of render time between calls
		Text = "COMEBACK!",
		Color = "#7CFFB2",
		Burst = {
			Spokes = 6,
			SpokeLength = 1.2,
			SpokeWidth = 0.14,
			Spread = 2.4,
			Rings = 1,
			RingEnd = 2.8,
			Flash = 1,
			Chips = 0,
			Glints = 10,
			Light = 2,
			Seconds = 0.45,
			Color = "#7CFFB2",
		},
		Sounds = { { Key = "ChimeCluster", Volume = 0.2, Pitch = 1.5, Jitter = 0.03, Short = 0.5 } },
	},

	-- Own glassy at low HP (participants only): a slight grade and a slow crack shimmer, no shake.
	Tension = {
		Fraction = 0.25,
		Saturation = -0.16,
		Contrast = 0.06,
		EaseSeconds = 0.6,
		PulseEvery = 0.95,
		PulseGlint = 0.12,
		Sounds = { { Key = "ClinkAlt", Volume = 0.07, Pitch = 0.55, Jitter = 0.02, Short = 0.2 } },
	},

	-- The final blow: hold the frame, tint the loser white, punch in, then release into the shatter/finisher.
	KO = {
		HoldSeconds = 0.18,
		ReducedHoldSeconds = 0.1,
		Trauma = 0.7,
		Fov = -5,
		Saturation = -0.3,
		Contrast = 0.15,
		Brightness = 0.06,
		GradeSeconds = 0.45,
		ImpactFlash = 0.18,
		Sounds = { { Key = "ClinkHeavy", Volume = 0.5, Pitch = 0.72, Jitter = 0.03, Short = 0.3 } },
	},

	Victory = {
		Burst = {
			Spokes = 0,
			SpokeLength = 0,
			SpokeWidth = 0,
			Spread = 0,
			Rings = 2,
			RingEnd = 3.8,
			Flash = 0,
			Chips = 0,
			Glints = 18,
			Light = 3,
			Seconds = 0.7,
			Color = "#FFE45C",
		},
		LocalWinSounds = { { Key = "UiSuccess", Volume = 0.35, Pitch = 1.0, Jitter = 0, Short = 1.2 } },
		Sounds = { { Key = "ChimeCluster", Volume = 0.2, Pitch = 1.1, Jitter = 0.02, Short = 0.9 } },
	},

	-- Workstream A's cast contract: SignatureReady, then CastStart { Manual = true } when the player tapped CAST.
	Cast = {
		ReadySounds = { { Key = "ClinkLightA", Volume = 0.14, Pitch = 2.1, Jitter = 0, Short = 0.15 } },
		ReadyGlints = 6,
		Manual = {
			Text = "NICE CAST!",
			Color = "#FFE45C",
			Hitstop = 0.05,
			Trauma = 0.25,
			Fov = -3,
			OtherScale = 0.5, -- glints/rings for someone else's manual cast (bots, the opponent)
			Burst = {
				Spokes = 10,
				SpokeLength = 1.6,
				SpokeWidth = 0.18,
				Spread = 3.2,
				Rings = 2,
				RingEnd = 3.8,
				Flash = 1.6,
				Chips = 0,
				Glints = 14,
				Light = 4,
				Seconds = 0.5,
				Color = "#FFC21F",
			},
			Sounds = {
				{ Key = "RisingWhoosh", Volume = 0.22, Pitch = 1.3, Jitter = 0.02, Short = 0.45 },
				{ Key = "ChimeCluster", Volume = 0.22, Pitch = 1.4, Jitter = 0.02, Delay = 0.05, Short = 0.6 },
			},
		},
	},

	-- Accessibility and budgets.
	ReducedMotion = {
		Shake = 0, -- multiplies trauma shake and kicks
		Fov = 0, -- multiplies FOV punches
		React = 0.5, -- multiplies glass wobble/jolt
		Hitstop = 0.6, -- multiplies hold length
		Grade = 0.5, -- multiplies colour-grade dips
	},
	Budget = {
		MobileParticles = 0.6, -- touch-only devices emit this share of chips/glints
		LowParticles = 0.4, -- SavedQualityLevel 1-3
		LowQualityLevel = 3,
		PoolRings = 4, -- pooled ring meshes per fight
		PoolSpokes = 12,
		PoolFlashes = 2,
	},
}
