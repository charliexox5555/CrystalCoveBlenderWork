local RS = game:GetService("ReplicatedStorage")
local Glassies = require(RS.Shared.Config.Glassies)
local Catalog = {}
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
	for _, id in Glassies.Starters do
		if Catalog.has(id) and not out[id] then
			out[id] = {}
		end
	end
	return out
end
return Catalog
