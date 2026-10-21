-- Crown Hill (decision 105, docs/design/FEATURED_STAGE.md): the featured arena's King of the Hill.
-- The King stands on pad A, challengers join a line with the prompt on pad B and fight the King one sudden-death
-- round at a time. The Crown Bot holds an empty hill and challenges a lonely King. Rules (line, reign cap, AFK,
-- coins, daily cap, stats) live in the pure HillRules; ArenaService hands the featured arena's Step, board and queue
-- events to this service, and MatchService hands it the hill fight's result.
--
-- Player attributes for the client (HillController): HillKing (bool), HillLine (position, 0 = not in line),
-- HillTick (count of crown coins this reign, drives "+1" pops), HillCrowned (count, drives the crown burst).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config.Hill)
local Rules = require(RS.Shared.HillRules)
local Levels = require(RS.Shared.LevelRules)
local Remotes = require(RS.Shared.Remotes)
local Board = require(script.Parent.Parent.Util.ArenaBoard)
local Audio = require(RS.Shared.Config.Audio)
local Debris = game:GetService("Debris")
local Service = {}

function Service:Init(services)
	self.Services = services
	self.Hills = {} -- [arena] = { Arena, State, Fight?, TickAt?, Crown? }
end

function Service:Hill(arena)
	local hill = self.Hills[arena]
	if not hill then
		hill = { Arena = arena, State = Rules.new(workspace:GetServerTimeNow()) }
		self.Hills[arena] = hill
	end
	return hill
end

local function byId(id)
	return id and Players:GetPlayerByUserId(id) or nil
end

local function alive(player)
	local character = player and player.Character
	local human = character and character:FindFirstChildOfClass("Humanoid")
	return human ~= nil and human.Health > 0 and character:FindFirstChild("HumanoidRootPart") ~= nil
end

function Service:Busy(player)
	return self.Services.MatchService.ByPlayer[player] ~= nil or self.Services.ArenaService.ByPlayer[player] ~= nil
end

-- Can this line member fight right now?
function Service:Eligible(arena, id)
	local player = byId(id)
	if not player or not alive(player) or self:Busy(player) then
		return false
	end
	if not self.Services.MatchService:IsReady(player) then
		return false
	end
	local root = player.Character.HumanoidRootPart
	local center = (arena.Pads[1].Position + arena.Pads[2].Position) / 2
	return (root.Position - center).Magnitude <= Config.LineRadius
end

-- Line positions as attributes (0 = not in line).
function Service:SyncLine(hill)
	for index, id in hill.State.Line do
		local player = byId(id)
		if player and player:GetAttribute("HillLine") ~= index then
			player:SetAttribute("HillLine", index)
		end
	end
end

local function clearLine(player)
	if player and player:GetAttribute("HillLine") then
		player:SetAttribute("HillLine", nil)
	end
end

-- Crown ---------------------------------------------------------------------------------------------------------

local GOLD, GOLD_DARK = Color3.fromHex("#FFC94A"), Color3.fromHex("#C9851E")
local GEMS = { Color3.fromHex("#E8445A"), Color3.fromHex("#6FB6FF"), Color3.fromHex("#E8445A") }

-- A chunky toy crown from parts, welded to a head: gold band, five points with gem tips, a soft light.
local function buildCrown(head)
	local model = Instance.new("Model")
	model.Name = "HillCrown"
	local lift = head.Size.Y / 2 + 1.1
	local base = head.CFrame * CFrame.new(0, lift, 0)
	local function part(name, size, cframe, color, material, shape)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame, p.Color = name, size, cframe, color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Reflectance = if material == Enum.Material.Neon then 0 else 0.15
		p.Shape = shape or Enum.PartType.Block
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, false, true
		p.CastShadow = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = p, head, p
		p.Parent = model
		return p
	end
	local radius, segments = 0.78, 10
	for i = 0, segments - 1 do
		local angle = i / segments * math.pi * 2
		local around = base * CFrame.Angles(0, angle, 0)
		part("Band", Vector3.new(0.52, 0.42, 0.16), around * CFrame.new(0, 0, -radius), GOLD)
	end
	for i = 0, 4 do
		local angle = i / 5 * math.pi * 2
		local around = base * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius)
		part("Point", Vector3.new(0.3, 0.55, 0.14), around * CFrame.new(0, 0.46, 0), GOLD_DARK)
		part(
			"Gem",
			Vector3.new(0.26, 0.26, 0.26),
			around * CFrame.new(0, 0.8, 0),
			GEMS[i % #GEMS + 1],
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
	end
	local core = part("Core", Vector3.new(0.2, 0.2, 0.2), base, GOLD)
	core.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Parent = GOLD, 1.2, 7, core
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "Sparkle"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(GOLD)
	sparkle.LightEmission, sparkle.Rate = 0.8, 3
	sparkle.Lifetime = NumberRange.new(0.6, 1)
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Speed = NumberRange.new(0.5, 1.2)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = core
	model.PrimaryPart = core
	return model
end

-- Puts the crown on the current King (a player's character, or the Crown Bot's stage avatar during a fight).
function Service:PlaceCrown(hill)
	local head
	local kingPlayer = byId(hill.State.King)
	if kingPlayer then
		head = kingPlayer.Character and kingPlayer.Character:FindFirstChild("Head")
	elseif hill.Arena.Busy then
		local entry = self.Services.MatchService.Matches[hill.Arena.Id]
		local bot = entry and entry.Stage and entry.Stage.Folder:FindFirstChild("Bot1")
		head = bot and bot:FindFirstChild("Head")
	end
	if head and not head:IsA("BasePart") then
		head = nil
	end
	if hill.Crown and hill.Crown.Parent and hill.CrownHead == head and head and head.Parent then
		return
	end
	if hill.Crown then
		hill.Crown:Destroy()
	end
	hill.Crown, hill.CrownHead = nil, nil
	if head and head.Parent then
		local crown = buildCrown(head)
		-- Inside the character so hide-others and streaming treat it as part of the avatar.
		crown.Parent = head.Parent
		hill.Crown, hill.CrownHead = crown, head
	end
end

-- King changes ---------------------------------------------------------------------------------------------------

function Service:SetKing(hill, previous)
	local king = hill.State.King
	local old = byId(previous)
	if old and previous ~= king then
		old:SetAttribute("HillKing", nil)
		old:SetAttribute("HillTick", nil)
	end
	local player = byId(king)
	if player then
		player:SetAttribute("HillKing", true)
		clearLine(player)
	end
	self:PlaceCrown(hill)
end

-- A chime from the King's pad that the whole island hears when the crown changes hands.
local function fanfare(arena, big)
	for _, name in if big then { "ChimeCluster", "PartyHorn" } else { "ChimeCluster" } do
		local sound = Instance.new("Sound")
		sound.Name, sound.SoundId, sound.Volume = "HillFanfare", Audio[name], 0.55
		sound.RollOffMinDistance, sound.RollOffMaxDistance = 30, Config.LineRadius + 40
		sound.Parent = arena.Pads[1]
		sound:Play()
		Debris:AddItem(sound, 4)
	end
end

-- Data -------------------------------------------------------------------------------------------------------------

function Service:Profile(player)
	local data = player and self.Services.DataService and self.Services.DataService:Get(player)
	return data, data and Rules.reconcile(data)
end

-- Pays one hill payment kind; returns the coins granted after the daily cap.
function Service:Pay(player, kind, now)
	local data, hill = self:Profile(player)
	if not data then
		return 0
	end
	local coins = Rules.pay(hill, kind, now)
	if coins > 0 then
		data.Coins += coins
	end
	if kind == "Retire" then
		local category = Rules.ticket(hill, now)
		if category and data.FreePulls then
			data.FreePulls[category] = (data.FreePulls[category] or 0) + 1
		end
	end
	return coins
end

-- Fights -----------------------------------------------------------------------------------------------------------

function Service:StartFight(hill, fight, now)
	local arena, arenaService = hill.Arena, self.Services.ArenaService
	local king, challenger = byId(fight.King), byId(fight.Challenger)
	if fight.King and not (king and arenaService.ByPlayer[king] and arenaService.ByPlayer[king].Arena == arena) then
		-- The King isn't on the pad any more: the Crown Bot takes the hill back and fights this challenger.
		local previous = hill.State.King
		Rules.stepDown(hill.State, fight.King)
		self:SetKing(hill, previous)
		fight.King, king = nil, nil
	end
	if challenger and not arenaService:Queue(challenger, arena, 2, now) then
		clearLine(challenger)
		return false
	end
	clearLine(challenger)
	if not king and not challenger then
		return false
	end
	hill.Fight = { King = fight.King, Challenger = fight.Challenger }
	hill.TickAt = now + Config.Coins.TickSeconds
	arenaService:StartArena(arena, now, {
		Hill = true,
		Hearts = Config.Hearts,
		BotName = Config.Bot.Name,
		BotSkill = Config.Bot.Skill,
	})
	self:PlaceCrown(hill)
	return true
end

-- Called by MatchService:Finish before the arena is released.
function Service:MatchFinished(entry, eligible)
	local hill = self.Hills[entry.Arena]
	local fight = hill and hill.Fight
	if not fight then
		return
	end
	hill.Fight, hill.TickAt = nil, nil
	local now = workspace:GetServerTimeNow()
	local match = entry.Runner.Match
	local kingWon = match.Winner == 1
	local state = hill.State
	local previous = state.King
	local paid = {}
	if not eligible and kingWon then
		-- The challenger quit before the round finished: no defence, no coins.
		state.ReadyAt = now + Config.GapSeconds
	else
		local aimed = fight.King == nil or entry.Runner.Locked[1] == true
		local outcome = Rules.result(state, fight.King, fight.Challenger, kingWon, aimed, now)
		if eligible then
			for _, payment in outcome.Pay do
				local player = byId(payment.Id)
				local side = player and table.find(entry.Players, player)
				-- Quitting a hill fight pays nothing, like a normal match.
				if player and not (side and entry.Forfeited[side]) then
					paid[player] = (paid[player] or 0) + self:Pay(player, payment.Kind, now)
				end
			end
		end
		for _, id in { fight.King, fight.Challenger } do
			local player = id and byId(id)
			local _, profile = self:Profile(player)
			if profile then
				Rules.record(profile, id, outcome)
			end
		end
		if outcome.Crowned or outcome.Kind == "Retired" then
			fanfare(hill.Arena, outcome.Kind == "Retired")
		end
		local crowned = byId(outcome.Crowned)
		if crowned then
			crowned:SetAttribute("HillCrowned", (crowned:GetAttribute("HillCrowned") or 0) + 1)
			crowned:SetAttribute("HillTick", 0)
		end
		if outcome.Kind == "Retired" then
			local retired = byId(outcome.OldKing)
			if retired then
				retired:SetAttribute("HillRetired", (retired:GetAttribute("HillRetired") or 0) + 1)
			end
		end
	end
	self:SetKing(hill, previous)
	for side, player in entry.Players do
		if player.Parent ~= Players then
			continue
		end
		local data, profile = self:Profile(player)
		-- Level XP (decision 104): a hill fight earns a share of a normal match's XP.
		local xp, levels = 0, 0
		if data and eligible then
			xp = math.floor(Levels.matchXp({
				Won = match.Winner == side,
				RoundsWon = entry.ActualWins[side],
				Perfects = entry.Perfects[side],
				VsBot = entry.Players[3 - side] == nil,
				Forfeited = entry.Forfeited[side] == true,
			}) * Config.XpShare)
			data.Xp, levels = Levels.add(data.Xp, xp)
		end
		if self.Services.DataService then
			self.Services.DataService:CommitCurrency(player)
		end
		Remotes.MatchResult:FireClient(player, {
			MatchId = entry.Id,
			Won = match.Winner == side,
			NoContest = not eligible,
			Side = side,
			Rewards = { Coins = paid[player] or 0, Trophies = 0 },
			History = if eligible then match.History else {},
			Hearts = { match.Sides[1].Hearts, match.Sides[2].Hearts },
			Saved = self.Services.DataService and self.Services.DataService:IsPersistent(player) or false,
			ArenaId = entry.Arena.Id,
			Names = self.Services.MatchService:Meta(entry).Names,
			Xp = { Gained = xp, LevelsGained = levels },
			Hill = { King = state.King == player.UserId, Reign = state.Reign, Crowns = profile and profile.Crowns },
		})
	end
end

-- Queue events from ArenaService ----------------------------------------------------------------------------------

-- A queued player on the hill left their pad (Leave button, reset or left the game).
function Service:QueueLeft(arena, player, side)
	local hill = self.Hills[arena]
	if not hill then
		return
	end
	if side == 1 and hill.State.King == player.UserId then
		local previous = hill.State.King
		Rules.stepDown(hill.State, player.UserId)
		self:SetKing(hill, previous)
	end
end

function Service:Join(player, arena)
	local hill = self:Hill(arena)
	if self:Busy(player) then
		return
	end
	local onboarding = self.Services.OnboardingService
	if onboarding and onboarding:BeforePlay(player) then
		return -- a new player's claim card opens first (decision 100)
	end
	local ok = Rules.join(hill.State, player.UserId)
	if ok then
		self:SyncLine(hill)
		self:Board(arena)
	end
end

-- Step (from ArenaService, every QueueCheckSeconds) ------------------------------------------------------------------

function Service:Step(arena, now)
	local hill = self:Hill(arena)
	local state = hill.State
	-- Drop line members who left the game or went to play somewhere else.
	for index = #state.Line, 1, -1 do
		local player = byId(state.Line[index])
		if not player or self:Busy(player) then
			table.remove(state.Line, index)
			clearLine(player)
		end
	end
	self:SyncLine(hill)
	local king = byId(state.King)
	if state.King and not king then
		-- The King left the game.
		local previous = state.King
		Rules.stepDown(state, previous)
		self:SetKing(hill, previous)
	end
	if arena.Busy then
		-- Crown coins trickle while the King is fighting.
		if king and hill.Fight and hill.Fight.King == state.King and hill.TickAt and now >= hill.TickAt then
			hill.TickAt = now + Config.Coins.TickSeconds
			local coins = self:Pay(king, "Tick", now)
			if coins > 0 then
				king:SetAttribute("HillTick", (king:GetAttribute("HillTick") or 0) + coins)
				self.Services.DataService:Sync(king)
			end
		end
		self:PlaceCrown(hill)
		return
	end
	-- Between fights the King waits on pad A.
	local arenaService = self.Services.ArenaService
	if king and not arenaService.ByPlayer[king] then
		if self.Services.MatchService.ByPlayer[king] or not arenaService:Queue(king, arena, 1, now) then
			local previous = state.King
			Rules.stepDown(state, previous)
			self:SetKing(hill, previous)
			king = nil
		else
			self:PlaceCrown(hill)
		end
	end
	local fight, skipped = Rules.nextFight(state, now, function(id)
		return self:Eligible(arena, id)
	end)
	for _, id in skipped do
		clearLine(byId(id))
	end
	if fight and self:StartFight(hill, fight, now) then
		return -- MatchService draws the battle board.
	end
	self:PlaceCrown(hill)
	self:Board(arena)
end

-- Board -------------------------------------------------------------------------------------------------------------

local CROWN_ICON = "screens/profile/icon_crown"

function Service:Board(arena, meta)
	local hill = self:Hill(arena)
	local state = hill.State
	local king = byId(state.King)
	local kingSide = if king
		then { UserId = king.UserId, Name = king.DisplayName }
		else { UserId = 0, Name = Config.Bot.Name }
	local challenger
	if meta then
		challenger = { UserId = meta.PlayerIds[2], Name = meta.Names[2] }
		if meta.PlayerIds[1] == 0 then
			kingSide = { UserId = 0, Name = meta.Names[1] }
		end
	else
		local next = byId(state.Line[1])
		challenger = next and { UserId = next.UserId, Name = next.DisplayName } or nil
	end
	local now = workspace:GetServerTimeNow()
	local status
	if meta then
		status = "SUDDEN DEATH!"
	elseif #state.Line > 0 then
		status = "Next up: " .. (challenger and challenger.Name or "?")
	elseif king then
		local wait = math.max(0, state.ReadyAt, state.IdleSince or now) + Config.BotChallengeSeconds
		status = Config.Bot.Name .. " challenges in " .. math.max(0, math.ceil(wait - now)) .. "s"
	else
		status = "Step on the pad to challenge!"
	end
	Board.update(arena.Board, {
		Title = Config.Title,
		Count = if meta then "IN BATTLE" else "LINE: " .. #state.Line,
		Status = status,
		Sides = { kingSide, challenger },
		Win = state.Reign .. " / " .. Config.ReignCap,
		WinIcon = CROWN_ICON,
		Crown = true,
	})
end

function Service:Start()
	Players.PlayerRemoving:Connect(function(player)
		for _, hill in self.Hills do
			Rules.leave(hill.State, player.UserId)
		end
	end)
	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "HillDev"
		dev.OnInvoke = function(command, ...)
			local arena
			for a in self.Hills do
				arena = a
			end
			for _, a in self.Services.ArenaService.Arenas do
				if a.Hill then
					arena = a
				end
			end
			if not arena then
				return nil
			end
			local hill = self:Hill(arena)
			if command == "Join" then
				self:Join(..., arena)
				return true
			elseif command == "King" then
				-- Make a player King at once (testing the defence loop).
				local player = ...
				local previous = hill.State.King
				hill.State.King, hill.State.Reign, hill.State.Misses = player and player.UserId, 0, 0
				self:SetKing(hill, previous)
				return true
			elseif command == "End" then
				-- End the running hill fight now: winner side (1 = King, 2 = challenger), and whether the King aimed.
				local winner, aimed = ...
				local entry = self.Services.MatchService.Matches[arena.Id]
				if not entry or not entry.Hill or entry.Finished then
					return false
				end
				local now = workspace:GetServerTimeNow()
				entry.ActualWins[winner] += 1
				entry.Runner.Locked[1] = aimed ~= false
				entry.Runner:Forfeit(3 - winner, now)
				self.Services.MatchService:Dispatch(entry, now)
				return true
			elseif command == "Profile" then
				local data, profile = self:Profile(...)
				return data and { Hill = profile, FreePulls = data.FreePulls, Coins = data.Coins }
			elseif command == "Ready" then
				hill.State.ReadyAt, hill.State.IdleSince = 0, nil
				return true
			end
			local line = {}
			for _, id in hill.State.Line do
				table.insert(line, id)
			end
			return {
				ArenaId = arena.Id,
				King = hill.State.King,
				Reign = hill.State.Reign,
				Misses = hill.State.Misses,
				Line = line,
				Busy = arena.Busy,
				Fight = hill.Fight,
				ReadyAt = hill.State.ReadyAt,
				Now = workspace:GetServerTimeNow(),
				Crown = hill.Crown and hill.Crown:GetFullName(),
			}
		end
		dev.Parent = game.ServerStorage
	end
end

return Service
