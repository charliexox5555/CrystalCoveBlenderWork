-- Group reward (decision 114, docs/design/GROUP_REWARD.md). A stand in the lobby with a ProximityPrompt: not in the
-- group -> the client shows Roblox's join prompt (GroupService:PromptJoinAsync only runs on the client) and reports the
-- result; the server checks membership itself and, once confirmed, the stand offers the claim card. OPEN -> one free
-- Marble Kiln open (Coin Kiln where paid random items are restricted), once per player ever, played like the welcome
-- and first-win openings (OnboardingReveal, Kind = "Group").
--   Player attributes: GroupReward ("Join" | "Ready" | "Claimed"), GroupRewardKiln ("Marbles" | "Coins")
--   Client -> server: GroupReward(action) with action "Prompt" (+ the prompt's GroupMembershipStatus name) or "Claim"
-- Membership: Player:IsInGroupAsync caches per server for the whole visit, and a join through the prompt only clears
-- the client's cache (Creator Docs), so a re-check after the prompt uses GroupService:GetGroupsAsync, with retries.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local GroupService = game:GetService("GroupService")
local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")
local Config = require(RS.Shared.Config.GroupReward)
local Remotes = require(RS.Shared.Remotes)
local Rules = require(script.Parent.Parent.Data.GroupRewardRules)
local Schema = require(script.Parent.Parent.Data.ProfileSchema)
local Guard = require(script.Parent.Parent.Util.RemoteGuard)
local Service = {}

function Service:Init(services)
	-- Member[player] = true once the server confirmed membership; DevMember = Studio-only overrides.
	self.Services, self.Guard, self.Member, self.Busy, self.DevMember = services, Guard.new(), {}, {}, {}
end

local function data(self, player)
	return self.Services.DataService and self.Services.DataService:Get(player)
end

-- Funnel counts for the stand: Prompted / Joined / Claimed (custom events; Studio prints them).
function Service:Log(player, event)
	if RunService:IsStudio() then
		print(string.format("[GroupReward] %s (%s)", event, player.Name))
	end
	pcall(function()
		AnalyticsService:LogCustomEvent(player, "GroupReward" .. event)
	end)
end

-- Asks Roblox. `fresh` skips the per-server IsInGroupAsync cache (after a join prompt). nil = the check failed.
function Service:Ask(player, fresh)
	local dev = self.DevMember[player]
	if dev ~= nil then
		return dev
	end
	if not fresh then
		local ok, member = pcall(player.IsInGroupAsync, player, Config.GroupId)
		if ok then
			return member == true
		end
	end
	local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
	return if ok then Rules.inGroups(groups, Config.GroupId) else nil
end

function Service:Publish(player)
	local profile = data(self, player)
	if not profile or player.Parent ~= Players then
		return
	end
	local state = Rules.state(profile.Flags, self.Member[player])
	player:SetAttribute("GroupReward", state)
	player:SetAttribute("GroupRewardKiln", Rules.kiln(self.Services.MatchService.PaidRandomAllowed[player]))
	return state
end

-- Re-checks membership (after a join, `tries` times a couple of seconds apart) and publishes the state.
function Service:Check(player, fresh, tries)
	local waited = os.clock()
	while self.Busy[player] and os.clock() - waited < 10 do
		task.wait(0.2) -- one check at a time per player (the join check can land on the join-time one)
	end
	self.Busy[player] = true
	for attempt = 1, tries or 1 do
		local member = self:Ask(player, fresh)
		if player.Parent ~= Players then
			break
		end
		if member then
			self.Member[player] = true
			break
		end
		if attempt < (tries or 1) then
			task.wait(Config.CheckRetrySeconds)
		end
	end
	self.Busy[player] = nil
	return self:Publish(player)
end

-- The client's join prompt closed with `status` (a GroupMembershipStatus name). Never trusted for the grant itself.
function Service:Prompted(player, status)
	local profile = data(self, player)
	local next = Rules.afterPrompt(status)
	if not profile or not next or profile.Flags.GroupRewardClaimed then
		return
	end
	self:Log(player, "Prompted")
	if next == "Check" and not self.Member[player] then
		if self:Check(player, true, Config.CheckTries) == "Ready" and status == "Joined" then
			self:Log(player, "Joined")
		end
	elseif self.Member[player] then
		self:Publish(player)
	end
end

-- OPEN on the claim card: membership confirmed on the server, flag first, then the roll, grant and the opening.
function Service:Claim(player)
	local profile = data(self, player)
	if not profile or self.Services.MatchService.ByPlayer[player] then
		return
	end
	if profile.Flags.GroupRewardClaimed then
		self:Publish(player)
		return
	end
	if not self.Member[player] then
		self:Check(player, true, 1)
	end
	profile = data(self, player) -- the check yields: the profile can be gone
	if not profile then
		return
	end
	local ok = Rules.claim(profile, self.Member[player])
	if not ok then
		self:Publish(player)
		return
	end
	local kiln = Rules.kiln(self.Services.MatchService.PaidRandomAllowed[player])
	local random = Random.new()
	local id, rainbow = Rules.roll(kiln, (self.Services.KilnService:Pool()), function()
		return random:NextNumber()
	end)
	local results = {}
	if id then
		table.insert(results, Schema.grant(profile, id, rainbow, os.time()))
		profile.Stats.KilnPulls += 1
	end
	self.Services.DataService:Sync(player)
	self.Services.DataService.Profiles[player].Profile:Save()
	self:Publish(player)
	self:Log(player, "Claimed")
	if #results > 0 then
		-- Free claim card: no odds line (decision 102).
		Remotes.OnboardingReveal:FireClient(player, { Kind = "Group", Currency = kiln, Results = results })
	end
end

-- DataService: profile ready. A cached membership check is fine here (it's the first one this visit).
function Service:Loaded(player)
	self:Publish(player)
	task.spawn(function()
		local profile = data(self, player)
		if profile and not profile.Flags.GroupRewardClaimed then
			self:Check(player, false, 1)
		end
		-- PaidRandomAllowed arrives a moment after join (MatchService): publish the Kiln once it is known.
		local waited = os.clock()
		while
			player.Parent == Players
			and self.Services.MatchService.PaidRandomAllowed[player] == nil
			and os.clock() - waited < 15
		do
			task.wait(0.5)
		end
		self:Publish(player)
	end)
end

function Service:Start()
	Remotes.GroupReward.OnServerEvent:Connect(function(player, action, status)
		if action == "Prompt" then
			if self.Guard:Allow(player, "Prompt", Config.PromptRateSeconds) and type(status) == "string" then
				self:Prompted(player, status)
			end
		elseif action == "Claim" then
			if self.Guard:Allow(player, "Claim", Config.ClaimRateSeconds) then
				self:Claim(player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.Member[player], self.Busy[player], self.DevMember[player] = nil, nil, nil
		self.Guard:Remove(player)
	end)
	if RunService:IsStudio() then
		-- Studio testing: IsInGroupAsync returns the Studio user's real membership, so force either path:
		--   ("Member", player, true|false|nil)  pretend in / out of the group (nil = ask Roblox again)
		--   ("Reset", player)                   unclaim and forget the confirmed membership
		local dev = Instance.new("BindableFunction")
		dev.Name = "GroupRewardDev"
		dev.OnInvoke = function(command, player, value)
			local profile = data(self, player)
			if not profile then
				return false
			end
			if command == "Member" then
				self.DevMember[player], self.Member[player] = value, nil
				return self:Check(player, true, 1)
			elseif command == "Reset" then
				profile.Flags.GroupRewardClaimed, self.Member[player] = false, nil
				return self:Check(player, true, 1)
			end
			return false
		end
		dev.Parent = game.ServerStorage
	end
end

return Service
