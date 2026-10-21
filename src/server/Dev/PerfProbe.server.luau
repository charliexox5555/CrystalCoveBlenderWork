-- Studio-only server performance probe for the optimization pass (docs/testing/perf).
-- ServerStorage.PerfProbeServerDev:Invoke("Sample", seconds) returns Heartbeat frame times, time spent in the
-- per-frame service methods, profile sync counts and Roblox's own network stats. Measuring only: the wrappers
-- call straight through and are removed again when the sample ends.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local services = script.Parent.Parent:WaitForChild("Services")

local TARGETS = {
	{ "FightService", "Step" },
	{ "FightService", "Send" },
	{ "MatchService", "Dispatch" },
	{ "ArenaService", "Step" },
	{ "ArenaService", "MatchBoard" },
	{ "HillService", "Step" },
	{ "DataService", "Sync" },
	{ "LeaderboardService", "Changed" },
}

local dev = Instance.new("BindableFunction")
dev.Name = "PerfProbeServerDev"
dev.OnInvoke = function(command, seconds)
	if command ~= "Sample" then
		return nil
	end
	seconds = math.clamp(tonumber(seconds) or 5, 1, 30)
	local timing, originals = {}, {}
	for _, target in TARGETS do
		local module = services:FindFirstChild(target[1])
		local service = module and require(module)
		local original = service and service[target[2]]
		if type(original) == "function" then
			local key = target[1] .. "." .. target[2]
			local entry = { Calls = 0, Seconds = 0 }
			timing[key] = entry
			originals[key] = { service, target[2], original }
			service[target[2]] = function(...)
				local started = os.clock()
				local results = table.pack(original(...))
				entry.Calls += 1
				entry.Seconds += os.clock() - started
				return table.unpack(results, 1, results.n)
			end
		end
	end
	local frames = {}
	local connection = RunService.Heartbeat:Connect(function(dt)
		table.insert(frames, dt * 1000)
	end)
	local sendSamples = {}
	local stop = os.clock() + seconds
	while os.clock() < stop do
		task.wait(0.5)
		table.insert(sendSamples, Stats.DataSendKbps)
	end
	connection:Disconnect()
	for _, saved in originals do
		saved[1][saved[2]] = saved[3]
	end
	table.sort(frames)
	local out = {}
	for key, entry in timing do
		out[key] = string.format(
			"%d calls/s, %.3f ms/frame",
			entry.Calls / seconds,
			entry.Seconds * 1000 / math.max(1, #frames)
		)
	end
	local sendTotal = 0
	for _, kbps in sendSamples do
		sendTotal += kbps
	end
	return {
		Players = #Players:GetPlayers(),
		Frames = #frames,
		HeartbeatMeanMs = (function()
			local total = 0
			for _, ms in frames do
				total += ms
			end
			return total / math.max(1, #frames)
		end)(),
		HeartbeatMaxMs = frames[#frames] or 0,
		Services = out,
		SendKbps = sendTotal / math.max(1, #sendSamples),
		HeapKB = gcinfo(),
		TotalMemoryMB = Stats:GetTotalMemoryUsageMb(),
	}
end
dev.Parent = game:GetService("ServerStorage")
