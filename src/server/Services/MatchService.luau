local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Balance = require(RS.Shared.Config.Balance)
local Logic = require(RS.Shared.MatchLogic)
local Rules = require(RS.Shared.FightRules)
local Rng = require(RS.Shared.Rng)
local Remotes = require(RS.Shared.Remotes)
local Runner = require(script.Parent.Parent.Simulation.MatchRunner)
local Guard = require(script.Parent.Parent.Util.RemoteGuard)
local Assets = require(script.Parent.Parent.Util.AssetCatalog)
local Glassies = require(RS.Shared.Config.Glassies)
local Bots = require(RS.Shared.Config.Bots)
local Stage = require(script.Parent.Parent.Util.MatchStage)
local CosmeticConfig = require(RS.Shared.Config.RoundCosmetics)
local CosmeticRules = require(RS.Shared.RoundCosmeticRules)
local PolicyService = game:GetService("PolicyService")
local OnboardingRules = require(script.Parent.Parent.Data.OnboardingRules)
local Service = {}

function Service:Init(services)
	self.Services, self.Matches, self.ByPlayer, self.Serial, self.Temporary = services, {}, {}, 0, {}
	self.Guard = Guard.new()
	self.CharacterConnections = {}
	self.PaidRandomAllowed = {}
end

function Service:IsReady(player)
	return not self.Services.DataService or self.Services.DataService:IsReady(player)
end

function Service:Collection(player)
	local data = player and self.Services.DataService and self.Services.DataService:Get(player)
	return Assets.collection(data and data.Glassies or {})
end

function Service:Meta(entry)
	local match = entry.Runner.Match
	local out = {
		MatchId = entry.Id,
		Round = match.Round,
		Hearts = {},
		Names = {},
		PlayerIds = {},
		LastPicks = {},
		ArenaId = entry.Arena.Id,
		Spectate = entry.Spectate,
		Deadline = entry.Runner.Deadline,
		Phase = entry.Runner.Phase,
		StageName = entry.Stage and entry.Stage.Folder.Name,
		Rideables = entry.Cosmetics and entry.Cosmetics.Rideables,
		Finishers = entry.Cosmetics and entry.Cosmetics.Finishers,
	}
	for side = 1, 2 do
		local player = entry.Players[side]
		out.Hearts[side], out.Names[side] =
			match.Sides[side].Hearts, player and player.DisplayName or entry.BotNames[side]
		out.PlayerIds[side], out.LastPicks[side] = player and player.UserId or 0, match.Sides[side].LastPick or ""
	end
	return out
end

function Service:Offer(entry, side, message, reelAction)
	local player = entry.Players[side]
	if not player or not player.Parent then
		return
	end
	local state = entry.Runner.Match.Sides[side]
	local collection = state.Collection
	local data = self.Services.DataService and self.Services.DataService:Get(player)
	Remotes.RollOffers:FireClient(player, {
		MatchId = entry.Id,
		Round = entry.Runner.Match.Round,
		Deadline = entry.Runner.Deadline,
		Offers = state.Offers,
		Collection = collection,
		HandRevision = state.HandRevision,
		ReelAction = reelAction,
		SelectionRevision = state.SelectionRevision,
		RerollCost = Logic.rerollCost(state.RerollsUsed),
		PickAnyCost = Logic.pickAnyCost(state.PickAnyUsed),
		Marbles = data and data.Marbles or 0,
		PaidRandomAllowed = self.PaidRandomAllowed[player] == true,
		CanReroll = #Logic.ownedIds(collection) > Balance.Match.RollChoices
			and self.PaidRandomAllowed[player] == true
			and not state.Pick,
		CanPickAny = not state.Pick,
		Picked = state.Pick,
		Message = message,
	})
end

function Service:StartMatch(arena, players, now, spectate)
	if self.Matches[arena.Id] then
		return false
	end
	self.Serial += 1
	local seed = Random.new():NextInteger(1, 100000000)
	local rng = Rng.new(seed)
	local setups = {}
	local humanCollection = self:Collection(players[1] or players[2])
	-- Onboarding (decision 100): a new player's first match against a bot is assisted (OnboardingRules.assist).
	local tutorial = nil
	local onboarding = self.Services.OnboardingService
	for side = 1, 2 do
		local player = players[side]
		if player and not players[3 - side] and onboarding and onboarding:IsFirstMatch(player) then
			tutorial = { Side = side, Player = player }
		end
	end
	for side = 1, 2 do
		setups[side] = {
			Collection = players[side] and self:Collection(players[side])
				or Assets.collection(Logic.botCollection(humanCollection, rng)),
			IsBot = players[side] == nil,
			Skill = if tutorial and side ~= tutorial.Side
				then Balance.Onboarding.BotSkill
				else Balance.Match.BotSkillMin + rng() * (Balance.Match.BotSkillMax - Balance.Match.BotSkillMin),
		}
	end
	local entry = {
		Id = (game.JobId ~= "" and game.JobId or "studio") .. "-match-" .. self.Serial,
		Arena = arena,
		Players = players,
		Seed = seed,
		Spectate = spectate == true,
		Runner = Runner.new(
			setups,
			rng,
			now,
			if tutorial then { RollSeconds = Balance.Onboarding.RollSeconds } else nil
		),
		Tutorial = tutorial,
		Perfects = { 0, 0 },
		ActualWins = { 0, 0 },
		HeavyShatters = { 0, 0 },
		Chip = { 0, 0 }, -- share of the winner's HP dealt in lost fights (loss coins)
		Forfeited = { false, false },
		Used = { {}, {} },
		BotNames = {},
		Finished = false,
		Cosmetics = { Rideables = {}, Finishers = {} },
	}
	for side = 1, 2 do
		local data = players[side] and self.Services.DataService and self.Services.DataService:Get(players[side])
		local cosmetics = data and CosmeticRules.loadout(data)
		-- "" = nothing equipped: no ride, basic glass-break finisher (decision 95).
		entry.Cosmetics.Rideables[side] = cosmetics and cosmetics.Rideables or ""
		entry.Cosmetics.Finishers[side] = cosmetics and cosmetics.Finishers or ""
		if not players[side] then
			-- Visual variety without consuming or changing the gameplay RNG stream.
			entry.Cosmetics.Rideables[side] = CosmeticConfig.Rideables[(seed + side) % #CosmeticConfig.Rideables + 1].Id
			entry.Cosmetics.Finishers[side] = CosmeticConfig.Finishers[(seed + side) % #CosmeticConfig.Finishers + 1].Id
			entry.BotNames[side] = if tutorial
				then Balance.Onboarding.BotName
				else Bots.Names[math.floor(rng() * #Bots.Names) + 1]
		end
	end
	self.Matches[arena.Id] = entry
	arena.Busy = true
	for side, player in players do
		self.ByPlayer[player] = { Entry = entry, Side = side }
	end
	Stage.start(entry)
	if onboarding then
		for _, player in players do
			onboarding:MatchStarted(player, tutorial ~= nil and tutorial.Player == player)
		end
	end
	self:Dispatch(entry, now)
	return true, entry.Id
end

function Service:Finish(entry)
	if entry.Finished then
		return
	end
	entry.Finished = true
	local match = entry.Runner.Match
	local eligible = entry.ActualWins[1] + entry.ActualWins[2] > 0
	local names = self:Meta(entry).Names
	if entry.FightId then
		self.Services.FightService:Stop(entry.FightId, { MatchId = entry.Id, ArenaId = entry.Arena.Id, Over = true })
	end
	Stage.finish(entry)
	for side, player in entry.Players do
		self.ByPlayer[player] = nil
		if not player.Parent then
			continue
		end
		local profile = self.Services.DataService and self.Services.DataService:Get(player)
		local temp = self.Temporary[player] or { Coins = 0, Trophies = 0 }
		self.Temporary[player] = temp
		local rewards = Logic.rewards(match, side, profile and profile.Trophies or temp.Trophies, eligible, {
			Hearts = entry.ActualWins[side],
			Chip = entry.Chip[side],
			Perfects = entry.Perfects[side],
			Forfeited = entry.Forfeited[side],
		})
		-- XP (decision 104): ProfileSchema.recordMatch writes XpGained / LevelsGained back into this table.
		local observed = {
			Eligible = eligible,
			Perfects = entry.Perfects[side],
			RoundWins = entry.ActualWins[side],
			Shatters = entry.ActualWins[side],
			Used = entry.Used[side],
			HeavyShatters = entry.HeavyShatters[side],
			VsBot = entry.Players[3 - side] == nil,
			Forfeited = entry.Forfeited[side] == true,
		}
		if self.Services.DataService then
			self.Services.DataService:RecordMatch(player, entry.Id, match, side, rewards, observed)
		else
			temp.Coins += rewards.Coins
			temp.Trophies += rewards.Trophies
		end
		Remotes.MatchResult:FireClient(player, {
			MatchId = entry.Id,
			Won = match.Winner == side,
			NoContest = not eligible,
			Side = side,
			Rewards = rewards,
			History = if eligible then match.History else {},
			Hearts = { match.Sides[1].Hearts, match.Sides[2].Hearts },
			Saved = self.Services.DataService and self.Services.DataService:IsPersistent(player) or false,
			ArenaId = entry.Arena.Id,
			Names = names,
			Quests = self.Services.RetentionService and self.Services.RetentionService:View(player).Quests or {},
			FirstMatch = entry.Tutorial ~= nil and entry.Tutorial.Player == player,
			Xp = { Gained = observed.XpGained or 0, LevelsGained = observed.LevelsGained or 0 },
		})
		if self.Services.OnboardingService then
			self.Services.OnboardingService:MatchFinished(
				player,
				match.Winner == side and not entry.Forfeited[side],
				entry.Tutorial ~= nil and entry.Tutorial.Player == player
			)
		end
	end
	self.Matches[entry.Arena.Id] = nil
	self.Services.ArenaService:Release(entry.Arena, entry.Players)
end

function Service:Dispatch(entry, now)
	for _, change in entry.Runner:Drain() do
		local meta = self:Meta(entry)
		local match = entry.Runner.Match
		if change.Phase == "Rolling" then
			if entry.FightId then
				self.Services.FightService:Stop(
					entry.FightId,
					{ MatchId = entry.Id, ArenaId = entry.Arena.Id, Over = false }
				)
			end
			entry.FightId = entry.Id .. "-round-" .. match.Round
			for side, player in entry.Players do
				Remotes.MatchState:FireClient(player, meta)
				self:Offer(entry, side)
			end
		elseif change.Phase == "Aiming" or change.Phase == "Countdown" then
			local setup = Logic.fightSetup(match)
			meta.Id, meta.ReleaseAt = entry.FightId, if change.Phase == "Countdown" then change.Deadline else nil
			if change.Phase == "Aiming" then
				for _, state in match.Sides do
					if not state.IsBot then
						state.Aim, state.AimYaw = nil, nil
					end
				end
				setup.A.Aim, setup.A.AimYaw, setup.B.Aim, setup.B.AimYaw =
					Balance.Motion.AimDefault, 0, Balance.Motion.AimDefault, 0
			end
			Remotes.MatchState:FireAllClients(self.Services.FightService:Describe(entry.Arena, setup, meta))
		elseif change.Phase == "Fighting" then
			local setup = Logic.fightSetup(match)
			if entry.Tutorial then
				setup.Assist = OnboardingRules.assist(match.Round, entry.Tutorial.Side)
				if match.Round == 1 then
					self.Services.OnboardingService:Track(entry.Tutorial.Player, "FirstFightStarted")
				end
			end
			for side, state in match.Sides do
				entry.Used[side][state.Pick] = true
			end
			meta.Id = entry.FightId
			for side, state in match.Sides do
				if Rules.isPerfect(state.Aim, match.SweetSpot) then
					entry.Perfects[side] += 1
				end
			end
			self.Services.FightService:StartFight(
				entry.FightId,
				entry.Arena,
				setup,
				entry.Seed + match.Round,
				meta,
				function(fight)
					if entry.Finished then
						return
					end
					if entry.Runner:FightEnded(fight.Winner, workspace:GetServerTimeNow()) then
						entry.ActualWins[fight.Winner] += 1
						local winner = fight.Fighters[fight.Winner]
						entry.Chip[3 - fight.Winner] += math.clamp(1 - winner.Hp / math.max(winner.MaxHp, 1), 0, 1)
						if Glassies.get(match.Sides[3 - fight.Winner].Pick).Type == "Heavy" then
							entry.HeavyShatters[fight.Winner] += 1
						end
						self:Dispatch(entry, workspace:GetServerTimeNow())
					end
				end
			)
		elseif change.Phase == "RoundEnd" then
			meta.Id = entry.FightId
			local setup = Logic.fightSetup(match)
			meta.RoundWinner = match.History[#match.History].Winner
			if entry.Tutorial and #match.History == 1 then
				self.Services.OnboardingService:Track(entry.Tutorial.Player, "FirstRoundFinished")
			end
			Remotes.MatchState:FireAllClients(self.Services.FightService:Describe(entry.Arena, setup, meta))
		elseif change.Phase == "MatchEnd" then
			self:Finish(entry)
		end
		if not entry.Finished then
			self.Services.ArenaService:MatchBoard(entry.Arena, meta)
		end
	end
end

function Service:Request(player, action, interval, callback)
	if not self.Guard:Allow(player, action, interval) then
		return
	end
	local owned = self.ByPlayer[player]
	if not owned or owned.Entry.Finished then
		return
	end
	callback(owned.Entry, owned.Side)
end

function Service:Forfeit(player)
	local owned = self.ByPlayer[player]
	if owned and not owned.Entry.Finished then
		owned.Entry.Forfeited[owned.Side] = true
		owned.Entry.Runner:Forfeit(owned.Side, workspace:GetServerTimeNow())
		self:Dispatch(owned.Entry, workspace:GetServerTimeNow())
	end
end

-- A quoted action is tied to one match, round and selection revision. Nothing below yields
-- until both wallet debit and match mutation have completed, so stale/replayed requests cannot charge.
function Service:Selection(entry, side, kind, id, matchId, round, revision, quotedCost)
	local runner, state = entry.Runner, entry.Runner.Match.Sides[side]
	local function reject(reason)
		self:Offer(entry, side, reason)
		return false, reason
	end
	if matchId ~= entry.Id or round ~= runner.Match.Round or revision ~= state.SelectionRevision then
		return reject("stale")
	end
	if runner.Phase ~= "Rolling" or workspace:GetServerTimeNow() >= runner.Deadline then
		return reject("phase")
	end
	local cost = if kind == "Reroll" then Logic.rerollCost(state.RerollsUsed) else Logic.pickAnyCost(state.PickAnyUsed)
	if quotedCost ~= cost then
		return reject("price_changed")
	end
	if kind == "Reroll" then
		if self.PaidRandomAllowed[entry.Players[side]] ~= true then
			return reject("restricted")
		end
		if runner.Deadline - workspace:GetServerTimeNow() < Balance.Match.RerollReserveSeconds then
			return reject("too_late")
		end
	end
	local allowed, reason
	if kind == "Reroll" then
		allowed, reason = Logic.canReroll(runner.Match, side)
	else
		allowed, reason = Logic.canPickAny(runner.Match, side, id)
	end
	if not allowed then
		return reject(reason)
	end
	local player = entry.Players[side]
	local service = self.Services.DataService
	local data = service and service:Get(player)
	if not data then
		return reject("data_unavailable")
	end
	if not service:SpendMarbles(player, cost) then
		return reject("insufficient_marbles")
	end
	local ok
	if kind == "Reroll" then
		ok, reason = runner:Reroll(side)
	else
		ok, reason = runner:PickAny(side, id)
	end
	if not ok then
		data.Marbles += cost
		return reject(reason)
	end
	self:Offer(entry, side, nil, if kind == "Reroll" then "Reroll" else nil)
	service:CommitCurrency(player)
	runner:Step(workspace:GetServerTimeNow())
	self:Dispatch(entry, workspace:GetServerTimeNow())
	return true
end

function Service:Start()
	local function track(player)
		task.spawn(function()
			local ok, policy = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
			if player.Parent ~= Players then
				return
			end
			self.PaidRandomAllowed[player] = ok
				and type(policy) == "table"
				and policy.ArePaidRandomItemsRestricted == false
			local current = self.ByPlayer[player]
			if current and current.Entry.Runner.Phase == "Rolling" then
				self:Offer(current.Entry, current.Side)
			end
		end)
		-- Forfeit as soon as the character dies (reset), not ~5 s later when it is removed at respawn.
		local function watch(character)
			local humanoid = character:WaitForChild("Humanoid", 5)
			if humanoid then
				humanoid.Died:Once(function()
					self:Forfeit(player)
				end)
			end
		end
		self.CharacterConnections[player] = {
			player.CharacterRemoving:Connect(function()
				self:Forfeit(player)
			end),
			player.CharacterAdded:Connect(watch),
		}
		if player.Character then
			task.spawn(watch, player.Character)
		end
	end
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	Remotes.PickGlassy.OnServerEvent:Connect(function(player, id)
		self:Request(player, "Pick", Balance.Match.PickRateSeconds, function(entry, side)
			if type(id) ~= "string" or #id > 64 then
				return
			end
			entry.Runner:Pick(side, id)
			self:Offer(entry, side)
			entry.Runner:Step(workspace:GetServerTimeNow())
			self:Dispatch(entry, workspace:GetServerTimeNow())
		end)
	end)
	Remotes.Reroll.OnServerEvent:Connect(function(player, matchId, round, revision, cost)
		self:Request(player, "Reroll", Balance.Match.RerollRateSeconds, function(entry, side)
			self:Selection(entry, side, "Reroll", nil, matchId, round, revision, cost)
		end)
	end)
	Remotes.PickAny.OnServerEvent:Connect(function(player, id, matchId, round, revision, cost)
		self:Request(player, "PickAny", Balance.Match.PickAnyRateSeconds, function(entry, side)
			if type(id) ~= "string" or #id > 64 then
				return
			end
			self:Selection(entry, side, "PickAny", id, matchId, round, revision, cost)
		end)
	end)
	Remotes.SetAim.OnServerEvent:Connect(function(player, aim, yaw)
		self:Request(player, "Aim", Balance.Match.AimRateSeconds, function(entry, side)
			if not Guard.finite(aim) or not Guard.finite(yaw) then
				return
			end
			entry.Runner:Aim(side, aim, yaw)
			entry.Runner:Step(workspace:GetServerTimeNow())
			self:Dispatch(entry, workspace:GetServerTimeNow())
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:Forfeit(player)
		for _, connection in self.CharacterConnections[player] or {} do
			connection:Disconnect()
		end
		self.CharacterConnections[player] = nil
		self.ByPlayer[player], self.Temporary[player] = nil, nil
		self.PaidRandomAllowed[player] = nil
		self.Guard:Remove(player)
	end)
	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		for _, entry in self.Matches do
			entry.Runner:Step(now)
			self:Dispatch(entry, now)
		end
	end)
	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "MatchDev"
		dev.OnInvoke = function(command, ...)
			if command == "SelectionAttempt" and self.Services.DataService.Mock then
				local player, kind, id, quote = ...
				local current = self.ByPlayer[player]
				if not current then
					return false, "no_match"
				end
				return self:Selection(
					current.Entry,
					current.Side,
					kind,
					id,
					quote.MatchId,
					quote.Round,
					quote.SelectionRevision,
					quote.Cost
				)
			end
			if command == "SelectionState" then
				local player = ...
				local current = self.ByPlayer[player]
				if not current then
					return nil
				end
				local entry, state = current.Entry, current.Entry.Runner.Match.Sides[current.Side]
				return {
					MatchId = entry.Id,
					Round = entry.Runner.Match.Round,
					Phase = entry.Runner.Phase,
					Offers = table.clone(state.Offers),
					Pick = state.Pick,
					HandRevision = state.HandRevision,
					SelectionRevision = state.SelectionRevision,
					RerollsUsed = state.RerollsUsed,
					PickAnyUsed = state.PickAnyUsed,
					Marbles = self.Services.DataService:Get(player).Marbles,
				}
			end
			if command == "SelectionTest" and self.Services.DataService.Mock then
				local action, player, value = ...
				if action == "Policy" then
					self.PaidRandomAllowed[player] = value
					return true
				end
				local current = self.ByPlayer[player]
				if not current then
					return false
				end
				if action == "Hold" then
					current.Entry.Runner.Deadline = workspace:GetServerTimeNow() + value
					self:Offer(current.Entry, current.Side)
					return true
				end
				if action == "NextRound" then
					current.Entry.Runner:StartRound(workspace:GetServerTimeNow())
					self:Dispatch(current.Entry, workspace:GetServerTimeNow())
					return true
				end
				if action == "Forfeit" then
					self:Forfeit(player)
					return true
				end
			end
			if command == "Start" then
				local id, a, b = ...
				local arena = self.Services.ArenaService.Arenas[id]
				if not arena or arena.Busy then
					return false
				end
				return self:StartMatch(arena, { [1] = a, [2] = b }, workspace:GetServerTimeNow())
			end
			if command == "AllBots" then
				local out = {}
				for id, arena in self.Services.ArenaService.Arenas do
					if not arena.Busy then
						out[id] = { self:StartMatch(arena, {}, workspace:GetServerTimeNow(), id == 1) }
					end
				end
				return out
			end
			if command == "Inspect" then
				local out = {}
				for id, e in self.Matches do
					out[id] = {
						Phase = e.Runner.Phase,
						Round = e.Runner.Match.Round,
						Hearts = { e.Runner.Match.Sides[1].Hearts, e.Runner.Match.Sides[2].Hearts },
					}
				end
				return out
			end
		end
		dev.Parent = game.ServerStorage
	end
end

return Service
