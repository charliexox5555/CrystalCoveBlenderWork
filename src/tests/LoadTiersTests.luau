-- Config/LoadTiers (decision 111): every tier item and on-demand item must parse, and point at something real.
local function config(name: string): any
	return if script then require(game.ReplicatedStorage.Shared.Config:FindFirstChild(name)) else nil
end
local LoadTiers = if script then config("LoadTiers") else require("../shared/Config/LoadTiers")
local UIAssets = if script then config("UIAssets") else require("../shared/Config/UIAssets")
-- The config modules items may name with images: / sounds: / anims:.
local Modules = if script
	then {
		Audio = config("Audio"),
		PowerAudio = config("PowerAudio"),
		KilnAssets = config("KilnAssets"),
		PrizeCardAssets = config("PrizeCardAssets"),
		FinisherShows = config("FinisherShows"),
		RideAnimations = config("RideAnimations"),
		RideFamilies = config("RideFamilies"),
		ItemIcons = config("ItemIcons"),
	}
	else {
		Audio = require("../shared/Config/Audio"),
		PowerAudio = require("../shared/Config/PowerAudio"),
		KilnAssets = require("../shared/Config/KilnAssets"),
		PrizeCardAssets = require("../shared/Config/PrizeCardAssets"),
		FinisherShows = require("../shared/Config/FinisherShows"),
		RideAnimations = require("../shared/Config/RideAnimations"),
		RideFamilies = require("../shared/Config/RideFamilies"),
		ItemIcons = require("../shared/Config/ItemIcons"),
	}

local KINDS =
	{ ui = true, screen = true, asset = true, rs = true, images = true, sounds = true, anims = true, id = true }
local BARE = { fonts = true, spawn = true, lobby = true, owned = true }

local function hasId(value: any, depth: number): boolean
	if type(value) == "string" then
		return value:match("^rbxassetid://%d+") ~= nil
	elseif type(value) == "table" and depth < 8 then
		for _, v in value do
			if hasId(v, depth + 1) then
				return true
			end
		end
	end
	return false
end

return function(t)
	local function checkItem(where: string, item: string)
		if BARE[item] then
			t.ok(true, where)
			return
		end
		local kind, arg = item:match("^(%w+):(.*)$")
		t.ok(kind ~= nil and KINDS[kind] == true, where .. ": " .. item .. " has a known kind")
		if kind == "ui" then
			local found = false
			for key in UIAssets do
				if key:sub(1, #arg) == arg then
					found = true
				end
			end
			t.ok(found, where .. ": " .. item .. " matches a UIAssets key")
		elseif kind == "images" or kind == "sounds" or kind == "anims" then
			local segments = string.split(arg, "/")
			local value = Modules[segments[1]]
			for i = 2, #segments do
				value = if type(value) == "table" then value[segments[i]] else nil
			end
			t.ok(value ~= nil and hasId(value, 0), where .. ": " .. item .. " names a config part with ids")
		elseif kind == "id" then
			t.ok(arg:match("^rbxassetid://%d+$") ~= nil, where .. ": " .. item .. " is an asset id")
		elseif kind == "screen" or kind == "asset" or kind == "rs" then
			t.ok(arg:match("^[%w_/]*$") ~= nil, where .. ": " .. item .. " is a plain name")
		end
	end
	t.test("tiers are in order and every item parses", function()
		t.ok(#LoadTiers.Order == 3, "three tiers")
		for _, tier in LoadTiers.Order do
			local list = LoadTiers.Tiers[tier]
			t.ok(type(list) == "table" and #list > 0, tier .. " has items")
			local seen = {}
			for _, item in list or {} do
				t.ok(not seen[item], tier .. ": " .. item .. " listed once")
				seen[item] = true
				checkItem(tier, item)
			end
		end
		t.ok(table.find(LoadTiers.Tiers.Essential, "spawn") ~= nil, "Essential loads the spawn area")
		t.ok(table.find(LoadTiers.Tiers.Essential, "fonts") ~= nil, "Essential loads the fonts")
	end)
	t.test("the first minute's UI is Essential", function()
		for _, item in
			{
				"screen:LobbyHUD",
				"screen:WelcomeScreen",
				"screen:DailyRewardsScreen",
				"ui:onboarding/",
				"ui:topbar/",
				"ui:hud/",
			}
		do
			t.ok(table.find(LoadTiers.Tiers.Essential, item) ~= nil, item .. " is Essential")
		end
	end)
	t.test("on-demand groups and lanes are valid", function()
		for name, items in LoadTiers.OnDemand do
			t.ok(#items > 0, name .. " has items")
			for _, item in items do
				checkItem("OnDemand." .. name, item)
			end
		end
		for _, lane in { "Urgent", "Essential", "Soon", "Later" } do
			local spec = LoadTiers.Lanes[lane]
			t.ok(spec ~= nil and spec.Workers >= 1 and spec.Gap >= 0, lane .. " lane has workers and a gap")
		end
		t.ok(LoadTiers.Lanes.Later.Workers <= LoadTiers.Lanes.Soon.Workers, "Later never runs wider than Soon")
		t.ok(LoadTiers.BatchSize >= 1 and LoadTiers.SpawnRadius > 0 and LoadTiers.RetryDelay > 0, "numbers positive")
	end)
end
