-- Server owns timing, random rolls and every mutation of battle HP.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Shared = RS:WaitForChild("Shared")
local Formula = require(Shared.Formula)
local Logic = require(Shared.BattleLogic)
local Glassies = require(Shared.Config.Glassies)
local Balance = require(Shared.Config.Balance)
local Remotes = require(Shared.Remotes)
local BattleService = { Active = {}, ReleaseTimes = {}, PromptTimes = {} }

local function now()
	return workspace:GetServerTimeNow()
end
local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function waitUntil(time, state)
	while not state.Cancelled and now() < time do
		task.wait(math.min(Balance.Battle.PollSeconds, time - now()))
	end
end

function BattleService:Init()
	self.Stand = workspace:WaitForChild("ClashStand")
end

function BattleService:AcceptRelease(player, battleId, clashIndex, elapsed)
	local time = now()
	if time - (self.ReleaseTimes[player] or -math.huge) < Balance.Battle.ReleaseRateSeconds then
		return false
	end
	self.ReleaseTimes[player] = time
	if type(battleId) ~= "string" or #battleId > 64 or not finite(clashIndex) or not finite(elapsed) then
		return false
	end
	if clashIndex % 1 ~= 0 or elapsed < 0 or elapsed > Balance.Meter.MaxHoldTime then
		return false
	end
	local state = self.Active[player]
	if not state or state.Id ~= battleId or state.Index ~= clashIndex or state.Phase ~= "Meter" or state.Released then
		return false
	end
	local serverElapsed = time - state.StartTime
	if serverElapsed < 0 then
		return false
	end
	local judged = Formula.validateRelease(elapsed, serverElapsed)
	if not judged then
		return false
	end
	state.Released = true
	state.Zone = Formula.zoneFromRelease(judged, state.A.Swing)
	state.JudgedElapsed = judged
	return true
end

function BattleService:Finish(player, state, winner, reason)
	if self.Active[player] ~= state then
		return
	end
	state.Cancelled = true
	self.Active[player] = nil
	player:SetAttribute("M1BattleId", nil)
	if player.Parent == Players then
		Remotes.BattleEnded:FireClient(
			player,
			{ BattleId = state.Id, Winner = winner, Reason = reason, A = state.A, B = state.B }
		)
	end
end

function BattleService:RunBattle(player, state)
	local rng = Random.new()
	local roll = function()
		return rng:NextNumber()
	end
	local npc = Logic.npcChooser(Balance.Prototype.NpcSkill, roll)
	Remotes.BattleStarted:FireClient(
		player,
		{ BattleId = state.Id, A = table.clone(state.A), B = table.clone(state.B), Stand = self.Stand }
	)
	waitUntil(now() + Balance.Battle.StartLeadSeconds, state)
	for index = 1, Balance.Battle.MaxClashes do
		if state.Cancelled then
			return
		end
		state.Index, state.Phase, state.Released = index, "Meter", false
		state.Zone, state.JudgedElapsed = "Weak", nil
		state.StartTime = now() + Balance.Battle.ClashLeadSeconds
		local deadline = state.StartTime + Balance.Meter.MaxHoldTime + Balance.Meter.LatencyAllowance
		Remotes.ClashStarted:FireClient(player, {
			BattleId = state.Id,
			ClashIndex = index,
			StartTime = state.StartTime,
			ApproachTime = deadline + Balance.Battle.ClashLeadSeconds + Balance.Battle.SwingSeconds,
		})
		-- Releasing locks a bonus, never stops or accelerates the shared swing cycle.
		waitUntil(deadline, state)
		if state.Cancelled then
			return
		end
		state.Phase = "Swing"
		local result =
			Logic.resolveClash(table.clone(state.A), table.clone(state.B), state.Zone, npc(state.B, state.A), roll)
		local duration = Balance.Battle.SwingSeconds
		if result.Winner then
			duration += Balance.Feel.SlowMotionSeconds * (1 - Balance.Feel.SlowMotionRate)
		end
		local launch = now() + Balance.Battle.ClashLeadSeconds
		local impact = launch + duration
		Remotes.ClashResolved:FireClient(player, {
			BattleId = state.Id,
			ClashIndex = index,
			LaunchTime = launch,
			ImpactTime = impact,
			JudgedElapsed = state.JudgedElapsed,
			Result = result,
		})
		waitUntil(impact, state)
		if state.Cancelled then
			return
		end
		state.A.HP, state.B.HP = result.HpA, result.HpB
		waitUntil(impact + Balance.Battle.BounceSeconds, state)
		if state.Cancelled then
			return
		end
		if result.Winner then
			waitUntil(impact + Balance.Battle.ResultSeconds, state)
			self:Finish(player, state, result.Winner, "Shattered")
			return
		end
	end
	self:Finish(player, state, nil, "Draw")
end

function BattleService:StartBattle(player)
	if self.Active[player] then
		return false
	end
	local time = now()
	if time - (self.PromptTimes[player] or -math.huge) < Balance.Battle.PromptRateSeconds then
		return false
	end
	self.PromptTimes[player] = time
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
	if
		not root
		or not humanoid
		or humanoid.Health <= 0
		or (root.Position - self.PromptPart.Position).Magnitude > Balance.Battle.PromptDistance
	then
		return false
	end
	local state = {
		Id = HttpService:GenerateGUID(false),
		Cancelled = false,
		Index = 0,
		Phase = "Starting",
		A = Logic.newFighter(Glassies.get(Balance.Prototype.PlayerId), { Level = Balance.Prototype.Level }),
		B = Logic.newFighter(Glassies.get(Balance.Prototype.OpponentId), { Level = Balance.Prototype.Level }),
	}
	self.Active[player] = state
	player:SetAttribute("M1BattleId", state.Id)
	task.spawn(function()
		local ok, err = xpcall(function()
			self:RunBattle(player, state)
		end, debug.traceback)
		if not ok then
			warn("[GlassClash] battle failed: " .. tostring(err))
			self:Finish(player, state, nil, "Interrupted")
		end
	end)
	return true
end

function BattleService:Start()
	local part = Instance.new("Part")
	part.Name, part.Size, part.CFrame = "BattlePrompt", Vector3.one, CFrame.new(0, 3, 12)
	part.Anchored, part.CanCollide, part.Transparency = true, false, 1
	part.Parent = self.Stand
	self.PromptPart = part
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.ActionText, prompt.ObjectText = "Challenge", "CLASH", "Practice • Pop vs Jam"
	prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
	prompt.RequiresLineOfSight, prompt.MaxActivationDistance = false, Balance.Battle.PromptDistance
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		self:StartBattle(player)
	end)
	Remotes.ReleaseSwing.OnServerEvent:Connect(function(player, ...)
		self:AcceptRelease(player, ...)
	end)
	local function watch(player)
		player.CharacterRemoving:Connect(function()
			local state = self.Active[player]
			if state then
				self:Finish(player, state, nil, "Interrupted")
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local state = self.Active[player]
		if state then
			state.Cancelled = true
		end
		self.Active[player], self.ReleaseTimes[player], self.PromptTimes[player] = nil, nil, nil
	end)
end
return BattleService
