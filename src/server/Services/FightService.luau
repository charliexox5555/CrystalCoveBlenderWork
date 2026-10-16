local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Balance = require(RS.Shared.Config.Balance)
local Rules = require(RS.Shared.FightRules)
local Rng = require(RS.Shared.Rng)
local Remotes = require(RS.Shared.Remotes)
local Codec = require(RS.Shared.SnapshotCodec)
local Pendulum = require(script.Parent.Parent.Simulation.Pendulum)
local Calibration = require(script.Parent.Parent.Simulation.Calibration)
local Guard = require(script.Parent.Parent.Util.RemoteGuard)
local Stage = require(script.Parent.Parent.Util.MatchStage)
local Service = {}
local M, Feel = Balance.Motion, Balance.Feel

function Service:Init(services)
	self.Services, self.Sessions, self.Serial, self.KeySerial = services, {}, 0, 0
	self.Guard = Guard.new()
end

function Service:Sync(player)
	for _, session in self.Sessions do
		local data = table.clone(session.Data)
		local entry = self.Services.MatchService and self.Services.MatchService.Matches[data.ArenaId]
		if entry then
			local meta = self.Services.MatchService:Meta(entry)
			data.Phase, data.Hearts, data.Round = meta.Phase, meta.Hearts, meta.Round
		end
		data.JoinedLate = true
		local fight = session.Sim.Fight
		data.DeadSides = {
			fight.Fighters[1].Hp <= 0 or (fight.Over and fight.Winner == 2),
			fight.Fighters[2].Hp <= 0 or (fight.Over and fight.Winner == 1),
		}
		data.Snapshot = Pendulum.snapshot(session.Sim)
		data.SignatureState = Pendulum.presentation(session.Sim)
		Remotes.MatchState:FireClient(player, data)
	end
end

function Service:Geometry(arena)
	local bar = arena.Stand:WaitForChild("Crossbar")
	local hooks = { bar:WaitForChild("HookA"), bar:WaitForChild("HookB") }
	-- Queue A/B were authored opposite the hook names on the rotated stands.
	if
		(hooks[2].WorldPosition - arena.Pads[1].Position).Magnitude
		< (hooks[1].WorldPosition - arena.Pads[1].Position).Magnitude
	then
		hooks[1], hooks[2] = hooks[2], hooks[1]
	end
	local a, b = hooks[1].WorldPosition, hooks[2].WorldPosition
	local x = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
	return CFrame.fromMatrix((a + b) / 2, x, Vector3.yAxis, x:Cross(Vector3.yAxis)), (b - a).Magnitude, hooks
end

function Service:Describe(arena, setup, metadata)
	local frame, _, hooks = self:Geometry(arena)
	local out = table.clone(metadata)
	out.A, out.B, out.Frame = setup.A, setup.B, frame
	out.HookPositions = { hooks[1].WorldPosition, hooks[2].WorldPosition }
	out.HeartPositions = { arena.Pads[1].Position, arena.Pads[2].Position }
	out.AvatarPositions = Stage.positions(arena)
	local inward = workspace.Lobby.SpawnLocation.Position - frame.Position
	out.CameraFacing = if inward:Dot(frame.ZVector) >= 0 then 1 else -1
	out.SweetSpot, out.ArenaId = setup.SweetSpot, arena.Id
	return out
end

function Service:Interested(session, player)
	if session.Data.Spectate or table.find(session.Data.PlayerIds or {}, player.UserId) then
		return true
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root and (root.Position - session.Data.Frame.Position).Magnitude < Feel.SpectatorDistance
end

function Service:Send(session, remote, packet)
	for _, player in Players:GetPlayers() do
		if self:Interested(session, player) then
			remote:FireClient(player, packet)
		end
	end
end

function Service:StartFight(id, arena, setup, seed, metadata, onEnd)
	assert(not self.Sessions[id], "Duplicate fight id")
	local data = self:Describe(arena, setup, metadata)
	-- Small numeric key so 20 Hz binary snapshots don't repeat the long fight id string.
	self.KeySerial = self.KeySerial % 65535 + 1
	data.Id, data.Key = id, self.KeySerial
	local _, gap = self:Geometry(arena)
	local session = {
		Id = id,
		Data = data,
		Sim = Pendulum.new(setup, seed, gap),
		OnEnd = onEnd,
		Accumulator = 0,
		SnapshotAccumulator = 0,
		ReleaseAt = metadata.ReleaseAt or workspace:GetServerTimeNow(),
	}
	session.Data.Phase = if session.ReleaseAt > workspace:GetServerTimeNow() then "Countdown" else "Fighting"
	session.Data.Snapshot = Pendulum.snapshot(session.Sim)
	self.Sessions[id], self.RecentId = session, id
	Remotes.MatchState:FireAllClients(session.Data)
	return session
end

function Service:Stop(id)
	-- Aiming/countdown views exist before a simulation session. Close those too on cancellation.
	Remotes.MatchState:FireAllClients({ Id = id, Phase = "Idle" })
	self.Sessions[id] = nil
end

function Service:Step(session, dt, now)
	if session.Sim.Fight.Over or now < session.ReleaseAt then
		return
	end
	if session.Data.Phase == "Countdown" then
		session.Data.Phase = "Fighting"
		Remotes.MatchState:FireAllClients(session.Data)
	end
	session.Accumulator += math.min(dt, M.MaxCatchupSeconds)
	local fixed = 1 / M.StepRate
	while session.Accumulator >= fixed and not session.Sim.Fight.Over do
		session.Accumulator -= fixed
		Pendulum.step(session.Sim, fixed)
		local events = Pendulum.events(session.Sim)
		if #events > 0 then
			self:Send(
				session,
				Remotes.FightEvents,
				{ Id = session.Id, Events = events, Snapshot = Pendulum.snapshot(session.Sim), SentAt = now }
			)
		end
	end
	session.SnapshotAccumulator += dt
	if session.SnapshotAccumulator >= 1 / Feel.SnapshotRate or session.Sim.Fight.Over then
		session.SnapshotAccumulator %= 1 / Feel.SnapshotRate
		self:Send(session, Remotes.FightSnapshot, Codec.encode(session.Data.Key, Pendulum.snapshot(session.Sim), now))
	end
	if session.Sim.Fight.Over then
		self.LastResult = { Seed = session.Sim.Seed, Fight = session.Sim.Fight, Metrics = session.Sim.Metrics }
		session.OnEnd(session.Sim.Fight, session.Sim.Metrics)
	end
end

function Service:BotVsBot(a, b, seed, spectate, prototype)
	assert(RunService:IsStudio(), "Dev helper is Studio-only")
	if not self.Sessions then
		return game.ServerStorage.FightDev:Invoke("BotVsBot", a, b, seed, spectate, prototype)
	end
	local arena = self.Services.ArenaService.Arenas[1]
	if arena.Busy then
		return false, "arena busy"
	end
	for id in self.Sessions do
		if id:sub(1, 4) == "dev-" then
			return false, "dev fight busy"
		end
	end
	local rng = Rng.new(seed)
	local sweet = Rules.rollSweetSpot(rng)
	local setup = {
		ReleaseKits = if prototype then true else nil,
		A = { Id = a, Aim = Rules.botAim(sweet, 0.45, rng), AimYaw = (rng() * 2 - 1) * M.AimYawMax },
		B = { Id = b, Aim = Rules.botAim(sweet, 0.45, rng), AimYaw = (rng() * 2 - 1) * M.AimYawMax },
		Rng = rng,
		SweetSpot = sweet,
	}
	self.Serial += 1
	local id = "dev-" .. self.Serial
	self:StartFight(id, arena, setup, seed, {
		ReleasePrototype = prototype == true,
		PlayerIds = { 0, 0 },
		Spectate = spectate,
		Hearts = { 3, 3 },
		ReleaseAt = workspace:GetServerTimeNow() + Balance.Match.CountdownSeconds,
	}, function(fight, metrics)
		self.LastResult = { Seed = seed, Fight = fight, Metrics = metrics }
		task.delay(Balance.Match.RoundEndSeconds, function()
			self:Stop(id)
		end)
	end)
	return true, id
end

function Service:Start()
	Remotes.RequestFightState.OnServerEvent:Connect(function(player)
		if self.Guard:Allow(player, "Sync", Balance.Data.RequestRateSeconds) then
			self:Sync(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.Guard:Remove(player)
	end)
	RunService.Heartbeat:Connect(function(dt)
		local now = workspace:GetServerTimeNow()
		for _, session in self.Sessions do
			self:Step(session, dt, now)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.delay(3, function()
			if not player.Parent then
				return
			end
			self:Sync(player)
		end)
	end)
	if not RunService:IsStudio() then
		return
	end
	local dev = Instance.new("BindableFunction")
	dev.Name = "FightDev"
	dev.OnInvoke = function(command, ...)
		if command == "Calibrate" then
			return Calibration.run(...)
		end
		if command == "BotVsBot" then
			return self:BotVsBot(...)
		end
		if command == "Inspect" then
			local s = self.Sessions[self.RecentId]
			return s and { Id = s.Id, Time = s.Sim.Fight.Time, Phase = s.Data.Phase } or self.LastResult
		end
		if command == "Cancel" then
			for id in self.Sessions do
				if id:sub(1, 4) == "dev-" then
					self:Stop(id)
				end
			end
			return true
		end
		if command == "WatchReport" then
			return { Running = self.Watching, Rounds = self.WatchReport }
		end
		if command == "Watch" then
			if self.Watching then
				return false
			end
			self.Watching, self.WatchReport = true, {}
			task.spawn(function()
				local pairs = {
					{ "pop", "prism" },
					{ "jam", "pickle_jar" },
					{ "hot_sauce", "glass_cup" },
					{ "potion_flask", "perfume" },
					{ "crystal_crown", "message_bottle" },
				}
				for i = 1, 10 do
					local pair = pairs[(i - 1) % #pairs + 1]
					local ok, id = self:BotVsBot(pair[1], pair[2], 400 + i, true)
					if not ok then
						break
					end
					while self.Sessions[id] do
						task.wait(0.25)
					end
					local r = self.LastResult
					table.insert(
						self.WatchReport,
						{ Seed = r.Seed, Time = r.Fight.Time, Hits = r.Fight.Hits, Reason = r.Fight.Reason }
					)
				end
				self.Watching = false
			end)
			return true
		end
	end
	dev.Parent = game.ServerStorage
end
return Service
