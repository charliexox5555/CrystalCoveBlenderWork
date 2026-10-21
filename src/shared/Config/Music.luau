--!strict
-- Background music and music stings (music plan 2026-10-21, decision 109). Provenance, lengths and how each
-- track ends are in docs/audio/SOUND_LIST.md. Pure data, so Lune can load it. Consumed by MusicController (client).

local Music = {}

-- Music beds. Volume is per-track gain at full player volume; the player's Music slider/mute scales the
-- MusicMaster SoundGroup. Loop: "Crossfade" starts the next play (or the next playlist track) on a second Sound
-- LoopCrossfade seconds before the end, for tracks that don't loop cleanly; "Looped" uses Sound.Looped.
-- Length is the measured TimeLength, used until the Sound reports its own.
Music.Tracks = {
	LobbyA = {
		Id = "rbxassetid://78720640408712",
		Volume = 0.22,
		Name = "Gravity Well",
		Length = 240.0,
		Loop = "Crossfade",
	},
	LobbyB = {
		Id = "rbxassetid://109260416655887",
		Volume = 0.22,
		Name = "Fractal Tide",
		Length = 239.1,
		Loop = "Crossfade",
	},
	Fight = {
		Id = "rbxassetid://9042709616",
		Volume = 0.26,
		Name = "I know that you like it no vocals",
		Length = 202.0,
		Loop = "Crossfade",
	},
	Overtime = {
		Id = "rbxassetid://9042708952",
		Volume = 0.24,
		Name = "Heavy Artillery main",
		Length = 154.9,
		Loop = "Crossfade",
	},
}

-- Which beds play in each music context, in order. Lobby starts at a random track per join, then alternates.
-- Lobby panels (Shop, Inventory, Kiln...) keep the lobby playlist.
Music.Playlists = {
	Lobby = { "LobbyA", "LobbyB" },
	Fight = { "Fight" }, -- rolling, aiming, countdown, fight, spectating
	Overtime = { "Overtime" }, -- Overtime, or a round where either side is down to its last heart
}

-- One-shots, played a little above the beds; the beds duck under them.
Music.Stings = {
	-- Ends on the release ("LET GO!"): starts Length seconds before ReleaseAt.
	Tension = { Id = "rbxassetid://103121809098519", Volume = 0.32, Name = "Abiter_Leave", Length = 3.0 },
	Win = { Id = "rbxassetid://127039883737564", Volume = 0.4, Name = "winner!", Length = 1.6 },
	Lose = { Id = "rbxassetid://1844442622", Volume = 0.38, Name = "Loser", Length = 1.3 },
}

Music.FadeIn = 1.5
Music.FadeOut = 1.2
-- Overlap when a "Crossfade" track hands over to its next play.
Music.LoopCrossfade = 3.0
-- A state must hold this long before the bed switches, so quick panel flicks don't thrash music.
Music.SwitchDelay = 0.6
-- After the win/lose sting the bed stays silent this much longer, then lobby music fades in.
Music.ResultGap = 0.8

-- Bed dips. Shatter/finisher and the Kiln reveal use Duck; stings hold StingDuck for their length.
Music.Duck = { Multiplier = 0.35, FadeDown = 0.15, Hold = 2.4, FadeUp = 1.4 }
Music.StingDuck = { Multiplier = 0.4, FadeDown = 0.4, FadeUp = 1.2 }

-- The player's music volume lives in Config/Settings (Music slider, decision 99).

return Music
