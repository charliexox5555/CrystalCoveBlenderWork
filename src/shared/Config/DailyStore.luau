--!strict
-- Personalized daily Featured store (design/DAILY_STORE_AND_HOLLOWLIGHT.md). Pure data; the
-- selection and purchase rules live in DailyStoreRules. A missing product ID or price keeps that
-- offer visibly unavailable.

local DailyStore = {}

-- Bump to deliberately reroll unpurchased offers (e.g. after a catalog fix).
DailyStore.OfferVersion = 1

-- Reset at 00:00 UTC = 6 PM fixed CST (UTC-6) all year; no daylight-saving shift.
DailyStore.DaySeconds = 86400
DailyStore.ResetOffsetSeconds = 0

-- Three Robux slots (one per category) and one Coin slot whose category rotates daily by
-- (UserId + DayKey) % 3 through CoinCategoryRotation.
DailyStore.Slots = {
	{ Currency = "Robux", Category = "Glassies" },
	{ Currency = "Robux", Category = "Finishers" },
	{ Currency = "Robux", Category = "Rideables" },
	{ Currency = "Coins" },
}
DailyStore.CoinCategoryRotation = { "Glassies", "Finishers", "Rideables" }

-- Rarity weights (percent). Empty or ineligible buckets are renormalized away.
DailyStore.Weights = {
	Robux = { Common = 0, Uncommon = 20, Rare = 45, Epic = 30, Legendary = 4.5, Mythic = 0.5 },
	Coins = { Common = 55, Uncommon = 35, Rare = 9, Epic = 1, Legendary = 0, Mythic = 0 },
}

-- Coin price per (Category, Rarity). A direct, named item costs more than one random crate pull
-- (Glassies 300, Finishers 300, Flyers 1000). Missing prices make that rarity ineligible for Coins.
DailyStore.CoinPrices = {
	Glassies = { Common = 450, Uncommon = 900, Rare = 2000, Epic = 5000 },
	Finishers = { Common = 400, Uncommon = 600, Rare = 1200, Epic = 3000 },
	Rideables = { Common = 1200, Uncommon = 1500, Rare = 3000, Epic = 6000 },
}

-- Robux value bands within a rarity. Items not listed under Featured are Standard.
DailyStore.ValueBands = { "Standard", "Featured" }
DailyStore.FeaturedBand = {
	Glassies = { frostglobe = true, prism_blade = true, glass_dragon = true },
	Finishers = { starfall = true },
	Rideables = { prism_ray = true },
}

-- Robux product matrix keyed [Category][Rarity][ValueBand]. Each entry is its own developer
-- product (universe 10770493435, created 2026-10-17, regional pricing off so Price is what the
-- player pays). Price must match the Creator Dashboard (StoreService holds back a product whose
-- dashboard price differs). Combos no item can reach are left out. Repriced by decision 116 onto
-- the 49/99/149/199/249/299/399/599 points (docs/design/MONETIZATION.md §6); the four new products'
-- ids live in Config/ProductIds (nil = not created: those items stay out of the rotation).
local Ids = if script then require(script.Parent.ProductIds) else require("./ProductIds")
local function p(id: number?, price: number)
	return { ProductId = id, Price = price }
end
DailyStore.RobuxProducts = {
	Glassies = {
		Uncommon = { Standard = p(3719124013, 49) },
		Rare = { Standard = p(3719124035, 99), Featured = p(3719124041, 129) },
		Epic = { Standard = p(3719124045, 199), Featured = p(3719124054, 249) },
		Legendary = { Standard = p(3719124061, 399) },
		Mythic = { Standard = p(3719124065, 599), Featured = p(3719124069, 699) },
	},
	Finishers = {
		Uncommon = { Standard = p(3719124072, 49) },
		Rare = { Standard = p(3719124077, 99) },
		Epic = { Standard = p(3719124084, 149) },
		Legendary = { Featured = p(3719124089, 299) },
		Mythic = { Standard = p(Ids.FinisherMythic, 499) },
	},
	Rideables = {
		Uncommon = { Standard = p(3719124092, 79) },
		Rare = { Standard = p(3719124095, 149) },
		Epic = { Standard = p(Ids.FlyerEpic, 199), Featured = p(3719124103, 299) },
		Legendary = { Standard = p(Ids.FlyerLegendary, 399) },
		Mythic = { Standard = p(Ids.FlyerMythic, 599) },
	},
} :: { [string]: { [string]: { [string]: { ProductId: number?, Price: number? } } } }

-- Never in the ordinary daily rotation (seasonal items are sold only as bundles).
DailyStore.Excluded = {
	Glassies = { hollowlight = true },
	Finishers = { lantern_eclipse = true },
	-- carousel/sunwing/starwhale join the rotation once their products (Config/ProductIds) exist.
	Rideables = { lantern_skiff = true },
}

-- Limited bundles. The first entry with Featured = true headlines the Featured page; others are
-- sold from the bundle preview (e.g. the Hollowlight glassy on its own).
DailyStore.Bundles = {
	{
		Id = "hollowlight_collection",
		Name = "Hollowlight Collection",
		Tagline = "Halloween limited set",
		Featured = true,
		ProductId = 3719124109 :: number?,
		Price = 699 :: number?, -- decision 116 (was 499): 26% under its parts at daily-store prices (249 + 399 + 299)
		Items = {
			{ Category = "Glassies", Id = "hollowlight" },
			{ Category = "Rideables", Id = "lantern_skiff" },
			{ Category = "Finishers", Id = "lantern_eclipse" },
		},
	},
	{
		Id = "hollowlight_glassy",
		Name = "Hollowlight",
		Tagline = "Seasonal glassy",
		Featured = false,
		ProductId = 3719142095 :: number?,
		Price = 249 :: number?,
		Items = {
			{ Category = "Glassies", Id = "hollowlight" },
		},
	},
}

-- Remote pacing (seconds) and purchase bookkeeping.
DailyStore.RequestRateSeconds = 0.5
DailyStore.PurchaseRateSeconds = 1
DailyStore.ReceiptSaveTimeoutSeconds = 15
DailyStore.MaxProcessedReceipts = 200
-- An open Robux prompt's intent blocks a different item on the same product for this long, so a
-- delayed receipt (retried on rejoin) still grants the item the player saw.
DailyStore.IntentHoldSeconds = 3 * 86400

return DailyStore
