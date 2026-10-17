--!strict
-- Finisher sound design (names from Config/Audio). Each cue fires at `At` seconds after its phase:
--   Rise  = the winner starts lifting (fight only, Feel.FinisherPause after the knockout)
--   Fly   = the winner launches at the loser (fight only, + Feel.FinisherRiseSeconds)
--   Burst = FinisherFX starts (fight impact and the inventory preview)
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
		-- Crystal Pop: shimmering charge, rising swish, bright glass shatter, glitter tail.
		glass_burst = {
			cue("MagicRiser", "Rise", 0, 1, 1.1),
			cue("RisingWhoosh", "Fly", 0, 1, 1.15),
			cue("SafetyGlass", "Burst", 0, 1, 1.1, 1),
			cue("ShatterScatter", "Burst", 0.1, 0.9, 1.2),
			cue("ChimeCluster", "Burst", 0.35, 0.9, 1.15),
		},
		-- Party Pop: party toot, whoosh, popper poof, confetti patter.
		party_burst = {
			cue("PartyHorn", "Rise", 0.05, 0.9, 1.15),
			cue("RisingWhoosh", "Fly", 0, 1, 1.25),
			cue("MagicPoof", "Burst", 0, 1.2, 1.2, 1),
			cue("BubblePop", "Burst", 0.02, 1.2, 0.75),
			cue("CapRattle", "Burst", 0.1, 1.2, 1.1),
			cue("CapRattle", "Burst", 0.66, 0.9, 1.3),
		},
		-- Bubble Bloom: bubbling swell, splash bloom, a ripple of pops as the bubbles burst.
		bubble_bloom = {
			cue("Bubbles", "Rise", 0, 0.8, 1.2),
			cue("RisingWhoosh", "Fly", 0, 0.9, 1.35),
			cue("SplashBloom", "Burst", 0, 1.1, 1.05, 1),
			cue("Bubbles", "Burst", 0.15, 0.7, 1.35),
			cue("BubblePop", "Burst", 0.8, 1.1, 1.0),
			cue("BubblePop", "Burst", 0.87, 1.0, 1.2),
			cue("BubblePop", "Burst", 0.94, 0.9, 1.4),
		},
		-- Block Boom: blocks rattle on the rise, heavy swish, soft boom, toy blocks tumbling down.
		brick_boom = {
			cue("ToyBlockA", "Rise", 0.05, 0.8, 0.9),
			cue("ToyBlockB", "Rise", 0.3, 0.8, 1.05),
			cue("RisingWhoosh", "Fly", 0, 1, 0.85),
			cue("SoftBoom", "Burst", 0, 1.1, 1.15, 1),
			cue("ToyBlockA", "Burst", 0.48, 1, 1.0),
			cue("ToyBlockB", "Burst", 0.6, 0.9, 1.15),
			cue("ToyBlockA", "Burst", 0.78, 0.8, 1.3),
		},
		-- Pocket Nova: cosmic riser, stars gather, nova burst, falling-star shimmer and glitter.
		starfall = {
			cue("CosmicRiser", "Rise", 0, 0.9, 1.1),
			cue("RisingWhoosh", "Fly", 0, 0.9, 1.0),
			cue("ChargeGlass", "Burst", 0, 0.6, 1.5),
			cue("MagicPoof", "Burst", 0.3, 1, 0.85, 1),
			cue("FallingShimmer", "Burst", 0.32, 0.9, 1.1),
			cue("ChimeCluster", "Burst", 0.6, 0.6, 1.4),
		},
		-- Lantern Eclipse (Balance.CosmeticPresentation.Eclipse: eclipse 0.55 s, release 0.85 s):
		-- lantern bell pops in, ghosts whoo as they swoop, rising shimmer under the moon, then a
		-- release poof with the lantern's glass bursting and a glittering fade.
		lantern_eclipse = {
			cue("LanternBell", "Rise", 0, 0.7, 0.9),
			cue("RisingWhoosh", "Fly", 0, 0.9, 0.85),
			cue("LanternBell", "Burst", 0, 0.9, 1.05),
			cue("GhostWhoo", "Burst", 0.05, 1, 1.2),
			cue("MagicRiser", "Burst", 0.4, 0.8, 1.25),
			cue("MagicPoof", "Burst", 0.85, 1.2, 0.9, 1),
			cue("SafetyGlass", "Burst", 0.87, 0.7, 1.2),
			cue("ChimeCluster", "Burst", 1.0, 0.8, 0.95),
		},
	},
}
