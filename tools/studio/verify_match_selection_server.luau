-- Server-only isolated Studio mock audit. Run once with an active human test player.
assert(game:GetService("RunService"):IsStudio())
local p = game.Players:GetPlayers()[1]
local data, dev = game.ServerStorage.DataDev, game.ServerStorage.MatchDev
assert(data:Invoke("Inspect", p).Mock, "Never test against live profiles")
dev:Invoke("SelectionTest", "Forfeit", p)
task.wait(0.1)
for _, g in game.ReplicatedStorage.Assets.Glassies:GetChildren() do
	data:Invoke("Grant", p, g.Name)
end
data:Invoke("Marbles", p, 1000 - data:Invoke("Inspect", p).Data.Marbles)
dev:Invoke("SelectionTest", "Policy", p, true)
assert(dev:Invoke("Start", 1, p, nil))
dev:Invoke("SelectionTest", "Hold", p, 120)
local checks = 0
local function check(v, m)
	assert(v, m)
	checks += 1
end
local function state()
	return dev:Invoke("SelectionState", p)
end
local function quote(cost)
	local s = state()
	return { MatchId = s.MatchId, Round = s.Round, SelectionRevision = s.SelectionRevision, Cost = cost }
end
local function attempt(kind, id, cost, q)
	return dev:Invoke("SelectionAttempt", p, kind, id, q or quote(cost))
end
local expected = 1000
local stale = quote(3)
for i, cost in { 3, 3, 6, 6, 9, 9, 9 } do
	check(attempt("Reroll", nil, cost), "Paid reroll")
	expected -= cost
	local s = state()
	check(s.Marbles == expected and s.RerollsUsed == i, "Exact reroll debit/tier")
	local seen = {}
	for _, id in s.Offers do
		check(not seen[id], "No duplicate offer")
		seen[id] = true
	end
	check(#s.Offers == 3, "Three distinct offers")
end
local before = state()
local ok, reason = attempt("Reroll", nil, 3, stale)
check(not ok and reason == "stale" and state().Marbles == before.Marbles, "Replay cannot debit")
ok, reason = attempt("Reroll", nil, 0)
check(not ok and reason == "price_changed" and state().Marbles == expected, "Forged price cannot debit")
ok, reason = attempt("PickAny", "__unowned_fixture", 0)
check(not ok and reason == "not_owned" and state().PickAnyUsed == 0, "Unowned cannot consume free pick")
local hand = table.concat(before.Offers, ",")
dev:Invoke("SelectionTest", "Policy", p, false)
check(not attempt("Reroll", nil, 9), "Restricted random reroll rejected")
check(attempt("PickAny", "milk_bottle", 0), "Free deterministic pick works under restriction")
check(state().Marbles == expected and state().PickAnyUsed == 1, "Free once, no debit")
check(table.concat(state().Offers, ",") == hand, "Pick Any never changes hand")
dev:Invoke("SelectionTest", "Policy", p, true)
dev:Invoke("SelectionTest", "NextRound", p)
dev:Invoke("SelectionTest", "Hold", p, 120)
check(state().Round == 2 and table.concat(state().Offers, ",") == hand, "Next round retains hand")
_G.MatchSelectionQAPart = { Checks = checks, Expected = expected, Hand = hand }
return { Checks = checks, Round = 2, Hand = state().Offers, Marbles = expected, PickAnyUsed = 1, RerollsUsed = 7 }
