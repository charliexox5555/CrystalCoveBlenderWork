-- Studio-only two-client QA for watching and stage isolation (launch: MultiplayerLauncher.watch()).
-- A watches a bot match for every round while B walks into that arena and respawns there; then A plays a
-- match while B stands in it. The client half (Dev/WatchHarness.client) samples camera, watch state and who
-- is visible every frame.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local STS = game:GetService("StudioTestService")
local args = STS:GetTestArgs()
if type(args) ~= "table" or args.Name ~= "GlassClashWatchQA" then
	return
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local root = Instance.new("Folder")
root.Name = "GlassClashWatchQA"
local command, report = Instance.new("RemoteEvent"), Instance.new("RemoteEvent")
command.Name, command.Parent = "Command", root
report.Name, report.Parent = "Report", root
local reports, errors, finished = {}, {}, false
local output = { Stages = {}, Errors = errors }
local function finish(ok, message)
	if finished then
		return
	end
	finished = true
	output.Ok, output.Message = ok, message
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
-- Studio noise, not game errors: meshes the test clients may not load, and MCP inspection commands.
local function noise(message)
	return message:find("MeshContentProvider", 1, true) ~= nil
		or message:find("ContentId", 1, true) ~= nil
		or message:find("AssistantCommand", 1, true) ~= nil
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
end)
root.Parent = RS
game:GetService("LogService").MessageOut:Connect(function(message, kind)
	if kind == Enum.MessageType.MessageError and not noise(message) then
		table.insert(errors, { Server = true, Message = message:sub(1, 600) })
	end
end)
task.delay(660, function()
	finish(false, "Eleven-minute watch QA timeout")
end)
local ok, err = xpcall(function()
	waitFor(function()
		return #Players:GetPlayers() >= 2
	end, 60, "two clients")
	local players = Players:GetPlayers()
	table.sort(players, function(x, y)
		return x.UserId < y.UserId
	end)
	local a, b = players[1], players[2]
	local services = script.Parent.Parent.Services
	local Data = require(services.DataService)
	local Arena = require(services.ArenaService)
	local Match = require(services.MatchService)
	for _, p in { a, b } do
		waitFor(function()
			return Data:IsReady(p) and reports[tostring(p.UserId)] and reports[tostring(p.UserId)].Ready
		end, 60, "profile/client ready")
		assert(Data.Mock, "Watch QA must use isolated mock profiles")
	end
	local function pen(arena)
		local floor = arena.Stand:FindFirstChild("PenFloor", true)
		return (floor and floor.Position or (arena.Pads[1].Position + arena.Pads[2].Position) / 2)
	end
	local function intrude(arena)
		local character = b.Character or b.CharacterAdded:Wait()
		character:WaitForChild("HumanoidRootPart", 10)
		local middle = (arena.Pads[1].Position + arena.Pads[2].Position) / 2
		character:PivotTo(CFrame.new(middle + Vector3.new(0, 4, 0)))
	end
	-- 1. Watch a whole bot match while B stands in it and respawns there.
	local watched, other = Arena.Arenas[2], Arena.Arenas[3]
	assert(Match:StartMatch(watched, {}, workspace:GetServerTimeNow()), "bot match did not start")
	Match:StartMatch(other, {}, workspace:GetServerTimeNow())
	local entry = Match.Matches[2]
	a.Character:PivotTo(CFrame.new(pen(watched) + Vector3.new(6, 4, 6)))
	intrude(watched)
	waitFor(function()
		return entry.Runner.Phase == "Fighting"
	end, 40, "watched fight")
	command:FireClient(a, "Watch", 2)
	waitFor(function()
		return reports[tostring(a.UserId)].Watch
	end, 5, "watch started")
	assert(reports[tostring(a.UserId)].Watch.Ok, "Watch did not start")
	table.insert(output.Stages, "watching arena 2 (bot match) with B standing in it")
	waitFor(function()
		return entry.Runner.Match.Round >= 2 or entry.Finished
	end, 90, "second round")
	b:LoadCharacter()
	task.wait(0.5)
	intrude(watched)
	table.insert(output.Stages, "B respawned into the watched arena")
	waitFor(function()
		return entry.Finished
	end, 300, "watched match end")
	output.WatchedRounds = #entry.Runner.Match.History
	task.wait(1.5)
	command:FireClient(a, "Report", "Watched")
	local watchedReport = waitFor(function()
		return reports[tostring(a.UserId)].Watched
	end, 10, "watch report")
	output.Watched = watchedReport
	-- 2. A plays a match while B stands in that arena.
	local own = Arena.Arenas[4]
	assert(Match:StartMatch(own, { [1] = a }, workspace:GetServerTimeNow()), "own match did not start")
	local ownEntry = Match.Matches[4]
	intrude(own)
	waitFor(function()
		return ownEntry.Runner.Phase == "Fighting"
	end, 70, "own fight")
	task.wait(1)
	command:FireClient(a, "Check", "InMatch")
	waitFor(function()
		return reports[tostring(a.UserId)].InMatch
	end, 5, "in-match check")
	Match:Forfeit(a)
	waitFor(function()
		return ownEntry.Finished
	end, 15, "forfeit")
	task.wait(1)
	command:FireClient(a, "Dismiss")
	task.wait(1)
	command:FireClient(a, "Check", "AfterMatch")
	waitFor(function()
		return reports[tostring(a.UserId)].AfterMatch
	end, 5, "after-match check")
	output.InMatch = reports[tostring(a.UserId)].InMatch
	output.AfterMatch = reports[tostring(a.UserId)].AfterMatch
	table.insert(output.Stages, "own match with B in the arena; forfeit")
	-- 3. Watch a human's match (B vs a bot) with slow picks: the view must hold through a long roll, and B,
	-- a fighter, must stay visible.
	command:FireClient(b, "PickDelay", 6)
	local human = Arena.Arenas[5]
	assert(Match:StartMatch(human, { [1] = b }, workspace:GetServerTimeNow()), "human match did not start")
	local humanEntry = Match.Matches[5]
	a.Character:PivotTo(CFrame.new(pen(human) + Vector3.new(6, 4, 6)))
	waitFor(function()
		return humanEntry.Runner.Phase == "Fighting"
	end, 40, "human fight")
	command:FireClient(a, "Watch", 5)
	waitFor(function()
		return humanEntry.Runner.Match.Round >= 3 or humanEntry.Finished
	end, 200, "third round of the human match")
	waitFor(function()
		return humanEntry.Runner.Phase == "Fighting" or humanEntry.Finished
	end, 40, "third fight")
	task.wait(2)
	Match:Forfeit(b)
	waitFor(function()
		return humanEntry.Finished
	end, 15, "human forfeit")
	task.wait(1.5)
	command:FireClient(a, "Report", "WatchedHuman")
	output.WatchedHuman = waitFor(function()
		return reports[tostring(a.UserId)].WatchedHuman
	end, 10, "human watch report")
	table.insert(output.Stages, "watched a human match through slow rolls; forfeit ends the watch")
	-- Every sample while watching: watch flag on, fight camera, B as expected; the last sample: all back.
	local function check(name, log, bState, rounds)
		assert(#log >= 2, name .. ": too few samples")
		local views = {}
		for i, line in log do
			if i < #log then
				assert(line:find(" true Scriptable ", 1, true), name .. ": watch or camera dropped: " .. line)
				-- "none" = B has no character this instant (mid-respawn), which also shows nothing.
				local ok = line:find(b.Name .. "=" .. bState, 1, true)
					or bState == "hidden" and line:find(b.Name .. "=none", 1, true)
				assert(ok, name .. ": B not " .. bState .. ": " .. line)
				assert(
					line:find(" hidden " .. b.Name, 1, true) or line:find(" hidden Player", 1, true),
					name .. ": own avatar shown"
				)
				local view = line:match("round%-(%d+)")
				if view then
					views[view] = true
				end
			else
				assert(line:find(" false Custom ", 1, true), name .. ": camera not restored: " .. line)
				assert(line:find(b.Name .. "=shown", 1, true), name .. ": B not restored: " .. line)
			end
		end
		local count = 0
		for _ in views do
			count += 1
		end
		assert(count >= rounds, name .. ": followed " .. count .. " of " .. rounds .. " rounds")
	end
	check("Bot match", output.Watched.Log, "hidden", output.WatchedRounds)
	check("Human match", output.WatchedHuman.Log, "shown", 3)
	assert(output.InMatch.Others[b.Name] == "hidden" and output.InMatch.Self == "shown", "In-match isolation wrong")
	assert(output.AfterMatch.Others[b.Name] == "shown", "In-match isolation not restored")
	assert(#errors == 0, "Runtime errors captured")
end, debug.traceback)
finish(ok, if ok then "Watch QA passed" else tostring(err))
