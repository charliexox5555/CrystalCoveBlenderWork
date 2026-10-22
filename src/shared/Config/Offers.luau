--!strict
-- Robux offers outside the daily Featured store (decision 116, docs/design/MONETIZATION.md): the Starter Pack, the
-- Daily Glassy and Daily Marbles, plus the "Need Marbles" suggestion. Pure data; rules live in OfferRules and the
-- receipts go through StoreService like every other product. Product ids live in Config/ProductIds.
local Ids = if script then require(script.Parent.ProductIds) else require("./ProductIds")

local Offers = {}

-- Starter Pack: one per player ever, 49 R$ (creator). Three exclusive items (never in the Kiln, crates or the daily
-- store) and Marbles. The glassy sits on the normal rarity edge (decision 86), so it is not stronger than anything
-- free. Shown from the first spawn (Roblox starter-pack guide) for WindowHours after the player first sees it.
Offers.StarterPack = {
	ProductId = Ids.StarterPack,
	Price = 49,
	Marbles = 150,
	-- The Daybreak set (Glassies.StarterPackIds, RoundCosmetics.StarterPack): all three Epic. An id without a
	-- definition keeps the pack at SOON on live servers.
	Items = {
		{ Category = "Glassies", Id = "sunny_rooster" },
		{ Category = "Finishers", Id = "daybreak" },
		{ Category = "Rideables", Id = "dawn_kite" },
	},
	-- Studio only: existing items granted in place of exclusives that are not built yet, so the flow can be tested.
	StudioStandIns = { Glassies = "frostglobe", Finishers = "bubble_bloom", Rideables = "rocket_skiff" },
	WindowHours = 72, -- Roblox recommends 24 h to 3 days; nil = no end
	-- The pack opens by itself at most twice: once back in the lobby after onboarding, once in its last day.
	AutoOpenLastHours = 24,
	AutoOpenMax = 2,
}

-- Daily Glassy: one random glassy a day for 9 R$ (creator), from the Kiln's pool. A paid random item: odds are shown
-- before every purchase and the offer is hidden where PolicyService restricts paid random items. Weights are chosen
-- so each glassy is less likely than every glassy of a lower rarity (as in the Kiln). Duplicates add a star.
Offers.DailyGlassy = {
	ProductId = Ids.DailyGlassy,
	Price = 9,
	Weights = { Common = 0, Uncommon = 0, Rare = 60, Epic = 32, Legendary = 6.5, Mythic = 1.5 },
}

-- Daily Marbles: one buy per UTC day at a fixed price; each day you buy, the next buy gives more, up to the last
-- step, which then repeats. A missed day keeps your place (like Daily Rewards, decision 99): no streak to lose.
Offers.DailyMarbles = {
	ProductId = Ids.DailyMarbles,
	Price = 49,
	Amounts = { 60, 65, 70, 75, 80, 85, 100 },
}

Offers.RequestRateSeconds = 0.5
Offers.BuyRateSeconds = 1

return Offers
