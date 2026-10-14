-- Content identifiers/targets from GAME_DESIGN 11. Currency amounts stay in Balance.
return {
	Quests = {
		{ Id = "rounds", Name = "Win 3 rounds", Goal = 3, Observed = "RoundWins" },
		{ Id = "perfects", Name = "Land 2 Perfect Releases", Goal = 2, Observed = "Perfects" },
		{ Id = "heavy", Name = "Shatter a Heavy glassy", Goal = 1, Observed = "HeavyShatters" },
	},
	Codes = { STUDIOCLASH = { StudioOnly = true, Reward = "QuestCoins" } },
	GroupId = 0, -- owner must supply this; free Marble grants remain disabled
}
