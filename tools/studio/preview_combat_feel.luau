-- Run in Play / Client through the MCP. Stages one CombatFeel beat (slowed) for a screenshot; see
-- src/client/Dev/CombatFeelPreview.luau. Modes: Glance, Solid, Smash, Crit, Block, Perfect, Manual, KO, Victory,
-- Tension, Cleanup (always finish with Cleanup to hand the camera back).
local MODE, SLOW = "Crit", 60
local preview = game.Players.LocalPlayer.PlayerScripts.Client.Dev.CombatFeelPreview
return require(preview)(MODE, SLOW)
