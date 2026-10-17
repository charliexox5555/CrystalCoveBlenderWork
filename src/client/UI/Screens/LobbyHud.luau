local U = require(script.Parent.Parent.Components.Util)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Hud = {}
function Hud.new(open)
	-- Wait for Roblox's initial StarterGui clone; creating one earlier duplicates the HUD.
	game.Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("LobbyHUD")
	local gui = U.screen("LobbyHUD", 5)
	local connections = {}
	for _, entry in { { "ShopButton", "Kiln" }, { "InventoryButton", "Glassies" } } do
		local button = gui.Navigation[entry[1]]
		table.insert(
			connections,
			button.Activated:Connect(function()
				open(entry[2])
			end)
		)
	end
	table.insert(
		connections,
		gui.PlayButton.Activated:Connect(function()
			if not gui.Parent:GetAttribute("Queued") then
				Remotes.JoinNearestArena:FireServer()
			end
		end)
	)
	-- "+" on the Marble counter opens the Marble shop.
	require(script.Parent.Parent.Components.MarbleShop).attachPlus(gui.Currency.Marbles)
	return {
		Gui = gui,
		Currency = gui.Currency.Coins.CoinsAmount,
		Marbles = gui.Currency.Marbles.MarblesAmount,
		Hint = gui.Hint,
		Connections = connections,
	}
end
return Hud
