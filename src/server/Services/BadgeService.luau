-- Badges (decision 118, docs/design/BADGES.md). Server only. Data/BadgeRules decides what a player has earned; this
-- service awards it through Roblox's BadgeService and records it in the profile (Badges.Earned / Badges.Awarded), so a
-- badge is never awarded twice and a failed award is due again on the next check. Checks run on join, every
-- Config.CheckSeconds (level and Daily week also move through Crown Hill XP, playtime gifts and codes), and straight
-- after a round won over a player, a Kiln opening, a Daily claim or a recorded match.
-- Creator Docs (BadgeService): award from the server only, check GetBadgeInfoAsync().IsEnabled first, pcall every
-- call. AwardBadgeAsync and UserHasBadgeAsync each allow 50 + 35 x players calls a minute per server: a badge costs at
-- most one ownership check and one award per player, and badge info is cached per server.
-- Studio: an enabled badge cannot be awarded from Studio ("badges can only be tested if they are disabled"), so Studio
-- never calls Roblox. Awards there are printed and remembered for this server only (BadgeDev hook); the profile is not
-- marked, so a tester's real award still happens in a live server.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Badges = game:GetService("BadgeService")
local Config = require(RS.Shared.Config.Badges)
local Rules = require(script.Parent.Parent.Data.BadgeRules)
local Service = {}

function Service:Init(services)
	self.Services = services
	self.Busy, self.Again = {}, {} -- one check at a time per player; Again = another was asked for during it
	self.Info = {} -- [badgeId] = { Enabled = boolean, At = os.clock() }
	self.Studio = RunService:IsStudio()
	self.StudioAwarded, self.StudioLog = {}, {}
end

local function data(self, player)
	return self.Services.DataService and self.Services.DataService:Get(player)
end

-- pcall with retries (waits 1, 2, ... s between tries); returns ok, result.
local function retry(fn, ...)
	local wait, ok, result = Config.RetryBaseSeconds, false, nil
	for attempt = 1, Config.Retries do
		ok, result = pcall(fn, ...)
		if ok then
			return true, result
		end
		if attempt < Config.Retries then
			task.wait(wait)
			wait *= 2
		end
	end
	warn("[Badges] " .. tostring(result))
	return false, result
end

function Service:Enabled(badgeId)
	local cached = self.Info[badgeId]
	if cached and os.clock() - cached.At < Config.InfoCacheSeconds then
		return cached.Enabled
	end
	local ok, info = retry(Badges.GetBadgeInfoAsync, Badges, badgeId)
	if not ok then
		return false -- unknown: try again on the next check
	end
	local enabled = type(info) == "table" and info.IsEnabled == true
	self.Info[badgeId] = { Enabled = enabled, At = os.clock() }
	return enabled
end

-- Awards one badge; true once the player has it (awarded now or already owned).
function Service:Award(player, key)
	local def = Config.ByKey[key]
	if self.Studio then
		self.StudioAwarded[player.UserId] = self.StudioAwarded[player.UserId] or {}
		self.StudioAwarded[player.UserId][key] = true
		table.insert(self.StudioLog, { UserId = player.UserId, Key = key, Id = def.Id })
		print(string.format("[Badges] Studio: would award %s (%s) to %s", key, tostring(def.Id), player.Name))
		return false
	end
	if not self:Enabled(def.Id) then
		return false
	end
	local ok, owned = retry(Badges.UserHasBadgeAsync, Badges, player.UserId, def.Id)
	if ok and owned == true then
		return true
	end
	if player.Parent ~= Players then
		return false
	end
	local awarded
	ok, awarded = retry(Badges.AwardBadgeAsync, Badges, player.UserId, def.Id)
	return ok and awarded == true
end

function Service:Run(player)
	if self.Busy[player] then
		self.Again[player] = true
		return
	end
	self.Busy[player] = true
	local ok, err = pcall(function()
		repeat
			self.Again[player] = nil
			local profile = data(self, player)
			if not profile then
				break
			end
			Rules.fromState(profile)
			for _, key in Rules.due(profile, self.Studio and self.StudioAwarded[player.UserId], not self.Studio) do
				if player.Parent ~= Players then
					break
				end
				if self:Award(player, key) then
					Rules.markAwarded(profile, key)
				end
			end
		until not self.Again[player] or player.Parent ~= Players
	end)
	if not ok then
		warn("[Badges] check failed: " .. tostring(err))
	end
	self.Busy[player], self.Again[player] = nil, nil
end

-- Never yields: callers are mid-match, mid-pull or mid-claim.
function Service:Check(player)
	if player and player.Parent == Players then
		task.spawn(self.Run, self, player)
	end
end

function Service:Earn(player, key)
	local profile = key and data(self, player)
	if profile then
		Rules.earn(profile, key)
		self:Check(player)
	end
end

-- MatchService, as a fight ends: winner / loser are the Player on each side (nil for a bot).
function Service:RoundWon(winner, loser)
	if winner then
		self:Earn(winner, Rules.roundWon(winner ~= nil, loser ~= nil))
	end
end

-- KilnService, after an opening: the rarities that came out.
function Service:Pulled(player, rarities)
	self:Earn(player, Rules.pulled(rarities))
end

function Service:Start()
	Players.PlayerRemoving:Connect(function(player)
		self.Again[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Config.CheckSeconds)
			for _, player in Players:GetPlayers() do
				if not self.Busy[player] then
					self:Check(player)
				end
			end
		end
	end)
	if self.Studio then
		local dev = Instance.new("BindableFunction")
		dev.Name = "BadgeDev"
		dev.OnInvoke = function(command, player, key)
			local profile = player and data(self, player)
			if command == "State" and profile then
				return {
					Earned = table.clone(profile.Badges.Earned),
					Awarded = table.clone(profile.Badges.Awarded),
					Studio = table.clone(self.StudioAwarded[player.UserId] or {}),
					Log = table.clone(self.StudioLog),
				}
			end
			if command == "Earn" and profile and Config.ByKey[key] then
				self:Earn(player, key)
				return true
			end
			-- The hooks' own paths: "RoundWon" with "Player" or "Bot" as the loser, "Pulled" with a list of rarities.
			if command == "RoundWon" and profile then
				self:RoundWon(player, if key == "Player" then player else nil)
				return true
			end
			if command == "Pulled" and profile and type(key) == "table" then
				self:Pulled(player, key)
				return true
			end
			if command == "Check" and profile then
				self:Run(player)
				return table.clone(self.StudioAwarded[player.UserId] or {})
			end
			if command == "Reset" and profile and self.Services.DataService.Mock then
				-- Mock profiles only: forget every badge so the flow can be replayed.
				profile.Badges.Earned, profile.Badges.Awarded = {}, {}
				self.StudioAwarded[player.UserId] = nil
				return true
			end
			return false
		end
		dev.Parent = game.ServerStorage
	end
end

return Service
