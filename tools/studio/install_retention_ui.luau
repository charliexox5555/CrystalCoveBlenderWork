-- Add only the new rewards template/control; preserve every existing authored UI element.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before UI installation")
local starter = game:GetService("StarterGui")
if starter:FindFirstChild("RewardsScreen") then
	return { Skipped = true, Reason = "Rewards UI already exists" }
end
local ui = game.StarterPlayer.StarterPlayerScripts.Client.UI:Clone()
ui.Name = "RetentionUIBuild"
ui.Parent = game.ServerStorage
local content = require(game.ReplicatedStorage.Shared.Config.Retention)
local balance = require(game.ReplicatedStorage.Shared.Config.Balance)
local quests, gifts = {}, {}
for _, q in content.Quests do
	table.insert(
		quests,
		{ Id = q.Id, Name = q.Name, Goal = q.Goal, Progress = 0, Claimed = false, Coins = balance.Economy.DailyQuestCoins }
	)
end
for i, g in balance.Economy.PlaytimeGifts do
	table.insert(gifts, { Id = i, Seconds = g.Minutes * 60, Coins = g.Coins, Claimed = false })
end
local screen = require(ui.Screens.RewardsScreen).new(
	{ Retention = { Quests = quests, Gifts = gifts, Streak = 1, PlaytimeSeconds = 0 } },
	function() end,
	function() end,
	function() end
)
screen.Window.Gui.Enabled = false
screen.Window.Gui:SetAttribute("LayoutVersion", 3)
for _, c in screen.Window.Connections do
	c:Disconnect()
end
local U = require(ui.Components.Util)
local Button = require(ui.Components.Button)
local lobby = starter:FindFirstChild("LobbyHUD")
if lobby and not lobby:FindFirstChild("Rewards") then
	local button =
		Button.new(lobby, "Rewards", "REWARDS", "Yellow", UDim2.fromScale(0.2, 0.1), UDim2.fromScale(0.78, 0.13))
	U.make("UISizeConstraint", button, { MinSize = Vector2.new(44, 44) })
end
ui:Destroy()
return { Added = "StarterGui.RewardsScreen", Tabs = { "Quests", "Gifts", "Streak", "Codes" } }
