local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Balance = require(RS.Shared.Config.Balance)
local Remotes = require(RS.Shared.Remotes)
local ProfileStore = require(script.Parent.Parent.Vendor.ProfileStore)
local Schema = require(script.Parent.Parent.Data.ProfileSchema)
local Guard = require(script.Parent.Parent.Util.RemoteGuard)
local Service = {}
local D = Balance.Data

function Service:Init(services)
	self.Services, self.Profiles, self.Loading, self.ByUserId, self.Closing = services, {}, {}, {}, false
	self.Guard = Guard.new()
	self.Mock = RunService:IsStudio() and D.StudioMock
	local name = if RunService:IsStudio() then D.StudioStoreName else D.StoreName
	self.Store = ProfileStore.New(name, Schema.new(0))
	if self.Mock then
		self.Store = self.Store.Mock
	end
end

function Service:Get(player)
	local entry = self.Profiles[player]
	return entry and entry.Profile:IsActive() and entry.Profile.Data or nil
end
function Service:IsReady(player)
	return self:Get(player) ~= nil
end
function Service:IsPersistent(player)
	return self:IsReady(player) and not self.Mock and ProfileStore.DataStoreState == "Access"
end

function Service:Sync(player)
	local data = self:Get(player)
	if not data or player.Parent ~= Players then
		return
	end
	local snapshot = Schema.snapshot(data)
	snapshot.Persistent = self:IsPersistent(player)
	Remotes.ProfileSnapshot:FireClient(player, snapshot)
end

function Service:Release(player)
	local entry = self.Profiles[player]
	if not entry then
		return
	end
	self.Profiles[player] = nil
	if self.ByUserId[player.UserId] == player then
		self.ByUserId[player.UserId] = nil
	end
	entry.ExpectedEnd = true
	if entry.Connection then
		entry.Connection:Disconnect()
	end
	entry.Profile:EndSession()
end

function Service:Load(player)
	if self.Loading[player] or self.Profiles[player] or self.Closing then
		return
	end
	self.Loading[player] = true
	local old = self.ByUserId[player.UserId]
	if old and old ~= player then
		if self.Services.MatchService then
			self.Services.MatchService:Forfeit(old)
		end
		self:Release(old)
	end
	local began = os.clock()
	local ok, profile = pcall(function()
		return self.Store:StartSessionAsync("Player_" .. player.UserId, {
			Cancel = function()
				return self.Closing or player.Parent ~= Players or os.clock() - began >= D.LoadTimeout
			end,
		})
	end)
	self.Loading[player] = nil
	if not ok or not profile then
		if player.Parent == Players and not self.Closing then
			player:Kick("Your glassies could not load. Please rejoin.")
		end
		if not ok then
			warn("[GlassClash] profile load failed: " .. tostring(profile))
		end
		return
	end
	if player.Parent ~= Players or self.Closing then
		profile:EndSession()
		return
	end
	local reconciled = pcall(function()
		profile:AddUserId(player.UserId)
		Schema.reconcile(profile.Data, os.time())
		profile:Reconcile()
	end)
	if not reconciled then
		profile:EndSession()
		player:Kick("Your progress needs a newer server. Please rejoin.")
		return
	end
	local entry = { Profile = profile, ExpectedEnd = false }
	self.Profiles[player], self.ByUserId[player.UserId] = entry, player
	entry.Connection = profile.OnSessionEnd:Connect(function()
		if self.Profiles[player] ~= entry then
			return
		end
		self.Profiles[player] = nil
		if self.ByUserId[player.UserId] == player then
			self.ByUserId[player.UserId] = nil
		end
		if not entry.ExpectedEnd and not self.Closing and player.Parent == Players then
			player:Kick("Your glassies opened in another server. Please rejoin.")
		end
	end)
	self:Sync(player)
end

function Service:RecordMatch(player, id, match, side, rewards, observed)
	local data = self:Get(player)
	if not data then
		return false
	end
	if type(observed) == "number" then
		observed = { Perfects = observed }
	end
	local changed = Schema.recordMatch(data, id, match, side, rewards, observed)
	if changed then
		if self.Services.RetentionService then
			self.Services.RetentionService:MatchRecorded(player, match, side, observed or {})
		end
		self:Sync(player)
		self.Profiles[player].Profile:Save()
	end
	return changed
end

function Service:AddCoins(player, amount)
	local data = self:Get(player)
	if not data or not Guard.finite(amount) or amount % 1 ~= 0 or data.Coins + amount < 0 then
		return false
	end
	data.Coins += amount
	self:Sync(player)
	return true
end

function Service:Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			self:Load(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:Load(player)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		-- Let MatchService settle a forfeit before releasing the session.
		task.delay(D.ReleaseGrace, function()
			self:Release(player)
		end)
		self.Guard:Remove(player)
	end)
	Remotes.RequestProfile.OnServerEvent:Connect(function(player)
		if self.Guard:Allow(player, "Profile", D.RequestRateSeconds) then
			self:Sync(player)
		end
	end)
	game:BindToClose(function()
		self.Closing = true
		for player in self.Profiles do
			self:Release(player)
		end
		-- ProfileStore owns the final-save jobs and waits for them in its BindToClose.
	end)
	if self.Mock then
		print("[GlassClash] Studio progress uses isolated ProfileStore mock sessions")
	end
	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "DataDev"
		dev.OnInvoke = function(command, player, value)
			if command == "Inspect" then
				local d = self:Get(player)
				return {
					Data = d and Schema.snapshot(d),
					Mock = self.Mock,
					State = ProfileStore.DataStoreState,
					Active = d ~= nil,
				}
			end
			if command == "Coins" then
				return self:AddCoins(player, value)
			end
			if command == "Grant" then
				local d = self:Get(player)
				if not d then
					return false
				end
				local result = Schema.grant(d, value, false, os.time())
				self:Sync(player)
				return result
			end
			if command == "Reload" then
				self:Release(player)
				task.wait(0.1)
				self:Load(player)
				return Schema.snapshot(self:Get(player))
			end
			if command == "Save" then
				local entry = self.Profiles[player]
				if not entry then
					return false
				end
				local saved = false
				local connection = entry.Profile.OnAfterSave:Connect(function()
					saved = true
				end)
				entry.Profile:Save()
				local stop = os.clock() + 10
				while not saved and os.clock() < stop do
					task.wait()
				end
				connection:Disconnect()
				return { Saved = saved, Data = Schema.snapshot(entry.Profile.LastSavedData) }
			end
		end
		dev.Parent = game.ServerStorage
	end
end

return Service
