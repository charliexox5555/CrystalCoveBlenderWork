--!strict
-- Crown Hill: the featured arena's King of the Hill mode (decision 105, docs/design/FEATURED_STAGE.md).
-- Pure data. Kept out of Balance.luau so it doesn't collide with other workstreams; HillRules and HillService read it.
-- Coins are balanced against normal play (about 13 coins a minute, Balance.EconomyModel): a King earns about the
-- same per minute as a player winning normal matches, a long reign is a short treat, and a daily cap keeps the hill an
-- add-on instead of a farm.
return {
	Enabled = true,
	Title = "CROWN HILL",
	PadColor = "#FFC94A", -- the King's pad glow
	-- Hill fights are one sudden-death round: 1 heart each.
	Hearts = 1,
	-- The King defends this many times, then retires undefeated and the hill goes back to the Crown Bot.
	ReignCap = 5,
	-- The King steps down after this many fights in a row without aiming (AFK).
	AfkFights = 2,
	-- Pause after a hill fight before the next one starts (lets the crown moment play).
	GapSeconds = 4,
	-- With nobody in line, the Crown Bot challenges a player King after this long.
	BotChallengeSeconds = 10,
	-- A line member farther than this from the featured arena when their turn comes loses their spot.
	LineRadius = 90,
	MaxLine = 12,
	Bot = {
		Name = "Crown Bot",
		Skill = 0.5, -- medium: a kid with Commons beats it about half the time
	},
	Coins = {
		TickSeconds = 5, -- +1 coin per tick while you are King and a hill fight is running
		Tick = 1,
		Take = 25, -- taking the crown (from a player or the Crown Bot)
		Defence = 15, -- each defence won
		Retire = 100, -- retiring undefeated after ReignCap defences
		Loss = 5, -- losing a hill fight, just a thank-you
		DailyCap = 500, -- all Crown Hill coins per UTC day; play goes on after the cap, coins stop
	},
	-- Level XP for a hill fight, as a share of a normal match's XP (LevelRules.matchXp).
	XpShare = 0.5,
	-- Retiring undefeated also gives one free crate ticket, once per UTC day (spent in the Shop, odds shown there).
	-- Alternates by day between these FreePulls categories.
	RetireTickets = { "Finishers", "Rideables" },
}
