local Rules = if script then require(game.ReplicatedStorage.Shared.HillRules) else require("../shared/HillRules")
local Config = if script then require(game.ReplicatedStorage.Shared.Config.Hill) else require("../shared/Config/Hill")
local Balance = if script
	then require(game.ReplicatedStorage.Shared.Config.Balance)
	else require("../shared/Config/Balance")
local Logic = if script then require(game.ReplicatedStorage.Shared.MatchLogic) else require("../shared/MatchLogic")
local Rng = if script then require(game.ReplicatedStorage.Shared.Rng) else require("../shared/Rng")
return function(t)
	t.test("hill: a one-heart match is over after one round", function()
		local m = Logic.new(
			{ { Collection = {}, Hearts = Config.Hearts }, { Collection = {}, IsBot = true, Hearts = Config.Hearts } },
			Rng.new(5)
		)
		t.eq(m.Sides[1].Hearts, 1)
		Logic.startRound(m)
		Logic.autoPick(m, 1)
		Logic.autoPick(m, 2)
		Logic.endRound(m, 2)
		t.eq(m.Over, true)
		t.eq(m.Winner, 2)
		-- Normal matches keep the normal hearts.
		local normal = Logic.new({ { Collection = {} }, { Collection = {} } }, Rng.new(5))
		t.eq(normal.Sides[1].Hearts, Balance.Match.Hearts)
	end)
	local yes = function()
		return true
	end
	local T0 = 1792368000

	t.test("hill: the Crown Bot holds an empty hill and never fights itself", function()
		local s = Rules.new(T0)
		t.eq(s.King, nil)
		local fight = Rules.nextFight(s, T0 + 100, yes)
		t.eq(fight, nil)
	end)

	t.test("hill: the line is first come, first served, one spot each", function()
		local s = Rules.new(T0)
		t.ok(Rules.join(s, 11))
		t.ok(Rules.join(s, 22))
		local ok, why = Rules.join(s, 11)
		t.eq(ok, false)
		t.eq(why, "already")
		t.eq(Rules.position(s, 22), 2)
		local fight = Rules.nextFight(s, T0, yes)
		t.eq(fight and fight.Challenger, 11)
		t.eq(fight and fight.King, nil)
		t.eq(Rules.position(s, 22), 1)
		t.ok(Rules.leave(s, 22))
		t.eq(#s.Line, 0)
	end)

	t.test("hill: the King can't join the line and the line has a cap", function()
		local s = Rules.new(T0)
		s.King = 5
		local ok, why = Rules.join(s, 5)
		t.eq(ok, false)
		t.eq(why, "king")
		for id = 100, 100 + Config.MaxLine - 1 do
			t.ok(Rules.join(s, id))
		end
		local full, reason = Rules.join(s, 999)
		t.eq(full, false)
		t.eq(reason, "full")
	end)

	t.test("hill: ineligible line members at the front lose their spot", function()
		local s = Rules.new(T0)
		Rules.join(s, 1)
		Rules.join(s, 2)
		Rules.join(s, 3)
		local fight, skipped = Rules.nextFight(s, T0, function(id)
			return id == 3
		end)
		t.eq(fight and fight.Challenger, 3)
		t.eq(#skipped, 2)
		t.eq(#s.Line, 0)
	end)

	t.test("hill: taking the crown from the Crown Bot", function()
		local s = Rules.new(T0)
		local out = Rules.result(s, nil, 7, false, true, T0)
		t.eq(out.Kind, "Taken")
		t.eq(s.King, 7)
		t.eq(out.Crowned, 7)
		t.eq(#out.Pay, 1)
		t.eq(out.Pay[1].Kind, "Take")
		t.eq(s.ReadyAt, T0 + Config.GapSeconds)
	end)

	t.test("hill: losing to the Crown Bot pays the thank-you", function()
		local s = Rules.new(T0)
		local out = Rules.result(s, nil, 7, true, true, T0)
		t.eq(out.Kind, "BotHeld")
		t.eq(s.King, nil)
		t.eq(out.Pay[1].Id, 7)
		t.eq(out.Pay[1].Kind, "Loss")
	end)

	t.test("hill: the Crown Bot challenges a lonely King after a wait, never before the gap", function()
		local s = Rules.new(T0)
		Rules.result(s, nil, 7, false, true, T0) -- 7 is King, ready at T0 + gap
		t.eq(Rules.nextFight(s, T0 + 1, yes), nil)
		local ready = T0 + Config.GapSeconds
		t.eq(Rules.nextFight(s, ready, yes), nil) -- starts the idle clock
		t.eq(Rules.nextFight(s, ready + Config.BotChallengeSeconds - 0.1, yes), nil)
		local fight = Rules.nextFight(s, ready + Config.BotChallengeSeconds, yes)
		t.ok(fight ~= nil, "bot challenge")
		t.eq(fight and fight.King, 7)
		t.eq(fight and fight.Challenger, nil)
	end)

	t.test("hill: a real challenger goes before the Crown Bot", function()
		local s = Rules.new(T0)
		Rules.result(s, nil, 7, false, true, T0)
		Rules.nextFight(s, T0 + Config.GapSeconds, yes)
		Rules.join(s, 8)
		local fight = Rules.nextFight(s, T0 + Config.GapSeconds + 1, yes)
		t.eq(fight and fight.Challenger, 8)
	end)

	t.test("hill: defences count up and the King retires undefeated at the cap", function()
		local s = Rules.new(T0)
		Rules.result(s, nil, 7, false, true, T0)
		for i = 1, Config.ReignCap - 1 do
			local out = Rules.result(s, 7, 100 + i, true, true, T0 + i * 100)
			t.eq(out.Kind, "Defence")
			t.eq(s.Reign, i)
		end
		local out = Rules.result(s, 7, nil, true, true, T0 + 1000)
		t.eq(out.Kind, "Retired")
		t.eq(out.Reign, Config.ReignCap)
		t.eq(s.King, nil)
		local kinds = {}
		for _, p in out.Pay do
			kinds[p.Kind] = p.Id
		end
		t.eq(kinds.Defence, 7)
		t.eq(kinds.Retire, 7)
	end)

	t.test("hill: an AFK King steps down after missed aims in a row", function()
		local s = Rules.new(T0)
		Rules.result(s, nil, 7, false, true, T0)
		t.eq(Rules.result(s, 7, nil, true, false, T0 + 100).Kind, "Defence")
		t.eq(Rules.result(s, 7, nil, true, true, T0 + 200).Kind, "Defence") -- aimed: the count resets
		t.eq(Rules.result(s, 7, nil, true, false, T0 + 300).Kind, "Defence")
		local out = Rules.result(s, 7, nil, true, false, T0 + 400)
		t.eq(out.Kind, "AfkStepDown")
		t.eq(s.King, nil)
	end)

	t.test("hill: a challenger who beats the King takes the crown; the bot can take it back", function()
		local s = Rules.new(T0)
		Rules.result(s, nil, 7, false, true, T0)
		Rules.result(s, 7, nil, true, true, T0 + 100)
		local out = Rules.result(s, 7, 8, false, true, T0 + 200)
		t.eq(out.Kind, "Taken")
		t.eq(s.King, 8)
		t.eq(s.Reign, 0)
		t.eq(out.ReignEnded and out.ReignEnded.Reign, 1)
		local back = Rules.result(s, 8, nil, false, true, T0 + 300)
		t.eq(back.Kind, "BotTook")
		t.eq(s.King, nil)
		t.eq(back.Pay[1].Kind, "Loss")
	end)

	t.test("hill: stepping down hands the hill to the Crown Bot", function()
		local s = Rules.new(T0)
		Rules.result(s, nil, 7, false, true, T0)
		Rules.result(s, 7, nil, true, true, T0 + 100)
		local ended = Rules.stepDown(s, 7)
		t.eq(ended and ended.Reign, 1)
		t.eq(s.King, nil)
		t.eq(Rules.stepDown(s, 7), nil)
	end)

	t.test("hill: coins stop at the daily cap and come back the next day", function()
		local hill = Rules.reconcile({})
		local total = 0
		for _ = 1, 1000 do
			total += Rules.pay(hill, "Tick", T0 + 10)
		end
		total += Rules.pay(hill, "Retire", T0 + 20)
		t.eq(total, Config.Coins.DailyCap)
		t.eq(Rules.coinsLeft(hill, T0 + 30), 0)
		t.eq(Rules.pay(hill, "Take", T0 + 86400), Config.Coins.Take)
		-- Only real payment kinds pay.
		t.eq(Rules.pay(hill, "DailyCap", T0 + 86400), 0)
		t.eq(Rules.pay(hill, "TickSeconds", T0 + 86400), 0)
	end)

	t.test("hill: the retire ticket is once per day and rotates", function()
		local hill = Rules.reconcile({})
		local first = Rules.ticket(hill, T0)
		t.ok(first ~= nil, "first ticket")
		t.eq(Rules.ticket(hill, T0 + 60), nil)
		local nextDay = Rules.ticket(hill, T0 + 86400)
		t.ok(nextDay ~= nil and nextDay ~= first, "rotates the next day")
	end)

	t.test("hill: stats count crowns and the best reign", function()
		local s, hill = Rules.new(T0), Rules.reconcile({})
		Rules.record(hill, 7, Rules.result(s, nil, 7, false, true, T0))
		Rules.record(hill, 7, Rules.result(s, 7, nil, true, true, T0 + 100))
		Rules.record(hill, 7, Rules.result(s, 7, nil, true, true, T0 + 200))
		Rules.record(hill, 7, Rules.result(s, 7, 8, false, true, T0 + 300))
		t.eq(hill.Crowns, 1)
		t.eq(hill.BestReign, 2)
	end)

	t.test("hill: reconcile repairs junk", function()
		local data = { Hill = { Crowns = -3, BestReign = 0 / 0, Day = "x", CoinsToday = 2.7, TicketDay = math.huge } }
		local hill = Rules.reconcile(data)
		t.eq(hill.Crowns, 0)
		t.eq(hill.BestReign, 0)
		t.eq(hill.Day, 0)
		t.eq(hill.CoinsToday, 2)
		t.eq(hill.TicketDay, -1)
	end)

	-- Balance guard (FEATURED_STAGE.md): crown coins stay near normal play and never become a farm.
	t.test("hill: coins stay balanced against normal play", function()
		local C = Config.Coins
		local normalPerMinute = 800 / 60 -- ECONOMY.md: about 800 coins an hour from matches
		local fightSeconds = 100 -- one sudden-death round with picks
		local ticksPerFight = math.floor(fightSeconds / C.TickSeconds) * C.Tick
		-- A full reign: take + cap defences (each with its ticks) + retire.
		local reignCoins = C.Take + Config.ReignCap * (C.Defence + ticksPerFight) + C.Retire
		local reignMinutes = (Config.ReignCap + 1) * (fightSeconds + Config.GapSeconds) / 60
		local perMinute = reignCoins / reignMinutes
		t.ok(perMinute <= 3 * normalPerMinute, "a perfect reign is a treat, not a farm: " .. perMinute)
		-- A typical King (one defence, then loses) earns about normal play.
		local typical = (C.Take + C.Defence + 2 * ticksPerFight + C.Loss)
			/ (3 * (fightSeconds + Config.GapSeconds) / 60)
		t.ok(
			typical >= normalPerMinute and typical <= 2.5 * normalPerMinute,
			"typical King near normal play: " .. typical
		)
		-- Losing a hill fight pays less than a normal loss.
		t.ok(C.Loss < Balance.Match.Rewards.LossBaseCoins + 1, "hill loss below a normal loss")
		-- The daily cap is under an hour of normal play.
		t.ok(C.DailyCap < 60 * normalPerMinute, "cap under an hour of play")
		-- Hill fights are sudden death.
		t.eq(Config.Hearts, 1)
	end)
end
