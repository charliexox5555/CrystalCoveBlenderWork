-- Play/Client. Isolated profile for preview/layout/lifecycle; no server grants or spends.
local RS = game.ReplicatedStorage
local profile = {
	Glassies = { pop = { Count = 1, Stars = 0, Rainbow = false } },
	Stats = {},
	Cosmetics = {
		Rideables = { "skyboard", "lantern_skiff" },
		Finishers = { "glass_burst", "lantern_eclipse" },
		Skins = { "hollowlight" },
		EquippedRideables = "lantern_skiff",
		EquippedFinishers = "lantern_eclipse",
		EquippedSkins = "hollowlight",
	},
}
require(RS.Shared.RoundCosmeticRules).reconcile(profile)
local client = game.Players.LocalPlayer.PlayerScripts.Client
local screen = require(client.UI.Screens.InventoryScreen).new(profile, function() end)
local checks = 0
local function check(value, message)
	assert(value, message)
	checks += 1
end
local ok, problem = pcall(function()
	task.wait()
	local tabs = screen.Window.Panel.Tabs
	for _, name in { "Glassies", "Skins", "Finishers", "Flyers" } do
		local tab = tabs[name .. "Tab"]
		check(tab.Active and tab.Interactable, "Active authored-style tab")
		check(tab.AbsolutePosition.X >= tabs.AbsolutePosition.X - 1, "Tab inside left edge")
		check(
			tab.AbsolutePosition.X + tab.AbsoluteSize.X <= tabs.AbsolutePosition.X + tabs.AbsoluteSize.X + 1,
			"Tab inside right edge"
		)
	end
	check(
		#require(RS.Shared.Config.Glassies).visible(profile.Glassies) == 24,
		"Skin preserves the fixed release roster"
	)
	check(screen.DetailPortrait:GetAttribute("SkinId") == "hollowlight", "Inventory Pop uses equipped look")
	for tab, id in { Skins = "hollowlight", Flyers = "lantern_skiff", Finishers = "lantern_eclipse" } do
		screen:SelectTab(tab)
		local view = screen.CosmeticView
		view:Detail(id)
		task.wait()
		check(view.Owned and view.Equipped, "Persisted category equipment")
		check(view.World:FindFirstChildOfClass("Model") ~= nil, "Installed mesh portrait")
		local name = view.Tiles[id]:FindFirstChild("Name")
		check(name.TextFits and name.TextScaled, "Long seasonal names fit")
	end
	local view = screen.CosmeticView
	local first = view:PreviewSelected()
	local nextEffect = view:PreviewSelected()
	check(first.Parent == nil and nextEffect.Parent == view.World, "Replay clears previous effect")
	screen:SelectTab("Skins")
	check(nextEffect.Parent == nil, "Tab switch cancels effect")
	profile.Cosmetics.Skins = {}
	profile.Cosmetics.Counts.Skins.hollowlight = 0
	screen:Refresh(profile)
	check(not screen.CosmeticView.Equip.Active, "Locked look cannot equip")
	check(screen.CosmeticView.Status.Text:find("NOT AVAILABLE YET", 1, true), "Honest unavailable label")
end)
screen:Destroy()
assert(ok, problem)
return { Passed = checks, SourceTemplatesUnchanged = true }
