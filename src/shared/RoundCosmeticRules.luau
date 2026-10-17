-- Pure ownership/equipment rules. Counts migrate existing ownership; starters stay free.
local C = if script then require(script.Parent.Config.RoundCosmetics) else require("./Config/RoundCosmetics")
local Rules = {}
function Rules.matches(data)
	local stats = data.Stats or {}
	return (stats.MatchWins or 0) + (stats.MatchLosses or 0)
end
function Rules.reconcile(data)
	data.Cosmetics = if type(data.Cosmetics) == "table" then data.Cosmetics else {}
	data.Cosmetics.Counts = if type(data.Cosmetics.Counts) == "table" then data.Cosmetics.Counts else {}
	for _, category in { "Rideables", "Finishers", "Skins" } do
		local owned = data.Cosmetics[category]
		if type(owned) ~= "table" then
			owned = {}
			data.Cosmetics[category] = owned
		end
		local counts = data.Cosmetics.Counts[category]
		if type(counts) ~= "table" then
			counts = {}
			data.Cosmetics.Counts[category] = counts
		end
		for _, def in C.catalog(category) do
			local count = counts[def.Id]
			count = if type(count) == "number"
					and count == count
					and count < math.huge
				then math.max(0, math.floor(count))
				else 0
			if table.find(owned, def.Id) or def.Matches == 0 then
				count = math.max(1, count)
			end
			counts[def.Id] = count
			if count > 0 and not table.find(owned, def.Id) then
				table.insert(owned, def.Id)
			end
		end
		local key = "Equipped" .. category
		local id = data.Cosmetics[key]
		if not C.ByCategory[category][id] or not table.find(owned, id) then
			data.Cosmetics[key] = C.default(category)
		end
	end
	return data.Cosmetics
end
function Rules.count(data, category, id)
	local cosmetics = data.Cosmetics or {}
	local counts = cosmetics.Counts and cosmetics.Counts[category]
	return counts and counts[id] or (if table.find(cosmetics[category] or {}, id) then 1 else 0)
end
function Rules.grant(data, category, id)
	assert(C.ByCategory[category] and C.ByCategory[category][id], "Unknown cosmetic")
	Rules.reconcile(data)
	local previous = Rules.count(data, category, id)
	data.Cosmetics.Counts[category][id] = previous + 1
	if previous == 0 then
		table.insert(data.Cosmetics[category], id)
	end
	return { Id = id, Count = previous + 1, Duplicate = previous > 0 }
end
function Rules.equip(data, category, id)
	if
		type(category) ~= "string"
		or type(id) ~= "string"
		or #id > 40
		or not C.ByCategory[category]
		or (id ~= "" and not C.ByCategory[category][id])
	then
		return false
	end
	local cosmetics = Rules.reconcile(data)
	if id == "" then
		cosmetics["Equipped" .. category] = C.default(category)
		return true
	end
	if not table.find(cosmetics[category], id) then
		return false
	end
	local def = C.ByCategory[category][id]
	if def.BaseGlassy and (not data.Glassies or not data.Glassies[def.BaseGlassy]) then
		return false
	end
	cosmetics["Equipped" .. category] = id
	return true
end
-- Freeze a validated cosmetic loadout at match creation, independently of combat setup/stats.
function Rules.loadout(data)
	local cosmetics = Rules.reconcile(data)
	local skin = cosmetics.EquippedSkins
	local def = C.ByCategory.Skins[skin]
	if def and (not data.Glassies or not data.Glassies[def.BaseGlassy]) then
		skin = ""
	end
	return { Rideables = cosmetics.EquippedRideables, Finishers = cosmetics.EquippedFinishers, Skins = skin }
end
return Rules
