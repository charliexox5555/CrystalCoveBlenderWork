-- Add editable catalog content to existing Inventory/Shop without restyling authored layout.
assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local backups = game.ServerStorage:FindFirstChild("UIBackups")
assert(
	backups and not backups:FindFirstChild("BeforeRoundCosmetics_20261016"),
	"Backup already exists or missing UIBackups"
)
local backup = Instance.new("Folder")
backup.Name, backup.Parent = "BeforeRoundCosmetics_20261016", backups
for _, name in { "CollectionScreen", "KilnScreen" } do
	game.StarterGui[name]:Clone().Parent = backup
end
local Catalog = require(game.StarterPlayer.StarterPlayerScripts.Client.UI.Screens.CosmeticCatalog)
local profile = {
	Stats = { MatchWins = 0, MatchLosses = 0 },
	Cosmetics = {
		Rideables = { "skyboard" },
		Finishers = { "glass_burst" },
		EquippedRideables = "skyboard",
		EquippedFinishers = "glass_burst",
	},
}
local function install(parent, category, visible)
	local view = Catalog.new(parent, profile, category)
	for _, list in { view.Connections, view.TileConnections } do
		for _, connection in list do
			connection:Disconnect()
		end
	end
	view.Root.Visible = visible
	view.Root:SetAttribute("EditableCosmeticTemplate", true)
	return view.Root
end
install(game.StarterGui.CollectionScreen.Panel.Content, "Finishers", false)
for _, name in { "Finishers", "Flyers" } do
	local page = game.StarterGui.KilnScreen.Panel.Content[name .. "Page"]
	page.Preview.Visible = false
	install(page, if name == "Flyers" then "Rideables" else "Finishers", true)
end
return { InventoryTabs = 3, ShopCatalogs = 2, Backup = backup:GetFullName() }
