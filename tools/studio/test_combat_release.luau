-- Creator-operated check: run in Play / Server, one pair at a time. No grants or paid actions.
local pair = 1 -- 1: Pop/Axe, 2: Jam/Coil, 3: Prism/Briar
local pairs = { { "pop", "crescent_axe" }, { "jam", "arc_coil" }, { "prism", "briar_flask" } }
local dev = game.ServerStorage:FindFirstChild("FightDev")
assert(dev, "Start Play and use Server context")
local ids = assert(pairs[pair], "Pair must be 1, 2 or 3")
return dev:Invoke("BotVsBot", ids[1], ids[2], 1000 + pair, true, true)
