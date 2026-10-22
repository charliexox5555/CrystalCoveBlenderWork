-- Starter Pack, Daily Glassy, Daily Marbles and the Need Marbles suggestion (OfferRules, decision 116): one-time
-- flags, daily limits and resets, the streak table, odds tables, honest values and the receipt path.
local function load(path, file)
	if script then
		local node = game.ReplicatedStorage.Shared
		for _, name in path do
			node = node[name]
		end
		return require(node)
	end
	return require(file)
end
local Offers = load({ "OfferRules" }, "../shared/OfferRules")
local Store = load({ "DailyStoreRules" }, "../shared/DailyStoreRules")
local O = load({ "Config", "Offers" }, "../shared/Config/Offers")
local M = load({ "Config", "MarbleShop" }, "../shared/Config/MarbleShop")
local B = load({ "Config", "Balance" }, "../shared/Config/Balance")
local Formula = load({ "Formula" }, "../shared/Formula")
local Rng = load({ "Rng" }, "../shared/Rng")
local Schema = if script
	then require(game.ServerScriptService.Server.Data.ProfileSchema)
	else require("../server/Data/ProfileSchema")

local MIDNIGHT = 1792195200 -- 2026-10-17 00:00:00 UTC
local DAY = 86400
local STUDIO = { Studio = true, PaidRandomAllowed = true }
local LIVE = { Studio = false, PaidRandomAllowed = true }

return function(t)
	local function profile()
		local data = Schema.new(0)
		Schema.reconcile(data, 0)
		return data
	end
	local function grantFn(data)
		return function(category, id)
			return Schema.grantItem(data, category, id, 0)
		end
	end
	local function buy(data, kind, now, ctx, purchaseId)
		local ok, intent = Store.beginIntent(data, kind, ctx, now)
		if not ok then
			return false, intent
		end
		local status, applied =
			Store.applyReceipt(data, { PurchaseId = purchaseId, ProductId = intent.ProductId }, now, grantFn(data))
		return status == "Granted", applied
	end

	t.test("offers without a product id show SOON live and run on placeholders in Studio", function()
		local data = profile()
		for kind in Offers.Kinds do
			local product = Offers.product(kind, LIVE)
			if O[if kind == "Starter" then "StarterPack" else kind].ProductId == nil then
				t.eq(product, nil, kind .. " has no live product yet")
				t.eq(select(2, Store.beginIntent(data, kind, LIVE, MIDNIGHT)), "Coming soon")
			end
			local studio = Offers.product(kind, STUDIO)
			t.ok(studio and studio.ProductId > 0, kind .. " placeholder")
		end
	end)

	t.test("starter pack: one per player ever, exclusives granted with the Marbles", function()
		local data = profile()
		t.ok(Offers.markStarterSeen(data, MIDNIGHT))
		t.ok(not Offers.markStarterSeen(data, MIDNIGHT + 5), "the window starts once")
		local state = Offers.starterState(data, MIDNIGHT, STUDIO)
		t.ok(state.Visible and state.Available)
		t.eq(state.Price, 49)
		local marbles = data.Marbles
		local ok, applied = buy(data, "Starter", MIDNIGHT + 60, STUDIO, "s1")
		t.ok(ok, tostring(applied))
		t.eq(data.Marbles, marbles + O.StarterPack.Marbles)
		t.eq(#applied.Grants, #O.StarterPack.Items + 1)
		for _, item in Offers.starterItems(true) do
			t.ok(Store.owns(data, item.Category, item.Id) > 0, item.Id .. " granted")
		end
		t.ok(data.Deals.StarterBought)
		t.eq(select(2, Store.beginIntent(data, "Starter", STUDIO, MIDNIGHT + 120)), "You already have the Starter Pack")
		t.ok(not Offers.starterState(data, MIDNIGHT + 120, STUDIO).Visible, "the tile goes away")
	end)

	t.test("starter pack: the window closes after WindowHours and auto-opens at most twice", function()
		local data = profile()
		Offers.markStarterSeen(data, MIDNIGHT)
		local hours = O.StarterPack.WindowHours
		t.ok(Offers.starterAutoOpen(data, MIDNIGHT), "first visit opens it")
		t.ok(Offers.noteAutoOpen(data, MIDNIGHT))
		t.ok(not Offers.starterAutoOpen(data, MIDNIGHT + 3600), "not again the same day")
		local lastDay = MIDNIGHT + (hours - O.StarterPack.AutoOpenLastHours) * 3600 + 60
		t.ok(Offers.starterAutoOpen(data, lastDay), "once more in its last day")
		t.ok(Offers.noteAutoOpen(data, lastDay))
		t.ok(not Offers.starterAutoOpen(data, lastDay + 60), "then never")
		local ends = MIDNIGHT + hours * 3600
		t.ok(Offers.starterState(data, ends - 1, STUDIO).Available)
		t.ok(not Offers.starterState(data, ends, STUDIO).Visible, "gone at the end")
		t.eq(select(2, Store.beginIntent(data, "Starter", STUDIO, ends)), "The Starter Pack has ended")
		-- A first open already inside the last day uses up both auto-opens.
		local late = profile()
		Offers.markStarterSeen(late, MIDNIGHT)
		t.ok(Offers.noteAutoOpen(late, lastDay))
		t.ok(not Offers.starterAutoOpen(late, lastDay + 60))
	end)

	t.test("starter pack value is the sum of its parts at real prices and the discount is not overstated", function()
		local items = Offers.starterItems(true)
		local value = Offers.starterValue(items)
		local sum = 0
		for _, part in value.Parts do
			t.ok(part.Value > 0, tostring(part.Id or part.Category) .. " has a real price")
			sum += part.Value
		end
		t.eq(value.Total, sum)
		t.ok(O.StarterPack.Price / value.Total <= 1 - value.Off / 100 + 1e-9, "off rounds down")
		t.ok(value.Off >= 80, "a clearly good deal (" .. value.Off .. "% off)")
		t.eq(Offers.marbleValue(100), 99, "Marbles valued at the Handful's rate")
	end)

	t.test("starter exclusives never enter the daily store", function()
		local catalog = Store.catalog()
		for _, item in O.StarterPack.Items do
			for _, ids in catalog[item.Category] or {} do
				t.ok(not table.find(ids, item.Id), item.Id .. " is exclusive")
			end
		end
	end)

	t.test(
		"daily glassy odds: Rare and Epic most, each glassy rarer than every lower-rarity glassy, sum 100%",
		function()
			local odds = Offers.dailyGlassyOdds()
			local total, byRarity, each = 0, {}, {}
			for _, entry in odds do
				total += entry.Chance
				byRarity[entry.Rarity] = (byRarity[entry.Rarity] or 0) + entry.Chance
				each[entry.Rarity] = entry.Chance
			end
			t.near(total, 1, 1e-9)
			t.eq(byRarity.Common, nil)
			t.eq(byRarity.Uncommon, nil)
			t.ok(byRarity.Rare > byRarity.Epic and byRarity.Epic > byRarity.Legendary)
			t.ok(byRarity.Legendary > byRarity.Mythic)
			t.ok((byRarity.Rare + byRarity.Epic) >= 0.9, "mostly Rare and Epic")
			local order = { "Rare", "Epic", "Legendary", "Mythic" }
			for i = 2, #order do
				t.ok(each[order[i]] < each[order[i - 1]], order[i] .. " glassies are each rarer than " .. order[i - 1])
			end
			-- Only installed Kiln glassies; a rarity with none drops out and the rest renormalize.
			local available = {}
			for _, rarity in { "Rare", "Epic" } do
				for _, id in Formula.kilnPool(rarity) do
					available[id] = true
				end
			end
			local partial, sum = Offers.dailyGlassyOdds(available), 0
			for _, entry in partial do
				t.ok(entry.Rarity == "Rare" or entry.Rarity == "Epic")
				sum += entry.Chance
			end
			t.near(sum, 1, 1e-9)
		end
	)

	t.test("daily glassy draws follow the odds", function()
		local odds = Offers.dailyGlassyOdds()
		local rarity = {}
		for _, entry in odds do
			rarity[entry.Id] = entry.Rarity
		end
		local r = Rng.new(116)
		local counts, n = {}, 40000
		for _ = 1, n do
			local id = Offers.roll(odds, r)
			counts[rarity[id]] = (counts[rarity[id]] or 0) + 1
		end
		for _, row in Offers.dailyGlassyRarities() do
			t.near((counts[row.Rarity] or 0) / n, row.Chance, 0.01, row.Rarity)
		end
	end)

	t.test("daily glassy: once per UTC day, hidden where paid random items are restricted", function()
		local data = profile()
		local restricted = { Studio = true, PaidRandomAllowed = false }
		t.ok(not Offers.dailyGlassyState(data, MIDNIGHT, restricted).Visible)
		t.eq(
			select(2, Store.beginIntent(data, "DailyGlassy", restricted, MIDNIGHT)),
			"This offer is unavailable for your account"
		)
		t.ok(not Offers.dailyGlassyState(data, MIDNIGHT, { Studio = true }).Visible, "unknown policy = hidden")
		local ok, applied = buy(data, "DailyGlassy", MIDNIGHT + 10, STUDIO, "g1")
		t.ok(ok, tostring(applied))
		local granted = applied.Grants[1]
		t.ok(B.Rarities[load({ "Config", "Glassies" }, "../shared/Config/Glassies").get(granted.Id).Rarity].Order >= 3)
		t.ok(Offers.dailyGlassyState(data, MIDNIGHT + 20, STUDIO).BoughtToday)
		t.eq(select(2, Store.beginIntent(data, "DailyGlassy", STUDIO, MIDNIGHT + 20)), "Come back tomorrow for another")
		t.ok(Offers.dailyGlassyState(data, MIDNIGHT + DAY, STUDIO).Available, "back after the 00:00 UTC reset")
		local again = buy(data, "DailyGlassy", MIDNIGHT + DAY, STUDIO, "g2")
		t.ok(again)
	end)

	t.test("daily glassy duplicates follow the Kiln rule (a star)", function()
		local data = profile()
		local only = Offers.dailyGlassyOdds()[1].Id
		local intent = { Kind = "DailyGlassy", Day = 0, Odds = { { Id = only, Chance = 1 } } }
		Offers.apply(data, intent, 0, grantFn(data), function()
			return 0.5
		end)
		local second = Offers.apply(data, intent, 0, grantFn(data), function()
			return 0.5
		end)
		t.ok(second[1].Duplicate)
		t.eq(second[1].Stars, 1)
	end)

	t.test("daily marbles: one buy a day, the amount climbs per buy, a missed day keeps your place", function()
		local data = profile()
		local amounts = O.DailyMarbles.Amounts
		local marbles = data.Marbles
		local day = MIDNIGHT
		for step = 1, #amounts + 2 do
			local state = Offers.dailyMarblesState(data, day, STUDIO)
			t.eq(state.Next, amounts[math.min(step, #amounts)], "step " .. step)
			local ok = buy(data, "DailyMarbles", day + 30, STUDIO, "d" .. step)
			t.ok(ok)
			marbles += state.Next
			t.eq(data.Marbles, marbles)
			t.eq(select(2, Store.beginIntent(data, "DailyMarbles", STUDIO, day + 60)), "Come back tomorrow for more")
			-- Skip a day every other buy: the place is kept.
			day += if step % 2 == 0 then 2 * DAY else DAY
		end
		t.eq(Offers.dailyMarblesState(data, day, STUDIO).Next, amounts[#amounts], "the top step repeats")
	end)

	t.test("daily marbles: a delayed receipt honours what was shown and moves one step", function()
		local data = profile()
		local ok, intent = Store.beginIntent(data, "DailyMarbles", STUDIO, MIDNIGHT + DAY - 5)
		t.ok(ok)
		local before = data.Marbles
		t.eq(
			Store.applyReceipt(
				data,
				{ PurchaseId = "late", ProductId = intent.ProductId },
				MIDNIGHT + DAY + 5,
				grantFn(data)
			),
			"Granted"
		)
		t.eq(data.Marbles, before + O.DailyMarbles.Amounts[1])
		t.eq(data.Deals.DailyMarblesStep, 1)
		t.ok(Offers.dailyMarblesState(data, MIDNIGHT + DAY + 10, STUDIO).Available, "the new day is still open")
	end)

	t.test("daily marbles beat the smallest pack and the bonus shown is true", function()
		for _, amount in O.DailyMarbles.Amounts do
			t.ok(amount / O.DailyMarbles.Price > M.Packs[1].Marbles / M.Packs[1].Price)
		end
		for _, pack in Store.marblePacks() do
			if pack.Available then
				local real = pack.Marbles / pack.RobuxPrice / (M.Packs[1].Marbles / M.Packs[1].Price) - 1
				t.ok(pack.Bonus <= real * 100 + 1e-6 and pack.Bonus >= real * 100 - 1, pack.Id .. " bonus")
			end
		end
	end)

	t.test("need marbles: today's Daily Marbles when it covers the gap, else the smallest pack that does", function()
		local data = profile()
		local first = O.DailyMarbles.Amounts[1]
		local function daily()
			return Offers.dailyMarblesState(data, MIDNIGHT + 10, STUDIO)
		end
		local s = Offers.suggest(5, daily())
		t.eq(s.Kind, "DailyMarbles")
		t.eq(s.Marbles, first)
		s = Offers.suggest(first + 1, daily())
		t.eq(s.Kind, "Pack")
		t.eq(s.Id, "handful")
		t.eq(Offers.suggest(150, daily()).Id, "pouch")
		t.eq(Offers.suggest(1000000, daily()).Id, "vault", "the biggest when nothing covers it")
		t.eq(
			Offers.suggest(150, daily(), function(pack)
				return pack.Id == "pouch"
			end).Id,
			"jar",
			"a held-back pack is skipped"
		)
		buy(data, "DailyMarbles", MIDNIGHT, STUDIO, "x")
		t.eq(Offers.suggest(5, daily()).Kind, "Pack", "daily already bought")
	end)

	t.test("offer intents refresh their own snapshot and never block each other", function()
		local data = profile()
		local ok1, a = Store.beginIntent(data, "DailyMarbles", STUDIO, MIDNIGHT)
		Store.cancelIntent(data, a.ProductId)
		local ok2, b = Store.beginIntent(data, "DailyMarbles", STUDIO, MIDNIGHT + DAY * 2)
		t.ok(ok1 and ok2, "a stale intent never blocks a later day")
		t.eq(b.Day, Offers.dayKey(MIDNIGHT + DAY * 2))
		local ok3 = Store.beginIntent(data, "DailyGlassy", STUDIO, MIDNIGHT)
		local ok4 = Store.beginIntent(data, "Starter", STUDIO, MIDNIGHT)
		t.ok(ok3 and ok4)
	end)

	t.test("reconcile repairs bad saved offer state", function()
		local data = profile()
		data.Deals = { StarterBought = "yes", DailyMarblesStep = 99, DailyGlassyDay = 1.5, StarterAutoShown = -3 }
		Offers.reconcile(data)
		t.eq(data.Deals.StarterBought, false)
		t.eq(data.Deals.DailyMarblesStep, #O.DailyMarbles.Amounts)
		t.eq(data.Deals.DailyGlassyDay, -1)
		t.eq(data.Deals.StarterAutoShown, 0)
	end)
end
