-- Native Client presentation checks; fixtures never grant items or issue remotes.
assert(game:GetService("RunService"):IsClient(), "Run in Play Client")
local player = game.Players.LocalPlayer
player.PlayerScripts.LobbyClientDev:Invoke("Close")
local modules = player.PlayerScripts.Client.UI:Clone()
modules.Name, modules.Parent = "InventoryQA", player.PlayerScripts
local Inventory = require(modules.Screens.InventoryScreen)
local Glassies = require(game.ReplicatedStorage.Shared.Config.Glassies)
local Powers = require(game.ReplicatedStorage.Shared.Config.Powers)
local Formula = require(game.ReplicatedStorage.Shared.Formula)
local checks = 0
local function check(value, message)
	assert(value, message)
	checks += 1
end
local function profile(count)
	local data = { Glassies = {} }
	for i = 1, count do
		data.Glassies[Glassies.List[i].Id] = { Count = 1, Stars = 0, Rainbow = false }
	end
	return data
end
for _, count in { 0, 3, #Glassies.List } do
	local data = profile(count)
	local screen = Inventory.new(data, function() end)
	task.wait(0.25)
	local grid = screen.Grid
	check(#screen.Tiles == #Glassies.List, "Complete catalog")
	check(grid:GetAttribute("OwnedCount") == count, "Owned count")
	check(grid:GetAttribute("UnownedCount") == #Glassies.List - count, "Unowned count")
	check(grid.OwnedEmpty.Visible == (count == 0), "Empty collection state")
	check(grid.UnownedEmpty.Visible == (count == #Glassies.List), "Complete collection state")
	check(not screen.Info:FindFirstChild("Stars"), "Preserve creator's removed stars")
	check(
		grid.UnownedHeader.AbsolutePosition.Y >= grid.Tiles.AbsolutePosition.Y + grid.Tiles.AbsoluteSize.Y - 1,
		"Unowned follows Owned"
	)
	local seen = {}
	for _, tile in screen.Tiles do
		check(not seen[tile.Name], "No duplicate catalog entry")
		seen[tile.Name] = true
		local owned = data.Glassies[tile.Name] ~= nil
		check(tile.Parent == (if owned then grid.Tiles else grid.UnownedTiles), "Correct section")
		check(tile:GetAttribute("Unowned") == not owned, "Ownership state")
		check(tile.Open.AnchorPoint == Vector2.new(0.5, 0.5), "Centered button anchor")
		check(tile:FindFirstChild("Name").TextFits, "Tile name fits")
		if game.ReplicatedStorage.Assets.Glassies:FindFirstChild(tile.Name) then
			check(tile.Portrait.Visible and not tile.Unknown.Visible, "Installed portrait")
			check((tile.Portrait.ImageColor3 == Color3.new(1, 1, 1)) == owned, "Missing portrait is dimmed")
		else
			check(not tile.Portrait.Visible and tile.Unknown.Visible, "Missing art uses honest placeholder")
		end
	end
	for _, def in Glassies.List do
		screen:Detail(def.Id)
		task.wait(0.03)
		local p = screen.Info
		local owned = data.Glassies[def.Id]
		check(p.InfoName.Text == def.Name, "Unowned details selectable")
		check(p.Ownership.Text:find(if owned then "OWNED" else "UNOWNED", 1, true) == 1, "Detail ownership")
		check(p.PassiveDescription.Text == Powers.passive(def.Passive).Description, "Passive details")
		check(p.PowerDescription.Text == Powers.special(def.Special).Description, "Power details")
		check(p.HPAmount.Text == tostring(Formula.stats(def, owned).HP), "Base/owned stats")
		for _, label in p:GetChildren() do
			if label:IsA("TextLabel") and label.Visible then
				check(label.TextFits, "Detail label fits: " .. def.Id .. "/" .. label.Name)
			end
		end
	end
	if count == 3 then
		screen:Detail("milk_bottle")
		screen:Refresh(data)
		check(screen.Selected == "milk_bottle", "Missing selection survives unrelated refresh")
		data.Glassies.milk_bottle = { Count = 1, Stars = 0, Rainbow = false }
		screen:Refresh(data)
		task.wait(0.15)
		check(
			grid:GetAttribute("OwnedCount") == 4 and grid:GetAttribute("UnownedCount") == 27,
			"New item migrates sections"
		)
		check(
			grid.Tiles:FindFirstChild("milk_bottle") and not grid.UnownedTiles:FindFirstChild("milk_bottle"),
			"Item appears exactly once after acquisition"
		)
		check(
			grid.Tiles.milk_bottle.Portrait.ImageColor3 == Color3.new(1, 1, 1),
			"Acquired portrait restores full color"
		)
		check(
			screen.Selected == "milk_bottle" and screen.Info.Ownership.Text == "OWNED • x1",
			"Selected detail updates after acquisition"
		)
		for i = 1, 5 do
			screen:Refresh(data)
		end
		check(
			#screen.TileConnections == #Glassies.List and #screen.Tiles == #Glassies.List,
			"Refresh doesn't accumulate tiles or handlers"
		)
	end
	screen:Destroy()
	check(not player.PlayerGui:FindFirstChild("CollectionScreen"), "Close removes inventory")
end
modules:Destroy()
return { Passed = true, Checks = checks, Catalog = #Glassies.List, Fixtures = "empty / partial / complete / acquired" }
