--!strict
-- Developer product ids for the monetization pass (decision 116, docs/design/MONETIZATION.md §9). One place to fill in
-- once the products exist on Roblox (universe 10770493435, regional pricing off): `tools/opencloud/products.py`
-- creates them when the Open Cloud key has the developer-product scope, or the creator makes them on the Creator
-- Dashboard and pastes the ids here. nil = not created yet: live servers show SOON, Studio simulates the purchase.
-- The price on the dashboard must equal the Price next to each id's use (Config/Offers, Config/DailyStore).

export type Ids = {
	StarterPack: number?, -- "Starter Pack", 49
	DailyGlassy: number?, -- "Daily Glassy", 9
	DailyMarbles: number?, -- "Daily Marbles", 49
	MarbleBarrel: number?, -- "Marble Barrel", 1999
	FinisherMythic: number?, -- "Daily Offer: Mythic Finisher", 499
	FlyerEpic: number?, -- "Daily Offer: Epic Flyer", 199
	FlyerLegendary: number?, -- "Daily Offer: Legendary Flyer", 399
	FlyerMythic: number?, -- "Daily Offer: Mythic Flyer", 599
}

local ids: Ids = {
	StarterPack = nil,
	DailyGlassy = nil,
	DailyMarbles = nil,
	MarbleBarrel = nil,
	FinisherMythic = nil,
	FlyerEpic = nil,
	FlyerLegendary = nil,
	FlyerMythic = nil,
}

return ids
