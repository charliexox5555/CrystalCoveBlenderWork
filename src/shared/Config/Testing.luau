--!strict
-- Playtest switches. Change, then publish, to take effect in live servers.
return {
	-- Every player who joins while Enabled gets Marbles once per Wave (rejoining never stacks).
	-- Start a new playtest round by changing Wave; turn off by setting Enabled = false.
	TesterMarbles = {
		Enabled = true,
		Amount = 10000,
		Wave = "playtest-1",
	},
}
