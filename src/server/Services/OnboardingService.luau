-- First session (decision 100, docs/design/ONBOARDING.md): Welcome (3 free Kiln opens) -> Daily (claim day 1) ->
-- Arena (a reserved arena with a bot waiting) -> Match (assisted first match, won 3-1) -> Win (a claim card: OPEN
-- picks and grants a free Kiln open) -> Done. The step lives in the profile; the client reads the Player attributes below.
--   Player attributes: OnboardingStep (string), OnboardingPad (Vector3, the reserved pad while in Arena)
-- Services report tutorial moments with Track(player, event); OnboardingRules.Funnel turns them into the analytics
-- onboarding funnel (12 steps, joining to the end of the second match).
-- Rules and picks are pure (Data/OnboardingRules); this service only sequences, grants and reserves.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")
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
	return Rules.isFirstMatch(self:Step(player))
end

-- ArenaService / HillService, before queuing: a claim card still waiting (Welcome, Win) is opened instead, so the
-- player is pulled back to the next step and never plays around it. True = handled, don't queue.
function Service:BeforePlay(player)
	local open = Rules.claimBeforePlay(self:Step(player))
	if open == "OpenWelcome" then
		self:OpenWelcome(player)
	elseif open == "OpenWin" then
		self:OpenWin(player)
	end
	return open ~= nil
end

-- Logs the funnel step `event` completes (once per player, in order; see OnboardingRules.Funnel). Funnel events only
-- reach the dashboard from published servers; Studio prints them instead.
function Service:Track(player, event)
	local profile = data(self, player)
	local index = profile and Rules.funnelStep(profile.Onboarding.Funnel, event)
	if not index then
		return
	end
	profile.Onboarding.Funnel = index
	local name = Rules.Funnel[index].Name
	if RunService:IsStudio() then
		print(string.format("[Onboarding funnel] %d %s (%s)", index, name, player.Name))
	end
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, index, name)
	end)
end

function Service:SetStep(player, step)
	local profile = data(self, player)
	if not profile or profile.Onboarding.Step == step then
		return
	end
	profile.Onboarding.Step = step
	player:SetAttribute("OnboardingStep", step)
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
	self:Track(player, "WelcomeOpened")
	self:SetStep(player, "Daily")
	self:Reveal(player, "Welcome", picks)
end

-- RetentionService: a Daily Rewards claim succeeded.
function Service:DailyClaimed(player)
	if self:Step(player) == "Daily" then
		self:Track(player, "DailyClaimed")
		self:SetStep(player, "Arena")
	end
end

-- MatchService: a match with `player` in it started / finished. `tutorial` = the assisted first match.
-- `first`: this is the player's first match (against the assisted Rookie Bot or a real player, decision 125).
function Service:MatchStarted(player, first)
	local step = self:Step(player)
	if first and step ~= "Match" and Rules.isFirstMatch(step) then
		self:Track(player, "FirstMatchStarted")
		self:SetStep(player, "Match")
	elseif not first and step == "Done" then
		self:Track(player, "SecondMatchStarted")
	end
end

-- `finishedVsPlayer`: a first match against a real player played to the end; it pays the first-win prize even when
-- lost (the assist only exists against the bot, and a new player losing to a person shouldn't lose the prize too).
function Service:MatchFinished(player, won, first, finishedVsPlayer)
	if not first then
		if self:Step(player) == "Done" then
			self:Track(player, "SecondMatchFinished")
		end
		return
	end
	if self:Step(player) ~= "Match" then
		return
	end
	if won then
		self:Track(player, "FirstMatchWon")
	end
	-- Lost to the bot, left or forfeited: a fresh reserved arena waits. Won, or finished against a player: the claim
	-- card for the free Kiln open.
	self:SetStep(player, if won or finishedVsPlayer then "Win" else "Arena")
end

-- The win claim's OPEN: pick (never owned), grant and play the opening.
function Service:OpenWin(player)
	local profile = data(self, player)
	if not profile or profile.Onboarding.Step ~= "Win" then
		return
	end
	local rng = Random.new()
	local pick = Rules.winPick(profile.Glassies, self.Services.KilnService:Pool(), function()
		return rng:NextNumber()
	end)
	self:Track(player, "WinOpened")
	self:SetStep(player, "Done")
	if pick then
		self:Reveal(player, "Win", { pick })
	end
end

-- DataService: profile ready.
function Service:Loaded(player)
	local step = self:Step(player)
	if step == "Match" then
		step = "Arena" -- a match can't survive a rejoin
		data(self, player).Onboarding.Step = step
	end
	player:SetAttribute("OnboardingStep", step) -- after the fix-up, or the client would wait on a match that is gone
	if step == "Arena" then
		self:Reserve(player)
	end
	if step == "Welcome" then
		self:Track(player, "Joined")
	end
end

function Service:Start()
	Remotes.OnboardingAction.OnServerEvent:Connect(function(player, action)
		if not self.Guard:Allow(player, "Onboarding", Balance.Onboarding.ActionRateSeconds) then
			return
		end
		if action == "OpenWelcome" then
			self:OpenWelcome(player)
		elseif action == "OpenWin" then
			self:OpenWin(player)
		elseif action == "Collected" then
			-- The client closed an onboarding opening (welcome or win). Only counts right after an open.
			local funnel = data(self, player) and data(self, player).Onboarding.Funnel
			if funnel == Rules.funnelStep(0, "WelcomeOpened") or funnel == Rules.funnelStep(0, "WinOpened") then
				self:Track(player, "Collected")
			end
		end
	end)
	-- An expired reservation is renewed while the player is still on the Arena step and not in a queue.
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				local arenas = self.Services.ArenaService
				if
					self:Step(player) == "Arena"
					and not arenas.ByPlayer[player]
					and not self.Services.MatchService.ByPlayer[player]
					and not arenas:ReservedFor(player)
				then
					self:Reserve(player)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.Services.ArenaService:Unreserve(player)
		self.Guard:Remove(player)
	end)
	if RunService:IsStudio() then
		-- Studio testing: jump a player to a step, e.g. ("Step", player, "Win") to see the win claim card.
		local dev = Instance.new("BindableFunction")
		dev.Name = "OnboardingDev"
		dev.OnInvoke = function(command, player, value)
			if command == "Step" and table.find(Rules.Steps, value) then
				self:SetStep(player, value)
				return true
			end
			return false
		end
		dev.Parent = game.ServerStorage
	end
end

return Service
