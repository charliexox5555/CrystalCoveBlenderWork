-- First session (decision 100, docs/design/ONBOARDING.md): Welcome (3 free Kiln opens) -> Daily (claim day 1) ->
-- Arena (a reserved arena with a bot waiting) -> Match (assisted first match, won 3-1) -> Done (a free Kiln open
-- for the win). The step lives in the profile; the client reads the Player attributes below.
--   Player attributes: OnboardingStep (string), OnboardingPad (Vector3, the reserved pad while in Arena)
-- Rules and picks are pure (Data/OnboardingRules); this service only sequences, grants and reserves.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local AnalyticsService = game:GetService("AnalyticsService")
local Balance = require(RS.Shared.Config.Balance)
local Remotes = require(RS.Shared.Remotes)
local Rules = require(script.Parent.Parent.Data.OnboardingRules)
local Schema = require(script.Parent.Parent.Data.ProfileSchema)
local Guard = require(script.Parent.Parent.Util.RemoteGuard)
local Service = {}

function Service:Init(services)
	self.Services, self.Guard = services, Guard.new()
end

local function data(self, player)
	return self.Services.DataService and self.Services.DataService:Get(player)
end

function Service:Step(player)
	local profile = data(self, player)
	return profile and profile.Onboarding.Step or "Done"
end

-- Is `player` in the assisted first match window (MatchService asks before starting a match)?
function Service:IsFirstMatch(player)
	local step = self:Step(player)
	return step == "Arena" or step == "Match"
end

function Service:Funnel(player, step)
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, Rules.index(step), step)
	end)
end

function Service:SetStep(player, step)
	local profile = data(self, player)
	if not profile or profile.Onboarding.Step == step then
		return
	end
	profile.Onboarding.Step = step
	player:SetAttribute("OnboardingStep", step)
	self:Funnel(player, step)
	if step == "Arena" then
		self:Reserve(player)
	else
		self.Services.ArenaService:Unreserve(player)
		player:SetAttribute("OnboardingPad", nil)
	end
	self.Services.DataService:Sync(player)
end

function Service:Reserve(player)
	local pad = self.Services.ArenaService:Reserve(player)
	player:SetAttribute("OnboardingPad", pad and pad.Position or nil)
end

-- Grant glassies from a pick list and play them as a Kiln opening on the client.
function Service:Reveal(player, kind, ids)
	local profile = data(self, player)
	local results = {}
	for _, id in ids do
		table.insert(results, Schema.grant(profile, id, false, os.time()))
	end
	profile.Stats.KilnPulls += #ids
	self.Services.DataService:Sync(player)
	self.Services.DataService.Profiles[player].Profile:Save()
	Remotes.OnboardingReveal:FireClient(player, {
		Kind = kind,
		Results = results,
		Odds = if kind == "Welcome" then Rules.welcomeOddsText() else Rules.winOddsText(),
	})
end

function Service:OpenWelcome(player)
	local profile = data(self, player)
	if not profile or profile.Onboarding.Step ~= "Welcome" then
		return
	end
	local available = self.Services.KilnService:Pool()
	local rng = Random.new()
	local picks = Rules.welcomePicks(profile.Glassies, available, function()
		return rng:NextNumber()
	end)
	-- The old one-pull welcome after the first match is replaced by this flow.
	profile.Flags.WelcomePullUsed = true
	self:SetStep(player, "Daily")
	self:Reveal(player, "Welcome", picks)
end

-- RetentionService: a Daily Rewards claim succeeded.
function Service:DailyClaimed(player)
	if self:Step(player) == "Daily" then
		self:SetStep(player, "Arena")
	end
end

-- MatchService: the first match started / finished.
function Service:MatchStarted(player)
	if self:Step(player) == "Arena" then
		self:SetStep(player, "Match")
	end
end

function Service:MatchFinished(player, won)
	if self:Step(player) ~= "Match" then
		return
	end
	if not won then
		self:SetStep(player, "Arena") -- left or forfeited: a fresh reserved arena waits
		return
	end
	local profile = data(self, player)
	local available = self.Services.KilnService:Pool()
	local rng = Random.new()
	local pick = Rules.winPick(profile.Glassies, available, function()
		return rng:NextNumber()
	end)
	self:SetStep(player, "Done")
	if pick then
		-- After the results screen has had its moment.
		task.delay(Balance.Match.RoundEndSeconds, function()
			if player.Parent then
				self:Reveal(player, "Win", { pick })
			end
		end)
	end
end

-- DataService: profile ready.
function Service:Loaded(player)
	local step = self:Step(player)
	player:SetAttribute("OnboardingStep", step)
	if step == "Match" then
		step = "Arena" -- a match can't survive a rejoin
		data(self, player).Onboarding.Step = step
	end
	if step == "Arena" then
		self:Reserve(player)
	end
	if step ~= "Done" then
		self:Funnel(player, step)
	end
end

function Service:Start()
	Remotes.OnboardingAction.OnServerEvent:Connect(function(player, action)
		if not self.Guard:Allow(player, "Onboarding", Balance.Onboarding.ActionRateSeconds) then
			return
		end
		if action == "OpenWelcome" then
			self:OpenWelcome(player)
		end
	end)
	-- An expired reservation is renewed while the player is still on the Arena step and not in a queue.
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				if self:Step(player) == "Arena" and not self.Services.ArenaService:ReservedFor(player) then
					self:Reserve(player)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.Services.ArenaService:Unreserve(player)
		self.Guard:Remove(player)
	end)
end

return Service
