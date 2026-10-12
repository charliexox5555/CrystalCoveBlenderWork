--!strict
-- Cosmetics (GAME_DESIGN 9). Robux items get a ProductId / GamePassId once created on the
-- Creator Dashboard; leave nil until then.

export type ShatterFxDef = {
	Id: string,
	Name: string,
	Tier: "Free" | "Coins" | "Robux" | "Event",
	Coins: number?,
	ProductId: number?,
	Description: string,
}

export type FillDef = {
	Id: string,
	Name: string,
	Color: string,
	Coins: number?,
	ProductId: number?,
}

local Cosmetics = {}

Cosmetics.ShatterFx = {
	{ Id = "default", Name = "Sparkle", Tier = "Free", Description = "Clean glass sparkle." },
	{ Id = "confetti", Name = "Confetti", Tier = "Coins", Coins = 500, Description = "Party time." },
	{ Id = "bubbles", Name = "Bubbles", Tier = "Coins", Coins = 750, Description = "Pop, pop, pop." },
	{ Id = "ice_burst", Name = "Ice Burst", Tier = "Coins", Coins = 1200, Description = "Frosty shards." },
	{ Id = "rainbow", Name = "Rainbow", Tier = "Robux", Description = "Every colour at once." },
	{ Id = "lightning", Name = "Lightning", Tier = "Robux", Description = "Crackling bolts." },
	{ Id = "candy_pop", Name = "Candy Pop", Tier = "Robux", Description = "Sweets everywhere." },
	{ Id = "pumpkin_burst", Name = "Pumpkin Burst", Tier = "Event", Description = "Seeds and candy." },
	{ Id = "unicorn_sparkle", Name = "Unicorn Sparkle", Tier = "Robux", Description = "Rainbow glitter and stars." },
	{ Id = "dragon_fire", Name = "Dragon Fire", Tier = "Robux", Description = "Glowing embers." },
	{ Id = "galaxy", Name = "Galaxy", Tier = "Robux", Description = "A tiny supernova." },
} :: { ShatterFxDef }

Cosmetics.Fills = {
	{ Id = "soda", Name = "Soda", Color = "#8FE3FF", Coins = 300 },
	{ Id = "slime", Name = "Slime", Color = "#7CFF6B", Coins = 600 },
	{ Id = "lava", Name = "Lava", Color = "#FF6A2E", Coins = 900 },
	{ Id = "glitter", Name = "Glitter", Color = "#FFD6F5" },
	{ Id = "honey", Name = "Honey", Color = "#FFB92E", Coins = 600 },
	{ Id = "galaxy", Name = "Galaxy", Color = "#7A5CFF" },
} :: { FillDef }

return Cosmetics
