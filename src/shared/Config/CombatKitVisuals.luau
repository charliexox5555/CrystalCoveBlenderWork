-- Authored release identity and presentation; numbers live in Balance. Color/Accent: the power's own colours for
-- the v2 power VFX (docs/vfx/POWER_VFX_V2.md); the glassy tint is not used for powers.
return {
	hollowlight = {
		Name = "Lantern Seeds",
		Color = "#FFB347", -- signature colour (power VFX v2)
		Accent = "#9CFFD8",
		Description = "Clashes plant glowing seeds; three seeds burst into wisps that fly home.",
		ReleaseSound = "ChargeGlass",
		ContactSound = "ClinkLightA",
		MeshA = "Ring",
		MeshB = "CrystalChip",
	},
	pop = {
		Name = "Pressure Pop",
		Color = "#39D2FF", -- signature colour (power VFX v2)
		Accent = "#FF4A5A",
		Description = "Every third clash pops a pressure burst.",
		ReleaseSound = "BubblePop",
		ContactSound = "ClinkHeavy",
		MeshA = "Ring",
		MeshB = "BubbleDome",
	},
	jam = {
		Name = "Lid Guard",
		Color = "#FFC23D", -- signature colour (power VFX v2)
		Accent = "#FF5C86",
		Description = "Raises its lid to soften the next clash.",
		ReleaseSound = "LidClick",
		ContactSound = "LidBlock",
		MeshA = "GuardPlate",
		MeshB = "Ring",
	},
	prism = {
		Name = "Refraction Ray",
		Color = "#FFFFFF", -- signature colour (power VFX v2)
		Accent = "#C9A8FF",
		Description = "Charges a narrow prism ray that can miss.",
		ReleaseSound = "ChargeGlass",
		ContactSound = "ClinkLightA",
		MeshA = "Ring",
		MeshB = "CrystalChip",
	},
	crescent_axe = {
		Name = "Crescent Sweep",
		Color = "#8E5CFF", -- signature colour (power VFX v2)
		Accent = "#42A8DC",
		Description = "Winds up a glass axe at every second turnaround.",
		ReleaseSound = "AxeAir",
		ContactSound = "ClinkHeavy",
		MeshA = "CurvedSlash",
		MeshB = "CrystalChip",
	},
	briar_flask = {
		Name = "Thorn Bloom",
		Color = "#2FD38E", -- signature colour (power VFX v2)
		Accent = "#FF7AC8",
		Description = "Grows glass thorns that burst on its next clash.",
		ReleaseSound = "ClinkLightB",
		ContactSound = "ClinkLightA",
		MeshA = "Thorn",
		MeshB = "CrystalChip",
	},
	arc_coil = {
		Name = "Coil Discharge",
		Color = "#4FE8FF", -- signature colour (power VFX v2)
		Accent = "#FFFFFF",
		Description = "Charges on clashes, then fires a crackling arc.",
		ReleaseSound = "ElectricSnap",
		ContactSound = "ClinkLightA",
		MeshA = "Ring",
		MeshB = "CrystalChip",
	},
	milk_bottle = {
		Name = "Fresh Seal",
		Color = "#FFF6E0", -- signature colour (power VFX v2)
		Accent = "#6FB7FF",
		Description = "Foams over to seal a little damage once.",
		ReleaseSound = "BubblePop",
		ContactSound = "ClinkLightB",
		MeshA = "Ring",
		MeshB = "BubbleDome",
	},
	pickle_jar = {
		Name = "Brine Line",
		Color = "#5ECB3A", -- signature colour (power VFX v2)
		Accent = "#D8FF8A",
		Description = "Clashes leave a brief sticky brine tether.",
		ReleaseSound = "WaterSlap",
		ContactSound = "BubblePop",
		MeshA = "Droplet",
		MeshB = "Ring",
	},
	ketchup_bottle = {
		Name = "Splat Pop",
		Color = "#FF6A3D", -- signature colour (power VFX v2)
		Accent = "#FFD27A",
		Description = "Sticks a splat that pops on the next clash.",
		ReleaseSound = "WaterSlap",
		ContactSound = "BubblePop",
		MeshA = "Droplet",
		MeshB = "SplashSheet",
	},
	glass_cup = {
		Name = "Rim Rush",
		Color = "#6FD3FF", -- signature colour (power VFX v2)
		Accent = "#FFFFFF",
		Description = "Builds a bigger swing after two turnarounds.",
		ReleaseSound = "ChargeGlass",
		ContactSound = "ClinkHeavy",
		MeshA = "HalfRing",
		MeshB = "Ring",
	},
	water_jug = {
		Name = "Sloshback",
		Color = "#2FA8FF", -- signature colour (power VFX v2)
		Accent = "#BFF0FF",
		Description = "Stores two hits, then splashes back.",
		ReleaseSound = "WaterSlap",
		ContactSound = "WaterSlap",
		MeshA = "SplashSheet",
		MeshB = "Droplet",
	},
	lemonade_bottle = {
		Name = "Zest Volley",
		Color = "#FFD21F", -- signature colour (power VFX v2)
		Accent = "#6CC93A",
		Description = "Fires a fan of three zesty glass pips.",
		ReleaseSound = "BubblePop",
		ContactSound = "ClinkLightB",
		MeshA = "Droplet",
		MeshB = "Ring",
	},
	mason_jar = {
		Name = "Screw-Top Counter",
		Color = "#5FB4FF", -- signature colour (power VFX v2)
		Accent = "#FFC23D",
		Description = "Taking a heavy hit charges its next clash.",
		ReleaseSound = "LidClick",
		ContactSound = "ClinkHeavy",
		MeshA = "HalfRing",
		MeshB = "Ring",
	},
	hot_sauce = {
		Name = "Hot Streak",
		Color = "#FF4A2A", -- signature colour (power VFX v2)
		Accent = "#FFC24B",
		Description = "Heats up below half health for one fiery rush.",
		ReleaseSound = "PressureAir",
		ContactSound = "ClinkHeavy",
		MeshA = "Thorn",
		MeshB = "HalfRing",
	},
	crystal_tumbler = {
		Name = "Mirror Catch",
		Color = "#E6F2FF", -- signature colour (power VFX v2)
		Accent = "#6FC4FF",
		Description = "Catches part of a ray and returns a glint.",
		ReleaseSound = "ClinkLightA",
		ContactSound = "ClinkLightB",
		MeshA = "GuardPlate",
		MeshB = "CrystalChip",
	},
	chime = {
		Name = "Resonant Ring",
		Color = "#2FD8D0", -- signature colour (power VFX v2)
		Accent = "#E9FFFC",
		Description = "Rings out a glass pulse after two turnarounds.",
		ReleaseSound = "ChargeGlass",
		ContactSound = "ClinkLightB",
		MeshA = "Ring",
		MeshB = "HalfRing",
	},
	hourglass = {
		Name = "Second Turn",
		Color = "#FFA834", -- signature colour (power VFX v2)
		Accent = "#2FE68A",
		Description = "Below 65% HP, spins to heal 7%. Twice a round; 8s cooldown.",
		ReleaseSound = "ChargeGlass",
		ContactSound = "ClinkLightB",
		MeshA = "Droplet",
		MeshB = "Ring",
	},
	frostglobe = {
		Name = "Snowdrift",
		Color = "#5CC8FF", -- signature colour (power VFX v2)
		Accent = "#FFFFFF",
		Description = "Sends a frosty puff that slows the next swing.",
		ReleaseSound = "PressureAir",
		ContactSound = "ClinkLightA",
		MeshA = "PuffSheet",
		MeshB = "CrystalChip",
	},
	prism_blade = {
		Name = "Edgewake",
		Color = "#38CFFF", -- signature colour (power VFX v2)
		Accent = "#FFFFFF",
		Description = "Throws a crescent that cuts out and back, sharing one damage budget.",
		ReleaseSound = "AxeAir",
		ContactSound = "ClinkLightA",
		MeshA = "CurvedSlash",
		MeshB = "HalfRing",
	},
	rocket_pop = {
		Name = "Afterburn Swing",
		Color = "#FF8A2B", -- signature colour (power VFX v2)
		Accent = "#FFD34E",
		Description = "Ignites boosters for its next incoming swing.",
		ReleaseSound = "PressureAir",
		ContactSound = "BubblePop",
		MeshA = "Thorn",
		MeshB = "Ring",
	},
	glass_duck = {
		Name = "Bubble Buoy",
		Color = "#FFD83A", -- signature colour (power VFX v2)
		Accent = "#6FDDFF",
		Description = "Bubbles up to soften one dangerous clash.",
		ReleaseSound = "BubblePop",
		ContactSound = "BubblePop",
		MeshA = "BubbleDome",
		MeshB = "Ring",
	},
	comet = {
		Name = "Star Echo",
		Color = "#4FC3FF", -- signature colour (power VFX v2)
		Accent = "#FFC93C",
		Description = "Leaves one star that returns on its next turnaround.",
		ReleaseSound = "ChargeGlass",
		ContactSound = "ClinkLightB",
		MeshA = "CrystalChip",
		MeshB = "HalfRing",
	},
	glass_dragon = {
		Name = "Dragon Breath",
		Color = "#2EE6A8", -- signature colour (power VFX v2)
		Accent = "#FFE58A",
		Description = "Builds a sparkling breath, then sweeps a short cone.",
		ReleaseSound = "PressureAir",
		ContactSound = "ClinkLightB",
		MeshA = "PuffSheet",
		MeshB = "SplashSheet",
	},
	galaxy_orb = {
		Name = "Little Orbit",
		Color = "#7A5CFF", -- signature colour (power VFX v2)
		Accent = "#FFE8A9",
		Description = "Opens a tiny gravity well that bends one swing.",
		ReleaseSound = "ChargeGlass",
		ContactSound = "BubblePop",
		MeshA = "Ring",
		MeshB = "HalfRing",
	},
	-- Launch glassies (ROSTER_V2); descriptions match Glassies.luau.
	fishbowl = {
		Name = "Fish Flip",
		Color = "#2FA8FF", -- signature colour (power VFX v2)
		Accent = "#FF8A3D",
		Description = "A calm bowl with a tiny fish who thinks he's in charge.",
		ReleaseSound = "WaterSlap",
		ContactSound = "WaterSlap",
		MeshA = "Droplet",
		MeshB = "SplashSheet",
	},
	cookie_jar = {
		Name = "Crumb Toss",
		Color = "#E89A3C", -- signature colour (power VFX v2)
		Accent = "#FFE7B0",
		Description = "Generous and crumbly: bump it and it throws crumbs back.",
		ReleaseSound = "LidClick",
		ContactSound = "ClinkLightB",
		MeshA = "CrystalChip",
		MeshB = "Ring",
	},
	glass_top = {
		Name = "Spin Out",
		Color = "#FF4FA3", -- signature colour (power VFX v2)
		Accent = "#FFFFFF",
		Description = "Dizzy and delighted: whirls a glass ring all the way round.",
		ReleaseSound = "AxeAir",
		ContactSound = "ClinkLightA",
		MeshA = "Ring",
		MeshB = "HalfRing",
	},
	bubble_wand = {
		Name = "Bubble Trap",
		Color = "#5FD8FF", -- signature colour (power VFX v2)
		Accent = "#FF9BE0",
		Description = "Giggly: leaves a floating bubble that pops on whoever touches it.",
		ReleaseSound = "BubblePop",
		ContactSound = "BubblePop",
		MeshA = "BubbleDome",
		MeshB = "Ring",
	},
	piggy_bank = {
		Name = "Spare Change",
		Color = "#FF7AB0", -- signature colour (power VFX v2)
		Accent = "#FFC93C",
		Description = "Thrifty: saves every bump and shoots its savings back as coins.",
		ReleaseSound = "CapRattle",
		ContactSound = "ClinkLightB",
		MeshA = "CrystalChip",
		MeshB = "Ring",
	},
	light_bulb = {
		Name = "Power Surge",
		Color = "#FFD21F", -- signature colour (power VFX v2)
		Accent = "#FFFFFF",
		Description = "Bright idea, fragile ego: its charged clash steals the foe's power.",
		ReleaseSound = "ElectricSnap",
		ContactSound = "ElectricSnap",
		MeshA = "Ring",
		MeshB = "CrystalChip",
	},
	potion_flask = {
		Name = "Mystery Brew",
		Color = "#3FE07A", -- signature colour (power VFX v2)
		Accent = "#FF7AC8",
		Brews = { "#5ECB3A", "#FF7AC8", "#FFD34E" }, -- Cycle brew colours (slow, mark, heal)
		Description = "A bubbling mystery: the colour inside shows which brew comes next.",
		ReleaseSound = "BubblePop",
		ContactSound = "BubblePop",
		MeshA = "BubbleDome",
		MeshB = "HalfRing",
	},
	honey_bear = {
		Name = "Honey Puddle",
		Color = "#FFA31A", -- signature colour (power VFX v2)
		Accent = "#C96A00",
		Description = "Cuddly and sticky: leaves a honey blob that slows whoever swings through.",
		ReleaseSound = "WaterSlap",
		ContactSound = "BubblePop",
		MeshA = "BubbleDome",
		MeshB = "Ring",
	},
	crystal_ball = {
		Name = "Foresight",
		Color = "#9A7BFF", -- signature colour (power VFX v2)
		Accent = "#FFC93C",
		Description = "It saw this battle coming: a star strikes where the foe is about to be.",
		ReleaseSound = "ChargeGlass",
		ContactSound = "ClinkLightB",
		MeshA = "Ring",
		MeshB = "CrystalChip",
	},
	grizzly_guardian = {
		Name = "Guardian Roar",
		Color = "#FFB347", -- signature colour (power VFX v2)
		Accent = "#DDF6FF",
		Description = "The shelf's protector: a crystal guard that roars back when it blocks.",
		ReleaseSound = "LidClick",
		ContactSound = "LidBlock",
		MeshA = "GuardPlate",
		MeshB = "Ring",
	},
	glass_unicorn = {
		Name = "Rainbow Charge",
		Color = "#FF7AD9", -- signature colour (power VFX v2)
		Accent = "#8FE6FF",
		Description = "Its horn always finds the crack: a rainbow dash that breaks through guards.",
		ReleaseSound = "PressureAir",
		ContactSound = "ClinkHeavy",
		MeshA = "HalfRing",
		MeshB = "Ring",
	},
	glass_phoenix = {
		Name = "Ember Feathers",
		Color = "#FF6A1F", -- signature colour (power VFX v2)
		Accent = "#FFD34E",
		Description = "A proud firebird: the lower it gets, the brighter it burns.",
		ReleaseSound = "PressureAir",
		ContactSound = "ClinkLightA",
		MeshA = "Thorn",
		MeshB = "Ring",
	},
	-- Daily Rewards glassies (decision 115).
	whiskers = {
		Name = "Yarn Toss",
		Color = "#FF7FC4", -- signature colour (power VFX v2): pink yarn
		Accent = "#FFE27A", -- the gold bell
		Description = "A playful glass kitty: bats a yarn ball out and back that tangles whoever it hits.",
		ReleaseSound = "AxeAir",
		ContactSound = "ClinkLightA",
		MeshA = "BubbleDome",
		MeshB = "Ring",
	},
	midnight_moon = {
		Name = "Lullaby",
		Color = "#7C83FF", -- signature colour (power VFX v2): moonlit violet
		Accent = "#FFD25A", -- star gold
		Description = "The sleepy moon of Midnights Studio: its lullaby makes the foe drowsy, and their next clash wakes them with a bonk.",
		ReleaseSound = "ChargeGlass",
		ContactSound = "ChimeCluster",
		MeshA = "Ring",
		MeshB = "CrystalChip",
	},
}
