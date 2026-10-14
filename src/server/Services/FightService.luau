local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Balance = require(RS.Shared.Config.Balance)
local Glassies = require(RS.Shared.Config.Glassies)
local Rules = require(RS.Shared.FightRules)
local Rng = require(RS.Shared.Rng)
local Remotes = require(RS.Shared.Remotes)
local Pendulum = require(script.Parent.Parent.Simulation.Pendulum)
local Calibration = require(script.Parent.Parent.Simulation.Calibration)
local Service = {}
local M = Balance.Motion

local function finite(n)
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end

function Service:Init()
	self.Serial, self.LastAim = 0, {}
	self.Stand = workspace:WaitForChild("Lobby"):WaitForChild("Arenas"):WaitForChild("Arena1")
	local bar = self.Stand:WaitForChild("Crossbar")
	self.Hooks = { bar:WaitForChild("HookA"), bar:WaitForChild("HookB") }
	assert(self.Hooks[1] and self.Hooks[2], "Arena1 needs HookA/HookB")
	local a, b = self.Hooks[1].WorldPosition, self.Hooks[2].WorldPosition
	local x = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
	self.Frame = CFrame.fromMatrix((a + b) / 2, x, Vector3.yAxis, x:Cross(Vector3.yAxis))
	self.Gap = (b - a).Magnitude
end

function Service:Metadata()
	local s = self.Session
	local b = if s.Phase == "Aiming" then { Id = s.B.Id } else s.B
	return {
		Id = s.Id,
		Phase = s.Phase,
		UserId = s.Player and s.Player.UserId or 0,
		Spectate = s.Spectate,
		A = s.A,
		B = b,
		Frame = self.Frame,
		Hooks = self.Hooks,
		SweetSpot = s.SweetSpot,
		Deadline = s.Deadline,
		ReleaseAt = s.ReleaseAt,
		Snapshot = s.Sim and Pendulum.snapshot(s.Sim),
	}
end

function Service:Broadcast()
	Remotes.MatchState:FireAllClients(self:Metadata())
end

function Service:Create(player, a, b, seed, spectate)
	if self.Session then
		return false, "busy"
	end
	assert(Glassies.ById[a] and Glassies.ById[b], "Unknown glassy id")
	local rng = Rng.new(seed)
	local sweet = Rules.rollSweetSpot(rng)
	self.Serial += 1
	self.Session = {
		Id = self.Serial,
		Player = player,
		Rng = rng,
		Seed = seed,
		Spectate = spectate == true,
		A = { Id = a, Aim = M.AimDefault, AimYaw = 0 },
		B = {
			Id = b,
			Aim = Rules.botAim(
				sweet,
				Balance.Match.BotSkillMin + rng() * (Balance.Match.BotSkillMax - Balance.Match.BotSkillMin),
				rng
			),
			AimYaw = (rng() * 2 - 1) * M.AimYawMax,
		},
		SweetSpot = sweet,
		Phase = "Aiming",
		Deadline = workspace:GetServerTimeNow() + Balance.Match.AimSeconds,
		Accumulator = 0,
		SnapshotAccumulator = 0,
	}
	self.Prompt.Enabled = false
	if not player then
		self.Session.A.Aim = Rules.botAim(sweet, 0.45, rng)
		self.Session.A.AimYaw = (rng() * 2 - 1) * M.AimYawMax
		self:Countdown()
	else
		self:Broadcast()
	end
	return true, self.Serial
end

function Service:Countdown()
	local s = self.Session
	if not s or s.Phase ~= "Aiming" then
		return
	end
	s.Phase = "Countdown"
	s.ReleaseAt = workspace:GetServerTimeNow() + Balance.Match.CountdownSeconds
	s.Deadline = s.ReleaseAt
	s.Sim = Pendulum.new({ A = s.A, B = s.B, Rng = s.Rng, SweetSpot = s.SweetSpot }, s.Seed, self.Gap)
	self:Broadcast()
end

function Service:Cancel()
	local s = self.Session
	if not s then
		return
	end
	Remotes.MatchState:FireAllClients({ Id = s.Id, Phase = "Idle" })
	self.Session = nil
	self.Prompt.Enabled = true
end

-- Studio-only helpers; never exposed through a client remote.
function Service:BotVsBot(a, b, seed, spectate)
	assert(RunService:IsStudio(), "Dev helper is Studio-only")
	if not self.Serial then
		return game.ServerStorage:WaitForChild("FightDev"):Invoke("BotVsBot", a, b, seed, spectate)
	end
	return self:Create(nil, a, b, seed, spectate)
end
function Service:Calibrate(count, seed)
	assert(RunService:IsStudio(), "Dev helper is Studio-only")
	return Calibration.run(count, seed)
end

function Service:Step(dt)
	local s = self.Session
	if not s then
		return
	end
	local now = workspace:GetServerTimeNow()
	if s.Phase == "Aiming" then
		if now >= s.Deadline then
			self:Countdown()
		end
		return
	elseif s.Phase == "Countdown" then
		if now < s.ReleaseAt then
			return
		end
		s.Phase = "Fighting"
		self:Broadcast()
	elseif s.Phase == "RoundEnd" then
		if now >= s.Deadline then
			self:Cancel()
		end
		return
	end
	s.Accumulator += math.min(dt, M.MaxCatchupSeconds)
	local fixed = 1 / M.StepRate
	while s.Accumulator >= fixed and not s.Sim.Fight.Over do
		s.Accumulator -= fixed
		Pendulum.step(s.Sim, fixed)
		local events = Pendulum.events(s.Sim)
		if #events > 0 then
			Remotes.FightEvents:FireAllClients({
				Id = s.Id,
				Events = events,
				Snapshot = Pendulum.snapshot(s.Sim),
				SentAt = now,
			})
		end
	end
	s.SnapshotAccumulator += dt
	if s.SnapshotAccumulator >= 1 / Balance.Feel.SnapshotRate or s.Sim.Fight.Over then
		s.SnapshotAccumulator %= 1 / Balance.Feel.SnapshotRate
		local snapshot = Pendulum.snapshot(s.Sim)
		snapshot.Id, snapshot.SentAt = s.Id, now
		Remotes.FightSnapshot:FireAllClients(snapshot)
	end
	if s.Sim.Fight.Over then
		s.Phase, s.Deadline = "RoundEnd", now + Balance.Match.RoundEndSeconds
		self.LastResult = { Seed = s.Seed, Fight = s.Sim.Fight, Metrics = s.Sim.Metrics }
	end
end

function Service:Start()
	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "FightDev"
		dev.OnInvoke = function(command, ...)
			if command == "Watch" then
				if self.Watching then
					return false, "already watching"
				end
				self.Watching, self.WatchReport = true, {}
				task.spawn(function()
					local pairs = {
						{ "pop", "prism" },
						{ "jam", "jam" },
						{ "hot_sauce", "glass_cup" },
						{ "lemonade_bottle", "milk_bottle" },
						{ "crystal_crown", "message_bottle" },
					}
					for i = 1, 10 do
						while self.Session do
							task.wait(0.25)
						end
						local pair = pairs[(i - 1) % #pairs + 1]
						self:BotVsBot(pair[1], pair[2], 400 + i, true)
						while self.Session do
							task.wait(0.25)
						end
						local result = self.LastResult
						table.insert(
							self.WatchReport,
							{
								Seed = result.Seed,
								Time = result.Fight.Time,
								Hits = result.Fight.Hits,
								Reason = result.Fight.Reason,
							}
						)
					end
					self.Watching = false
				end)
				return true
			end
			if command == "WatchReport" then
				return { Running = self.Watching, Rounds = self.WatchReport }
			end
			if command == "BotVsBot" then
				return self:BotVsBot(...)
			end
			if command == "Calibrate" then
				return self:Calibrate(...)
			end
			if command == "StartPlayer" then
				local player, a, b, seed = ...
				return self:Create(player, a, b, seed, false)
			end
			if command == "Inspect" then
				return self.Session
						and {
							Phase = self.Session.Phase,
							Time = self.Session.Sim and self.Session.Sim.Fight.Time,
							Seed = self.Session.Seed,
						}
					or self.LastResult
			end
			if command == "Cancel" then
				self:Cancel()
				return true
			end
		end
		dev.Parent = game.ServerStorage
	end
	local host = self.Hooks[1].Parent
	local anchor = host:FindFirstChild("FightPromptAnchor") or Instance.new("Attachment")
	anchor.Name = "FightPromptAnchor"
	anchor.WorldPosition = self.Frame.Position - Vector3.yAxis * (M.StringLength + M.BodyCenter * M.GlassyScale)
	anchor.Parent = host
	-- WorldPosition must be assigned after parenting.
	anchor.WorldPosition = self.Frame.Position - Vector3.yAxis * (M.StringLength + M.BodyCenter * M.GlassyScale)
	self.Prompt = anchor:FindFirstChild("FightBotPrompt") or Instance.new("ProximityPrompt")
	self.Prompt.Name, self.Prompt.ActionText, self.Prompt.ObjectText =
		"FightBotPrompt", "Fight a bot", "Arena 1 • Glass Clash"
	self.Prompt.MaxActivationDistance, self.Prompt.RequiresLineOfSight, self.Prompt.HoldDuration =
		Balance.Feel.PromptDistance, false, 0
	self.Prompt.Parent = anchor
	self.Prompt.Triggered:Connect(function(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or (root.Position - anchor.WorldPosition).Magnitude > Balance.Feel.PromptDistance then
			return
		end
		local seed = Random.new():NextInteger(1, 100000000)
		local starter = Glassies.Starters[Random.new():NextInteger(1, #Glassies.Starters)]
		self:Create(player, Balance.Feel.PrototypePlayerId, starter, seed, false)
	end)
	Remotes.SetAim.OnServerEvent:Connect(function(player, aim, yaw)
		local now = os.clock()
		if now - (self.LastAim[player] or -math.huge) < Balance.Match.AimRateSeconds then
			return
		end
		self.LastAim[player] = now
		local s = self.Session
		if not s or s.Player ~= player or s.Phase ~= "Aiming" or not finite(aim) or not finite(yaw) then
			return
		end
		s.A.Aim, s.A.AimYaw = Rules.clampAim(aim), Rules.clampYaw(yaw)
		self:Countdown()
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.LastAim[player] = nil
		if self.Session and self.Session.Player == player then
			self:Cancel()
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.delay(3, function()
			if self.Session and player.Parent then
				Remotes.MatchState:FireClient(player, self:Metadata())
			end
		end)
	end)
	RunService.Heartbeat:Connect(function(dt)
		self:Step(dt)
	end)
end

return Service
