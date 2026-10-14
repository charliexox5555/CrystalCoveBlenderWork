--!strict
-- Glassy powers (GAME_DESIGN 3.5). Every glassy has one Passive (always on, or triggered by
-- hits) and one Special "burst" power that FIRES BY ITSELF at random moments in the round (no
-- button; Balance.Fight.Power*). Aimed specials (Params.LandChance) can miss depending on where
-- the glassies are when they fire. Glassies reference powers by Id in Config/Glassies
-- (Passive / Special) and may give them their own display name.
-- All numbers here are tunable; run the balance simulator after changing them.

export type PowerDef = {
	Id: string,
	Name: string,
	Description: string,
	Params: { [string]: number },
}

local Powers = {}

Powers.Passives = {
	fizz_burst = {
		Id = "fizz_burst",
		Name = "Fizz Burst",
		Description = "Every 4th hit fizzes over for extra damage.",
		Params = { Every = 4, DamageBonus = 0.75 },
	},
	sharp_edge = {
		Id = "sharp_edge",
		Name = "Sharp Edge",
		Description = "Hits leave cracks that keep chipping away.",
		Params = { BleedFraction = 0.15, BleedSeconds = 3, MaxStacks = 3 },
	},
	sturdy = {
		Id = "sturdy",
		Name = "Sturdy",
		Description = "Thick glass: takes less damage from every hit.",
		Params = { DamageTaken = 0.88 },
	},
	thorns = {
		Id = "thorns",
		Name = "Spiky Rim",
		Description = "Bounces part of the damage back.",
		Params = { Reflect = 0.12 },
	},
	sticky = {
		Id = "sticky",
		Name = "Sticky",
		Description = "Hits make the other glass swing weaker for a moment.",
		Params = { SwingLoss = 0.2, Seconds = 3, MaxStacks = 3 },
	},
	lucky = {
		Id = "lucky",
		Name = "Lucky Glint",
		Description = "Much higher chance to land a critical hit.",
		Params = { CritBonus = 0.2 },
	},
	second_wind = {
		Id = "second_wind",
		Name = "Second Wind",
		Description = "Once per round, survives a shattering hit and patches itself up a little.",
		Params = { HealFraction = 0.08 },
	},
	glow_core = {
		Id = "glow_core",
		Name = "Glow Core",
		Description = "Slowly heals during the round.",
		Params = { HealPerSecond = 0.0055 },
	},
	momentum = {
		Id = "momentum",
		Name = "Momentum",
		Description = "Each hit in a row without a crit taken builds extra power.",
		Params = { PerStack = 0.04, MaxStacks = 5 },
	},
} :: { [string]: PowerDef }

Powers.Specials = {
	slam = {
		Id = "slam",
		Name = "Slam",
		Description = "The next hit within 3 seconds is a big smash that knocks back hard.",
		Params = { Seconds = 3, DamageMult = 2.3, KnockbackMult = 1.5 },
	},
	shield = {
		Id = "shield",
		Name = "Shield",
		Description = "Blocks all damage for a short time.",
		Params = { Seconds = 1.8 },
	},
	pump = {
		Id = "pump",
		Name = "Big Swing",
		Description = "Swings much harder for a few seconds.",
		Params = { Seconds = 4, SwingMult = 1.5, DamageMult = 1.3 },
	},
	freeze = {
		Id = "freeze",
		Name = "Freeze",
		Description = "Freezes the other glass: it barely swings and turns brittle, taking extra damage.",
		Params = { Seconds = 3, LandChance = 0.7, Brittle = 1.5 },
	},
	beam = {
		Id = "beam",
		Name = "Beam",
		Description = "Zaps the other glass from a distance.",
		Params = { MaxHpFraction = 0.095, LandChance = 0.65 },
	},
	rage = {
		Id = "rage",
		Name = "Rage",
		Description = "Goes wild: +75% damage for a few seconds.",
		Params = { Seconds = 3, DamageMult = 1.75 },
	},
	glaze = {
		Id = "glaze",
		Name = "Glaze",
		Description = "Seals cracks and heals.",
		Params = { HealFraction = 0.06 },
	},
} :: { [string]: PowerDef }

function Powers.passive(id: string): PowerDef
	local def = Powers.Passives[id]
	assert(def, "Unknown passive: " .. tostring(id))
	return def
end

function Powers.special(id: string): PowerDef
	local def = Powers.Specials[id]
	assert(def, "Unknown special: " .. tostring(id))
	return def
end

return Powers
