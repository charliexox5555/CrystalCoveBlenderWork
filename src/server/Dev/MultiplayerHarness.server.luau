local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local STS = game:GetService("StudioTestService")
local args = STS:GetTestArgs()
if type(args) ~= "table" or args.Name ~= "GlassClashQA" then
	return
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local root = Instance.new("Folder")
root.Name = "GlassClashQA"
local command, report = Instance.new("RemoteEvent"), Instance.new("RemoteEvent")
command.Name, command.Parent = "Command", root
report.Name, report.Parent = "Report", root
local reports, errors, finished = {}, {}, false
local output = { Stages = {}, Clients = {}, Errors = errors }
local began = os.clock()
-- Studio noise, not game errors: meshes the test clients may not load, and MCP inspection commands.
local function noise(message)
	return message:find("MeshContentProvider", 1, true) ~= nil
		or message:find("ContentId", 1, true) ~= nil
		or message:find("AssistantCommand", 1, true) ~= nil
end
local function finish(ok, message)
	if finished then
		return
	end
	finished = true
	output.Ok, output.Message, output.Seconds = ok, message, os.clock() - began
	STS:EndTest(output)
end
local function waitFor(predicate, seconds, message)
	local limit = os.clock() + seconds
	repeat
		local value = predicate()
		if value then
			return value
		end
		task.wait(0.1)
	until os.clock() >= limit or finished
	error("Timeout: " .. message)
end
report.OnServerEvent:Connect(function(player, stage, data)
	if type(stage) ~= "string" or #stage > 40 or type(data) ~= "table" then
		return
	end
	local id = tostring(player.UserId)
	reports[id] = reports[id] or {}
	reports[id][stage] = data
	if stage == "Error" and not noise(tostring(data.Message)) then
		table.insert(errors, { Client = id, Message = data.Message })
	end
	output.Clients[id] = reports[id]
end)
root.Parent = RS
game:GetService("LogService").MessageOut:Connect(function(message, kind)
	if kind == Enum.MessageType.MessageError and not noise(message) then
		table.insert(errors, { Server = true, Message = message:sub(1, 600) })
	end
end)
task.delay(480, function()
	finish(false, "Eight-minute QA timeout")
end)
local ok, err = xpcall(function()
	waitFor(function()
		return #Players:GetPlayers() >= 2
	end, 60, "two clients")
	local players = Players:GetPlayers()
	table.sort(players, function(a, b)
		return a.UserId < b.UserId
	end)
	local a, b = players[1], players[2]
	a:SetAttribute("QASide", 1)
	b:SetAttribute("QASide", 2)
	local services = script.Parent.Parent.Services
	local Data = require(services.DataService)
	local Arena = require(services.ArenaService)
	local Match = require(services.MatchService)
	local Fight = require(services.FightService)
	local Glassies = require(RS.Shared.Config.Glassies)
	local Balance = require(RS.Shared.Config.Balance)
	for _, p in { a, b } do
		waitFor(function()
			return Data.Profiles
				and Data:IsReady(p)
				and reports[tostring(p.UserId)]
				and reports[tostring(p.UserId)].Ready
		end, 60, "profile/client ready")
		assert(Data.Mock, "Native QA must use isolated mock profiles")
		command:FireClient(p, "Invalid")
	end
	task.wait(2)
	-- Decision 102: a new profile owns no glassies; Glassies.Fallback lends a hand for each match.
	local ownedBefore = {}
	for _, p in { a, b } do
		local data = Data:Get(p)
		assert(data.Coins == 0, "Invalid inputs granted coins")
		assert(next(data.Glassies) == nil, "A new profile owns glassies (decision 102)")
		ownedBefore[p] = table.clone(data.Glassies)
	end
	table.insert(output.Stages, "two isolated profiles; invalid remote inputs rejected")
	-- Decision 100: a new profile opens its claim card instead of queueing, so the QA players skip the tutorial.
	local Onboarding = require(services.OnboardingService)
	for _, p in { a, b } do
		Onboarding:SetStep(p, "Done")
	end
	local arena = Arena.Arenas[1]
	-- Pads queue through their "Join Battle" ProximityPrompt; a server script can't trigger one, so stand on the
	-- pad and take the same authoritative path the prompt's Triggered handler calls.
	local function joinPad(p, side)
		p.Character:PivotTo(CFrame.new(arena.Pads[side].Position + Vector3.new(0, 4, 0)))
		assert(Arena:Queue(p, arena, side, workspace:GetServerTimeNow()), "Pad queue refused side " .. side)
	end
	for side, p in { a, b } do
		joinPad(p, side)
	end
	waitFor(function()
		return Match.ByPlayer[a] and Match.ByPlayer[b]
	end, 15, "pad PvP queue")
	local first = Match.ByPlayer[a].Entry
	assert(first.Players[1] == a and first.Players[2] == b, "Queue selected wrong players/sides")
	waitFor(function()
		return first.Runner.Phase == "Fighting"
	end, 25, "PvP release")
	table.insert(output.Stages, "two human pad queue; offered picks and aim remotes accepted")
	for id, other in Arena.Arenas do
		if id ~= 1 and not other.Busy then
			Match:StartMatch(other, {}, workspace:GetServerTimeNow())
		end
	end
	waitFor(function()
		local count = 0
		for _, session in Fight.Sessions do
			if not session.Sim.Fight.Over and session.Sim.Fight.Time > 0 then
				count += 1
			end
		end
		return count == 7
	end, 25, "seven simultaneous moving fights")
	-- Measure the real service step while all seven simulations are active.
	local originalStep = Fight.Step
	local steps, totalStep, maxStep, frames, totalFrame, maxFrame = 0, 0, 0, 0, 0, 0
	Fight.Step = function(self, ...)
		local at = os.clock()
		originalStep(self, ...)
		local elapsed = os.clock() - at
		steps += 1
		totalStep += elapsed
		maxStep = math.max(maxStep, elapsed)
	end
	local sampleConnection = RunService.Heartbeat:Connect(function(dt)
		frames += 1
		totalFrame += dt
		maxFrame = math.max(maxFrame, dt)
	end)
	command:FireClient(b, "Drop", 3)
	command:FireAllClients("Sample")
	task.wait(6)
	Fight.Step = originalStep
	sampleConnection:Disconnect()
	output.ServerSample = {
		Frames = frames,
		FPS = frames / math.max(0.001, totalFrame),
		MaxFrameMs = maxFrame * 1000,
		ServiceStepCalls = steps,
		MeanStepMs = totalStep * 1000 / math.max(1, steps),
		MaxStepMs = maxStep * 1000,
		MeanSimulationFrameMs = totalStep * 1000 / math.max(1, frames),
	}
	for side, p in { a, b } do
		local r = reports[tostring(p.UserId)]
		assert(r.View and r.View.Side == side and r.View.Buffer >= 1, "Participant view ownership/buffer failed")
		assert(r.Sample and r.Sample.Frames > 0, "Client frame sample missing")
	end
	table.insert(
		output.Stages,
		"seven moving fights; server/client frame samples; one-third unreliable snapshots dropped on side B"
	)
	waitFor(function()
		return first.Finished
	end, 330, "complete PvP match")
	for _, p in { a, b } do
		waitFor(function()
			return reports[tostring(p.UserId)].Result1
		end, 10, "results UI")
		local data = Data:Get(p)
		assert(data.Stats.MatchWins + data.Stats.MatchLosses == 1 and data.Coins > 0, "Match settlement missing")
		for id in data.Glassies do
			assert(ownedBefore[p][id], "The match granted a glassy: " .. id)
		end
		local offers = reports[tostring(p.UserId)].Offers
		assert(offers and #offers.Offers == Balance.Match.RollChoices, "The match did not roll a full hand")
		for _, id in offers.Offers do
			assert(table.find(Glassies.Fallback, id), "Offer outside the Fallback hand: " .. tostring(id))
		end
		command:FireClient(p, "Dismiss")
	end
	task.wait(0.5)
	for _, p in { a, b } do
		local clean = waitFor(function()
			return reports[tostring(p.UserId)].Cleanup1
		end, 10, "results cleanup")
		assert(
			(clean.Touch or clean.Claim and clean.GateOwners == 1)
				and clean.Camera == "Enum.CameraType.Custom"
				and not clean.InMatch
				and not clean.ResultsOpen,
			"Controls/camera did not restore"
		)
	end
	table.insert(output.Stages, "full PvP result/reward settlement; both cameras and controls restored")
	-- Exercise real Replay remote and disconnect cleanup during a second match.
	b.Character:PivotTo(CFrame.new(workspace.Lobby.Spots.Spawn.Position + Vector3.new(0, 4, 0)))
	task.wait(0.4)
	command:FireClient(a, "Replay")
	waitFor(function()
		return Arena.ByPlayer[a] ~= nil
	end, 5, "Play Again queue")
	joinPad(b, 2)
	waitFor(function()
		return Match.ByPlayer[a] and Match.ByPlayer[b]
	end, 10, "replay human match")
	local second = Match.ByPlayer[a].Entry
	local beforeAbandon = {
		Coins = Data:Get(a).Coins,
		Trophies = Data:Get(a).Trophies,
		Matches = Data:Get(a).Stats.MatchWins + Data:Get(a).Stats.MatchLosses,
	}
	waitFor(function()
		return second.Runner.Phase == "Fighting"
	end, 25, "replay fight")
	command:FireClient(b, "Leave")
	waitFor(function()
		return b.Parent ~= Players and second.Finished and not Match.ByPlayer[a]
	end, 15, "disconnect forfeit cleanup")
	command:FireClient(a, "Dismiss")
	local clean = waitFor(function()
		return reports[tostring(a.UserId)].Cleanup2
	end, 10, "post-disconnect UI cleanup")
	assert(
		(clean.Touch or clean.Claim and clean.GateOwners == 1)
			and clean.Camera == "Enum.CameraType.Custom"
			and not clean.InMatch
			and not clean.ResultsOpen,
		"Post-disconnect controls/camera did not restore"
	)
	table.insert(output.Stages, "Play Again; opponent disconnect; arena/player registry released")
	local afterAbandon = Data:Get(a)
	assert(
		afterAbandon.Coins == beforeAbandon.Coins
			and afterAbandon.Trophies == beforeAbandon.Trophies
			and afterAbandon.Stats.MatchWins + afterAbandon.Stats.MatchLosses == beforeAbandon.Matches,
		"Abandoned match awarded progress before a completed round"
	)
	output.NoContest = { CoinsUnchanged = true, TrophiesUnchanged = true, MatchStatsUnchanged = true }
	local spectate = Arena.Arenas[2]
	-- The bot match left in arena 2 since the seven-fight sample may be between rounds or finishing; start a new
	-- one whenever the arena is free.
	waitFor(function()
		if not Match.Matches[2] then
			Match:StartMatch(spectate, {}, workspace:GetServerTimeNow())
		end
		return Match.Matches[2] and Match.Matches[2].Runner.Phase == "Fighting"
	end, 60, "ongoing fight before join")
	STS:AddPlayers(1)
	local joined = waitFor(function()
		for _, p in Players:GetPlayers() do
			if p ~= a and p ~= b then
				return p
			end
		end
	end, 30, "staggered join")
	waitFor(function()
		return Data:IsReady(joined) and reports[tostring(joined.UserId)] and reports[tostring(joined.UserId)].Ready
	end, 40, "new client profile ready")
	assert(
		Data:Get(joined).Coins == 0 and next(Data:Get(joined).Glassies) == nil,
		"Fresh client inherited another profile"
	)
	-- Snapshots only reach players near an arena (FightService:Interested), so the joiner walks up to arena 2 first.
	local character = waitFor(function()
		return joined.Character and joined.Character:FindFirstChild("HumanoidRootPart") and joined.Character
	end, 20, "late joiner character")
	character:PivotTo(CFrame.new(spectate.Pads[1].Position + Vector3.new(0, 4, 0)))
	task.wait(1.5)
	command:FireClient(joined, "InspectWorld")
	local world = waitFor(function()
		return reports[tostring(joined.UserId)].Spectator
	end, 10, "late spectator state")
	assert(world.Count > 0, "Late spectator did not receive live fight state")
	assert(world.Camera == "Enum.CameraType.Custom" and world.Hud == false, "Spectator took over camera/HUD")
	table.insert(output.Stages, "staggered native join: isolated profile and immediate live spectator state")
	for _, p in { a, joined } do
		local data = Data:Get(p)
		output["Profile_" .. p.UserId] = { Coins = data.Coins, Trophies = data.Trophies, Stats = data.Stats }
	end
	-- The unit suites run in Lune and on a plain Play server (RunAll); run unyielding here, beside seven fights and
	-- three clients, they exceed the script timeout and kill the harness before EndTest.
	assert(#errors == 0, "Runtime errors captured")
end, debug.traceback)
finish(ok, if ok then "Native multiplayer checks passed" else tostring(err))
