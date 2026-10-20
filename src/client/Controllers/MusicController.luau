-- Background music: lobby theme in the lobby, match theme in a match/spectating, calm theme on
-- results and lobby panels (Kiln, Glassies, Rewards). Tracks crossfade; the shatter dips the music
-- briefly. Tracks and numbers live in Config/Music. Music plays in AudioGroups' MusicMaster group, whose volume
-- is the Settings screen's Music slider (SettingsController, decision 99).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Music = require(RS.Shared.Config.Music)
local AudioGroups = require(script.Parent.Parent.AudioGroups)
local Controller = {}

local POLL = 0.1

function Controller:Init(controllers)
	self.Controllers = controllers
	self.Player = Players.LocalPlayer
	self.Sounds = {}
	self.Active, self.Pending, self.PendingSince = nil, nil, 0
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
	self.Master, self.DuckGroup = master, duck
	for name, track in Music.Tracks do
		local sound = Instance.new("Sound")
		sound.Name, sound.SoundId = name, track.Id
		sound.Looped, sound.Volume, sound.SoundGroup = true, 0, duck
		sound.Parent = master
		self.Sounds[name] = sound
	end
	task.spawn(function()
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(master:GetChildren())
		end)
	end)
end

-- What should be playing right now, from state other controllers already publish.
function Controller:Desired()
	local pg = self.Player:FindFirstChild("PlayerGui")
	if not pg then
		return "Lobby"
	end
	if pg:GetAttribute("ResultsOpen") then
		return "Calm"
	end
	if pg:GetAttribute("InMatch") or pg:GetAttribute("Watching") then
		return "Match"
	end
	local lobby = self.Controllers.LobbyController
	if lobby and lobby.PanelOpen then
		return "Calm"
	end
	return "Lobby"
end

function Controller:Switch(name)
	local previous = self.Active
	self.Active = name
	if previous then
		local old = self.Sounds[previous]
		tween(old, Music.FadeOut, { Volume = 0 }).Completed:Connect(function()
			if self.Active ~= previous then
				old:Stop()
			end
		end)
	end
	local sound = self.Sounds[name]
	if not sound.IsPlaying then
		sound.TimePosition = 0
		sound:Play()
	end
	tween(sound, Music.FadeIn, { Volume = Music.Tracks[name].Volume })
end

function Controller:Duck()
	self.DuckToken = (self.DuckToken or 0) + 1
	local token = self.DuckToken
	tween(self.DuckGroup, Music.Duck.FadeDown, { Volume = Music.Duck.Multiplier })
	task.delay(Music.Duck.Hold, function()
		if self.DuckToken == token then
			tween(self.DuckGroup, Music.Duck.FadeUp, { Volume = 1 })
		end
	end)
end

function Controller:Poll(pg)
	local desired = self:Desired()
	local now = os.clock()
	if desired ~= self.Pending then
		self.Pending, self.PendingSince = desired, now
	end
	if desired ~= self.Active and (self.Active == nil or now - self.PendingSince >= Music.SwitchDelay) then
		self:Switch(desired)
	end
	-- The fight HUD stamps LastShatter when the shatter plays on screen; dip under it.
	local hud = pg:FindFirstChild("FightHud")
	local shatter = hud and hud:GetAttribute("LastShatter")
	if shatter and shatter ~= self.LastShatter then
		self.LastShatter = shatter
		self:Duck()
	elseif not hud then
		self.LastShatter = nil
	end
end

function Controller:Start()
	self:BuildAudio()
	local pg = self.Player:WaitForChild("PlayerGui")
	task.spawn(function()
		while true do
			self:Poll(pg)
			task.wait(POLL)
		end
	end)
end

return Controller
