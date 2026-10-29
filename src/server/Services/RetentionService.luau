local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Balance = require(RS.Shared.Config.Balance)
local Remotes = require(RS.Shared.Remotes)
local Rules = require(script.Parent.Parent.Data.RetentionRules)
local Guard = require(script.Parent.Parent.Util.RemoteGuard)
local Service = {}
function Service:Init(services)
	self.Services, self.Guard, self.Clocks = services, Guard.new(), {}
end
function Service:Loaded(player)
	local data = self.Services.DataService:Get(player)
	if data then
		Rules.ensure(data, os.time())
		self.Clocks[player] = { At = os.clock(), Sync = os.clock(), Fraction = 0 }
	end
end
-- Playtime gifts collect themselves (decision 115): grant every reached gift, save, and tell the client so it can
-- show a small toast. Called from the playtime tick, so a gift reached in an earlier session today arrives soon
-- after joining.
function Service:Collect(player, data)
	local granted = Rules.collectGifts(data, os.time())
	if #granted == 0 then
		return
	end
	-- The notice goes first, so the client's coin burst (on the next snapshot) starts at the toast.
	for _, gift in granted do
		Remotes.RetentionResult:FireClient(player, {
			Ok = true,
			Auto = true,
			Kind = "Gift",
			Id = gift.Id,
			Reward = gift.Reward,
			Item = gift.Item,
		})
	end
	self.Services.DataService:Sync(player)
	local profile = self.Services.DataService.Profiles[player]
	if profile then
		profile.Profile:Save()
	end
end
function Service:View(player)
	local data = self.Services.DataService:Get(player)
	return data and Rules.view(data, os.time(), RunService:IsStudio())
end
function Service:MatchRecorded(player, match, side, observed)
	local data = self.Services.DataService:Get(player)
	if data then
		local bonus = Rules.match(data, match, side, observed, os.time())
		if bonus > 0 and player.Parent == Players then
			Remotes.RetentionResult:FireClient(
				player,
				{ Ok = true, Message = "First win today: +" .. bonus .. " coins" }
			)
		end
	end
end
function Service:Pulled() end -- hook reserved for future quest rotations; no extra reward
-- One grant/save/result path for remote requests and trusted onboarding. The latter must not
-- lose Day 1 just because an unrelated claim consumed the remote rate-limit slot.
local function claim(self, player, kind, id)
	local data = self.Services.DataService:Get(player)
	local profile = self.Services.DataService.Profiles[player]
	if not data or not profile or type(kind) ~= "string" or #kind > 16 then
		return false
	end
	local ok, message, reward, item = Rules.claim(data, kind, id, os.time())
	if ok then
		self.Services.DataService:Sync(player)
		profile.Profile:Save()
		if self.Services.BadgeService then
			self.Services.BadgeService:Check(player) -- Midnight's Week, Level 10 (decision 118)
		end
	end
	Remotes.RetentionResult:FireClient(player, {
		Ok = ok,
		Message = message,
		Kind = kind,
		Id = id,
		Reward = if type(reward) == "table" then reward else nil,
		Item = item,
	})
	return ok
end

function Service:Request(player, kind, id)
	if not self.Guard:Allow(player, "Claim", Balance.Retention.ClaimRateSeconds) then
		return false
	end
	local ok = claim(self, player, kind, id)
	if ok and kind == "Daily" and self.Services.OnboardingService then
		-- The grant and save request precede advancing the tutorial.
		self.Services.OnboardingService:DailyClaimed(player)
	end
	return ok
end

-- Internal-only: there is no remote argument that can invoke this path. Rules.claimDaily
-- retains the once-per-UTC-day gate, including reconnects and a prior manual claim.
function Service:CompleteWelcomeDaily(player)
	local data = self.Services.DataService:Get(player)
	if not data or data.Onboarding.Step ~= "Daily" then
		return false
	end
	if Rules.calendar(data, os.time()).ClaimedToday then
		return true
	end
	claim(self, player, "Daily")
	return Rules.calendar(data, os.time()).ClaimedToday
end
function Service:Start()
	local props = workspace.Lobby:FindFirstChild("GlassClashProps")
	for _, model in props and props:GetChildren() or {} do
		local prompt = model:FindFirstChild("OpenRewards", true)
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player)
				if not self.Guard:Allow(player, "Open", Balance.Retention.ClaimRateSeconds) then
					return
				end
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if
					self.Services.DataService:Get(player)
					and not self.Services.MatchService.ByPlayer[player]
					and root
					and (root.Position - prompt.Parent.Position).Magnitude <= prompt.MaxActivationDistance
				then
					Remotes.RetentionResult:FireClient(player, { Open = prompt:GetAttribute("RewardTab") })
				end
			end)
		end
	end
	Remotes.ClaimRetention.OnServerEvent:Connect(function(player, kind, id)
		self:Request(player, kind, id)
	end)
	Remotes.RedeemCode.OnServerEvent:Connect(function(player, input)
		if not self.Guard:Allow(player, "Code", Balance.Retention.CodeRateSeconds) then
			return
		end
		local data = self.Services.DataService:Get(player)
		if not data then
			return
		end
		local ok, message, reward, item = Rules.redeem(data, input, RunService:IsStudio(), os.time())
		if ok then
			self.Services.DataService:Sync(player)
			self.Services.DataService.Profiles[player].Profile:Save()
		end
		Remotes.RetentionResult:FireClient(
			player,
			{ Ok = ok, Message = message, Kind = "Code", Reward = reward, Item = item }
		)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.Clocks[player] = nil
		self.Guard:Remove(player)
	end)
	task.spawn(function()
		while true do
			task.wait(Balance.Retention.TickSeconds)
			local now = os.clock()
			for player, clock in self.Clocks do
				local data = self.Services.DataService:Get(player)
				if data then
					clock.Fraction += math.clamp(now - clock.At, 0, Balance.Retention.MaxTickSeconds)
					local seconds = math.floor(clock.Fraction)
					clock.Fraction -= seconds
					Rules.advance(data, seconds, os.time())
					clock.At = now
					self:Collect(player, data)
					if now - clock.Sync >= Balance.Retention.SnapshotSeconds then
						clock.Sync = now
						self.Services.DataService:Sync(player)
					end
				else
					self.Clocks[player] = nil
				end
			end
		end
	end)
	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "RetentionDev"
		dev.OnInvoke = function(action, player, value)
			local data = self.Services.DataService:Get(player)
			if not data then
				return false
			end
			if action == "Advance" then
				Rules.advance(data, value, os.time())
				self:Collect(player, data)
				self.Services.DataService:Sync(player)
			elseif action == "Calendar" then
				-- QA: make `value` (1-7) today's claimable calendar day.
				data.Calendar.Index, data.Calendar.LastDay = math.clamp(value - 1, 0, 6), Rules.day(os.time()) - 1
				self.Services.DataService:Sync(player)
			elseif action == "Observe" then
				Rules.match(data, { Winner = 1 }, 1, value, os.time())
				self.Services.DataService:Sync(player)
			elseif action == "Inspect" then
				return self:View(player)
			end
		end
		dev.Parent = game.ServerStorage
	end
end
return Service
