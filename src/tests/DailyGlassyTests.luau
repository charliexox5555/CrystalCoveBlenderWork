-- Daily and Playtime rewards v2 (decision 115): the two Daily-only glassies, repeat weeks, the XP gift, gifts that
-- collect themselves, and Midnight's lullaby mark.
local Schema = if script
	then require(game.ServerScriptService.Server.Data.ProfileSchema)
	else require("../server/Data/ProfileSchema")
local Rules = if script
	then require(game.ServerScriptService.Server.Data.RetentionRules)
	else require("../server/Data/RetentionRules")
local Grant = if script
	then require(game.ServerScriptService.Server.Data.RewardGrant)
	else require("../server/Data/RewardGrant")
local Levels = if script then require(game.ReplicatedStorage.Shared.LevelRules) else require("../shared/LevelRules")

return function(t, d)
	local day = d.Balance.Data.DaySeconds
	local B, G = d.Balance, d.Glassies

	-- Claims calendar days on consecutive UTC days from `first`; returns the day after the last claim.
	local function claimDays(data, first, count)
		for i = 0, count - 1 do
			t.eq(Rules.claim(data, "Daily", nil, (first + i) * day), true, "claim on day " .. first + i)
		end
		return first + count
	end

	t.test("Day 2 gives Whiskers (Epic) and Day 7 gives Midnight (Legendary) with their coins", function()
		local rewards = B.Economy.DailyRewards
		t.eq(rewards[2].Item.Id, "whiskers")
		t.eq(rewards[7].Item.Id, "midnight_moon")
		t.eq(G.get("whiskers").Rarity, "Epic")
		t.eq(G.get("midnight_moon").Rarity, "Legendary")
		for i, r in rewards do
			t.ok((r.Coins or 0) >= 100, "Day " .. i .. " pays at least 100 coins")
		end
		local data = Schema.new(300 * day)
		claimDays(data, 300, 2)
		t.ok(data.Glassies.whiskers ~= nil and data.Glassies.whiskers.Count == 1, "Whiskers owned after Day 2")
		claimDays(data, 302, 5)
		t.ok(data.Glassies.midnight_moon ~= nil, "Midnight owned after Day 7")
		t.eq(data.FreePulls.Glassies, 1, "the free Kiln pull moved to Day 5")
		t.eq(data.Coins, 100 + 100 + 100 + 150 + 100 + 150 + 300)
	end)

	t.test("repeat weeks add a star to the Daily glassies until max, then give WhenMaxed instead", function()
		local data = Schema.new(400 * day)
		local nextDay = claimDays(data, 400, 7)
		local maxStars = B.Growth.MaxStars
		for week = 2, maxStars + 1 do
			nextDay = claimDays(data, nextDay, 7)
			t.eq(data.Glassies.whiskers.Stars, week - 1, "week " .. week .. " adds a Whiskers star")
			t.eq(data.Glassies.midnight_moon.Stars, week - 1, "week " .. week .. " adds a Midnight star")
		end
		t.eq(data.Glassies.whiskers.Stars, maxStars)
		local view = Rules.calendar(data, nextDay * day)
		t.eq(view.Rewards[2].Item, nil, "a maxed Whiskers is not shown again")
		t.eq(view.Rewards[2].Coins, B.Economy.DailyRewards[2].WhenMaxed.Coins)
		t.eq(view.Rewards[7].Pull, "Glassies", "maxed Day 7: a free Kiln pull")
		local count, coins, pulls = data.Glassies.whiskers.Count, data.Coins, data.FreePulls.Glassies
		claimDays(data, nextDay, 7)
		t.eq(data.Glassies.whiskers.Count, count, "no copy past max stars")
		local maxedWeek = 0
		for i, r in B.Economy.DailyRewards do
			local give = if r.WhenMaxed then r.WhenMaxed else r
			maxedWeek += give.Coins or 0
			t.eq(Rules.dailyReward(data, r).WhenMaxed, nil, "Day " .. i .. " view carries no WhenMaxed note")
		end
		t.eq(data.Coins - coins, maxedWeek, "no duplicate-overflow coins on top")
		t.eq(data.FreePulls.Glassies - pulls, 2, "Day 5 pull + maxed Day 7 pull")
	end)

	t.test("Daily glassies stay out of the release roster, the Kiln, the daily store and bot pools", function()
		for _, id in G.DailyIds do
			t.ok(G.isDaily(id))
			t.ok(not G.isRelease(id), id .. " is not in the release roster")
			for _, rarity in { "Epic", "Legendary" } do
				t.ok(table.find(d.Formula.kilnPool(rarity), id) == nil, id .. " is not in the Kiln")
			end
			t.ok(B.CombatRelease.Kits[id] ~= nil, id .. " has a kit")
			t.ok(Grant.valid({ Item = { Category = "Glassies", Id = id } }), id .. " can be granted")
			local found = false
			for _, def in G.visible({}) do
				found = found or def.Id == id
			end
			t.ok(found, id .. " shows in the collection before it is owned")
			t.ok(#G.get(id).Name <= 10, id .. " name fits a tile")
		end
		local DailyStoreRules = if script
			then require(game.ReplicatedStorage.Shared.DailyStoreRules)
			else require("../shared/DailyStoreRules")
		local catalog = DailyStoreRules.catalog()
		for _, ids in catalog.Glassies do
			for _, id in G.DailyIds do
				t.ok(table.find(ids, id) == nil, id .. " is never sold in the daily store")
			end
		end
	end)

	t.test("playtime gifts collect themselves once a day, pay more coins and include an XP gift", function()
		local gifts = B.Economy.PlaytimeGifts
		local xpGifts, total = 0, 0
		for _, g in gifts do
			xpGifts += if (g.Xp or 0) > 0 then 1 else 0
			total += g.Coins or 0
		end
		t.eq(xpGifts, 1, "exactly one gift is XP")
		t.ok(total > 255, "more coins than the decision 99 ladder (255)")
		local now = 500 * day
		local data = Schema.new(now)
		t.eq(#Rules.collectGifts(data, now), 0, "nothing at 0 min")
		Rules.advance(data, gifts[1].Minutes * 60, now)
		local first = Rules.collectGifts(data, now)
		t.eq(#first, 1)
		t.eq(data.Coins, gifts[1].Coins)
		t.eq(#Rules.collectGifts(data, now), 0, "a gift is granted once")
		Rules.advance(data, 60 * 60, now)
		local rest = Rules.collectGifts(data, now)
		t.eq(#rest, #gifts - 1, "the rest arrive together after a long gap")
		local xp = 0
		for _, g in gifts do
			xp += g.Xp or 0
		end
		t.eq(data.Xp, xp, "the XP gift goes into the level total")
		t.ok(Levels.level(data.Xp) >= 2, "200 XP is a level-up from level 1")
		t.eq(Rules.claim(data, "Gift", 1, now), false, "the old CLAIM path finds nothing left")
		-- the next UTC day starts over
		t.eq(#Rules.collectGifts(data, now + day), 0)
		t.eq(data.Daily.PlaytimeSeconds, 0)
	end)

	t.test("XP rewards are valid bundles and describe themselves", function()
		t.ok(Grant.valid({ Xp = 200 }))
		t.ok(not Grant.valid({ Xp = -1 }))
		t.ok(not Grant.valid({ Xp = 1.5 }))
		t.eq(Grant.describe({ Xp = 200 }), "+200 XP")
	end)

	t.test(
		"Midnight's lullaby marks and slows a foe it lands on (the next clash pops the mark, as mark_contact)",
		function()
			local R = d.FightRules
			local kit = B.CombatRelease.Kits.midnight_moon
			local s = R.new({
				A = { Id = "midnight_moon" },
				B = { Id = "jam" },
				Rng = function()
					return 0.01
				end,
				ReleaseKits = true,
				CastsManaged = true,
			})
			local cast
			for _ = 1, math.ceil((kit.First + kit.Jitter + kit.Windup + 1) / 0.05) do
				R.tick(s, 0.05)
				for _, c in R.drainCasts(s) do
					if c.Side == 1 and not cast then
						cast = c
					end
				end
				if cast then
					break
				end
			end
			t.ok(cast ~= nil and cast.Shape == "pulse", "the lullaby casts as a pulse")
			if not cast then
				return
			end
			t.ok(R.releaseCast(s, cast, { 0, 0, 0 }, { 1, 0, 0 }))
			t.ok(R.resolveAbility(s, cast.Id, true, { 1, 0, 0 }))
			local foe = s.Fighters[2]
			t.ok(foe.Signature.Mark ~= nil, "sleepy foe is marked")
			t.near(foe.Signature.Mark.Until - s.Time, kit.MarkSeconds, 0.001)
			t.ok((foe.Signature.SlowUntil or -1) > s.Time, "and slowed")
		end
	)
end
