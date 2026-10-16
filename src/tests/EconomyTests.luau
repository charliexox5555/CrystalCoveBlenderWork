-- Economy targets (GAME_DESIGN 8.4). Uses EconomySim with fewer simulated players.

return function(t, deps)
	local Balance = deps.Balance
	local EconomySim = if script then require(script.Parent.EconomySim) else require("./EconomySim")

	t.test("expected rounds per match is between 3 and 5", function()
		t.between(EconomySim.expectedRounds(0.5), 3, 5, "even match")
		t.near(EconomySim.expectedRounds(1), Balance.Match.Hearts, 1e-9, "a sweep")
	end)

	t.test("full-timeout matches allow the creator's longer selection and aim windows", function()
		t.between(EconomySim.matchSeconds() / 60, 5, 7, "full-timeout match minutes; ready players advance early")
	end)

	t.test("collection pacing: quick first rares, a long chase for Mythics", function()
		local players = Balance.EconomyModel.Players
		Balance.EconomyModel.Players = 400
		local r = EconomySim.simulate(5)
		Balance.EconomyModel.Players = players
		t.ok(r.PullsDay1 >= 3, "at least 3 Kiln pulls on day 1, got " .. r.PullsDay1)
		t.ok(r.FirstMinutes.Rare <= 90, "first Rare within 90 minutes of play")
		t.ok(r.FirstMinutes.Epic <= 6 * 60, "first Epic within 6 hours of play")
		t.between(r.FirstMinutes.Legendary / 60, 4, 25, "first Legendary hours")
		t.ok(r.FirstShare.Mythic < 0.5, "Mythics stay rare in the first month")
		t.ok(r.UniqueDay30 < r.KilnGlassies, "nobody finishes the collection in a month")
	end)
end
