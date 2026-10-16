-- Required by the Studio MCP in Edit mode (plugin context). Never runs in published servers.
local Launcher = {}
function Launcher.run()
	assert(game:GetService("RunService"):IsStudio() and not game:GetService("RunService"):IsRunning())
	local existing = game.ServerStorage:FindFirstChild("GlassClashQAResult")
	if existing and not existing:GetAttribute("Complete") then
		return "A QA run is already active"
	end
	local output = existing or Instance.new("StringValue")
	output.Name = "GlassClashQAResult"
	output.Value = ""
	output:SetAttribute("Complete", false)
	output.Parent = game.ServerStorage
	task.spawn(function()
		local ok, result = pcall(function()
			return game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(2, { Name = "GlassClashQA" })
		end)
		output.Value = game:GetService("HttpService"):JSONEncode({ Launched = ok, Result = result })
		output:SetAttribute("Complete", true)
		print("[GlassClash QA] " .. output.Value)
	end)
	return "Starting two native simulated clients; result appears in ServerStorage.GlassClashQAResult"
end
function Launcher.combat()
	assert(game:GetService("RunService"):IsStudio() and not game:GetService("RunService"):IsRunning())
	local output = game.ServerStorage:FindFirstChild("CombatReleaseQAResult") or Instance.new("StringValue")
	assert(output:GetAttribute("Running") ~= true, "Combat QA already running")
	output.Name, output.Value, output.Parent = "CombatReleaseQAResult", "", game.ServerStorage
	output:SetAttribute("Running", true)
	task.spawn(function()
		local ok, result = pcall(function()
			return game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(2, { Name = "GlassClashCombatQA" })
		end)
		output.Value = game:GetService("HttpService"):JSONEncode({ Launched = ok, Result = result })
		output:SetAttribute("Running", false)
	end)
	return "Focused two-client combat QA started"
end
return Launcher
