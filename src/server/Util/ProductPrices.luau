-- Checks each configured developer product's price against Roblox (MarketplaceService:GetProductInfoAsync) so a
-- product whose Creator Dashboard price differs from config is never sold: the grant would not match what the player
-- paid (decision 116; decision 80 asked for dashboard and config to change together). Prices are cached and
-- refreshed in the background; an unknown price (lookup failed) does not block, because Roblox's own purchase dialog
-- always shows the real price before the player confirms.
local MarketplaceService = game:GetService("MarketplaceService")
local Prices = {}
Prices.RefreshSeconds = 600
Prices.Known = {} -- [productId] = PriceInRobux
Prices.Expected = {} -- [productId] = config price

local function fetch(productId)
	local ok, info = pcall(function()
		local hasAsync = pcall(function()
			return MarketplaceService.GetProductInfoAsync
		end)
		if hasAsync then
			return MarketplaceService:GetProductInfoAsync(productId, Enum.InfoType.Product)
		end
		return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
	end)
	if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
		Prices.Known[productId] = info.PriceInRobux
	end
end

-- Registers every product the game sells: { { ProductId, Price, Name } }.
function Prices.watch(products)
	for _, product in products do
		if type(product.ProductId) == "number" and product.ProductId > 100 then
			Prices.Expected[product.ProductId] = product.Price
		end
	end
	task.spawn(function()
		while true do
			local mismatched = {}
			for productId, expected in Prices.Expected do
				fetch(productId)
				local known = Prices.Known[productId]
				if known and known ~= expected then
					table.insert(mismatched, productId .. " dashboard " .. known .. " / config " .. expected)
				end
				task.wait(0.2)
			end
			if #mismatched > 0 then
				warn(
					"[GlassClash] products held back until the dashboard price matches config: "
						.. table.concat(mismatched, "; ")
				)
			end
			task.wait(Prices.RefreshSeconds)
		end
	end)
end

-- false only when Roblox is known to charge a different price than config says.
function Prices.matches(productId, price)
	local known = Prices.Known[productId]
	return known == nil or known == price
end

-- Products currently held back: { [tostring(productId)] = dashboard price }.
function Prices.held()
	local out = {}
	for productId, expected in Prices.Expected do
		local known = Prices.Known[productId]
		if known and known ~= expected then
			out[tostring(productId)] = known
		end
	end
	return out
end

return Prices
