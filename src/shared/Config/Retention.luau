-- Content identifiers/targets from GAME_DESIGN 11. Currency amounts for quests and gifts stay in Balance.
-- Codes (decision 99): UPPERCASE keys, letters/digits/underscore. Reward is a RewardGrant bundle:
--   { Coins = n?, Marbles = n?, Pull = "Glassies"|"Finishers"|"Rideables"?, Pulls = n?, Item = { Category, Id }? }
-- Starts/Expires are UTC Unix times (optional). StudioOnly codes never work in live servers (tests and QA).
-- Adding a live code needs a publish. Free Marbles are allowed through codes only.
return {
	Quests = {
		{ Id = "rounds", Name = "Win 3 rounds", Goal = 3, Observed = "RoundWins" },
		{ Id = "perfects", Name = "Land 2 Perfect Releases", Goal = 2, Observed = "Perfects" },
		{ Id = "heavy", Name = "Shatter a Heavy glassy", Goal = 1, Observed = "HeavyShatters" },
	},
	Codes = {
		RELEASE = { Reward = { Coins = 300 } },
		HALLOWEEN = { Reward = { Pull = "Finishers" }, Expires = 1794096000 }, -- ends Nov 8 2026 00:00 UTC
		-- Studio QA: one code per reward kind, plus an expired one.
		STUDIOCLASH = { StudioOnly = true, Reward = { Coins = 75 } },
		TESTMARBLES = { StudioOnly = true, Reward = { Marbles = 10 } },
		TESTKILN = { StudioOnly = true, Reward = { Pull = "Glassies" } },
		TESTFLYER = { StudioOnly = true, Reward = { Pull = "Rideables" } },
		TESTITEM = { StudioOnly = true, Reward = { Item = { Category = "Finishers", Id = "frost_pop" } } },
		TESTEXPIRED = { StudioOnly = true, Reward = { Coins = 1 }, Expires = 1 },
	},
	GroupId = 0, -- owner must supply this; free Marble grants remain disabled
}
