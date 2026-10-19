-- Run in Play / Client through the MCP. Stages one kit's real event sequence (Ready -> cast -> release -> contact)
-- through the real CombatEffects + PowerFX pipeline; see src/client/Dev/PowerVFXPreview.luau.
-- KIT: any release kit id, or "Cleanup" (always finish with Cleanup to hand the camera back).
-- Options: Stop (freeze the clock at t), Slow (time divisor), Zoom (1 = default fight camera), Manual, Miss, Low, Foe.
local KIT = "glass_dragon"
local OPTIONS = { Stop = 2.05, Zoom = 0.5, Manual = true }
local preview = game.Players.LocalPlayer.PlayerScripts.Client.Dev.PowerVFXPreview
return require(preview)(KIT, OPTIONS)
