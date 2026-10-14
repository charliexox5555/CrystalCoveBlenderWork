local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Balance = require(RS.Shared.Config.Balance)
local Remotes = require(RS.Shared.Remotes)
local Guard = require(script.Parent.Parent.Util.RemoteGuard)
local Theme = require(game.StarterPlayer.StarterPlayerScripts.Client.UI.Theme)
local Service = {}

function Service:Init(services)
	self.Services, self.Arenas, self.ByPlayer, self.RequireExit, self.Recent = services, {}, {}, {}, {}
	self.Guard, self.Accumulator = Guard.new(), 0
	for _, stand in CollectionService:GetTagged("ArenaStand") do
		local id = stand:GetAttribute("ArenaId")
		if type(id) == "number" then
			self.Arenas[id] = { Id = id, Stand = stand, Pads = {}, Queue = {} }
		end
	end
	for _, pad in CollectionService:GetTagged("QueuePad") do
		local arena = self.Arenas[pad:GetAttribute("ArenaId")]
		local side = if pad:GetAttribute("Side") == "A" then 1 else 2
		if arena then
			arena.Pads[side] = pad
		end
	end
	for _, arena in self.Arenas do
		assert(arena.Pads[1] and arena.Pads[2], "Arena missing queue pads")
	end
end

function Service:OnPad(player, pad)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local delta = root.Position - pad.Position
	local radius = math.max(pad.Size.X, pad.Size.Y, pad.Size.Z) / 2 + Balance.Match.QueueMargin
	return Vector3.new(delta.X, 0, delta.Z).Magnitude <= radius and math.abs(delta.Y) <= Balance.Match.QueueHeight
end

function Service:Label(arena, text)
	if arena.LabelGui then
		local active = not text:find("Step on a pad", 1, true)
		arena.LabelGui.Enabled = active
		arena.LabelGui:SetAttribute("ArenaActive", active)
	end
	if arena.Label and arena.Label.Text ~= text then
		arena.Label.Text = text
	end
end

function Service:MakeLabel(arena)
	local bar = arena.Stand:FindFirstChild("Crossbar")
	local attachment = bar:FindFirstChild("ArenaLabelAnchor") or Instance.new("Attachment")
	attachment.Name, attachment.Parent = "ArenaLabelAnchor", bar
	attachment.Position = Vector3.yAxis * Balance.Feel.ArenaLabelHeight
	local gui = attachment:FindFirstChild("ArenaStatus") or Instance.new("BillboardGui")
	gui.Name, gui.Size, gui.MaxDistance, gui.AlwaysOnTop =
		"ArenaStatus", UDim2.fromOffset(260, 68), Balance.Feel.SpectatorDistance, false
	gui.Parent = attachment
	arena.LabelGui = gui
	local label = gui:FindFirstChild("Text") or Instance.new("TextLabel")
	label.Name, label.Size, label.BackgroundColor3, label.BackgroundTransparency =
		"Text", UDim2.fromScale(1, 1), Theme.Battle.PanelTop, Theme.Battle.PanelTransparency
	label.TextColor3, label.FontFace, label.TextScaled, label.BorderSizePixel =
		Theme.Colors.Text, Theme.Fonts.Body, true, 0
	label.Parent = gui
	if not label:FindFirstChildOfClass("UICorner") then
		local c = Instance.new("UICorner")
		c.CornerRadius = Theme.Radius.Tag
		c.Parent = label
	end
	arena.Label = label
	self:Label(arena, "ARENA " .. arena.Id .. "\nStep on a pad")
end

function Service:Leave(player, requireExit)
	local entry = self.ByPlayer[player]
	if not entry then
		return
	end
	entry.Arena.Queue[entry.Side] = nil
	self.ByPlayer[player] = nil
	if requireExit then
		self.RequireExit[player] = entry.Arena.Pads[entry.Side]
	end
	if player.Parent == Players then
		Remotes.MatchState:FireClient(player, { Phase = "QueueLeft", ArenaId = entry.Arena.Id })
	end
end

function Service:Queue(player, arena, side, now)
	if arena.Busy or arena.Queue[side] or self.ByPlayer[player] or self.Services.MatchService.ByPlayer[player] then
		return false
	end
	if not self.Services.MatchService:IsReady(player) then
		return false
	end
	arena.Queue[side] = player
	arena.QueuedAt = arena.QueuedAt or now
	self.ByPlayer[player] = { Arena = arena, Side = side }
	Remotes.MatchState:FireClient(
		player,
		{ Phase = "Queue", ArenaId = arena.Id, Deadline = arena.QueuedAt + Balance.Match.QueueBotAfterSeconds }
	)
	return true
end

function Service:StartArena(arena, now)
	local players = { [1] = arena.Queue[1], [2] = arena.Queue[2] }
	for _, player in players do
		self.ByPlayer[player] = nil
	end
	arena.Queue, arena.QueuedAt, arena.Busy = {}, nil, true
	self.Services.MatchService:StartMatch(arena, players, now)
end

function Service:Release(arena, players)
	arena.Busy, arena.Queue, arena.QueuedAt = false, {}, nil
	for side, player in players do
		if player and player.Parent then
			self.RequireExit[player] = arena.Pads[side]
			self.Recent[player] = { Arena = arena, Side = side }
		end
	end
	self:Label(arena, "ARENA " .. arena.Id .. "\nStep on a pad")
end

function Service:Replay(player)
	if self.Services.MatchService.ByPlayer[player] or self.ByPlayer[player] then
		return
	end
	local recent = self.Recent[player]
	if not recent or recent.Arena.Busy then
		Remotes.MatchState:FireClient(player, { Phase = "Notice", Text = "That arena is busy. Step on a free pad." })
		return
	end
	local arena, side = recent.Arena, recent.Side
	if arena.Queue[side] then
		side = 3 - side
	end
	if arena.Queue[side] then
		return
	end
	self:Leave(player, false)
	self.RequireExit[player] = nil
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(arena.Pads[side].Position + Vector3.yAxis * Balance.Lobby.RescueHeight))
	end
	self:Queue(player, arena, side, workspace:GetServerTimeNow())
end

function Service:Step(now)
	for player, pad in self.RequireExit do
		if not player.Parent or not self:OnPad(player, pad) then
			self.RequireExit[player] = nil
		end
	end
	for player, entry in self.ByPlayer do
		if not player.Parent or not self:OnPad(player, entry.Arena.Pads[entry.Side]) then
			self:Leave(player, false)
		end
	end
	for _, arena in self.Arenas do
		if arena.Busy then
			continue
		end
		for side, pad in arena.Pads do
			if arena.Queue[side] then
				continue
			end
			for _, player in Players:GetPlayers() do
				if not self.RequireExit[player] and self:OnPad(player, pad) then
					self:Queue(player, arena, side, now)
				end
			end
		end
		local a, b = arena.Queue[1], arena.Queue[2]
		if not a and not b then
			arena.QueuedAt = nil
			self:Label(arena, "ARENA " .. arena.Id .. "\nStep on a pad")
		elseif a and b or now - arena.QueuedAt >= Balance.Match.QueueBotAfterSeconds then
			self:StartArena(arena, now)
		else
			self:Label(
				arena,
				"ARENA "
					.. arena.Id
					.. "\nBot joins in "
					.. math.max(0, math.ceil(arena.QueuedAt + Balance.Match.QueueBotAfterSeconds - now))
					.. "s"
			)
		end
	end
end

function Service:Start()
	for _, arena in self.Arenas do
		self:MakeLabel(arena)
	end
	Remotes.LeaveQueue.OnServerEvent:Connect(function(player)
		if self.Guard:Allow(player, "Leave", Balance.Match.LeaveRateSeconds) then
			self:Leave(player, true)
		end
	end)
	Remotes.RequestRematch.OnServerEvent:Connect(function(player)
		if self.Guard:Allow(player, "Replay", Balance.Match.RequestRateSeconds) then
			self:Replay(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:Leave(player, false)
		self.RequireExit[player], self.Recent[player] = nil, nil
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
