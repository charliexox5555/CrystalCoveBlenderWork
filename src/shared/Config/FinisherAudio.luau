--!strict
-- Finisher sound design (names from Config/Audio). Each cue fires at `At` seconds after its phase:
--   Rise  = the winner starts lifting (fight only, Feel.FinisherPause after the knockout)
--   Fly   = the winner launches at the loser (fight only, + Feel.FinisherRiseSeconds)
--   Burst = FinisherFX starts (in a fight FinisherFX.leadIn before the impact; the whole inventory preview)
-- Priority 1 cues (the impact) may take a voice from an older cue; others are skipped when full.
export type Cue = { Sound: string, Phase: string, At: number, Volume: number?, Pitch: number?, Priority: number? }

local function cue(sound: string, phase: string, at: number, volume: number?, pitch: number?, priority: number?): Cue
	return { Sound = sound, Phase = phase, At = at, Volume = volume, Pitch = pitch, Priority = priority }
end

return {
	MaxVoices = 8, -- simultaneous finisher sounds on this client, across every arena
	RollOffMin = 20,
	RollOffMax = 70,
	PreviewVolume = 0.8, -- inventory preview is 2D, so a little quieter
	Volume = 1,
	Finishers = {
		-- Prism Pop (FinisherShows: shell snaps 0.24, peak 0.4): shimmer as the shell forms, a glassy ping as it
		-- locks, a bright glass shatter on the pop, then scatter and a glitter chime.
		glass_burst = {
			cue("MagicRiser", "Rise", 0, 0.9, 1.1),
			cue("RisingWhoosh", "Fly", 0, 0.9, 1.15),
			cue("ChargeGlass", "Burst", 0.05, 0.7, 1.4),
			cue("FN_GlassPing", "Burst", 0.24, 0.7, 1.3),
			cue("SafetyGlass", "Burst", 0.4, 1, 1.1, 1),
			cue("ShatterScatter", "Burst", 0.5, 0.8, 1.25),
			cue("ChimeCluster", "Burst", 0.62, 0.8, 1.2),
		},
		-- Piñata Pop (drop lands 0.22, wiggle to the peak at 0.5): a knock on landing, rattles as it wiggles,
		-- a punchy poof + pop on the burst, a party toot and confetti patter.
		party_burst = {
			cue("PartyHorn", "Rise", 0.05, 0.8, 1.15),
			cue("RisingWhoosh", "Fly", 0, 1, 1.25),
			cue("ToyBlockB", "Burst", 0.22, 0.8, 1.5),
			cue("CapRattle", "Burst", 0.33, 1, 1.2),
			cue("CapRattle", "Burst", 0.42, 1, 1.35),
			cue("FN_PunchyPoof", "Burst", 0.5, 1.1, 1.1, 1),
			cue("BubblePop", "Burst", 0.51, 1.2, 0.75),
			cue("PartyHorn", "Burst", 0.62, 0.9, 1.25),
			cue("CapRattle", "Burst", 1.2, 0.8, 1.4),
		},
		-- Fizz Bloom (peak 0.55, bloom pops from 1.15 every 65 ms): fizz and a humming swell, a splash on the
		-- pop, then a rising ripple of bubble pops and a glassy ping.
		bubble_bloom = {
			cue("Bubbles", "Rise", 0, 0.8, 1.2),
			cue("RisingWhoosh", "Fly", 0, 0.9, 1.35),
			cue("Bubbles", "Burst", 0.02, 0.7, 1.1),
			cue("FN_GlowSwell", "Burst", 0.1, 0.6, 1.2),
			cue("SplashBloom", "Burst", 0.55, 1.1, 1.05, 1),
			cue("BubblePop", "Burst", 1.15, 1.1, 1.0),
			cue("BubblePop", "Burst", 1.28, 1.0, 1.15),
			cue("BubblePop", "Burst", 1.41, 0.95, 1.3),
			cue("FN_GlassPing", "Burst", 1.5, 0.6, 1.6),
		},
		-- Ka-Block (blocks stack 0.26-0.61, peak 0.55, letters land 1.0, pop from 1.38): toy-block knocks, a soft
		-- boom + poof, clacks as BOOM lands and hops, then pings and a chime as the letters pop.
		brick_boom = {
			cue("ToyBlockA", "Rise", 0.05, 0.8, 0.9),
			cue("ToyBlockB", "Rise", 0.3, 0.8, 1.05),
			cue("RisingWhoosh", "Fly", 0, 1, 0.85),
			cue("ToyBlockA", "Burst", 0.26, 0.9, 1.0),
			cue("ToyBlockB", "Burst", 0.4, 0.9, 1.1),
			cue("SoftBoom", "Burst", 0.55, 1.1, 1.15, 1),
			cue("FN_PunchyPoof", "Burst", 0.56, 0.9, 1.0),
			cue("ToyBlockB", "Burst", 1.0, 1, 1.2),
			cue("ToyBlockA", "Burst", 1.12, 0.8, 1.35),
			cue("FN_GlassPing", "Burst", 1.38, 0.7, 1.2),
			cue("ChimeCluster", "Burst", 1.46, 0.7, 1.3),
		},
		-- Supernova (hush 0.5, peak 0.62, twinkle 1.5): a humming swell and spiralling shimmer, a hush, a big magic
		-- burst with a low boom underneath, falling-star shimmer, glitter chime and the last twinkle.
		starfall = {
			cue("CosmicRiser", "Rise", 0, 0.9, 1.1),
			cue("RisingWhoosh", "Fly", 0, 0.9, 1.0),
			cue("FN_GlowSwell", "Burst", 0, 0.8, 1.0),
			cue("MagicRiser", "Burst", 0.12, 0.7, 1.3),
			cue("ChargeGlass", "Burst", 0.42, 0.6, 1.6),
			cue("FN_MagicBurst", "Burst", 0.62, 1.1, 1.0, 1),
			cue("SoftBoom", "Burst", 0.63, 0.7, 0.85),
			cue("FallingShimmer", "Burst", 0.8, 0.9, 1.1),
			cue("ChimeCluster", "Burst", 1.15, 0.7, 1.4),
			cue("FN_GlassPing", "Burst", 1.5, 0.7, 1.5),
		},
		-- Lantern Eclipse v2 (Balance.CosmeticPresentation.Eclipse: gather 0.3, eclipse 1.0, hush 1.55, release 1.7 s).
		-- The Hollowlight motif is LanternBell rung as a rising minor triad (x1, x1.19, x1.5): note 1 on ignite,
		-- notes 2 and 3 as the ghosts arrive. Saw riser and choir under the eclipse, a hush, then a deep boom,
		-- glass break and poof on release, and an ember shimmer tail. Every cue ends by 3.1 s (the anchor's life).
		lantern_eclipse = {
			cue("LanternBell", "Rise", 0, 0.55, 0.84),
			cue("RisingWhoosh", "Fly", 0, 0.9, 0.85),
			cue("LanternBell", "Burst", 0, 0.9, 1),
			cue("HL_SawRise", "Burst", 0.22, 1, 1),
			cue("GhostWhoo", "Burst", 0.32, 0.8, 1.25),
			cue("LanternBell", "Burst", 0.55, 0.8, 1.19),
			cue("LanternBell", "Burst", 0.8, 0.85, 1.5),
			cue("HL_Choir", "Burst", 0.85, 1, 0.85),
			cue("HL_ShadowSweep", "Burst", 0.98, 1, 1.15),
			cue("HL_EclipseBoom", "Burst", 1.7, 1, 0.8, 1),
			cue("SafetyGlass", "Burst", 1.71, 0.75, 1.15),
			cue("MagicPoof", "Burst", 1.72, 0.9, 0.85),
			cue("HL_EmberFall", "Burst", 1.85, 1, 1),
			cue("HL_Twinkle", "Burst", 2.55, 0.8, 1.1),
		},
	},
}
