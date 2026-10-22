-- Pure daily Featured store rules: deterministic per-player/day offers, Coin purchases and
-- Robux purchase intents/receipts. No Roblox APIs, so Lune tests and the server share them.
-- Profile state lives in data.Store; receipts are remembered in data.ProcessedReceipts.
local D = if script then require(script.Parent.Config.DailyStore) else require("./Config/DailyStore")
local B = if script then require(script.Parent.Config.Balance) else require("./Config/Balance")
local G = if script then require(script.Parent.Config.Glassies) else require("./Config/Glassies")
local C = if script then require(script.Parent.Config.RoundCosmetics) else require("./Config/RoundCosmetics")
local Rng = if script then require(script.Parent.Rng) else require("./Rng")
local M = if script then require(script.Parent.Config.MarbleShop) else require("./Config/MarbleShop")
-- Starter Pack, Daily Glassy and Daily Marbles intents (decision 116) are built and applied by OfferRules.
local Offers = if script then require(script.Parent.OfferRules) else require("./OfferRules")

local Rules = {}
Rules.Categories = { "Glassies", "Finishers", "Rideables" }

local TWO32 = 4294967296
-- FNV-1a (32-bit) over a string; the multiply is split so it stays exact in doubles.
function Rules.hash(...): number
	local text = table.concat(table.pack(...) :: any, "|")
	local h = 2166136261
	for i = 1, #text do
		h = bit32.bxor(h, string.byte(text, i))
		h = (h * 403 + bit32.lshift(h, 24)) % TWO32
	end
	return h
end
local function rng(...)
	local r = Rng.new(Rules.hash(...) % 2147483646 + 1)
	r()
	return r
end

function Rules.dayKey(now: number): number
	return math.floor((now - D.ResetOffsetSeconds) / D.DaySeconds)
end
function Rules.nextReset(now: number): number
	return (Rules.dayKey(now) + 1) * D.DaySeconds + D.ResetOffsetSeconds
end

local function rarityOrder(rarity)
	return B.Rarities[rarity] and B.Rarities[rarity].Order or 99
end
local rarityList = {}
for rarity, info in B.Rarities do
	if rarity ~= "Starter" then
		table.insert(rarityList, rarity)
	end
end
table.sort(rarityList, function(a, b)
	return rarityOrder(a) < rarityOrder(b)
end)
Rules.Rarities = rarityList

function Rules.definition(category, id)
	if type(category) ~= "string" or type(id) ~= "string" then
		return nil
	end
	if category == "Glassies" then
		return G.ById[id]
	end
	return C.ByCategory[category] and C.ByCategory[category][id]
end

-- Canonical eligible catalog: [category][rarity] = sorted ids. `installed(category, id)` may
-- return false to drop items whose art is missing in this server.
function Rules.catalog(installed)
	local out = {}
	local function add(category, def)
		if (D.Excluded[category] and D.Excluded[category][def.Id]) or Offers.exclusive(category, def.Id) then
			return
		end
		if installed and not installed(category, def.Id) then
			return
		end
		out[category][def.Rarity] = out[category][def.Rarity] or {}
		table.insert(out[category][def.Rarity], def.Id)
	end
	out.Glassies = {}
	for _, def in G.ReleaseList do
		if def.Rarity ~= "Starter" and not G.isSeasonal(def.Id) then
			add("Glassies", def)
		end
	end
	for _, category in { "Finishers", "Rideables" } do
		out[category] = {}
		for _, def in C[category] do
			-- Free starter cosmetics are never sold, and an item whose rarity and band have no created Robux product
			-- yet (Config/ProductIds still nil) stays out of the daily store until it has one.
			local priced = def.Rarity and Rules.product(category, def.Rarity, Rules.valueBand(category, def.Id))
			if def.Matches ~= 0 and priced then
				add(category, def)
			end
		end
	end
	for _, buckets in out do
		for _, ids in buckets do
			table.sort(ids)
		end
	end
	return out
end

function Rules.owns(data, category, id): number
	if category == "Glassies" then
		local owned = data.Glassies and data.Glassies[id]
		return if type(owned) == "table" then math.max(1, owned.Count or 1) else 0
	end
	local cosmetics = data.Cosmetics or {}
	local counts = cosmetics.Counts and cosmetics.Counts[category]
	local count = counts and counts[id]
	if type(count) == "number" then
		return count
	end
	return if table.find(cosmetics[category] or {}, id) then 1 else 0
end

function Rules.valueBand(category, id)
	return if D.FeaturedBand[category] and D.FeaturedBand[category][id] then "Featured" else "Standard"
end
function Rules.coinPrice(category, rarity)
	local price = D.CoinPrices[category] and D.CoinPrices[category][rarity]
	return if type(price) == "number" and price > 0 and price % 1 == 0 then price else nil
end
local function validProduct(entry)
	if type(entry) ~= "table" then
		return nil
	end
	local id, price = entry.ProductId, entry.Price
	if type(id) == "number" and id > 0 and id % 1 == 0 and type(price) == "number" and price > 0 then
		return { ProductId = id, Price = price }
	end
	return nil
end
function Rules.product(category, rarity, band)
	local byRarity = D.RobuxProducts[category] and D.RobuxProducts[category][rarity]
	return validProduct(byRarity and byRarity[band])
end
function Rules.bundle(id)
	for _, bundle in D.Bundles do
		if bundle.Id == id then
			return bundle
		end
	end
	return nil
end
function Rules.bundleProduct(bundle)
	return validProduct(bundle)
end
function Rules.marblePack(id)
	for _, pack in M.Packs do
		if pack.Id == id then
			return pack
		end
	end
	return nil
end
function Rules.packProduct(pack)
	return validProduct(pack)
end

-- Deterministic shuffled bag per player/category/rarity: walking one item per day through a
-- shuffled order avoids repeats on consecutive days that land in the same rarity.
local function shuffled(ids, userId, category, rarity, cycle)
	local order = table.clone(ids)
	local r = rng("bag", D.OfferVersion, userId, category, rarity, cycle)
	for i = #order, 2, -1 do
		local j = math.floor(r() * i) + 1
		order[i], order[j] = order[j], order[i]
	end
	return order
end
function Rules.bag(ids, userId, category, rarity, day)
	local n = #ids
	if n <= 2 then
		local start = Rules.hash("pair", userId, category, rarity) % math.max(n, 1)
		local order = {}
		for k = 0, n - 1 do
			order[k + 1] = ids[(day + start + k) % n + 1]
		end
		return order
	end
	local cycle, pos = day // n, day % n
	local order = shuffled(ids, userId, category, rarity, cycle)
	local previous = shuffled(ids, userId, category, rarity, cycle - 1)
	if order[1] == previous[n] then
		order[1], order[2] = order[2], order[1]
	end
	local out = {}
	for k = 0, n - 1 do
		out[k + 1] = order[(pos + k) % n + 1]
	end
	return out
end

function Rules.slotCategory(slot, userId, day)
	local def = D.Slots[slot]
	if def.Category then
		return def.Category
	end
	local rotation = D.CoinCategoryRotation
	return rotation[(userId + day) % #rotation + 1]
end

-- One offer for one slot, or an Empty placeholder when nothing is eligible.
function Rules.pick(slot, userId, day, catalog, owns, used)
	local def = D.Slots[slot]
	local currency = def.Currency
	local category = Rules.slotCategory(slot, userId, day)
	local weights = D.Weights[currency]
	local buckets, total = {}, 0
	for _, rarity in rarityList do
		local ids = catalog[category] and catalog[category][rarity]
		local weight = weights[rarity] or 0
		if currency == "Coins" and not Rules.coinPrice(category, rarity) then
			weight = 0
		end
		local free = false
		for _, id in ids or {} do
			free = free or not used[category .. ":" .. id]
		end
		if weight > 0 and free then
			table.insert(buckets, { Rarity = rarity, Weight = weight, Ids = ids })
			total += weight
		end
	end
	if total <= 0 then
		return { Slot = slot, Currency = currency, Category = category, Empty = true }
	end
	local r = rng("slot", D.OfferVersion, userId, day, slot)
	local draw, chosen = r() * total, buckets[#buckets]
	for _, bucket in buckets do
		draw -= bucket.Weight
		if draw < 0 then
			chosen = bucket
			break
		end
	end
	local pickId, fallback
	for _, id in Rules.bag(chosen.Ids, userId, category, chosen.Rarity, day) do
		if not used[category .. ":" .. id] then
			if owns(category, id) == 0 then
				pickId = id
				break
			end
			fallback = fallback or id
		end
	end
	local id = pickId or fallback
	used[category .. ":" .. id] = true
	return {
		Slot = slot,
		Currency = currency,
		Category = category,
		Id = id,
		Rarity = chosen.Rarity,
		ValueBand = if currency == "Robux" then Rules.valueBand(category, id) else nil,
		Price = if currency == "Coins" then Rules.coinPrice(category, chosen.Rarity) else nil,
		Extra = pickId == nil, -- every eligible item was already owned: an extra copy
		Purchased = false,
	}
end

function Rules.generate(userId, day, catalog, owns)
	local used, offers = {}, {}
	owns = owns or function()
		return 0
	end
	for slot in D.Slots do
		offers[slot] = Rules.pick(slot, userId, day, catalog, owns, used)
	end
	return offers
end

function Rules.reconcile(data)
	local store = data.Store
	if type(store) ~= "table" then
		store = {}
		data.Store = store
	end
	store.Version = if type(store.Version) == "number" then store.Version else 0
	store.Day = if type(store.Day) == "number" then store.Day else -1
	store.Offers = if type(store.Offers) == "table" then store.Offers else {}
	store.Intents = if type(store.Intents) == "table" then store.Intents else {}
	store.Bundles = if type(store.Bundles) == "table" then store.Bundles else {}
	Offers.reconcile(data)
	data.ProcessedReceipts = if type(data.ProcessedReceipts) == "table" then data.ProcessedReceipts else {}
	return store
end

local function anyPurchased(store)
	for _, offer in store.Offers do
		if offer.Purchased then
			return true
		end
	end
	return false
end

-- Today's locked offers. Generated once per day from the ownership at that moment; later
-- ownership changes, reconnects or other servers never reroll them. Returns store, regenerated.
function Rules.today(data, userId, now, catalog)
	local store = Rules.reconcile(data)
	local day = Rules.dayKey(now)
	if store.Day == day and (store.Version == D.OfferVersion or anyPurchased(store)) and #store.Offers == #D.Slots then
		return store, false
	end
	store.Day, store.Version = day, D.OfferVersion
	store.Offers = Rules.generate(userId, day, catalog, function(category, id)
		return Rules.owns(data, category, id)
	end)
	return store, true
end

local function fail(message)
	return false, message
end

-- One Coin purchase per slot per day; the caller re-generates today first and grants through
-- `grant(category, id)`. Debit, mark and grant happen without yielding.
function Rules.buyCoins(data, slot, expectedId, expectedDay, now, grant)
	local store = Rules.reconcile(data)
	if type(slot) ~= "number" or slot % 1 ~= 0 or type(expectedId) ~= "string" or type(expectedDay) ~= "number" then
		return fail("Choose an offer")
	end
	if store.Day ~= Rules.dayKey(now) or expectedDay ~= store.Day then
		return fail("The store refreshed. Check today's offers")
	end
	local offer = store.Offers[slot]
	if type(offer) ~= "table" or offer.Empty or offer.Currency ~= "Coins" then
		return fail("Choose an offer")
	end
	if offer.Id ~= expectedId then
		return fail("The store refreshed. Check today's offers")
	end
	if offer.Purchased then
		return fail("Already bought today")
	end
	local price = offer.Price
	if not Rules.definition(offer.Category, offer.Id) or type(price) ~= "number" or price <= 0 or price % 1 ~= 0 then
		return fail("This offer is unavailable")
	end
	if (data.Coins or 0) < price then
		return fail("Need " .. (price - (data.Coins or 0)) .. " more coins")
	end
	data.Coins -= price
	offer.Purchased, offer.PurchasedAt = true, now
	return true, { Offer = offer, Price = price, Grant = grant(offer.Category, offer.Id) }
end

local function sameItem(a, b)
	return a.Kind == b.Kind
		and a.Id == b.Id
		and a.Day == b.Day
		and a.Slot == b.Slot
		and a.BundleId == b.BundleId
		and a.PackId == b.PackId
end

-- Persist what a Robux prompt is for before prompting. kind "Offer": ref = { Slot, Id, Day };
-- kind "Bundle": ref = { Id }; kind "Marbles": ref = { Id } (a Marble pack); kinds "Starter", "DailyGlassy" and
-- "DailyMarbles": ref = the OfferRules ctx. An unresolved intent for another item is never overwritten; an
-- OfferRules kind always refreshes its own snapshot (one product per kind, so it is always the same item).
function Rules.beginIntent(data, kind, ref, now)
	local store = Rules.reconcile(data)
	if type(ref) ~= "table" then
		return fail("Choose an offer")
	end
	local intent, product
	if kind == "Offer" then
		local offer = type(ref.Slot) == "number" and store.Offers[ref.Slot]
		if
			type(offer) ~= "table"
			or offer.Empty
			or offer.Currency ~= "Robux"
			or offer.Id ~= ref.Id
			or ref.Day ~= store.Day
			or store.Day ~= Rules.dayKey(now)
		then
			return fail("The store refreshed. Check today's offers")
		end
		if offer.Purchased then
			return fail("Already bought today")
		end
		product = Rules.product(offer.Category, offer.Rarity, offer.ValueBand)
		intent = {
			Kind = "Offer",
			Day = store.Day,
			Slot = ref.Slot,
			Category = offer.Category,
			Id = offer.Id,
			Rarity = offer.Rarity,
			ValueBand = offer.ValueBand,
		}
	elseif kind == "Bundle" then
		local bundle = type(ref.Id) == "string" and Rules.bundle(ref.Id)
		if not bundle then
			return fail("Choose an offer")
		end
		local missing = false
		for _, item in bundle.Items do
			missing = missing or Rules.owns(data, item.Category, item.Id) == 0
		end
		if not missing then
			return fail("You already own this collection")
		end
		product = Rules.bundleProduct(bundle)
		intent = { Kind = "Bundle", BundleId = bundle.Id, Items = table.clone(bundle.Items) }
		for i, item in intent.Items do
			intent.Items[i] = table.clone(item)
		end
	elseif Offers.Kinds[kind] then
		local ok, made, offerProduct = Offers.intent(data, kind, now, ref)
		if not ok then
			return fail(made)
		end
		intent, product = made, offerProduct
	elseif kind == "Marbles" then
		local pack = type(ref.Id) == "string" and Rules.marblePack(ref.Id)
		if not pack then
			return fail("Choose a pack")
		end
		product = Rules.packProduct(pack)
		intent = { Kind = "Marbles", PackId = pack.Id, Marbles = pack.Marbles }
	else
		return fail("Choose an offer")
	end
	if not product then
		return fail("Coming soon")
	end
	intent.ProductId, intent.Price, intent.CreatedAt, intent.Open = product.ProductId, product.Price, now, 1
	local key = tostring(product.ProductId)
	local existing = store.Intents[key]
	if existing and Offers.Kinds[intent.Kind] and existing.Kind == intent.Kind then
		intent.Open = (if existing.Cancelled then 0 else existing.Open or 0) + 1
		store.Intents[key] = intent
		return true, intent
	end
	if existing then
		if sameItem(existing, intent) then
			existing.Open = (existing.Cancelled and 0 or existing.Open or 0) + 1
			existing.Cancelled = nil
			return true, existing
		end
		if not existing.Cancelled and now - (existing.CreatedAt or 0) < D.IntentHoldSeconds then
			return fail("Finish your earlier purchase first")
		end
	end
	store.Intents[key] = intent
	return true, intent
end

-- The prompt closed without buying. Keep the snapshot so a delayed receipt is still honored.
function Rules.cancelIntent(data, productId)
	local store = Rules.reconcile(data)
	local intent = store.Intents[tostring(productId)]
	if intent then
		intent.Open = math.max(0, (intent.Open or 1) - 1)
		intent.Cancelled = intent.Open == 0 or nil
	end
	return intent
end

-- Idempotent receipt application. Returns "Granted", "Duplicate" or "NoIntent" plus details. The Daily Glassy draw
-- uses `draw` when given, else a generator seeded by the PurchaseId (unknown before the purchase).
function Rules.applyReceipt(data, receipt, now, grant, draw)
	local store = Rules.reconcile(data)
	local purchaseId = type(receipt) == "table" and receipt.PurchaseId
	if type(purchaseId) ~= "string" or purchaseId == "" then
		return "NoIntent", nil
	end
	if data.ProcessedReceipts[purchaseId] then
		return "Duplicate", nil
	end
	local key = tostring(receipt.ProductId)
	local intent = store.Intents[key]
	if not intent then
		return "NoIntent", nil
	end
	local grants = {}
	if intent.Kind == "Offer" then
		table.insert(grants, grant(intent.Category, intent.Id))
		local offer = store.Offers[intent.Slot]
		if store.Day == intent.Day and type(offer) == "table" and offer.Id == intent.Id then
			offer.Purchased, offer.PurchasedAt = true, now
		end
	elseif intent.Kind == "Marbles" then
		data.Marbles = (data.Marbles or 0) + intent.Marbles
		table.insert(grants, { Marbles = intent.Marbles })
	elseif Offers.Kinds[intent.Kind] then
		grants = Offers.apply(data, intent, now, grant, draw or rng("receipt", purchaseId))
	else
		for _, item in intent.Items do
			table.insert(grants, grant(item.Category, item.Id))
		end
		store.Bundles[intent.BundleId] = (store.Bundles[intent.BundleId] or 0) + 1
	end
	data.ProcessedReceipts[purchaseId] = now
	local count, oldestId, oldestAt = 0, nil, math.huge
	for id, at in data.ProcessedReceipts do
		count += 1
		if type(at) ~= "number" or at < oldestAt then
			oldestId, oldestAt = id, if type(at) == "number" then at else -math.huge
		end
	end
	if count > D.MaxProcessedReceipts and oldestId then
		data.ProcessedReceipts[oldestId] = nil
	end
	intent.Open = math.max(0, (intent.Open or 1) - 1)
	if intent.Open == 0 then
		store.Intents[key] = nil
	end
	return "Granted", { Intent = intent, Grants = grants }
end

-- Client view of today's offers and the featured bundle; ownership is read live.
function Rules.view(data, now)
	local store = Rules.reconcile(data)
	local view = { Day = store.Day, NextReset = Rules.nextReset(now), Offers = {}, Bundles = {} }
	for slot, offer in store.Offers do
		local entry = table.clone(offer)
		if not offer.Empty then
			entry.Owned = Rules.owns(data, offer.Category, offer.Id)
			if offer.Currency == "Robux" then
				local product = Rules.product(offer.Category, offer.Rarity, offer.ValueBand)
				entry.RobuxPrice = product and product.Price
				entry.Available = product ~= nil and not offer.Purchased
			else
				entry.Available = not offer.Purchased and Rules.definition(offer.Category, offer.Id) ~= nil
			end
		end
		view.Offers[slot] = entry
	end
	for _, bundle in D.Bundles do
		local items, allOwned = {}, true
		for _, item in bundle.Items do
			local owned = Rules.owns(data, item.Category, item.Id)
			allOwned = allOwned and owned > 0
			table.insert(items, { Category = item.Category, Id = item.Id, Owned = owned })
		end
		local product = Rules.bundleProduct(bundle)
		table.insert(view.Bundles, {
			Id = bundle.Id,
			Name = bundle.Name,
			Tagline = bundle.Tagline,
			Featured = bundle.Featured == true,
			Items = items,
			AllOwned = allOwned,
			RobuxPrice = product and product.Price,
			Available = product ~= nil and not allOwned,
		})
	end
	return view
end

-- Marble packs for the client grid (config is shared; availability = product configured).
function Rules.marblePacks()
	local out = {}
	for _, pack in M.Packs do
		local product = Rules.packProduct(pack)
		table.insert(out, {
			Id = pack.Id,
			Name = pack.Name,
			Marbles = pack.Marbles,
			-- Shown on the card; computed from the smallest pack's rate so it is always true.
			Bonus = if product then Offers.bonus(pack.Marbles, product.Price) else 0,
			Art = pack.Art,
			RobuxPrice = product and product.Price,
			Available = product ~= nil,
		})
	end
	return out
end

-- Every (Category, Rarity, ValueBand) a Robux slot can actually show, for the creator's
-- product/price checklist.
function Rules.requiredProducts(catalog)
	local keys, seen = {}, {}
	for slot, def in D.Slots do
		if def.Currency == "Robux" then
			for rarity, ids in catalog[def.Category] or {} do
				if (D.Weights.Robux[rarity] or 0) > 0 then
					for _, id in ids do
						local key = def.Category .. "/" .. rarity .. "/" .. Rules.valueBand(def.Category, id)
						if not seen[key] then
							seen[key] = true
							table.insert(keys, key)
						end
					end
				end
			end
		end
	end
	table.sort(keys)
	return keys
end

return Rules
