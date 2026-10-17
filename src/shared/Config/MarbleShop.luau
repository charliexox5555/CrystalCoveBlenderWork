--!strict
-- Marble (premium currency) packs sold as developer products through StoreService's receipt
-- path. Marbles buy items directly (Pick Any) and, where allowed, Marble crates; paid-random
-- gates stay in MatchService/KilnService. A missing ProductId or Price keeps a pack unavailable.
-- Bonus is the extra Marbles over one Marble per Robux, shown on the card. Products created
-- 2026-10-17 in universe 10770493435 (regional pricing off); Price must match the dashboard.

export type Pack = {
	Id: string,
	Name: string,
	Marbles: number,
	Bonus: number, -- percent, display only
	Art: number, -- illustration size step 1..6
	ProductId: number?,
	Price: number?,
}

local MarbleShop = {}

MarbleShop.Packs = {
	{ Id = "handful", Name = "Marble Handful", Marbles = 100, Bonus = 0, Art = 1, ProductId = 3719142015, Price = 99 },
	{ Id = "pouch", Name = "Marble Pouch", Marbles = 420, Bonus = 5, Art = 2, ProductId = 3719142028, Price = 399 },
	{ Id = "jar", Name = "Marble Jar", Marbles = 900, Bonus = 13, Art = 3, ProductId = 3719142039, Price = 799 },
	{
		Id = "bucket",
		Name = "Marble Bucket",
		Marbles = 2200,
		Bonus = 16,
		Art = 4,
		ProductId = 3719142052,
		Price = 1899,
	},
	{ Id = "chest", Name = "Marble Chest", Marbles = 5000, Bonus = 25, Art = 5, ProductId = 3719142077, Price = 3999 },
	{ Id = "vault", Name = "Marble Vault", Marbles = 12000, Bonus = 33, Art = 6, ProductId = 3719142087, Price = 8999 },
} :: { Pack }

return MarbleShop
