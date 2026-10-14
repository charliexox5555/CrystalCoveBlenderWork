-- Run in Studio Play / Server. All world setup is performed reproducibly by FightService.
-- No Rojo-managed script is edited from Studio.
local dev = game.ServerStorage:FindFirstChild("FightDev")
assert(dev, "Start Play after Rojo has synced FightService")
return dev:Invoke("BotVsBot", "pop", "prism", 101, true)
