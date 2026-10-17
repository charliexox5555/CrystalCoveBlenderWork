--!strict
-- Background music (creator-approved 2026-10-16). All three tracks are APM Music cues from the
-- Roblox-licensed "APMOfficial" Creator Store account; provenance in docs/audio/SOUND_LIST.md.
-- Pure data plus normalize helpers, so Lune can load it. Consumed by MusicController (client)
-- and MusicPrefsService (server).

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

Music.Defaults = { Muted = false, Volume = 0.7 }

Music.Prefs = {
	StoreName = "GlassClashMusicPrefs_v1",
	SetRateSeconds = 0.25,
	SaveDelaySeconds = 8,
}

function Music.normalize(raw: any): { Muted: boolean, Volume: number }
	local muted = Music.Defaults.Muted
	local volume = Music.Defaults.Volume
	if type(raw) == "table" then
		if type(raw.Muted) == "boolean" then
			muted = raw.Muted
		end
		if type(raw.Volume) == "number" and raw.Volume == raw.Volume then
			volume = math.clamp(raw.Volume, 0, 1)
		end
	end
	return { Muted = muted, Volume = volume }
end

function Music.toggled(prefs: { Muted: boolean, Volume: number }): { Muted: boolean, Volume: number }
	local volume = if prefs.Volume <= 0 then Music.Defaults.Volume else prefs.Volume
	return { Muted = not prefs.Muted, Volume = volume }
end

return Music
