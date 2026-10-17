-- Unit tests for MatchLogic (rolls, rerolls, picks, hearts, rewards, bots).

return function(t, deps)
	local Balance, MatchLogic, Glassies, Rng = deps.Balance, deps.MatchLogic, deps.Glassies, deps.Rng
	local B = Balance.Match
	t.test("uncompleted matches give neither side rewards; eligible rewards keep existing amounts", function()
		local match = MatchLogic.new({ { Collection = {} }, { Collection = {} } }, Rng.new(1))
		for _ = 1, 3 do
			MatchLogic.endRound(match, 1)
		end
		for side = 1, 2 do
			local denied = MatchLogic.rewards(match, side, 100, false)
			t.eq(denied.Coins, 0)
			t.eq(denied.Trophies, 0)
			local ordinary, eligible = MatchLogic.rewards(match, side, 100), MatchLogic.rewards(match, side, 100, true)
			t.eq(eligible.Coins, ordinary.Coins)
			t.eq(eligible.Trophies, ordinary.Trophies)
		end
	end)

	local function collection(ids: { string })
		local c = {}
		for _, id in ids do
			c[id] = {}
		end
		return c
	end

	local big = collection({ "pop", "jam", "prism", "milk_bottle", "pickle_jar", "glass_cup", "comet" })

	t.test("offers are distinct glassies from the player's collection", function()
		local rng = Rng.new(11)
		for _ = 1, 200 do
			local offers = MatchLogic.rollOffers(big, 3, rng)
			t.eq(#offers, 3, "three offers")
			local seen = {}
			for _, id in offers do
				t.ok(big[id] ~= nil, id .. " is owned")
				t.ok(not seen[id], "no repeats")
				seen[id] = true
			end
		end
	end)

	t.test("starters are always in the collection; small collections offer everything", function()
		local offers = MatchLogic.rollOffers({}, 3, Rng.new(1))
		t.eq(#offers, 3, "starters fill the roll")
		local ids = MatchLogic.ownedIds({ glass_cup = {} })
		t.eq(#ids, 4, "starters + 1")
		t.ok(table.find(MatchLogic.ownedIds({ not_a_glassy = {} }), "not_a_glassy") == nil, "unknown ids ignored")
	end)

	t.test("every owned glassy comes up about equally often", function()
		local rng, counts, n = Rng.new(21), {}, 6000
		for _ = 1, n do
			for _, id in MatchLogic.rollOffers(big, 3, rng) do
				counts[id] = (counts[id] or 0) + 1
			end
		end
		for id in big do
			t.near(counts[id] / n, 3 / 7, 0.03, id .. " offer rate")
		end
	end)

	t.test("rerolls always cost Marbles in pairs capped at nine", function()
		for used, cost in { 3, 3, 6, 6, 9, 9, 9 } do
			t.eq(MatchLogic.rerollCost(used - 1), cost)
		end
		local costs = B.RerollMarbleCosts
		t.eq(MatchLogic.rerollCost(B.FreeRerollsPerMatch), costs[1], "first paid")
		t.eq(MatchLogic.rerollCost(B.FreeRerollsPerMatch + 50), costs[#costs], "repeats")
	end)

	t.test("hand and counters survive rounds and new matches reset them", function()
		local m = MatchLogic.new({ { Collection = big }, { Collection = big } }, Rng.new(31))
		MatchLogic.startRound(m)
		local initial = table.concat(m.Sides[1].Offers, ",")
		MatchLogic.startRound(m)
		t.eq(table.concat(m.Sides[1].Offers, ","), initial)
		MatchLogic.reroll(m, 1)
		local changed = table.concat(m.Sides[1].Offers, ",")
		MatchLogic.startRound(m)
		t.eq(table.concat(m.Sides[1].Offers, ","), changed)
		t.eq(m.Sides[1].RerollsUsed, 1)
		t.eq(m.Sides[1].HandRevision, 1)
		local fresh = MatchLogic.new({ { Collection = big }, { Collection = big } }, Rng.new(31))
		t.eq(fresh.Sides[1].RerollsUsed, 0)
		t.eq(fresh.Sides[1].PickAnyUsed, 0)
	end)
	t.test("Pick Any selects one round without replacing the hand", function()
		local m = MatchLogic.new({ { Collection = big }, { Collection = big } }, Rng.new(32))
		MatchLogic.startRound(m)
		local before = table.concat(m.Sides[1].Offers, ",")
		local chosen
		for id in big do
			if not table.find(m.Sides[1].Offers, id) then
				chosen = id
				break
			end
		end
		t.ok(not MatchLogic.pickAny(m, 1, "glass_dragon"))
		t.eq(m.Sides[1].PickAnyUsed, 0)
		t.ok(MatchLogic.pickAny(m, 1, chosen))
		t.eq(m.Sides[1].Pick, chosen)
		t.eq(table.concat(m.Sides[1].Offers, ","), before)
		t.eq(m.Sides[1].PickAnyUsed, 1)
		t.ok(not MatchLogic.pickAny(m, 1, chosen))
		MatchLogic.startRound(m)
		t.eq(m.Sides[1].Pick, nil)
		t.eq(m.Sides[1].PickAnyUsed, 1)
		for used, cost in { 0, 6, 9, 12, 12, 12 } do
			t.eq(MatchLogic.pickAnyCost(used - 1), cost)
		end
	end)
	t.test("rerolls and picks are validated", function()
		local m = MatchLogic.new({ { Collection = big }, { Collection = {} } }, Rng.new(3))
		MatchLogic.startRound(m)
		t.ok(MatchLogic.reroll(m, 1), "reroll ok")
		t.eq(m.Sides[1].RerollsUsed, 1, "counted")
		local ok, why = MatchLogic.reroll(m, 2)
		t.ok(not ok and why == "nothing_new", "no point rerolling 3 starters")
		local bad, reason = MatchLogic.pick(m, 1, "glass_dragon")
		t.ok(not bad and reason == "not_offered", "can't pick what wasn't offered")
		t.ok(not MatchLogic.pick(m, 1, 42), "type checked")
		t.ok(MatchLogic.pick(m, 1, m.Sides[1].Offers[2]), "pick an offer")
		t.ok(not MatchLogic.pick(m, 1, m.Sides[1].Offers[1]), "only once")
		t.ok(not MatchLogic.reroll(m, 1), "no reroll after picking")
		t.eq(MatchLogic.autoPick(m, 2), m.Sides[2].Offers[1], "timeout picks the first offer")
	end)

	t.test("hearts: first to lose 3 loses the match", function()
		local m = MatchLogic.new({ { Collection = big }, { Collection = big } }, Rng.new(4))
		local rounds = 0
		local results = { 1, 2, 1, 2, 1 }
		for _, w in results do
			MatchLogic.startRound(m)
			MatchLogic.autoPick(m, 1)
			MatchLogic.autoPick(m, 2)
			rounds += 1
			if MatchLogic.endRound(m, w) then
				break
			end
		end
		t.eq(rounds, 5, "goes the distance")
		t.ok(m.Over and m.Winner == 1, "side 1 wins 3-2")
		t.eq(m.Sides[2].Hearts, 0, "no hearts left")
		t.eq(#m.History, 5, "history")
		t.eq(m.Sides[1].LastPick, m.History[5].Picks[1], "last pick remembered")
	end)

	t.test("fight setup carries picks, stars and aim", function()
		local m = MatchLogic.new(
			{ { Collection = { pop = { Stars = 2 } } }, { Collection = big, IsBot = true, Skill = 1 } },
			Rng.new(8)
		)
		MatchLogic.startRound(m)
		MatchLogic.pick(m, 1, "pop")
		MatchLogic.setAim(m, 1, 5, -5)
		local setup = MatchLogic.fightSetup(m)
		t.eq(setup.A.Id, "pop", "pick")
		t.eq(setup.A.Stars, 2, "stars")
		t.eq(setup.A.Aim, Balance.Motion.AimMax, "aim clamped")
		t.eq(setup.A.AimYaw, -Balance.Motion.AimYawMax, "yaw clamped")
		t.ok(math.abs(setup.B.Aim - m.SweetSpot) < 1e-9, "skill-1 bot aims at the sweet spot")
	end)

	t.test("skilled bots counter-pick the last glassy they saw", function()
		local m = MatchLogic.new({ { Collection = big }, { Collection = big, IsBot = true, Skill = 1 } }, Rng.new(9))
		m.Sides[1].LastPick = "jam" -- Heavy; Fizzy beats Heavy
		local fizzy = 0
		for _ = 1, 50 do
			m.Sides[2].Pick = nil
			m.Sides[2].Offers = { "prism", "milk_bottle", "glass_cup" }
			if Glassies.get(MatchLogic.autoPick(m, 2)).Type == "Fizzy" then
				fizzy += 1
			end
		end
		t.eq(fizzy, 50, "always takes the type advantage")
	end)

	t.test("rewards: a win always pays 100, a loss pays for performance, bots never take trophies", function()
		local R = B.Rewards
		local m = MatchLogic.new({ { Collection = big }, { Collection = big } }, Rng.new(5))
		for _, w in { 1, 1, 2, 1 } do
			MatchLogic.startRound(m)
			MatchLogic.endRound(m, w)
		end
		local win, loss = MatchLogic.rewards(m, 1, 100), MatchLogic.rewards(m, 2, 3)
		t.eq(win.Coins, 100, "a win pays 100")
		t.eq(R.MatchWinCoins, 100)
		t.eq(loss.Coins, R.LossBaseCoins + R.LossHeartCoins, "loss defaults to hearts taken from the match")
		t.ok(loss.Coins > 0 and loss.Coins < win.Coins, "both earn, winner more")
		t.eq(win.Trophies, R.WinTrophies, "win trophies")
		t.eq(loss.Trophies, -3, "never below zero")
		local played = MatchLogic.rewards(m, 2, 3, true, { Hearts = 1, Chip = 2.4, Perfects = 2 })
		t.eq(
			played.Coins,
			R.LossBaseCoins + R.LossHeartCoins + math.floor(2.4 * R.LossChipCoins + 0.5) + 2 * R.LossPerfectCoins
		)
		t.ok(played.Coins > loss.Coins, "more damage and perfects pay more")
		local close = MatchLogic.rewards(m, 2, 3, true, { Hearts = 0, Chip = 2.7, Perfects = 1 })
		t.ok(close.Coins < played.Coins, "taking a heart is worth more than chip damage")
		t.eq(MatchLogic.rewards(m, 2, 3, true, { Hearts = 2, Chip = 3, Perfects = 5 }).Coins, R.LossMaxCoins, "capped")
		t.ok(R.LossMaxCoins <= R.MatchWinCoins / 2, "a loss is capped well below a win")
		t.eq(MatchLogic.rewards(m, 2, 3, true, { Hearts = 2, Forfeited = true }).Coins, 0, "quitting pays nothing")
		t.eq(MatchLogic.rewards(m, 1, 100, true, { Hearts = 0, Chip = 0 }).Coins, 100, "a win pays 100 no matter what")
		local vb = MatchLogic.new({ { Collection = big }, { Collection = big, IsBot = true } }, Rng.new(6))
		for _ = 1, 3 do
			MatchLogic.startRound(vb)
			MatchLogic.endRound(vb, 2)
		end
		local r = MatchLogic.rewards(vb, 1, 50, true, { Hearts = 0, Chip = 1.2, Perfects = 0 })
		t.eq(r.Trophies, 0, "losing to a bot costs no trophies")
		t.eq(r.Coins, MatchLogic.lossCoins(0, 1.2, 0))
		local beat = MatchLogic.new({ { Collection = big }, { Collection = big, IsBot = true } }, Rng.new(7))
		for _ = 1, 3 do
			MatchLogic.startRound(beat)
			MatchLogic.endRound(beat, 1)
		end
		local botWin = MatchLogic.rewards(beat, 1, 50)
		t.eq(botWin.Coins, 100, "beating a bot also pays 100")
		t.eq(botWin.Trophies, R.BotWinTrophies)
		t.eq(MatchLogic.rewards(beat, 1, 50, false).Coins, 0, "no contest still pays nothing")
	end)

	t.test("bot collections match the player's size and best rarity", function()
		local rng = Rng.new(12)
		local bot = MatchLogic.botCollection(big, rng)
		local size, best = 0, 0
		for id in bot do
			size += 1
			local def = Glassies.get(id)
			best = math.max(best, Balance.Rarities[def.Rarity].Order)
		end
		t.eq(size, 7, "same size")
		t.ok(best <= Balance.Rarities.Legendary.Order, "no rarer than the player's best")
		for _, id in Glassies.Starters do
			t.ok(bot[id] ~= nil, "bot owns " .. id)
		end
	end)
end
