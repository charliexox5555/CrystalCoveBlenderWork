-- Config/ItemIcons (decision 113): every icon is an asset id for a real item, and Large only adds to Small.
local Shared = if script then game.ReplicatedStorage.Shared.Config else nil
local ItemIcons = if Shared then require(Shared.ItemIcons) else require("../shared/Config/ItemIcons")
local Glassies = if Shared then require(Shared.Glassies) else require("../shared/Config/Glassies")
local Cosmetics = if Shared then require(Shared.RoundCosmetics) else require("../shared/Config/RoundCosmetics")
return function(t)
	local function known(category, id)
		if category == "Glassies" then
			return Glassies.get(id) ~= nil
		elseif category == "Machines" then
			local kind, currency = id:match("^(%w+):(%w+)$")
			return (kind == "Glassies" or kind == "Finishers" or kind == "Rideables")
				and (currency == "Coins" or currency == "Marbles")
		end
		return id == "no_flyer" and category == "Rideables" or Cosmetics.ByCategory[category][id] ~= nil
	end
	t.test("icons are asset ids for real items", function()
		for _, size in { "Small", "Large" } do
			for _, category in { "Glassies", "Rideables", "Finishers", "Machines" } do
				local list = ItemIcons[size][category]
				t.ok(type(list) == "table", size .. "." .. category .. " exists")
				for id, image in list or {} do
					t.ok(image:match("^rbxassetid://%d+$") ~= nil, size .. " " .. id .. " is an asset id")
					t.ok(known(category, id), size .. " " .. category .. "/" .. id .. " is a real item")
					if size == "Large" then
						t.ok(ItemIcons.Small[category][id] ~= nil, id .. " has a Small icon too")
					end
				end
			end
		end
	end)
	t.test("get returns Small with Large when there is one", function()
		local id, image = next(ItemIcons.Small.Glassies)
		if id then
			local entry = ItemIcons.get("Glassies", id)
			t.ok(entry ~= nil and entry.Small == image, "get finds " .. id)
		end
		t.ok(ItemIcons.get("Glassies", "no_such_glassy") == nil, "unknown ids fall back to the viewport")
		t.ok(ItemIcons.LargeAbovePixels > 0, "large threshold positive")
	end)
end
