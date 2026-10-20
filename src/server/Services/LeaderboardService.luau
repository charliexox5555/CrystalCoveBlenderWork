-- Lobby leaderboards (decision 101, Proposed): the boards in Config/Leaderboards (Left: Robux spent this week, Middle:
-- total wins, Right: Robux spent all time). Ordered stores per stat (a fresh store each week for RobuxWeek), rows
-- drawn into each board's Display SurfaceGui (template built by tools/studio/install_leaderboards_v3.luau).
-- Robux spend is recorded by StoreService (receipts and game passes) through LeaderboardRules.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local UserService = game:GetService("UserService")
local RS = game:GetService("ReplicatedStorage")
local Balance = require(RS.Shared.Config.Balance)
local Config = require(RS.Shared.Config.Leaderboards)
local Rules = require(script.Parent.Parent.Data.LeaderboardRules)
local Service = {}

-- Top-three row colours (gold, silver, bronze) and the rest.
local MEDALS = { Color3.fromHex("#F5A524"), Color3.fromHex("#B7B3CC"), Color3.fromHex("#C9814A") }
local ROW = Color3.fromHex("#332854")
local ROW_TOP = Color3.fromHex("#3B2F5E")

function Service:Init(services)
	self.Services = services
	self.Pending, self.NextWrite, self.Written, self.Names, self.Stores = {}, {}, {}, {}, {}
	self.Mock = RunService:IsStudio() and Balance.Data.StudioMock
	self.Prefix = if RunService:IsStudio() then Balance.Data.StudioStoreName else Balance.Data.StoreName
	self.Stats = {}
	for _, board in Config.Boards do
		self.Stats[board.Stat] = true
	end
end

function Service:Store(stat, now)
	local name = Rules.storeName(self.Prefix, stat, Config.WeeklyStats[stat], now)
	if not self.Stores[name] then
		self.Stores[name] = DataStoreService:GetOrderedDataStore(name)
	end
	return self.Stores[name], name
end

-- DataService:Sync: queue this player's board stats for the next write.
function Service:Changed(player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local now = os.time()
	local values = {}
	for stat in self.Stats do
		values[stat] = Rules.statValue(data, stat, now)
	end
	self.Pending[player.UserId] = { Values = values, At = now }
	self.Names[player.UserId] = player.DisplayName
end

-- Display names for ranked user ids (one batched lookup for the unknown ones).
function Service:Resolve(rows)
	local missing = {}
	for _, row in rows do
		if not self.Names[row.UserId] then
			table.insert(missing, row.UserId)
		end
	end
	if #missing > 0 then
		local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, missing)
		if ok then
			for _, info in infos do
				self.Names[info.Id] = info.DisplayName
			end
		end
		for _, id in missing do
			if not self.Names[id] then
				local found, name = pcall(Players.GetNameFromUserIdAsync, Players, id)
				self.Names[id] = if found then name else "Player"
			end
		end
	end
	for _, row in rows do
		row.Name = self.Names[row.UserId]
	end
	return rows
end

function Service:Board(board)
	local props = workspace:FindFirstChild("Lobby") and workspace.Lobby:FindFirstChild("GlassClashProps")
	return props and props:FindFirstChild("Leaderboard_" .. board.Id)
end

function Service:Draw(board, rows, now)
	local model = self:Board(board)
	local display = model and model:FindFirstChild("Display", true)
	local root = display and display:FindFirstChild("Root")
	local list = root and root:FindFirstChild("Rows")
	local template = list and list:FindFirstChild("RowTemplate")
	if not template then
		return
	end
	local header = model:FindFirstChild("Header", true)
	local title = header and header:FindFirstChild("Title", true)
	local subtitle, footer, empty =
		root:FindFirstChild("Subtitle"), root:FindFirstChild("Footer"), root:FindFirstChild("Empty")
	if title then
		title.Text = board.Title
	end
	if subtitle then
		subtitle.Text = board.Subtitle or ""
	end
	if footer then
		footer.Text = if Config.WeeklyStats[board.Stat] then Rules.resetText(now) else "UPDATES EVERY FEW MINUTES"
	end
	if empty then
		empty.Text, empty.Visible = board.Empty or "", #rows == 0
	end
	-- Row heights come from the template's Rows frame (TopHeight for the top three, RowHeight for the rest).
	local top, height = list:GetAttribute("TopHeight") or 80, list:GetAttribute("RowHeight") or 56
	for rank = 1, Config.Rows do
		local row = rows[rank]
		local frame = list:FindFirstChild("Row" .. rank)
		if row and not frame then
			frame = template:Clone()
			frame.Name, frame.LayoutOrder = "Row" .. rank, rank
			frame.Size = UDim2.new(1, 0, 0, if rank <= 3 then top else height)
			frame.Parent = list
		end
		if frame then
			frame.Visible = row ~= nil
		end
		if row and frame then
			local medal = MEDALS[rank]
			frame.BackgroundColor3 = if medal then ROW_TOP else ROW
			local rankLabel, avatar, name, value, icon, stroke =
				frame:FindFirstChild("Rank", true),
				frame:FindFirstChild("Avatar", true),
				frame:FindFirstChild("PlayerName", true),
				frame:FindFirstChild("Value", true),
				frame:FindFirstChild("RobuxIcon", true),
				frame:FindFirstChildOfClass("UIStroke")
			if rankLabel then
				rankLabel.Text = tostring(rank)
				rankLabel.TextColor3 = medal or Color3.fromHex("#CDAAFF")
			end
			if stroke then
				stroke.Color, stroke.Transparency = medal or Color3.fromHex("#57299F"), if medal then 0 else 0.4
			end
			if avatar then
				avatar.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", row.UserId)
			end
			if name then
				name.Text = row.Name or "Player"
			end
			if value then
				value.Text = Rules.format(row.Value)
				value.TextColor3 = medal or Color3.new(1, 1, 1)
			end
			if icon then
				icon.Visible = board.Format == "Robux"
			end
		end
	end
end

-- Rows for one board: live players' profiles in Studio mock mode, the ordered store otherwise.
function Service:Rows(board, now)
	if self.Preview then
		return self.Preview[board.Id] or {}
	end
	if self.Mock then
		local entries = {}
		for _, player in Players:GetPlayers() do
			local data = self.Services.DataService:Get(player)
			if data then
				local id = if player.UserId > 0 then player.UserId else 1
				table.insert(entries, { key = tostring(id), value = Rules.statValue(data, board.Stat, now) })
				self.Names[id] = player.DisplayName
			end
		end
		return self:Resolve(Rules.rows(entries, Config.Rows))
	end
	local store = self:Store(board.Stat, now)
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, Config.Rows, 1)
	end)
	if not ok then
		warn("[GlassClash] leaderboard read failed: " .. board.Id)
		return nil
	end
	return self:Resolve(Rules.rows(page:GetCurrentPage(), Config.Rows))
end

function Service:Read()
	local now = os.time()
	for _, board in Config.Boards do
		local rows = self:Rows(board, now)
		if rows then
			self:Draw(board, rows, now)
		end
	end
end

-- One player's queued stats: only positive values that changed since the last write (budget friendly).
function Service:Write(id, pending)
	local written = self.Written[id] or {}
	self.Written[id] = written
	local success = true
	for stat, value in pending.Values do
		local key = stat .. (if Config.WeeklyStats[stat] then Rules.weekKey(pending.At) else "")
		if value > 0 and written[key] ~= value then
			local ok = pcall(function()
				self:Store(stat, pending.At):UpdateAsync(tostring(id), function(previous)
					return math.max(tonumber(previous) or 0, value)
				end)
			end)
			if ok then
				written[key] = value
			end
			success = success and ok
		end
	end
	return success
end

function Service:Start()
	task.spawn(function()
		while true do
			task.wait(Balance.Retention.TickSeconds)
			local now = os.clock()
			for id, pending in self.Pending do
				if now >= (self.NextWrite[id] or 0) then
					self.NextWrite[id] = now + Balance.Retention.LeaderboardPublishSeconds
					if self.Mock or id <= 0 then
						self.Pending[id] = nil
					elseif self:Write(id, pending) and self.Pending[id] == pending then
						self.Pending[id] = nil
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
	Players.PlayerRemoving:Connect(function(player)
		self.Written[player.UserId], self.NextWrite[player.UserId] = nil, nil
	end)
	if RunService:IsStudio() then
		-- Studio testing: ("Spend", player, robux) fakes a purchase (mock sessions only); ("Preview", true|false)
		-- fills every board with ten sample rows (the local player's headshot) for screenshots.
		local dev = Instance.new("BindableFunction")
		dev.Name = "LeaderboardDev"
		dev.OnInvoke = function(command, player, value)
			if command == "Spend" and self.Mock then
				local data = self.Services.DataService:Get(player)
				local ok = data ~= nil and Rules.recordSpend(data, value, os.time())
				if ok then
					self.Services.DataService:Sync(player)
				end
				self:Read()
				return ok and data.Spend
			elseif command == "Preview" then
				self.Preview = nil
				if player then
					local id = math.max(1, Players:GetPlayers()[1] and Players:GetPlayers()[1].UserId or 1)
					local names = {
						"GlassHero",
						"PrismPal",
						"ShardStar",
						"FizzyFox",
						"MarbleMax",
						"JarJam",
						"CrystalCat",
						"BottleBolt",
						"SunnyShard",
						"GlintGlow",
					}
					self.Preview = {}
					for _, board in Config.Boards do
						local rows, top = {}, if board.Format == "Robux" then 4200 else 860
						for rank, name in names do
							table.insert(
								rows,
								{ Rank = rank, UserId = id, Name = name, Value = math.floor(top / rank) }
							)
						end
						self.Preview[board.Id] = rows
					end
				end
				self:Read()
				return true
			elseif command == "Refresh" then
				self:Read()
				return true
			end
			return false
		end
		dev.Parent = game.ServerStorage
	end
end

return Service
