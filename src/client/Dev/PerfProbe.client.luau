-- Studio-only client performance probe for the optimization pass (docs/testing/perf).
-- PlayerScripts.PerfProbeDev:Invoke("Sample", seconds) measures for `seconds` and returns:
--   frames (mean / p95 / max ms), remote traffic received per remote (messages and approximate KB per second),
--   Luau heap and total memory, instance counts and live effect counts.
-- Measuring only: it changes nothing in the game.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local player = Players.LocalPlayer

-- Approximate wire size: buffers by length, everything else by its JSON form (Roblox's encoding differs,
-- but it is the same order and tracks changes).
local function size(value)
	local kind = typeof(value)
	if kind == "buffer" then
		return buffer.len(value)
	elseif kind == "table" then
		local total = 2
		for k, v in value do
			total += size(k) + size(v)
		end
		return total
	elseif kind == "string" then
		return #value + 1
	elseif kind == "number" then
		return 8
	elseif kind == "boolean" then
		return 1
	elseif kind == "Vector3" then
		return 12
	elseif kind == "CFrame" then
		return 48
	elseif kind == "Instance" then
		return 8
	end
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, value)
	return if ok then #encoded else 8
end

local traffic = {}
local function watch(remote)
	if not remote:IsA("RemoteEvent") and not remote:IsA("UnreliableRemoteEvent") then
		return
	end
	remote.OnClientEvent:Connect(function(...)
		local entry = traffic[remote.Name]
		if not entry then
			entry = { Count = 0, Bytes = 0, Max = 0 }
			traffic[remote.Name] = entry
		end
		local bytes = 0
		for i = 1, select("#", ...) do
			bytes += size((select(i, ...)))
		end
		entry.Count += 1
		entry.Bytes += bytes
		entry.Max = math.max(entry.Max, bytes)
	end)
end
local folder = RS:WaitForChild("Remotes")
for _, remote in folder:GetChildren() do
	watch(remote)
end
folder.ChildAdded:Connect(watch)

local function counts()
	local out = {
		Workspace = 0,
		PlayerGui = #player.PlayerGui:GetDescendants(),
		Parts = 0,
		EmittersOn = 0,
		BeamsTrailsOn = 0,
		HighlightsOn = 0,
		LightsOn = 0,
		ViewportsShown = 0,
		SoundsPlaying = 0,
		TextLabels = 0,
	}
	for _, object in workspace:GetDescendants() do
		out.Workspace += 1
		if object:IsA("BasePart") then
			out.Parts += 1
		elseif object:IsA("ParticleEmitter") and object.Enabled then
			out.EmittersOn += 1
		elseif (object:IsA("Beam") or object:IsA("Trail")) and object.Enabled then
			out.BeamsTrailsOn += 1
		elseif object:IsA("Light") and object.Enabled then
			out.LightsOn += 1
		elseif object:IsA("Sound") and object.IsPlaying then
			out.SoundsPlaying += 1
		elseif object:IsA("Highlight") and object.Enabled then
			out.HighlightsOn += 1
		end
	end
	for _, object in player.PlayerGui:GetDescendants() do
		if object:IsA("ViewportFrame") and object.Visible then
			local gui = object:FindFirstAncestorWhichIsA("ScreenGui")
			if gui and gui.Enabled then
				out.ViewportsShown += 1
			end
		elseif object:IsA("TextLabel") or object:IsA("TextButton") then
			out.TextLabels += 1
		end
	end
	return out
end

local dev = Instance.new("BindableFunction")
dev.Name = "PerfProbeDev"
dev.OnInvoke = function(command, seconds)
	if command == "Counts" then
		return counts()
	end
	if command ~= "Sample" then
		return nil
	end
	seconds = math.clamp(tonumber(seconds) or 5, 1, 30)
	table.clear(traffic)
	local frames = {}
	local heapStart = gcinfo()
	local connection = RunService.RenderStepped:Connect(function(dt)
		table.insert(frames, dt * 1000)
	end)
	task.wait(seconds)
	connection:Disconnect()
	table.sort(frames)
	local total = 0
	for _, ms in frames do
		total += ms
	end
	local remotes = {}
	for name, entry in traffic do
		remotes[name] = string.format(
			"%.1f msg/s, %.2f KB/s, max %d B",
			entry.Count / seconds,
			entry.Bytes / seconds / 1024,
			entry.Max
		)
	end
	return {
		Seconds = seconds,
		Frames = #frames,
		MeanMs = total / math.max(1, #frames),
		P95Ms = frames[math.max(1, math.floor(#frames * 0.95))] or 0,
		MaxMs = frames[#frames] or 0,
		HeapKB = gcinfo(),
		HeapGrowthKB = gcinfo() - heapStart,
		TotalMemoryMB = Stats:GetTotalMemoryUsageMb(),
		Remotes = remotes,
		Counts = counts(),
	}
end
dev.Parent = player:WaitForChild("PlayerScripts")
