-- Arena queues. Players join a side with the ProximityPrompt on its pad (or PLAY / Rematch),
-- are fixed to that spot facing the arena until the match ends or they leave (LeaveQueue or a
-- reset), and a bot fills an empty side after Balance.Match.QueueBotAfterSeconds.
--
-- MatchState messages sent to the queued player (the client moves the camera and shows Leave):
--   { Phase = "Queue", ArenaId, Side, Deadline, Locked = true, CanLeave = true,
--     Spot: CFrame (where the avatar is fixed), Center: Vector3 (middle of the arena) }
--   { Phase = "QueueLeft", ArenaId, Reason = "Left" | "Reset" | "MatchOver" }
--     "MatchOver" is sent once the match ends and the avatar is free to move again.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Balance = require(RS.Shared.Config.Balance)
local Remotes = require(RS.Shared.Remotes)
local Guard = require(script.Parent.Parent.Util.RemoteGuard)
local Stage = require(script.Parent.Parent.Util.MatchStage)
local Board = require(script.Parent.Parent.Util.ArenaBoard)
local Service = {}

function Service:Init(services)
	self.Services, self.Arenas, self.ByPlayer, self.Locks, self.Recent = services, {}, {}, {}, {}
	self.Reserved = {} -- [player] = { Arena, Until }: onboarding first match (decision 100)
	self.Guard, self.Accumulator = Guard.new(), 0
	-- Backups of old lobbies in ServerStorage carry the same tags; only live stands count.
	for _, stand in CollectionService:GetTagged("ArenaStand") do
		local id = stand:GetAttribute("ArenaId")
		if type(id) == "number" and stand:IsDescendantOf(workspace) then
			self.Arenas[id] = { Id = id, Stand = stand, Pads = {}, Queue = {}, Prompts = {} }
		end
	end
	for _, pad in CollectionService:GetTagged("QueuePad") do
		local arena = self.Arenas[pad:GetAttribute("ArenaId")]
		local side = if pad:GetAttribute("Side") == "A" then 1 else 2
		if arena and pad:IsDescendantOf(arena.Stand) then
			arena.Pads[side] = pad
		end
	end
	for _, arena in self.Arenas do
		assert(arena.Pads[1] and arena.Pads[2], "Arena missing queue pads")
	end
end

function Service:Title(arena)
	return if arena.Stand:GetAttribute("Featured") then "FEATURED ARENA" else "ARENA " .. arena.Id
end

local function who(player)
	return player and { UserId = player.UserId, Name = player.DisplayName } or nil
end

-- Bot Play setting (decision 99): a lone queued player who turned it off waits for a real opponent.
function Service:BotsAllowed(arena)
	local solo = arena.Queue[1] or arena.Queue[2]
	local settings = self.Services.SettingsService
	return solo == nil or settings == nil or settings:Get(solo).BotPlay ~= false
end

-- Onboarding (decision 100): a new player's first match waits in the nearest free arena with a bot ready.
-- Nobody else can queue there while it is reserved; the reserved player starts at once.
function Service:ReservedFor(player)
	local entry = self.Reserved[player]
	if entry and (os.clock() > entry.Until or entry.Arena.Busy) then
		self:Unreserve(player)
		return nil
	end
	return entry and entry.Arena
end

function Service:Holder(arena)
	for player, entry in self.Reserved do
		if entry.Arena == arena and os.clock() <= entry.Until then
			return player
		end
	end
	return nil
end

-- Reserves the free arena nearest the player and returns its nearest pad (nil if none is free).
function Service:Reserve(player)
	self:Unreserve(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local from = if root then root.Position else workspace.Lobby.SpawnLocation.Position
	local best, bestPad, distance = nil, nil, math.huge
	for _, arena in self.Arenas do
		if not arena.Busy and not arena.Queue[1] and not arena.Queue[2] and not self:Holder(arena) then
			for _, pad in arena.Pads do
				local d = (pad.Position - from).Magnitude
				if d < distance then
					best, bestPad, distance = arena, pad, d
				end
			end
		end
	end
	if not best then
		return nil
	end
	self.Reserved[player] = { Arena = best, Until = os.clock() + Balance.Onboarding.ReserveSeconds }
	self:QueueBoard(best, workspace:GetServerTimeNow())
	return bestPad
end

function Service:Unreserve(player)
	local entry = self.Reserved[player]
	self.Reserved[player] = nil
	if entry then
		self:QueueBoard(entry.Arena, workspace:GetServerTimeNow())
	end
end

-- Queue board for an arena that is not fighting.
function Service:QueueBoard(arena, now)
	local a, b = arena.Queue[1], arena.Queue[2]
	local count = (if a then 1 else 0) + (if b then 1 else 0)
	local holder = self:Holder(arena)
	local status = if count == 0 and holder
		then "Reserved for " .. holder.DisplayName .. "!"
		elseif count == 0 then "Walk up to a pad and press to join!"
		elseif not self:BotsAllowed(arena) then "Waiting for a player…"
		else "Bot joins in " .. math.max(
			0,
			math.ceil((arena.QueuedAt or now) + Balance.Match.QueueBotAfterSeconds - now)
		) .. "s"
	Board.update(arena.Board, {
		Title = self:Title(arena),
		Count = count .. " / 2 PLAYERS",
		Status = status,
		Sides = { who(a), who(b) },
	})
end

-- Board while a match runs; MatchService passes its meta (names, ids, hearts, round).
function Service:MatchBoard(arena, meta)
	local sides = {}
	for side = 1, 2 do
		sides[side] = { UserId = meta.PlayerIds[side], Name = meta.Names[side] }
	end
	Board.update(arena.Board, {
		Title = self:Title(arena),
		Count = "IN BATTLE",
		Status = string.rep("♥", meta.Hearts[1]) .. "  ROUND " .. meta.Round .. "  " .. string.rep(
			"♥",
			meta.Hearts[2]
		),
		Sides = sides,
	})
end

-- Pad glows and prompts show the arena state: open, someone waiting there, or match on.
function Service:PadState(arena)
	for side, pad in arena.Pads do
		local prompt = arena.Prompts[side]
		local open = not arena.Busy and not arena.Queue[side]
		if prompt and prompt.Enabled ~= open then
			prompt.Enabled = open
		end
		local glow = pad:FindFirstChild("Glow")
		if not glow or not glow:IsA("BasePart") then
			continue
		end
		if glow:GetAttribute("OpenColor") == nil then
			glow:SetAttribute("OpenColor", glow.Color)
			glow:SetAttribute("OpenTransparency", glow.Transparency)
		end
		local state = if arena.Busy then "Busy" elseif arena.Queue[side] then "Waiting" else "Open"
		if glow:GetAttribute("PadState") == state then
			continue
		end
		glow:SetAttribute("PadState", state)
		local openColor, base = glow:GetAttribute("OpenColor"), glow:GetAttribute("OpenTransparency")
		glow.Color = if state == "Busy" then Color3.fromHex(Balance.Lobby.BusyPadColor) else openColor
		glow.Transparency = if state == "Busy"
			then Balance.Lobby.BusyPadTransparency
			elseif state == "Waiting" then Balance.Lobby.WaitingPadTransparency
			else base
	end
end

function Service:MakePrompts(arena)
	for side, pad in arena.Pads do
		local anchor = pad:FindFirstChild("QueuePromptAnchor") or Instance.new("Attachment")
		anchor.Name, anchor.Parent = "QueuePromptAnchor", pad
		anchor.WorldPosition = pad.Position + Vector3.yAxis * 3
		local prompt = anchor:FindFirstChild("QueuePrompt") or Instance.new("ProximityPrompt")
		prompt.Name, prompt.ActionText, prompt.ObjectText = "QueuePrompt", "Join Battle", self:Title(arena)
		prompt.HoldDuration, prompt.RequiresLineOfSight = 0, false
		prompt.MaxActivationDistance = Balance.Match.QueuePromptDistance
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt:SetAttribute("ArenaId", arena.Id)
		prompt:SetAttribute("Side", side)
		prompt.Parent = anchor
		arena.Prompts[side] = prompt
		prompt.Triggered:Connect(function(player)
			if self.Guard:Allow(player, "Prompt", Balance.Match.QueuePromptRateSeconds) then
				self:Queue(player, arena, side, workspace:GetServerTimeNow())
			end
		end)
	end
end

function Service:Unlock(player)
	local lock = self.Locks[player]
	self.Locks[player] = nil
	if lock then
		if lock.Died then
			lock.Died:Disconnect()
		end
		Stage.unlock(lock.Saved)
	end
end

-- reason: "Left" (button), "Reset" (character died/removed) or nil (player leaving the game).
function Service:Leave(player, reason)
	local entry = self.ByPlayer[player]
	if not entry then
		return
	end
	entry.Arena.Queue[entry.Side] = nil
	if entry.Arena.FirstMatch == player then
		entry.Arena.FirstMatch = nil
	end
	self.ByPlayer[player] = nil
	self:Unlock(player)
	self:PadState(entry.Arena)
	if player.Parent == Players then
		Remotes.MatchState:FireClient(player, { Phase = "QueueLeft", ArenaId = entry.Arena.Id, Reason = reason })
	end
end

function Service:Queue(player, arena, side, now)
	if arena.Busy or arena.Queue[side] or self.ByPlayer[player] or self.Services.MatchService.ByPlayer[player] then
		return false
	end
	local holder = self:Holder(arena)
	if holder and holder ~= player then
		Remotes.MatchState:FireClient(
			player,
			{ Phase = "Notice", Text = "This arena is saved for a new player. Try another!" }
		)
		return false
	end
	if self.Locks[player] or not self.Services.MatchService:IsReady(player) then
		return false
	end
	local character = player.Character
	local saved = Stage.lock(arena, side, character)
	if not saved then
		return false
	end
	self.Locks[player] = {
		Saved = saved,
		-- A reset frees the spot at once; in a live match MatchService turns it into a forfeit.
		Died = saved.Humanoid.Died:Once(function()
			if self.ByPlayer[player] then
				self:Leave(player, "Reset")
			end
		end),
	}
	arena.Queue[side] = player
	arena.QueuedAt = arena.QueuedAt or now
	self.ByPlayer[player] = { Arena = arena, Side = side }
	if holder == player then
		-- The new player's reserved arena: the bot is already waiting.
		self.Reserved[player] = nil
		arena.QueuedAt = now - Balance.Match.QueueBotAfterSeconds
		arena.FirstMatch = player
	end
	self:PadState(arena)
	self:QueueBoard(arena, now)
	Remotes.MatchState:FireClient(player, {
		Phase = "Queue",
		ArenaId = arena.Id,
		Side = side,
		Deadline = if self:BotsAllowed(arena) then arena.QueuedAt + Balance.Match.QueueBotAfterSeconds else nil,
		Locked = true,
		CanLeave = true,
		Spot = character:GetPivot(),
		Center = Stage.center(arena),
	})
	return true
end

function Service:StartArena(arena, now)
	local players = { [1] = arena.Queue[1], [2] = arena.Queue[2] }
	arena.FirstMatch = nil
	for _, player in players do
		self.ByPlayer[player] = nil -- the lock stays on until Release
	end
	arena.Queue, arena.QueuedAt, arena.Busy = {}, nil, true
	self:PadState(arena)
	self.Services.MatchService:StartMatch(arena, players, now)
end

function Service:Release(arena, players)
	arena.Busy, arena.Queue, arena.QueuedAt = false, {}, nil
	for side, player in players do
		self:Unlock(player)
		if player.Parent == Players then
			self.Recent[player] = { Arena = arena, Side = side }
			Remotes.MatchState:FireClient(player, { Phase = "QueueLeft", ArenaId = arena.Id, Reason = "MatchOver" })
		end
	end
	self:QueueBoard(arena, workspace:GetServerTimeNow())
	self:PadState(arena)
end

-- LeaveQueue: leave the queue, or forfeit the live match (same as a reset).
function Service:LeaveBattle(player)
	if self.ByPlayer[player] then
		self:Leave(player, "Left")
	elseif self.Services.MatchService.ByPlayer[player] then
		self.Services.MatchService:Forfeit(player)
	end
end

function Service:Replay(player)
	if self.Services.MatchService.ByPlayer[player] or self.ByPlayer[player] then
		return
	end
	local recent = self.Recent[player]
	if not recent or recent.Arena.Busy then
		Remotes.MatchState:FireClient(player, { Phase = "Notice", Text = "That arena is busy. Try a free pad." })
		return
	end
	local arena, side = recent.Arena, recent.Side
	if arena.Queue[side] then
		side = 3 - side
	end
	if arena.Queue[side] then
		Remotes.MatchState:FireClient(player, { Phase = "Notice", Text = "That arena just filled up. Try a free pad." })
		return
	end
	self:Queue(player, arena, side, workspace:GetServerTimeNow())
end

function Service:Step(now)
	for player in self.ByPlayer do
		local lock = self.Locks[player]
		if
			not lock
			or not player.Parent
			or player.Character ~= lock.Saved.Character
			or lock.Saved.Humanoid.Health <= 0
		then
			self:Leave(player, "Reset")
		end
	end
	for player in self.Locks do
		-- Locks outlive the queue only while a match holds the player.
		if not self.ByPlayer[player] and not self.Services.MatchService.ByPlayer[player] then
			self:Unlock(player)
		end
	end
	for _, arena in self.Arenas do
		self:PadState(arena)
		if arena.Busy then
			continue
		end
		local a, b = arena.Queue[1], arena.Queue[2]
		if not a and not b then
			arena.QueuedAt = nil
		elseif
			a and b
			or arena.FirstMatch
			or (now - arena.QueuedAt >= Balance.Match.QueueBotAfterSeconds and self:BotsAllowed(arena))
		then
			self:StartArena(arena, now)
			continue
		end
		self:QueueBoard(arena, now)
	end
end

-- PLAY uses the same authoritative queue path as the pad prompts.
function Service:JoinNearest(player)
	if self.ByPlayer[player] or self.Services.MatchService.ByPlayer[player] then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local best, nearestSide, distance = nil, nil, math.huge
	-- A new player's PLAY goes to their reserved arena.
	local reserved = self:ReservedFor(player)
	for _, arena in if reserved then { reserved } else self.Arenas do
		if not arena.Busy and (reserved or not self:Holder(arena)) then
			for side, pad in arena.Pads do
				if not arena.Queue[side] then
					local d = (pad.Position - root.Position).Magnitude
					if d < distance then
						best, nearestSide, distance = arena, side, d
					end
				end
			end
		end
	end
	if not best then
		Remotes.MatchState:FireClient(player, { Phase = "Notice", Text = "All arenas are busy. Try again soon!" })
		return
	end
	self:Queue(player, best, nearestSide, workspace:GetServerTimeNow())
end

function Service:Start()
	for _, arena in self.Arenas do
		arena.Board = Board.build(arena)
		self:MakePrompts(arena)
		self:QueueBoard(arena, workspace:GetServerTimeNow())
		self:PadState(arena)
	end
	Remotes.JoinNearestArena.OnServerEvent:Connect(function(player, ...)
		if not self.Guard:Allow(player, "JoinNearest", Balance.Match.RequestRateSeconds) then
			return
		end
		if select("#", ...) ~= 0 then
			return
		end
		self:JoinNearest(player)
	end)
	Remotes.LeaveQueue.OnServerEvent:Connect(function(player, ...)
		if select("#", ...) ~= 0 or not self.Guard:Allow(player, "Leave", Balance.Match.LeaveRateSeconds) then
			return
		end
		self:LeaveBattle(player)
	end)
	Remotes.RequestRematch.OnServerEvent:Connect(function(player)
		if self.Guard:Allow(player, "Replay", Balance.Match.RequestRateSeconds) then
			self:Replay(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:Leave(player, nil)
		self:Unlock(player)
		self.Recent[player] = nil
		self.Guard:Remove(player)
	end)
	RunService.Heartbeat:Connect(function(dt)
		self.Accumulator += dt
		if self.Accumulator >= Balance.Match.QueueCheckSeconds then
			self.Accumulator = 0
			self:Step(workspace:GetServerTimeNow())
		end
	end)
end

return Service
