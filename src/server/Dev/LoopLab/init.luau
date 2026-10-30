-- Manual Studio-only entry point. Nothing in Main/Services requires this module.
local Lab = {}
function Lab.start()
	assert(game:GetService("RunService"):IsStudio(), "Loop Lab is private to Studio")
	if Lab.Stop then
		Lab.Stop()
	end
	local RS = game:GetService("ReplicatedStorage")
	local C = require(RS.Shared.Config.LoopLab)
	local Session = require(script.Session)
	local runtime = Instance.new("Folder")
	runtime.Name = "LoopLabRuntime"
	local remote = Instance.new("RemoteEvent")
	remote.Name, remote.Parent = "Action", runtime
	runtime.Parent = RS
	local sessions, limits, reports, pairs, serial = {}, {}, {}, {}, 0
	local connections = {}
	table.insert(
		connections,
		remote.OnServerEvent:Connect(function(player, action, mode, id)
			local now = workspace:GetServerTimeNow()
			local bucket = if action == "Stop" then "Stop" else "Input"
			local record = limits[player] or {}
			if now - (record[bucket] or -math.huge) < C.RateSeconds then
				return
			end
			record[bucket], limits[player] = now, record
			if action == "Stop" then
				sessions[player] = nil
				return
			end
			if action == "Start" then
				if mode ~= "B" or not table.find(C.Roster, id) then
					return
				end
				if sessions[player] and sessions[player].Phase ~= "Result" then
					return
				end
				local previous = pairs[player]
				local seed
				if previous and previous.Id == id and previous.Mode ~= mode then
					seed = previous.Seed
				else
					serial += 1
					seed = C.Seed + serial
				end
				pairs[player] = { Id = id, Mode = mode, Seed = seed }
				sessions[player] = Session.new(mode, id, seed, now)
				remote:FireClient(player, sessions[player]:packet())
			elseif action == "Launch" and sessions[player] then
				sessions[player]:launch(mode, id, now)
			elseif action == "Switch" and sessions[player] and table.find(C.Roster, id) then
				sessions[player].NextId = id -- queue a choice without interrupting the current fight
			end
		end)
	)
	local accumulator, snapshotAt = 0, 0
	table.insert(
		connections,
		game:GetService("RunService").Heartbeat:Connect(function(dt)
			accumulator += math.min(dt, 0.1)
			local now = workspace:GetServerTimeNow()
			while accumulator >= C.Step do
				for player, session in sessions do
					session:step(C.Step, now)
					if session.Phase == "Result" and now >= session.ResultAt + C.ContinueSeconds then
						serial += 1
						sessions[player] = session:next(now, C.Seed + serial)
					end
				end
				accumulator -= C.Step
			end
			if now < snapshotAt then
				return
			end
			snapshotAt = now + C.SnapshotSeconds
			for player, session in sessions do
				if session.Phase == "Result" and not session.Reported then
					session.Reported = true
					table.insert(reports, {
						Mode = session.Mode,
						Id = session.Id,
						Rival = session.Rival,
						Seed = session.Seed,
						Duration = session.Duration,
						Shots = session.Shots,
						Contacts = session.Contacts,
						Reason = session.Reason,
						Winner = session.Winner,
					})
				end
				remote:FireClient(player, session:packet())
			end
		end)
	)
	table.insert(
		connections,
		game.Players.PlayerRemoving:Connect(function(player)
			sessions[player], limits[player], pairs[player] = nil, nil, nil
		end)
	)
	local dev = Instance.new("BindableFunction")
	dev.Name, dev.Parent = "LoopLabReport", game.ServerStorage
	dev.OnInvoke = function()
		return reports
	end
	function Lab.Stop()
		for _, c in connections do
			c:Disconnect()
		end
		runtime:Destroy()
		dev:Destroy()
		Lab.Stop = nil
	end
	return "Loop Lab server ready (Studio only, no profiles or rewards)"
end
return Lab
