-- Play/Client (Studio MCP execute_luau). Decision 95 inventory check with an isolated profile (no server calls):
-- "Basic Shatter" is listed first among owned finishers, always owned, equipped when nothing is, previews its
-- plain glass break, and stops being equipped once a real finisher is. Leaves the screen open for a screenshot
-- when _G.KeepBasicShatterScreen is true (destroy it with _G.BasicShatterScreen:Destroy()).
local RS = game.ReplicatedStorage
local Shows = require(RS.Shared.Config.FinisherShows)
local profile = {
	Glassies = { pop = { Count = 1, Stars = 0, Rainbow = false } },
	Stats = {},
	Cosmetics = {
		Rideables = {},
		Finishers = { "frost_pop", "gumball" },
		EquippedRideables = "",
		EquippedFinishers = "",
	},
}
require(RS.Shared.RoundCosmeticRules).reconcile(profile)
local client = game.Players.LocalPlayer.PlayerScripts.Client
local screen = require(client.UI.Screens.InventoryScreen).new(profile, function() end)
local checks, results = 0, {}
local function check(value, message)
	assert(value, message)
	checks += 1
end
local ok, problem = pcall(function()
	task.wait()
	screen:SelectTab("Finishers")
	task.wait()
	local view = screen.CosmeticView
	local tile = view.Tiles[Shows.BasicId]
	check(tile ~= nil, "Basic Shatter tile exists")
	check(tile.Parent == view.Grid.Tiles, "Basic Shatter sits with owned finishers")
	check(tile.LayoutOrder == 1, "Basic Shatter is listed first")
	check(tile.Equipped.Visible, "Basic Shatter shows as equipped when nothing is")
	view:Detail(Shows.BasicId)
	task.wait()
	check(view.Owned and view.Equipped, "Basic Shatter is owned and equipped")
	check(view.Status.Text:find("ALWAYS YOURS", 1, true), "Always-owned status")
	check(not view.Equip.Active, "Equipped default cannot be unequipped")
	check(#view.World:GetDescendants() > 5, "Basic Shatter portrait still built")
	local effect = view:PreviewSelected()
	check(typeof(effect) == "Instance" and effect.Parent == view.World, "Preview plays")
	results.Preview = effect.Name
	-- Equipping a real finisher moves the badge off Basic Shatter.
	profile.Cosmetics.EquippedFinishers = "frost_pop"
	screen:Refresh(profile)
	task.wait()
	view = screen.CosmeticView
	check(not view.Tiles[Shows.BasicId].Equipped.Visible, "Basic Shatter no longer equipped")
	check(view.Tiles.frost_pop.Equipped.Visible, "Frost Pop now equipped")
	view:Detail(Shows.BasicId)
	check(view.Equip.Active, "Basic Shatter can be equipped again")
	results.Status = view.Status.Text
end)
if _G.KeepBasicShatterScreen and ok then
	profile.Cosmetics.EquippedFinishers = ""
	screen:Refresh(profile)
	screen.CosmeticView:Detail(Shows.BasicId)
	_G.BasicShatterScreen = screen
else
	screen:Destroy()
end
assert(ok, problem)
return { Checks = checks, Preview = results.Preview, Status = results.Status }
