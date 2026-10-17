-- Plays a finisher's timed sound cues (Config/FinisherAudio). Client-only and cosmetic.
-- Every cue belongs to an `owner` Instance: cues still waiting are skipped and sounds already playing
-- stop as soon as the owner is destroyed (fight cleanup, preview replay or closing the inventory).
-- A client-wide voice cap keeps several arenas finishing at once from stacking up.
local RS = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Audio = require(RS.Shared.Config.Audio)
local AudioCues = require(RS.Shared.Config.AudioCues)
local Config = require(RS.Shared.Config.FinisherAudio)
local FinisherAudio = {}
local voices = {} -- { Sound, Priority }, oldest first
local handles = setmetatable({}, { __mode = "k" })

local function prune()
	for i = #voices, 1, -1 do
		if not voices[i].Sound.Parent then
			table.remove(voices, i)
		end
	end
end

local function claim(priority)
	prune()
	if #voices < Config.MaxVoices then
		return true
	end
	if priority ~= 1 then
		return false
	end
	for i, voice in voices do
		if voice.Priority ~= 1 then
			voice.Sound:Destroy()
			table.remove(voices, i)
			return true
		end
	end
	voices[1].Sound:Destroy()
	table.remove(voices, 1)
	return true
end

local function play(cue, emitter, volume)
	local id = Audio[cue.Sound]
	if not id or not claim(cue.Priority) then
		return nil
	end
	local trim = AudioCues[id]
	local sound = Instance.new("Sound")
	sound.Name = "Finisher_" .. cue.Sound
	sound.SoundId = id
	sound.Volume = (cue.Volume or 1) * (if trim then trim.Volume else 0.35) * volume
	sound.PlaybackSpeed = (cue.Pitch or 1) * (if trim then trim.Pitch else 1)
	sound.RollOffMinDistance, sound.RollOffMaxDistance = Config.RollOffMin, Config.RollOffMax
	sound.TimePosition = if trim then trim.Start else 0
	sound.Parent = emitter or SoundService
	sound:Play()
	table.insert(voices, { Sound = sound, Priority = cue.Priority })
	local seconds = (if trim then trim.Seconds else 2) / sound.PlaybackSpeed
	local fade = math.min(seconds, if trim then trim.Fade else 0.05)
	task.delay(math.max(0, seconds - fade), function()
		if sound.Parent then
			TweenService:Create(sound, TweenInfo.new(fade), { Volume = 0 }):Play()
		end
	end)
	task.delay(seconds + 0.05, function()
		sound:Destroy()
	end)
	return sound
end

local function track(owner)
	local handle = handles[owner]
	if handle then
		return handle
	end
	handle = { Sounds = {}, Cancelled = false }
	handles[owner] = handle
	owner.Destroying:Once(function()
		handle.Cancelled = true
		handles[owner] = nil
		for _, sound in handle.Sounds do
			sound:Destroy()
		end
	end)
	return handle
end

-- Schedules every cue of `phase` for finisher `id`. `emitter` (a BasePart/Attachment in the world)
-- makes the sound 3D; nil plays it 2D for UI previews. `quiet` keeps only the impact cue.
function FinisherAudio.phase(owner, id, phase, emitter, options)
	local cues = Config.Finishers[id]
	if not cues or not owner or not owner.Parent then
		return
	end
	local opts = options or {}
	local handle = track(owner)
	local volume = Config.Volume * (if emitter then 1 else Config.PreviewVolume)
	for _, cue in cues do
		if cue.Phase ~= phase or (opts.Quiet and cue.Priority ~= 1) then
			continue
		end
		task.delay(cue.At, function()
			if handle.Cancelled or not owner.Parent or (emitter and not emitter.Parent) then
				return
			end
			local sound = play(cue, emitter, volume)
			if sound then
				table.insert(handle.Sounds, sound)
			end
		end)
	end
end

-- Inventory/shop preview: the whole burst sequence, non-positional, cancelled with the preview root.
function FinisherAudio.preview(owner, id)
	FinisherAudio.phase(owner, id, "Burst", nil)
end

return FinisherAudio
