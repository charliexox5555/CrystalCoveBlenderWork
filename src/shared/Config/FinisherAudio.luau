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
		-- Launch finishers (COSMETICS_V2 §4.2; show timings in Config/FinisherShows).
		-- Frost Pop (peak 0.4): frost crackle as the cube forms, glass shatter, scatter, chime, a last ping.
		frost_pop = {
			cue("MagicRiser", "Rise", 0, 0.9, 1.15),
			cue("RisingWhoosh", "Fly", 0, 0.9, 1.2),
			cue("FN_IceCrackle", "Burst", 0.05, 0.8, 1.1),
			cue("ChargeGlass", "Burst", 0.12, 0.6, 1.5),
			cue("SafetyGlass", "Burst", 0.4, 1, 1.15, 1),
			cue("ShatterScatter", "Burst", 0.5, 0.8, 1.3),
			cue("ChimeCluster", "Burst", 0.8, 0.8, 1.25),
			cue("FN_GlassPing", "Burst", 1.2, 0.5, 1.7),
		},
		-- Gumball (drop lands 0.25, crank to the peak at 0.5): a knock, two crank clicks, a poof and pop, the
		-- gumballs rattling as they bounce, then pops as they burst in turn.
		gumball = {
			cue("PartyHorn", "Rise", 0.05, 0.6, 1.25),
			cue("RisingWhoosh", "Fly", 0, 1, 1.3),
			cue("ToyBlockB", "Burst", 0.25, 0.8, 1.4),
			cue("LidClick", "Burst", 0.32, 0.9, 1.0),
			cue("LidClick", "Burst", 0.42, 0.9, 1.15),
			cue("MagicPoof", "Burst", 0.5, 1.1, 1.1, 1),
			cue("BubblePop", "Burst", 0.52, 1, 0.8),
			cue("CapRattle", "Burst", 0.7, 0.9, 1.2),
			cue("BubblePop", "Burst", 1.15, 1, 1.1),
			cue("BubblePop", "Burst", 1.27, 0.9, 1.25),
			cue("BubblePop", "Burst", 1.39, 0.9, 1.4),
			cue("FN_GlassPing", "Burst", 1.5, 0.5, 1.6),
		},
		-- Honeyburst (peak 0.5): buzzing bees, a honey splash, a poof, chimes and drips.
		honeyburst = {
			cue("FN_BeeBuzz", "Rise", 0, 0.6, 1.0),
			cue("RisingWhoosh", "Fly", 0, 0.9, 1.2),
			cue("FN_BeeBuzz", "Burst", 0.05, 0.7, 1.15),
			cue("ChargeGlass", "Burst", 0.1, 0.6, 1.3),
			cue("SplashBloom", "Burst", 0.5, 1.1, 1.0, 1),
			cue("FN_PunchyPoof", "Burst", 0.51, 0.7, 1.2),
			cue("ChimeCluster", "Burst", 0.9, 0.8, 1.1),
			cue("Bubbles", "Burst", 1.15, 0.5, 1.3),
			cue("FN_GlassPing", "Burst", 1.35, 0.5, 1.4),
		},
		-- Hocus Pop (peak 0.55, chain puffs 1.2/1.32/1.44): bubbling brew and a magic swell, the poof, a ribbit as
		-- the frog hops, three pops and a chime.
		hocus_pop = {
			cue("MagicRiser", "Rise", 0, 0.8, 0.95),
			cue("RisingWhoosh", "Fly", 0, 0.9, 1.1),
			cue("Bubbles", "Burst", 0.1, 0.7, 1.0),
			cue("FN_GlowSwell", "Burst", 0.2, 0.6, 1.3),
			cue("MagicPoof", "Burst", 0.55, 1.1, 1.0, 1),
			cue("FN_Ribbit", "Burst", 0.88, 0.8, 1.15),
			cue("BubblePop", "Burst", 1.2, 1, 1.0),
			cue("BubblePop", "Burst", 1.32, 1, 1.2),
			cue("BubblePop", "Burst", 1.44, 1, 1.4),
			cue("ChimeCluster", "Burst", 1.5, 0.7, 1.3),
		},
		-- Petalstorm (peak 0.55, chimes from 1.3): a shimmering swell, the bloom poof, a wind swirl, and a chime
		-- for each flower.
		petalstorm = {
			cue("MagicRiser", "Rise", 0, 0.8, 1.2),
			cue("RisingWhoosh", "Fly", 0, 0.9, 1.25),
			cue("ChargeGlass", "Burst", 0.2, 0.6, 1.4),
			cue("FN_GlowSwell", "Burst", 0.25, 0.5, 1.4),
			cue("MagicPoof", "Burst", 0.55, 1.0, 1.15, 1),
			cue("FN_WindSwirl", "Burst", 0.6, 0.8, 1.1),
			cue("ChimeCluster", "Burst", 1.3, 0.7, 1.2),
			cue("ChimeCluster", "Burst", 1.42, 0.6, 1.35),
			cue("FN_GlassPing", "Burst", 1.5, 0.5, 1.5),
		},
		-- Starmane (peak 0.55, bow 1.4): wood-block hoof clops down the rainbow, a magic poof over a soft boom as
		-- the column fires, falling shimmer for the star rain, and a sparkle for the bow.
		starmane = {
			cue("MagicRiser", "Rise", 0, 0.9, 1.0),
			cue("RisingWhoosh", "Fly", 0, 0.9, 1.0),
			cue("ToyBlockA", "Burst", 0.1, 0.7, 1.5),
			cue("ToyBlockB", "Burst", 0.2, 0.7, 1.6),
			cue("ToyBlockA", "Burst", 0.3, 0.7, 1.5),
			cue("ToyBlockB", "Burst", 0.4, 0.7, 1.6),
			cue("MagicPoof", "Burst", 0.55, 1.1, 1.0, 1),
			cue("SoftBoom", "Burst", 0.56, 0.7, 1.0),
			cue("FallingShimmer", "Burst", 0.8, 0.9, 1.2),
			cue("ChimeCluster", "Burst", 1.45, 0.8, 1.1),
		},
		-- Emberwing (P 0.55, P2 1.25): the Phoenix set's three-note sun chime (x1.0, x1.25, x1.5) rises across the
		-- show: note 1 at the impact, note 2 at the climb, note 3 on the dive with the big magic burst.
		emberwing = {
			cue("CosmicRiser", "Rise", 0, 0.9, 0.95),
			cue("RisingWhoosh", "Fly", 0, 0.9, 0.95),
			cue("FN_GlowSwell", "Burst", 0, 0.7, 0.9),
			cue("FN_SunChime", "Burst", 0.55, 0.9, 1.0),
			cue("MagicPoof", "Burst", 0.56, 0.8, 0.85),
			cue("MagicRiser", "Burst", 0.7, 0.6, 0.9),
			cue("FN_SunChime", "Burst", 0.9, 0.9, 1.25),
			cue("FN_SunChime", "Burst", 1.25, 1.0, 1.5),
			cue("FN_MagicBurst", "Burst", 1.25, 1.1, 0.9, 1),
			cue("SafetyGlass", "Burst", 1.26, 0.7, 1.0),
			cue("FallingShimmer", "Burst", 1.4, 0.9, 1.0),
			cue("FN_GlassPing", "Burst", 1.5, 0.5, 1.3),
		},
		-- Basic Shatter: inventory preview only (fights use the glassy's own break sound). Not a catalog item.
		basic_shatter = {
			cue("ShatterHeavy", "Burst", 0.3, 0.9, 1.05, 1),
			cue("ShatterScatter", "Burst", 0.38, 0.7, 1.2),
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
