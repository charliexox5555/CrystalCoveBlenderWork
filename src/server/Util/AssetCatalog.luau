local RS = game:GetService("ReplicatedStorage")
local Glassies = require(RS.Shared.Config.Glassies)
local Catalog = {}
function Catalog.cosmetic(category, id)
	if type(category) ~= "string" or type(id) ~= "string" then
		return nil
	end
	local C = require(RS.Shared.Config.RoundCosmetics)
	local def = C.ByCategory[category] and C.ByCategory[category][id]
	if not def then
		return nil
	end
	if def.AssetBundle then
		local seasonal = RS.Assets:FindFirstChild("Seasonal")
		local bundle = seasonal and seasonal:FindFirstChild(def.AssetBundle)
		return bundle and bundle:FindFirstChild(def.AssetName)
	end
	local folder = RS.Assets:FindFirstChild(if category == "Rideables" then "Rideables" else "RoundFinishers")
	return folder and folder:FindFirstChild(id)
end
function Catalog.has(id)
	local folder = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("Glassies")
	local source = folder and folder:FindFirstChild(id)
	return source
		and source:FindFirstChild("Body")
		and source.Body:IsA("BasePart")
		and source:FindFirstChild("Shards")
		and #source.Shards:GetChildren() >= 12
end
function Catalog.collection(collection)
	local out = {}
	for id, owned in collection do
		if Glassies.ById[id] and Catalog.has(id) then
			out[id] = table.clone(owned)
		end
	end
	return out
end
return Catalog
