-- Pure ownership/equipment rules. Unlocks count only recorded eligible completed matches.
local C = if script then require(script.Parent.Config.RoundCosmetics) else require("./Config/RoundCosmetics")
local Rules = {}
function Rules.matches(data)
	local stats = data.Stats or {}
	return (stats.MatchWins or 0) + (stats.MatchLosses or 0)
end
function Rules.reconcile(data)
	data.Cosmetics = if type(data.Cosmetics) == "table" then data.Cosmetics else {}
	local total = Rules.matches(data)
	for _, category in { "Rideables", "Finishers" } do
		local owned = data.Cosmetics[category]
		if type(owned) ~= "table" then
			owned = {}
			data.Cosmetics[category] = owned
		end
		for _, def in C[category] do
			if total >= def.Matches and not table.find(owned, def.Id) then
				table.insert(owned, def.Id)
			end
		end
		local key = "Equipped" .. category
		local id = data.Cosmetics[key]
		if not C.ByCategory[category][id] or not table.find(owned, id) then
			data.Cosmetics[key] = C[category][1].Id
		end
	end
	return data.Cosmetics
end
function Rules.equip(data, category, id)
	if
		type(category) ~= "string"
		or type(id) ~= "string"
		or #id > 40
		or not C.ByCategory[category]
		or not C.ByCategory[category][id]
	then
		return false
	end
	local cosmetics = Rules.reconcile(data)
	if not table.find(cosmetics[category], id) then
		return false
	end
	cosmetics["Equipped" .. category] = id
	return true
end
return Rules
