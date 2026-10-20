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
function Service:Request(player, kind, id)
	if not self.Guard:Allow(player, "Claim", Balance.Retention.ClaimRateSeconds) then
		return
	end
	local data = self.Services.DataService:Get(player)
	if not data or type(kind) ~= "string" or #kind > 16 then
		return
	end
	local ok, message, reward, item = Rules.claim(data, kind, id, os.time())
	if ok and kind == "Daily" and self.Services.OnboardingService then
		self.Services.OnboardingService:DailyClaimed(player) -- onboarding step 2 -> 3 (decision 100)
	end
	if ok then
		self.Services.DataService:Sync(player)
		self.Services.DataService.Profiles[player].Profile:Save()
	end
	Remotes.RetentionResult:FireClient(player, {
		Ok = ok,
		Message = message,
		Kind = kind,
		Id = id,
		Reward = if type(reward) == "table" then reward else nil,
		Item = item,
	})
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
