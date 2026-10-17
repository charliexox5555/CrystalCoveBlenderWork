-- Daily Featured store: reset boundaries, stable per-player rotation, distribution, Coin
-- purchases, Robux intents/receipts and the Hollowlight bundle.
local Rules = if script
	then require(game.ReplicatedStorage.Shared.DailyStoreRules)
	else require("../shared/DailyStoreRules")
local D = if script
	then require(game.ReplicatedStorage.Shared.Config.DailyStore)
	else require("../shared/Config/DailyStore")
local Crates = if script then require(game.ReplicatedStorage.Shared.CrateRules) else require("../shared/CrateRules")
local Schema = if script
	then require(game.ServerScriptService.Server.Data.ProfileSchema)
	else require("../server/Data/ProfileSchema")

local MIDNIGHT = 1792195200 -- 2026-10-17 00:00:00 UTC (6 PM CST on the 16th)
local LEAP = 1835395200 -- 2028-02-29 00:00:00 UTC

return function(t, d)
	local catalog = Rules.catalog()
	local function profile()
		local data = Schema.new(0)
		data.Coins = 100000
		return data
	end
	local function grantFn(data)
		return function(category, id)
			return Schema.grantItem(data, category, id, 0)
		end
	end
	-- Temporarily replace every product (test IDs, or nil for "not configured") and always restore
	-- the shipped config, so these tests do not depend on the real product IDs.
	local function withConfig(configured, fn)
		local saved, n, entries, added = {}, 0, {}, {}
		for _, category in Rules.Categories do
			for rarity, weight in D.Weights.Robux do
				if weight > 0 then
					if not D.RobuxProducts[category][rarity] then
						D.RobuxProducts[category][rarity] = {}
						table.insert(added, { D.RobuxProducts[category], rarity })
					end
					local byRarity = D.RobuxProducts[category][rarity]
					for _, band in D.ValueBands do
						if not byRarity[band] then
							byRarity[band] = {}
							table.insert(added, { byRarity, band })
						end
						table.insert(entries, byRarity[band])
					end
				end
			end
		end
		local bundle = D.Bundles[1]
		table.insert(entries, bundle)
		for _, entry in entries do
			saved[entry] = { entry.ProductId, entry.Price }
			n += 1
			entry.ProductId, entry.Price = if configured then 1000 + n else nil, if configured then 99 else nil
		end
		bundle.Price = if configured then 499 else nil
		local ok, err = pcall(fn)
		for entry, values in saved do
			entry.ProductId, entry.Price = values[1], values[2]
		end
		for i = #added, 1, -1 do
			added[i][1][added[i][2]] = nil
		end
		if not ok then
			error(err, 0)
		end
	end
	local function withProducts(fn)
		withConfig(true, fn)
	end

	t.test("day resets at 00:00 UTC, including a leap day", function()
		t.eq(Rules.dayKey(MIDNIGHT) - Rules.dayKey(MIDNIGHT - 1), 1, "one second before midnight is yesterday")
		t.eq(Rules.nextReset(MIDNIGHT - 1), MIDNIGHT)
		t.eq(Rules.nextReset(MIDNIGHT), MIDNIGHT + 86400)
		t.eq(Rules.dayKey(LEAP - 1) + 1, Rules.dayKey(LEAP))
		t.eq(Rules.dayKey(LEAP + 86399), Rules.dayKey(LEAP), "Feb 29 is one whole day")
		t.eq(Rules.dayKey(LEAP + 86400), Rules.dayKey(LEAP) + 1, "Mar 1 follows")
		t.eq(D.ResetOffsetSeconds, 0, "fixed CST 6 PM = 00:00 UTC, no DST")
	end)

	t.test("seasonal bundle items stay out of the daily catalog and ordinary crates", function()
		for _, item in D.Bundles[1].Items do
			for _, ids in catalog[item.Category] do
				t.ok(not table.find(ids, item.Id), item.Id .. " in daily catalog")
			end
			if item.Category ~= "Glassies" then
				for _, entry in Crates.odds(item.Category, "Coins") do
					t.ok(entry.Id ~= item.Id, item.Id .. " in crate pool")
				end
			end
		end
		for _, ids in catalog.Glassies do
			for _, id in ids do
				t.ok(d.Glassies.isRelease(id) and d.Glassies.get(id).Rarity ~= "Starter", id)
			end
		end
		t.ok(not table.find(catalog.Rideables.Common or {}, "skyboard"), "free starter flyer is not sold")
	end)

	t.test("offers are stable per player/day and differ between players and days", function()
		local function key(offers)
			local parts = {}
			for _, offer in offers do
				table.insert(parts, offer.Category .. ":" .. tostring(offer.Id))
			end
			return table.concat(parts, ",")
		end
		local day = Rules.dayKey(MIDNIGHT)
		t.eq(key(Rules.generate(77, day, catalog)), key(Rules.generate(77, day, Rules.catalog())))
		local players, days = {}, {}
		for user = 1, 40 do
			players[key(Rules.generate(user, day, catalog))] = true
			days[key(Rules.generate(77, day + user, catalog))] = true
		end
		local function count(set)
			local n = 0
			for _ in set do
				n += 1
			end
			return n
		end
		t.between(count(players), 30, 40, "distinct player sets")
		t.between(count(days), 30, 40, "distinct day sets")
	end)

	t.test("four slots: three Robux categories, one rotating Coin slot, never a duplicate", function()
		for user = -3, 300 do
			local day = 20000 + user * 7
			local offers = Rules.generate(user, day, catalog)
			t.eq(#offers, 4)
			local seen = {}
			for slot, offer in offers do
				t.ok(not offer.Empty, "slot empty")
				t.eq(offer.Currency, D.Slots[slot].Currency)
				local k = offer.Category .. ":" .. offer.Id
				t.ok(not seen[k], "duplicate " .. k)
				seen[k] = true
				t.eq(Rules.definition(offer.Category, offer.Id).Rarity, offer.Rarity)
			end
			t.eq(offers[1].Category, "Glassies")
			t.eq(offers[2].Category, "Finishers")
			t.eq(offers[3].Category, "Rideables")
			t.eq(offers[4].Category, D.CoinCategoryRotation[(user + day) % 3 + 1])
			t.ok(offers[4].Price and offers[4].Price > 0 and offers[4].ValueBand == nil)
			t.ok(offers[1].ValueBand == "Standard" or offers[1].ValueBand == "Featured")
		end
	end)

	t.test("rarity distribution follows the configured weights", function()
		local robux, coins, n, nc = {}, {}, 20000, 0
		local priceSum = 0
		for i = 1, n do
			local offers = Rules.generate(i, 21000 + i % 97, catalog)
			robux[offers[1].Rarity] = (robux[offers[1].Rarity] or 0) + 1
			priceSum += offers[4].Price
			if offers[4].Category == "Glassies" then
				nc += 1
				coins[offers[4].Rarity] = (coins[offers[4].Rarity] or 0) + 1
			end
		end
		for rarity, weight in D.Weights.Robux do
			t.near((robux[rarity] or 0) / n * 100, weight, 1.5, "Robux glassy " .. rarity)
		end
		for rarity, weight in D.Weights.Coins do
			t.near((coins[rarity] or 0) / nc * 100, weight, 2, "Coin glassy " .. rarity)
		end
		-- Coin pacing: the average daily Coin offer stays a few days of ordinary play.
		t.between(priceSum / n, 400, 1500, "mean Coin offer price")
	end)

	t.test("empty rarity buckets renormalize and an empty category stays visibly empty", function()
		local narrow = {
			Glassies = { Rare = catalog.Glassies.Rare, Epic = catalog.Glassies.Epic },
			Finishers = {},
			Rideables = {},
		}
		local rare, n = 0, 6000
		for i = 1, n do
			local offers = Rules.generate(i, 400, narrow)
			t.ok(offers[1].Rarity == "Rare" or offers[1].Rarity == "Epic")
			rare += if offers[1].Rarity == "Rare" then 1 else 0
			t.ok(offers[2].Empty and offers[3].Empty)
		end
		t.near(rare / n, 45 / 75, 0.03, "Rare share after renormalizing")
	end)

	t.test("unowned items are preferred; owning everything offers a labelled extra copy", function()
		local day = Rules.dayKey(MIDNIGHT)
		local rare = catalog.Glassies.Rare
		local keep = rare[1]
		for user = 1, 200 do
			local offers = Rules.generate(user, day, catalog, function(category, id)
				return if category == "Glassies" and id ~= keep then 1 else 0
			end)
			local first = offers[1]
			t.ok(first.Id == keep or first.Extra, "owned glassy offered without Extra")
			if first.Rarity == "Rare" then
				t.eq(first.Id, keep)
				t.eq(first.Extra, false)
			end
		end
	end)

	t.test("the shuffled bag avoids consecutive-day repeats inside one rarity", function()
		for _, ids in { catalog.Glassies.Rare, catalog.Glassies.Common, catalog.Glassies.Mythic } do
			for user = 1, 5 do
				for day = 1, 120 do
					local a = Rules.bag(ids, user, "Glassies", "R", day)[1]
					local b = Rules.bag(ids, user, "Glassies", "R", day + 1)[1]
					t.ok(a ~= b, "repeat on day " .. day)
				end
			end
		end
	end)

	t.test("today's offers lock once and survive rejoin, other servers and ownership changes", function()
		local data = profile()
		local store, fresh = Rules.today(data, 42, MIDNIGHT + 10, catalog)
		t.ok(fresh)
		local first = store.Offers[1].Id
		Schema.grantItem(data, "Glassies", first, 0)
		local moved = Schema.reconcile(Schema.copy(data), 0) -- rejoin on another server
		local again, regen = Rules.today(moved, 42, MIDNIGHT + 5000, Rules.catalog())
		t.eq(regen, false)
		t.eq(again.Offers[1].Id, first)
		local nextDay, rolled = Rules.today(moved, 42, MIDNIGHT + 86400, catalog)
		t.ok(rolled)
		t.eq(nextDay.Day, Rules.dayKey(MIDNIGHT) + 1)
	end)

	t.test("Coin purchase: one per slot/day, honest wallet and boundary checks", function()
		local data = profile()
		local now = MIDNIGHT - 1
		local store = Rules.today(data, 9, now, catalog)
		local offer = store.Offers[4]
		local grant = grantFn(data)
		t.eq(select(2, Rules.buyCoins(data, 1, store.Offers[1].Id, store.Day, now, grant)), "Choose an offer")
		t.eq(
			select(2, Rules.buyCoins(data, 4, "nope", store.Day, now, grant)),
			"The store refreshed. Check today's offers"
		)
		data.Coins = offer.Price - 1
		local ok, message = Rules.buyCoins(data, 4, offer.Id, store.Day, now, grant)
		t.eq(ok, false)
		t.eq(message, "Need 1 more coins")
		t.eq(data.Coins, offer.Price - 1)
		t.eq(Rules.owns(data, offer.Category, offer.Id), 0)
		data.Coins = offer.Price + 5
		-- One second later it is a new day: yesterday's quote is refused until today regenerates.
		ok, message = Rules.buyCoins(data, 4, offer.Id, store.Day, MIDNIGHT, grant)
		t.eq(ok, false)
		t.eq(message, "The store refreshed. Check today's offers")
		local result
		ok, result = Rules.buyCoins(data, 4, offer.Id, store.Day, now, grant)
		t.ok(ok, tostring(result))
		t.eq(data.Coins, 5)
		t.eq(Rules.owns(data, offer.Category, offer.Id), 1)
		t.ok(store.Offers[4].Purchased)
		ok, message = Rules.buyCoins(data, 4, offer.Id, store.Day, now, grant)
		t.eq(message, "Already bought today")
		t.eq(Rules.view(data, now).Offers[4].Available, false)
		t.eq(Rules.view(data, now).NextReset, MIDNIGHT)
	end)

	t.test("every reachable Robux slot and the bundle have a real product and price", function()
		for _, key in Rules.requiredProducts(catalog) do
			local category, rarity, band = string.match(key, "(%a+)/(%a+)/(%a+)")
			t.ok(Rules.product(category, rarity, band), key)
		end
		t.ok(Rules.bundleProduct(D.Bundles[1]), "bundle product")
		local seen = {}
		for _, byRarity in D.RobuxProducts do
			for _, bands in byRarity do
				for _, entry in bands do
					if entry.ProductId then
						t.ok(not seen[entry.ProductId], "product reused " .. entry.ProductId)
						seen[entry.ProductId] = true
					end
				end
			end
		end
		t.ok(not seen[D.Bundles[1].ProductId], "bundle product reused")
	end)

	t.test("missing product IDs keep Robux offers and the bundle unavailable", function()
		withConfig(false, function()
			local data = profile()
			local store = Rules.today(data, 5, MIDNIGHT, catalog)
			local view = Rules.view(data, MIDNIGHT)
			for slot = 1, 3 do
				t.eq(view.Offers[slot].Available, false)
				t.eq(view.Offers[slot].RobuxPrice, nil)
				local ok, message = Rules.beginIntent(
					data,
					"Offer",
					{ Slot = slot, Id = store.Offers[slot].Id, Day = store.Day },
					MIDNIGHT
				)
				t.eq(ok, false)
				t.eq(message, "Coming soon")
			end
			t.eq(view.Bundles[1].Available, false)
			t.eq(
				select(2, Rules.beginIntent(data, "Bundle", { Id = "hollowlight_collection" }, MIDNIGHT)),
				"Coming soon"
			)
			t.eq(next(store.Intents), nil, "no intent persisted without a product")
			local required = Rules.requiredProducts(catalog)
			t.ok(#required >= 10)
			for _, key in required do
				local category, rarity, band = string.match(key, "(%a+)/(%a+)/(%a+)")
				t.ok(D.RobuxProducts[category][rarity][band], key)
			end
		end)
	end)

	t.test("Robux receipts are idempotent and honor the original snapshot across reset", function()
		withProducts(function()
			local data = profile()
			local now = MIDNIGHT - 30
			local store = Rules.today(data, 11, now, catalog)
			local offer = store.Offers[1]
			local ok, intent = Rules.beginIntent(data, "Offer", { Slot = 1, Id = offer.Id, Day = store.Day }, now)
			t.ok(ok, tostring(intent))
			-- The receipt arrives after the reset and after today's offers rolled over.
			local later = Rules.today(data, 11, MIDNIGHT + 60, catalog)
			t.ok(later.Day ~= intent.Day)
			local before = Rules.owns(data, "Glassies", offer.Id)
			local receipt = { PurchaseId = "p-1", ProductId = intent.ProductId }
			local status = Rules.applyReceipt(data, receipt, MIDNIGHT + 61, grantFn(data))
			t.eq(status, "Granted")
			t.eq(Rules.owns(data, "Glassies", offer.Id), before + 1)
			t.eq(later.Offers[1].Purchased, false, "new day's slot untouched")
			t.eq(Rules.applyReceipt(data, receipt, MIDNIGHT + 62, grantFn(data)), "Duplicate")
			t.eq(Rules.owns(data, "Glassies", offer.Id), before + 1)
			t.eq(Rules.applyReceipt(data, { PurchaseId = "p-2", ProductId = 424242 }, 0, grantFn(data)), "NoIntent")
		end)
	end)

	t.test("open intents block other items; cancel keeps the snapshot; double prompts both grant", function()
		withProducts(function()
			local data = profile()
			local now = MIDNIGHT + 100
			local store = Rules.today(data, 12, now, catalog)
			local offer = store.Offers[2]
			local ref = { Slot = 2, Id = offer.Id, Day = store.Day }
			local _, intent = Rules.beginIntent(data, "Offer", ref, now)
			local key = tostring(intent.ProductId)
			Rules.beginIntent(data, "Offer", ref, now) -- second prompt for the same item
			t.eq(store.Intents[key].Open, 2)
			-- A different item mapped to the same product cannot overwrite the open intent.
			store.Offers[2] = table.clone(offer)
			store.Offers[2].Id = "other_item"
			local ok, message = Rules.beginIntent(data, "Offer", { Slot = 2, Id = "other_item", Day = store.Day }, now)
			t.eq(ok, false)
			t.eq(message, "Finish your earlier purchase first")
			store.Offers[2] = offer
			Rules.cancelIntent(data, intent.ProductId)
			Rules.cancelIntent(data, intent.ProductId)
			t.ok(store.Intents[key].Cancelled, "cancelled but kept")
			Rules.beginIntent(data, "Offer", ref, now)
			Rules.beginIntent(data, "Offer", ref, now)
			t.eq(
				Rules.applyReceipt(data, { PurchaseId = "a", ProductId = intent.ProductId }, now, grantFn(data)),
				"Granted"
			)
			t.eq(
				Rules.applyReceipt(data, { PurchaseId = "b", ProductId = intent.ProductId }, now, grantFn(data)),
				"Granted"
			)
			t.eq(store.Intents[key], nil)
			t.eq(Rules.owns(data, offer.Category, offer.Id), 2)
			t.ok(store.Offers[2].Purchased)
			t.eq(select(2, Rules.beginIntent(data, "Offer", ref, now)), "Already bought today")
			-- A delayed receipt after a cancel still grants the snapshot.
			local offer3 = store.Offers[3]
			local _, i3 = Rules.beginIntent(data, "Offer", { Slot = 3, Id = offer3.Id, Day = store.Day }, now)
			Rules.cancelIntent(data, i3.ProductId)
			t.eq(
				Rules.applyReceipt(data, { PurchaseId = "c", ProductId = i3.ProductId }, now, grantFn(data)),
				"Granted"
			)
			t.eq(Rules.owns(data, offer3.Category, offer3.Id), 1)
		end)
	end)

	t.test("Hollowlight bundle grants all three items and shows owned state", function()
		withProducts(function()
			local data = profile()
			local view = Rules.view(data, MIDNIGHT).Bundles[1]
			t.eq(view.Featured, true)
			t.eq(#view.Items, 3)
			t.eq(view.Available, true)
			t.eq(view.RobuxPrice, 499)
			local ok, intent = Rules.beginIntent(data, "Bundle", { Id = "hollowlight_collection" }, MIDNIGHT)
			t.ok(ok, tostring(intent))
			t.eq(
				Rules.applyReceipt(data, { PurchaseId = "h1", ProductId = intent.ProductId }, MIDNIGHT, grantFn(data)),
				"Granted"
			)
			t.eq(Rules.owns(data, "Glassies", "hollowlight"), 1)
			t.eq(Rules.owns(data, "Rideables", "lantern_skiff"), 1)
			t.eq(Rules.owns(data, "Finishers", "lantern_eclipse"), 1)
			view = Rules.view(data, MIDNIGHT).Bundles[1]
			t.eq(view.AllOwned, true)
			t.eq(view.Available, false)
			t.eq(
				select(2, Rules.beginIntent(data, "Bundle", { Id = "hollowlight_collection" }, MIDNIGHT)),
				"You already own this collection"
			)
		end)
	end)

	t.test("profiles gain the Store field additively and reconcile bad shapes", function()
		local fresh = Schema.new(0)
		t.eq(fresh.Store.Day, -1)
		local old = Schema.new(0)
		old.Store = nil
		Schema.reconcile(old, 0)
		t.eq(type(old.Store.Offers), "table")
		old.Store = { Day = "x", Offers = 3 }
		old.ProcessedReceipts = "bad"
		Schema.reconcile(old, 0)
		t.eq(old.Store.Day, -1)
		t.eq(type(old.Store.Offers), "table")
		t.eq(type(old.ProcessedReceipts), "table")
		t.eq(Schema.snapshot(fresh).Store, nil, "store bookkeeping stays private")
	end)
end
