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
	StarterPack = 3720942636,
	DailyGlassy = 3720942645,
	DailyMarbles = 3720942670,
	MarbleBarrel = 3720942682,
	FinisherMythic = 3720942703,
	FlyerEpic = 3720942723,
	FlyerLegendary = 3720942740,
	FlyerMythic = 3720942761,
}

return ids
