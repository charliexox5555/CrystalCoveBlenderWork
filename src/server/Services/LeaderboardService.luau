local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local RS = game:GetService("ReplicatedStorage")
local Balance = require(RS.Shared.Config.Balance)
local Service = {}
local keys = { "Trophies", "MatchWins", "Shatters" }
function Service:Init(services)
	self.Services, self.Pending, self.NextWrite, self.Cache, self.Stores = services, {}, {}, {}, {}
	self.Mock = RunService:IsStudio() and Balance.Data.StudioMock
end
function Service:Changed(player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	self.Pending[player.UserId] = {
		Trophies = data.Trophies,
		MatchWins = data.Stats.MatchWins,
		Shatters = data.Stats.Shatters,
		Name = player.DisplayName,
	}
end
function Service:Name(id)
	if not self.Cache[id] then
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, id)
		self.Cache[id] = if ok then name else "Player " .. id
	end
	return self.Cache[id]
end
function Service:Draw(key, rows)
	local props = workspace.Lobby:FindFirstChild("GlassClashProps")
	local board = props and props:FindFirstChild("Leaderboard_" .. key)
	local label = board and board:FindFirstChild("Entries", true)
	if not label then
		return
	end
	local lines = {}
	for i, row in rows do
		table.insert(lines, i .. ". " .. row.Name .. "   " .. row.Value)
	end
	label.Text = if #lines > 0 then table.concat(lines, "\n") else "Clash to make the board!"
end
function Service:Read()
	for _, key in keys do
		local rows = {}
		if self.Mock then
			for _, player in Players:GetPlayers() do
				local data = self.Services.DataService:Get(player)
				if data then
					table.insert(
						rows,
						{
							Name = player.DisplayName,
							Value = if key == "Trophies" then data.Trophies else data.Stats[key],
						}
					)
				end
			end
			table.sort(rows, function(a, b)
				return a.Value > b.Value
			end)
		else
			local ok, page = pcall(function()
				return self.Stores[key]:GetSortedAsync(false, Balance.Retention.LeaderboardRows)
			end)
			if ok then
				for _, entry in page:GetCurrentPage() do
					local id = tonumber(entry.key)
					if id and id > 0 then
						table.insert(rows, { Name = self:Name(id), Value = entry.value })
					end
				end
			else
				warn("[GlassClash] leaderboard read failed: " .. key)
			end
		end
		self:Draw(key, rows)
	end
end
function Service:Start()
	if not self.Mock then
		local prefix = if RunService:IsStudio() then Balance.Data.StudioStoreName else Balance.Data.StoreName
		for _, key in keys do
			self.Stores[key] = DataStoreService:GetOrderedDataStore(prefix .. "_" .. key)
		end
	end
	task.spawn(function()
		while true do
			task.wait(Balance.Retention.TickSeconds)
			local now = os.clock()
			for id, values in self.Pending do
				if now >= (self.NextWrite[id] or 0) then
					self.NextWrite[id] = now + Balance.Retention.LeaderboardPublishSeconds
					if self.Mock then
						self.Pending[id] = nil
					elseif id > 0 then
						local success = true
						for _, key in keys do
							local ok = pcall(function()
								if key == "Trophies" then
									self.Stores[key]:SetAsync(tostring(id), values[key])
								else
									self.Stores[key]:UpdateAsync(tostring(id), function(previous)
										return math.max(previous or 0, values[key])
									end)
								end
							end)
							success = success and ok
						end
						if success and self.Pending[id] == values then
							self.Pending[id] = nil
						end
					end
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			self:Read()
			task.wait(if self.Mock then Balance.Retention.SnapshotSeconds else Balance.Retention.LeaderboardReadSeconds)
		end
	end)
end
return Service
