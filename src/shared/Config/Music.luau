--!strict
-- Background music (creator-approved 2026-10-16). All three tracks are APM Music cues from the
-- Roblox-licensed "APMOfficial" Creator Store account; provenance in docs/audio/SOUND_LIST.md.
-- Pure data, so Lune can load it. Consumed by MusicController (client).

local Music = {}

-- Volume is per-track gain at full player volume; the player's slider/mute scales a SoundGroup.
Music.Tracks = {
	Lobby = { Id = "rbxassetid://9043613723", Volume = 0.32, Name = "Rainbow Garden (a 30)", Length = 30.1 },
	Match = {
		Id = "rbxassetid://9042710302",
		Volume = 0.3,
		Name = "I know that you like it 30 sec no vocals",
		Length = 32.0,
	},
	Calm = { Id = "rbxassetid://1836139113", Volume = 0.28, Name = "Positive Pre School Program", Length = 20.0 },
}

Music.FadeIn = 1.6
Music.FadeOut = 1.2
-- A state must hold this long before the track switches, so quick panel flicks don't thrash music.
Music.SwitchDelay = 0.6

-- Dip under the finisher/shatter moment, then recover.
Music.Duck = { Multiplier = 0.35, FadeDown = 0.15, Hold = 2.4, FadeUp = 1.4 }

-- The player's music volume lives in Config/Settings (Music slider, decision 99).

return Music
