--!strict
-- Hollowlight set sound design outside the finisher (the finisher's cues live in Config/FinisherAudio).
-- Keys are Config/Audio names; Volume multiplies the AudioCues trim, Pitch multiplies its pitch.
-- The motif: LanternBell rung as a rising minor triad (docs/vfx/HOLLOWLIGHT_PREMIUM.md section 2).
export type Layer = { Key: string, Volume: number, Pitch: number?, At: number? }

return {
	Chime = { Key = "LanternBell", Pitches = { 1, 1.19, 1.5 }, Volume = 1.1 },
	Seeds = {
		Plant = 0.9, -- seed n rings motif note n
		Lost = { Key = "LanternBell", Volume = 0.8, Pitch = 0.75 },
		Ready = { Volume = 0.6, Gap = 0.1 }, -- soft triad once when the bloom is ready to cast
		Bloom = { Volume = 1.1, Gap = 0.07 }, -- quick arpeggio on every bloom
		Manual = { { Key = "GhostWhoo", Volume = 0.55, Pitch = 1.35 } } :: { Layer }, -- extra on a manual cast
		Home = { Key = "HL_Twinkle", Volume = 0.55, Pitch = 1.2 }, -- each wisp landing
		LastHome = { Key = "MagicPoof", Volume = 0.45, Pitch = 1.25 },
	},
	Ride = {
		-- Looped 3D bed under the carriage while it is near the camera.
		Loop = {
			{ Key = "HL_RideSparkle", Volume = 1 },
			{ Key = "HL_RideHum", Volume = 1, Pitch = 0.85 },
		} :: { Layer },
		LoopDistance = 55, -- studs; beyond this the loop fades out
		RollOffMin = 8,
		RollOffMax = 55,
		TakeOff = {
			{ Key = "HL_TakeOff", Volume = 1, Pitch = 1.05 },
			{ Key = "LanternBell", Volume = 0.8, Pitch = 1, At = 0.1 },
			{ Key = "LanternBell", Volume = 0.75, Pitch = 1.19, At = 0.22 },
			{ Key = "LanternBell", Volume = 0.8, Pitch = 1.5, At = 0.34 },
		} :: { Layer },
		Land = {
			{ Key = "LanternBell", Volume = 0.75, Pitch = 1.5 },
			{ Key = "LanternBell", Volume = 0.7, Pitch = 1.19, At = 0.12 },
			{ Key = "LanternBell", Volume = 0.75, Pitch = 1, At = 0.24 },
			{ Key = "MagicPoof", Volume = 0.6, Pitch = 1.1, At = 0.2 },
		} :: { Layer },
	},
}
