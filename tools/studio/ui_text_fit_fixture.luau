-- Workstream J: drives every lobby/shop/match screen state in Studio Play (Client) for the text-fit scan.
-- Needs _G.TFScan (tools/studio/ui_text_fit_scan.luau loaded first). Studio only; no purchases, no
-- remotes beyond the LobbyClientDev / UIPreview fixtures (PreviewKiln shows a local fake opening).
-- Usage: _G.TFStates = <this file>; task.spawn(_G.TFStates.all, store, stress), then read `store`.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local pg = player.PlayerGui
local scripts = player.PlayerScripts
local dev = scripts:WaitForChild("LobbyClientDev")
local ui = scripts.Client.UI
local Glassies = require(game.ReplicatedStorage.Shared.Config.Glassies)

local LONG_NAME, LONG_POWER = "", ""
for _, def in Glassies.List do
	if #def.Name > #LONG_NAME then
		LONG_NAME = def.Name
	end
	if def.SpecialName and #def.SpecialName > #LONG_POWER then
		LONG_POWER = def.SpecialName
	end
end

local function settle(seconds)
	task.wait(seconds or 1.2)
end

local function enabled(name)
	local gui = pg:FindFirstChild(name)
	return gui and gui.Enabled and gui or nil
end

local States = {}
States.Order = {}
local steps = {}
local function state(name, open)
	table.insert(States.Order, name)
	steps[name] = open
end

state("LobbyHUD", function()
	dev:Invoke("Close")
	settle(0.6)
	return enabled("LobbyHUD")
end)
for _, tab in { "Featured", "Glassies", "Finishers", "Flyers", "Marbles" } do
	state("Shop." .. tab, function()
		if not enabled("KilnScreen") then
			dev:Invoke("Open", "Kiln")
			settle(2.5)
		end
		dev:Invoke("ShopTab", tab)
		settle(1.5)
		return enabled("KilnScreen")
	end)
end
state("Kiln.Reveal", function()
	dev:Invoke("PreviewKiln", 10) -- a local fake 10-pull opening; nothing is awarded
	settle(3)
	dev:Invoke("KilnSkip")
	settle(2)
	return enabled("KilnRevealScreen") or enabled("KilnScreen")
end)
for _, tab in { "Glassies", "Flyers", "Finishers" } do
	state("Inventory." .. tab, function()
		if not enabled("CollectionScreen") then
			dev:Invoke("Close")
			dev:Invoke("Open", "Glassies")
			settle(2.5)
		end
		dev:Invoke("ShopTab", tab)
		settle(1.2)
		return enabled("CollectionScreen")
	end)
end
state("Index", function()
	dev:Invoke("Close")
	dev:Invoke("Open", "Index")
	settle(2.5)
	return enabled("IndexScreen") or enabled("CollectionScreen")
end)
for _, tab in { "Quests", "Gifts", "Streak", "Codes" } do
	state("Rewards." .. tab, function()
		if not enabled("RewardsScreen") then
			dev:Invoke("Close")
			dev:Invoke("Open", "Rewards")
			settle(2)
		end
		dev:Invoke("RewardsTab", tab)
		settle(1)
		return enabled("RewardsScreen")
	end)
end
for _, kind in { "Queue", "Roll", "Results" } do
	state("Match." .. kind, function()
		dev:Invoke("PreviewMatch", kind)
		settle(2)
		return enabled(
			if kind == "Roll" then "RollScreen" elseif kind == "Queue" then "QueuePanel" else "ResultsScreen"
		)
	end)
end
state("Cast.LongPower", function()
	dev:Invoke("Close")
	local Cast = require(ui.Screens.CastButton)
	local cast = Cast.new(function() end)
	cast.Power.Text = LONG_POWER
	cast.Root.Visible = true
	States.Cast = cast
	settle(0.6)
	return cast.Gui
end)

-- Pads every string by 40% ("WWWW", about what a translation adds), scans, then puts the text back.
function States.stress(root)
	local saved = {}
	for _, l in root:GetDescendants() do
		if (l:IsA("TextLabel") or l:IsA("TextButton")) and l.Text ~= "" and not l.RichText and l.Text:match("%a") then
			saved[l] = l.Text
			l.Text = l.Text .. " " .. string.rep("W", math.ceil(#l.Text * 0.4))
		end
	end
	task.wait(0.5)
	local report = _G.TFScan({ Root = root, Phone = false })
	for l, t in saved do
		l.Text = t
	end
	return report
end

-- Opens a state and returns the scan text (stress: padded strings).
function States.run(name, stress)
	local ok, gui = pcall(steps[name])
	if not ok then
		return name .. ": ERROR " .. tostring(gui)
	end
	if not gui then
		return name .. ": no screen"
	end
	local report = if stress then States.stress(gui) else _G.TFScan({ Root = gui })
	return "== " .. name .. " (" .. gui.Name .. ")\n" .. report
end

-- Runs every state into `store` (call from task.spawn: a full pass takes longer than one MCP call).
function States.all(store, stress)
	for _, name in States.Order do
		store[name] = States.run(name, stress)
	end
	store.Done = true
end

States.LongName, States.LongPower = LONG_NAME, LONG_POWER
return States
