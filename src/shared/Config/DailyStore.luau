--!strict
-- Personalized daily Featured store (design/DAILY_STORE_AND_HOLLOWLIGHT.md). Pure data; the
-- selection and purchase rules live in DailyStoreRules. Robux product IDs and prices stay nil
-- until the creator supplies them: a nil entry keeps that offer visibly unavailable.

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

-- Robux product matrix keyed [Category][Rarity][ValueBand]. Each entry gets its own developer
-- product. Fill ProductId (number) and Price (Robux, shown on the card) from the Creator
-- Dashboard; both must be set for the offer to become purchasable.
local function bands()
	return {
		Standard = { ProductId = nil :: number?, Price = nil :: number? },
		Featured = { ProductId = nil :: number?, Price = nil :: number? },
	}
end
DailyStore.RobuxProducts = {} :: { [string]: { [string]: { [string]: { ProductId: number?, Price: number? } } } }
for _, category in { "Glassies", "Finishers", "Rideables" } do
	DailyStore.RobuxProducts[category] = {
		Uncommon = bands(),
		Rare = bands(),
		Epic = bands(),
		Legendary = bands(),
		Mythic = bands(),
	}
end

-- Never in the ordinary daily rotation (seasonal items are sold only as bundles).
DailyStore.Excluded = {
	Glassies = { hollowlight = true },
	Finishers = { lantern_eclipse = true },
	Rideables = { lantern_skiff = true },
}

-- Limited bundles. The first entry with Featured = true headlines the Featured page.
DailyStore.Bundles = {
	{
		Id = "hollowlight_collection",
		Name = "Hollowlight Collection",
		Tagline = "Halloween limited set",
		Featured = true,
		ProductId = nil :: number?,
		Price = nil :: number?,
		Items = {
			{ Category = "Glassies", Id = "hollowlight" },
			{ Category = "Rideables", Id = "lantern_skiff" },
			{ Category = "Finishers", Id = "lantern_eclipse" },
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
