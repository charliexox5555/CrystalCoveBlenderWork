-- Background music (decision 109): the lobby playlist in the lobby and its panels, the Fight bed in a match or
-- spectating, the Overtime bed once Overtime fires or a round starts with a side on its last heart. A tension sting
-- ends on the release, a win/lose sting plays on MatchResult over silence, then lobby music fades back in.
-- Beds play on Sounds cloned from preloaded templates, so a track can crossfade into its own next play or the
-- next playlist track; every switch fades. Tracks and numbers live in Config/Music. Everything plays in AudioGroups'
-- MusicMaster group, whose volume is the Settings screen's Music slider (SettingsController, decision 99).
-- Signals read here: PlayerGui InMatch / Watching (MatchController, FightController), FightHud Phase / FightId /
-- ReleaseAt / Overtime / LastHeart (FightView, FightScene), PlayerGui MusicDuckAt (shatter, Kiln reveal) and the
-- existing MatchResult remote.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Music = require(RS.Shared.Config.Music)
local Remotes = require(RS.Shared.Remotes)
local AudioGroups = require(script.Parent.Parent.AudioGroups)
local Controller = {}

local POLL = 0.1

function Controller:Init(controllers)
	self.Controllers = controllers
	self.Player = Players.LocalPlayer
	self.Templates, self.Stings = {}, {}
	self.Voices = {} -- live bed Sounds -> true, so fades never leak instances
	self.Voice = nil -- { Sound, Track, Context, Handed }
	self.Context, self.Pending, self.PendingSince = nil, nil, 0
	self.Next = {} -- playlist position per context
	self.QuietUntil = 0
	self.Stung = nil -- FightId whose tension sting already played
	self.OvertimeFight = nil -- FightId that switched the bed to Overtime
end

local function tween(object, seconds, goal)
	local t = TweenService:Create(object, TweenInfo.new(seconds, Enum.EasingStyle.Sine), goal)
	t:Play()
	return t
end

function Controller:BuildAudio()
	local master = AudioGroups.music()
	local duck = Instance.new("SoundGroup")
	duck.Name, duck.Volume = "MusicDuck", 1
	duck.Parent = master
	local templates = Instance.new("Folder")
	templates.Name = "MusicTemplates"
	templates.Parent = master
	self.Master, self.DuckGroup = master, duck
	for name, track in Music.Tracks do
		local sound = Instance.new("Sound")
		sound.Name, sound.SoundId = name, track.Id
		sound.Looped, sound.Volume, sound.SoundGroup = track.Loop == "Looped", 0, duck
		sound.Parent = templates
		self.Templates[name] = sound
	end
	-- Stings sit beside the duck group, so they never dip under their own duck.
	for name, sting in Music.Stings do
		local sound = Instance.new("Sound")
		sound.Name, sound.SoundId = "Sting" .. name, sting.Id
		sound.Looped, sound.Volume, sound.SoundGroup = false, sting.Volume, master
		sound.Parent = master
		self.Stings[name] = sound
	end
	task.spawn(function()
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(master:GetDescendants())
		end)
	end)
end

-- What the bed should be right now, from state other controllers already publish.
function Controller:Desired(pg)
	if os.clock() < self.QuietUntil then
		return nil -- the win/lose sting plays over silence
	end
	if not (pg:GetAttribute("InMatch") or pg:GetAttribute("Watching")) then
		return "Lobby" -- panels keep the lobby playlist
	end
	local hud = pg:FindFirstChild("FightHud")
	if not hud then
		-- Between rounds (rolling): stay on whichever match bed is playing.
		return if self.Context == "Overtime" then "Overtime" else "Fight"
	end
	local fightId = hud:GetAttribute("FightId")
	if hud:GetAttribute("Overtime") or hud:GetAttribute("LastHeart") then
		self.OvertimeFight = fightId
		return "Overtime"
	end
	-- Back to Fight only at a new round where neither condition holds.
	if self.Context == "Overtime" and fightId == self.OvertimeFight then
		return "Overtime"
	end
	return "Fight"
end

function Controller:FadeOut(voice, seconds)
	local sound = voice.Sound
	tween(sound, seconds or Music.FadeOut, { Volume = 0 }).Completed:Connect(function()
		sound:Stop()
		sound:Destroy()
		self.Voices[sound] = nil
	end)
end

-- Start the context's next playlist track on a fresh Sound, fading in over `fade`.
function Controller:StartVoice(context, fade)
	local list = Music.Playlists[context]
	local index = self.Next[context] or math.random(#list)
	self.Next[context] = index % #list + 1
	local name = list[index]
	local sound = self.Templates[name]:Clone()
	sound.Volume = 0
	sound.Parent = self.Master
	self.Voices[sound] = true
	sound:Play()
	tween(sound, fade, { Volume = Music.Tracks[name].Volume })
	self.Voice = { Sound = sound, Track = name, Context = context, Handed = false }
end

function Controller:Switch(context)
	self.Context = context
	if self.Voice then
		self:FadeOut(self.Voice)
		self.Voice = nil
	end
	if context then
		self:StartVoice(context, Music.FadeIn)
	end
end

-- "Crossfade" tracks hand over to the next play a little before the end, so there is never a gap or click.
function Controller:Continue()
	local voice = self.Voice
	if not voice or voice.Handed or Music.Tracks[voice.Track].Loop ~= "Crossfade" then
		return
	end
	local sound = voice.Sound
	local length = if sound.TimeLength > 0 then sound.TimeLength else Music.Tracks[voice.Track].Length
	if sound.IsPlaying and sound.TimePosition >= length - Music.LoopCrossfade then
		voice.Handed = true
		self:FadeOut(voice, Music.LoopCrossfade)
		self:StartVoice(voice.Context, Music.LoopCrossfade)
	end
end

-- Dip the beds to `multiplier`, hold, then recover. The latest dip wins.
function Controller:Duck(multiplier, fadeDown, hold, fadeUp)
	self.DuckToken = (self.DuckToken or 0) + 1
	local token = self.DuckToken
	tween(self.DuckGroup, fadeDown, { Volume = multiplier })
	task.delay(hold, function()
		if self.DuckToken == token then
			tween(self.DuckGroup, fadeUp, { Volume = 1 })
		end
	end)
end

function Controller:Sting(name)
	local sound, sting = self.Stings[name], Music.Stings[name]
	local length = if sound.TimeLength > 0 then sound.TimeLength else sting.Length
	sound.Volume = sting.Volume
	sound.TimePosition = 0
	sound:Play()
	local d = Music.StingDuck
	self:Duck(d.Multiplier, d.FadeDown, length, d.FadeUp)
	return length
end

function Controller:StopTension()
	local sound = self.Stings.Tension
	if sound and sound.IsPlaying then
		tween(sound, 0.4, { Volume = 0 }).Completed:Connect(function()
			sound:Stop()
		end)
	end
end

-- The tension sting ends on the release: it starts its own length before ReleaseAt.
function Controller:Tension(pg)
	local hud = pg:FindFirstChild("FightHud")
	local fightId = hud and hud:GetAttribute("FightId")
	local releaseAt = hud and hud:GetAttribute("ReleaseAt")
	if not (fightId and releaseAt) or hud:GetAttribute("Phase") ~= "Countdown" or self.Stung == fightId then
		if self.Stung and (not hud or hud:GetAttribute("FightId") ~= self.Stung) then
			self:StopTension() -- the fight it belonged to is gone (cancelled match, left spectating)
		end
		return
	end
	local length = Music.Stings.Tension.Length
	local now = workspace:GetServerTimeNow()
	if now >= releaseAt - length and now < releaseAt - 0.25 then
		self.Stung = fightId
		self:Sting("Tension")
	end
end

function Controller:Result(data)
	if data.NoContest then
		return
	end
	self:StopTension()
	local length = self:Sting(if data.Won then "Win" else "Lose")
	self.QuietUntil = os.clock() + length + Music.ResultGap
	self:Switch(nil) -- the match bed fades out under the sting; Poll brings lobby music back after the gap
	self.Pending, self.PendingSince = nil, os.clock()
end

function Controller:Poll(pg)
	local desired = self:Desired(pg)
	local now = os.clock()
	if desired ~= self.Pending then
		self.Pending, self.PendingSince = desired, now
	end
	if desired ~= self.Context and (self.Voice == nil or now - self.PendingSince >= Music.SwitchDelay) then
		self:Switch(desired)
	end
	self:Continue()
	self:Tension(pg)
end

function Controller:Start()
	self:BuildAudio()
	local pg = self.Player:WaitForChild("PlayerGui")
	-- The shatter (FightView) and the Kiln reveal (KilnOpening) stamp MusicDuckAt; dip under them.
	pg:GetAttributeChangedSignal("MusicDuckAt"):Connect(function()
		local d = Music.Duck
		self:Duck(d.Multiplier, d.FadeDown, d.Hold, d.FadeUp)
	end)
	Remotes.MatchResult.OnClientEvent:Connect(function(data)
		if type(data) == "table" then
			self:Result(data)
		end
	end)
	task.spawn(function()
		while true do
			self:Poll(pg)
			task.wait(POLL)
		end
	end)
end

return Controller
