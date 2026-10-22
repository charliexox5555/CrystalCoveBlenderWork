-- Badges (decision 118, docs/design/BADGES.md). The five free badges of launch day: created through Open Cloud by
-- tools/opencloud/badges.py with the stained-glass icons from tools/ui/badge_art.py (assets/badges/png).
-- Id = nil until the badge exists on Roblox: the profile still records it as earned, and the award follows on the
-- player's next check once the id is filled in (BadgeService on the server; rules in Server/Data/BadgeRules).
local Badges = {}

-- Award order when several are due at once (the Welcome toast first).
Badges.Order = { "Welcome", "FirstWin", "LegendaryFind", "Level10", "DailyWeek" }

Badges.ByKey = {
	Welcome = {
		Id = nil,
		Name = "Welcome to Glass Clash!",
		Description = "You joined Glass Clash! Collect glassies, pick one and swing it into battle.",
		Icon = "assets/badges/png/welcome.png",
	},
	FirstWin = {
		Id = nil,
		Name = "First Win!",
		Description = "Win a round against another player. Bots don't count!",
		Icon = "assets/badges/png/first_win.png",
	},
	LegendaryFind = {
		Id = nil,
		Name = "Legendary Find",
		Description = "Pull a Legendary or Mythic from any Kiln.",
		Icon = "assets/badges/png/legendary_find.png",
	},
	Level10 = {
		Id = nil,
		Name = "Level 10",
		Description = "Reach level 10 by playing matches.",
		Icon = "assets/badges/png/level_10.png",
	},
	DailyWeek = {
		Id = nil,
		Name = "Midnight's Week",
		Description = "Claim all 7 days of Daily Rewards and meet Midnight.",
		Icon = "assets/badges/png/daily_week.png",
	},
}

-- What earns them (BadgeRules).
Badges.Level = 10
Badges.FindRarities = { Legendary = true, Mythic = true }
Badges.WeekGlassy = "midnight_moon" -- the Day 7 glassy (decision 115): owning it means a full Daily week was claimed
Badges.WeekDays = 7

-- BadgeService: how often everyone's state-based badges (level, Daily week) are re-checked, retries per Roblox call
-- (waits 1, 2 s between tries) and how long a badge's enabled state is trusted.
Badges.CheckSeconds = 20
Badges.Retries = 3
Badges.RetryBaseSeconds = 1
Badges.InfoCacheSeconds = 600

return Badges
