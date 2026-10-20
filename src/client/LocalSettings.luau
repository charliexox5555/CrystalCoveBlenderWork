-- The local player's Settings screen choices that presentation code reads (decision 99). SettingsController
-- stamps them as PlayerGui attributes; these readers are cheap and safe to call every frame.
local Players = game:GetService("Players")
local LocalSettings = {}

local function attribute(name)
	local player = Players.LocalPlayer
	local gui = player and player:FindFirstChildOfClass("PlayerGui")
	return gui and gui:GetAttribute(name)
end

-- Large Effects off: every effect takes its low-detail branch (fewer particles, no lights, trails or grades).
function LocalSettings.lowEffects(): boolean
	return attribute("LargeEffects") == false
end

-- Auto-Cast Powers on: the CAST button never shows; the server fires powers by themselves.
function LocalSettings.autoCast(): boolean
	return attribute("AutoCast") == true
end

-- Hide Others' Cosmetics on: other players' flyer effects and finisher shows are skipped.
function LocalSettings.hideOthers(): boolean
	return attribute("HideCosmetics") == true
end

return LocalSettings
