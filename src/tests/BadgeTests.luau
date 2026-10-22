local Rules = if script
	then require(game.ServerScriptService.Server.Data.BadgeRules)
	else require("../server/Data/BadgeRules")
local Schema = if script
	then require(game.ServerScriptService.Server.Data.ProfileSchema)
	else require("../server/Data/ProfileSchema")
local Config = if script
	then require(game.ReplicatedStorage.Shared.Config.Badges)
	else require("../shared/Config/Badges")
local Levels = if script then require(game.ReplicatedStorage.Shared.LevelRules) else require("../shared/LevelRules")
return function(t, d)
	-- A set from a list of keys.
	local function keys(list)
		local out = {}
		for _, key in list do
			out[key] = true
		end
		return out
	end
	t.test("badges: five, so none cost Robux (5 free a day per experience)", function()
		t.eq(#Config.Order, 5)
		local seen = {}
		for _, key in Config.Order do
			local def = Config.ByKey[key]
			t.ok(def ~= nil and not seen[key], key)
			seen[key] = true
			t.ok(#def.Name > 0 and #def.Name <= 50, key .. " name fits the 50-character limit")
			t.ok(#def.Description > 0 and #def.Description <= 1000, key .. " description")
			t.ok(def.Id == nil or (type(def.Id) == "number" and def.Id > 0 and def.Id % 1 == 0), key .. " id")
			t.ok(string.find(def.Icon, "^assets/badges/png/") ~= nil, key .. " icon")
		end
		t.ok(Config.ByKey.Welcome ~= nil and Config.ByKey.FirstWin ~= nil, "the creator's two")
		t.ok(d.Glassies.ById[Config.WeekGlassy] ~= nil, "Midnight exists")
		t.ok(Config.FindRarities.Legendary and Config.FindRarities.Mythic and not Config.FindRarities.Epic)
	end)
	t.test("badges: new profiles start empty, reconcile drops junk", function()
		local data = Schema.new(0)
		t.eq(next(data.Badges.Earned), nil)
		t.eq(next(data.Badges.Awarded), nil)
		data.Badges = { Earned = { Welcome = true, Bogus = true, FirstWin = "yes" }, Awarded = 5 }
		Schema.reconcile(data, 0)
		t.eq(data.Badges.Earned.Welcome, true)
		t.eq(data.Badges.Earned.Bogus, nil)
		t.eq(data.Badges.Earned.FirstWin, nil)
		t.eq(next(data.Badges.Awarded), nil)
		local old = Schema.new(0)
		old.Badges = nil -- a profile from before badges
		Schema.reconcile(old, 0)
		t.ok(type(old.Badges.Earned) == "table" and type(old.Badges.Awarded) == "table")
	end)
	t.test("badges: Welcome on the first check; level and week from the profile", function()
		local data = Schema.new(0)
		t.eq(Rules.fromState(data)[1], "Welcome")
		t.eq(#Rules.fromState(data), 0, "nothing new the second time")
		data.Xp = Levels.totalFor(Config.Level) - 1
		Rules.fromState(data)
		t.eq(data.Badges.Earned.Level10, nil, "one XP short")
		data.Xp += 1
		t.eq(Rules.fromState(data)[1], "Level10")
		data.Calendar.Index = 6
		Rules.fromState(data)
		t.eq(data.Badges.Earned.DailyWeek, nil, "Day 6")
		data.Calendar.Index = 7
		t.eq(Rules.fromState(data)[1], "DailyWeek")
		local back = Schema.new(0) -- did a week before badges: the cycle restarted, Midnight stayed
		back.Calendar.Index = 2
		Schema.grant(back, Config.WeekGlassy, false, 0)
		Rules.fromState(back)
		t.eq(back.Badges.Earned.DailyWeek, true)
	end)
	t.test("badges: First Win needs a player on both sides", function()
		t.eq(Rules.roundWon(true, true), "FirstWin")
		t.eq(Rules.roundWon(true, false), nil, "won over a bot")
		t.eq(Rules.roundWon(false, true), nil, "the bot won")
		t.eq(Rules.roundWon(nil, nil), nil)
	end)
	t.test("badges: Legendary Find from Legendary or Mythic only", function()
		t.eq(Rules.pulled({ "Common", "Rare", "Epic" }), nil)
		t.eq(Rules.pulled({ "Common", "Legendary" }), "LegendaryFind")
		t.eq(Rules.pulled({ "Mythic" }), "LegendaryFind")
		t.eq(Rules.pulled({}), nil)
		t.eq(Rules.pulled(nil), nil)
	end)
	t.test("badges: due once, in order, until awarded; never twice", function()
		local data = Schema.new(0)
		Rules.earn(data, "LegendaryFind")
		Rules.fromState(data)
		t.eq(Rules.earn(data, "Welcome"), false, "already earned")
		t.eq(Rules.earn(data, "Bogus"), false)
		local studio = Rules.due(data, nil, false)
		t.eq(studio[1], "Welcome")
		t.eq(studio[2], "LegendaryFind")
		t.eq(#studio, 2)
		t.eq(#Rules.due(data, keys({ "Welcome" }), false), 1, "Studio skips what it mock-awarded")
		local withIds = 0
		for _, key in studio do
			if Config.ByKey[key].Id then
				withIds += 1
			end
		end
		t.eq(#Rules.due(data, nil, true), withIds, "live awards only badges with an id")
		-- A failed award leaves it due; a confirmed one never comes back, even if the rule fires again.
		Rules.markAwarded(data, "Welcome")
		Rules.fromState(data)
		t.eq(Rules.earn(data, "Welcome"), false)
		t.eq(Rules.due(data, nil, false)[1], "LegendaryFind")
		Rules.markAwarded(data, "LegendaryFind")
		t.eq(#Rules.due(data, nil, false), 0)
		-- Awarded survives a save and reload.
		local saved = Schema.copy(data)
		Schema.reconcile(saved, 0)
		t.eq(saved.Badges.Awarded.Welcome, true)
		t.eq(#Rules.due(saved, nil, false), 0)
	end)
end
