-- Focused Client Play checks; no purchases or changes to saved profiles.
local client = game.Players.LocalPlayer.PlayerScripts.Client
local ui, RS = client.UI, game.ReplicatedStorage
local Crate = require(ui.Components.CrateShopPanel)
local Rules = require(RS.Shared.CrateRules)
local checks = 0
local function check(value, message)
	assert(value, message)
	checks += 1
end
local gui = Instance.new("ScreenGui")
gui.Name, gui.Parent = "CrateUIFixture", game.Players.LocalPlayer.PlayerGui
local host = Instance.new("Frame")
host.Size, host.Position = UDim2.fromOffset(800, 400), UDim2.fromOffset(3000, 0)
host.Parent = gui
local function offer(currency)
	return {
		Odds = Rules.odds("Finishers", currency),
		Cost = Rules.cost("Finishers", currency, 1),
		TenCost = Rules.cost("Finishers", currency, 10),
	}
end
local noop = function() end
local callbacks = { Open = noop, Inspect = noop, ViewAll = noop }
local view = Crate.new(host, "Finishers", { Coins = offer("Coins"), Marbles = offer("Marbles") }, callbacks)
task.wait(0.1)
check(not view.Root.ScrollingEnabled, "Desktop panes unexpectedly scroll")
for _, pane in view.Panels do
	for _, button in pane.Buttons do
		check(button:GetAttribute("StainedGlass"), "Purchase button does not use native theme")
		check(button.AbsoluteSize.X >= 44 and button.AbsoluteSize.Y >= 44, "Purchase target too small")
		check(button.Active and button.Visible, "Low-wallet purchase action hidden")
	end
end
for _, carousel in view.Carousels do
	check(carousel.Root:IsA("Frame") and not carousel.Root:IsA("ScrollingFrame"), "Prize strip allows manual scrolling")
	local slot = carousel.Slots[1]
	local world = slot.Object.Portrait:FindFirstChildOfClass("WorldModel")
	carousel:Step(0.01)
	check(slot.Object.Portrait:FindFirstChildOfClass("WorldModel") == world, "Models rebuilt every frame")
	carousel:Step(1000)
	check(carousel.Offset >= 0 and carousel.Offset < #carousel.Odds, "Carousel failed to wrap")
	for _, s in carousel.Slots do
		check(s.Object.AnchorPoint == Vector2.new(0.5, 0.5), "Card origin disagrees with interaction animation")
		check(s.Object.Artwork.ScaleType == Enum.ScaleType.Stretch, "Card background does not fit its label")
		check(s.Object.Portrait.CurrentCamera ~= nil, "Missing item camera")
		check(s.Object.NamePlaque.AnchorPoint == Vector2.new(0.5, 0.5), "Nameplate misplaced")
	end
	carousel.Offset = 0
	carousel:Step(0)
	check(carousel.Slots[1].Entry.Id == carousel.Odds[1].Id, "Wrap reset skipped first item")
end
host.Size = UDim2.fromOffset(400, 600)
task.wait(0.1)
check(view.Root.ScrollingEnabled and view.Root.CanvasSize.Y.Offset > 600, "Narrow panes do not stack")
for _, pane in view.Panels do
	for _, b in pane.Buttons do
		check(b.AbsoluteSize.Y >= 44, "Narrow target too small")
	end
end
view:Destroy()
-- Baked premium panes must also disappear, not just dynamically created ones.
local page = game.StarterGui.KilnScreen.Panel.Content.FinishersPage:Clone()
page.Size, page.Parent = UDim2.fromScale(1, 1), host
local restricted = Crate.new(page, "Finishers", { Coins = offer("Coins") }, callbacks)
check(not restricted.Root.MarblesCrate.Visible, "Baked premium panel visible to restricted account")
check(restricted.Root.CoinsCrate.Visible, "Coin panel hidden for restricted account")
restricted:Destroy()
gui:Destroy()
return { Passed = checks, Failed = 0, Fixture = "Layout/theme/wrap/reuse/narrow/policy", DeviceEmulator = false }
