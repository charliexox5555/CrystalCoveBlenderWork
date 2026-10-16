-- Client-only, isolated presentation checks; no remotes or purchases are issued.
assert(game:GetService("RunService"):IsClient(), "Run in Play Client")
local player = game.Players.LocalPlayer
player.PlayerScripts.LobbyClientDev:Invoke("Close")
local modules = player.PlayerScripts.Client.UI:Clone()
modules.Name, modules.Parent = "OpeningQA", player.PlayerScripts
local Screen = require(modules.Screens.KilnScreen)
local Formula = require(game.ReplicatedStorage.Shared.Formula)
local available = {}
for _, model in game.ReplicatedStorage.Assets.Glassies:GetChildren() do
	available[model.Name] = true
end
local odds = Formula.kilnOdds(available)
local data = { Odds = odds, Coins = 10000, Marbles = 0, Welcome = 0, Cost = 300, TenCost = 2700, Quote = "QA" }
local checks = 0
local function check(value, message)
	assert(value, message)
	checks += 1
end
local function fixture(count)
	local results = {}
	for i = 1, count do
		table.insert(results, {
			Id = odds[(i - 1) % #odds + 1].Id,
			Duplicate = i % 2 == 0,
			Stars = 1,
			Rainbow = i == 3,
			BonusCoins = if i == 6 then 20 else 0,
		})
	end
	return { Results = results, Quote = "QA" .. count }
end
local function create(count)
	local completed = 0
	local screen = Screen.new(data, function()
		completed += 1
	end, function()
		error("UI attempted purchase")
	end, function() end, "Glassies")
	screen.QACompletions = function()
		return completed
	end
	screen:Pending()
	check(not player.PlayerGui:FindFirstChild("KilnScreen"), "Shop must close on open, before server response")
	check(screen.Window.Content.Status.Text == "WARMING THE KILN…", "Pending UI")
	screen:Result(fixture(count))
	return screen
end
local function verifyCards(screen, count)
	task.wait(0.2)
	local c = screen.Window.Content
	check(screen.Window.Gui:GetAttribute("RevealedCount") == count, "Every reward revealed")
	check(c.Collect.Visible and not c.Skip.Visible, "Result controls")
	for i, result in screen.Results do
		local card = c.Rewards["Reward" .. i]
		check(card.Visible and card:GetAttribute("GlassyId") == result.Id, "Card matches awarded result " .. i)
		check(card.Portrait:GetAttribute("GlassyId") == result.Id, "Portrait matches result " .. i)
		check(
			(
				(card.AbsolutePosition + card.AbsoluteSize / 2)
				- (card.Artwork.AbsolutePosition + card.Artwork.AbsoluteSize / 2)
			).Magnitude < 1,
			"Centered artwork " .. i
		)
		check(math.abs(card.AbsoluteSize.X / card.AbsoluteSize.Y - 5 / 6) < 0.01, "Card proportions " .. i)
		for _, label in { card.Rarity, card.NameLabel, card.RewardLabel, card.BonusLabel } do
			check(label.TextFits, "Label clipping: " .. label:GetFullName())
		end
		for _, part in card.Portrait.WorldModel:GetChildren() do
			if part:IsA("BasePart") then
				check(
					part:GetPivot().UpVector:Dot(Vector3.yAxis) > 0.99999
						and part:GetPivot().RightVector:Dot(Vector3.xAxis) > 0.99999,
					"Upright glass portrait pivot"
				)
			end
		end
	end
	if count == 1 then
		local card = c.Rewards.Reward1
		check(
			(
				(card.AbsolutePosition + card.AbsoluteSize / 2)
				- (screen.Window.Gui.AbsolutePosition + screen.Window.Gui.AbsoluteSize / 2)
			).Magnitude < 1,
			"Hero card centered on screen"
		)
	end
end
for _, count in { 1, 10 } do
	local screen = create(count)
	task.wait(0.1)
	screen:Step(7)
	for i, result in screen.Results do
		check(screen.Opening.Reels.Rows[i].Frame:GetAttribute("SelectedId") == result.Id, "Exact reel landing")
	end
	screen:Step(1)
	check(screen.Opening.FireCount == 1, "One firing per batch")
	screen:Step(1)
	screen:Step(1)
	screen:Step(2)
	verifyCards(screen, count)
	local opening = screen.Opening
	screen:Result(fixture(count))
	check(screen.Opening == opening, "Duplicate result doesn't restart opening")
	check(screen.Window.Panel.BackgroundTransparency == 1, "Transparent opening overlay")
	check(not screen.Window.Gui:FindFirstChild("Backdrop"), "No full-screen backdrop")
	check(not player.PlayerGui.LobbyHUD.PlayButton.Visible, "Play doesn't overlap Collect")
	check(player.PlayerGui.LobbyHUD.Enabled, "Inventory destination visible")
	opening:Collect()
	check(opening.Phase == "Collect" and not screen.Window.Content.Collect.Visible, "Collect starts once")
	for frame = 1, 90 do
		screen:Step(1 / 60)
	end
	check(opening.ArrivalCount == count, "Every glassy reaches Inventory")
	check(screen.QACompletions() == 1, "Collection completion occurs once")
	opening:Collect()
	screen:Step(1)
	check(screen.QACompletions() == 1, "Repeated collect doesn't repeat completion")
	local target = opening.Target.AbsolutePosition + opening.Target.AbsoluteSize / 2
	task.wait(0.05)
	for _, item in opening.Cards do
		check(not item.Object.Visible, "Arrived glassy hidden")
		check(
			((item.Object.AbsolutePosition + item.Object.AbsoluteSize / 2) - target).Magnitude < 1,
			"Glassy lands on Inventory button"
		)
	end
	screen:Destroy()
	check(not game.SoundService:FindFirstChild("KilnOpeningAudio"), "Audio cleaned on close")
	for _, phase in { "Reels", "Landed", "Fire", "Launch" } do
		local skipped = create(count)
		task.wait(0.05)
		if phase ~= "Reels" then
			skipped:Step(7)
		end
		if phase == "Fire" or phase == "Launch" then
			skipped:Step(1)
		end
		if phase == "Launch" then
			skipped:Step(2)
		end
		skipped.Opening:Skip()
		verifyCards(skipped, count)
		skipped:Destroy()
		check(not game.SoundService:FindFirstChild("KilnOpeningAudio"), "Skip cleanup")
	end
	for _, phase in { "Reels", "Fire", "Collect" } do
		local interrupted = create(count)
		task.wait(0.05)
		if phase == "Fire" then
			interrupted:Step(7)
			interrupted:Step(1)
		end
		if phase == "Collect" then
			interrupted.Opening:Skip()
			interrupted.Opening:Collect()
			interrupted:Step(0.2)
		end
		local owner = interrupted.Opening
		interrupted:Destroy()
		check(
			owner.Dead and not game.SoundService:FindFirstChild("KilnOpeningAudio"),
			"Cleanup on interrupted " .. phase
		)
		check(player.PlayerGui.LobbyHUD.PlayButton.Visible, "HUD restored after interrupted " .. phase)
	end
end
local failed = Screen.new(data, function() end, function() end, function() end, "Glassies")
failed:Pending()
failed:Result({ Error = "Test rejection" })
check(
	failed.Window.Gui.Name == "KilnScreen" and failed.Message.Text == "Test rejection",
	"Rejected pull returns to Shop with error"
)
failed:Destroy()
modules:Destroy()
return { Checks = checks, Passed = true, Purchases = 0 }
