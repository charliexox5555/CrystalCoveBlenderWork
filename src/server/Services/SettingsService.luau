-- Remembers each player's settings (Config/Settings, decision 99): volumes and the Settings screen toggles.
-- Separate from the profile on purpose: these are comfort settings, so a failed load or save falls back to defaults
-- and never blocks play. Replaces the music-only prefs store; its mute/volume migrate in on first load.
-- The server reads BotPlay (ArenaService bot fill); everything else is applied by the client's SettingsController.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RS = game:GetService("ReplicatedStorage")
local Remotes = require(RS.Shared.Remotes)
local Settings = require(RS.Shared.Config.Settings)
local Guard = require(script.Parent.Parent.Util.RemoteGuard)
local Service = {}

function Service:Init()
	self.Guard, self.Values, self.Dirty, self.Loading, self.Unread = Guard.new(), {}, {}, {}, {}
	local function store(name)
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(name)
		end)
		return if ok then result else nil
	end
	self.Store, self.Legacy = store(Settings.Store.Name), store(Settings.Store.LegacyMusicName)
end

-- Current settings (defaults until loaded). Other services read this, e.g. ArenaService for BotPlay.
function Service:Get(player)
	return self.Values[player] or Settings.Defaults
end

local function read(store, key)
	if not store then
		return false, nil
	end
	return pcall(function()
		return store:GetAsync(key)
	end)
end

function Service:Load(player)
	local key = tostring(player.UserId)
	local values = Settings.normalize(nil)
	local ok, stored = read(self.Store, key)
	if ok and stored ~= nil then
		values = Settings.normalize(stored)
	elseif ok then
		local legacyOk, legacy = read(self.Legacy, key)
		if legacyOk and legacy ~= nil then
			values = Settings.fromLegacyMusic(legacy)
			self.Dirty[player] = true
		end
	end
	if player.Parent then
		-- A failed read leaves the stored settings unknown: this visit runs on defaults and never overwrites them.
		self.Unread[player] = not ok or nil
		-- A SetSetting that landed while the store was loading wins over the stored value.
		self.Values[player] = self.Values[player] or values
		Remotes.Settings:FireClient(player, self.Values[player])
	end
	self.Loading[player] = nil
end

function Service:Save(player)
	local values = self.Values[player]
	if not (values and self.Store and self.Dirty[player]) or self.Unread[player] then
		return
	end
	self.Dirty[player] = nil
	pcall(function()
		self.Store:SetAsync(tostring(player.UserId), values)
	end)
end

function Service:Request(player)
	if self.Values[player] then
		Remotes.Settings:FireClient(player, self.Values[player])
	elseif not self.Loading[player] then
		self.Loading[player] = true
		task.spawn(self.Load, self, player)
	end
end

function Service:Start()
	Players.PlayerAdded:Connect(function(player)
		self:Request(player)
	end)
	for _, player in Players:GetPlayers() do
		self:Request(player)
	end
	Remotes.RequestSettings.OnServerEvent:Connect(function(player)
		if self.Guard:Allow(player, "RequestSettings", 1) then
			self:Request(player)
		end
	end)
	Remotes.SetSetting.OnServerEvent:Connect(function(player, key, value)
		if not self.Guard:Allow(player, "SetSetting", Settings.Store.SetRateSeconds) then
			return
		end
		local updated = Settings.change(self:Get(player), key, value)
		if not updated then
			return
		end
		self.Values[player] = updated
		if not self.Dirty[player] then
			self.Dirty[player] = true
			task.delay(Settings.Store.SaveDelaySeconds, function()
				if player.Parent then
					self:Save(player)
				end
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:Save(player)
		self.Values[player], self.Dirty[player], self.Loading[player], self.Unread[player] = nil, nil, nil, nil
		self.Guard:Remove(player)
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			self:Save(player)
		end
	end)
end

return Service
