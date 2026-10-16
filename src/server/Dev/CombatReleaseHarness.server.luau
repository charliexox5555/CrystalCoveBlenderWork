if not game:GetService("RunService"):IsStudio() then
	return
end
local STS = game:GetService("StudioTestService")
local args = STS:GetTestArgs()
if type(args) ~= "table" or args.Name ~= "GlassClashCombatQA" then
	return
end
local folder = Instance.new("Folder")
folder.Name = "CombatReleaseQA"
local report, command = Instance.new("RemoteEvent"), Instance.new("RemoteEvent")
report.Name, report.Parent = "Report", folder
command.Name, command.Parent = "Command", folder
local reports = {}
report.OnServerEvent:Connect(function(player, kind, data)
	reports[player.UserId] = reports[player.UserId] or {}
	reports[player.UserId][kind] = data
end)
folder.Parent = game.ReplicatedStorage
local finished = false
local function finish(result)
	if finished then
		return
	end
	finished = true
	STS:EndTest(result)
end
task.delay(100, function()
	finish({ Ok = false, Message = "Combat QA timeout" })
end)
local function waitFor(predicate, limit)
	local deadline = os.clock() + limit
	repeat
		if predicate() then
			return
		end
		task.wait(0.1)
	until os.clock() > deadline
	error("Combat QA stage timed out")
end
local ok, result = xpcall(function()
	waitFor(function()
		local players = game.Players:GetPlayers()
		if #players ~= 2 then
			return false
		end
		for _, p in players do
			if not reports[p.UserId] or not reports[p.UserId].Ready then
				return false
			end
		end
		return true
	end, 40)
	local services = script.Parent.Parent.Services
	local Fight, Arena, Data =
		require(services.FightService), require(services.ArenaService), require(services.DataService)
	assert(Data.Mock, "Isolated mock profiles required")
	local players = game.Players:GetPlayers()
	waitFor(function()
		for _, p in players do
			if not p.Character or not p.Character:FindFirstChild("HumanoidRootPart") then
				return false
			end
		end
		return true
	end, 20)
	-- Reserve all pads before positioning test avatars; otherwise the real auto-queue starts an
	-- unrelated eighth fight and replaces the developer metadata during this isolated test.
	for _, arena in Arena.Arenas do
		arena.Busy = true
	end
	for side, p in players do
		p.Character:PivotTo(CFrame.new(Arena.Arenas[1].Pads[side].Position + Vector3.yAxis * 4))
	end
	local Rng = require(game.ReplicatedStorage.Shared.Rng)
	local pairs = {
		{ "glass_dragon", "lemonade_bottle" },
		{ "rocket_pop", "glass_duck" },
		{ "hourglass", "comet" },
		{ "prism_blade", "frostglobe" },
		{ "water_jug", "glass_cup" },
		{ "ketchup_bottle", "pickle_jar" },
		{ "milk_bottle", "crystal_tumbler" },
	}
	local sessions = {}
	for i, pair in pairs do
		local id = if i == 1 then "combat-qa-main" else "combat-qa-" .. i
		local setup = {
			A = { Id = pair[1], Aim = 0.85 },
			B = { Id = pair[2], Aim = 0.85 },
			Rng = Rng.new(8800 + i),
			SweetSpot = 0.85,
		}
		sessions[i] = Fight:StartFight(id, Arena.Arenas[i], setup, 8800 + i, {
			Names = { players[1].DisplayName, players[2].DisplayName },
			PlayerIds = if i == 1 then { players[1].UserId, players[2].UserId } else { 0, 0 },
			Hearts = { 3, 3 },
			ReleaseAt = workspace:GetServerTimeNow() + 1,
		}, function() end)
	end
	task.wait(4)
	command:FireAllClients("Profile")
	waitFor(function()
		for _, p in players do
			if not reports[p.UserId].Profile then
				return false
			end
		end
		return true
	end, 30)
	waitFor(function()
		return sessions[1].Sim.Fight.Over
	end, 50)
	task.wait(3)
	for _, session in sessions do
		Fight:Stop(session.Id)
	end
	task.wait(1)
	command:FireAllClients("Finish")
	waitFor(function()
		for _, p in players do
			if not reports[p.UserId].Finished then
				return false
			end
		end
		return true
	end, 5)
	for _, p in players do
		local r = reports[p.UserId]
		assert(r.Profile and r.Profile.Views == 7, "Seven render views")
		assert(r.Finished.Releases > 0 and r.Finished.Contacts > 0, "Replicated release/contact facts")
		assert(r.Finished.JoinedLate, "Mid-fight state rejoin")
		assert(r.Finished.Roots == 0 and next(r.Finished.Views) == nil, "Round cleanup")
		assert(#r.Finished.Errors == 0, "Client errors: " .. table.concat(r.Finished.Errors, "; "))
	end
	return {
		Ok = true,
		Clients = reports,
		RoundSeconds = sessions[1].Sim.Fight.Time,
		Winner = sessions[1].Sim.Fight.Winner,
	}
end, debug.traceback)
finish(if ok then result else { Ok = false, Message = result, Clients = reports })
