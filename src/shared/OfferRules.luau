-- Pure rules for the Starter Pack, the Daily Glassy and Daily Marbles (Config/Offers, decision 116) and the "Need
-- Marbles" suggestion. No Roblox APIs, so Lune tests and the server share them. Profile state lives in data.Deals.
-- Purchases go through DailyStoreRules' intents and receipts (StoreService owns ProcessReceipt); this module builds
-- the intent snapshot (what the player saw) and applies it when the receipt arrives.
--
-- ctx (built by the server): { Studio = bool, PaidRandomAllowed = bool, Available = { [glassyId]: true }? }
-- Studio = true lets offers without a product id run on placeholder ids and stand-in items (never on live servers).
local O = if script then require(script.Parent.Config.Offers) else require("./Config/Offers")
local D = if script then require(script.Parent.Config.DailyStore) else require("./Config/DailyStore")
local M = if script then require(script.Parent.Config.MarbleShop) else require("./Config/MarbleShop")
local B = if script then require(script.Parent.Config.Balance) else require("./Config/Balance")
local G = if script then require(script.Parent.Config.Glassies) else require("./Config/Glassies")
local C = if script then require(script.Parent.Config.RoundCosmetics) else require("./Config/RoundCosmetics")
local Formula = if script then require(script.Parent.Formula) else require("./Formula")

local Rules = {}
Rules.Kinds = { Starter = true, DailyGlassy = true, DailyMarbles = true }
-- Fake product ids for Studio runs of offers that have no product yet (never prompted; StoreService fakes the receipt).
Rules.StudioProductIds = { Starter = 1, DailyGlassy = 2, DailyMarbles = 3 }

local function config(kind)
	return if kind == "Starter" then O.StarterPack elseif kind == "DailyGlassy" then O.DailyGlassy else O.DailyMarbles
end

function Rules.dayKey(now: number): number
	return math.floor((now - D.ResetOffsetSeconds) / D.DaySeconds)
end
function Rules.nextReset(now: number): number
	return (Rules.dayKey(now) + 1) * D.DaySeconds + D.ResetOffsetSeconds
end

local function integer(value, fallback)
	return if type(value) == "number" and value == value and value % 1 == 0 then value else fallback
end

function Rules.reconcile(data)
	local deals = if type(data.Deals) == "table" then data.Deals else {}
	data.Deals = deals
	deals.StarterBought = deals.StarterBought == true
	deals.StarterSeenAt = if type(deals.StarterSeenAt) == "number" then deals.StarterSeenAt else nil
	deals.StarterAutoShown = math.max(0, integer(deals.StarterAutoShown, 0))
	deals.DailyGlassyDay = integer(deals.DailyGlassyDay, -1)
	deals.DailyMarblesStep = math.clamp(integer(deals.DailyMarblesStep, 0), 0, #O.DailyMarbles.Amounts)
	deals.DailyMarblesDay = integer(deals.DailyMarblesDay, -1)
	return deals
end

local function definition(category, id)
	if type(category) ~= "string" or type(id) ~= "string" then
		return nil
	end
	if category == "Glassies" then
		return G.ById[id]
	end
	return C.ByCategory[category] and C.ByCategory[category][id]
end
Rules.definition = definition

local function validProduct(entry)
	local id, price = entry.ProductId, entry.Price
	if type(id) == "number" and id > 0 and id % 1 == 0 and type(price) == "number" and price > 0 then
		return { ProductId = id, Price = price }
	end
	return nil
end

-- The product a kind is sold through, or nil (SOON). In Studio a missing product runs on a placeholder id.
function Rules.product(kind, ctx)
	local entry = config(kind)
	local product = validProduct(entry)
	if product then
		return product
	end
	if ctx and ctx.Studio and type(entry.Price) == "number" then
		return { ProductId = Rules.StudioProductIds[kind], Price = entry.Price, Placeholder = true }
	end
	return nil
end

-- Ids that are only sold in the Starter Pack: [category][id] = true. Kept out of the daily store (DailyStoreRules).
function Rules.exclusive(category, id)
	for _, item in O.StarterPack.Items do
		if item.Category == category and item.Id == id then
			return true
		end
	end
	return false
end

-- The pack's items as granted: { Category, Id, Rarity }. nil while an item has no definition (the pack shows SOON).
-- `_studio` is kept for callers; the Daybreak set exists everywhere now (decision 117).
function Rules.starterItems(_studio)
	local out = {}
	for _, item in O.StarterPack.Items do
		local def = definition(item.Category, item.Id)
		if not def then
			return nil
		end
		table.insert(out, { Category = item.Category, Id = item.Id, Rarity = def.Rarity })
	end
	return out
end

-- What the same thing costs elsewhere in the game, in Robux. Items: the daily store's Standard price for that
-- category and rarity (Featured if there is no Standard). Marbles: the smallest pack's rate. 0 when unknown.
function Rules.referencePrice(category, rarity)
	local byRarity = D.RobuxProducts[category] and D.RobuxProducts[category][rarity]
	local entry = byRarity and (byRarity.Standard or byRarity.Featured)
	return if entry and type(entry.Price) == "number" then entry.Price else 0
end
function Rules.baseRate(): number
	local base
	for _, pack in M.Packs do
		if not base or pack.Price < base.Price then
			base = pack
		end
	end
	return if base then base.Price / base.Marbles else 1
end
function Rules.marbleValue(marbles: number): number
	return math.floor(marbles * Rules.baseRate() + 0.5)
end

-- Honest value: the sum of what each part costs on its own. Off is rounded down so the claim is never overstated.
function Rules.starterValue(items)
	local parts, total = {}, 0
	for _, item in items or {} do
		local value = Rules.referencePrice(item.Category, item.Rarity)
		table.insert(parts, { Category = item.Category, Id = item.Id, Value = value })
		total += value
	end
	local marbles = Rules.marbleValue(O.StarterPack.Marbles)
	table.insert(parts, { Category = "Marbles", Value = marbles, Marbles = O.StarterPack.Marbles })
	total += marbles
	local off = if total > 0 then math.max(0, math.floor((1 - O.StarterPack.Price / total) * 100)) else 0
	return { Total = total, Off = off, Parts = parts }
end

local function starterEnds(deals)
	local hours = O.StarterPack.WindowHours
	return if hours and deals.StarterSeenAt then deals.StarterSeenAt + hours * 3600 else nil
end

-- The window starts the first time the server shows the pack (first spawn).
function Rules.markStarterSeen(data, now)
	local deals = Rules.reconcile(data)
	if not deals.StarterBought and not deals.StarterSeenAt then
		deals.StarterSeenAt = now
		return true
	end
	return false
end

function Rules.starterAutoOpen(data, now)
	local deals = Rules.reconcile(data)
	local ends = starterEnds(deals)
	if deals.StarterBought or (ends and now >= ends) or deals.StarterAutoShown >= O.StarterPack.AutoOpenMax then
		return false
	end
	if deals.StarterAutoShown == 0 then
		return true
	end
	return ends ~= nil and ends - now <= O.StarterPack.AutoOpenLastHours * 3600
end

-- The client opened the pack by itself. A first open already inside the last day uses up both.
function Rules.noteAutoOpen(data, now)
	if not Rules.starterAutoOpen(data, now) then
		return false
	end
	local deals = data.Deals
	local ends = starterEnds(deals)
	deals.StarterAutoShown += 1
	if ends and ends - now <= O.StarterPack.AutoOpenLastHours * 3600 then
		deals.StarterAutoShown = O.StarterPack.AutoOpenMax
	end
	return true
end

function Rules.starterState(data, now, ctx)
	local deals = Rules.reconcile(data)
	local items = Rules.starterItems(ctx and ctx.Studio)
	local ends = starterEnds(deals)
	local expired = ends ~= nil and now >= ends
	local product = items and Rules.product("Starter", ctx)
	return {
		Visible = not deals.StarterBought and not expired,
		Available = not deals.StarterBought and not expired and product ~= nil,
		Bought = deals.StarterBought,
		EndsAt = ends,
		Price = O.StarterPack.Price,
		Marbles = O.StarterPack.Marbles,
		Items = items or O.StarterPack.Items,
		Value = Rules.starterValue(items),
		AutoOpen = Rules.starterAutoOpen(data, now),
	}
end

-- Daily Glassy odds per glassy: rarity weight (renormalized over rarities with glassies), split evenly inside it.
-- `available` = the server's installed Kiln glassies (nil in tests: every Kiln glassy).
function Rules.dailyGlassyRarities(available)
	local rows, total = {}, 0
	for rarity, weight in O.DailyGlassy.Weights do
		local pool = Formula.kilnPool(rarity, available)
		if weight > 0 and #pool > 0 then
			table.insert(rows, { Rarity = rarity, Weight = weight, Pool = pool })
			total += weight
		end
	end
	table.sort(rows, function(a, b)
		return B.Rarities[a.Rarity].Order < B.Rarities[b.Rarity].Order
	end)
	for _, row in rows do
		row.Chance = row.Weight / total
	end
	return rows
end
function Rules.dailyGlassyOdds(available)
	local out = {}
	for _, row in Rules.dailyGlassyRarities(available) do
		for _, id in row.Pool do
			table.insert(out, { Id = id, Rarity = row.Rarity, Chance = row.Chance / #row.Pool })
		end
	end
	return out
end

-- One draw from an odds list { { Id, Chance } } (chances sum to 1).
function Rules.roll(odds, rng)
	local draw, acc = rng(), 0
	for _, entry in odds do
		acc += entry.Chance
		if draw < acc then
			return entry.Id
		end
	end
	return odds[#odds].Id
end

function Rules.dailyGlassyState(data, now, ctx)
	local deals = Rules.reconcile(data)
	local allowed = ctx ~= nil and ctx.PaidRandomAllowed == true
	local bought = deals.DailyGlassyDay == Rules.dayKey(now)
	return {
		Visible = allowed,
		Available = allowed and not bought and Rules.product("DailyGlassy", ctx) ~= nil,
		BoughtToday = bought,
		Price = O.DailyGlassy.Price,
		Rarities = if allowed then Rules.dailyGlassyRarities(ctx.Available) else {},
		NextReset = Rules.nextReset(now),
	}
end

-- Daily Marbles: the amount the next buy gives and its 1-based step in Amounts.
function Rules.dailyMarblesNext(data)
	local deals = Rules.reconcile(data)
	local amounts = O.DailyMarbles.Amounts
	local step = math.min(deals.DailyMarblesStep + 1, #amounts)
	return amounts[step], step
end

-- Bonus over the smallest pack's rate, in whole percent (rounded down).
function Rules.bonus(marbles, price)
	return math.max(0, math.floor((marbles * Rules.baseRate() / price - 1) * 100))
end

function Rules.dailyMarblesState(data, now, ctx)
	local deals = Rules.reconcile(data)
	local amount, step = Rules.dailyMarblesNext(data)
	local bought = deals.DailyMarblesDay == Rules.dayKey(now)
	return {
		Available = not bought and Rules.product("DailyMarbles", ctx) ~= nil,
		BoughtToday = bought,
		Step = step, -- the step the next buy is on (shown as "Day N")
		Done = deals.DailyMarblesStep, -- buys so far, capped at #Amounts
		Next = amount,
		Amounts = O.DailyMarbles.Amounts,
		Price = O.DailyMarbles.Price,
		Bonus = Rules.bonus(amount, O.DailyMarbles.Price),
		NextReset = Rules.nextReset(now),
	}
end

-- The cheapest way to cover `shortfall` Marbles: today's Daily Marbles when it covers it, else the smallest pack that
-- does, else the biggest pack. `daily` = a dailyMarblesState (what is on sale today); `held(pack)` = true for a pack
-- the server holds back. nil when nothing is on sale.
function Rules.suggest(shortfall, daily, held)
	if daily and daily.Available and daily.Next >= shortfall then
		return { Kind = "DailyMarbles", Marbles = daily.Next, Price = daily.Price }
	end
	local best, biggest
	for _, pack in M.Packs do
		if validProduct(pack) and not (held and held(pack)) then
			if pack.Marbles >= shortfall and (not best or pack.Marbles < best.Marbles) then
				best = pack
			end
			if not biggest or pack.Marbles > biggest.Marbles then
				biggest = pack
			end
		end
	end
	local pack = best or biggest
	return if pack then { Kind = "Pack", Id = pack.Id, Marbles = pack.Marbles, Price = pack.Price } else nil
end

local function fail(message)
	return false, message
end

-- Snapshot of what the player is buying, saved before the Robux prompt. Returns ok, intent | message, product.
function Rules.intent(data, kind, now, ctx)
	if not Rules.Kinds[kind] then
		return fail("Choose an offer")
	end
	local deals = Rules.reconcile(data)
	local today = Rules.dayKey(now)
	local intent
	if kind == "Starter" then
		local state = Rules.starterState(data, now, ctx)
		if state.Bought then
			return fail("You already have the Starter Pack")
		elseif not state.Visible then
			return fail("The Starter Pack has ended")
		end
		local items = Rules.starterItems(ctx and ctx.Studio)
		if not items then
			return fail("Coming soon")
		end
		intent = { Kind = "Starter", Items = items, Marbles = O.StarterPack.Marbles }
	elseif kind == "DailyGlassy" then
		if not (ctx and ctx.PaidRandomAllowed == true) then
			return fail("This offer is unavailable for your account")
		end
		if deals.DailyGlassyDay == today then
			return fail("Come back tomorrow for another")
		end
		local odds = Rules.dailyGlassyOdds(ctx.Available)
		if #odds == 0 then
			return fail("Coming soon")
		end
		local snapshot = {}
		for i, entry in odds do
			snapshot[i] = { Id = entry.Id, Chance = entry.Chance }
		end
		intent = { Kind = "DailyGlassy", Day = today, Odds = snapshot }
	else
		if deals.DailyMarblesDay == today then
			return fail("Come back tomorrow for more")
		end
		local amount, step = Rules.dailyMarblesNext(data)
		intent = { Kind = "DailyMarbles", Day = today, Marbles = amount, Step = step }
	end
	local product = Rules.product(kind, ctx)
	if not product then
		return fail("Coming soon")
	end
	return true, intent, product
end

-- Applies a paid intent (once per receipt; DailyStoreRules guards PurchaseIds). `grant(category, id)` grants one
-- item; `rng` draws the Daily Glassy. A second paid receipt the same day still grants (Roblox has charged), but
-- Daily Marbles only moves one step per day.
function Rules.apply(data, intent, now, grant, rng)
	local deals = Rules.reconcile(data)
	local grants = {}
	if intent.Kind == "Starter" then
		for _, item in intent.Items do
			table.insert(grants, grant(item.Category, item.Id))
		end
		data.Marbles = (data.Marbles or 0) + intent.Marbles
		table.insert(grants, { Marbles = intent.Marbles })
		deals.StarterBought = true
	elseif intent.Kind == "DailyGlassy" then
		local id = Rules.roll(intent.Odds, rng)
		table.insert(grants, grant("Glassies", id))
		deals.DailyGlassyDay = math.max(deals.DailyGlassyDay, intent.Day)
	elseif intent.Kind == "DailyMarbles" then
		data.Marbles = (data.Marbles or 0) + intent.Marbles
		table.insert(grants, { Marbles = intent.Marbles })
		if deals.DailyMarblesDay < intent.Day then
			deals.DailyMarblesStep = math.min(deals.DailyMarblesStep + 1, #O.DailyMarbles.Amounts)
			deals.DailyMarblesDay = intent.Day
		end
	end
	return grants
end

-- Everything the client shows for these offers.
function Rules.view(data, now, ctx)
	return {
		Starter = Rules.starterState(data, now, ctx),
		DailyGlassy = Rules.dailyGlassyState(data, now, ctx),
		DailyMarbles = Rules.dailyMarblesState(data, now, ctx),
		NextReset = Rules.nextReset(now),
	}
end

return Rules
