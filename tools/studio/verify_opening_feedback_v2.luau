-- Focused regression: all three categories, camera stability and exact launch coordinates.
local player = game.Players.LocalPlayer
player.PlayerScripts.LobbyClientDev:Invoke("Close")
local Screen = require(player.PlayerScripts.Client.UI.Screens.KilnScreen)
local K = require(player.PlayerScripts.Client.UI.Theme).Kiln
local checks = 0
local function check(ok, message)
	assert(ok, message)
	checks += 1
end
local data = {
	Odds = { { Id = "pop", Rarity = "Starter", Chance = 1 } },
	Cost = 300,
	TenCost = 2700,
	Coins = 0,
	Marbles = 0,
	Quote = "fixture",
}
for category, id in { Glassies = "pop", Finishers = "starfall", Rideables = "prism_ray" } do
	for _, count in { 1, 10 } do
		local results = {}
		for i = 1, count do
			table.insert(results, { Id = id, Count = i, Duplicate = i > 1 })
		end
		local s = Screen.new(data, function() end, function()
			error("No fixture purchases")
		end, function() end)
		s:Pending(category)
		s:Result({ Category = category, Results = results, Odds = { { Id = id, Chance = 1 } } })
		task.wait(0.1)
		s:Step(7)
		s:Step(K.LandHold)
		local o = s.Opening
		check(o.FireCount == 1, "Expected one category firing")
		local camera = o.FireFX.View.CurrentCamera.CFrame
		s:Step(K.ChargeSeconds + 0.1)
		task.wait(0.05)
		check(
			(o.FireFX.View.CurrentCamera.CFrame.Position - camera.Position).Magnitude < 0.001,
			"Animated lid moved the camera"
		)
		check(o.FireFX.Puff.ImageRectSize == Vector2.new(128, 128), "Wrong 512px/4x4 pressure atlas crop")
		s:Step(K.FireSeconds)
		task.wait(0.05)
		o:LaunchStep(0)
		task.wait(0.05)
		local first = o.Cards[1].Object
		check(
			(first.AbsolutePosition + first.AbsoluteSize / 2 - o.FireFX:Pixel()).Magnitude < 2,
			"Item launched outside the real mouth"
		)
		o:Skip()
		for _, item in o.Cards do
			check(
				item.Object.Rotation == 0 and item.Object.Artwork.ImageTransparency == 0,
				"Skip left a tilted/transparent reward"
			)
		end
		s:Destroy()
		check(not game.SoundService:FindFirstChild("KilnOpeningAudio"), "Opening leaked sound")
	end
end
return { Checks = checks, Passed = true, Purchases = 0 }
