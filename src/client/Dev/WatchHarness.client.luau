-- Client half of the Studio-only watch QA (Dev/WatchHarness.server). Samples every frame while watching:
-- the Watching flag, camera type, which round view is on screen, and whether other players, our own avatar
-- and other matches' stages are hidden.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local started = false

local function partsHidden(model)
	local hidden, shown = 0, 0
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item.Transparency < 1 then
			if item.LocalTransparencyModifier >= 0.99 then
				hidden += 1
			else
				shown += 1
			end
		end
	end
	return hidden, shown
end

-- "hidden", "shown", "mixed" or "none" for a model's visible parts.
local function state(model)
	if not model then
		return "none"
	end
	local hidden, shown = partsHidden(model)
	if hidden + shown == 0 then
		return "none"
	end
	return if shown == 0 then "hidden" elseif hidden == 0 then "shown" else "mixed"
end

local function others()
	local out = {}
	for _, p in Players:GetPlayers() do
		if p ~= player then
			out[p.Name] = state(p.Character)
			local human = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			out[p.Name .. ".Name"] = human and tostring(human.DisplayDistanceType) or "none"
		end
	end
	return out
end

local function stages(watched)
	local out = {}
	for _, child in workspace:GetChildren() do
		if child.Name:match("^MatchStage_") then
			out[if watched and child.Name == watched then "watched" else child.Name] = state(child)
		end
	end
	return out
end

local function start(folder)
	if started or folder.Name ~= "GlassClashWatchQA" then
		return
	end
	started = true
	local command, report = folder:WaitForChild("Command"), folder:WaitForChild("Report")
	local remotes = require(RS.Shared.Remotes)
	local scripts = player:WaitForChild("PlayerScripts")
	local fight = scripts:WaitForChild("FightClientDev", 30)
	local match = scripts:WaitForChild("MatchClientDev", 30)
	if not fight or not match then
		report:FireServer("Error", { Message = "Client controllers did not initialize" })
		return
	end
	game:GetService("LogService").MessageOut:Connect(function(message, kind)
		if kind == Enum.MessageType.MessageError then
			report:FireServer("Error", { Message = message:sub(1, 600) })
		end
	end)
	-- Play our own match on autopilot (PickDelay slows the picks down like a real player).
	local pickDelay = 0.15
	remotes.RollOffers.OnClientEvent:Connect(function(data)
		if not data.Picked and data.Offers and data.Offers[1] then
			task.delay(pickDelay, function()
				remotes.PickGlassy:FireServer(data.Offers[1])
			end)
		end
	end)
	remotes.MatchState.OnClientEvent:Connect(function(data)
		if data.Phase == "Aiming" and table.find(data.PlayerIds or {}, player.UserId) then
			task.delay(0.15, function()
				remotes.SetAim:FireServer(data.SweetSpot, 0)
			end)
		end
	end)
	local log, last, samples, watchedStage = {}, nil, nil, nil
	local function snapshot()
		local w = fight:Invoke("Watching")
		local pg = player.PlayerGui
		return {
			Watching = pg:GetAttribute("Watching") == true,
			Camera = tostring(workspace.CurrentCamera.CameraType):gsub("Enum.CameraType.", ""),
			View = w and w.ViewId,
			Lingering = w and w.Lingering,
			Isolated = w and w.Isolated,
			Others = others(),
			Self = state(player.Character),
			Stages = stages(watchedStage),
		}
	end
	local function key(s)
		local parts = { tostring(s.Watching), s.Camera, tostring(s.View), tostring(s.Lingering), s.Self }
		local names = {}
		for name in s.Others do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in names do
			table.insert(parts, name .. "=" .. s.Others[name])
		end
		local stageNames = {}
		for name in s.Stages do
			table.insert(stageNames, name)
		end
		table.sort(stageNames)
		for _, name in stageNames do
			table.insert(parts, name .. "=" .. s.Stages[name])
		end
		return table.concat(parts, " ")
	end
	local began = os.clock()
	command.OnClientEvent:Connect(function(action, value)
		if action == "PickDelay" then
			pickDelay = value
		elseif action == "Watch" then
			log, last = {}, nil
			local ok = fight:Invoke("Watch", value)
			local w = fight:Invoke("Watching")
			report:FireServer("Watch", { Ok = ok == true })
			-- The stage folder of the watched match, so the samples can tell it from other matches' stages.
			for _, child in workspace:GetChildren() do
				if w and w.MatchId and child.Name == "MatchStage_" .. w.MatchId then
					watchedStage = child.Name
				end
			end
			began = os.clock()
			samples = RunService.RenderStepped:Connect(function()
				local s = snapshot()
				local k = key(s)
				if k ~= last then
					last = k
					table.insert(log, string.format("%6.2f %s", os.clock() - began, k))
				end
			end)
		elseif action == "Report" then
			if samples then
				samples:Disconnect()
				samples = nil
			end
			report:FireServer(value, { Log = log })
		elseif action == "Check" then
			local s = snapshot()
			s.InMatch = player.PlayerGui:GetAttribute("InMatch") == true
			report:FireServer(value, s)
		elseif action == "Dismiss" then
			match:Invoke("DismissResults")
		end
	end)
	report:FireServer("Ready", { Name = player.Name })
end
RS.ChildAdded:Connect(function(child)
	if child.Name == "GlassClashWatchQA" then
		task.spawn(start, child)
	end
end)
local folder = RS:FindFirstChild("GlassClashWatchQA")
if folder then
	task.spawn(start, folder)
end
