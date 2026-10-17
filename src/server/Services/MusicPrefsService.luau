-- Remembers each player's music mute/volume across sessions. Separate from the profile on purpose:
-- it is a comfort setting, so a failed load/save just falls back to defaults and never blocks play.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RS = game:GetService("ReplicatedStorage")
local Remotes = require(RS.Shared.Remotes)
local Music = require(RS.Shared.Config.Music)
local Guard = require(script.Parent.Parent.Util.RemoteGuard)
local Service = {}

function Service:Init()
	self.Guard, self.Prefs, self.Dirty, self.Loading = Guard.new(), {}, {}, {}
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(Music.Prefs.StoreName)
	end)
	self.Store = if ok then store else nil
end

function Service:Load(player)
	local prefs = Music.normalize(nil)
	if self.Store then
		local ok, stored = pcall(function()
			return self.Store:GetAsync(tostring(player.UserId))
		end)
		if ok then
			prefs = Music.normalize(stored)
		end
	end
	if player.Parent then
		-- A SetMusicPrefs that landed while the store was loading wins over the stored value.
		self.Prefs[player] = self.Prefs[player] or prefs
		Remotes.MusicPrefs:FireClient(player, self.Prefs[player])
	end
	self.Loading[player] = nil
end

function Service:Save(player)
	local prefs = self.Prefs[player]
	if not (prefs and self.Store and self.Dirty[player]) then
		return
	end
	self.Dirty[player] = nil
	pcall(function()
		self.Store:SetAsync(tostring(player.UserId), { Muted = prefs.Muted, Volume = prefs.Volume })
	end)
end

function Service:Start()
	local P = Music.Prefs
	Remotes.RequestMusicPrefs.OnServerEvent:Connect(function(player)
		if not self.Guard:Allow(player, "RequestMusicPrefs", 1) then
			return
		end
		if self.Prefs[player] then
			Remotes.MusicPrefs:FireClient(player, self.Prefs[player])
		elseif not self.Loading[player] then
			self.Loading[player] = true
			task.spawn(self.Load, self, player)
		end
	end)
	Remotes.SetMusicPrefs.OnServerEvent:Connect(function(player, muted, volume)
		if not self.Guard:Allow(player, "SetMusicPrefs", P.SetRateSeconds) then
			return
		end
		if type(muted) ~= "boolean" or not Guard.finite(volume) then
			return
		end
		self.Prefs[player] = Music.normalize({ Muted = muted, Volume = volume })
		if not self.Dirty[player] then
			self.Dirty[player] = true
			task.delay(P.SaveDelaySeconds, function()
				if player.Parent then
					self:Save(player)
				end
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:Save(player)
		self.Prefs[player], self.Dirty[player], self.Loading[player] = nil, nil, nil
		self.Guard:Remove(player)
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			self:Save(player)
		end
	end)
end

return Service
