-- Background music: lobby theme in the lobby, match theme in a match/spectating, calm theme on
-- results and lobby panels (Kiln, Glassies, Rewards). Tracks crossfade; the shatter dips the music
-- briefly. A small round button mutes/unmutes; the choice is saved by MusicPrefsService.
-- Tracks and numbers live in Config/Music. Music sits in its own SoundGroup under the effects.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Remotes = require(RS.Shared.Remotes)
local Music = require(RS.Shared.Config.Music)
local Theme = require(script.Parent.Parent.UI.Theme)
local Controller = {}

local POLL = 0.1
local PREF_TWEEN = TweenInfo.new(0.25)

function Controller:Init(controllers)
	self.Controllers = controllers
	self.Player = Players.LocalPlayer
	self.Prefs = Music.normalize(nil)
	self.Sounds = {}
	self.Active, self.Pending, self.PendingSince = nil, nil, 0
end

local function tween(object, seconds, goal)
	local t = TweenService:Create(object, TweenInfo.new(seconds, Enum.EasingStyle.Sine), goal)
	t:Play()
	return t
end

function Controller:BuildAudio()
	local master = Instance.new("SoundGroup")
	master.Name, master.Volume = "MusicMaster", 0
	master.Parent = SoundService
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

function Controller:ApplyPrefs(animate)
	local volume = if self.Prefs.Muted then 0 else self.Prefs.Volume
	if animate then
		tween(self.Master, PREF_TWEEN.Time, { Volume = volume })
	else
		self.Master.Volume = volume
	end
	self:RefreshButton()
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

function Controller:Save()
	Remotes.SetMusicPrefs:FireServer(self.Prefs.Muted, self.Prefs.Volume)
end

function Controller:RefreshButton()
	local button = self.Button
	if not button then
		return
	end
	local muted = self.Prefs.Muted or self.Prefs.Volume <= 0
	button.Slash.Visible = muted
	button.Note.TextTransparency = if muted then 0.45 else 0
	button:SetAttribute("Muted", muted)
end

function Controller:BuildButton()
	local P = Theme.Palette
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "MusicToggle", false, 6
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	local button = Instance.new("TextButton")
	button.Name, button.Text, button.AutoButtonColor = "Button", "", true
	button.AnchorPoint, button.Position = Vector2.new(1, 0), UDim2.new(1, -12, 0, 12)
	button.Size = UDim2.fromOffset(44, 44)
	button.BackgroundColor3, button.BackgroundTransparency = P.smoke, 0.1
	button.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness = P.aqua, 2
	stroke.Parent = button
	local note = Instance.new("TextLabel")
	note.Name, note.Text, note.BackgroundTransparency = "Note", "♪", 1
	note.Size, note.FontFace, note.TextScaled = UDim2.fromScale(1, 1), Theme.Fonts.Body, true
	note.TextColor3 = P.milkLight
	note.Parent = button
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.14, 0), UDim.new(0.14, 0)
	pad.Parent = note
	local slash = Instance.new("Frame")
	slash.Name, slash.AnchorPoint, slash.Position = "Slash", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	slash.Size, slash.Rotation = UDim2.new(0.82, 0, 0, 3), 45
	slash.BackgroundColor3, slash.BorderSizePixel = P.ruby, 0
	slash.Parent = button
	button.Activated:Connect(function()
		self.Prefs = Music.toggled(self.Prefs)
		self:ApplyPrefs(true)
		self:Save()
	end)
	gui.Parent = self.Player:WaitForChild("PlayerGui")
	self.Gui, self.Button = gui, button
	self:RefreshButton()
end

function Controller:Start()
	self:BuildAudio()
	self:ApplyPrefs(false)
	local pg = self.Player:WaitForChild("PlayerGui")
	self:BuildButton()
	Remotes.MusicPrefs.OnClientEvent:Connect(function(prefs)
		self.Prefs = Music.normalize(prefs)
		self:ApplyPrefs(true)
	end)
	Remotes.RequestMusicPrefs:FireServer()
	task.spawn(function()
		while true do
			self:Poll(pg)
			task.wait(POLL)
		end
	end)
end

return Controller
