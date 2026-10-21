-- Power VFX v2 sound cues (workstream E). Client presentation only. New sounds are free ProSoundEffects Creator Store
-- audio (Roblox's licensed library; ids and source names in docs/audio/SOUND_LIST.md, "Power sounds"). Cues may also
-- reuse any Config/Audio bank key; those keep their AudioCues trim (start, length, fade).
-- CombatEffects already plays each kit's Release/Contact sound and LidBlock on blocks; cues here add on top, never
-- the same sample twice.
-- Layer: { Key, Volume (final volume), Pitch, Jitter (+-fraction), Delay (s), Seconds (play length) }.
return {
	VoiceCap = 6, -- power sounds alive at once on this client; extra cues are dropped
	UnwatchedScale = 0.6, -- fights you aren't watching play only their first layer, quieter
	-- Contact cues (marked Contact = true) stay at or below ContactMaxVolume and drop their tail layers when one of
	-- workstream B's Smash/Crit hits lands within BigHitWindow seconds (B's tier already plays up to 4 layers).
	ContactMaxVolume = 0.35,
	BigHitWindow = 0.08,
	Sounds = {
		PW_FizzPop = { Id = "rbxassetid://9117848644", Seconds = 0.45 }, -- Pops Mouth Popping Multiple Versions 7
		PW_LidBonk = { Id = "rbxassetid://9113911944", Seconds = 0.5 }, -- Cooking Pot 26 (stainless lid hit)
		PW_MagicSwirl = { Id = "rbxassetid://9116408879", Seconds = 1.2 }, -- Magic Swirling Tone 1
		PW_StarExit = { Id = "rbxassetid://9125635285", Seconds = 1.2 }, -- Magical Exit Sparkling Pass Bys Clinking Chimes 3
		PW_Crackle = { Id = "rbxassetid://9114246605", Seconds = 0.6 }, -- Electricity Static 7
		PW_AirRush = { Id = "rbxassetid://9114374049", Seconds = 0.9 }, -- Fast Pass By Airy Whooshes Windy 8
		PW_Roar = { Id = "rbxassetid://9117733732", Seconds = 0.75 }, -- Polar Bear 1 (first roar only, pitched up)
		PW_FireBurst = { Id = "rbxassetid://9114444008", Seconds = 0.9 }, -- Fire Whoosh 3
		PW_FireLick = { Id = "rbxassetid://9114446852", Seconds = 0.7 }, -- Fire Whoosh 15
		PW_SlideUp = { Id = "rbxassetid://9119198150", Seconds = 0.75 }, -- Slide Whistle 6
		PW_MusicBox = { Id = "rbxassetid://9117042092", Seconds = 2.4 }, -- Music Box Swan Lake Single Notes 3 (decision 115)
	},
	Cues = {
		-- Daily Rewards glassies (decision 115). Whiskers: a slide-whistle wiggle, a whoosh with a tiny bell, a soft pop
		-- when the yarn tangles. Midnight: a music-box lullaby over a rising bell triad, a shimmer as the foe gets
		-- sleepy, and a bright bonk + chime when the next clash wakes it.
		whiskers_wiggle = {
			{ Key = "PW_SlideUp", Volume = 0.2, Pitch = 1.7, Seconds = 0.35 },
			{ Key = "LanternBell", Volume = 0.16, Pitch = 2.6, Delay = 0.05, Seconds = 0.25 },
		},
		whiskers_toss = {
			{ Key = "PW_AirRush", Volume = 0.3, Pitch = 1.5, Jitter = 0.04, Seconds = 0.45 },
			{ Key = "LanternBell", Volume = 0.16, Pitch = 3.0, Delay = 0.03, Seconds = 0.25 },
		},
		whiskers_tangle = {
			Contact = true,
			{ Key = "BubblePop", Volume = 0.35, Pitch = 0.8, Jitter = 0.05 },
			{ Key = "ChimeCluster", Volume = 0.18, Pitch = 1.6, Seconds = 0.5 },
		},
		midnight_lullaby = {
			{ Key = "PW_MusicBox", Volume = 0.38, Pitch = 1.0, Seconds = 1.6 },
			{ Key = "LanternBell", Volume = 0.16, Pitch = 1.0, Seconds = 0.6 },
			{ Key = "LanternBell", Volume = 0.15, Pitch = 1.26, Delay = 0.18, Seconds = 0.6 },
			{ Key = "LanternBell", Volume = 0.15, Pitch = 1.5, Delay = 0.36, Seconds = 0.8 },
		},
		midnight_sleepy = {
			Contact = true,
			{ Key = "FallingShimmer", Volume = 0.25, Pitch = 0.8, Seconds = 0.9 },
		},
		midnight_bonk = {
			Contact = true,
			{ Key = "PW_LidBonk", Volume = 0.35, Pitch = 1.5, Seconds = 0.4 },
			{ Key = "ChimeCluster", Volume = 0.2, Pitch = 1.2, Seconds = 0.6 },
		},
		pop_payoff = {
			Contact = true,
			{ Key = "PW_FizzPop", Volume = 0.45, Pitch = 1.15, Jitter = 0.05 },
		},
		jam_bonk = {
			Contact = true,
			{ Key = "PW_LidBonk", Volume = 0.4, Pitch = 1.2, Jitter = 0.04, Seconds = 0.45 },
		},
		prism_gather = { { Key = "PW_MagicSwirl", Volume = 0.22, Pitch = 1.3, Seconds = 0.5 } },
		comet_launch = {
			{ Key = "RisingWhoosh", Volume = 0.3, Pitch = 1.2, Seconds = 0.6 },
			{ Key = "PW_StarExit", Volume = 0.3, Pitch = 1.1, Delay = 0.05, Seconds = 1.0 },
		},
		comet_hit = {
			Contact = true,
			{ Key = "ChimeCluster", Volume = 0.35, Pitch = 1.15, Seconds = 0.9 },
		},
		dragon_inhale = { { Key = "PW_AirRush", Volume = 0.25, Pitch = 1.5, Seconds = 0.45 } },
		dragon_breath = {
			{ Key = "PW_AirRush", Volume = 0.4, Pitch = 0.9, Seconds = 0.8 },
			{ Key = "FallingShimmer", Volume = 0.22, Pitch = 1.3, Seconds = 0.9 },
		},
		galaxy_vortex = {
			{ Key = "PW_MagicSwirl", Volume = 0.35, Pitch = 0.8, Seconds = 1.2 },
			{ Key = "CosmicRiser", Volume = 0.18, Pitch = 1.2, Seconds = 1.0 },
		},
		rocket_ignite = { { Key = "PW_FireBurst", Volume = 0.4, Pitch = 1.2, Jitter = 0.04, Seconds = 0.7 } },
		duck_pop = {
			Contact = true,
			{ Key = "BubblePop", Volume = 0.45, Pitch = 0.9 },
			{ Key = "Bubbles", Volume = 0.25, Seconds = 0.6 },
		},
		arc_crackle = { { Key = "PW_Crackle", Volume = 0.28, Pitch = 1.2, Seconds = 0.35 } },
		arc_bolt = { { Key = "PW_Crackle", Volume = 0.45, Pitch = 0.9, Seconds = 0.5 } },
		chime_ring = {
			{ Key = "LanternBell", Volume = 0.3, Pitch = 1.0, Seconds = 0.9 },
			{ Key = "ChimeCluster", Volume = 0.2, Pitch = 1.3, Seconds = 0.8 },
		},
		zone_pop = {
			Contact = true,
			{ Key = "PW_FizzPop", Volume = 0.4, Pitch = 0.95, Jitter = 0.05 },
		},
		drain_zap = {
			Contact = true,
			{ Key = "PW_Crackle", Volume = 0.4, Pitch = 1.4, Seconds = 0.45 },
			{ Key = "MagicRiser", Volume = 0.2, Pitch = 1.4, Seconds = 0.5 },
		},
		roar = {
			{ Key = "SoftBoom", Volume = 0.35, Pitch = 1.1, Seconds = 0.9 },
			{ Key = "PW_Roar", Volume = 0.28, Pitch = 1.25, Delay = 0.04 },
		},
		dash = {
			{ Key = "PW_StarExit", Volume = 0.3, Pitch = 1.25, Seconds = 0.8 },
			{ Key = "RisingWhoosh", Volume = 0.25, Pitch = 1.3, Seconds = 0.5 },
		},
		rebirth_gather = { { Key = "MagicRiser", Volume = 0.3, Pitch = 0.9, Seconds = 0.5 } },
		rebirth_flare = {
			{ Key = "PW_FireBurst", Volume = 0.45, Pitch = 0.95, Seconds = 0.9 },
			{ Key = "ChimeCluster", Volume = 0.3, Pitch = 1.2, Delay = 0.05, Seconds = 0.9 },
		},
		spin = { { Key = "PW_SlideUp", Volume = 0.3, Seconds = 0.75 } },
		hot_sauce = { { Key = "PW_FireLick", Volume = 0.35, Pitch = 1.1, Seconds = 0.7 } },
	},
}
