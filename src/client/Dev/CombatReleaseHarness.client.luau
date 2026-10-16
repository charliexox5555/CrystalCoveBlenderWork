if not game:GetService("RunService"):IsStudio() then
	return
end
local RS, player = game.ReplicatedStorage, game.Players.LocalPlayer
local function start(folder)
	if folder.Name ~= "CombatReleaseQA" then
		return
	end
	local report, command = folder:WaitForChild("Report"), folder:WaitForChild("Command")
	local dev = player.PlayerScripts:WaitForChild("FightClientDev", 30)
	if not dev then
		return
	end
	local Remotes = require(RS.Shared.Remotes)
	local facts = { Releases = 0, Contacts = 0, Errors = {}, JoinedLate = false }
	game:GetService("LogService").MessageOut:Connect(function(message, kind)
		if kind == Enum.MessageType.MessageError and not message:find("Foundation") then
			table.insert(facts.Errors, message:sub(1, 500))
		end
	end)
	Remotes.MatchState.OnClientEvent:Connect(function(data)
		if data.Id == "combat-qa-main" and data.JoinedLate then
			facts.JoinedLate = true
			facts.BootstrapEvents = math.max(facts.BootstrapEvents or 0, #(data.SignatureState or {}))
		end
	end)
	local rejoined = false
	Remotes.FightEvents.OnClientEvent:Connect(function(packet)
		if packet.Id ~= "combat-qa-main" then
			return
		end
		for _, e in packet.Events do
			if e.Type == "CastRelease" then
				facts.Releases += 1
				if not rejoined and e.Kit == "glass_dragon" then
					rejoined = true
					task.delay(0.1, function()
						dev:Invoke("Rejoin", packet.Id)
					end)
				end
			elseif e.Type == "CastContact" then
				facts.Contacts += 1
			end
		end
	end)
	command.OnClientEvent:Connect(function(action)
		if action == "Profile" then
			report:FireServer("Profile", dev:Invoke("Profile", { Frames = 12 }))
		elseif action == "Finish" then
			facts.Roots = 0
			for _, v in workspace:GetChildren() do
				if v.Name:match("^LocalFight_") then
					facts.Roots += 1
				end
			end
			facts.Views = dev:Invoke("Inspect")
			report:FireServer("Finished", facts)
		end
	end)
	report:FireServer("Ready", {})
end
RS.ChildAdded:Connect(start)
for _, folder in RS:GetChildren() do
	start(folder)
end
