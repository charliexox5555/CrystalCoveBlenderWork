--!strict
-- Player settings (decision 99): the Settings screen's rows, their defaults and validation. Pure, so the server
-- (SettingsService), the client (SettingsController) and Lune tests share one normalize().
-- Volumes are 0..1. Toggles are booleans. Older saves from the music-only prefs ({ Muted, Volume }) migrate in.
local Settings = {}

export type Values = {
	Master: number,
	Music: number,
	SFX: number,
	BotPlay: boolean,
	AutoCast: boolean,
	LargeEffects: boolean,
	ReducedMotion: boolean,
	HideCosmetics: boolean,
}

Settings.Defaults = {
	Master = 1,
	Music = 0.8,
	SFX = 1,
	BotPlay = true,
	AutoCast = false,
	LargeEffects = true,
	ReducedMotion = false,
	HideCosmetics = false,
} :: Values

Settings.Sliders = { "Master", "Music", "SFX" }
Settings.Toggles = { "BotPlay", "AutoCast", "LargeEffects", "ReducedMotion", "HideCosmetics" }

Settings.Store = {
	Name = "GlassClashSettings_v1",
	LegacyMusicName = "GlassClashMusicPrefs_v1", -- read once to migrate the old music mute/volume
	SetRateSeconds = 0.2,
	SaveDelaySeconds = 8,
}

local function volume(value: any, fallback: number): number
	if type(value) == "number" and value == value and math.abs(value) < math.huge then
		return math.clamp(math.round(value * 100) / 100, 0, 1)
	end
	return fallback
end

-- Any table (a save, a client request, nil) becomes a complete, valid settings table.
function Settings.normalize(raw: any): Values
	local out = table.clone(Settings.Defaults)
	if type(raw) ~= "table" then
		return out
	end
	for _, key in Settings.Sliders do
		out[key] = volume(raw[key], out[key])
	end
	for _, key in Settings.Toggles do
		if type(raw[key]) == "boolean" then
			out[key] = raw[key]
		end
	end
	return out :: Values
end

-- Old music-only prefs: Muted = true -> Music 0, otherwise their Volume.
function Settings.fromLegacyMusic(raw: any): Values
	local out = table.clone(Settings.Defaults)
	if type(raw) == "table" then
		out.Music = if raw.Muted == true then 0 else volume(raw.Volume, out.Music)
	end
	return out :: Values
end

-- One field change from the client: valid name and value, or nil.
function Settings.change(current: Values, key: any, value: any): Values?
	if type(key) ~= "string" then
		return nil
	end
	local updated = table.clone(current)
	if table.find(Settings.Sliders, key) then
		if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
			return nil
		end
		updated[key] = volume(value, current[key])
	elseif table.find(Settings.Toggles, key) then
		if type(value) ~= "boolean" then
			return nil
		end
		updated[key] = value
	else
		return nil
	end
	return updated :: Values
end

return Settings
