local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local started = false
local function start(folder)
	if started or folder.Name ~= "GlassClashQA" then
		return
	end
	started = true
	local command, report = folder:WaitForChild("Command"), folder:WaitForChild("Report")
	local remotes = require(RS.Shared.Remotes)
	local scripts = player:WaitForChild("PlayerScripts")
	local lobby = scripts:WaitForChild("LobbyClientDev", 30)
	local match = scripts:WaitForChild("MatchClientDev", 30)
	local fight = scripts:WaitForChild("FightClientDev", 30)
	if not lobby or not match or not fight then
		report:FireServer("Error", { Message = "Client controllers did not initialize" })
		return
	end
	local untilAt = os.clock() + 30
	while not lobby:Invoke("Inspect").Profile and os.clock() < untilAt do
		remotes.RequestProfile:FireServer()
		task.wait(0.6)
	end
	game:GetService("LogService").MessageOut:Connect(function(message, kind)
		if kind == Enum.MessageType.MessageError then
			report:FireServer("Error", { Message = message:sub(1, 600) })
		end
	end)
	local results = 0
	remotes.RollOffers.OnClientEvent:Connect(function(data)
		if not data.Picked then
			task.delay(0.15, function()
				remotes.PickGlassy:FireServer(if table.find(data.Offers, "pop") then "pop" else data.Offers[1])
			end)
		end
	end)
	remotes.MatchState.OnClientEvent:Connect(function(data)
		if not table.find(data.PlayerIds or {}, player.UserId) then
			return
		end
		if data.Phase == "Aiming" then
			task.delay(0.15, function()
				remotes.SetAim:FireServer(data.SweetSpot, 0)
			end)
		elseif data.Phase == "Fighting" then
			task.delay(0.6, function()
				for _, view in fight:Invoke("Inspect") do
					if view.Viewing then
						report:FireServer("View", { Side = view.Side, Buffer = view.Buffer, Round = data.Round })
					end
				end
			end)
		end
	end)
	remotes.MatchResult.OnClientEvent:Connect(function(data)
		results += 1
		task.delay(0.2, function()
			report:FireServer("Result" .. results, {
				Won = data.Won,
				Side = data.Side,
				Rewards = data.Rewards,
				ResultsOpen = player.PlayerGui:GetAttribute("ResultsOpen"),
			})
		end)
	end)
	command.OnClientEvent:Connect(function(action, value)
		if action == "Invalid" then
			remotes.PickGlassy:FireServer("not_owned")
			remotes.SetAim:FireServer(0 / 0, math.huge)
			remotes.ClaimRetention:FireServer("Gift", 999)
			remotes.RedeemCode:FireServer({ Coins = 999999 })
			remotes.PullKiln:FireServer(1000, "bad")
			for _ = 1, 20 do
				remotes.RequestProfile:FireServer()
			end
		elseif action == "Drop" then
			fight:Invoke("DropEvery", value)
		elseif action == "Sample" then
			task.spawn(function()
				local frames, total, maximum = 0, 0, 0
				local c = RunService.RenderStepped:Connect(function(dt)
					frames += 1
					total += dt
					maximum = math.max(maximum, dt)
				end)
				task.wait(5)
				c:Disconnect()
				report:FireServer(
					"Sample",
					{ Frames = frames, FPS = frames / math.max(0.001, total), MaxFrameMs = maximum * 1000 }
				)
			end)
		elseif action == "Dismiss" then
			match:Invoke("DismissResults")
			task.delay(0.35, function()
				report:FireServer("Cleanup" .. results, {
					Touch = game:GetService("GuiService").TouchControlsEnabled,
					Camera = tostring(workspace.CurrentCamera.CameraType),
					InMatch = player.PlayerGui:GetAttribute("InMatch"),
					ResultsOpen = player.PlayerGui:GetAttribute("ResultsOpen"),
				})
			end)
		elseif action == "InspectWorld" then
			task.delay(0.5, function()
				local count = 0
				for _, v in fight:Invoke("Inspect") do
					if not v.Viewing and v.Side == 0 and v.Buffer > 0 and v.Time > 0 then
						count += 1
					end
				end
				local hud = player.PlayerGui:FindFirstChild("FightHud")
				report:FireServer("Spectator", {
					Count = count,
					Camera = tostring(workspace.CurrentCamera.CameraType),
					Hud = hud ~= nil and hud.Enabled,
				})
			end)
		elseif action == "Replay" then
			remotes.RequestRematch:FireServer()
		elseif action == "Leave" then
			local svc = game:GetService("StudioTestService")
			if svc:CanLeaveTest() then
				svc:LeaveTest()
			else
				report:FireServer("Error", { Message = "Native client cannot leave test" })
			end
		end
	end)
	report:FireServer(
		"Ready",
		{ Name = player.Name, UserId = player.UserId, ProfileLoaded = lobby:Invoke("Inspect").Profile ~= nil }
	)
end
RS.ChildAdded:Connect(function(child)
	if child.Name == "GlassClashQA" then
		task.spawn(start, child)
	end
end)
local folder = RS:FindFirstChild("GlassClashQA")
if folder then
	task.spawn(start, folder)
end
