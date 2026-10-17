-- Small UI sound set (click, hover tick, open, close, tab, purchase success, error).
-- Cues stay silent until their ids exist in Config/Audio (UiClick, UiHover, UiOpen, UiClose, UiTab,
-- UiSuccess, UiError), so the shared Button/Window code can call play() before the sounds are approved.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Audio: { [string]: string } = require(RS.Shared.Config.Audio) :: any
local Levels = require(RS.Shared.Config.UiMotion).Sounds
local UiAudio = {}

-- Volume and pitch are per cue; one shared Sound per cue is restarted rather than cloned.
local Cues = {
	Click = { Key = "UiClick" },
	Hover = { Key = "UiHover" },
	Open = { Key = "UiOpen" },
	Close = { Key = "UiClose" },
	Tab = { Key = "UiTab" },
	Success = { Key = "UiSuccess" },
	Error = { Key = "UiError" },
}
local sounds: { [string]: Sound } = {}
local group: SoundGroup? = nil

local function muted(): boolean
	local gui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	-- UI sounds follow only their own switch, never the music mute.
	return gui ~= nil and gui:GetAttribute("UiSoundsMuted") == true
end

function UiAudio.play(cue: string)
	local spec = Cues[cue]
	local id = spec and Audio[spec.Key]
	if not spec or not id or muted() then
		return
	end
	if not group then
		group = Instance.new("SoundGroup")
		group.Name, group.Volume = "UiSounds", 1
		group.Parent = SoundService
	end
	local sound = sounds[cue]
	if not sound then
		sound = Instance.new("Sound")
		local level = Levels[cue]
		sound.Name, sound.SoundId, sound.Volume, sound.PlaybackSpeed = cue, id, level.Volume, level.Pitch
		sound.RollOffMode = Enum.RollOffMode.Linear
		sound.SoundGroup = group
		sound.Parent = group
		sounds[cue] = sound
	end
	sound.TimePosition = 0
	sound:Play()
	UiAudio.LastPlayed = cue
end

return UiAudio
