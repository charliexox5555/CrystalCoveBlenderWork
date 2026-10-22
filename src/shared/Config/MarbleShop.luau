--!strict
-- Marble (premium currency) packs sold as developer products through StoreService's receipt
-- path. Marbles buy items directly (Pick Any) and, where allowed, Marble crates; paid-random
-- gates stay in MatchService/KilnService. A missing ProductId or Price keeps a pack unavailable.
-- The card's bonus is computed from the smallest pack's rate (OfferRules.bonus), never typed in.
-- Products created 2026-10-17 in universe 10770493435 (regional pricing off). Ladder repriced by
-- decision 116 (docs/design/MONETIZATION.md §5): Price must match the Creator Dashboard, and a pack
-- whose dashboard price differs is held back by StoreService until they match.

export type Pack = {
	Id: string,
	Name: string,
	Marbles: number,
	Art: number, -- illustration size step 1..7
	ProductId: number?,
	Price: number?,
}

local MarbleShop = {}

-- The creator kept an 8,999 R$ top pack (2026-10-21); the 3,999 and 8,999 products keep their dashboard prices.
local Ids = if script then require(script.Parent.ProductIds) else require("./ProductIds")
MarbleShop.Packs = {
	{ Id = "handful", Name = "Marble Handful", Marbles = 100, Art = 1, ProductId = 3719142015, Price = 99 },
	{ Id = "pouch", Name = "Marble Pouch", Marbles = 220, Art = 2, ProductId = 3719142028, Price = 199 },
	{ Id = "jar", Name = "Marble Jar", Marbles = 480, Art = 3, ProductId = 3719142039, Price = 399 },
	{ Id = "bucket", Name = "Marble Bucket", Marbles = 1000, Art = 4, ProductId = 3719142052, Price = 799 },
	{ Id = "barrel", Name = "Marble Barrel", Marbles = 2600, Art = 5, ProductId = Ids.MarbleBarrel, Price = 1999 },
	{ Id = "chest", Name = "Marble Chest", Marbles = 5600, Art = 6, ProductId = 3719142077, Price = 3999 },
	{ Id = "vault", Name = "Marble Vault", Marbles = 13000, Art = 7, ProductId = 3719142087, Price = 8999 },
} :: { Pack }

return MarbleShop
