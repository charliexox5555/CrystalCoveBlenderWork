-- Small UI sound set (click, hover tick, open, close, tab, purchase success, error).
-- Cues stay silent until their ids exist in Config/Audio (UiClick, UiHover, UiOpen, UiClose, UiTab,
-- UiSuccess, UiError), so the shared Button/Window code can call play() before the sounds are approved.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Audio: { [string]: string } = require(RS.Shared.Config.Audio) :: any
local UiAudio = {}

-- Volume and pitch are per cue; one shared Sound per cue is restarted rather than cloned.
local Cues = {
	Click = { Key = "UiClick", Volume = 0.45, Pitch = 1 },
	Hover = { Key = "UiHover", Volume = 0.1, Pitch = 1.8 },
	Open = { Key = "UiOpen", Volume = 0.4, Pitch = 1.15 },
	Close = { Key = "UiClose", Volume = 0.35, Pitch = 0.85 },
	Tab = { Key = "UiTab", Volume = 0.4, Pitch = 1.25 },
	Success = { Key = "UiSuccess", Volume = 0.45, Pitch = 1 },
	Error = { Key = "UiError", Volume = 0.35, Pitch = 0.9 },
}
local sounds: { [string]: Sound } = {}
local group: SoundGroup? = nil

local function muted(): boolean
	local gui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	-- The music controller's mute also silences UI sounds once it publishes this attribute.
	return gui ~= nil and (gui:GetAttribute("MusicMuted") == true or gui:GetAttribute("UiSoundsMuted") == true)
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
		sound.Name, sound.SoundId, sound.Volume, sound.PlaybackSpeed = cue, id, spec.Volume, spec.Pitch
		sound.SoundGroup = group
		sound.Parent = group
		sounds[cue] = sound
	end
	sound.TimePosition = 0
	sound:Play()
end

return UiAudio
