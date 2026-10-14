-- Run once in Edit mode. Never overwrites existing ScreenGuis or the creator's edits.
assert(not game:GetService("RunService"):IsRunning(), "Install UI in Edit mode")
local starter = game:GetService("StarterGui")
local names = {
	"LobbyHUD",
	"QueuePanel",
	"RollScreen",
	"RollInfoScreen",
	"ResultsScreen",
	"CollectionScreen",
	"IndexScreen",
	"GlassyDetailScreen",
	"KilnScreen",
	"KilnRevealScreen",
	"FightHud",
	"RoundEnd",
	"MatchNotice",
}
for _, name in names do
	if starter:FindFirstChild(name) then
		return { Skipped = true, Reason = "UI already exists; preserve manual edits", Existing = name }
	end
end
-- A fresh clone avoids the command runner's ModuleScript cache. Sources remain Rojo-managed.
local ui = game.StarterPlayer.StarterPlayerScripts.Client.UI:Clone()
ui.Name = "GlassClashUITemplateBuild"
ui.Parent = game.ServerStorage
local U = require(ui.Components.Util)
local Theme = require(ui.Theme)
local Screens = require(ui.Screens.MatchScreens)
local Collection = require(ui.Screens.CollectionScreen)
local Kiln = require(ui.Screens.KilnScreen)
local Hud = require(ui.Screens.FightHud)
local profile = { Coins = 300, Trophies = 0, Stats = { GlassyUses = {} }, Glassies = {
	pop = { Stars = 0 },
	jam = { Stars = 0 },
	prism = { Stars = 0 },
} }
local ids = { "pop", "jam", "prism" }
local data = {
	Round = 2,
	MatchId = "layout",
	Deadline = workspace:GetServerTimeNow() + 15,
	Names = { "YOU", "RIVAL" },
	PlayerIds = { 0, -1 },
	LastPicks = { "pop", "jam" },
}
local function prototype(parent, object, name)
	local folder = parent:FindFirstChild("Templates") or Instance.new("Folder")
	folder.Name, folder.Parent = "Templates", parent
	local copy = object:Clone()
	copy.Name, copy.Parent = name, folder
	if copy:IsA("GuiObject") then
		copy.Visible = false
	end
end
local function disconnect(window)
	for _, connection in window and window.Connections or {} do
		connection:Disconnect()
	end
end
require(ui.Screens.LobbyHud).new(function() end)
local queue = Screens.queue(data, function() end)
queue:Render(workspace:GetServerTimeNow())
local roll = Screens.roll(data, function() end, function() end)
roll:Offers({ Offers = ids, Collection = profile.Glassies, CanReroll = true })
roll:Render(workspace:GetServerTimeNow())
roll:PowerInfo("pop")
local history = {}
for i = 1, 5 do
	history[i] = { Winner = if i % 2 == 1 then 1 else 2, Picks = { ids[(i - 1) % 3 + 1], ids[i % 3 + 1] } }
end
local results = Screens.results(
	{ Side = 1, Won = true, Saved = true, Rewards = { Coins = 36, Trophies = 5 }, History = history },
	function() end,
	function() end
)
results:Render(workspace:GetServerTimeNow() + 1)
prototype(results.Gui.Results.History, results.Gui.Results.History.Round1_1, "RoundPortrait")
for _, index in { false, true } do
	local collection = Collection.new(index, profile, function() end)
	prototype(collection.Grid, collection.Tiles[1], "GlassyTile")
	if not index then
		collection:Detail("pop")
		disconnect(collection.DetailWindow)
	end
	collection.Window.Gui.Enabled = true
	collection.Resize:Disconnect()
	disconnect(collection.Window)
end
local kiln = Kiln.new(
	{ Quote = "layout", Odds = { { Id = "milk_bottle", Chance = 1, Rarity = "Common" } }, Coins = 300, Welcome = 0, Cost = 300, TenCost = 2700 },
	function() end,
	function() end,
	function() end
)
prototype(kiln.Window.Content.Odds, kiln.Window.Content.Odds.Rows.milk_bottle, "OddsRow")
local odds = kiln.Window.Gui:Clone()
kiln:Result({ Results = { { Id = "pop", Duplicate = true, Stars = 1, Rainbow = false, BonusCoins = 0 } } })
task.wait(0.85)
odds.Parent = starter
local fight = Hud.new(
	{ Id = "layout", A = { Id = "pop" }, B = { Id = "jam" }, PlayerIds = { 0, -1 }, SweetSpot = 1, Hearts = { 3, 3 } },
	{ 112, 114 },
	function() end
)
fight:Phase("Aiming", "PULL BACK")
fight:Aim(1, 0, false)
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "Templates", fight.Gui
local popup = U.text(folder, "Popup", "24", UDim2.fromScale(0.2, 0.12), UDim2.fromScale(0.4, 0.4), Theme.Fonts.PopUp)
popup.Visible = false
local notice = U.screen("MatchNotice", 30)
U.text(notice, "Notice", "Notice placeholder", UDim2.fromScale(0.8, 0.1), UDim2.fromScale(0.1, 0.75), Theme.Fonts.Body)
local round = U.screen("RoundEnd", 15)
U.text(round, "Round", "ROUND 2 → YOU", UDim2.fromScale(0.6, 0.08), UDim2.fromScale(0.2, 0.83), Theme.Fonts.Heading)
for _, name in names do
	local gui = starter:FindFirstChild(name)
	assert(gui, "Missing UI " .. name)
	gui.Enabled = false
	gui:SetAttribute("LayoutVersion", 3)
	gui:SetAttribute("EditHint", "Enable this ScreenGui to edit; keep names and Templates folders")
	for _, object in gui:GetDescendants() do
		if object:IsA("ViewportFrame") then
			for _, child in object:GetChildren() do
				if child:IsA("WorldModel") or child:IsA("Camera") then
					child:Destroy()
				end
			end
			local placeholder =
				U.text(object, "Placeholder", "IMAGE", UDim2.fromScale(1, 1), UDim2.new(), Theme.Fonts.Caption)
			placeholder.TextColor3 = Theme.Colors.TextMuted
		end
		if object:IsA("GuiObject") then
			assert(
				object.Size.X.Offset == 0
					and object.Size.Y.Offset == 0
					and object.Position.X.Offset == 0
					and object.Position.Y.Offset == 0,
				"Offset layout: " .. object:GetFullName()
			)
		end
	end
end
disconnect(queue)
disconnect(roll)
disconnect(results)
disconnect(roll.Info)
disconnect(kiln.Window)
fight.LockConnection:Disconnect()
ui:Destroy()
return { Created = names, ScaleOnly = true, Source = "tools/studio/install_ui_templates.luau" }
